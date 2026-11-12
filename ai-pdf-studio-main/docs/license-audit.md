# Dependency and license audit

**Read this first.** I compiled this from my own knowledge (cutoff mid-2026) with no live registry access. Licenses and maintenance status change; **re-verify every row against the package's current license file and release history before each Store submission**, and generate a machine-readable inventory then (`pip-licenses`, `dart pub deps`, plus a manual review of bundled binaries). This is an engineering assessment, not legal advice. Have a lawyer review before commercial release if revenue matters.

Legend: ✅ adopt, 🟡 adopt with conditions, ❌ avoid, ❓ owner decision.

## 1. Headline findings

1. **PyMuPDF/MuPDF is AGPL-3.0** (or paid commercial license from Artifex). Shipping it in a closed-source Store app without a commercial license is not compatible. ❌ by default. The plan below avoids it entirely.
2. **`pdf2docx` is GPL-3.0 and depends on PyMuPDF.** ❌. PDF to Word needs another route.
3. **Ghostscript is AGPL-3.0.** ❌ for bundling. OCRmyPDF can use it optionally; we do not depend on OCRmyPDF.
4. **Syncfusion Community License** is only for companies under a revenue cap and a small developer count, requires registration, and ties you to their terms. 🟡 Not needed: pdfrx covers viewing. Do not adopt.
5. **PaddleOCR** is Apache-2.0 but pulls in PaddlePaddle (hundreds of MB), which is unfriendly to Store size and to a Python 3.13 bundle. 🟡 Optional download-on-demand only, after Tesseract is solid.
6. Everything else in the proposed stack is permissive (MIT/BSD/Apache) or weak-copyleft (MPL-2.0, LGPL) with manageable obligations.

## 2. Flutter / Dart side

| Package | License | Role | Maintenance / notes | Verdict |
| --- | --- | --- | --- | --- |
| Flutter SDK + Dart | BSD-3 | Framework | Google, very active; Windows desktop stable | ✅ |
| `pdfrx` | MIT | PDF viewer on PDFium | Active, desktop supported. Downloads PDFium binaries at build time (needs network on the build machine); PDFium is BSD-3/Apache-2.0. Confirm text selection, search and printing APIs in Step 6 before committing the UI to them | ✅ (evaluate in Step 5/6) |
| PDFium (binary via `pdfrx`/`pdfium-binaries`) | BSD-3 / Apache-2.0 | Rendering engine | Chromium-maintained | ✅ |
| `flutter_riverpod`, `riverpod_annotation` | MIT | State | Active | ✅ |
| `freezed`, `json_serializable`, `build_runner` | MIT / BSD-3 | Typed models, codegen | Active | ✅ |
| `window_manager` | MIT | Window control, min size, full-screen | Active | ✅ |
| `desktop_drop` | MIT | Drag and drop | Windows supported; check Store-package behavior | ✅ |
| `file_selector` (flutter.dev) | BSD-3 | Open/save dialogs | First-party | ✅ |
| `flutter_secure_storage` | BSD-3 | Windows Credential Manager | Active; confirm it uses Credential Manager on Windows (it does, via wincred) | ✅ |
| `msix` | MIT | MSIX packaging | Active; handles identity, capabilities | ✅ |
| `flutter_markdown` / `markdown_widget` | BSD-3 / MIT | Chat Markdown | `flutter_markdown` was discontinued by Flutter team in 2025; evaluate maintained forks | 🟡 |
| `flutter_math_fork` | Apache-2.0 / MIT | Math rendering | Community fork, slower updates | 🟡 |
| `flutter_highlight` / `re_highlight` | MIT | Code blocks | Fine | ✅ |
| `path_provider`, `shared_preferences`, `url_launcher` | BSD-3 | Basics | First-party | ✅ |
| Native Store-licensing plugin (we write it) | ours | `Windows.Services.Store` via C++/WinRT or `win32`/FFI | Cannot be tested off Windows | ❓ owner testing |
| Syncfusion Flutter PDF/PDF Viewer | Commercial / community-limited | — | See headline 4 | ❌ |

## 3. Python sidecar

