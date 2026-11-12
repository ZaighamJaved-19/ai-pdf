from PyInstaller.utils.hooks import collect_submodules

hiddenimports = collect_submodules("ai_pdf_studio")

a = Analysis(
    ["src/ai_pdf_studio/rpc_server/__main__.py"],
    pathex=["."],
    hiddenimports=hiddenimports,
    datas=[],
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    name="aips-sidecar",
    console=True,
)
