from __future__ import annotations

import tempfile
import threading
from pathlib import Path

from PySide6.QtCore import QFile, QIODevice, QObject, Property, QUrl, Signal, Slot
from PySide6.QtQml import QmlElement

from .covers import CoverResolver
from .db import LibraryDatabase
from .importer import BookImporter
from .models import TranslationOptions
from .text import narration_chunks
from .translation import BookTranslationService

QML_IMPORT_NAME = "Auralis"
QML_IMPORT_MAJOR_VERSION = 1


@QmlElement
class AppController(QObject):
    libraryChanged = Signal()
    busyChanged = Signal()
    statusChanged = Signal()
    selectedBookChanged = Signal()
    readerChanged = Signal()
    settingsChanged = Signal()
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
        self._use_translation = bool(self.db.get_setting("reader.use_translation", False))
        self._speech_rate = float(self.db.get_setting("speech.rate", 1.0))
        self._preferred_voice = str(self.db.get_setting("speech.voice", ""))

    @Property("QVariantList", notify=libraryChanged)
    def books(self):
        return [self._book_map(book) for book in self._books]

    @Property(bool, notify=busyChanged)
    def busy(self) -> bool:
        return self._busy

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Property(str, notify=selectedBookChanged)
    def selectedBookId(self) -> str:
        return self._selected_book_id

    @Property(str, notify=selectedBookChanged)
    def selectedBookTitle(self) -> str:
        book = self._selected_book()
        return book.title if book else "Nenhum livro selecionado"

    @Property(str, notify=selectedBookChanged)
    def selectedBookAuthor(self) -> str:
        book = self._selected_book()
        return book.author if book else ""

    @Property(str, notify=selectedBookChanged)
    def selectedBookCover(self) -> str:
        book = self._selected_book()
        return QUrl.fromLocalFile(book.cover_path).toString() if book and book.cover_path else ""

    @Property(str, notify=readerChanged)
    def readerText(self) -> str:
        book = self._selected_book()
        if not book or not book.chapters:
            return ""
        chapter = book.chapters[max(0, min(book.current_chapter, len(book.chapters) - 1))]
        if self._use_translation and book.active_translation:
            translated = self.db.latest_translation(
                book_id=book.id,
                chapter_index=chapter.index,
                target_language=book.active_translation,
            )
            if translated:
                return translated
        return chapter.text

    @Property(str, notify=readerChanged)
    def readerLanguage(self) -> str:
        book = self._selected_book()
        if not book:
            return "pt-BR"
        if self._use_translation and book.active_translation:
            return self._locale_for(book.active_translation)
        return self._locale_for(book.language)

    @Property(str, notify=readerChanged)
    def readerChapterTitle(self) -> str:
        book = self._selected_book()
        if not book or not book.chapters:
            return ""
        return book.chapters[max(0, min(book.current_chapter, len(book.chapters) - 1))].title

    @Property(int, notify=readerChanged)
    def readerChapter(self) -> int:
        book = self._selected_book()
        return (book.current_chapter + 1) if book else 0

    @Property(int, notify=readerChanged)
    def readerChapterCount(self) -> int:
        book = self._selected_book()
        return len(book.chapters) if book else 0

    @Property(int, notify=readerChanged)
    def readerOffset(self) -> int:
        book = self._selected_book()
        return min(book.current_offset, len(self.readerText)) if book else 0

    @Property(float, notify=readerChanged)
    def readerProgress(self) -> float:
        book = self._selected_book()
        return book.progress if book else 0.0

    @Property(bool, notify=readerChanged)
    def readerTranslationAvailable(self) -> bool:
        book = self._selected_book()
        return bool(book and book.active_translation and self.db.has_translation(
            book_id=book.id,
            target_language=book.active_translation,
        ))

    @Property(bool, notify=readerChanged)
    def readerUseTranslation(self) -> bool:
        return self._use_translation

    @Property(float, notify=settingsChanged)
    def speechRate(self) -> float:
        return self._speech_rate

    @Property(str, notify=settingsChanged)
    def preferredVoice(self) -> str:
        return self._preferred_voice

    @Slot(str)
    def selectBook(self, book_id: str) -> None:
        if not any(book.id == book_id for book in self._books):
            return
        self._selected_book_id = book_id
        self.selectedBookChanged.emit()
        self.readerChanged.emit()

    @Slot(str)
    def importBook(self, path_or_url: str) -> None:
        if not path_or_url:
            return
        try:
            path = self._materialize_url(path_or_url)
        except Exception as exc:
            self.errorOccurred.emit(f"Não foi possível abrir esse arquivo: {exc}")
            return
        self._run_background(lambda: self._import(path))

    def _materialize_url(self, value: str) -> str:
        url = QUrl(value)
        if url.isLocalFile():
            return url.toLocalFile()
        if not url.scheme():
            return value
        # Android file pickers often return content:// URIs. QFile uses Qt's Android file engine,
        # so copying through it avoids assuming that a content URI is a POSIX path.
        source = QFile(value)
        if not source.open(QIODevice.ReadOnly):
            raise OSError(source.errorString())
        suffix = Path(url.fileName()).suffix or ".epub"
        temp = tempfile.NamedTemporaryFile(prefix="auralis-import-", suffix=suffix, delete=False)
        try:
            while not source.atEnd():
                temp.write(bytes(source.read(1024 * 1024)))
        finally:
            temp.close()
            source.close()
        return temp.name

    def _import(self, path: str) -> None:
        self._set_status("Importando livro…")
        book = self.importer.import_file(path)
        self._set_status("Procurando uma capa compatível…")
        cover = self.covers.resolve(book)
        if cover:
            book.cover_path = cover
        self.db.save_book(book)
        self._books = self.db.list_books()
        self._selected_book_id = book.id
        self.libraryChanged.emit()
        self.selectedBookChanged.emit()
        self.readerChanged.emit()

    @Slot()
    def previousChapter(self) -> None:
        book = self._selected_book()
        if not book or book.current_chapter <= 0:
            return
        book.current_chapter -= 1
        book.current_offset = 0
        self._save_progress(book)

    @Slot()
    def nextChapter(self) -> None:
        book = self._selected_book()
        if not book or book.current_chapter >= len(book.chapters) - 1:
            return
        book.current_chapter += 1
        book.current_offset = 0
        self._save_progress(book)

    @Slot(int)
    def setReaderOffset(self, offset: int) -> None:
        book = self._selected_book()
        if not book:
            return
        text_len = max(1, len(self.readerText))
        book.current_offset = max(0, min(int(offset), text_len))
        chapter_part = book.current_offset / text_len
        book.progress = min(1.0, (book.current_chapter + chapter_part) / max(1, len(book.chapters)))
        self.db.save_book(book)
        self.readerChanged.emit()
        self.libraryChanged.emit()

    @Slot(bool)
    def setReaderUseTranslation(self, value: bool) -> None:
        self._use_translation = bool(value) and self.readerTranslationAvailable
        self.db.set_setting("reader.use_translation", self._use_translation)
        self.readerChanged.emit()

    @Slot(float)
    def setSpeechRate(self, value: float) -> None:
        self._speech_rate = max(0.6, min(2.0, float(value)))
        self.db.set_setting("speech.rate", self._speech_rate)
        self.settingsChanged.emit()

    @Slot(str)
    def setPreferredVoice(self, value: str) -> None:
        self._preferred_voice = value
        self.db.set_setting("speech.voice", value)
        self.settingsChanged.emit()

    @Slot(int, result="QVariantList")
    def readerSpeechChunks(self, offset: int):
        return [
            {"text": chunk.text, "start": chunk.start, "length": chunk.length}
            for chunk in narration_chunks(self.readerText, offset, max_chars=850)
        ]

    @Slot(str, str, str, str, bool)
    def translateText(self, text: str, source: str, target: str, mode: str, studio: bool) -> None:
        options = self._translation_options(source, target, mode, studio)
        self._run_background(lambda: self._translate_text(text, options))

    def _translate_text(self, text: str, options: TranslationOptions) -> None:
        self._set_status("Traduzindo localmente…")
        result = self.translator.translate_text(text, options)
        self.translationReady.emit(result.text)

    @Slot(str, str, str, bool)
    def translateSelectedBook(self, target: str, source: str, mode: str, studio: bool) -> None:
        book = self._selected_book()
        if not book:
            self.errorOccurred.emit("Selecione um livro primeiro.")
            return
        options = self._translation_options(source or book.language, target, mode, studio)
        self._run_background(lambda: self._translate_book(book, options))

    def _translate_book(self, book, options) -> None:
        def on_progress(p):
            self._set_status(f"{p.message} • trecho {p.chunk}/{p.chunk_count}")
        chapters = self.translator.translate_book(book, options, progress=on_progress)
        book.active_translation = options.target_language
        self.db.save_book(book)
        self._books = self.db.list_books()
        self._use_translation = True
        self.db.set_setting("reader.use_translation", True)
        self.libraryChanged.emit()
        self.selectedBookChanged.emit()
        self.readerChanged.emit()
        self.translationReady.emit("\n\n".join(chapters))

    @Slot(str, result=str)
    def bookText(self, book_id: str) -> str:
        book = next((b for b in self._books if b.id == book_id), None)
        return "\n\n".join(chapter.text for chapter in book.chapters) if book else ""

    @Slot(result=str)
    def translationCapability(self) -> str:
        if self.translator.madlad.available():
            return "IA local MADLAD disponível"
        if self.translator.argos.available():
            return "Tradutor offline leve disponível"
        return "Instale o pacote de tradução local nas configurações deste build."

    def _selected_book(self):
        return next((book for book in self._books if book.id == self._selected_book_id), None)

    def _save_progress(self, book) -> None:
        book.progress = min(1.0, book.current_chapter / max(1, len(book.chapters)))
        self.db.save_book(book)
        self.readerChanged.emit()
        self.libraryChanged.emit()

    @staticmethod
    def _translation_options(source: str, target: str, mode: str, studio: bool) -> TranslationOptions:
        return TranslationOptions(
            source_language=source or "auto",
            target_language=target or "pt",
            quality="studio" if studio else "smart",
            literary_mode=mode or "faithful",
            post_edit=studio,
        )

    @staticmethod
    def _locale_for(language: str) -> str:
        mapping = {
            "pt": "pt-BR", "pt-br": "pt-BR", "en": "en-US", "es": "es-ES",
            "fr": "fr-FR", "de": "de-DE", "it": "it-IT", "ja": "ja-JP",
            "ko": "ko-KR", "zh": "zh-CN", "ru": "ru-RU", "ar": "ar-SA",
            "hi": "hi-IN", "la": "la", "el": "el-GR", "und": "pt-BR",
        }
        return mapping.get((language or "und").casefold(), language or "pt-BR")

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
            "progressPercent": round(book.progress * 100),
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
