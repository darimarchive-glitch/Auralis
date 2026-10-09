from __future__ import annotations

import re
from dataclasses import dataclass

_ABBREVIATIONS = {
    "sr.", "sra.", "dr.", "dra.", "prof.", "profa.", "etc.", "p.ex.",
    "mr.", "mrs.", "ms.", "dr.", "st.", "vs.", "e.g.", "i.e.",
    "m.", "mme.", "mlle.", "fr.", "jr.", "sr.",
}


@dataclass(slots=True)
class SpeechUnit:
    text: str
    kind: str = "narration"  # narration | dialogue | heading


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\u00ad", "")
    # Repara palavras quebradas no fim da linha sem usar escapes inválidos do Dart legado.
    text = re.sub(r"([A-Za-zÀ-ÖØ-öø-ÿ])-\s*\n\s*([A-Za-zÀ-ÖØ-öø-ÿ])", r"\1\2", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def split_sentences(text: str) -> list[str]:
    text = normalize_text(text)
    if not text:
        return []
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    out: list[str] = []
    for paragraph in paragraphs:
        start = 0
        for match in re.finditer(r"[.!?…]+(?:[\"'”’»)]*)\s+", paragraph):
            end = match.end()
            candidate = paragraph[start:end].strip()
            tail = candidate.lower().split()[-1] if candidate.split() else ""
            if tail in _ABBREVIATIONS or re.search(r"\b[A-ZÀ-ÖØ-Þ]\.$", candidate):
                continue
            if candidate:
                out.append(candidate)
            start = end
        remainder = paragraph[start:].strip()
        if remainder:
            out.append(remainder)
    return out


def speech_units(text: str) -> list[SpeechUnit]:
    units: list[SpeechUnit] = []
    for sentence in split_sentences(text):
        stripped = sentence.strip()
        if len(stripped) < 90 and stripped.upper() == stripped and any(ch.isalpha() for ch in stripped):
            kind = "heading"
        elif stripped.startswith(("—", "–", "-", "“", '"', "«")):
            kind = "dialogue"
        else:
            kind = "narration"
        units.append(SpeechUnit(stripped, kind))
    return units


def translation_chunks(text: str, max_chars: int = 2200) -> list[str]:
    """Split long prose without destroying paragraph boundaries or dialogue."""
    text = normalize_text(text)
    if len(text) <= max_chars:
        return [text] if text else []
    chunks: list[str] = []
    current: list[str] = []
    current_len = 0
    for paragraph in text.split("\n\n"):
        paragraph = paragraph.strip()
        if not paragraph:
            continue
        pieces = [paragraph]
        if len(paragraph) > max_chars:
            pieces = split_sentences(paragraph)
        for piece in pieces:
            extra = len(piece) + (2 if current else 0)
            if current and current_len + extra > max_chars:
                chunks.append("\n\n".join(current))
                current = []
                current_len = 0
            if len(piece) > max_chars:
                # Last-resort hard split for pathological OCR paragraphs.
                for i in range(0, len(piece), max_chars):
                    part = piece[i : i + max_chars].strip()
                    if current:
                        chunks.append("\n\n".join(current))
                        current = []
                        current_len = 0
                    if part:
                        chunks.append(part)
            else:
                current.append(piece)
                current_len += extra
    if current:
        chunks.append("\n\n".join(current))
    return chunks
