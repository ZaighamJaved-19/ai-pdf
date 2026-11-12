from pathlib import Path
from zipfile import ZipFile

from pypdf import PdfReader

from ai_pdf_studio.ai_tools import AiToolRequest, AiToolsService
from ai_pdf_studio.ai_tools.export import export_result


class FakeProvider:
    provider_id = "openai"

    def chat(self, messages, **kwargs):
        prompt = messages[-1].content
        if "valid JSON" in prompt:
            return '{"items":[{"front":"Question","back":"Answer"}]}'
        return "Generated result."


def test_ai_tools_support_summary_and_structured_flashcards() -> None:
    service = AiToolsService()
    summary = service.generate(
        AiToolRequest("summary", "The document text.", mode="executive"),
        FakeProvider(),  # type: ignore[arg-type]
        model="test",
    )
    cards = service.generate(
        AiToolRequest("flashcards", "The document text.", difficulty="hard"),
        FakeProvider(),  # type: ignore[arg-type]
        model="test",
    )

    assert summary.title == "Executive Summary"
    assert cards.items[0]["front"] == "Question"


def test_exports_are_valid_txt_pdf_and_docx(tmp_path: Path) -> None:
    txt = export_result("Title", "Body", tmp_path / "result.txt", "txt")
    pdf = export_result("Title", "Body", tmp_path / "result.pdf", "pdf")
    docx = export_result("Title", "Body", tmp_path / "result.docx", "docx")

    assert txt.read_text(encoding="utf-8").startswith("Title")
    assert "Body" in PdfReader(str(pdf)).pages[0].extract_text()
    with ZipFile(docx) as archive:
        assert "word/document.xml" in archive.namelist()
