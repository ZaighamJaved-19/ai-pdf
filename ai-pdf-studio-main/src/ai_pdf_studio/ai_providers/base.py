from collections.abc import Iterator, Sequence
from typing import Protocol

from .openai import ChatMessage


class ProviderError(RuntimeError):
    def __init__(self, message: str, *, kind: str = "Provider", status: int | None = None):
        super().__init__(message)
        self.kind = kind
        self.status = status


class ProviderAdapter(Protocol):
    provider_id: str

    def chat(
        self,
        messages: Sequence[ChatMessage],
        *,
        model: str,
        temperature: float = 0.2,
        max_tokens: int = 1200,
        stream: bool = False,
    ) -> str | Iterator[str]:
        ...

    def embeddings(self, texts: Sequence[str], *, model: str) -> tuple[tuple[float, ...], ...]:
        ...
