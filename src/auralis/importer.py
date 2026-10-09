from __future__ import annotations

import html as html_lib
import re
import shutil
import uuid
import xml.etree.ElementTree as ET
import zipfile
from html.parser import HTMLParser
from pathlib import Path

from .models import Book, Chapter
from .paths import ensure_dirs
from .text import normalize_text

SUPPORTED = {".txt", ".md", ".html", ".htm", ".epub", ".docx", ".fb2", ".rtf", ".pdf"}


class _TextHTMLParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.parts: list[str] = []

    def handle_data(self, data: str) -> None:
        if data.strip():
            self.parts.append(data.strip())

    def text(self) -> str:
        return "\n".join(self.parts)


class BookImporter:
    def __init__(self) -> None:
        self.dirs = ensure_dirs()

    def import_file(self, source: str | Path) -> Book:
        source = Path(source)
        suffix = source.suffix.lower()
        if suffix not in SUPPORTED:
            raise ValueError(f"Formato não suportado: {suffix or 'sem extensão'}")

        book_id = uuid.uuid4().hex
        target_dir = self.dirs["books"] / book_id
        target_dir.mkdir(parents=True, exist_ok=True)
        stored = target_dir / source.name
        shutil.copy2(source, stored)

        title = source.stem.replace("_", " ").strip() or "Livro sem título"
        author = "Autor desconhecido"
        language = "und"
        cover_path = ""

        if suffix == ".epub":
            title, author, language, chapters, cover_path = self._epub(stored, target_dir)
        elif suffix == ".docx":
            chapters = [Chapter(0, "Documento", self._docx(stored))]
        elif suffix == ".fb2":
            title, author, chapters = self._fb2(stored)
        elif suffix == ".rtf":
            chapters = [Chapter(0, "Documento", self._rtf(stored))]
        elif suffix in {".html", ".htm"}:
            chapters = [Chapter(0, "Documento", self._html(stored.read_text("utf-8", errors="ignore")))]
        elif suffix == ".pdf":
            chapters = self._pdf(stored)
        else:
            chapters = [Chapter(0, "Texto", stored.read_text("utf-8", errors="ignore"))]

        chapters = [Chapter(c.index, c.title, normalize_text(c.text)) for c in chapters if c.text.strip()]
        if not chapters:
            raise ValueError("Não foi possível extrair texto deste arquivo. PDFs escaneados precisam de OCR.")

        return Book(
            id=book_id,
            title=title,
            author=author,
            language=language,
            format=suffix.lstrip("."),
            source_path=str(source),
            stored_path=str(stored),
            cover_path=cover_path,
            chapters=chapters,
        )

    def _epub(self, path: Path, target_dir: Path) -> tuple[str, str, str, list[Chapter], str]:
        with zipfile.ZipFile(path) as zf:
            container = ET.fromstring(zf.read("META-INF/container.xml"))
            rootfile = next(el for el in container.iter() if el.tag.endswith("rootfile"))
            opf_path = rootfile.attrib["full-path"]
            opf_dir = Path(opf_path).parent
            opf = ET.fromstring(zf.read(opf_path))

            def first_text(local: str, default: str = "") -> str:
                for el in opf.iter():
                    if el.tag.endswith(local) and el.text:
                        return el.text.strip()
                return default

            title = first_text("title", path.stem)
            author = first_text("creator", "Autor desconhecido")
            language = first_text("language", "und")
            manifest: dict[str, tuple[str, str, str]] = {}
            for el in opf.iter():
                if el.tag.endswith("item"):
                    manifest[el.attrib.get("id", "")] = (
                        el.attrib.get("href", ""),
                        el.attrib.get("media-type", ""),
                        el.attrib.get("properties", ""),
                    )
            spine = [el.attrib.get("idref", "") for el in opf.iter() if el.tag.endswith("itemref")]
            chapters: list[Chapter] = []
            for idx, item_id in enumerate(spine):
                href, _, _ = manifest.get(item_id, ("", "", ""))
                if not href:
                    continue
                full = str((opf_dir / href).as_posix())
                try:
                    parsed = self._html(zf.read(full).decode("utf-8", errors="ignore"))
                except KeyError:
                    continue
                if parsed.strip():
                    chapters.append(Chapter(idx, f"Capítulo {idx + 1}", parsed))

            cover = ""
            cover_item = next((v for v in manifest.values() if "cover-image" in v[2]), None)
            if cover_item:
                cover_member = str((opf_dir / cover_item[0]).as_posix())
                try:
                    ext = Path(cover_item[0]).suffix or ".jpg"
                    cover_file = target_dir / f"cover{ext}"
                    cover_file.write_bytes(zf.read(cover_member))
                    cover = str(cover_file)
                except KeyError:
                    pass
            return title, author, language, chapters, cover

    def _docx(self, path: Path) -> str:
        with zipfile.ZipFile(path) as zf:
            root = ET.fromstring(zf.read("word/document.xml"))
        paragraphs: list[str] = []
        for paragraph in [e for e in root.iter() if e.tag.endswith("}p")]:
            text = "".join((node.text or "") for node in paragraph.iter() if node.tag.endswith("}t"))
            if text.strip():
                paragraphs.append(text.strip())
        return "\n\n".join(paragraphs)

    def _fb2(self, path: Path) -> tuple[str, str, list[Chapter]]:
        root = ET.parse(path).getroot()
        title = path.stem
        author = "Autor desconhecido"
        for el in root.iter():
            tag = el.tag.split("}")[-1]
            if tag == "book-title" and el.text:
                title = el.text.strip()
            elif tag == "author":
                names = ["".join(child.itertext()).strip() for child in el]
                names = [n for n in names if n]
                if names:
                    author = " ".join(names)
                    break
        sections = [el for el in root.iter() if el.tag.endswith("}section")]
        chapters: list[Chapter] = []
        for i, section in enumerate(sections):
            text = normalize_text("\n".join(x.strip() for x in section.itertext() if x.strip()))
            if text:
                chapters.append(Chapter(i, f"Capítulo {i + 1}", text))
        return title, author, chapters or [Chapter(0, "Livro", "\n".join(root.itertext()))]

    @staticmethod
    def _rtf(path: Path) -> str:
        raw = path.read_text("latin-1", errors="ignore")
        raw = re.sub(r"\\par[d]?\b", "\n", raw)
        raw = re.sub(r"\\'[0-9a-fA-F]{2}", "", raw)
        raw = re.sub(r"\\[a-zA-Z]+-?\d* ?", "", raw)
        raw = raw.replace("{", "").replace("}", "")
        return raw

    @staticmethod
    def _html(raw: str) -> str:
        parser = _TextHTMLParser()
        parser.feed(html_lib.unescape(raw))
        return parser.text()

    @staticmethod
    def _pdf(path: Path) -> list[Chapter]:
        try:
            from PySide6.QtCore import QUrl
            from PySide6.QtPdf import QPdfDocument
        except Exception as exc:  # pragma: no cover - requires Qt runtime
            raise RuntimeError("Qt PDF não está disponível neste build.") from exc

        doc = QPdfDocument()
        error = doc.load(str(path))
        # Qt returns a status/error enum depending on version; pageCount is the robust signal.
        if doc.pageCount() <= 0:
            raise ValueError(f"Não foi possível abrir o PDF: {error}")
        pages: list[str] = []
        for page in range(doc.pageCount()):
            selection = doc.getAllText(page)
            text = selection.text() if selection else ""
            if text.strip():
                pages.append(text.strip())
        doc.close()
        if not pages:
            raise ValueError("PDF sem camada de texto. Ative OCR para livros escaneados.")
        return [Chapter(0, "PDF", "\n\n".join(pages))]
