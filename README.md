# Auralis Reader 3.1.0-rc5

Auralis é um leitor universal para **Android, Windows e Linux**, com biblioteca visual, leitura sincronizada com voz, modo audiobook e tradução literária integrada. O projeto é Python + Qt/QML no desktop e usa a mesma interface Qt Quick no APK sempre que o backend da plataforma permite.

## Experiência 3.1

A navegação principal fica na parte inferior: **Biblioteca · Ler · Traduzir · Audiobook**. No leitor, o botão **Livro** abre um seletor rápido de e-books sem abandonar a leitura; **Voz** abre um painel inferior com as vozes realmente instaladas no sistema e controle de velocidade.

A narração usa `QTextToSpeech.enqueue()` para manter vários trechos preparados. Quando o mecanismo suporta progresso palavra a palavra, o sinal `sayingWord` do Qt fornece a posição exata da palavra dentro do trecho; o Auralis converte essa posição para a posição absoluta no capítulo e destaca o texto que está sendo falado. Em engines sem esse recurso, o destaque cai para o trecho atual.

### Vozes

- Android: usa o mecanismo TTS instalado no aparelho. Vozes com nomes contendo **Natural, Neural, Premium, Enhanced ou Google** aparecem primeiro no menu.
- Windows: usa as vozes expostas pelo mecanismo WinRT/Qt TextToSpeech.
- Linux: usa os engines disponíveis através do Qt TextToSpeech, normalmente Speech Dispatcher.
- A voz preferida e a velocidade ficam salvas localmente.

O backend neural local continua isolado da interface. Isso permite acrescentar um runtime ONNX específico por plataforma sem reescrever leitor, biblioteca, sincronização ou audiobook.

## Tradução

O Auralis mantém dois caminhos locais:

- **Argos Lite** para tradução offline mais leve;
- **MADLAD-400 3B** para tradução local de maior qualidade;
- modo **Studio** com revisão literária opcional por Qwen para preservar tom, época e fluidez.

As traduções são feitas por capítulo e guardadas no SQLite. Depois de traduzir um livro, o leitor pode alternar instantaneamente entre **Original** e **Traduzido**, e o audiobook narra a versão que estiver ativa.

> Os modelos de tradução grandes não são embutidos no APK base. O APK de teste prioriza leitura, biblioteca, TTS real, sincronização e audiobook; os runtimes de IA local exigem binários próprios para Android e são instalados apenas em builds que os incluam.

## Formatos

EPUB, PDF com camada de texto, TXT, Markdown, HTML, DOCX, FB2 e RTF. EPUBs usam a capa incorporada quando disponível. Quando não há capa, o Auralis procura automaticamente por título/autor e só aceita correspondências acima do limiar de confiança.

## Builds

Os workflows em `.github/workflows/` produzem artefatos de teste e os anexem automaticamente ao GitHub Release correspondente ao arquivo `VERSION`:

- `Android APK` → `Auralis-Android-arm64.apk`
- `Windows build` → `Auralis-Windows-x64.zip`
- `Linux build` → `Auralis-Linux-x64.tar.gz`

O APK usa o processo oficial `pyside6-android-deploy` e wheels Android do Qt for Python. O modo `debug` gera um APK instalável diretamente; builds de loja devem usar AAB/release com assinatura própria.

## Desenvolvimento

```bash
python -m pip install -e '.[dev]'
pytest -q
python main.py
```

Tradução leve:

```bash
python -m pip install -e '.[translation-lite]'
```

Tradução IA local:

```bash
python -m pip install -e '.[translation-ai]'
```

## Privacidade

Biblioteca, progresso, preferências e traduções em cache ficam localmente. A busca automática de capa usa internet. TTS depende do mecanismo selecionado pelo sistema operacional; algumas vozes de sistema podem usar rede, conforme a configuração do próprio sistema.

## Licença

**Software proprietário — Todos os Direitos Reservados.** O código e os materiais próprios do Auralis não podem ser copiados, modificados, redistribuídos ou sublicenciados sem autorização prévia por escrito. Dependências de terceiros permanecem sob suas próprias licenças; consulte `THIRD_PARTY_NOTICES.md`.
