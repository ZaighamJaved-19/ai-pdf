from __future__ import annotations

from io import BytesIO
from pathlib import Path
from typing import Any, Iterable

from pypdf import PdfReader, PdfWriter, Transformation
from pypdf.generic import ArrayObject, DictionaryObject, FloatObject, NameObject, TextStringObject

from .service import PdfError


class PdfEditor:
    """Applies non-destructive PDF edits to a new output file."""

    def edit(
        self,
        input_path: Path,
        output: Path,
        *,
        annotations: Iterable[dict[str, Any]] = (),
        crop: dict[str, float] | None = None,
        text: Iterable[dict[str, Any]] = (),
        image: Iterable[dict[str, Any]] = (),
        header: str | None = None,
        footer: str | None = None,
        watermark: str | None = None,
    ) -> Path:
        reader = self._reader(input_path)
        if input_path.expanduser().resolve() == output.expanduser().resolve():
            raise PdfError("The output PDF must be different from the source PDF.")
        total_pages = len(reader.pages)
        annotation_items = tuple(annotations)
        text_items = tuple(text)
        image_items = tuple(image)
        for page_number, page in enumerate(reader.pages, start=1):
            page_annotations = [item for item in annotation_items if int(item.get("page", 1)) == page_number]
            self._apply_crop(page, crop if crop and int(crop.get("page", page_number)) == page_number else None)
            for item in page_annotations:
                self._add_annotation(page, item)
            for item in text_items:
                if int(item.get("page", 1)) == page_number:
                    self._add_free_text(page, item)
            for item in image_items:
                if int(item.get("page", 1)) == page_number:
                    self._add_image(page, item)
            if header or footer or watermark:
                overlay = _text_overlay(
                    float(page.mediabox.width),
                    float(page.mediabox.height),
                    header=header.replace("{page}", str(page_number)).replace("{pages}", str(total_pages)) if header else None,
                    footer=footer.replace("{page}", str(page_number)).replace("{pages}", str(total_pages)) if footer else None,
                    watermark=watermark,
                )
                page.merge_page(overlay)
        return self._write(reader, output)

    def crop(self, input_path: Path, output: Path, page: int, rectangle: dict[str, float]) -> Path:
        return self.edit(input_path, output, crop={**rectangle, "page": page})

    def extract(self, input_path: Path, output: Path, pages: Iterable[int]) -> Path:
        if input_path.expanduser().resolve() == output.expanduser().resolve():
            raise PdfError("The output PDF must be different from the source PDF.")
        reader = self._reader(input_path)
        selected = [int(page) for page in pages]
        if not selected or any(page < 1 or page > len(reader.pages) for page in selected):
            raise PdfError("Selected page numbers are outside the document.")
        writer = PdfWriter()
        for page in selected:
            writer.add_page(reader.pages[page - 1])
        return self._write(writer, output)

    @staticmethod
    def _apply_crop(page: Any, crop: dict[str, float] | None) -> None:
        if not crop:
            return
        x = float(crop["x"])
        y = float(crop["y"])
        width = float(crop["width"])
        height = float(crop["height"])
        if width <= 0 or height <= 0:
            raise ValueError("Crop width and height must be positive.")
        page.cropbox.lower_left = (x, y)
        page.cropbox.upper_right = (x + width, y + height)

    @staticmethod
    def _add_annotation(page: Any, item: dict[str, Any]) -> None:
        kind = str(item.get("type", "highlight")).lower()
        rect = _rect(item)
        color = ArrayObject([FloatObject(float(value)) for value in item.get("color", [1, 1, 0])])
        annotation = DictionaryObject(
            {
                NameObject("/Type"): NameObject("/Annot"),
                NameObject("/Subtype"): NameObject(f"/{_annotation_subtype(kind)}"),
                NameObject("/Rect"): rect,
                NameObject("/C"): color,
                NameObject("/Contents"): TextStringObject(str(item.get("contents", ""))),
                NameObject("/Subj"): TextStringObject(str(item.get("subject", kind.title()))),
            }
        )
        if kind in {"highlight", "underline", "strikethrough"}:
            annotation[NameObject("/QuadPoints")] = _quad_points(rect)
        elif kind == "arrow":
            annotation[NameObject("/L")] = ArrayObject(
                [FloatObject(float(item.get("x1", rect[0]))), FloatObject(float(item.get("y1", rect[1]))),
                 FloatObject(float(item.get("x2", rect[2]))), FloatObject(float(item.get("y2", rect[3])))]
            )
            annotation[NameObject("/LE")] = ArrayObject([NameObject("/None"), NameObject("/OpenArrow")])
        elif kind == "freehand":
            points = item.get("points", [])
            annotation[NameObject("/InkList")] = ArrayObject(
                [ArrayObject([FloatObject(float(value)) for point in points for value in point])]
            )
        elif kind in {"rectangle", "shape", "circle", "ellipse"}:
            annotation[NameObject("/BS")] = DictionaryObject({NameObject("/W"): FloatObject(1)})
        elif kind == "comment":
            annotation[NameObject("/Subtype")] = NameObject("/Text")
            annotation[NameObject("/Open")] = False
        _append_annotation(page, annotation)

    @staticmethod
    def _add_free_text(page: Any, item: dict[str, Any]) -> None:
        rect = _rect(item)
        annotation = DictionaryObject(
            {
                NameObject("/Type"): NameObject("/Annot"),
                NameObject("/Subtype"): NameObject("/FreeText"),
                NameObject("/Rect"): rect,
                NameObject("/Contents"): TextStringObject(str(item.get("text", ""))),
                NameObject("/DA"): TextStringObject(str(item.get("appearance", "/Helv 12 Tf 0 g"))),
                NameObject("/Border"): ArrayObject([FloatObject(0), FloatObject(0), FloatObject(0)]),
            }
        )
        _append_annotation(page, annotation)

    @staticmethod
    def _add_image(page: Any, item: dict[str, Any]) -> None:
        from PIL import Image

        source = Path(str(item["path"])).expanduser().resolve()
        if not source.is_file():
            raise PdfError(f"Image file does not exist: {source}")
        buffer = BytesIO()
        with Image.open(source) as image:
            image.convert("RGB").save(buffer, format="PDF", resolution=72.0)
        image_page = PdfReader(BytesIO(buffer.getvalue()), strict=False).pages[0]
        width = float(item.get("width", image_page.mediabox.width))
        height = float(item.get("height", image_page.mediabox.height))
        scale_x = width / float(image_page.mediabox.width)
        scale_y = height / float(image_page.mediabox.height)
        page.merge_transformed_page(
            image_page,
            Transformation().scale(scale_x, scale_y).translate(float(item.get("x", 0)), float(item.get("y", 0))),
        )

    @staticmethod
    def _reader(path: Path) -> PdfReader:
        try:
            return PdfReader(str(path), strict=False)
        except Exception as exc:
            raise PdfError(f"Unable to open PDF: {path}") from exc

    @staticmethod
    def _write(source: PdfReader | PdfWriter, output: Path) -> Path:
        output = output.expanduser().resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(source, PdfWriter):
            writer = source
        else:
            writer = PdfWriter()
            for page in source.pages:
                writer.add_page(page)
        with output.open("wb") as stream:
            writer.write(stream)
        return output


