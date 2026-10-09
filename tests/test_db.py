from pathlib import Path

from auralis.db import LibraryDatabase
from auralis.models import Book, Chapter


def test_book_roundtrip(tmp_path: Path):
    db = LibraryDatabase(tmp_path / "test.sqlite3")
    book = Book(id="abc", title="Teste", chapters=[Chapter(0, "Um", "Texto")])
    db.save_book(book)
    loaded = db.get_book("abc")
    assert loaded is not None
    assert loaded.title == "Teste"
    assert loaded.chapters[0].text == "Texto"


def test_translation_cache_invalidates_when_source_changes(tmp_path: Path):
    db = LibraryDatabase(tmp_path / "test.sqlite3")
    db.store_translation(
        book_id="b", chapter_index=0, target_language="pt", literary_mode="faithful",
        provider="fake", source_text="hello", translated_text="olá",
    )
    assert db.cached_translation(
        book_id="b", chapter_index=0, target_language="pt", literary_mode="faithful",
        provider="fake", source_text="hello",
    ) == "olá"
    assert db.cached_translation(
        book_id="b", chapter_index=0, target_language="pt", literary_mode="faithful",
        provider="fake", source_text="changed",
    ) is None


def test_latest_translation(tmp_path):
    from auralis.db import LibraryDatabase
    db = LibraryDatabase(tmp_path / "db.sqlite3")
    db.store_translation(
        book_id="b", chapter_index=0, target_language="pt", literary_mode="faithful",
        provider="test", source_text="hello", translated_text="olá"
    )
    assert db.latest_translation(book_id="b", chapter_index=0, target_language="pt") == "olá"
    assert db.has_translation(book_id="b", target_language="pt")
