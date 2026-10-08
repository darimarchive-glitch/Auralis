from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PySide6.QtCore import QObject, Property, QUrl, Signal, Slot

from .metadata import MetadataResolver
from .model_manager import SupertonicModelManager
from .models import Book
from .paths import ensure_layout
from .storage import LibraryStore
from .text import segment_for_speech
from .tts import NarrationEngine


class Backend(QObject):
    booksChanged = Signal()
    readerChanged = Signal()
    busyChanged = Signal()
    settingsChanged = Signal()
    narrationChanged = Signal()
    toast = Signal(str)
    modelProgress = Signal(float, str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.paths = ensure_layout()
        self.store = LibraryStore(self.paths["root"])
        self.metadata = MetadataResolver()
        self.model_manager = SupertonicModelManager(self.paths["models"])
        self.narration = NarrationEngine(self.paths["audio_cache"], self.model_manager, self)
        self.pool = ThreadPoolExecutor(max_workers=3, thread_name_prefix="auralis-worker")
        self._busy = False
        self._status = ""
        self._current_book: Book | None = None
        self._current_segments = []
        self._current_segment = 0
        self.narration.segmentChanged.connect(self._segment_changed)
        self.narration.playingChanged.connect(lambda _: self.narrationChanged.emit())
        self.narration.errorOccurred.connect(lambda message: self.toast.emit(f"Narração: {message}"))

    def _book_dict(self, book: Book) -> dict:
        data = book.to_dict()
        data["coverUrl"] = QUrl.fromLocalFile(book.cover_path).toString() if book.cover_path else ""
        data["progressText"] = f"{round(book.progress * 100)}%"
        return data

    @Property("QVariantList", notify=booksChanged)
    def books(self):
        return [self._book_dict(book) for book in self.store.list_books()]

    @Property("QVariantMap", notify=readerChanged)
    def currentBook(self):
        return self._book_dict(self._current_book) if self._current_book else {}

    @Property("QVariantList", notify=readerChanged)
    def chapters(self):
        if not self._current_book:
            return []
        return [{"index": ch.index, "title": ch.title} for ch in self._current_book.chapters]

    @Property("QVariantList", notify=readerChanged)
    def segments(self):
        return [{"index": s.index, "text": s.text, "kind": s.kind, "language": s.language} for s in self._current_segments]

    @Property(int, notify=narrationChanged)
    def currentSegment(self) -> int:
        return self._current_segment

    @Property(bool, notify=narrationChanged)
    def playing(self) -> bool:
        return bool(self.narration._playing)

    @Property(bool, notify=busyChanged)
    def busy(self) -> bool:
        return self._busy

    @Property(str, notify=busyChanged)
    def status(self) -> str:
        return self._status

    @Property(bool, notify=settingsChanged)
    def automaticCovers(self) -> bool:
        return bool(self.store.setting("automatic_covers", True))

    @Property(bool, notify=settingsChanged)
    def neuralModelInstalled(self) -> bool:
        return self.model_manager.installed()

    @Property(bool, notify=settingsChanged)
    def neuralRuntimeAvailable(self) -> bool:
        try:
            import sherpa_onnx  # noqa: F401
            return True
        except Exception:
            return False

    @Property(bool, notify=settingsChanged)
    def preferNeural(self) -> bool:
        return bool(self.store.setting("prefer_neural", True))

    @Property(float, notify=settingsChanged)
    def narrationRate(self) -> float:
        return float(self.store.setting("narration_rate", 1.0))

    def _set_busy(self, value: bool, status: str = "") -> None:
        self._busy = value
        self._status = status
        self.busyChanged.emit()

    @Slot(str)
    def importFile(self, value: str) -> None:
        url = QUrl(value)
        path = Path(url.toLocalFile() if url.isLocalFile() else value)
        if not path.exists():
            self.toast.emit("Arquivo não encontrado.")
            return
        self._set_busy(True, "Importando e entendendo o livro…")

        def work() -> None:
            try:
                book = self.store.import_book(path)
                if self.automaticCovers and not book.cover_path:
                    self._resolve_metadata_sync(book.id)
                self.booksChanged.emit()
                self.toast.emit(f"{book.title} adicionado à biblioteca.")
            except Exception as exc:
                self.toast.emit(f"Não foi possível importar: {exc}")
            finally:
                self._set_busy(False)
        self.pool.submit(work)

    @Slot(str)
    def openBook(self, book_id: str) -> None:
        book = self.store.get_book(book_id, include_chapters=True)
        if not book:
            self.toast.emit("Livro não encontrado.")
            return
        self.narration.stop()
        self._current_book = book
        chapter_index = max(0, min(book.current_chapter, len(book.chapters) - 1)) if book.chapters else 0
        self._load_chapter(chapter_index, book.current_segment)
        self.readerChanged.emit()
        self.narrationChanged.emit()

    @Slot()
    def closeBook(self) -> None:
        self.narration.stop()
        self._current_book = None
        self._current_segments = []
        self._current_segment = 0
        self.readerChanged.emit()
        self.narrationChanged.emit()

    @Slot(int)
    def setChapter(self, chapter_index: int) -> None:
        if not self._current_book or not self._current_book.chapters:
            return
        self.narration.stop()
        chapter_index = max(0, min(chapter_index, len(self._current_book.chapters) - 1))
        self._load_chapter(chapter_index, 0)
        self.readerChanged.emit()
        self.narrationChanged.emit()

    def _load_chapter(self, chapter_index: int, segment_index: int) -> None:
        if not self._current_book:
            return
        chapter = self._current_book.chapters[chapter_index]
        self._current_book.current_chapter = chapter_index
        self._current_segments = segment_for_speech(chapter.text, self._current_book.language)
        self._current_segment = max(0, min(segment_index, len(self._current_segments) - 1)) if self._current_segments else 0
        self._save_progress()

    @Slot()
    def toggleNarration(self) -> None:
        if not self._current_book or not self._current_segments:
            return
        if self.narration._playing:
            self.narration.stop()
            return
        mode = "neural" if self.preferNeural else "system"
        self.narration.start(
            self._current_segments,
            self._current_segment,
            mode=mode,
            language=self._current_book.language or "pt-BR",
            rate=self.narrationRate,
            voice_id=int(self.store.setting("voice_id", 0)),
            steps=int(self.store.setting("neural_steps", 8)),
        )

    @Slot(int)
    def seekSegment(self, index: int) -> None:
        if not self._current_segments:
            return
        self._current_segment = max(0, min(index, len(self._current_segments) - 1))
        if self.narration._playing:
            self.narration.seek(self._current_segment)
        self._save_progress()
        self.narrationChanged.emit()

    @Slot(str)
    def refreshMetadata(self, book_id: str) -> None:
        self._set_busy(True, "Procurando capa e metadados…")

        def work() -> None:
            try:
                if self._resolve_metadata_sync(book_id, force_cover=True):
                    self.toast.emit("Capa e metadados atualizados.")
                    self.booksChanged.emit()
                    if self._current_book and self._current_book.id == book_id:
                        self._current_book = self.store.get_book(book_id, include_chapters=True)
                        self.readerChanged.emit()
                else:
                    self.toast.emit("Não encontrei uma correspondência confiável para este livro.")
            finally:
                self._set_busy(False)
        self.pool.submit(work)

    def _resolve_metadata_sync(self, book_id: str, force_cover: bool = False) -> bool:
        book = self.store.get_book(book_id, include_chapters=False)
        if not book:
            return False
        candidate = self.metadata.resolve(book)
        if not candidate:
            return False
        cover_path = None
        if candidate.cover_url and (force_cover or not book.cover_path):
            destination = self.paths["covers"] / f"{book.id}-online.jpg"
            if self.metadata.download_cover(candidate, destination):
                cover_path = str(destination)
        self.store.update_metadata(
            book.id,
            author=(candidate.author if not book.author else None),
            language=(candidate.language if not book.language else None),
            isbn=(candidate.isbn if not book.isbn else None),
            cover_path=cover_path,
        )
        return bool(cover_path or candidate.author or candidate.isbn)

    @Slot(str)
    def deleteBook(self, book_id: str) -> None:
        if self._current_book and self._current_book.id == book_id:
            self.closeBook()
        self.store.delete_book(book_id)
        self.booksChanged.emit()
        self.toast.emit("Livro removido.")

    @Slot(bool)
    def setAutomaticCovers(self, value: bool) -> None:
        self.store.set_setting("automatic_covers", bool(value))
        self.settingsChanged.emit()

    @Slot(bool)
    def setPreferNeural(self, value: bool) -> None:
        self.store.set_setting("prefer_neural", bool(value))
        self.settingsChanged.emit()

    @Slot(float)
    def setNarrationRate(self, value: float) -> None:
        self.store.set_setting("narration_rate", max(0.5, min(2.0, float(value))))
        self.settingsChanged.emit()

    @Slot(int)
    def setVoiceId(self, value: int) -> None:
        self.store.set_setting("voice_id", max(0, min(9, int(value))))
        self.settingsChanged.emit()

    @Slot()
    def installNeuralModel(self) -> None:
        if not self.neuralRuntimeAvailable:
            self.toast.emit("Este build ainda não contém o runtime neural para esta plataforma.")
            return
        if self.model_manager.installed():
            self.toast.emit("A voz neural já está instalada.")
            return
        self._set_busy(True, "Baixando voz neural…")

        def progress(value: float, message: str) -> None:
            self.modelProgress.emit(value, message)

        def work() -> None:
            try:
                self.model_manager.install(progress)
                self.toast.emit("Voz neural instalada.")
                self.settingsChanged.emit()
            except Exception as exc:
                self.toast.emit(f"Falha ao instalar voz neural: {exc}")
            finally:
                self._set_busy(False)
        self.pool.submit(work)

    @Slot(int)
    def _segment_changed(self, index: int) -> None:
        self._current_segment = index
        self._save_progress()
        self.narrationChanged.emit()

    def _save_progress(self) -> None:
        if not self._current_book:
            return
        chapter = self._current_book.current_chapter
        segment_count = max(1, len(self._current_segments))
        segment_part = self._current_segment / segment_count
        chapter_count = max(1, len(self._current_book.chapters))
        progress = min(1.0, (chapter + segment_part) / chapter_count)
        self._current_book.current_segment = self._current_segment
        self._current_book.progress = progress
        self.store.update_progress(self._current_book.id, chapter, self._current_segment, progress)