| Package | License | Role | Notes | Verdict |
| --- | --- | --- | --- | --- |
| `pypdf` (already used) | BSD-3 | Read, merge, split, rotate, metadata, basic encrypt | Pure Python, active. Weaker on malformed files; text extraction quality is moderate | ✅ |
| `pikepdf` (+ qpdf) | MPL-2.0 (qpdf: Apache-2.0) | Robust structural edits, AES-256 encryption, linearization, object streams, content stream access | Binary wheels for Windows. MPL: modifications to MPL files must be shared; using as a library is fine | ✅ |
| `pypdfium2` | Apache-2.0 or BSD-3 (PDFium itself BSD-3) | Rasterization for OCR, redaction, visual diff, thumbnails server-side | Active, wheels for Windows | ✅ |
| `pdfminer.six` | MIT | Layout-aware text and table geometry | Slow but good for comparison/tables | ✅ |
| `pdfplumber` | MIT | Table extraction | Built on pdfminer | 🟡 optional |
| `pyHanko` | MIT | Digital signatures create/validate | Active; heavy on `cryptography`; validate long-term-validation features honestly | ✅ |
| `cryptography` | Apache-2.0 / BSD | AES-GCM, signatures | Active | ✅ |
| `sqlcipher3` (or `sqlcipher3-binary`) | zlib-style (bindings); SQLCipher core BSD-style | Encrypted DB | Windows wheel availability must be verified (ADR-6) | 🟡 gate |
| `pydantic` v2 | MIT | Typed models, contract validation | Active | ✅ |
| `httpx` | BSD-3 | HTTPS provider calls, timeouts, streaming | Active | ✅ |
| `openai` SDK | Apache-2.0 | Optional; adapter can use raw `httpx` instead | Prefer own thin adapter to control size limits, HTTPS enforcement, error mapping | 🟡 optional |
| `anthropic` SDK | MIT | Second provider | Same: thin adapter via `httpx` preferred | 🟡 optional |
| `tiktoken` | MIT | Token counting | Needs encoding files; first run may download. Use a heuristic fallback offline | 🟡 |
| `numpy` | BSD-3 | Vector math | Active; adds ~30 MB | ✅ |
| `onnxruntime` | MIT | Local embeddings | ~10-30 MB CPU wheel | ✅ |
| `fastembed` | Apache-2.0 | ONNX embedding wrapper | Downloads model on first use; model licenses must be checked individually (e.g. BGE-small is MIT; verify the exact checkpoint) | 🟡 |
| `rank_bm25` or own BM25 | Apache-2.0 | Keyword leg | Own ~40 lines is simpler and removes a dependency | ✅ own |
| `sentence-transformers` / `torch` | Apache-2.0 / BSD | — | Too large for Store bundle | ❌ |
| `Pillow` | HPND (permissive) | Image ops | Active | ✅ |
| `img2pdf` | LGPL-3.0 | Lossless image to PDF | LGPL as a dynamically-used Python lib is workable but adds obligations. Alternative: Pillow + `pikepdf` | 🟡 prefer alternative |
| `python-docx` | MIT | DOCX read/write (exports) | Active | ✅ |
| `openpyxl` | MIT | XLSX | Active | ✅ |
| `python-pptx` | MIT | PPTX | Active | ✅ |
| `reportlab` | BSD-3 (open-source edition) | Create PDFs (summaries, reports, watermarks) | Active | ✅ |
| `beautifulsoup4`, `lxml` | MIT, BSD-3 | HTML parsing | Active | ✅ |
| `markdown-it-py` | MIT | Markdown to HTML for exports | Active | ✅ |
| `difflib` (stdlib) | PSF | Text diff | — | ✅ |
| `keyring` | MIT | Not used (Dart side owns keys) | — | n/a |
| `PyInstaller` | GPL-2.0 with bootloader exception | Freezing the sidecar | The exception permits commercial distribution of frozen apps; confirm current terms | ✅ |
| `Nuitka` | Apache-2.0 | Alternative freezer | Smaller/faster, slower builds | 🟡 alternative |
| `pytest`, `ruff`, `mypy`, `hypothesis` | MIT / MPL | Dev only, not shipped | — | ✅ |

## 4. OCR and conversion engines

