# AI PDF Studio Flutter app

This directory contains the professional Flutter workspace UI. It is intentionally
dependency-light and currently uses an in-memory state store so the screens can be
reviewed before wiring the JSON-RPC sidecar.

## Run on Windows

Install Flutter stable and Visual Studio with **Desktop development with C++**, then:

```powershell
cd app
flutter create --platforms=windows .
flutter pub get
flutter run -d windows
```

The generated Windows runner is machine-specific and is not committed here. The
OpenAI API key field is a local UI setting; production wiring should store it in
Windows Credential Manager and pass it to the Python sidecar only for a consented
request.

## Build

```powershell
flutter analyze
flutter test
flutter build windows --release
```
