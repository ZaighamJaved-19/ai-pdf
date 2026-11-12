from pathlib import Path

from pypdf import PdfReader, PdfWriter

from ai_pdf_studio.pdf import PdfEditor


def _document(path: Path) -> None:
    writer = PdfWriter()
    writer.add_blank_page(width=600, height=800)
    writer.add_blank_page(width=600, height=800)
    with path.open("wb") as stream:
        writer.write(stream)


def test_editor_adds_annotations_text_overlay_and_preserves_source(tmp_path: Path) -> None:
    source = tmp_path / "source.pdf"
    output = tmp_path / "edited.pdf"
    _document(source)

    PdfEditor().edit(
        source,
        output,
        annotations=[
            {"page": 1, "type": "highlight", "x": 20, "y": 20, "width": 100, "height": 20},
            {"page": 1, "type": "freehand", "points": [[20, 20], [40, 60]]},
        ],
        text=[{"page": 1, "text": "Added text", "x": 40, "y": 650, "width": 180, "height": 30}],
        header="Page {page}/{pages}",
        watermark="DRAFT",
    )

    original = PdfReader(str(source))
    edited = PdfReader(str(output))
    assert len(original.pages) == 2
    assert len(edited.pages[0]["/Annots"]) == 3
    assert edited.pages[0]["/Annots"][0].get_object()["/Subtype"] == "/Highlight"


def test_editor_extracts_and_crops_pages(tmp_path: Path) -> None:
    source = tmp_path / "source.pdf"
    cropped = tmp_path / "cropped.pdf"
    extracted = tmp_path / "extracted.pdf"
    _document(source)

    PdfEditor().edit(source, cropped, crop={"page": 1, "x": 10, "y": 20, "width": 300, "height": 400})
    PdfEditor().extract(source, extracted, [2])

    assert tuple(PdfReader(str(cropped)).pages[0].cropbox) == (10, 20, 310, 420)
    assert len(PdfReader(str(extracted)).pages) == 1
