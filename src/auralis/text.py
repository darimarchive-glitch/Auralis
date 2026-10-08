from __future__ import annotations

import hashlib
import re
import unicodedata
from dataclasses import dataclass


ABBREVIATIONS = {
    "sr.", "sra.", "srta.", "dr.", "dra.", "prof.", "profa.", "etc.", "ex.", "p.ex.",
    "mr.", "mrs.", "ms.", "dr.", "st.", "vs.", "e.g.", "i.e.", "no.", "vol.", "cap.",
}

LANG_HINTS = {
    "pt-BR": {"que", "não", "uma", "para", "com", "ele", "ela", "por", "como", "mais", "seu", "isso", "está"},
    "en-US": {"the", "and", "that", "with", "you", "for", "was", "this", "have", "from", "his", "her"},
    "es-ES": {"que", "una", "para", "con", "por", "como", "más", "pero", "sus", "del", "las", "los"},
    "fr-FR": {"que", "une", "pour", "avec", "dans", "est", "pas", "plus", "des", "les", "qui", "sur"},
    "de-DE": {"und", "der", "die", "das", "mit", "für", "ist", "nicht", "ein", "eine", "auf", "von"},
    "it-IT": {"che", "una", "per", "con", "non", "più", "della", "del", "gli", "le", "nel", "come"},
}


@dataclass(slots=True, frozen=True)
class SpeechSegment:
    index: int
    text: str
    kind: str
    language: str
    cache_key: str


def normalize_text(text: str) -> str:
    if not text:
        return ""
    text = unicodedata.normalize("NFC", text.replace("\r\n", "\n").replace("\r", "\n"))
    text = text.replace("\u00ad", "")
    text = re.sub(r"([A-Za-zÀ-ÖØ-öø-ÿ])-[ \t]*\n[ \t]*([A-Za-zÀ-ÖØ-öø-ÿ])", r"\1\2", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"(?m)^\s*(?:p(?:ágina)?\.?\s*)?\d{1,4}\s*$", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def detect_language(text: str, fallback: str = "pt-BR") -> str:
    sample = text[:5000]
    if re.search(r"[\u3040-\u30ff]", sample):
        return "ja-JP"
    if re.search(r"[\uac00-\ud7af]", sample):
        return "ko-KR"
    if re.search(r"[\u0600-\u06ff]", sample):
        return "ar"
    if re.search(r"[\u0900-\u097f]", sample):
        return "hi-IN"
    if re.search(r"[\u0400-\u04ff]", sample):
        return "ru-RU"
    words = re.findall(r"[A-Za-zÀ-ÖØ-öø-ÿ']+", text.lower())[:700]
    if not words:
        return fallback
    bag = set(words)
    scores = {lang: len(bag & hints) for lang, hints in LANG_HINTS.items()}
    lang, score = max(scores.items(), key=lambda item: item[1])
    return lang if score else fallback


def _protect_abbreviations(text: str) -> tuple[str, str]:
    marker = "∯"
    protected = text
    for abbr in sorted(ABBREVIATIONS, key=len, reverse=True):
        protected = re.sub(
            rf"(?i)(?<!\w){re.escape(abbr)}",
            lambda m: m.group(0).replace(".", marker),
            protected,
        )
    protected = re.sub(r"(?<=\b[A-Z])\.(?=[A-Z]\.)", marker, protected)
    return protected, marker


def split_sentences(text: str) -> list[str]:
    text = normalize_text(text)
    if not text:
        return []
    protected, marker = _protect_abbreviations(text)
    parts = re.split(r"(?<=[.!?…])(?:[\"'”’»)]*)\s+(?=[A-ZÀ-ÖØ-Þ0-9—–\"'“‘«])|\n{2,}", protected)
    output: list[str] = []
    for part in parts:
        part = part.replace(marker, ".").strip()
        if not part:
            continue
        if len(part) > 520:
            output.extend(_soft_split(part, 420))
        else:
            output.append(part)
    return output


def _soft_split(text: str, target: int) -> list[str]:
    result: list[str] = []
    remaining = text.strip()
    while len(remaining) > target:
        window = remaining[: target + 100]
        candidates = [window.rfind(sep) for sep in ("; ", ": ", ", ", " — ", " – ")]
        cut = max(candidates)
        if cut < target // 2:
            cut = window.rfind(" ")
        if cut <= 0:
            cut = target
        result.append(remaining[: cut + 1].strip())
        remaining = remaining[cut + 1 :].strip()
    if remaining:
        result.append(remaining)
    return result


def segment_for_speech(text: str, language: str = "") -> list[SpeechSegment]:
    lang = language or detect_language(text)
    segments: list[SpeechSegment] = []
    for index, sentence in enumerate(split_sentences(text)):
        stripped = sentence.lstrip()
        if stripped.startswith(("—", "–", '"', "“", "‘")):
            kind = "dialogue"
        elif sentence.isupper() and len(sentence) < 100:
            kind = "heading"
        else:
            kind = "narration"
        key = hashlib.sha256(f"{lang}\0{sentence}".encode("utf-8")).hexdigest()
        segments.append(SpeechSegment(index, sentence, kind, lang, key))
    return segments
