# AI PDF Studio architecture (v2, Step 1 proposal)

Status: **proposal for owner review**. Supersedes the v1 text, which left the UI toolkit open ("Flutter or Qt"). That decision is now made (ADR-1).

Related documents:
- [`license-audit.md`](license-audit.md): dependency and license audit
- [`project-tree.md`](project-tree.md): target repository layout
- [`api/openrpc.json`](api/openrpc.json): versioned sidecar API contract (v1)
- [`owner-tasks.md`](owner-tasks.md): things only the owner can do

## 1. Shape of the system

```
+--------------------------- MSIX package (full trust) ---------------------------+
|                                                                                  |
|  Flutter Windows app (UI, Riverpod)             Python sidecar (heavy work)      |
|  - reader/editor via PDFium (pdfrx)    stdio    - OCR, conversion, redaction     |
|  - simple page ops in Dart/PDFium  <--JSON-RPC-> - compare, RAG, embeddings      |
|  - Credential Manager (keys)                    - AI provider adapters           |
|  - Store licensing (native)                     - SQLite/SQLCipher library       |
|                                                                                  |
+----------------------------------------------------------------------------------+
         user PDFs stay at original paths; app data in %LOCALAPPDATA% (package-virtualized)
```

The UI never parses PDFs for heavy jobs and never talks to AI providers directly. The sidecar never renders UI. All cross-boundary traffic goes through one versioned contract.

## 2. Decisions (ADRs)

**ADR-1: Flutter for UI, Python for the sidecar.** Matches the brief. Python keeps the existing tested core and has the best OCR, conversion and NLP ecosystem. Cost: bundle size (~80-150 MB Python runtime + deps + Tesseract) and a process boundary. Accepted.

**ADR-2: Transport = JSON-RPC 2.0 over the sidecar's stdin/stdout, newline-delimited UTF-8 JSON.**
- No listening socket: nothing for other local processes to connect to, no token to leak, no firewall prompt, no port clashes. This is stronger than the "localhost + token" option offered in the brief, so I chose it.
- stdout carries protocol messages only. stderr carries logs (scrubbed of document text and keys).
- Streaming (chat tokens, progress) uses JSON-RPC notifications correlated by `jobId`.
- Large binary payloads (page images, converted files) are never inlined; they are written to a per-job temp directory and referenced by path.
- Fallback: if stdio proves problematic on Windows (pipe buffering, encoding), switch the transport to a named pipe with an ACL. The contract is transport-independent.

**ADR-3: Contract = OpenRPC 1.3** (`docs/api/openrpc.json`), the JSON-RPC equivalent of OpenAPI. Python side: pydantic v2 models are validated against it in CI (a test fails if code and contract drift). Dart side: a small generator script (`tools/gen_dart_client.py`, built in Step 5) emits typed models and a client. OpenAPI/Swagger generators do not fit a stdio JSON-RPC protocol, so a purpose-built generator is the honest choice. Contract versioning: semver in `info.version`, checked by a `system.handshake` call at startup; a mismatch is a hard, user-visible error.

**ADR-4: Division of PDF work.**
| Operation | Where | Why |
| --- | --- | --- |
| Render, thumbnails, text selection, in-document search, print | Dart + PDFium (pdfrx) | Needs UI-thread proximity and caching; PDFium is the right engine |
| Rotate, delete, reorder, duplicate, extract, insert blank, merge, split | Python (`pikepdf`/`pypdf`) first; Dart/PDFium only if latency demands | Must be testable in this repo's Linux CI; PDFium page-import in Dart is possible later as an optimization |
| Annotations (highlight, notes, ink, shapes) | Python writes standard PDF annotations; Dart renders the live overlay | Standard annotations interoperate with other readers |
| Redaction, OCR, conversion, compare, encryption, signatures | Python | Heavy, security-sensitive, needs verification |

I deviate from "Dart where practical" for page operations on purpose: anything done in Python can be tested here, anything done in Dart cannot (no Flutter in this environment). Move them to Dart later only with a measured reason.

