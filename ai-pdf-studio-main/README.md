# AI PDF Studio

AI PDF Studio is a privacy-first Windows PDF productivity workspace. Traditional PDF operations are designed to run locally; AI features are provider-backed and require explicit configuration and consent.

## Current status

The repository currently contains a tested Python core that can back the planned Windows UI:

- Typed PDF document models.
- Local PDF inspection and page-aware text extraction using `pypdf`.
- SQLite document-library repository for source references and reading position.
- Page-aware local retrieval and hybrid lexical/vector retrieval.
- OpenAI chat and embeddings-compatible HTTP integration, including SSE chat streaming.
- Explicit consent enforcement before document text is sent to OpenAI.
- Citation-aware PDF chat responses whose source pages are resolved from retrieved chunks.
- Local page editing operations: merge, split, compress, reorder, rotate, delete, duplicate,
  and blank-page insertion.
- True raster redaction, Tesseract OCR, LibreOffice conversion, and text comparison services
  with explicit errors when their optional engines are unavailable.
- SQLite-backed tags and workspaces, AES-GCM field encryption, opt-in telemetry, signed
  entitlement verification, and settings/onboarding models.
- An MSIX manifest template and Windows packaging checklist.
- Architecture and delivery documentation.

The Flutter Windows UI is not included in this checkout yet. These services expose the behavior
that a Flutter sidecar client can call without coupling UI code to PDF parsing or provider APIs.

OCR requires Tesseract, office conversion requires LibreOffice, and redaction requires the
`pdftoppm` command plus Pillow. The services fail clearly when an optional engine is missing.

## Development

Requirements: Python 3.11+.

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
python -m pytest
```

The package is structured so a Windows desktop frontend can call the local application services without coupling UI code to PDF parsing or persistence.

## Privacy

No PDF content is uploaded by local operations. The OpenAI adapter requires a caller-supplied
`Consent` object for document chat; API keys are held only by the client instance and are never
written to logs or the document library. Never commit an API key to source control.

See [`docs/architecture.md`](docs/architecture.md) for the planned module boundaries, security model, and release phases.
