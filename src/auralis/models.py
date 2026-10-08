from __future__ import annotations

from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any


@dataclass(slots=True)
class Chapter:
    index: int
    title: str
    text: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class Book:
    id: str
    title: str
    author: str = ""
    language: str = ""
    isbn: str = ""
    source_path: str = ""
    stored_path: str = ""
    cover_path: str = ""
    format: str = ""
    current_chapter: int = 0
    current_segment: int = 0
    progress: float = 0.0
    last_opened: int = 0
    added_at: int = 0
    chapters: list[Chapter] = field(default_factory=list)

    def to_dict(self, include_chapters: bool = False) -> dict[str, Any]:
        data = {k: v for k, v in asdict(self).items() if k != "chapters"}
        data["displayAuthor"] = self.author or "Autor desconhecido"
        data["hasCover"] = bool(self.cover_path and Path(self.cover_path).exists())
        if include_chapters:
            data["chapters"] = [c.to_dict() for c in self.chapters]
        return data


@dataclass(slots=True)
class ImportResult:
    title: str
    author: str
    language: str
    isbn: str
    chapters: list[Chapter]
    cover_bytes: bytes | None = None
    cover_extension: str = ".jpg"


@dataclass(slots=True)
class MetadataCandidate:
    provider: str
    title: str
    author: str = ""
    isbn: str = ""
    language: str = ""
    cover_url: str = ""
    score: float = 0.0