**ADR-5: True redaction without PyMuPDF.** PyMuPDF is AGPL-3.0 and would force either open-sourcing the app or buying a commercial license. Plan: two modes, both verified.
1. *Rasterize mode (default, guaranteed):* redacted pages are rendered with PDFium (`pypdfium2`), the redaction rectangles are painted into the bitmap, and the page is rebuilt as an image. OCR re-adds an invisible text layer for the unredacted areas when requested. Underlying content is physically gone.
2. *Content-stream mode (later, best effort):* rewrite text operators intersecting the rectangles with `pikepdf`, drop intersecting images and annotations. Only enabled for pages where verification passes.
In both modes the job ends with a verification step: re-extract text under and around each rectangle, and fail the job if any redacted string survives. Metadata, XMP, attachments, bookmarks and annotations are scrubbed by default.

**ADR-6: Local database = SQLite + SQLCipher** via `sqlcipher3` wheels, with the key held in Windows Credential Manager (DPAPI-protected). Alternative evaluated: SQLite + field-level encryption of notes and chat text only. Decision gate: confirm a maintained Windows wheel exists for the pinned Python version during Step 2. If not, fall back to field-level encryption (`cryptography`, AES-GCM) and document the weaker guarantee (paths and titles are not encrypted). Schema changes go through numbered migrations from day one; the existing `documents` table becomes migration 0001.

**ADR-7: Retrieval = hybrid.** Keep the existing `LocalRetriever` as the keyword leg and extend it: BM25 instead of raw term counts, page-aware section chunking, a vector leg with a local ONNX embedding model (`fastembed`/`onnxruntime`, Apache-2.0, no PyTorch), reciprocal rank fusion, optional cross-encoder rerank. Vector store: SQLite tables with float32 blobs plus brute-force cosine in numpy (adequate to roughly 100k chunks per document set, no extra native dependency). Per-document isolation stays a hard filter applied before scoring, never after.
Embedding provider choice: local by default (fully offline indexing). Remote embeddings are opt-in and go through the same consent dialog as chat.

**ADR-8: Citation verification.** The model is asked to answer in a structured form with `[p:<chunk_id>]` markers. After generation the sidecar parses every citation and drops or flags any whose chunk ID was not in the retrieved set. If retrieval confidence is below a threshold, or no valid citations remain for a factual answer, the response is replaced by the fixed "the document does not contain this" result. Page numbers shown to the user are always looked up from the chunk record, never taken from model text.

**ADR-9: Secrets and consent.**
- API keys live only in Windows Credential Manager, written by the Flutter side (`flutter_secure_storage`) and passed to the sidecar per request in memory (never persisted, never logged; log scrubber tested). The sidecar has no code path that writes a key to disk.
- Any RPC that would send document content to a provider requires `consent` in its params: `{providerId, documentId, scope, grantedAt}` produced by the UI dialog. The sidecar rejects the call with error `-32041 ConsentRequired` if it is absent or does not match the provider and document. The UI labels every operation offline/online from the contract's `x-network` tag.
- HTTPS only, enforced in the adapter; 30 s default timeouts; request size cap; no redirects to non-HTTPS.

**ADR-10: Licensing.** Entitlements are determined by Microsoft Store license info (`Windows.Services.Store`) read by a small native plugin on the Flutter side, optionally cross-checked by a backend. The sidecar enforces *usage metering* (AI credits, OCR pages) but receives the entitlement as a signed token, not a flag: Flutter obtains a short-lived signed entitlement from the (owner-hosted) licensing backend or Store receipt validation, and the sidecar verifies the signature against an embedded public key. Nothing is "premium by local flag". An honest limit: a determined user can patch a locally shipped app, so the signed-token design raises the bar and protects the server-side AI credits; it cannot make offline Pro features unpatchable. Free mode must work with no backend at all.

**ADR-11: Malicious PDF hardening.** Every sidecar job that opens an untrusted PDF runs with: a file-size cap, a page cap for heavy operations, a wall-clock timeout, a memory limit (Windows Job Object applied by Flutter when spawning worker processes), and a fresh per-job temp directory removed in a `finally`. Heavy parsers (OCR, conversion, redaction) run in short-lived *worker subprocesses* spawned by the sidecar, so a crash or hang kills the worker, not the sidecar. Office conversion never executes macros.

