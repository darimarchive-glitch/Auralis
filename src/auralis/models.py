from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(slots=True)
class Chapter:
    index: int
    title: str
    text: str


@dataclass(slots=True)
class Book:
    id: str
    title: str
    author: str = "Autor desconhecido"
    language: str = "und"
    format: str = "txt"
    source_path: str = ""
    stored_path: str = ""
    cover_path: str = ""
    added_at: str = field(default_factory=now_iso)
    progress: float = 0.0
    current_chapter: int = 0
    current_offset: int = 0
    active_translation: str = ""
    chapters: list[Chapter] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["chapters"] = [asdict(chapter) for chapter in self.chapters]
        return data


@dataclass(slots=True)
class TranslationOptions:
    source_language: str = "auto"
    target_language: str = "pt"
    quality: str = "smart"  # smart | lite | studio
    literary_mode: str = "faithful"  # faithful | modern | literal | study
    preserve_names: bool = True
    preserve_paragraphs: bool = True
    post_edit: bool = False


@dataclass(slots=True)
class TranslationResult:
    text: str
    provider: str
    source_language: str
    target_language: str
    literary_mode: str
