import io
import json
from pathlib import Path

from pypdf import PdfWriter

from ai_pdf_studio.rpc_server import SidecarServer


def test_authenticated_rpc_handshake_and_library(tmp_path: Path) -> None:
    database = tmp_path / "library.db"
    pdf = tmp_path / "document.pdf"
    writer = PdfWriter()
    writer.add_blank_page(width=200, height=200)
    with pdf.open("wb") as stream:
        writer.write(stream)
    server = SidecarServer("secret", database)
    server._database.upsert(pdf, title="Document")
    output = io.StringIO()
    server.serve(
        io.StringIO(
            json.dumps({"jsonrpc": "2.0", "id": 1, "auth": "wrong", "method": "system.health"}) + "\n"
            + json.dumps({"jsonrpc": "2.0", "id": 2, "auth": "secret", "method": "system.handshake", "params": {"clientContractVersion": "1.0.0"}}) + "\n"
        ),
        output,
    )
    responses = [json.loads(line) for line in output.getvalue().splitlines()]
    assert responses[0]["error"]["code"] == -32001
    assert responses[1]["result"]["capabilities"]["transport"] == "stdio"
