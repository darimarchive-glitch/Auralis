# Auralis 3.0

Auralis 3 é uma reescrita do leitor em **Python + Qt/QML**, com o mesmo núcleo para Linux,
Windows e Android. A geração Flutter anterior foi preservada na branch `legacy-flutter-2.1`.

O objetivo agora é ser três produtos em um só: **biblioteca**, **audiobook local** e **tradutor
literário de livros inteiros**.

## O que já está na nova arquitetura

- biblioteca local com SQLite e progresso persistente;
- importação de EPUB, PDF com camada de texto, TXT, Markdown, HTML, DOCX, FB2 e RTF;
- extração de capa do EPUB;
- busca automática de capa por título/autor: Open Library primeiro, Google Books como fallback;
- pontuação de confiança para evitar associar capas claramente erradas;
- normalização de hifenização, parágrafos, diálogos, abreviações e pontuação;
- pipeline TTS separado do parser, preparado para prefetch/cache e voz neural;
- tradutor de texto e de **livro completo**, com cache por capítulo;
- quatro modos de tradução: `faithful`, `modern`, `literal`, `study`;
- modo `smart`: prioriza o modelo local MADLAD-400 quando instalado;
- modo leve: Argos Translate, com pacotes de idioma baixados sob demanda;
- modo `studio`: MADLAD-400 + uma segunda revisão literária local por Qwen3;
- nenhum token, conta ou API paga é necessário para a tradução local;
- interface QML responsiva com Biblioteca e Tradutor no mesmo aplicativo.

## Tradução por IA

### Smart — MADLAD-400 3B

O backend de maior qualidade usa `google/madlad400-3b-mt`, um modelo especializado em tradução,
com suporte a centenas de idiomas. O modelo não é empacotado no APK/instalador: ele é baixado pelo
runtime local na primeira utilização e fica no cache do usuário.

Instalação de desenvolvimento:

```bash
python -m pip install -e '.[translation-ai]'
```

### Lite — Argos Translate

Para hardware mais fraco, o Auralis pode usar Argos Translate e baixar apenas os pares de idiomas
necessários:

```bash
python -m pip install -e '.[translation-lite]'
```

### Studio — tradução + revisão literária

O modo Studio adiciona um segundo passe com `Qwen/Qwen3-4B-Instruct-2507`, sempre local. O revisor
recebe o original e a tradução base e é instruído a não inventar, resumir ou omitir conteúdo. Esse
modo é especialmente útil para prosa antiga, diálogos, construções arcaicas e traduções em que se
quer escolher entre preservar a época ou usar linguagem contemporânea.

## Perfis literários

- **faithful**: conserva época, registro, ritmo e ambiguidades;
- **modern**: moderniza a linguagem sem resumir nem mudar fatos;
- **literal**: interfere o mínimo possível;
- **study**: prioriza clareza sem acrescentar notas ou conteúdo inexistente.

A estrutura do livro é mantida por capítulo e por parágrafo. A tradução é cacheada com hash do texto
original; se o capítulo não mudou, ele não é traduzido de novo.

## Voz e narração

Auralis mantém `QTextToSpeech` como fallback. A camada de narração já é independente do backend e
segmenta headings, diálogos e narração, permitindo que um backend neural gere os próximos trechos
enquanto o atual toca. `sherpa-onnx` e Supertonic continuam previstos como backend neural opcional.

## Desenvolvimento

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -e '.[dev]'
pytest
python main.py
```

Para tradução de alta qualidade:

```bash
python -m pip install -e '.[dev,translation-ai]'
```

## Android

Qt for Python fornece `pyside6-android-deploy`, que gera APK/AAB a partir da mesma aplicação QML.
Dependências nativas opcionais (sherpa-onnx/Argos/MADLAD) precisam de builds compatíveis com Android;
por isso o núcleo não depende delas para iniciar. O aplicativo continua funcional como leitor mesmo
quando um pacote neural não está instalado.

## Privacidade

Livros, progresso, traduções em cache e áudio ficam no dispositivo. A internet é usada apenas para
funções explícitas, como baixar modelos/pacotes e procurar metadados/capas. O texto de um livro não
precisa ser enviado a um serviço externo.

## Licença

Código e materiais próprios do Auralis são **proprietários — Todos os Direitos Reservados**.
Dependências e modelos mantêm suas licenças próprias; veja `THIRD_PARTY_NOTICES.md`.
