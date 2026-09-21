# Auralis 2.0 architecture

## Core flow

1. `AppController` owns library/settings state.
2. `BookRepository` stores imported copies, extracted content and progress.
3. `BookImporter` parses supported formats into chapters.
4. `ReaderController` turns chapters into speech chunks and advances only after each utterance finishes.
5. `LocalTtsService` routes speech to neural TTS or the operating system.
6. `NeuralTtsService` downloads and verifies the model, keeps the ONNX TTS instance in a background isolate, writes a temporary WAV, plays it locally and removes it.

## Why Supertonic 3

The project needs voices that are materially more natural than classic Android/Linux TTS while remaining free of per-request tokens. Supertonic 3 is a compact multilingual ONNX model designed for on-device inference. The app uses the official sherpa-onnx compatible INT8 model package.

## Packaging

- Android: Flutter release APK.
- Windows: Flutter native bundle wrapped by Inno Setup.
- Linux: Flutter native bundle copied into a GNOME 50 Flatpak runtime.

All three are built independently in GitHub Actions so a platform-specific failure does not hide the status of the other platforms.
