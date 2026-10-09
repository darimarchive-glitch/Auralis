from __future__ import annotations

import hashlib
import json
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from .models import Book, Chapter
from .paths import app_data_dir

SCHEMA = """
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS books (
  id TEXT PRIMARY KEY,
  metadata_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS translations (
  book_id TEXT NOT NULL,
  chapter_index INTEGER NOT NULL,
  target_language TEXT NOT NULL,
  literary_mode TEXT NOT NULL,
  provider TEXT NOT NULL,
  source_hash TEXT NOT NULL,
  translated_text TEXT NOT NULL,
  PRIMARY KEY (book_id, chapter_index, target_language, literary_mode, provider)
);
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
"""


class LibraryDatabase:
    def __init__(self, path: Path | None = None) -> None:
        self.path = path or (app_data_dir() / "library.sqlite3")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.executescript(SCHEMA)

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        db = sqlite3.connect(self.path)
        db.row_factory = sqlite3.Row
        try:
            yield db
            db.commit()
        finally:
            db.close()

    def save_book(self, book: Book) -> None:
        payload = json.dumps(book.to_dict(), ensure_ascii=False)
        with self.connect() as db:
            db.execute(
                "INSERT INTO books(id, metadata_json) VALUES(?, ?) "
                "ON CONFLICT(id) DO UPDATE SET metadata_json=excluded.metadata_json",
                (book.id, payload),
            )

    def list_books(self) -> list[Book]:
        with self.connect() as db:
            rows = db.execute("SELECT metadata_json FROM books ORDER BY rowid DESC").fetchall()
        return [self._book_from_json(row[0]) for row in rows]

    def get_book(self, book_id: str) -> Book | None:
        with self.connect() as db:
            row = db.execute("SELECT metadata_json FROM books WHERE id=?", (book_id,)).fetchone()
        return self._book_from_json(row[0]) if row else None

    def delete_book(self, book_id: str) -> None:
        with self.connect() as db:
            db.execute("DELETE FROM translations WHERE book_id=?", (book_id,))
            db.execute("DELETE FROM books WHERE id=?", (book_id,))

    def cached_translation(
        self,
        *,
        book_id: str,
        chapter_index: int,
        target_language: str,
        literary_mode: str,
        provider: str,
        source_text: str,
    ) -> str | None:
        source_hash = self.hash_text(source_text)
        with self.connect() as db:
            row = db.execute(
                "SELECT translated_text, source_hash FROM translations "
                "WHERE book_id=? AND chapter_index=? AND target_language=? "
                "AND literary_mode=? AND provider=?",
                (book_id, chapter_index, target_language, literary_mode, provider),
            ).fetchone()
        if row and row["source_hash"] == source_hash:
            return str(row["translated_text"])
        return None

    def store_translation(
        self,
        *,
        book_id: str,
        chapter_index: int,
        target_language: str,
        literary_mode: str,
        provider: str,
        source_text: str,
        translated_text: str,
    ) -> None:
        with self.connect() as db:
            db.execute(
                "INSERT INTO translations(book_id, chapter_index, target_language, literary_mode, "
                "provider, source_hash, translated_text) VALUES(?,?,?,?,?,?,?) "
                "ON CONFLICT(book_id, chapter_index, target_language, literary_mode, provider) "
                "DO UPDATE SET source_hash=excluded.source_hash, translated_text=excluded.translated_text",
                (
                    book_id,
                    chapter_index,
                    target_language,
                    literary_mode,
                    provider,
                    self.hash_text(source_text),
                    translated_text,
                ),
            )

    def set_setting(self, key: str, value: object) -> None:
        with self.connect() as db:
            db.execute(
                "INSERT INTO settings(key,value) VALUES(?,?) "
                "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                (key, json.dumps(value, ensure_ascii=False)),
            )

    def get_setting(self, key: str, default: object = None) -> object:
        with self.connect() as db:
            row = db.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return json.loads(row[0]) if row else default

    @staticmethod
    def hash_text(text: str) -> str:
        return hashlib.sha256(text.encode("utf-8")).hexdigest()

    @staticmethod
    def _book_from_json(payload: str) -> Book:
        data = json.loads(payload)
        data["chapters"] = [Chapter(**chapter) for chapter in data.get("chapters", [])]
        return Book(**data)
