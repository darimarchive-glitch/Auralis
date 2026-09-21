# Third-party notices

Auralis Reader source code is distributed under the MIT License. Third-party software and downloaded models remain under their respective licenses.

## sherpa-onnx

Auralis uses `sherpa_onnx` 1.13.8 for local ONNX text-to-speech inference.

- Project: https://github.com/k2-fsa/sherpa-onnx
- License: Apache-2.0

## Supertonic 3

The optional local neural voice uses Supertonic 3 compatible assets distributed through the sherpa-onnx TTS model release.

- Model card: https://huggingface.co/Supertone/supertonic-3
- Model license: OpenRAIL-M
- Compatible package: https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models

The model is not committed to this repository or bundled in the base application package. It is downloaded only when the user requests neural voices.

## Other Flutter packages

The project uses packages including `audioplayers`, `file_picker`, `pdfrx`, `archive`, `xml`, `html`, `path_provider` and `flutter_tts`. Refer to each package's repository/package page for its license and notices.
