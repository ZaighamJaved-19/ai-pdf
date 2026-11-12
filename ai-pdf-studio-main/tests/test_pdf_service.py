from pathlib import Path

from pypdf import PdfWriter

from ai_pdf_studio.pdf import PdfError, PdfService


def create_pdf(path: Path) -> None:
    writer = PdfWriter()
    writer.add_blank_page(width=200, height=200)
    writer.add_metadata({"/Title": "Test document", "/Author": "AI PDF Studio"})
    with path.open("wb") as stream:
        writer.write(stream)


def test_inspect_returns_metadata_and_page_count(tmp_path: Path) -> None:
    pdf_path = tmp_path / "sample.pdf"
    create_pdf(pdf_path)

    document = PdfService().inspect(pdf_path)

    assert document.path == pdf_path.resolve()
    assert document.page_count == 1
    assert document.title == "Test document"
    assert document.author == "AI PDF Studio"
    assert document.encrypted is False


def test_missing_file_is_reported(tmp_path: Path) -> None:
    try:
        PdfService().inspect(tmp_path / "missing.pdf")
    except PdfError as error:
        assert "does not exist" in str(error)
    else:
        raise AssertionError("Expected PdfError")
