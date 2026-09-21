# Third-party notices

Auralis Reader is licensed under MIT. Third-party packages and downloaded voice models keep their own licenses.

## sherpa-onnx

The neural TTS backend uses `sherpa_onnx` to run ONNX models locally on supported devices.

- Project: https://github.com/k2-fsa/sherpa-onnx
- License: Apache-2.0

## Supertonic 3 model

The optional neural voice download uses the Supertonic 3 model through the sherpa-onnx compatible INT8 package.

- Model card: https://huggingface.co/Supertone/supertonic-3
- Model license: OpenRAIL-M
- Runtime model package: https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models

The model is not bundled in the Auralis source tree or APK. The user explicitly downloads it from the app. Auralis verifies the downloaded archive with SHA-256 before installing it.

## audioplayers

Auralis uses `audioplayers` to reproduce the locally generated WAV audio.

- Project: https://github.com/bluefireteam/audioplayers
- License: MIT

Refer to each upstream project for the complete license text and current terms.
