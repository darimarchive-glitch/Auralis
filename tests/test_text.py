from auralis.text import detect_language, normalize_text, segment_for_speech, split_sentences


def test_repairs_hyphenated_line_breaks():
    assert normalize_text("inter-\nnacional") == "internacional"


def test_does_not_split_common_abbreviation():
    parts = split_sentences("O Dr. Silva chegou. Depois, sentou-se.")
    assert parts == ["O Dr. Silva chegou.", "Depois, sentou-se."]


def test_dialogue_detection():
    segments = segment_for_speech("— Onde você estava?\n\nEu fiquei em casa.", "pt-BR")
    assert segments[0].kind == "dialogue"
    assert segments[1].kind == "narration"


def test_language_heuristic():
    assert detect_language("Ele não sabia que ela estava com seu livro para devolver.") == "pt-BR"
    assert detect_language("The book was on the table and this was his final chance.") == "en-US"


def test_detecta_scripts_multilingues():
    assert detect_language("これは日本語の文章です。") == "ja-JP"
    assert detect_language("이것은 한국어 문장입니다.") == "ko-KR"
    assert detect_language("Это русское предложение.") == "ru-RU"


def test_detecta_linguas_latinas():
    assert detect_language("Le monde est plus grand que les rêves dans une histoire.") == "fr-FR"
    assert detect_language("Die Welt ist nicht klein und das ist eine Geschichte.") == "de-DE"
