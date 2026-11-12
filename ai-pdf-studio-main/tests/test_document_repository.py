from pathlib import Path

from ai_pdf_studio.library import DocumentRepository


def test_repository_upserts_and_orders_recent_documents(tmp_path: Path) -> None:
    repository = DocumentRepository(tmp_path / "library.db")
    first = tmp_path / "first.pdf"
    second = tmp_path / "second.pdf"

    repository.upsert(first, title="First", last_page=3)
    repository.upsert(second, title="Second", favorite=True)
    repository.upsert(first, title="First", last_page=4)

    recent = repository.list_recent()

    assert [record.path for record in recent] == [first.resolve(), second.resolve()]
    assert repository.get(first).last_page == 4
    assert repository.get(second).favorite is True
    repository.close()


def test_repository_persists_notes_tags_content_and_removal(tmp_path: Path) -> None:
    repository = DocumentRepository(tmp_path / "library.db")
    document = tmp_path / "notes.pdf"
    repository.upsert(document, title="Notes")

    repository.set_note(document, "Review chapter two.")
    repository.set_tags(document, {"work", "review"})
    repository.index_content(document, ((1, "alpha beta"), (2, "chapter two details")))

    assert repository.note(document) == "Review chapter two."
    assert repository.tags(document) == ("review", "work")
    assert repository.search_content("chapter", limit=10)[0]["page_number"] == 2
    assert repository.remove(document) is True
    assert repository.list_documents() == ()
    repository.close()
