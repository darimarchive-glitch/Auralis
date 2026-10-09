# Auralis Reader 3.1.0-rc5

Esta é uma **pré-versão de teste** da nova geração Python + Qt/QML do Auralis.

## Incluído

- biblioteca visual com capas incorporadas e busca automática por metadados;
- leitor responsivo para desktop e celular;
- navegação inferior: Biblioteca, Ler, Traduzir e Audiobook;
- troca rápida de e-book sem sair do leitor;
- seleção das vozes disponíveis no sistema em painel inferior;
- controle de velocidade e preferência de voz persistente;
- narração em fila e sincronização por palavra quando o mecanismo TTS fornece posição;
- modo audiobook com avanço automático e temporizador;
- tradução de texto ou livro inteiro por capítulo;
- cache SQLite de traduções e progresso;
- alternância imediata entre Original e Traduzido;
- perfis de tradução faithful, modern, literal e study;
- suporte a EPUB, PDF com camada de texto, TXT, Markdown, HTML, DOCX, FB2 e RTF;
- licença proprietária — Todos os Direitos Reservados.

## Tradução por IA

O código inclui suporte opcional a Argos Translate, MADLAD-400 e uma segunda etapa de revisão literária. Os modelos grandes não são incorporados no instalador base; eles são dependências opcionais.

## Voz neural

O RC5 usa as vozes expostas pelo sistema através do Qt TextToSpeech. O runtime neural local permanece modular e será distribuído por plataforma quando os binários Android/Windows/Linux estiverem validados. Portanto, este RC não deve ser apresentado como tendo uma voz neural própria embutida.

## Objetivo deste RC

Validar instalação, importação de livros, interface, sincronização, TTS, tradução, persistência de progresso e empacotamento nas três plataformas antes da versão estável.
