# Auralis Reader 3.1.1

Auralis é um leitor universal para **Android, Windows e Linux**, reconstruído
sobre uma única base **Flutter/Dart** para manter o mesmo comportamento nas três
plataformas.

## O que a 3.1.1 entrega

- EPUB, PDF com camada de texto, TXT, HTML, Markdown, DOCX, FB2 e RTF;
- biblioteca visual com capa incorporada do EPUB;
- busca automática de capa por título/autor em Open Library e Google Books;
- leitor com acompanhamento automático do trecho atual;
- destaque palavra a palavra quando o mecanismo TTS fornece speech marks;
- menu inferior para trocar de livro, traduzir, abrir audiobook e mudar voz;
- modo audiobook dedicado, avanço automático e temporizador;
- seleção e prévia das vozes realmente instaladas no aparelho;
- Supertonic 3 via sherpa-onnx como opção neural local/offline;
- tradução de livro completo com cache por idioma;
- modo de tradução rápida e modo IA literária OpenAI-compatible;
- perfis de tradução fiel à obra, moderno, literal e estudo;
- progresso, preferências, capas e traduções salvos localmente.

## Tradução literária

O modo rápido funciona sem credenciais. Para tradução literária por LLM, o
usuário informa no aplicativo um endpoint OpenAI-compatible, o modelo e, se o
provedor exigir, a própria chave. Esses dados são locais e **nenhuma chave é
incluída no GitHub**. Um servidor Ollama na rede local também pode ser usado.

## Vozes

No Android e Windows, o Auralis lista as vozes fornecidas pelo mecanismo TTS do
sistema e prioriza vozes que se identificam como Natural, Neural, Premium,
Enhanced, Studio ou de alta qualidade. No Linux há fallback por Speech
Dispatcher/espeak. O Supertonic 3 continua disponível como modelo offline
opcional.

## Desenvolvimento

```bash
python tool/bootstrap.py
flutter test
flutter analyze --no-fatal-infos
flutter run
```

`tool/bootstrap.py` gera os runners Android, Linux e Windows e aplica os ajustes
necessários de manifesto. As pastas nativas também fazem parte da release
3.1.1 para que o repositório seja reproduzível sem depender de arquivos
privados.

## Artefatos oficiais 3.1.1

- `Auralis-Reader-3.1.1.apk`
- `Auralis-Reader-3.1.1-Setup.exe`
- `Auralis-Reader-3.1.1.flatpak`
- `SHA256SUMS.txt`

A release só é publicada como estável quando os três builds e testes passam no
GitHub Actions.

## Privacidade

Biblioteca, progresso, preferências, traduções e chaves configuradas pelo
usuário não pertencem ao repositório. Capas e tradução rápida usam internet.
Algumas vozes de sistema também podem usar serviços do fabricante do aparelho.

## Licença

**Software proprietário — Todos os Direitos Reservados.** Consulte `LICENSE` e
`THIRD_PARTY_NOTICES.md`.
