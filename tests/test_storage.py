from pathlib import Path

from auralis.storage import LibraryStore


def test_txt_roundtrip(tmp_path):
    source = tmp_path / "teste.txt"
    source.write_text("Este é um livro de teste. Ele tem duas frases.", encoding="utf-8")
    store = LibraryStore(tmp_path / "data")
    created = store.import_book(source)
    loaded = store.get_book(created.id, include_chapters=True)
    assert loaded is not None
    assert loaded.title == "teste"
    assert len(loaded.chapters) == 1
    assert Path(loaded.stored_path).exists()
    store.update_progress(loaded.id, 0, 1, 0.5)
    assert store.get_book(loaded.id, False).progress == 0.5
