# Auralis Reader 2.0

Auralis é um leitor universal multiplataforma para **Android, Windows e Linux**, com foco em leitura confortável e narração por voz neural local.

A versão 2.0 foi reorganizada como um projeto limpo e mantém a versão anterior preservada na branch `legacy-1.2`.

## Vozes realistas e locais

O modo principal de narração usa **Supertonic 3** através do `sherpa_onnx` 1.13.8. A síntese acontece no próprio aparelho, sem tokens e sem API de voz paga. O pacote neural é baixado uma única vez, verificado por SHA-256 e instalado no armazenamento privado do aplicativo.

O modelo oferece **10 vozes (F1–F5 e M1–M5)** e 31 idiomas, incluindo português, inglês, espanhol, francês, alemão, italiano, japonês e coreano. O Auralis também mantém o TTS do sistema como fallback.

### Modelo usado

- pacote: `sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2`
- tamanho do download: 128.774.318 bytes (~123 MiB)
- SHA-256: `82fa96f91c4ef8abaae3a14a3f4153facf88bed821d1f7331cec2700f432c427`
- modelo: OpenRAIL-M
- runtime: `sherpa_onnx` / Apache-2.0

## Formatos

A biblioteca importa PDF com camada de texto, EPUB, TXT, HTML, Markdown, DOCX, FB2 e RTF. Os livros importados são copiados para o armazenamento privado do Auralis e o progresso é salvo localmente.

## Plataformas

### Android

O workflow `Android APK` gera:

```text
Auralis-Reader-2.0.0.apk
```

### Windows

O workflow `Windows EXE` compila o runner nativo e cria um instalador com Inno Setup:

```text
Auralis-Reader-2.0.0-Setup.exe
```

### Linux

O workflow `Linux Flatpak` compila o bundle Flutter Linux e empacota:

```text
Auralis-Reader-2.0.0.flatpak
```

O Flatpak usa `org.gnome.Platform//50`, atualmente suportado pelo Flathub, e tem acesso à rede somente porque o usuário pode optar por baixar o modelo neural.

## Desenvolvimento

Requisitos principais:

- Flutter stable 3.47+ / Dart 3.13+
- Android SDK para APK
- Visual Studio Desktop C++ para Windows
- GTK3, CMake, Ninja e toolchain Linux para Linux

O repositório não precisa guardar runners gerados pelo Flutter. Rode:

```bash
python tool/bootstrap.py
```

Depois:

```bash
flutter test
flutter analyze --no-fatal-infos
flutter run
```

## Build local

Android:

```bash
flutter build apk --release
```

Windows:

```powershell
flutter build windows --release
```

Linux:

```bash
flutter build linux --release
```

Para builds reproduzíveis de distribuição, use os workflows em `.github/workflows/`.

## Privacidade

No modo neural, o texto do livro é processado localmente. A conexão de internet é usada para baixar o modelo; depois da instalação, a síntese não precisa de serviço de nuvem. No modo TTS do sistema, o comportamento de rede depende do mecanismo de voz instalado no sistema operacional.

## Licenças

O código do Auralis é MIT. Dependências e modelos mantêm suas licenças próprias; veja `THIRD_PARTY_NOTICES.md`.
