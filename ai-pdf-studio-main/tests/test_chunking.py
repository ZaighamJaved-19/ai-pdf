from pathlib import Path

from ai_pdf_studio.pdf import PdfPageText
from ai_pdf_studio.rag import PersistentVectorStore, SemanticChunker


def test_semantic_chunker_detects_sections_and_preserves_pages() -> None:
    chunks = SemanticChunker(max_words=20, overlap_words=0).chunk(
        [PdfPageText(page_number=3, text="INTRODUCTION\nThis section explains the scope.")]
    )

    assert chunks[0].section == "INTRODUCTION"
    assert chunks[0].page_number == 3


def test_vector_store_replaces_document_chunks(tmp_path: Path) -> None:
    store = PersistentVectorStore(tmp_path / "vectors.db")
    chunks = SemanticChunker().chunk([PdfPageText(page_number=1, text="A section with content.")])
    store.replace("doc-a", chunks, ((0.1, 0.2),))

    saved = store.chunks("doc-a")
    assert saved[0]["pageNumber"] == 1
    assert saved[0]["embedding"] == (0.1, 0.2)
    store.close()
