from collections import Counter
from dataclasses import dataclass
import re
from typing import Iterable

from ai_pdf_studio.pdf.models import PdfPageText


@dataclass(frozen=True, slots=True)
class TextChunk:
    document_id: str
    page_number: int
    chunk_index: int
    text: str


@dataclass(frozen=True, slots=True)
class RetrievalResult:
    chunk: TextChunk
    score: float


class LocalRetriever:
    """Small deterministic lexical retriever with document-context isolation."""

    def __init__(
        self, *, max_words: int = 180, overlap_words: int | None = None
    ) -> None:
        if max_words < 1:
            raise ValueError("max_words must be at least 1")
        if overlap_words is None:
            overlap_words = min(30, max_words - 1)
        if overlap_words < 0 or overlap_words >= max_words:
            raise ValueError("overlap_words must be between 0 and max_words - 1")
        self._max_words = max_words
        self._overlap_words = overlap_words
        self._chunks: list[TextChunk] = []

    def index(self, document_id: str, pages: Iterable[PdfPageText]) -> tuple[TextChunk, ...]:
        if not document_id.strip():
            raise ValueError("document_id must not be empty")
        indexed: list[TextChunk] = []
        for page in pages:
            words = page.text.split()
            if not words:
                continue
            step = self._max_words - self._overlap_words
            for offset in range(0, len(words), step):
                chunk_words = words[offset : offset + self._max_words]
                if not chunk_words:
                    break
                indexed.append(
                    TextChunk(
                        document_id=document_id,
                        page_number=page.page_number,
                        chunk_index=len(indexed),
                        text=" ".join(chunk_words),
                    )
                )
                if offset + self._max_words >= len(words):
                    break
        self._chunks = [
            chunk for chunk in self._chunks if chunk.document_id != document_id
        ] + indexed
        return tuple(indexed)

    def search(
        self, query: str, *, document_id: str, limit: int = 5
    ) -> tuple[RetrievalResult, ...]:
        terms = self._terms(query)
        if not terms:
            return ()
        if limit < 1:
            raise ValueError("limit must be at least 1")

        results: list[RetrievalResult] = []
        for chunk in self._chunks:
            if chunk.document_id != document_id:
                continue
            chunk_terms = Counter(self._terms(chunk.text))
            score = sum(chunk_terms[term] for term in terms)
            if score:
                results.append(RetrievalResult(chunk=chunk, score=float(score)))
        results.sort(
            key=lambda result: (
                -result.score,
                result.chunk.page_number,
                result.chunk.chunk_index,
            )
        )
        return tuple(results[:limit])

    @staticmethod
    def _terms(value: str) -> tuple[str, ...]:
        return tuple(re.findall(r"[a-z0-9]{2,}", value.lower()))
