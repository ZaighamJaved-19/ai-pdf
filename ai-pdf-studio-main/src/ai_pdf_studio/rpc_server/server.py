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
from ai_pdf_studio.ai_providers import OpenAIClient
from ai_pdf_studio.library import DocumentRepository
from ai_pdf_studio.pdf import PdfError, PdfService
from ai_pdf_studio.rag import LocalRetriever
from ai_pdf_studio.security import Consent

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
        self._retrievers: dict[str, LocalRetriever] = {}
        self._methods: dict[str, Callable[[dict[str, Any], Any], Any]] = {
            "system.handshake": self._handshake,
            "system.health": self._health,
            "system.shutdown": self._shutdown,
            "job.cancel": self._cancel,
            "job.result": self._job_result,
            "library.list": self._library_list,
            "library.upsert": self._library_upsert,
            "pdf.inspect": self._pdf_inspect,
            "pdf.extractText": self._pdf_extract,
            "chat.ask": self._chat_ask,
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
        documents = self._database.list_recent(int(params.get("limit", 100)))
        if scope == "favorites":
            documents = tuple(document for document in documents if document.favorite)
        query = str(params.get("query", "")).lower().strip()
        if query:
            documents = tuple(
                document for document in documents
                if query in (document.title or document.path.name).lower()
                or query in str(document.path).lower()
            )
        return {"documents": [self._document_json(document) for document in documents]}

    def _library_upsert(self, params: dict[str, Any], _: Any) -> dict[str, Any]:
        path = Path(str(params["path"])).expanduser().resolve()
        record = self._database.upsert(
            path,
            title=params.get("title"),
            last_page=int(params.get("lastPage", 1)),
            favorite=bool(params.get("favorite", False)),
        )
        return self._document_json(record)

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
        retriever = self._retrievers.setdefault(document_id, LocalRetriever())
        retriever.index(document_id, pages)
        token.raise_if_cancelled()
        self._progress(token, "retrieving", 0.45)
        api_key = str(provider.get("apiKey", ""))
        if not api_key:
            raise RpcFailure(-32041, "OpenAI API key is required.", {"kind": "ProviderAuth"})
        service = PdfChatService(retriever, OpenAIClient(api_key))
        answer = service.answer(question, document_id=document_id, consent=consent)
        self._progress(token, "complete", 1.0)
        return {
            "text": answer.text,
            "citations": [
                {"sourceId": citation.source_id, "pageNumber": citation.page_number, "text": citation.text}
                for citation in answer.citations
            ],
        }

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
