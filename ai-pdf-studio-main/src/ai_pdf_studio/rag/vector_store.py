import json
import sqlite3
from pathlib import Path
from typing import Iterable

from .chunking import SectionChunk


class PersistentVectorStore:
    """SQLite-backed chunk and embedding store scoped by document id."""

    def __init__(self, database_path: Path) -> None:
        self._connection = sqlite3.connect(database_path)
        self._connection.execute(
            """
            CREATE TABLE IF NOT EXISTS vector_chunks (
                document_id TEXT NOT NULL,
                page_number INTEGER NOT NULL,
                chunk_index INTEGER NOT NULL,
                section TEXT,
                text TEXT NOT NULL,
                embedding TEXT,
                PRIMARY KEY(document_id, chunk_index)
            )
            """
        )
        self._connection.commit()

    def replace(
        self,
        document_id: str,
        chunks: Iterable[SectionChunk],
        embeddings: Iterable[tuple[float, ...]] = (),
    ) -> None:
        vectors = list(embeddings)
        rows = []
        for index, chunk in enumerate(chunks):
            vector = vectors[index] if index < len(vectors) else ()
            rows.append((document_id, chunk.page_number, chunk.chunk_index, chunk.section, chunk.text, json.dumps(vector)))
        self._connection.execute("DELETE FROM vector_chunks WHERE document_id = ?", (document_id,))
        self._connection.executemany(
            "INSERT INTO vector_chunks(document_id, page_number, chunk_index, section, text, embedding) VALUES (?, ?, ?, ?, ?, ?)",
            rows,
        )
        self._connection.commit()

    def chunks(self, document_id: str) -> tuple[dict[str, object], ...]:
        rows = self._connection.execute(
            "SELECT page_number, chunk_index, section, text, embedding FROM vector_chunks "
            "WHERE document_id = ? ORDER BY chunk_index",
            (document_id,),
        ).fetchall()
        return tuple(
            {
                "pageNumber": row[0],
                "chunkIndex": row[1],
                "section": row[2],
                "text": row[3],
                "embedding": tuple(json.loads(row[4] or "[]")),
            }
            for row in rows
        )

    def clear(self) -> None:
        self._connection.execute("DELETE FROM vector_chunks")
        self._connection.commit()

    def close(self) -> None:
        self._connection.close()
