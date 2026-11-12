# AI PDF Studio Flutter app

This directory contains the professional Flutter workspace UI. Documents, reading
positions, favorites, PDF inspection, and AI chat are backed by the authenticated
JSON-RPC sidecar.

## Run on Windows

Install Flutter stable and Visual Studio with **Desktop development with C++**, then:

```powershell
cd app
$env:PYTHONPATH = "$pwd\..\src"
flutter create --platforms=windows .
flutter pub get
flutter run -d windows
```

The generated Windows runner is machine-specific and is not committed here. The
OpenAI API key field is held for the current app session and passed to the Python
sidecar only for a consented request.

## Sidecar

From the repository root, build the bundled Python sidecar before running the
release app:

```powershell
.\tools\build_sidecar.ps1
```

The app starts `app\sidecar\aips-sidecar.exe` when `AIPS_SIDECAR_PATH` points to
it. For development, it starts `python -m ai_pdf_studio.rpc_server`; install the
Python package and run Flutter from an environment where that module is available.
The process receives a per-launch authentication token, is health-checked every
five seconds, and is restarted after an unexpected exit or failed health check.

## Build

```powershell
flutter analyze
flutter test
flutter build windows --release
```
