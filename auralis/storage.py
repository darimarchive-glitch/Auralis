from __future__ import annotations

import json
import shutil
import sqlite3
import time
import uuid
from pathlib import Path

from .importers import BookImporter
from .models import Book, Chapter
from .paths import ensure_layout
from .text import detect_language


class LibraryStore:
    def __init__(self, root: Path | None = None) -> None:
        self.paths = ensure_layout(root)
        self.db_path = self.paths["root"] / "auralis.sqlite3"
        self.importer = BookImporter()
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=15)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA foreign_keys=ON")
        return conn

    def _init_db(self) -> None:
        with self._connect() as db:
            db.executescript(
                """
                CREATE TABLE IF NOT EXISTS books(
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    author TEXT NOT NULL DEFAULT '',
                    language TEXT NOT NULL DEFAULT '',
                    isbn TEXT NOT NULL DEFAULT '',
                    source_path TEXT NOT NULL DEFAULT '',
                    stored_path TEXT NOT NULL DEFAULT '',
                    cover_path TEXT NOT NULL DEFAULT '',
                    format TEXT NOT NULL DEFAULT '',
                    current_chapter INTEGER NOT NULL DEFAULT 0,
                    current_segment INTEGER NOT NULL DEFAULT 0,
                    progress REAL NOT NULL DEFAULT 0,
                    last_opened INTEGER NOT NULL DEFAULT 0,
                    added_at INTEGER NOT NULL DEFAULT 0
                );
                CREATE TABLE IF NOT EXISTS chapters(
                    book_id TEXT NOT NULL,
                    chapter_index INTEGER NOT NULL,
                    title TEXT NOT NULL,
                    text TEXT NOT NULL,
                    PRIMARY KEY(book_id, chapter_index),
                    FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
                );
                CREATE TABLE IF NOT EXISTS settings(
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """
            )

    def list_books(self) -> list[Book]:
        with self._connect() as db:
            rows = db.execute("SELECT * FROM books ORDER BY last_opened DESC, added_at DESC").fetchall()
        return [self._book_from_row(row, include_chapters=False) for row in rows]

    def get_book(self, book_id: str, include_chapters: bool = True) -> Book | None:
        with self._connect() as db:
            row = db.execute("SELECT * FROM books WHERE id=?", (book_id,)).fetchone()
            if not row:
                return None
            book = self._book_from_row(row, include_chapters=False)
            if include_chapters:
                chapters = db.execute(
                    "SELECT chapter_index,title,text FROM chapters WHERE book_id=? ORDER BY chapter_index", (book_id,)
                ).fetchall()
                book.chapters = [Chapter(int(x["chapter_index"]), x["title"], x["text"]) for x in chapters]
            return book

    def import_book(self, source: str | Path) -> Book:
        source = Path(source).resolve()
        result = self.importer.import_file(source)
        book_id = uuid.uuid4().hex
        dest = self.paths["books"] / f"{book_id}{source.suffix.lower()}"
        shutil.copy2(source, dest)
        cover_path = ""
        if result.cover_bytes:
            ext = result.cover_extension if result.cover_extension.startswith(".") else "." + result.cover_extension
            cover = self.paths["covers"] / f"{book_id}{ext}"
            cover.write_bytes(result.cover_bytes)
            cover_path = str(cover)
        sample = "\n".join(ch.text for ch in result.chapters[:3])[:5000]
        language = result.language or detect_language(sample)
        now = int(time.time())
        book = Book(
            id=book_id,
            title=result.title or source.stem,
            author=result.author,
            language=language,
            isbn=result.isbn,
            source_path=str(source),
            stored_path=str(dest),
            cover_path=cover_path,
            format=source.suffix.lower().lstrip("."),
            last_opened=now,
            added_at=now,
            chapters=result.chapters,
        )
        with self._connect() as db:
            self._insert_book(db, book)
            db.executemany(
                "INSERT INTO chapters(book_id,chapter_index,title,text) VALUES(?,?,?,?)",
                [(book.id, ch.index, ch.title, ch.text) for ch in book.chapters],
            )
        return book

    def _insert_book(self, db: sqlite3.Connection, book: Book) -> None:
        db.execute(
            """INSERT INTO books(
            id,title,author,language,isbn,source_path,stored_path,cover_path,format,
            current_chapter,current_segment,progress,last_opened,added_at)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                book.id, book.title, book.author, book.language, book.isbn, book.source_path,
                book.stored_path, book.cover_path, book.format, book.current_chapter,
                book.current_segment, book.progress, book.last_opened, book.added_at,
            ),
        )

    def update_metadata(self, book_id: str, *, title: str | None = None, author: str | None = None,
                        language: str | None = None, isbn: str | None = None, cover_path: str | None = None) -> None:
        values: dict[str, str] = {}
        if title is not None and title.strip():
            values["title"] = title.strip()
        if author is not None and author.strip():
            values["author"] = author.strip()
        if language is not None and language.strip():
            values["language"] = language.strip()
        if isbn is not None and isbn.strip():
            values["isbn"] = isbn.strip()
        if cover_path is not None:
            values["cover_path"] = cover_path
        if not values:
            return
        fields = ",".join(f"{key}=?" for key in values)
        with self._connect() as db:
            params = (*values.values(), book_id)
            db.execute(f"UPDATE books SET {fields} WHERE id=?", params)

    def update_progress(self, book_id: str, chapter: int, segment: int, progress: float) -> None:
        now = int(time.time())
        with self._connect() as db:
            db.execute(
                "UPDATE books SET current_chapter=?,current_segment=?,progress=?,last_opened=? WHERE id=?",
                (chapter, segment, max(0.0, min(1.0, progress)), now, book_id),
            )

    def delete_book(self, book_id: str) -> None:
        book = self.get_book(book_id, include_chapters=False)
        if not book:
            return
        with self._connect() as db:
            db.execute("DELETE FROM books WHERE id=?", (book_id,))
        for value in (book.stored_path, book.cover_path):
            if value:
                Path(value).unlink(missing_ok=True)

    def setting(self, key: str, default=None):
        with self._connect() as db:
            row = db.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        if not row:
            return default
        try:
            return json.loads(row["value"])
        except json.JSONDecodeError:
            return default

    def set_setting(self, key: str, value) -> None:
        encoded = json.dumps(value, ensure_ascii=False)
        with self._connect() as db:
            db.execute(
                "INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                (key, encoded),
            )

    @staticmethod
    def _book_from_row(row: sqlite3.Row, include_chapters: bool = False) -> Book:
        return Book(
            id=row["id"], title=row["title"], author=row["author"], language=row["language"],
            isbn=row["isbn"], source_path=row["source_path"], stored_path=row["stored_path"],
            cover_path=row["cover_path"], format=row["format"], current_chapter=row["current_chapter"],
            current_segment=row["current_segment"], progress=row["progress"], last_opened=row["last_opened"],
            added_at=row["added_at"], chapters=[] if not include_chapters else [],
        )
