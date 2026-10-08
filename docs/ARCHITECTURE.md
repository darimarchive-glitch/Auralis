# Auralis 3 architecture

Auralis 3 intentionally separates four layers.

1. **Core** — Python models, text normalization, document import, metadata, SQLite and settings.
2. **Narration** — a backend interface with Supertonic/sherpa-onnx and Qt system TTS implementations.
3. **UI** — Qt Quick/QML only; it does not parse books or know network APIs.
4. **Packaging** — PySide deployment for desktop and Android.

The app never relies on a remote Auralis backend. Cover providers are replaceable and optional.
A failure in Open Library, Google Books or model download does not make the library unreadable.

## Import flow

`file -> format parser -> normalized chapters -> SQLite -> embedded cover -> online metadata fallback`

## Narration flow

`paragraph -> semantic segmentation -> queue -> cache lookup -> neural render/system TTS -> playback`

The queue prefetches upcoming neural segments to remove gaps between sentences and stores generated
WAV files by content hash, voice, language and speed.
