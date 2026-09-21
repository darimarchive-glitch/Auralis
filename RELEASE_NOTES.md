# Release notes

## 1.2.0

- Novo backend de voz neural local baseado em Supertonic 3 + sherpa-onnx.
- 10 vozes neurais selecionáveis (F1–F5 e M1–M5).
- Português e outros 30 idiomas suportados pelo modelo.
- Download do modelo dentro do app, com barra de progresso e verificação SHA-256.
- Inferência executada em isolate dedicado para evitar bloquear a interface.
- Reprodução local do áudio gerado e limpeza automática de WAVs temporários.
- Fallback para o TTS do sistema se o modelo neural não estiver disponível.
- Configuração de 6/8/12 etapas de síntese; padrão 8.
- Permissão Android de internet adicionada pelo bootstrap somente para permitir o download opcional do modelo.
- Workflow GitHub Actions para testar/analisar e compilar APK automaticamente.

## 1.1.0

- Seleção de mecanismo TTS no Android.
- Priorização de Google/Samsung/Microsoft quando disponíveis.
- Ordenação das vozes do sistema por metadados de qualidade.
- Prévia de voz nas configurações.
- Correção da expressão regular Unicode usada na normalização de hifenização de PDFs.
