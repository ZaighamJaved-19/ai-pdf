from collections.abc import Callable, Iterable
import math
import re

from .retriever import RetrievalResult, TextChunk


Embedding = tuple[float, ...]
Embedder = Callable[[str], Embedding]


class HybridRetriever:
    """Combines lexical scores with cosine similarity using reciprocal rank fusion."""

    def __init__(self, *, lexical_weight: float = 0.5, vector_weight: float = 0.5):
        if lexical_weight < 0 or vector_weight < 0 or lexical_weight + vector_weight == 0:
            raise ValueError("retrieval weights must be non-negative and not both zero")
        self._lexical_weight = lexical_weight
        self._vector_weight = vector_weight
        self._chunks: tuple[TextChunk, ...] = ()
        self._embeddings: dict[tuple[str, int], Embedding] = {}

    def index(
        self, chunks: Iterable[TextChunk], embedder: Embedder
    ) -> None:
        self._chunks = tuple(chunks)
        self._embeddings = {
            (chunk.document_id, chunk.chunk_index): embedder(chunk.text)
            for chunk in self._chunks
        }

    def search(
        self,
        query: str,
        *,
        document_id: str,
        embedder: Embedder,
        limit: int = 5,
    ) -> tuple[RetrievalResult, ...]:
        if limit < 1:
            raise ValueError("limit must be at least 1")
        candidates = [chunk for chunk in self._chunks if chunk.document_id == document_id]
        query_terms = set(re.findall(r"[a-z0-9]{2,}", query.lower()))
        query_vector = embedder(query)
        lexical = sorted(
            (
                (sum(term in set(re.findall(r"[a-z0-9]{2,}", chunk.text.lower()))
                      for term in query_terms), chunk)
                for chunk in candidates
            ),
            key=lambda item: (-item[0], item[1].page_number, item[1].chunk_index),
        )
        vector = sorted(
            (
                (self._cosine(query_vector, self._embeddings[(chunk.document_id, chunk.chunk_index)]), chunk)
                for chunk in candidates
            ),
            key=lambda item: (-item[0], item[1].page_number, item[1].chunk_index),
        )
        lexical_rank = {chunk: rank for rank, (_, chunk) in enumerate(lexical, start=1)}
        vector_rank = {chunk: rank for rank, (_, chunk) in enumerate(vector, start=1)}
        results = []
        for chunk in candidates:
            score = (
                self._lexical_weight / (60 + lexical_rank[chunk])
                + self._vector_weight / (60 + vector_rank[chunk])
            )
            results.append(RetrievalResult(chunk=chunk, score=score))
        results.sort(key=lambda result: (-result.score, result.chunk.page_number))
        return tuple(results[:limit])

    @staticmethod
    def _cosine(left: Embedding, right: Embedding) -> float:
        if len(left) != len(right) or not left:
            return 0.0
        denominator = math.sqrt(sum(value * value for value in left)) * math.sqrt(
            sum(value * value for value in right)
        )
        return sum(a * b for a, b in zip(left, right)) / denominator if denominator else 0.0
