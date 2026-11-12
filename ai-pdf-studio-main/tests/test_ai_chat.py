from pathlib import Path

import pytest

from ai_pdf_studio.ai_chat import PdfChatService
from ai_pdf_studio.ai_providers import ChatMessage
from ai_pdf_studio.pdf import PdfPageText
from ai_pdf_studio.rag import LocalRetriever
from ai_pdf_studio.security import Consent, ConsentError


class FakeProvider:
    def chat(self, messages: list[ChatMessage], **kwargs: object) -> str:
        assert "page=4" in messages[-1].content
        return "The renewal date is June 12. [source-1]"


def test_chat_requires_consent_and_returns_verified_page_citation() -> None:
    retriever = LocalRetriever()
    retriever.index(
        "doc",
        [PdfPageText(page_number=4, text="The renewal date is June 12.")],
    )
    service = PdfChatService(retriever, FakeProvider())  # type: ignore[arg-type]

    with pytest.raises(ConsentError):
        service.answer("When is renewal?", document_id="doc", consent=None)

    answer = service.answer(
        "When is renewal?",
        document_id="doc",
        consent=Consent.grant("openai", "doc", "chat"),
    )
    assert answer.citations[0].page_number == 4


def test_untrusted_citation_is_not_returned() -> None:
    retriever = LocalRetriever()
    retriever.index("doc", [PdfPageText(page_number=2, text="Only this.")])

    class Provider(FakeProvider):
        def chat(self, messages: list[ChatMessage], **kwargs: object) -> str:
            return "Unsupported claim [source-99]."

    answer = PdfChatService(retriever, Provider()).answer(
        "What?",
        document_id="doc",
        consent=Consent.grant("openai", "doc", "chat"),
    )
    assert answer.citations == ()
