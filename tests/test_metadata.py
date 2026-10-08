from auralis.metadata import score_candidate
from auralis.models import Book, MetadataCandidate


def book():
    return Book(id="1", title="O Grande Gatsby", author="F. Scott Fitzgerald", isbn="9780000000001")


def test_exact_isbn_wins():
    c = MetadataCandidate(provider="x", title="Wrong", author="Wrong", isbn="9780000000001")
    assert score_candidate(book(), c) == 1.0


def test_good_title_author_scores_high():
    c = MetadataCandidate(provider="x", title="O Grande Gatsby", author="F Scott Fitzgerald")
    assert score_candidate(book(), c) > 0.85


def test_wrong_title_rejected():
    c = MetadataCandidate(provider="x", title="Manual de Tratores", author="Outro Autor")
    assert score_candidate(book(), c) < 0.4
