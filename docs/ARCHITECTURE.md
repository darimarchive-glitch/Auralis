# Auralis 3 architecture

Auralis 3 uses one Python domain layer and one Qt Quick/QML interface across Android, Windows and Linux.

## Layers

- `src/auralis/importer.py`: document ingestion and normalized chapters.
- `src/auralis/db.py`: SQLite library, progress, preferences and translation cache.
- `src/auralis/covers.py`: embedded cover extraction and metadata-based cover resolution.
- `src/auralis/text.py`: normalization, narration units and translation chunks.
- `src/auralis/translation.py`: offline/light and optional local-AI translation providers.
- `src/auralis/tts.py`: backend-neutral narration planning.
- `src/auralis/controller.py`: UI-facing application controller.
- `src/auralis/qml/`: responsive Qt Quick user interface.

## Secrets

No API keys, signing keys, passwords or user data are committed. Optional remote/provider credentials must be supplied at runtime by the user or CI secret storage.

## Distribution

- Android uses Qt for Python Android deployment and produces an arm64 APK.
- Windows produces a Nuitka standalone app and wraps it in an Inno Setup installer.
- Linux produces a Nuitka standalone app and wraps it in a Flatpak bundle.

The `VERSION` file is the release source of truth. CI verifies that Python package versions match it.