| Engine | License | Role | Concerns | Verdict |
| --- | --- | --- | --- | --- |
| **Tesseract 5** | Apache-2.0 | OCR | Needs bundled `tesseract.exe` + DLLs (Windows build, e.g. UB-Mannheim distribution; check its bundled-lib licenses) and `tessdata` language files (Apache-2.0). Size per language ~10-40 MB (`tessdata_fast`). Language packs for English, German, Spanish, French, Portuguese, Arabic, Urdu should be optional downloads. Orientation via OSD (`osd.traineddata`) | ✅ |
| `pytesseract` | Apache-2.0 | Wrapper | Thin; can call the executable directly with `subprocess` for better cancellation | ✅ or direct |
| PaddleOCR | Apache-2.0 | Higher-accuracy OCR | Size and runtime weight (see headline 5) | 🟡 later, optional |
| OCRmyPDF | MPL-2.0 | Searchable-PDF pipeline | Depends on Ghostscript (AGPL) for some paths and many CLI tools. We implement the simple, reliable pipeline ourselves: rasterize (pypdfium2) → Tesseract hOCR/PDF output → merge text layer with `pikepdf`/`pypdf` | ❌ (build our own) |
| **LibreOffice** (headless) | MPL-2.0 (+ bundled third-party components) | Office/HTML/TXT to PDF; limited PDF import | ~300-400 MB installed. Bundling into MSIX is heavy; detect an existing install or offer an optional component. Fidelity for DOCX/XLSX/PPTX to PDF is good, not perfect. Run headless in an isolated profile dir, macros disabled | 🟡 ❓ |
| Microsoft Word/Excel/PowerPoint COM | Proprietary, user's own license | Highest-fidelity Office to PDF **only if installed** | Cannot assume it; automation from a Store/full-trust app is possible but fragile; honest "only when Office is installed" | 🟡 optional |
| `docx2pdf` | MIT | Wrapper over Word COM | Requires Word | 🟡 optional |
| `pdf2docx` | **GPL-3.0** | PDF to Word | See headline 2 | ❌ |
| PyMuPDF-based converters | **AGPL-3.0** | — | See headline 1 | ❌ |
| `pdfplumber`/`pdfminer.six` + `python-docx`/`openpyxl`/`python-pptx` (own converters) | MIT | PDF to Word/Excel/PPT, built by us | Honest scope: **text and simple table reconstruction, not layout-faithful**. Quality warnings mandatory for scans, multi-column pages, complex tables | ✅ with disclosed limits |
| PDFium rendering | BSD-3 / Apache | PDF to JPG/PNG | Excellent | ✅ |
| Commercial engines (Aspose, Spire, Apryse, ABBYY) | Commercial | High-fidelity conversion | Per-developer/royalty licensing, large cost | ❓ only if you want to pay for fidelity |

### Honest conversion position (required by the brief, section 12)

- **To PDF:** Images, TXT, HTML → fully local and reliable (Pillow/`pikepdf`/`reportlab`, HTML via LibreOffice or a limited internal renderer; to be decided in Step 3 by test results). Word/Excel/PowerPoint → **requires LibreOffice or Microsoft Office on the machine**; there is no reliable pure-Python route. The app will detect which exists and show a clear "install/enable" state, rather than a button that fails.
- **From PDF:** JPG/PNG/TXT/HTML → reliable. Word/Excel/PowerPoint → best-effort reconstruction with visible quality warnings. No open-source, permissively licensed engine matches paid ones here, and I will not pretend otherwise.

## 5. Owner decisions needed (blocking later steps, not Step 2)

1. **Office to PDF route:** (a) optional LibreOffice component, (b) Word COM when present, (c) both (recommended), (d) paid engine.
2. **PyMuPDF commercial license?** Not needed under this design; mention only if you later want higher-fidelity redaction/conversion.
3. **Open-source or closed-source?** AGPL avoidance assumes closed-source Store distribution.
4. **Bundle size tolerance** for LibreOffice and extra OCR languages.

## 6. Release-time checklist

- Generate third-party notices file (`THIRD_PARTY_NOTICES.txt`) from both ecosystems and bundle it in the app (About screen).
- Confirm no AGPL/GPL package is in the final bundle: scan the frozen sidecar's `*.dist-info` and the Flutter plugin list.
- Verify MPL/LGPL obligations (source availability for modified MPL files; dynamic linking for LGPL).
- Confirm ONNX model and tessdata licenses individually.
