from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from auralis.importers import BookImporter


def make_epub(path: Path):
    container = """<?xml version="1.0"?>
    <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
    </container>"""
    opf = """<?xml version="1.0" encoding="utf-8"?>
    <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
      <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
       <dc:title>Livro Teste</dc:title><dc:creator>Autora Teste</dc:creator><dc:language>pt-BR</dc:language>
      </metadata>
      <manifest><item id="c1" href="chapter1.xhtml" media-type="application/xhtml+xml"/></manifest>
      <spine><itemref idref="c1"/></spine>
    </package>"""
    html = "<html><body><h1>Primeiro capítulo</h1><p>Olá mundo. Segunda frase.</p></body></html>"
    with ZipFile(path, "w", ZIP_DEFLATED) as zf:
        zf.writestr("META-INF/container.xml", container)
        zf.writestr("OEBPS/content.opf", opf)
        zf.writestr("OEBPS/chapter1.xhtml", html)


def test_epub_import(tmp_path):
    path = tmp_path / "book.epub"
    make_epub(path)
    result = BookImporter().import_file(path)
    assert result.title == "Livro Teste"
    assert result.author == "Autora Teste"
    assert result.language == "pt-BR"
    assert len(result.chapters) == 1
    assert "Olá mundo" in result.chapters[0].text
