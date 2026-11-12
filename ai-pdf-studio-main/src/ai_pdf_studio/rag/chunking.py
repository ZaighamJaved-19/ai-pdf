from dataclasses import dataclass
import re
from collections.abc import Iterable

from ai_pdf_studio.pdf.models import PdfPageText


@dataclass(frozen=True, slots=True)
class SectionChunk:
    page_number: int
    chunk_index: int
    section: str | None
    text: str


class SemanticChunker:
    """Builds page-preserving chunks and keeps likely section headings as metadata."""

    _heading = re.compile(r"^(?:(?:\d+(?:\.\d+)*)\s+)?([A-Z][A-Za-z0-9][^.!?]{2,100})$")

    def __init__(self, *, max_words: int = 180, overlap_words: int = 30) -> None:
        if max_words < 1 or overlap_words < 0 or overlap_words >= max_words:
            raise ValueError("overlap_words must be between 0 and max_words - 1")
        self.max_words = max_words
        self.overlap_words = overlap_words

    def chunk(self, pages: Iterable[PdfPageText]) -> tuple[SectionChunk, ...]:
        chunks: list[SectionChunk] = []
        section: str | None = None
        for page in pages:
            lines = [line.strip() for line in page.text.splitlines() if line.strip()]
            words: list[str] = []
            for line in lines:
                match = self._heading.match(line)
                if match and len(line.split()) <= 12:
                    section = match.group(1).strip()
                words.extend(line.split())
            step = self.max_words - self.overlap_words
            for offset in range(0, len(words), step):
                part = words[offset : offset + self.max_words]
                if not part:
                    break
                chunks.append(SectionChunk(page.page_number, len(chunks), section, " ".join(part)))
                if offset + self.max_words >= len(words):
                    break
        return tuple(chunks)
