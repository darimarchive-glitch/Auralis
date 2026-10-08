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


def test_metadata_update(tmp_path):
    source = tmp_path / "metadata.txt"
    source.write_text("Um livro simples para testar atualização.", encoding="utf-8")
    store = LibraryStore(tmp_path / "data2")
    created = store.import_book(source)
    store.update_metadata(
        created.id,
        author="Autora Exemplo",
        language="pt-BR",
        isbn="9781234567890",
        cover_path=str(tmp_path / "cover.jpg"),
    )
    loaded = store.get_book(created.id, include_chapters=False)
    assert loaded is not None
    assert loaded.author == "Autora Exemplo"
    assert loaded.language == "pt-BR"
    assert loaded.isbn == "9781234567890"
    assert loaded.cover_path.endswith("cover.jpg")
