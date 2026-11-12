"""Page-preserving local retrieval primitives."""

from .retriever import LocalRetriever, RetrievalResult, TextChunk
from .hybrid import HybridRetriever

__all__ = ["HybridRetriever", "LocalRetriever", "RetrievalResult", "TextChunk"]
