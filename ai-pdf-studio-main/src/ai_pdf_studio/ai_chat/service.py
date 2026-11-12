from dataclasses import dataclass
import re

from collections.abc import Iterator

from ai_pdf_studio.ai_providers import ChatMessage, ProviderAdapter
from ai_pdf_studio.rag import LocalRetriever, RetrievalResult
from ai_pdf_studio.security import Consent, require_consent


@dataclass(frozen=True, slots=True)
class Citation:
    source_id: str
    page_number: int
    text: str


@dataclass(frozen=True, slots=True)
class Answer:
    text: str
    citations: tuple[Citation, ...]


class PdfChatService:
    """Retrieves page-aware context and verifies citations in an AI response."""

    def __init__(self, retriever: LocalRetriever, provider: ProviderAdapter) -> None:
        self._retriever = retriever
        self._provider = provider

    def answer(
        self,
        question: str,
        *,
        document_id: str,
        consent: Consent | None,
        limit: int = 5,
        model: str = "gpt-4o-mini",
        provider_id: str = "openai",
        temperature: float = 0.2,
        max_tokens: int = 1200,
    ) -> Answer:
        require_consent(
            consent,
            provider_id=provider_id,
            document_id=document_id,
            scope="chat",
        )
        retrieved = self._retriever.search(question, document_id=document_id, limit=limit)
        if not retrieved:
            return Answer("The document does not contain enough information to answer that.", ())
        context = "\n\n".join(
            f"[source-{index} page={result.chunk.page_number}]\n{result.chunk.text}"
            for index, result in enumerate(retrieved, start=1)
        )
        response = self._provider.chat(
            [
                ChatMessage(
                    "system",
                    "Answer only from the provided sources. Cite factual claims with "
                    "[source-N]. If the sources do not answer the question, say so.",
                ),
                ChatMessage("user", f"Question: {question}\n\nSources:\n{context}"),
            ],
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        if not isinstance(response, str):
            raise TypeError("The chat provider returned a stream; use answer_stream.")
        citations = self._citations(response, retrieved)
        return Answer(response, citations)

    def answer_stream(
        self,
        question: str,
        *,
        document_id: str,
        consent: Consent | None,
        limit: int = 5,
        model: str = "gpt-4o-mini",
        provider_id: str = "openai",
        temperature: float = 0.2,
        max_tokens: int = 1200,
    ) -> tuple[Iterator[str], tuple[RetrievalResult, ...]]:
        require_consent(consent, provider_id=provider_id, document_id=document_id, scope="chat")
        retrieved = self._retriever.search(question, document_id=document_id, limit=limit)
        if not retrieved:
            return iter(("The document does not contain enough information to answer that.",)), ()
        context = "\n\n".join(
            f"[source-{index} page={result.chunk.page_number}]\n{result.chunk.text}"
            for index, result in enumerate(retrieved, start=1)
        )
        response = self._provider.chat(
            [
                ChatMessage("system", "Answer only from the provided sources. Cite factual claims with [source-N]. If the sources do not answer the question, say so."),
                ChatMessage("user", f"Question: {question}\n\nSources:\n{context}"),
            ],
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            stream=True,
        )
        if isinstance(response, str):
            return iter((response,)), retrieved
        return response, retrieved

    def citations_for(self, text: str, results: tuple[RetrievalResult, ...]) -> tuple[Citation, ...]:
        return self._citations(text, results)

    @staticmethod
    def _citations(text: str, results: tuple[RetrievalResult, ...]) -> tuple[Citation, ...]:
        citations = []
        for match in re.finditer(r"\[source-(\d+)\]", text):
            index = int(match.group(1)) - 1
            if 0 <= index < len(results):
                result = results[index]
                citation = Citation(
                    source_id=f"source-{index + 1}",
                    page_number=result.chunk.page_number,
                    text=result.chunk.text,
                )
                if citation not in citations:
                    citations.append(citation)
        return tuple(citations)
