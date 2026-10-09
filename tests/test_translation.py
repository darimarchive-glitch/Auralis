from pathlib import Path

from auralis.db import LibraryDatabase
from auralis.models import Book, Chapter, TranslationOptions
from auralis.translation import BookTranslationService


class FakeProvider:
    name = "fake"
    def available(self): return True
    def translate(self, text, source, target): return f"[{target}] {text}"


def test_full_book_translation_uses_cache(tmp_path: Path):
    db = LibraryDatabase(tmp_path / "test.sqlite3")
    service = BookTranslationService(db)
    fake = FakeProvider()
    service.choose_provider = lambda quality: fake
    book = Book(id="b", title="Book", chapters=[Chapter(0, "One", "Hello world.")])
    options = TranslationOptions(source_language="en", target_language="pt")
    first = service.translate_book(book, options)
    second = service.translate_book(book, options)
    assert first == ["[pt] Hello world."]
    assert second == first
