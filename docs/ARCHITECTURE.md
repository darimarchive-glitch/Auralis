# Auralis 3.1.1 architecture

Auralis 3.1.1 usa Flutter/Dart como camada única de UI, biblioteca e fluxo de
leitura em Android, Windows e Linux.

- `controllers/`: estado da biblioteca e sessão de leitura.
- `models/`: livros, capítulos e preferências persistentes.
- `services/book_importer.dart`: extração de texto/metadados/capa.
- `services/book_repository.dart`: armazenamento local e cache de tradução.
- `services/cover_service.dart`: Open Library -> Google Books.
- `services/translation_service.dart`: tradução rápida ou LLM configurável.
- `services/tts_service.dart`: TTS do sistema e seleção de voz.
- `services/neural_tts_service.dart`: Supertonic/sherpa-onnx local.
- `ui/`: biblioteca, leitor, audiobook, tradução e folhas de controle.

O repositório não inclui segredos. Modelos neurais pesados são baixados em
runtime ou fornecidos pelo usuário.
