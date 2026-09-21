# Auralis Reader 1.2.0

Leitor universal gratuito e local, com interface inspirada no GNOME/GTK Adwaita. O objetivo é transformar livros em uma experiência de leitura + narração sem conta, créditos ou tokens.

## Destaque da 1.2: voz neural realmente local

Auralis agora possui dois backends de narração:

- **Neural — Supertonic 3 (recomendado):** síntese ONNX local via `sherpa_onnx`, com 10 estilos de voz e suporte a português. O modelo é baixado uma vez (~123 MiB) e, depois disso, a síntese acontece no próprio dispositivo.
- **Sistema:** usa Google Speech Services, Samsung TTS, Microsoft TTS ou outro mecanismo instalado, com fallback Linux para `speech-dispatcher`/`espeak-ng`.

O modelo neural não é empacotado no APK. Isso mantém o instalador menor e permite que o usuário decida se quer ocupar espaço com o modelo. O download é validado com SHA-256 antes da instalação.

### Idiomas do modo neural

Supertonic 3 suporta 31 idiomas, incluindo português, inglês, espanhol, francês, alemão, italiano, japonês e coreano. O Auralis converte locales como `pt-BR` para o código de síntese `pt` automaticamente.

### Vozes

O pacote oficial expõe 10 speakers, identificados como `F1`–`F5` e `M1`–`M5`. O usuário pode alternar entre todos eles nas configurações e ouvir uma prévia.

## Recursos do leitor

- Biblioteca local persistente.
- Importa **PDF com camada de texto, EPUB, TXT, HTML, Markdown, DOCX, FB2 e RTF**.
- Copia o livro para o armazenamento privado do aplicativo.
- Divide conteúdo em capítulos/blocos e normaliza espaços, quebras e hifenização de PDF.
- Narração sequencial com destaque do trecho atual.
- Toque em qualquer trecho para continuar dali.
- Retomada automática de capítulo e trecho.
- Velocidade de leitura ajustável.
- Tema claro/escuro/sistema com visual Adwaita.
- Sem login, backend próprio, API key ou consumo de tokens.

## Privacidade

O texto dos livros não é enviado a um serviço de TTS quando o modo Neural é usado. A internet é necessária somente para baixar o pacote do modelo. Biblioteca, texto extraído e progresso permanecem no armazenamento do aplicativo.

No modo Sistema, o comportamento de rede depende do mecanismo TTS escolhido pelo usuário e das configurações desse mecanismo.

## Requisitos de desenvolvimento

- Flutter **3.47+** / Dart **3.13+**.
- Android SDK para APK.
- Linux: toolchain Flutter Linux + GTK de desenvolvimento.
- Windows: Visual Studio com Desktop development with C++.

## Preparar o projeto

Os runners `android/`, `linux/` e `windows/` são gerados pela versão instalada do Flutter:

```bash
python tool/bootstrap.py
```

Esse passo também adiciona a permissão `INTERNET` ao Android para o download opcional do modelo neural e registra a consulta dos mecanismos TTS do sistema.

Depois:

```bash
flutter run -d linux
# ou
flutter run -d windows
# ou um Android conectado/emulador
```

## Gerar builds

```bash
python tool/build.py
```

Saída Android típica:

```text
build/app/outputs/flutter-apk/app-release.apk
```

O repositório também inclui `.github/workflows/android.yml`. Cada push para `main` executa testes, análise e gera um APK como artifact do GitHub Actions.

## Modelo neural

A implementação fica em `lib/services/neural_tts_service.dart`.

Fluxo:

1. Baixa `sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2`.
2. Verifica o SHA-256 esperado.
3. Extrai o modelo para o diretório privado de suporte do app.
4. Mantém a inferência em um isolate dedicado para não bloquear a interface.
5. Gera um WAV temporário por trecho.
6. Reproduz o WAV localmente e apaga o arquivo temporário.
7. Mantém o TTS do sistema como fallback quando o modelo não está instalado ou o idioma não é suportado.

O modelo usa 8 etapas de síntese por padrão, conforme os exemplos oficiais do Supertonic 3 no sherpa-onnx. O usuário pode escolher 6, 8 ou 12 nas configurações.

## Estrutura

```text
lib/
├── controllers/
│   ├── app_controller.dart
│   └── reader_controller.dart
├── models/
│   ├── book.dart
│   └── settings.dart
├── services/
│   ├── book_importer.dart
│   ├── book_repository.dart
│   ├── neural_tts_service.dart
│   ├── text_normalizer.dart
│   └── tts_service.dart
└── ui/
    ├── library_page.dart
    ├── reader_page.dart
    ├── settings_page.dart
    └── widgets/book_card.dart
```

## Limites conhecidos

1. **PDF escaneado:** OCR local ainda não está implementado.
2. **MOBI/AZW3:** ainda não fazem parte do importador.
3. **Primeira instalação da voz neural:** exige internet e espaço temporário adicional para download/descompactação.
4. **Desempenho:** a velocidade da síntese neural depende da CPU do aparelho.
5. DRM não é removido nem contornado.

## Licenças

- Código do Auralis: MIT.
- `sherpa-onnx`: Apache-2.0.
- Modelo Supertonic 3: OpenRAIL-M.

Veja [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) antes de redistribuir o aplicativo com alterações no mecanismo/modelo de voz.
