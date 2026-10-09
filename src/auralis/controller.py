from __future__ import annotations

import threading
from pathlib import Path

from PySide6.QtCore import QObject, Property, QUrl, Signal, Slot
from PySide6.QtQml import QmlElement

from .covers import CoverResolver
from .db import LibraryDatabase
from .importer import BookImporter
from .models import TranslationOptions
from .translation import BookTranslationService

QML_IMPORT_NAME = "Auralis"
QML_IMPORT_MAJOR_VERSION = 1


@QmlElement
class AppController(QObject):
    libraryChanged = Signal()
    busyChanged = Signal()
    statusChanged = Signal()
    translationReady = Signal(str)
    errorOccurred = Signal(str)

    def __init__(self) -> None:
        super().__init__()
        self.db = LibraryDatabase()
        self.importer = BookImporter()
        self.covers = CoverResolver()
        self.translator = BookTranslationService(self.db)
        self._busy = False
        self._status = ""
        self._books = self.db.list_books()
        self._selected_book_id = self._books[0].id if self._books else ""

    @Property("QVariantList", notify=libraryChanged)
    def books(self):
        return [self._book_map(book) for book in self._books]

    @Property(bool, notify=busyChanged)
    def busy(self) -> bool:
        return self._busy

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Slot(str)
    def selectBook(self, book_id: str) -> None:
        self._selected_book_id = book_id

    @Slot(str)
    def importBook(self, path_or_url: str) -> None:
        path = QUrl(path_or_url).toLocalFile() if path_or_url.startswith("file:") else path_or_url
        if not path:
            return
        self._run_background(lambda: self._import(path))

    def _import(self, path: str) -> None:
        self._set_status("Importando livro…")
        book = self.importer.import_file(path)
        self._set_status("Procurando capa…")
        cover = self.covers.resolve(book)
        if cover:
            book.cover_path = cover
        self.db.save_book(book)
        self._books = self.db.list_books()
        self._selected_book_id = book.id
        self.libraryChanged.emit()

    @Slot(str, str, str, str, bool)
    def translateText(self, text: str, source: str, target: str, mode: str, studio: bool) -> None:
        options = TranslationOptions(
            source_language=source or "auto",
            target_language=target or "pt",
            quality="studio" if studio else "smart",
            literary_mode=mode or "faithful",
            post_edit=studio,
        )
        self._run_background(lambda: self._translate_text(text, options))

    def _translate_text(self, text: str, options: TranslationOptions) -> None:
        self._set_status("Traduzindo localmente…")
        result = self.translator.translate_text(text, options)
        self.translationReady.emit(result.text)

    @Slot(str, str, str, bool)
    def translateSelectedBook(self, target: str, source: str, mode: str, studio: bool) -> None:
        book = next((b for b in self._books if b.id == self._selected_book_id), None)
        if not book:
            self.errorOccurred.emit("Selecione um livro primeiro.")
            return
        options = TranslationOptions(
            source_language=source or book.language or "auto",
            target_language=target or "pt",
            quality="studio" if studio else "smart",
            literary_mode=mode or "faithful",
            post_edit=studio,
        )
        self._run_background(lambda: self._translate_book(book, options))

    def _translate_book(self, book, options) -> None:
        def on_progress(p):
            self._set_status(f"{p.message} • trecho {p.chunk}/{p.chunk_count}")
        chapters = self.translator.translate_book(book, options, progress=on_progress)
        book.active_translation = options.target_language
        self.db.save_book(book)
        self._books = self.db.list_books()
        self.libraryChanged.emit()
        self.translationReady.emit("\n\n".join(chapters))

    @Slot(str, result=str)
    def bookText(self, book_id: str) -> str:
        book = next((b for b in self._books if b.id == book_id), None)
        return "\n\n".join(chapter.text for chapter in book.chapters) if book else ""

    @staticmethod
    def _book_map(book):
        return {
            "id": book.id,
            "title": book.title,
            "author": book.author,
            "language": book.language,
            "format": book.format.upper(),
            "cover": QUrl.fromLocalFile(book.cover_path).toString() if book.cover_path else "",
            "progress": book.progress,
            "translation": book.active_translation,
        }

    def _run_background(self, fn) -> None:
        if self._busy:
            return
        self._busy = True
        self.busyChanged.emit()

        def worker():
            try:
                fn()
            except Exception as exc:
                self.errorOccurred.emit(str(exc))
            finally:
                self._busy = False
                self._status = ""
                self.busyChanged.emit()
                self.statusChanged.emit()

        threading.Thread(target=worker, daemon=True).start()

    def _set_status(self, value: str) -> None:
        self._status = value
        self.statusChanged.emit()
