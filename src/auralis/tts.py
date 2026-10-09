from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from typing import Iterable

from .text import SpeechUnit, speech_units


@dataclass(slots=True)
class NarrationPlan:
    units: list[SpeechUnit]
    language: str
    rate: float = 1.0


class NarrationPlanner:
    """Text-side TTS pipeline shared by all voice backends.

    Audio backends can prefetch the next units while the current one is playing. Keeping this class
    backend-neutral prevents the old problem where sentence parsing was tied to a platform TTS API.
    """

    def plan(self, text: str, language: str, rate: float = 1.0) -> NarrationPlan:
        return NarrationPlan(speech_units(text), language, rate)

    @staticmethod
    def prefetch_window(units: Iterable[SpeechUnit], size: int = 4) -> deque[SpeechUnit]:
        queue: deque[SpeechUnit] = deque(maxlen=size)
        for unit in units:
            queue.append(unit)
            if len(queue) == size:
                break
        return queue


class QtSpeechBackend:
    def __init__(self) -> None:
        from PySide6.QtTextToSpeech import QTextToSpeech
        self.tts = QTextToSpeech()

    def available(self) -> bool:
        return self.tts.engine() is not None

    def speak(self, text: str, locale: str, rate: float = 1.0) -> None:
        from PySide6.QtCore import QLocale
        self.tts.setLocale(QLocale(locale.replace("-", "_")))
        self.tts.setRate(max(-1.0, min(1.0, rate - 1.0)))
        self.tts.say(text)

    def stop(self) -> None:
        self.tts.stop()
