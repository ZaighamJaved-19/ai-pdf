$ErrorActionPreference = "Stop"

Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Get-Command pyinstaller -ErrorAction SilentlyContinue)) {
    python -m pip install "pyinstaller>=6.0,<7"
}

python -m pip install -e .
pyinstaller --noconfirm --clean packaging/sidecar/aips-sidecar.spec

$destination = Join-Path (Get-Location) "app\sidecar"
New-Item -ItemType Directory -Force $destination | Out-Null
Copy-Item -Force "dist\aips-sidecar.exe" (Join-Path $destination "aips-sidecar.exe")
Write-Host "Sidecar copied to $destination"
