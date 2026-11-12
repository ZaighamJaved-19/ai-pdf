from collections.abc import Iterable
from pathlib import Path

from pypdf import PdfReader, PdfWriter

from .service import PdfError


class PdfPageOperations:
    """Local, lossless page editing operations."""

    def merge(self, inputs: Iterable[Path], output: Path) -> Path:
        writer = PdfWriter()
        for path in inputs:
            reader = self._reader(path)
            for page in reader.pages:
                writer.add_page(page)
        return self._write(writer, output)

    def transform(
        self,
        input_path: Path,
        output: Path,
        *,
        order: Iterable[int] | None = None,
        rotate: dict[int, int] | None = None,
        delete: Iterable[int] = (),
        duplicate: Iterable[int] = (),
        blank_after: Iterable[int] = (),
    ) -> Path:
        reader = self._reader(input_path)
        page_order = list(order) if order is not None else list(range(len(reader.pages)))
        deleted = set(delete)
        duplicates = set(duplicate)
        blank_pages = set(blank_after)
        additions: list[int | None] = []
        for index in page_order:
            if index < 0 or index >= len(reader.pages):
                raise PdfError(f"Page index out of range: {index}")
            if index in deleted:
                continue
            additions.append(index)
            if index in duplicates:
                additions.append(index)
            if index in blank_pages:
                additions.append(None)
        writer = PdfWriter()
        for index in additions:
            if index is None:
                writer.add_blank_page(
                    width=float(reader.pages[0].mediabox.width),
                    height=float(reader.pages[0].mediabox.height),
                )
                continue
            page = reader.pages[index]
            angle = (rotate or {}).get(index, 0)
            if angle % 90:
                raise ValueError("Page rotation must be a multiple of 90 degrees")
            if angle:
                page.rotate(angle)
            writer.add_page(page)
        return self._write(writer, output)

    @staticmethod
    def _reader(path: Path) -> PdfReader:
        try:
            return PdfReader(str(path), strict=False)
        except Exception as exc:
            raise PdfError(f"Unable to open PDF: {path}") from exc

    @staticmethod
    def _write(writer: PdfWriter, output: Path) -> Path:
        output = output.expanduser().resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("wb") as stream:
            writer.write(stream)
        return output
