from ai_pdf_studio.pdf import PdfPageText
from ai_pdf_studio.rag import LocalRetriever


def test_search_keeps_document_context_isolated() -> None:
    retriever = LocalRetriever(max_words=20)
    retriever.index(
        "document-a",
        [PdfPageText(page_number=2, text="The contract renewal date is June 12.")],
    )
    retriever.index(
        "document-b",
        [PdfPageText(page_number=1, text="The contract renewal date is July 4.")],
    )

    results = retriever.search("renewal date June", document_id="document-a")

    assert len(results) == 1
    assert results[0].chunk.document_id == "document-a"
    assert results[0].chunk.page_number == 2
    assert "June" in results[0].chunk.text


def test_long_pages_are_chunked_with_page_numbers() -> None:
    retriever = LocalRetriever(max_words=4, overlap_words=1)
    chunks = retriever.index(
        "document-a",
        [PdfPageText(page_number=7, text="one two three four five six seven")],
    )

    assert [chunk.text for chunk in chunks] == [
        "one two three four",
        "four five six seven",
    ]
    assert all(chunk.page_number == 7 for chunk in chunks)
