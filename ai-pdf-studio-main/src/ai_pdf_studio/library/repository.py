import sqlite3
import os
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass(frozen=True, slots=True)
class DocumentRecord:
    path: Path
    title: str | None
    last_page: int
    favorite: bool
    updated_at: datetime

    @property
    def exists(self) -> bool:
        return self.path.is_file()


@dataclass(frozen=True, slots=True)
class Workspace:
    name: str
    created_at: datetime


class DocumentRepository:
    """Stores references and reading state without copying document contents."""

    def __init__(self, database_path: Path) -> None:
        self._connection = sqlite3.connect(database_path)
        self._connection.row_factory = sqlite3.Row
        self._connection.execute(
            """
            CREATE TABLE IF NOT EXISTS documents (
                path TEXT PRIMARY KEY,
                title TEXT,
                last_page INTEGER NOT NULL DEFAULT 1,
                favorite INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL
            )
            """
        )
        self._connection.execute(
            "CREATE TABLE IF NOT EXISTS tags (path TEXT NOT NULL, tag TEXT NOT NULL, "
            "PRIMARY KEY(path, tag))"
        )
        self._connection.execute(
            "CREATE TABLE IF NOT EXISTS workspaces (name TEXT PRIMARY KEY, created_at TEXT NOT NULL)"
        )
        self._connection.execute(
            "CREATE TABLE IF NOT EXISTS workspace_documents "
            "(workspace TEXT NOT NULL, path TEXT NOT NULL, PRIMARY KEY(workspace, path))"
        )
        self._connection.execute(
            "CREATE TABLE IF NOT EXISTS document_notes "
            "(path TEXT PRIMARY KEY, note TEXT NOT NULL DEFAULT '')"
        )
        self._connection.execute(
            "CREATE VIRTUAL TABLE IF NOT EXISTS document_content USING fts5("
            "path UNINDEXED, page_number UNINDEXED, text)"
        )
        self._connection.commit()

    def upsert(
        self,
        path: Path,
        *,
        title: str | None = None,
        last_page: int = 1,
        favorite: bool = False,
    ) -> DocumentRecord:
        if last_page < 1:
            raise ValueError("last_page must be at least 1")
        timestamp = datetime.now(timezone.utc)
        self._connection.execute(
            """
            INSERT INTO documents(path, title, last_page, favorite, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                title = excluded.title,
                last_page = excluded.last_page,
                favorite = excluded.favorite,
                updated_at = excluded.updated_at
            """,
            (str(path.expanduser().resolve()), title, last_page, int(favorite), timestamp.isoformat()),
        )
        self._connection.commit()
        return self.get(path)

    def get(self, path: Path) -> DocumentRecord:
        row = self._connection.execute(
            "SELECT * FROM documents WHERE path = ?", (str(path.expanduser().resolve()),)
        ).fetchone()
        if row is None:
            raise KeyError(path)
        return self._record(row)

    def list_recent(self, limit: int = 20) -> tuple[DocumentRecord, ...]:
        if limit < 1:
            raise ValueError("limit must be at least 1")
        rows = self._connection.execute(
            "SELECT * FROM documents ORDER BY updated_at DESC LIMIT ?", (limit,)
        ).fetchall()
        return tuple(self._record(row) for row in rows)

    def list_documents(
        self,
        *,
        query: str = "",
        favorite: bool | None = None,
        folder: str | None = None,
        tag: str | None = None,
        workspace: str | None = None,
        limit: int = 100,
    ) -> tuple[DocumentRecord, ...]:
        if limit < 1:
            raise ValueError("limit must be at least 1")
        clauses = ["1 = 1"]
        values: list[object] = []
        if favorite is not None:
            clauses.append("d.favorite = ?")
            values.append(int(favorite))
        if folder:
            clauses.append("d.path LIKE ?")
            values.append(str(Path(folder).expanduser().resolve()) + os.sep + "%")
        if tag:
            clauses.append("EXISTS (SELECT 1 FROM tags t WHERE t.path = d.path AND t.tag = ?)")
            values.append(tag)
        if workspace:
            clauses.append(
                "EXISTS (SELECT 1 FROM workspace_documents wd WHERE wd.path = d.path AND wd.workspace = ?)"
            )
            values.append(workspace)
        if query:
            clauses.append("(LOWER(COALESCE(d.title, '')) LIKE ? OR LOWER(d.path) LIKE ?)")
            pattern = f"%{query.lower().strip()}%"
            values.extend([pattern, pattern])
        rows = self._connection.execute(
            f"SELECT d.* FROM documents d WHERE {' AND '.join(clauses)} "
            "ORDER BY d.updated_at DESC LIMIT ?",
            (*values, limit),
        ).fetchall()
        return tuple(self._record(row) for row in rows)

    def remove(self, path: Path) -> bool:
        key = str(path.expanduser().resolve())
        deleted = self._connection.execute("DELETE FROM documents WHERE path = ?", (key,)).rowcount > 0
        self._connection.execute("DELETE FROM tags WHERE path = ?", (key,))
        self._connection.execute("DELETE FROM workspace_documents WHERE path = ?", (key,))
        self._connection.execute("DELETE FROM document_notes WHERE path = ?", (key,))
        self._connection.execute("DELETE FROM document_content WHERE path = ?", (key,))
        self._connection.commit()
        return deleted

    def relocate(self, old_path: Path, new_path: Path) -> DocumentRecord:
        old_key = str(old_path.expanduser().resolve())
        new_key = str(new_path.expanduser().resolve())
        if self._connection.execute("SELECT 1 FROM documents WHERE path = ?", (new_key,)).fetchone():
            raise ValueError("The destination file is already in the library.")
        row = self._connection.execute("SELECT * FROM documents WHERE path = ?", (old_key,)).fetchone()
        if row is None:
            raise KeyError(old_path)
        self._connection.execute("UPDATE documents SET path = ? WHERE path = ?", (new_key, old_key))
        self._connection.execute("UPDATE tags SET path = ? WHERE path = ?", (new_key, old_key))
        self._connection.execute("UPDATE workspace_documents SET path = ? WHERE path = ?", (new_key, old_key))
        self._connection.execute("UPDATE document_notes SET path = ? WHERE path = ?", (new_key, old_key))
        self._connection.execute("UPDATE document_content SET path = ? WHERE path = ?", (new_key, old_key))
        self._connection.commit()
        return self.get(new_path)

    def set_note(self, path: Path, note: str) -> str:
        key = str(path.expanduser().resolve())
        self._connection.execute(
            "INSERT INTO document_notes(path, note) VALUES (?, ?) "
            "ON CONFLICT(path) DO UPDATE SET note = excluded.note",
            (key, note),
        )
        self._connection.commit()
        return note

    def note(self, path: Path) -> str:
        row = self._connection.execute(
            "SELECT note FROM document_notes WHERE path = ?", (str(path.expanduser().resolve()),)
        ).fetchone()
        return str(row["note"]) if row else ""

    def index_content(self, path: Path, pages: tuple[tuple[int, str], ...]) -> None:
        key = str(path.expanduser().resolve())
        self._connection.execute("DELETE FROM document_content WHERE path = ?", (key,))
        self._connection.executemany(
            "INSERT INTO document_content(path, page_number, text) VALUES (?, ?, ?)",
            [(key, page_number, text) for page_number, text in pages if text.strip()],
        )
        self._connection.commit()

    def search_content(self, query: str, limit: int = 100) -> tuple[dict[str, object], ...]:
        tokens = re.findall(r"\w+", query, flags=re.UNICODE)
        if not tokens:
            return ()
        normalized = " AND ".join(f'"{token}"' for token in tokens)
        rows = self._connection.execute(
            "SELECT path, page_number, snippet(document_content, 2, '[', ']', '…', 18) AS snippet "
            "FROM document_content WHERE document_content MATCH ? LIMIT ?",
            (normalized, limit),
        ).fetchall()
        return tuple(dict(row) for row in rows)

    def content_index_empty(self) -> bool:
        row = self._connection.execute("SELECT 1 FROM document_content LIMIT 1").fetchone()
        return row is None

    def list_folders(self) -> tuple[str, ...]:
        rows = self._connection.execute(
            "SELECT DISTINCT substr(path, 1, length(path) - length(replace(path, '/', ''))) AS depth, "
            "path FROM documents"
        ).fetchall()
        folders = {str(Path(row["path"]).parent) for row in rows}
        return tuple(sorted(folders, key=str.casefold))

    def list_tags(self) -> tuple[str, ...]:
        rows = self._connection.execute("SELECT DISTINCT tag FROM tags ORDER BY tag").fetchall()
        return tuple(str(row["tag"]) for row in rows)

    def list_workspaces(self) -> tuple[Workspace, ...]:
        rows = self._connection.execute("SELECT * FROM workspaces ORDER BY name").fetchall()
        return tuple(Workspace(row["name"], datetime.fromisoformat(row["created_at"])) for row in rows)

    def set_tags(self, path: Path, tags: set[str]) -> tuple[str, ...]:
        normalized = {tag.strip() for tag in tags if tag.strip()}
        key = str(path.expanduser().resolve())
        self._connection.execute("DELETE FROM tags WHERE path = ?", (key,))
        self._connection.executemany(
            "INSERT INTO tags(path, tag) VALUES (?, ?)", [(key, tag) for tag in normalized]
        )
        self._connection.commit()
        return tuple(sorted(normalized))

    def tags(self, path: Path) -> tuple[str, ...]:
        key = str(path.expanduser().resolve())
        rows = self._connection.execute(
            "SELECT tag FROM tags WHERE path = ? ORDER BY tag", (key,)
        ).fetchall()
        return tuple(row["tag"] for row in rows)

    def create_workspace(self, name: str) -> Workspace:
        if not name.strip():
            raise ValueError("workspace name must not be empty")
        created_at = datetime.now(timezone.utc)
        self._connection.execute(
            "INSERT INTO workspaces(name, created_at) VALUES (?, ?)",
            (name.strip(), created_at.isoformat()),
        )
        self._connection.commit()
        return Workspace(name.strip(), created_at)

    def add_to_workspace(self, workspace: str, path: Path) -> None:
        self._connection.execute(
            "INSERT OR IGNORE INTO workspace_documents(workspace, path) VALUES (?, ?)",
            (workspace, str(path.expanduser().resolve())),
        )
        self._connection.commit()

    def workspace_documents(self, workspace: str) -> tuple[Path, ...]:
        rows = self._connection.execute(
            "SELECT path FROM workspace_documents WHERE workspace = ? ORDER BY path",
            (workspace,),
        ).fetchall()
        return tuple(Path(row["path"]) for row in rows)

    def close(self) -> None:
        self._connection.close()

    @staticmethod
    def _record(row: sqlite3.Row) -> DocumentRecord:
        return DocumentRecord(
            path=Path(row["path"]),
            title=row["title"],
            last_page=row["last_page"],
            favorite=bool(row["favorite"]),
            updated_at=datetime.fromisoformat(row["updated_at"]),
        )