## 3. Sidecar lifecycle

1. Flutter locates the bundled `sidecar/aips-sidecar.exe` (PyInstaller one-folder build) and spawns it with `Process.start`, stdio piped.
2. Handshake: `system.handshake` returns `{contractVersion, sidecarVersion, capabilities}`. `capabilities` lists what is actually available (e.g. Tesseract language packs present, LibreOffice found). The UI renders only available features.
3. Health: `system.health` every 5 s; two misses trigger a kill and restart with exponential backoff (max 3 tries), then a visible error with a Retry button. In-flight jobs are reported failed, never silently dropped.
4. Shutdown: `system.shutdown` with a 3 s grace period, then a forced kill. The sidecar also exits on stdin EOF so it cannot outlive the app. Temp directories are swept on next start.
5. Cancellation: `job.cancel {jobId}`; every long method is cancellable and emits `job.progress` notifications (`{jobId, fraction|null, stage}`); `fraction` is `null` when the real progress is unknown (never a fake bar).

## 4. Python modules (target)

`pdf`, `ocr`, `conversion`, `redaction`, `compare`, `rag`, `embeddings`, `ai_providers`, `library`, `security`, `licensing`, `telemetry`, `rpc_server`, plus a thin `jobs` package (job registry, cancellation tokens, temp-dir management) used by all of them.

Refactor of the existing code (no rewrite):
- `pdf.PdfService` keeps its API; add password-aware `open`, page operations, annotation writers. The `PdfError` type gains an error `code` for RPC mapping.
- `library.DocumentRepository`: connection moves behind a `Database` class that runs migrations; the table gains folders/tags/notes/workspaces/history in later migrations. Current public methods remain.
- `rag.LocalRetriever`: stays as the lexical leg behind a `Retriever` protocol; the in-memory chunk list gets a persistent store so indexing is incremental and survives restarts. Known limitation to fix: `search` currently scans all chunks of all documents and filters afterwards; it will index by `document_id`.

## 5. Flutter modules (target)

`app_core`, `design_system`, `shell`, `reader`, `editor`, `tools`, `ai_chat`, `library`, `settings`, `subscriptions`, `onboarding`, `sidecar_client`. Riverpod providers per feature; repositories wrap the generated client; no business logic in widgets; files kept small. Details in [`project-tree.md`](project-tree.md).

## 6. Offline/online labelling

Each RPC method in the contract carries `x-network: none | optional | required`. The UI derives its offline/online badge from this tag rather than hard-coding it per screen, so a label cannot disagree with behavior.

## 7. Known risks (stated up front)

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Flutter code cannot be compiled or run in my environment | UI bugs only found when you run it | Strict step-by-step handoff; you paste back `flutter analyze/test` output |
| High-fidelity PDF to Word/Excel/PPT without AGPL/GPL libraries | Weak conversion quality | See audit section 4; ship honest quality warnings; consider a paid engine only if you choose |
| Office to PDF on machines without Office | No free, reliable embedded route | Optional LibreOffice (MPL) install detected at runtime, or bundled; or Word COM when Office exists. Decision needed from you |
| SQLCipher wheel availability on Windows | Weaker encryption fallback | Gate in Step 2 |
| MSIX size (Python + Tesseract + ONNX model + LibreOffice) | Slow download, Store friction | Optional components, model download on first use with a visible label |
| Store licensing needs a native Windows plugin | Cannot be tested outside Windows | Owner task, code + guide provided |

## 8. Delivery phases

Unchanged from the brief's order (section 19 of the master prompt): Step 1 (this document) then sidecar core, utilities/redaction/OCR/conversion, AI/RAG, Flutter scaffold, reader/library/settings, chat/tools/editing/comparison, licensing/privacy/telemetry, performance/docs/MSIX. Each step ships only behavior with passing tests and real error states.
