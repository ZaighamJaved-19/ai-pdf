from __future__ import annotations

import argparse
from collections.abc import Callable
from datetime import datetime
import json
import os
from pathlib import Path
import secrets
import sys
import threading
import time
import traceback
from typing import Any
import uuid

from ai_pdf_studio.ai_chat import PdfChatService
from ai_pdf_studio.ai_tools import AiToolError, AiToolRequest, AiToolsService
from ai_pdf_studio.ai_tools.export import export_result
from ai_pdf_studio.ai_providers import AnthropicClient, ChatMessage, OpenAIClient, OpenAIError, ProviderError
from ai_pdf_studio.library import DocumentRepository
from ai_pdf_studio.pdf import PdfEditor, PdfError, PdfPageOperations, PdfSecurityError, PdfSecurityService, PdfService
from ai_pdf_studio.redaction import RedactionError, RedactionRequest, RedactionService
from ai_pdf_studio.rag import LocalRetriever, PersistentVectorStore, SemanticChunker, TextChunk
from ai_pdf_studio.security import Consent, require_consent

CONTRACT_VERSION = "1.0.0-draft.1"
SIDECAR_VERSION = "0.2.0"


class RpcFailure(RuntimeError):
    def __init__(self, code: int, message: str, data: dict[str, Any] | None = None):
        super().__init__(message)
        self.code = code
        self.data = data or {}


class CancellationToken:
    def __init__(self, job_id: str) -> None:
        self.job_id = job_id
        self._event = threading.Event()

    def cancel(self) -> None:
        self._event.set()

    def raise_if_cancelled(self) -> None:
        if self._event.is_set():
            raise RpcFailure(-32800, "Job cancelled.", {"kind": "Cancelled"})


class Job:
    def __init__(self, job_id: str, request_id: Any, token: CancellationToken):
        self.job_id = job_id
        self.request_id = request_id
        self.token = token
        self.result: dict[str, Any] | None = None
        self.error: RpcFailure | None = None
        self.done = threading.Event()


