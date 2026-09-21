# Arquitetura do Auralis Reader 1.2

## Camadas

- `BookImporter`: identifica o formato e extrai texto/chapter data.
- `BookRepository`: persiste biblioteca, configurações e conteúdo extraído.
- `AppController`: estado global da biblioteca/configurações.
- `ReaderController`: navegação, progresso e fila sequencial de trechos narrados.
- `LocalTtsService`: fachada de narração. Decide entre backend neural e TTS do sistema.
- `NeuralTtsService`: download, validação, instalação, inferência Supertonic 3 e reprodução.

## Backend neural

O modelo não é enviado no APK. `NeuralTtsService` baixa o arquivo oficial compatível com sherpa-onnx e valida o SHA-256 antes de extrair.

A instância `OfflineTts` vive em um isolate persistente. Assim, o modelo não precisa ser recarregado para cada trecho e a chamada de inferência não bloqueia o isolate da interface. O isolate retorna um caminho de WAV temporário; o isolate principal usa `audioplayers` para reproduzi-lo e remove o arquivo após a conclusão.

`ReaderController.play()` continua aguardando cada chamada `speak()`. Isso preserva a lógica existente de avançar um trecho apenas depois que o áudio anterior terminou.

Ao pausar durante uma inferência, o worker neural é encerrado. Na próxima reprodução ele é recriado. Durante reprodução de WAV, apenas o player é interrompido e o modelo permanece carregado.

## Fallback

Se o backend configurado for neural, mas o modelo não estiver instalado ou o idioma não fizer parte dos 31 idiomas suportados, `LocalTtsService` usa o TTS do sistema. Isso evita tornar o leitor inutilizável antes do download.

## Dados

- Livros e progresso: diretório de suporte do app.
- Modelo neural: `<support>/tts_models/supertonic3/`.
- WAVs gerados: diretório temporário e removidos depois da reprodução.
- Não existe servidor próprio do Auralis.
