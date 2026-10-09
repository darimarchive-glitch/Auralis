from auralis.text import normalize_text, split_sentences, translation_chunks


def test_repairs_line_hyphenation():
    assert normalize_text("inter-\nnacional") == "internacional"


def test_sentence_split_keeps_abbreviation():
    parts = split_sentences("O Dr. Silva chegou. Depois saiu.")
    assert parts == ["O Dr. Silva chegou.", "Depois saiu."]


def test_translation_chunks_preserve_paragraphs():
    text = "Primeiro parágrafo.\n\nSegundo parágrafo.\n\nTerceiro parágrafo."
    chunks = translation_chunks(text, max_chars=40)
    assert "".join(chunks).replace("\n", "").replace(" ", "")
    assert all(len(chunk) <= 40 for chunk in chunks)
