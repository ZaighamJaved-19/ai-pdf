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
