"""Page-preserving local retrieval primitives."""

from .retriever import LocalRetriever, RetrievalResult, TextChunk
from .hybrid import HybridRetriever
from .chunking import SemanticChunker, SectionChunk
from .vector_store import PersistentVectorStore

__all__ = [
    "HybridRetriever",
    "LocalRetriever",
    "PersistentVectorStore",
    "RetrievalResult",
    "SemanticChunker",
    "SectionChunk",
    "TextChunk",
]
