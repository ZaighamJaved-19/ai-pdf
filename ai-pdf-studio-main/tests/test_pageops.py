from pathlib import Path

from pypdf import PdfReader, PdfWriter

from ai_pdf_studio.pdf import PdfPageOperations


def make_pdf(path: Path, pages: int) -> None:
    writer = PdfWriter()
    for _ in range(pages):
        writer.add_blank_page(width=200, height=200)
    with path.open("wb") as stream:
        writer.write(stream)


def test_page_transform_can_delete_duplicate_and_insert_blank(tmp_path: Path) -> None:
    source = tmp_path / "source.pdf"
    output = tmp_path / "output.pdf"
    make_pdf(source, 3)

    PdfPageOperations().transform(
        source,
        output,
        delete=[1],
        duplicate=[0],
        blank_after=[2],
    )

    assert len(PdfReader(str(output)).pages) == 4


def test_split_creates_one_pdf_per_page(tmp_path: Path) -> None:
    source = tmp_path / "source.pdf"
    make_pdf(source, 2)

    outputs = PdfPageOperations().split(source, tmp_path / "split")

    assert len(outputs) == 2
    assert all(len(PdfReader(str(output)).pages) == 1 for output in outputs)
