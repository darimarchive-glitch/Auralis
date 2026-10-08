from __future__ import annotations

import base64
import html as html_module
import mimetypes
import re
import zipfile
from html.parser import HTMLParser
from pathlib import Path, PurePosixPath
from xml.etree import ElementTree as ET

from .models import Chapter, ImportResult
from .text import normalize_text


class ImportErrorAuralis(RuntimeError):
    pass


class _TextHTMLParser(HTMLParser):
    BLOCKS = {"p", "div", "section", "article", "br", "li", "h1", "h2", "h3", "h4", "h5", "h6"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self._skip = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        if tag in {"script", "style", "svg", "nav"}:
            self._skip += 1
        if not self._skip and tag in self.BLOCKS:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in {"script", "style", "svg", "nav"} and self._skip:
            self._skip -= 1
        if not self._skip and tag in self.BLOCKS:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        if not self._skip:
            self.parts.append(data)


def html_to_text(value: str) -> str:
    parser = _TextHTMLParser()
    parser.feed(value)
    return normalize_text("".join(parser.parts))


def _decode_bytes(data: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-16", "cp1252", "latin-1"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            pass
    return data.decode("utf-8", errors="replace")


def _local_name(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def _xml_text(element: ET.Element) -> str:
    chunks: list[str] = []
    for node in element.iter():
        if _local_name(node.tag) in {"p", "title", "subtitle", "v", "text-author", "empty-line"}:
            text = "".join(node.itertext()).strip()
            if text:
                chunks.append(text)
    return normalize_text("\n\n".join(chunks))


def _find_text(root: ET.Element, name: str) -> str:
    for node in root.iter():
        if _local_name(node.tag) == name and node.text:
            return node.text.strip()
    return ""


def _rtf_to_text(raw: str) -> str:
    raw = re.sub(r"\\'([0-9a-fA-F]{2})", lambda m: bytes.fromhex(m.group(1)).decode("cp1252", "replace"), raw)
    raw = raw.replace("\\par", "\n").replace("\\line", "\n").replace("\\tab", "\t")
    raw = re.sub(r"\\u(-?\d+)\??", lambda m: chr(int(m.group(1)) % 65536), raw)
    raw = re.sub(r"\\[a-zA-Z]+-?\d* ?", "", raw)
    raw = re.sub(r"[{}]", "", raw)
    return normalize_text(raw)


class BookImporter:
    SUPPORTED = {".pdf", ".epub", ".txt", ".html", ".htm", ".md", ".markdown", ".docx", ".fb2", ".rtf"}

    def import_file(self, path: str | Path) -> ImportResult:
        file = Path(path)
        if not file.exists() or not file.is_file():
            raise ImportErrorAuralis("Arquivo não encontrado.")
        ext = file.suffix.lower()
        if ext not in self.SUPPORTED:
            raise ImportErrorAuralis(f"Formato não suportado: {ext or 'sem extensão'}")
        if ext == ".pdf":
            return self._pdf(file)
        if ext == ".epub":
            return self._epub(file)
        if ext in {".html", ".htm"}:
            return self._html(file)
        if ext in {".md", ".markdown"}:
            return self._markdown(file)
        if ext == ".docx":
            return self._docx(file)
        if ext == ".fb2":
            return self._fb2(file)
        if ext == ".rtf":
            return self._rtf(file)
        return self._text(file)

    def _text(self, file: Path) -> ImportResult:
        text = normalize_text(_decode_bytes(file.read_bytes()))
        return ImportResult(file.stem, "", "", "", [Chapter(0, "Livro", text)])

    def _html(self, file: Path) -> ImportResult:
        source = _decode_bytes(file.read_bytes())
        title_match = re.search(r"<title[^>]*>(.*?)</title>", source, re.I | re.S)
        title = html_module.unescape(re.sub(r"<[^>]+>", "", title_match.group(1))).strip() if title_match else file.stem
        return ImportResult(title, "", "", "", [Chapter(0, title, html_to_text(source))])

    def _markdown(self, file: Path) -> ImportResult:
        source = _decode_bytes(file.read_bytes())
        title = file.stem
        m = re.search(r"(?m)^#\s+(.+)$", source)
        if m:
            title = m.group(1).strip()
        source = re.sub(r"\`{3}.*?\`{3}", "", source, flags=re.S)
        source = re.sub(r"\`([^\`]+)\`", r"\1", source)
        source = re.sub(r"!\[[^]]*]\([^)]*\)", "", source)
        source = re.sub(r"\[([^]]+)]\([^)]*\)", r"\1", source)
        source = re.sub(r"(?m)^#{1,6}\s*", "", source)
        source = re.sub(r"[*_~]{1,3}", "", source)
        return ImportResult(title, "", "", "", [Chapter(0, title, normalize_text(source))])

    def _rtf(self, file: Path) -> ImportResult:
        return ImportResult(file.stem, "", "", "", [Chapter(0, file.stem, _rtf_to_text(_decode_bytes(file.read_bytes())))])

    def _docx(self, file: Path) -> ImportResult:
        try:
            with zipfile.ZipFile(file) as zf:
                root = ET.fromstring(zf.read("word/document.xml"))
                paragraphs = []
                for node in root.iter():
                    if _local_name(node.tag) == "p":
                        text = "".join(child.text or "" for child in node.iter() if _local_name(child.tag) == "t").strip()
                        if text:
                            paragraphs.append(text)
                title, author = file.stem, ""
                if "docProps/core.xml" in zf.namelist():
                    core = ET.fromstring(zf.read("docProps/core.xml"))
                    title = _find_text(core, "title") or title
                    author = _find_text(core, "creator")
                return ImportResult(title, author, "", "", [Chapter(0, title, normalize_text("\n\n".join(paragraphs)))])
        except (zipfile.BadZipFile, KeyError, ET.ParseError) as exc:
            raise ImportErrorAuralis("DOCX inválido ou corrompido.") from exc

    def _fb2(self, file: Path) -> ImportResult:
        try:
            root = ET.fromstring(file.read_bytes())
        except ET.ParseError as exc:
            raise ImportErrorAuralis("FB2 inválido.") from exc
        title = _find_text(root, "book-title") or file.stem
        author = " ".join(p for p in (_find_text(root, "first-name"), _find_text(root, "last-name")) if p)
        lang, isbn = _find_text(root, "lang"), _find_text(root, "isbn")
        chapters = []
        for body in [n for n in root.iter() if _local_name(n.tag) == "body"]:
            for section in [n for n in body if _local_name(n.tag) == "section"]:
                text = _xml_text(section)
                if text:
                    chapters.append(Chapter(len(chapters), _find_text(section, "title") or f"Capítulo {len(chapters)+1}", text))
        if not chapters:
            chapters = [Chapter(0, title, _xml_text(root))]
        cover_bytes, cover_ext, cover_id = None, ".jpg", ""
        for node in root.iter():
            if _local_name(node.tag) == "coverpage":
                for child in node.iter():
                    if _local_name(child.tag) == "image":
                        for key, value in child.attrib.items():
                            if key.endswith("href") and value.startswith("#"):
                                cover_id = value[1:]
        if cover_id:
            for node in root.iter():
                if _local_name(node.tag) == "binary" and node.attrib.get("id") == cover_id:
                    try:
                        cover_bytes = base64.b64decode("".join(node.itertext()).strip())
                        cover_ext = mimetypes.guess_extension(node.attrib.get("content-type", "image/jpeg")) or ".jpg"
                    except (ValueError, TypeError):
                        pass
                    break
        return ImportResult(title, author, lang, isbn, chapters, cover_bytes, cover_ext)

    def _epub(self, file: Path) -> ImportResult:
        try:
            with zipfile.ZipFile(file) as zf:
                container = ET.fromstring(zf.read("META-INF/container.xml"))
                rootfile = next((n.attrib.get("full-path") for n in container.iter() if _local_name(n.tag) == "rootfile"), None)
                if not rootfile:
                    raise ImportErrorAuralis("EPUB sem pacote OPF.")
                opf = ET.fromstring(zf.read(rootfile))
                base = PurePosixPath(rootfile).parent
                title, author, language = _find_text(opf, "title") or file.stem, _find_text(opf, "creator"), _find_text(opf, "language")
                isbn = ""
                for identifier in [n for n in opf.iter() if _local_name(n.tag) == "identifier"]:
                    compact = re.sub(r"[^0-9Xx]", "", (identifier.text or "").strip())
                    if len(compact) in {10, 13}:
                        isbn = compact
                        break
                manifest = {}
                for item in [n for n in opf.iter() if _local_name(n.tag) == "item"]:
                    manifest[item.attrib.get("id", "")] = (item.attrib.get("href", ""), item.attrib.get("media-type", ""), item.attrib.get("properties", ""))
                spine = [n.attrib.get("idref", "") for n in opf.iter() if _local_name(n.tag) == "itemref"]
                chapters = []
                for item_id in spine:
                    href, media, _ = manifest.get(item_id, ("", "", ""))
                    if not href or "html" not in media:
                        continue
                    try:
                        source = _decode_bytes(zf.read(str((base / href).as_posix())))
                    except KeyError:
                        continue
                    text = html_to_text(source)
                    if text:
                        h = re.search(r"<h[1-3][^>]*>(.*?)</h[1-3]>", source, re.I | re.S)
                        heading = html_module.unescape(re.sub(r"<[^>]+>", "", h.group(1))).strip() if h else f"Capítulo {len(chapters)+1}"
                        chapters.append(Chapter(len(chapters), heading, text))
                if not chapters:
                    raise ImportErrorAuralis("EPUB não contém capítulos legíveis.")
                cover_bytes, cover_ext = None, ".jpg"
                cover_item = next((v for v in manifest.values() if "cover-image" in v[2]), None)
                if not cover_item:
                    cover_id = next((m.attrib.get("content", "") for m in opf.iter() if _local_name(m.tag) == "meta" and m.attrib.get("name", "").lower() == "cover"), "")
                    if cover_id:
                        cover_item = manifest.get(cover_id)
                if cover_item:
                    href, media, _ = cover_item
                    try:
                        cover_bytes = zf.read(str((base / href).as_posix()))
                        cover_ext = mimetypes.guess_extension(media) or Path(href).suffix or ".jpg"
                    except KeyError:
                        pass
                return ImportResult(title, author, language, isbn, chapters, cover_bytes, cover_ext)
        except (zipfile.BadZipFile, KeyError, ET.ParseError) as exc:
            raise ImportErrorAuralis("EPUB inválido ou corrompido.") from exc

    def _pdf(self, file: Path) -> ImportResult:
        try:
            from PySide6.QtCore import QBuffer, QByteArray, QIODevice, QSize
            from PySide6.QtPdf import QPdfDocument
        except Exception as exc:
            raise ImportErrorAuralis("O módulo Qt PDF não está disponível neste build.") from exc
        doc = QPdfDocument()
        error = doc.load(str(file))
        if int(error.value if hasattr(error, "value") else error) != 0:
            raise ImportErrorAuralis("Não foi possível abrir o PDF.")
        pages = []
        for page in range(doc.pageCount()):
            selection = doc.getAllText(page)
            text = selection.text() if hasattr(selection, "text") else str(selection)
            if text.strip():
                pages.append(text)
        title = str(doc.metaData(QPdfDocument.MetaDataField.Title) or "").strip() or file.stem
        author = str(doc.metaData(QPdfDocument.MetaDataField.Author) or "").strip()
        cover_bytes = None
        try:
            if doc.pageCount() > 0:
                image = doc.render(0, QSize(900, 1280))
                data = QByteArray()
                buffer = QBuffer(data)
                if buffer.open(QIODevice.OpenModeFlag.WriteOnly) and image.save(buffer, "PNG"):
                    cover_bytes = bytes(data)
                buffer.close()
        except Exception:
            pass
        doc.close()
        text = normalize_text("\n\n".join(pages))
        if not text:
            raise ImportErrorAuralis("Este PDF não possui camada de texto. OCR será necessário.")
        return ImportResult(title, author, "", "", [Chapter(0, title, text)], cover_bytes, ".png")
