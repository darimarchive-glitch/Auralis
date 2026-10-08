from __future__ import annotations

import hashlib
import threading
from concurrent.futures import Future, ThreadPoolExecutor
from pathlib import Path

from PySide6.QtCore import QObject, QLocale, Signal, Slot, QUrl
from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer
from PySide6.QtTextToSpeech import QTextToSpeech

from .model_manager import SupertonicModelManager
from .text import SpeechSegment


class NeuralRenderer:
    def __init__(self, manager: SupertonicModelManager) -> None:
        self.manager = manager
        self._lock = threading.Lock()
        self._tts = None

    def available(self) -> bool:
        if not self.manager.installed():
            return False
        try:
            import sherpa_onnx  # noqa: F401
            return True
        except Exception:
            return False

    def _engine(self):
        if self._tts is not None:
            return self._tts
        import sherpa_onnx

        paths = self.manager.config()
        model = sherpa_onnx.OfflineTtsSupertonicModelConfig(
            duration_predictor=paths["duration_predictor.int8.onnx"],
            text_encoder=paths["text_encoder.int8.onnx"],
            vector_estimator=paths["vector_estimator.int8.onnx"],
            vocoder=paths["vocoder.int8.onnx"],
            tts_json=paths["tts.json"],
            unicode_indexer=paths["unicode_indexer.bin"],
            voice_style=paths["voice.bin"],
        )
        config = sherpa_onnx.OfflineTtsConfig(
            model=sherpa_onnx.OfflineTtsModelConfig(
                supertonic=model,
                num_threads=2,
                debug=False,
                provider="cpu",
            ),
            max_num_sentences=1,
        )
        self._tts = sherpa_onnx.OfflineTts(config)
        return self._tts

    def render(self, text: str, output: Path, *, language: str, voice_id: int, speed: float, steps: int) -> Path:
        if output.is_file() and output.stat().st_size > 100:
            return output
        import sherpa_onnx

        output.parent.mkdir(parents=True, exist_ok=True)
        lang = language.lower().replace("_", "-").split("-")[0]
        with self._lock:
            tts = self._engine()
            config = sherpa_onnx.OfflineTtsGenerationConfig(
                sid=max(0, min(9, int(voice_id))),
                speed=max(0.65, min(1.45, float(speed))),
                num_steps=max(6, min(16, int(steps))),
                silence_scale=0.16,
                extra={"lang": lang},
            )
            audio = tts.generate_with_config(text=text, config=config)
            ok = sherpa_onnx.write_wave(str(output), audio.samples, audio.sample_rate)
            if not ok:
                raise RuntimeError("Não foi possível gravar o áudio neural.")
        return output


