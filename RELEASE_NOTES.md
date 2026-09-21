# Release notes

## 2.0.0

- Reorganização do Auralis como projeto multiplataforma limpo.
- Branch `legacy-1.2` criada antes da migração.
- Dependências atualizadas para o ecossistema Flutter de setembro de 2026.
- `file_picker` migrado para a API 13.1.0.
- `pdfrx` 2.6.5 inicializado corretamente antes de usar as APIs de PDF.
- `sherpa_onnx` 1.13.8 como runtime de TTS neural offline.
- Supertonic 3 INT8 como voz neural principal, com 10 speakers e 31 idiomas.
- Download do modelo com SHA-256 e armazenamento local.
- TTS do sistema preservado como fallback.
- GitHub Actions independentes para APK Android, instalador EXE do Windows e Flatpak Linux.
- Instalador Windows criado com Inno Setup.
- Flatpak baseado em GNOME Platform 50.
- Correção permanente da regex Unicode usada para juntar palavras hifenizadas em PDFs.

## 1.2.0

- Primeira integração experimental do Supertonic 3.
- Seleção de backend neural/sistema.

## 1.1.0

- Seleção de mecanismos TTS instalados no Android.
