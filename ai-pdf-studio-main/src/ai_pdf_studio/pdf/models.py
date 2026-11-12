from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass(frozen=True, slots=True)
class PdfPageText:
    """Extracted text for one PDF page, retaining its one-based page number."""

    page_number: int
    text: str


@dataclass(frozen=True, slots=True)
class PdfDocument:
    """Stable, UI-independent metadata for a local PDF document."""

    path: Path
    page_count: int
    file_size_bytes: int
    title: Optional[str]
    author: Optional[str]
    encrypted: bool
