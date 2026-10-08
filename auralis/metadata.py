from __future__ import annotations

import json
import re
import urllib.parse
import urllib.request
from difflib import SequenceMatcher
from pathlib import Path

from .models import Book, MetadataCandidate


USER_AGENT = "Auralis-Reader/3.0 (+https://github.com/darimarchive-glitch/Auralis)"


def _clean(value: str) -> str:
    value = value.casefold()
    value = re.sub(r"[^\w\s]", " ", value, flags=re.UNICODE)
    return " ".join(value.split())


def similarity(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, _clean(a), _clean(b)).ratio()


def score_candidate(book: Book, candidate: MetadataCandidate) -> float:
    if book.isbn and candidate.isbn:
        if re.sub(r"\D", "", book.isbn) == re.sub(r"\D", "", candidate.isbn):
            return 1.0
    title = similarity(book.title, candidate.title)
    author = similarity(book.author, candidate.author) if book.author and candidate.author else 0.55
    score = title * 0.74 + author * 0.26
    if title < 0.55:
        score *= 0.55
    return max(0.0, min(1.0, score))


class MetadataResolver:
    def __init__(self, timeout: float = 8.0) -> None:
        self.timeout = timeout

    def resolve(self, book: Book) -> MetadataCandidate | None:
        candidates: list[MetadataCandidate] = []
        candidates.extend(self._open_library(book))
        candidates.extend(self._google_books(book))
        for candidate in candidates:
            candidate.score = score_candidate(book, candidate)
        candidates.sort(key=lambda c: c.score, reverse=True)
        if not candidates or candidates[0].score < 0.72:
            return None
        return candidates[0]

    def download_cover(self, candidate: MetadataCandidate, destination: Path) -> bool:
        if not candidate.cover_url:
            return False
        req = urllib.request.Request(candidate.cover_url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as response:
                data = response.read(6 * 1024 * 1024)
                content_type = response.headers.get("Content-Type", "")
            if len(data) < 1024 or "image" not in content_type.lower():
                return False
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
            return True
        except Exception:
            return False

    def _json(self, url: str) -> dict:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception:
            return {}

    def _open_library(self, book: Book) -> list[MetadataCandidate]:
        if book.isbn:
            query = f"isbn:{book.isbn}"
        else:
            bits = [f'title:"{book.title}"']
            if book.author:
                bits.append(f'author:"{book.author}"')
            query = " ".join(bits)
        url = "https://openlibrary.org/search.json?" + urllib.parse.urlencode({"q": query, "limit": 6})
        payload = self._json(url)
        out: list[MetadataCandidate] = []
        for doc in payload.get("docs", []):
            cover_id = doc.get("cover_i")
            isbn_values = doc.get("isbn") or []
            out.append(MetadataCandidate(
                provider="Open Library",
                title=doc.get("title", ""),
                author=", ".join(doc.get("author_name") or []),
                isbn=(isbn_values[0] if isbn_values else ""),
                language=((doc.get("language") or [""])[0]),
                cover_url=(f"https://covers.openlibrary.org/b/id/{cover_id}-L.jpg" if cover_id else ""),
            ))
        return out

    def _google_books(self, book: Book) -> list[MetadataCandidate]:
        if book.isbn:
            q = f"isbn:{book.isbn}"
        else:
            q = f'intitle:"{book.title}"'
            if book.author:
                q += f' inauthor:"{book.author}"'
        url = "https://www.googleapis.com/books/v1/volumes?" + urllib.parse.urlencode({"q": q, "maxResults": 6})
        payload = self._json(url)
        out: list[MetadataCandidate] = []
        for item in payload.get("items", []):
            info = item.get("volumeInfo", {})
            ids = info.get("industryIdentifiers", [])
            isbn = next((x.get("identifier", "") for x in ids if x.get("type") == "ISBN_13"), "")
            if not isbn and ids:
                isbn = ids[0].get("identifier", "")
            images = info.get("imageLinks", {})
            cover = images.get("extraLarge") or images.get("large") or images.get("medium") or images.get("thumbnail") or ""
            if cover.startswith("http://"):
                cover = "https://" + cover[7:]
            out.append(MetadataCandidate(
                provider="Google Books",
                title=info.get("title", ""),
                author=", ".join(info.get("authors") or []),
                isbn=isbn,
                language=info.get("language", ""),
                cover_url=cover,
            ))
        return out
