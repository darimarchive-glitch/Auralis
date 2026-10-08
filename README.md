# Auralis 3

Auralis 3 is a full rewrite of the reader around a Python core and Qt/QML interface.
The same application code targets Linux, Windows and Android.

## Goals

- one codebase for library, parsing, metadata, covers, progress and narration logic;
- no account, no API token and no mandatory cloud service;
- local-first storage with SQLite;
- PDF via Qt PDF/PDFium instead of a platform-specific parser;
- EPUB, TXT, HTML, Markdown, DOCX, FB2 and RTF via Python standard library;
- automatic embedded-cover extraction first, then Open Library and Google Books fallback;
- confidence scoring to avoid attaching a clearly wrong cover;
- sentence-aware narration pipeline with abbreviations, dialogue and punctuation handling;
- neural Supertonic 3 backend where sherpa-onnx is available, with system TTS fallback;
- QML interface designed for touch and desktop instead of a stretched mobile layout.

The previous Flutter generation is preserved in `legacy-flutter-2.1`.

## Development

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -e '.[dev,neural]'
pytest
python -m auralis.main
```

Without the optional neural dependency, Auralis still works with Qt TextToSpeech.

## Storage

Auralis keeps its database, imported originals, covers, models and narration cache inside the
platform application-data directory. Imported files are copied into the application library so
removing or moving the original does not break the book.

## Online behavior

Book reading and local narration do not require a server. Network access is optional and is used
for two user-visible tasks: downloading a neural voice model and resolving book metadata/covers.
Automatic cover lookup can be disabled.

## License

Auralis-owned code and assets are proprietary. **All Rights Reserved.** Third-party runtimes and
models retain their own licenses; see `THIRD_PARTY_NOTICES.md`.
