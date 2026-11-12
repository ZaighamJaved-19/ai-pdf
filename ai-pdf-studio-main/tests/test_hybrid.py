from ai_pdf_studio.pdf import PdfPageText
from ai_pdf_studio.rag import HybridRetriever, LocalRetriever


def embed(value: str) -> tuple[float, ...]:
    return (float("renewal" in value.lower()), float("budget" in value.lower()))


def test_hybrid_search_keeps_document_isolation() -> None:
    lexical = LocalRetriever(max_words=20)
    chunks = []
    for document_id, text in (("a", "renewal date"), ("b", "renewal date")):
        chunks.extend(lexical.index(document_id, [PdfPageText(1, text)]))

    hybrid = HybridRetriever()
    hybrid.index(chunks, embed)
    results = hybrid.search("renewal", document_id="a", embedder=embed)

    assert len(results) == 1
    assert results[0].chunk.document_id == "a"
