from pathlib import Path
from typing import Iterable

from pypdf import PdfReader
from pypdf.errors import PdfReadError

from .models import PdfDocument, PdfPageText


class PdfError(RuntimeError):
    """Raised when a PDF cannot be safely opened or processed."""


class PdfService:
    """Local PDF operations used by the desktop application and future API layer."""

    def inspect(self, path: Path) -> PdfDocument:
        path = self._validate_path(path)
        reader = self._open_reader(path)
        metadata = reader.metadata
        return PdfDocument(
            path=path,
            page_count=len(reader.pages),
            file_size_bytes=path.stat().st_size,
            title=self._metadata_value(metadata, "/Title"),
            author=self._metadata_value(metadata, "/Author"),
            encrypted=reader.is_encrypted,
        )

    def extract_text(self, path: Path) -> tuple[PdfPageText, ...]:
        path = self._validate_path(path)
        reader = self._open_reader(path)
        if reader.is_encrypted:
            raise PdfError("The document is password protected.")

        pages: list[PdfPageText] = []
        for page_number, page in enumerate(reader.pages, start=1):
            try:
                pages.append(
                    PdfPageText(
                        page_number=page_number,
                        text=page.extract_text() or "",
                    )
                )
            except Exception as exc:
                raise PdfError(
                    f"Unable to extract text from page {page_number}."
                ) from exc
        return tuple(pages)

    @staticmethod
    def _metadata_value(metadata: object, key: str) -> str | None:
        value = metadata.get(key) if metadata else None
        return str(value) if value else None

    @staticmethod
    def _validate_path(path: Path) -> Path:
        resolved = path.expanduser().resolve()
        if not resolved.is_file():
            raise PdfError(f"PDF file does not exist: {resolved}")
        if resolved.suffix.lower() != ".pdf":
            raise PdfError("The selected file is not a PDF.")
        return resolved

    @staticmethod
    def _open_reader(path: Path) -> PdfReader:
        try:
            return PdfReader(str(path), strict=False)
        except (PdfReadError, OSError, ValueError) as exc:
            raise PdfError("Unable to open this PDF.") from exc