class SidecarServer:
    """Authenticated newline-delimited JSON-RPC server for the Flutter client."""

    def __init__(self, token: str, database_path: Path | None = None) -> None:
        if not token:
            raise ValueError("A sidecar authentication token is required.")
        self._token = token
        self._started = time.monotonic()
        self._output_lock = threading.Lock()
        self._stop = threading.Event()
        self._jobs: dict[str, Job] = {}
        self._jobs_lock = threading.Lock()
        database = database_path or Path.home() / ".ai-pdf-studio" / "library.db"
        database.parent.mkdir(parents=True, exist_ok=True)
        self._database = DocumentRepository(database)
        self._pdf = PdfService()
        self._pageops = PdfPageOperations()
        self._editor = PdfEditor()
        self._security = PdfSecurityService()
        self._redaction = RedactionService()
        self._retrievers: dict[str, LocalRetriever] = {}
        self._vectors = PersistentVectorStore(database)
        self._ai_tools = AiToolsService()
        self._methods: dict[str, Callable[[dict[str, Any], Any], Any]] = {
            "system.handshake": self._handshake,
            "system.health": self._health,
            "system.shutdown": self._shutdown,
            "job.cancel": self._cancel,
            "job.result": self._job_result,
            "library.list": self._library_list,
            "library.upsert": self._library_upsert,
            "library.remove": self._library_remove,
            "library.relocate": self._library_relocate,
            "library.note.get": self._library_note_get,
            "library.note.set": self._library_note_set,
            "library.tags": self._library_tags,
            "library.tags.set": self._library_tags_set,
            "library.folders": self._library_folders,
            "library.workspaces": self._library_workspaces,
            "library.workspace.create": self._library_workspace_create,
            "library.workspace.add": self._library_workspace_add,
            "library.searchContent": self._library_search_content,
            "pdf.inspect": self._pdf_inspect,
            "pdf.extractText": self._pdf_extract,
            "pdf.edit": self._pdf_edit,
            "pdf.saveAs": self._pdf_edit,
            "pdf.extractPages": self._pdf_extract_pages,
            "pdf.transform": self._pdf_transform,
            "pdf.merge": self._pdf_merge,
            "pdf.split": self._pdf_split,
            "pdf.compress": self._pdf_compress,
            "pdf.protect": self._pdf_protect,
            "pdf.removePassword": self._pdf_remove_password,
            "pdf.removeMetadata": self._pdf_remove_metadata,
            "pdf.sign": self._pdf_sign,
            "pdf.validateSignature": self._pdf_validate_signature,
            "pdf.redact": self._pdf_redact,
            "chat.ask": self._chat_ask,
            "index.start": self._index_start,
            "provider.test": self._provider_test,
            "ai.tool.generate": self._ai_tool_generate,
            "ai.tool.export": self._ai_tool_export,
            "privacy.clearCache": self._privacy_clear_cache,
        }

    def serve(self, input_stream: Any = sys.stdin, output_stream: Any = sys.stdout) -> None:
        for line in input_stream:
            if self._stop.is_set():
                break
            if not line.strip():
                continue
            try:
                request = json.loads(line)
                response = self._dispatch(request)
            except json.JSONDecodeError:
                response = self._error(None, -32700, "Invalid JSON.")
            except Exception:
                response = self._error(None, -32603, "Internal server error.")
                print(traceback.format_exc(), file=sys.stderr, flush=True)
            if response is not None:
                self._write(response, output_stream)
        self._database.close()
        self._vectors.close()

    def _dispatch(self, request: dict[str, Any]) -> dict[str, Any] | None:
        request_id = request.get("id")
        if request.get("jsonrpc") != "2.0":
            return self._error(request_id, -32600, "Invalid Request.")
        if not secrets.compare_digest(str(request.get("auth", "")), self._token):
            return self._error(request_id, -32001, "Authentication failed.", {"kind": "Auth"})
        method = request.get("method")
        handler = self._methods.get(method)
        if handler is None:
            return self._error(request_id, -32601, f"Method not found: {method}")
        try:
            result = handler(request.get("params") or {}, request_id)
            if request_id is None:
                return None
            return {"jsonrpc": "2.0", "id": request_id, "result": result}
        except RpcFailure as exc:
            return self._error(request_id, exc.code, str(exc), exc.data)
        except PdfSecurityError as exc:
            return self._error(request_id, -32011, str(exc), {"kind": "PdfSecurityError"})
        except RedactionError as exc:
            return self._error(request_id, -32012, str(exc), {"kind": "RedactionError"})
        except (KeyError, TypeError, ValueError) as exc:
            return self._error(request_id, -32602, str(exc))
        except PdfError as exc:
            return self._error(request_id, -32010, str(exc), {"kind": "PdfError"})

    def _handshake(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        client_version = params.get("clientContractVersion")
        if client_version and str(client_version).split(".")[0] != CONTRACT_VERSION.split(".")[0]:
            raise RpcFailure(-32002, "Contract version mismatch.", {"kind": "VersionMismatch"})
        return {
            "contractVersion": CONTRACT_VERSION,
            "sidecarVersion": SIDECAR_VERSION,
            "capabilities": {
                "methods": sorted(self._methods),
                "streaming": True,
                "transport": "stdio",
                "ocr": False,
                "conversion": False,
                "aiTools": True,
                "exports": ["txt", "pdf", "docx"],
            },
        }

    def _health(self, _: dict[str, Any], __: Any) -> dict[str, Any]:
        with self._jobs_lock:
            active = sum(not job.done.is_set() for job in self._jobs.values())
        return {"ok": True, "uptimeSeconds": time.monotonic() - self._started, "activeJobs": active}

    def _shutdown(self, _: dict[str, Any], __: Any) -> dict[str, Any]:
        self._stop.set()
        return {"ok": True}

    def _cancel(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        job = self._jobs.get(str(params["jobId"]))
        if job is None:
            return {"cancelled": False}
        job.token.cancel()
        return {"cancelled": True}

    def _job_result(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        job = self._jobs.get(str(params["jobId"]))
        if job is None:
            raise RpcFailure(-32004, "Unknown job.", {"kind": "UnknownJob"})
        if not job.done.is_set():
            return {"state": "running", "jobId": job.job_id}
        if job.error:
            raise job.error
        return {"state": "completed", "jobId": job.job_id, "result": job.result}

    def _library_list(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        scope = params.get("scope", "recent")
        documents = self._database.list_documents(
            query=str(params.get("query", "")),
            favorite=True if scope == "favorites" else None,
            folder=params.get("folder"),
            tag=params.get("tag"),
            workspace=params.get("workspace"),
            limit=int(params.get("limit", 100)),
        )
        return {"documents": [self._document_json(document) for document in documents]}

    def _library_upsert(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = Path(str(params["path"])).expanduser().resolve()
        if not path.is_file():
            raise RpcFailure(-32010, "PDF file does not exist.", {"kind": "FileNotFound"})
        if path.suffix.lower() != ".pdf":
            raise RpcFailure(-32011, "Selected file is not a PDF.", {"kind": "NotAPdf"})
        record = self._database.upsert(
            path,
            title=params.get("title"),
            last_page=int(params.get("lastPage", 1)),
            favorite=bool(params.get("favorite", False)),
        )
        try:
            pages = self._pdf.extract_text(path)
            self._database.index_content(path, tuple((page.page_number, page.text) for page in pages))
        except PdfError:
            # Keep the library reference so the UI can report a corrupt or encrypted source.
            pass
        return self._document_json(record)

    def _library_remove(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = Path(str(params["path"])).expanduser().resolve()
        return {"removed": self._database.remove(path), "path": str(path)}

    def _library_relocate(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        old_path = Path(str(params["oldPath"])).expanduser().resolve()
        new_path = Path(str(params["newPath"])).expanduser().resolve()
        if not new_path.is_file():
            raise RpcFailure(-32010, "The replacement PDF does not exist.", {"kind": "FileNotFound"})
        if new_path.suffix.lower() != ".pdf":
            raise RpcFailure(-32011, "The replacement file is not a PDF.", {"kind": "NotAPdf"})
        record = self._database.relocate(old_path, new_path)
        return self._document_json(record)

    def _library_note_get(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = Path(str(params["path"])).expanduser().resolve()
        return {"path": str(path), "note": self._database.note(path)}

    def _library_note_set(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = Path(str(params["path"])).expanduser().resolve()
        note = str(params.get("note", ""))
        return {"path": str(path), "note": self._database.set_note(path, note)}

    def _library_tags(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = Path(str(params["path"])).expanduser().resolve()
        return {"path": str(path), "tags": list(self._database.tags(path))}

    def _library_tags_set(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = Path(str(params["path"])).expanduser().resolve()
        tags = {str(tag) for tag in params.get("tags", [])}
        return {"path": str(path), "tags": list(self._database.set_tags(path, tags))}

    def _library_folders(self, _: dict[str, Any], __: Any) -> dict[str, Any]:
        return {"folders": list(self._database.list_folders())}

    def _library_workspaces(self, _: dict[str, Any], __: Any) -> dict[str, Any]:
        return {
            "workspaces": [
                {"name": workspace.name, "createdAt": workspace.created_at.isoformat()}
                for workspace in self._database.list_workspaces()
            ]
        }

    def _library_workspace_create(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        workspace = self._database.create_workspace(str(params["name"]))
        return {"name": workspace.name, "createdAt": workspace.created_at.isoformat()}

    def _library_workspace_add(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        self._database.add_to_workspace(str(params["workspace"]), Path(str(params["path"])))
        return {"ok": True}

    def _library_search_content(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        if self._database.content_index_empty():
            for record in self._database.list_documents(limit=1000):
                if not record.exists:
                    continue
                try:
                    pages = self._pdf.extract_text(record.path)
                    self._database.index_content(record.path, tuple((page.page_number, page.text) for page in pages))
                except PdfError:
                    continue
        return {"matches": list(self._database.search_content(str(params.get("query", "")), int(params.get("limit", 100))))}

    def _pdf_inspect(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        document = self._pdf.inspect(Path(str(params["path"])))
        return {
            "path": str(document.path),
            "pageCount": document.page_count,
            "fileSizeBytes": document.file_size_bytes,
            "title": document.title,
            "author": document.author,
            "encrypted": document.encrypted,
        }

    def _pdf_extract(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        pages = self._pdf.extract_text(Path(str(params["path"])))
        return {"pages": [{"pageNumber": page.page_number, "text": page.text} for page in pages]}

    def _pdf_edit(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        source = Path(str(params["inputPath"])).expanduser().resolve()
        output = Path(str(params["outputPath"])).expanduser().resolve()
        path = self._editor.edit(
            source,
            output,
            annotations=params.get("annotations", []),
            crop=params.get("crop"),
            text=params.get("text", []),
            image=params.get("images", []),
            header=params.get("header"),
            footer=params.get("footer"),
            watermark=params.get("watermark"),
        )
        return {"path": str(path), "originalPreserved": path != source}

    def _pdf_extract_pages(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        source = Path(str(params["inputPath"])).expanduser().resolve()
        output = Path(str(params["outputPath"])).expanduser().resolve()
        path = self._editor.extract(source, output, params.get("pages", []))
        return {"path": str(path), "pages": [int(page) for page in params["pages"]]}

    def _pdf_transform(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        source = Path(str(params["inputPath"])).expanduser().resolve()
        output = Path(str(params["outputPath"])).expanduser().resolve()
        path = self._pageops.transform(
            source,
            output,
            order=params.get("order"),
            rotate={int(key): int(value) for key, value in (params.get("rotate") or {}).items()},
            delete=params.get("delete", []),
            duplicate=params.get("duplicate", []),
            blank_after=params.get("blankAfter", []),
        )
        return {"path": str(path), "originalPreserved": path != source}

    def _pdf_merge(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        output = Path(str(params["outputPath"])).expanduser().resolve()
        path = self._pageops.merge((Path(str(item)) for item in params["inputPaths"]), output)
        return {"path": str(path)}

    def _pdf_split(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        outputs = self._pageops.split(
            Path(str(params["inputPath"])).expanduser().resolve(),
            Path(str(params["outputDirectory"])).expanduser().resolve(),
        )
        return {"paths": [str(path) for path in outputs]}

    def _pdf_compress(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = self._pageops.compress(
            Path(str(params["inputPath"])).expanduser().resolve(),
            Path(str(params["outputPath"])).expanduser().resolve(),
        )
        return {"path": str(path)}

    def _pdf_protect(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = self._security.protect(
            params["inputPath"],
            params["outputPath"],
            user_password=str(params["userPassword"]),
            owner_password=str(params.get("ownerPassword") or "") or None,
            permissions=tuple(str(item) for item in params.get("permissions", [])),
            use_128bit=bool(params.get("use128Bit", True)),
        )
        return {"path": str(path), "originalPreserved": True}

    def _pdf_remove_password(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = self._security.remove_password(
            params["inputPath"], params["outputPath"], password=str(params["password"])
        )
        return {"path": str(path), "originalPreserved": True}

    def _pdf_remove_metadata(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = self._security.remove_metadata(params["inputPath"], params["outputPath"])
        return {"path": str(path), "originalPreserved": True}

    def _pdf_sign(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        key_path = Path(str(params["privateKeyPath"])).expanduser().resolve()
        if not key_path.is_file():
            raise PdfSecurityError("Private signing key does not exist.")
        path = self._security.sign(
            params["inputPath"],
            params["signaturePath"],
            private_key_pem=key_path.read_bytes(),
            password=(str(params["keyPassword"]).encode() if params.get("keyPassword") else None),
        )
        return {"path": str(path), "detached": True}

    def _pdf_validate_signature(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        return {"valid": self._security.validate_signature(params["inputPath"], params["signaturePath"])}

    def _pdf_redact(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        input_path = Path(str(params["inputPath"])).expanduser().resolve()
        output_path = Path(str(params["outputPath"])).expanduser().resolve()
        terms = tuple(str(term) for term in params.get("terms", []))
        if terms:
            path = self._redaction.redact_terms(input_path, output_path, terms)
        else:
            requests = tuple(
                RedactionRequest(
                    page_number=int(item["pageNumber"]),
                    left=float(item["left"]),
                    bottom=float(item["bottom"]),
                    right=float(item["right"]),
                    top=float(item["top"]),
                )
                for item in params.get("regions", [])
            )
            path = self._redaction.redact(input_path, output_path, requests)
        return {"path": str(path), "verified": True, "originalPreserved": True}

    def _chat_ask(self, params: dict[str, Any], request_id: Any) -> dict[str, Any]:
        document_id = str(params["documentId"])
        question = str(params["question"]).strip()
        provider = params.get("provider") or {}
        consent_data = params.get("consent") or {}
        consent = Consent(
            provider_id=str(consent_data["providerId"]),
            document_id=document_id,
            scope=str(consent_data["scope"]),
            granted_at=datetime.fromisoformat(str(consent_data["grantedAt"])),
        )
        path = self._path_for_document(document_id)
        job = self._start_job(request_id, lambda token: self._run_chat(
            token, document_id, path, question, provider, consent
        ))
        return {"jobId": job.job_id}

    def _index_start(self, params: dict[str, Any], request_id: Any) -> dict[str, Any]:
        path = Path(str(params["path"])).expanduser().resolve()
        if not path.is_file():
            raise RpcFailure(-32010, "PDF file does not exist.", {"kind": "FileNotFound"})
        provider = params.get("provider") or {}
        job = self._start_job(request_id, lambda token: self._run_index(token, path, provider))
        return {"jobId": job.job_id}

    def _provider_test(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        provider = params.get("provider") or {}
        try:
            adapter = self._provider_adapter(provider)
            adapter.chat(
                [ChatMessage("user", "Reply with OK.")],
                model=str(provider.get("model", "gpt-4o-mini")),
                temperature=0,
                max_tokens=8,
            )
        except (OpenAIError, ProviderError, ValueError) as exc:
            raise RpcFailure(-32043, str(exc), {"kind": getattr(exc, "kind", "Provider")}) from exc
        return {"ok": True, "provider": getattr(adapter, "provider_id", provider.get("id", "openai"))}

    def _privacy_clear_cache(self, _: dict[str, Any], __: Any) -> dict[str, Any]:
        self._vectors.clear()
        return {"cleared": True}

    def _ai_tool_generate(self, params: dict[str, Any], request_id: Any) -> dict[str, Any]:
        operation = str(params["operation"])
        document_id = str(params.get("documentId", ""))
        provider = params.get("provider") or {}
        provider_id = str(provider.get("id", "openai")).lower()
        consent_data = params.get("consent") or {}
        consent = Consent(
            provider_id=str(consent_data["providerId"]),
            document_id=document_id,
            scope=str(consent_data["scope"]),
            granted_at=datetime.fromisoformat(str(consent_data["grantedAt"])),
        )
        require_consent(consent, provider_id=provider_id, document_id=document_id, scope="ai_tools")
        text = str(params.get("text", "")).strip()
        if not text:
            path = self._path_for_document(document_id)
            text = "\n\n".join(f"[page {page.page_number}]\n{page.text}" for page in self._pdf.extract_text(path))
        if len(text) > 400_000:
            raise RpcFailure(-32045, "The selected text is too large for one request.", {"kind": "ContextLength"})
        request = AiToolRequest(
            operation=operation,
            text=text,
            mode=str(params["mode"]) if params.get("mode") is not None else None,
            difficulty=str(params.get("difficulty", "medium")),
            language=str(params.get("language", "English")),
            tone=str(params.get("tone", "professional")),
            instruction=str(params.get("instruction", "")),
        )
        job = self._start_job(request_id, lambda token: self._run_ai_tool(token, request, provider))
        return {"jobId": job.job_id}

    def _run_ai_tool(
        self,
        token: CancellationToken,
        request: AiToolRequest,
        provider: dict[str, Any],
    ) -> dict[str, Any]:
        self._progress(token, "generating", 0.2)
        api_key = str(provider.get("apiKey", ""))
        if not api_key:
            raise RpcFailure(-32041, "A provider API key is required.", {"kind": "ProviderAuth"})
        adapter = self._provider_adapter(provider)
        result = self._ai_tools.generate(
            request,
            adapter,
            model=str(provider.get("model", "gpt-4o-mini")),
            temperature=float(provider.get("temperature", 0.2)),
            max_tokens=int(provider.get("maxTokens", 1200)),
        )
        token.raise_if_cancelled()
        self._progress(token, "complete", 1.0)
        return result.as_dict()

    def _ai_tool_export(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        title = str(params.get("title", "AI PDF Studio result"))
        content = str(params.get("content", ""))
        output = Path(str(params["outputPath"]))
        format_name = str(params.get("format", output.suffix.removeprefix(".")))
        path = export_result(title, content, output, format_name)
        return {"path": str(path), "format": format_name.lower()}

    def _run_index(self, token: CancellationToken, path: Path, provider: dict[str, Any]) -> dict[str, Any]:
        self._progress(token, "extracting", 0.1)
        pages = self._pdf.extract_text(path)
        chunker = SemanticChunker()
        chunks = chunker.chunk(pages)
        token.raise_if_cancelled()
        self._progress(token, "embedding", 0.45)
        embeddings: tuple[tuple[float, ...], ...] = ()
        api_key = str(provider.get("apiKey", ""))
        if api_key and str(provider.get("id", "openai")) == "openai":
            embeddings = OpenAIClient(api_key).embeddings(
                [chunk.text for chunk in chunks],
                model=str(provider.get("embeddingModel", "text-embedding-3-small")),
            )
        self._vectors.replace(str(path), chunks, embeddings)
        self._progress(token, "complete", 1.0)
        return {"path": str(path), "chunks": len(chunks), "vectors": len(embeddings)}

    def _run_chat(
        self,
        token: CancellationToken,
        document_id: str,
        path: Path,
        question: str,
        provider: dict[str, Any],
        consent: Consent,
    ) -> dict[str, Any]:
        self._progress(token, "extracting", 0.15)
        pages = self._pdf.extract_text(path)
        stored = self._vectors.chunks(document_id)
        retriever = self._retrievers.setdefault(document_id, LocalRetriever())
        if stored:
            retriever.index(
                document_id,
                [
                    type("_Page", (), {"page_number": int(item["pageNumber"]), "text": str(item["text"])})()
                    for item in stored
                ],
            )
        else:
            semantic = SemanticChunker().chunk(pages)
            retriever.index(
                document_id,
                [
                    type("_Page", (), {"page_number": chunk.page_number, "text": chunk.text})()
                    for chunk in semantic
                ],
            )
        token.raise_if_cancelled()
        self._progress(token, "retrieving", 0.45)
        api_key = str(provider.get("apiKey", ""))
        if not api_key:
            raise RpcFailure(-32041, "A provider API key is required.", {"kind": "ProviderAuth"})
        adapter = self._provider_adapter(provider)
        service = PdfChatService(retriever, adapter)
        requested_tokens = int(provider.get("maxTokens", 1200))
        usage_limit = int(provider.get("usageLimit", 0))
        if usage_limit > 0:
            requested_tokens = min(requested_tokens, usage_limit)
        if requested_tokens < 1:
            raise RpcFailure(-32044, "The configured usage limit is too low.", {"kind": "UsageLimit"})
        stream, retrieved = service.answer_stream(
            question,
            document_id=document_id,
            consent=consent,
            model=str(provider.get("model", "gpt-4o-mini")),
            provider_id=str(provider.get("id", "openai")),
            temperature=float(provider.get("temperature", 0.2)),
            max_tokens=requested_tokens,
        )
        pieces: list[str] = []
        for piece in stream:
            token.raise_if_cancelled()
            pieces.append(piece)
            self._notify("chat.delta", {"jobId": token.job_id, "text": piece})
        text = "".join(pieces)
        citations = service.citations_for(text, retrieved)
        self._progress(token, "complete", 1.0)
        return {
            "text": text,
            "citations": [
                {"sourceId": citation.source_id, "pageNumber": citation.page_number, "text": citation.text}
                for citation in citations
            ],
        }

    @staticmethod
    def _provider_adapter(provider: dict[str, Any]) -> Any:
        provider_id = str(provider.get("id", "openai")).lower()
        api_key = str(provider.get("apiKey", ""))
        if provider_id == "anthropic":
            return AnthropicClient(api_key)
        if provider_id == "openai":
            return OpenAIClient(api_key)
        raise RpcFailure(-32042, "Unsupported provider.", {"kind": "Provider"})

    def _start_job(self, request_id: Any, operation: Callable[[CancellationToken], dict[str, Any]]) -> Job:
        job_id = str(uuid.uuid4())
        job = Job(job_id, request_id, CancellationToken(job_id))
        with self._jobs_lock:
            self._jobs[job.job_id] = job

        def run() -> None:
            try:
                job.result = operation(job.token)
                self._notify("job.finished", {"jobId": job.job_id, "ok": True, "result": job.result})
            except RpcFailure as exc:
                job.error = exc
                self._notify("job.finished", {"jobId": job.job_id, "ok": False, "error": self._error_data(exc)})
            except AiToolError as exc:
                job.error = RpcFailure(-32602, str(exc), {"kind": "InvalidToolRequest"})
                self._notify("job.finished", {"jobId": job.job_id, "ok": False, "error": self._error_data(job.error)})
            except (OpenAIError, ProviderError, ValueError) as exc:
                job.error = RpcFailure(-32043, str(exc), {"kind": getattr(exc, "kind", "Provider")})
                self._notify("job.finished", {"jobId": job.job_id, "ok": False, "error": self._error_data(job.error)})
            except Exception as exc:
                job.error = RpcFailure(-32603, "Job failed.", {"kind": type(exc).__name__})
                self._notify("job.finished", {"jobId": job.job_id, "ok": False, "error": self._error_data(job.error)})
                print(traceback.format_exc(), file=sys.stderr, flush=True)
            finally:
                job.done.set()

        threading.Thread(target=run, daemon=True).start()
        return job

    def _progress(self, token: CancellationToken, stage: str, fraction: float | None) -> None:
        token.raise_if_cancelled()
        self._notify(
            "job.progress",
            {"jobId": token.job_id, "stage": stage, "fraction": fraction},
        )

    def _path_for_document(self, document_id: str) -> Path:
        for record in self._database.list_recent(1000):
            if self._document_id(record.path) == document_id or str(record.path) == document_id:
                return record.path
        path = Path(document_id)
        if path.is_file():
            return path
        raise RpcFailure(-32010, "Document was not found.", {"kind": "FileNotFound"})

    @staticmethod
    def _document_id(path: Path) -> str:
        return str(path)

    def _document_json(self, record: Any) -> dict[str, Any]:
        page_count = None
        if record.path.is_file():
            try:
                page_count = self._pdf.inspect(record.path).page_count
            except PdfError:
                page_count = None
        return {
            "documentId": self._document_id(record.path),
            "path": str(record.path),
            "title": record.title or record.path.name,
            "lastPage": record.last_page,
            "favorite": record.favorite,
            "updatedAt": record.updated_at.isoformat(),
            "pageCount": page_count,
            "status": "available" if record.exists else "missing",
            "note": self._database.note(record.path),
            "tags": list(self._database.tags(record.path)),
        }

    def _notify(self, method: str, params: dict[str, Any]) -> None:
        self._write({"jsonrpc": "2.0", "method": method, "params": params}, sys.stdout)

    def _write(self, payload: dict[str, Any], stream: Any) -> None:
        with self._output_lock:
            stream.write(json.dumps(payload, separators=(",", ":")) + "\n")
            stream.flush()

    @staticmethod
    def _error_data(error: RpcFailure) -> dict[str, Any]:
        return {"code": error.code, "message": str(error), "data": error.data}

    @classmethod
    def _error(cls, request_id: Any, code: int, message: str, data: dict[str, Any] | None = None) -> dict[str, Any]:
        return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message, "data": data or {}}}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--token", default=os.environ.get("AIPS_SIDECAR_TOKEN", ""))
    parser.add_argument("--database", type=Path)
    args = parser.parse_args()
    SidecarServer(args.token, args.database).serve()


if __name__ == "__main__":
    main()