class NarrationEngine(QObject):
    segmentChanged = Signal(int)
    playingChanged = Signal(bool)
    errorOccurred = Signal(str)
    renderReady = Signal(int, str)

    def __init__(self, cache_dir: Path, model_manager: SupertonicModelManager, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.cache_dir = cache_dir
        self.system = QTextToSpeech(self)
        self.audio = QAudioOutput(self)
        self.player = QMediaPlayer(self)
        self.player.setAudioOutput(self.audio)
        self.renderer = NeuralRenderer(model_manager)
        self.executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="auralis-tts")
        self._segments: list[SpeechSegment] = []
        self._index = 0
        self._playing = False
        self._mode = "system"
        self._language = "pt-BR"
        self._rate = 1.0
        self._voice_id = 0
        self._steps = 8
        self._futures: dict[int, Future] = {}
        self._generation = 0
        self._system_speaking = False
        self._system_ids: dict[int, int] = {}
        self._system_queued_until = -1
        self.renderReady.connect(self._on_render_ready)
        self.player.mediaStatusChanged.connect(self._media_status)
        self.system.stateChanged.connect(self._system_state)
        try:
            self.system.aboutToSynthesize.connect(self._system_about_to_synthesize)
        except Exception:
            pass

    @property
    def index(self) -> int:
        return self._index

    def neural_available(self) -> bool:
        return self.renderer.available()

    @Slot()
    def stop(self) -> None:
        self._generation += 1
        self._playing = False
        self._system_speaking = False
        self._system_ids.clear()
        self._system_queued_until = -1
        self.player.stop()
        self.system.stop()
        for future in self._futures.values():
            future.cancel()
        self._futures.clear()
        self.playingChanged.emit(False)

    def start(self, segments: list[SpeechSegment], index: int = 0, *, mode: str = "neural",
              language: str = "pt-BR", rate: float = 1.0, voice_id: int = 0, steps: int = 8) -> None:
        self.stop()
        self._segments = segments
        if not segments:
            return
        self._index = max(0, min(index, len(segments) - 1))
        self._mode = mode if mode == "neural" and self.neural_available() else "system"
        self._language = language or "pt-BR"
        self._rate = max(0.5, min(2.0, rate))
        self._voice_id = voice_id
        self._steps = steps
        self._playing = True
        self.playingChanged.emit(True)
        self.segmentChanged.emit(self._index)
        if self._mode == "neural":
            self._prefetch()
            self._play_neural(self._index)
        else:
            self._speak_system()

    def seek(self, index: int) -> None:
        if not self._segments:
            return
        was_playing = self._playing
        mode, lang, rate, voice, steps = self._mode, self._language, self._rate, self._voice_id, self._steps
        self.stop()
        self._index = max(0, min(index, len(self._segments) - 1))
        self.segmentChanged.emit(self._index)
        if was_playing:
            self.start(self._segments, self._index, mode=mode, language=lang, rate=rate, voice_id=voice, steps=steps)

    def _cache_path(self, segment: SpeechSegment) -> Path:
        key = hashlib.sha256(
            f"{segment.cache_key}|{self._language}|{self._voice_id}|{self._rate:.3f}|{self._steps}".encode()
        ).hexdigest()
        return self.cache_dir / key[:2] / f"{key}.wav"

    def _prefetch(self) -> None:
        generation = self._generation
        for idx in range(self._index, min(len(self._segments), self._index + 4)):
            if idx in self._futures:
                continue
            path = self._cache_path(self._segments[idx])
            if path.is_file():
                self.renderReady.emit(idx, str(path))
                continue
            segment = self._segments[idx]
            future = self.executor.submit(
                self.renderer.render,
                segment.text,
                path,
                language=segment.language or self._language,
                voice_id=self._voice_id,
                speed=max(0.65, min(1.45, self._rate)),
                steps=self._steps,
            )
            self._futures[idx] = future

            def done(fut: Future, i: int = idx, gen: int = generation) -> None:
                self._futures.pop(i, None)
                if gen != self._generation or fut.cancelled():
                    return
                try:
                    result = fut.result()
                    self.renderReady.emit(i, str(result))
                except Exception as exc:
                    self.errorOccurred.emit(str(exc))
            future.add_done_callback(done)

    def _play_neural(self, index: int) -> None:
        path = self._cache_path(self._segments[index])
        if path.is_file():
            self.player.setSource(QUrl.fromLocalFile(str(path)))
            self.player.play()
        else:
            self._prefetch()

    @Slot(int, str)
    def _on_render_ready(self, index: int, path: str) -> None:
        if not self._playing or self._mode != "neural" or index != self._index:
            return
        if self.player.playbackState() != QMediaPlayer.PlaybackState.PlayingState:
            self.player.setSource(QUrl.fromLocalFile(path))
            self.player.play()
        self._prefetch()

    @Slot(object)
    def _media_status(self, status) -> None:
        if status == QMediaPlayer.MediaStatus.EndOfMedia and self._playing and self._mode == "neural":
            self._advance()

    def _select_system_voice(self) -> None:
        voices = list(self.system.availableVoices())
        if not voices:
            return
        keywords = ("neural", "natural", "studio", "enhanced", "google", "premium", "online")

        def score(voice) -> tuple[int, int]:
            name = voice.name().casefold()
            keyword_score = sum(1 for word in keywords if word in name)
            adult_score = 1 if "adult" in str(voice.age()).casefold() else 0
            return keyword_score, adult_score

        voices.sort(key=score, reverse=True)
        try:
            self.system.setVoice(voices[0])
        except Exception:
            pass

    def _speak_system(self) -> None:
        if not self._playing or not self._segments:
            return
        self.system.setLocale(QLocale(self._language))
        self._select_system_voice()
        qt_rate = max(-1.0, min(1.0, (self._rate - 1.0) * 0.9))
        self.system.setRate(qt_rate)
        self._system_speaking = True
        self._system_ids.clear()
        self._system_queued_until = self._index - 1
        self._fill_system_queue()

    def _fill_system_queue(self) -> None:
        if not self._playing or self._mode != "system":
            return
        target = min(len(self._segments), self._index + 8)
        while self._system_queued_until + 1 < target:
            idx = self._system_queued_until + 1
            try:
                utterance_id = int(self.system.enqueue(self._segments[idx].text))
                self._system_ids[utterance_id] = idx
            except Exception:
                if idx == self._index:
                    self.system.say(self._segments[idx].text)
                break
            self._system_queued_until = idx

    @Slot(int)
    def _system_about_to_synthesize(self, utterance_id: int) -> None:
        if not self._playing or self._mode != "system":
            return
        idx = self._system_ids.get(int(utterance_id))
        if idx is None:
            return
        self._index = idx
        self.segmentChanged.emit(self._index)
        self._fill_system_queue()

    @Slot(object)
    def _system_state(self, state) -> None:
        if not self._playing or self._mode != "system" or not self._system_speaking:
            return
        if state == QTextToSpeech.State.Ready:
            if self._index + 1 >= len(self._segments):
                self.stop()
            elif not self._system_ids:
                self._index += 1
                self.segmentChanged.emit(self._index)
                self.system.say(self._segments[self._index].text)

    def _advance(self) -> None:
        if self._index + 1 >= len(self._segments):
            self.stop()
            return
        self._index += 1
        self.segmentChanged.emit(self._index)
        if self._mode == "neural":
            self._prefetch()
            self._play_neural(self._index)
        else:
            self._speak_system()