def _append_annotation(page: Any, annotation: DictionaryObject) -> None:
    annotations = page.get("/Annots")
    if annotations is None:
        annotations = ArrayObject()
        page[NameObject("/Annots")] = annotations
    annotations.append(annotation)


def _rect(item: dict[str, Any]) -> ArrayObject:
    return ArrayObject(
        [
            FloatObject(float(item.get("x", 0))),
            FloatObject(float(item.get("y", 0))),
            FloatObject(float(item.get("x", 0)) + float(item.get("width", 100))),
            FloatObject(float(item.get("y", 0)) + float(item.get("height", 20))),
        ]
    )


def _quad_points(rect: ArrayObject) -> ArrayObject:
    return ArrayObject([rect[0], rect[3], rect[2], rect[3], rect[0], rect[1], rect[2], rect[1]])


def _annotation_subtype(kind: str) -> str:
    return {
        "strikethrough": "StrikeOut",
        "comment": "Text",
        "sticky": "Text",
        "shape": "Square",
        "rectangle": "Square",
        "circle": "Circle",
        "ellipse": "Circle",
        "signature": "Stamp",
        "freehand": "Ink",
    }.get(kind, kind.title())


def _text_overlay(
    width: float,
    height: float,
    *,
    header: str | None,
    footer: str | None,
    watermark: str | None,
) -> Any:
    from pypdf import PdfReader

    commands: list[str] = []
    if header:
        commands.append(f"BT /F1 9 Tf 36 {height - 28:.2f} Td ({_escape(header)}) Tj ET")
    if footer:
        commands.append(f"BT /F1 9 Tf 36 20 Td ({_escape(footer)}) Tj ET")
    if watermark:
        commands.append(f"BT /F1 28 Tf 150 {height / 2:.2f} Td ({_escape(watermark)}) Tj ET")
    content = "\n".join(commands).encode("latin-1", errors="replace")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {width:.2f} {height:.2f}] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>".encode(),
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Length " + str(len(content)).encode() + b" >>\nstream\n" + content + b"\nendstream",
    ]
    data = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for index, obj in enumerate(objects, start=1):
        offsets.append(len(data))
        data.extend(f"{index} 0 obj\n".encode())
        data.extend(obj)
        data.extend(b"\nendobj\n")
    xref = len(data)
    data.extend(f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode())
    data.extend("".join(f"{offset:010d} 00000 n \n" for offset in offsets[1:]).encode())
    data.extend(f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode())
    return PdfReader(BytesIO(bytes(data)), strict=False).pages[0]


def _escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
