import sqlite3
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
