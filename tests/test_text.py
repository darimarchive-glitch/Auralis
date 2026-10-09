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


def test_narration_chunks_keep_exact_offsets():
    from auralis.text import narration_chunks
    text = "Primeira frase. Segunda frase um pouco maior. Terceira frase."
    chunks = narration_chunks(text, 5, max_chars=28)
    assert chunks
    for chunk in chunks:
        assert text[chunk.start:chunk.start + chunk.length] == chunk.text
    assert chunks[0].start >= 5
