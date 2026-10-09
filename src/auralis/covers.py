from __future__ import annotations

import json
import re
import urllib.parse
import urllib.request
from difflib import SequenceMatcher
from pathlib import Path

from .models import Book
from .paths import ensure_dirs

UA = "Auralis/3.0 (book metadata resolver)"


def _norm(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.casefold()).strip()


def _similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, _norm(a), _norm(b)).ratio()


class CoverResolver:
    def __init__(self) -> None:
        self.cover_dir = ensure_dirs()["covers"]

    def resolve(self, book: Book) -> str:
        if book.cover_path and Path(book.cover_path).exists():
            return book.cover_path
        candidates = self._open_library(book) + self._google_books(book)
        candidates.sort(key=lambda c: c[0], reverse=True)
        if not candidates or candidates[0][0] < 0.72:
            return ""
        _, url = candidates[0]
        target = self.cover_dir / f"{book.id}.jpg"
        try:
            request = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(request, timeout=10) as response:
                data = response.read(5_000_000)
            if len(data) < 500:
                return ""
            target.write_bytes(data)
            return str(target)
        except Exception:
            return ""

    def _open_library(self, book: Book) -> list[tuple[float, str]]:
        query = urllib.parse.urlencode({"title": book.title, "author": book.author, "limit": 5})
        try:
            data = self._json(f"https://openlibrary.org/search.json?{query}")
        except Exception:
            return []
        out: list[tuple[float, str]] = []
        for doc in data.get("docs", []):
            cover_i = doc.get("cover_i")
            if not cover_i:
                continue
            title_score = _similarity(book.title, str(doc.get("title", "")))
            authors = " ".join(doc.get("author_name", []) or [])
            author_score = _similarity(book.author, authors) if book.author != "Autor desconhecido" else 0.8
            score = title_score * 0.72 + author_score * 0.28
            out.append((score, f"https://covers.openlibrary.org/b/id/{cover_i}-L.jpg"))
        return out

    def _google_books(self, book: Book) -> list[tuple[float, str]]:
        q = f'intitle:"{book.title}"'
        if book.author != "Autor desconhecido":
            q += f' inauthor:"{book.author}"'
        query = urllib.parse.urlencode({"q": q, "maxResults": 5, "printType": "books"})
        try:
            data = self._json(f"https://www.googleapis.com/books/v1/volumes?{query}")
        except Exception:
            return []
        out: list[tuple[float, str]] = []
        for item in data.get("items", []) or []:
            info = item.get("volumeInfo", {})
            image = (info.get("imageLinks") or {}).get("thumbnail")
            if not image:
                continue
            title_score = _similarity(book.title, str(info.get("title", "")))
            authors = " ".join(info.get("authors", []) or [])
            author_score = _similarity(book.author, authors) if book.author != "Autor desconhecido" else 0.8
            score = title_score * 0.72 + author_score * 0.28
            out.append((score, image.replace("http://", "https://")))
        return out

    @staticmethod
    def _json(url: str) -> dict:
        request = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(request, timeout=8) as response:
            return json.loads(response.read().decode("utf-8"))
