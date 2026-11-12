# MSIX packaging

The Windows release should package the Flutter runner and the Python sidecar as a
full-trust MSIX. Build prerequisites are Flutter stable, Visual Studio Desktop
development with C++, and a code-signing certificate.

The final manifest must use the owner-reserved identity and certificate. Do not
commit certificates, private keys, Store secrets, or API keys. The sidecar is
expected at `sidecar/aips-sidecar.exe` and is launched by the Flutter process
over stdin/stdout.

Build checklist:

1. Build the sidecar with the pinned Python dependencies.
2. Build the Windows Flutter runner in release mode.
3. Copy the sidecar into the runner's packaged data directory.
4. Generate/sign the MSIX with the owner certificate.
5. Validate installation and uninstall on clean Windows 10 and 11 machines.
