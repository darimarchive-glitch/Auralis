import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class NeuralVoice {
  const NeuralVoice({
    required this.id,
    required this.name,
    required this.kind,
  });

  final int id;
  final String name;
  final String kind;

  String get label => '$name • $kind';
}

class NeuralModelProgress {
  const NeuralModelProgress(this.value, this.message);

  final double value;
  final String message;
}

class NeuralTtsService {
  static const modelName = 'Supertonic 3 INT8';
  static const modelArchiveName =
      'sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2';
  static const modelFolderName =
      'sherpa-onnx-supertonic-3-tts-int8-2026-05-11';
  static const modelUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$modelArchiveName';
  static const modelArchiveBytes = 128774318;
  static const modelSha256 =
      '82fa96f91c4ef8abaae3a14a3f4153facf88bed821d1f7331cec2700f432c427';

  static const voices = <NeuralVoice>[
    NeuralVoice(id: 0, name: 'F1', kind: 'feminina'),
    NeuralVoice(id: 1, name: 'F2', kind: 'feminina'),
    NeuralVoice(id: 2, name: 'F3', kind: 'feminina'),
    NeuralVoice(id: 3, name: 'F4', kind: 'feminina'),
    NeuralVoice(id: 4, name: 'F5', kind: 'feminina'),
    NeuralVoice(id: 5, name: 'M1', kind: 'masculina'),
    NeuralVoice(id: 6, name: 'M2', kind: 'masculina'),
    NeuralVoice(id: 7, name: 'M3', kind: 'masculina'),
    NeuralVoice(id: 8, name: 'M4', kind: 'masculina'),
    NeuralVoice(id: 9, name: 'M5', kind: 'masculina'),
  ];

  static const supportedLanguageCodes = <String>{
    'ar',
    'bg',
    'cs',
    'da',
    'de',
    'el',
    'en',
    'es',
    'et',
    'fi',
    'fr',
    'hi',
    'hr',
    'hu',
    'id',
    'it',
    'ja',
    'ko',
    'lt',
    'lv',
    'nl',
    'pl',
    'pt',
    'ro',
    'ru',
    'sk',
    'sl',
    'sv',
    'tr',
    'uk',
    'vi',
  };

  final AudioPlayer _player = AudioPlayer();
  Isolate? _worker;
  ReceivePort? _receivePort;
  SendPort? _workerPort;
  Completer<void>? _readyCompleter;
  final Map<int, Completer<String>> _pending = {};
  int _requestId = 0;
  int _workerGeneration = 0;
  bool _downloading = false;
  Completer<void>? _playbackCancelled;

  bool get supportedPlatform =>
      Platform.isAndroid || Platform.isLinux || Platform.isWindows;

  bool supportsLanguage(String locale) =>
      supportedLanguageCodes.contains(_languageCode(locale));

  Future<Directory> _ttsRoot() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'tts_models'));
  }

  Future<Directory> modelDirectory() async {
    final root = await _ttsRoot();
    return Directory(p.join(root.path, 'supertonic3'));
  }

  Future<bool> isInstalled() async {
    if (!supportedPlatform) return false;
    final dir = await modelDirectory();
    if (!await dir.exists()) return false;
    for (final name in _requiredFiles) {
      final file = File(p.join(dir.path, name));
      if (!await file.exists() || await file.length() == 0) return false;
    }
    return true;
  }

  Future<void> downloadModel({
    void Function(NeuralModelProgress progress)? onProgress,
  }) async {
    if (!supportedPlatform) {
      throw UnsupportedError('A voz neural ainda não está disponível nesta plataforma.');
    }
    if (_downloading) {
      throw StateError('O download da voz neural já está em andamento.');
    }
    if (await isInstalled()) {
      onProgress?.call(const NeuralModelProgress(1, 'Voz neural instalada.'));
      return;
    }

    _downloading = true;
    final root = await _ttsRoot();
    await root.create(recursive: true);
    final archiveFile = File(p.join(root.path, modelArchiveName));
    final staging = Directory(p.join(root.path, '.supertonic3-staging'));
    final target = await modelDirectory();

    try {
      if (await staging.exists()) await staging.delete(recursive: true);
      if (await archiveFile.exists()) await archiveFile.delete();

      onProgress?.call(const NeuralModelProgress(0, 'Baixando modelo neural…'));
      await _download(archiveFile, onProgress);

      onProgress?.call(
        const NeuralModelProgress(
          .82,
          'Verificando e preparando a voz em segundo plano…',
        ),
      );

      // SHA-256 + BZip2/TAR são operações pesadas de CPU. Executá-las no
      // isolate da interface fazia o Android aparentar travar em
      // "Verificando download…" e podia disparar um ANR em aparelhos mais
      // lentos. Todo o trabalho pesado de instalação agora roda fora da UI.
      await staging.create(recursive: true);
      final installError = await Isolate.run<String?>(() async {
        try {
          final digest = await sha256.bind(archiveFile.openRead()).first;
          if (digest.toString() != modelSha256) {
            return 'A verificação SHA-256 do modelo falhou. Tente baixar novamente.';
          }
          await extractFileToDisk(
            archiveFile.path,
            staging.path,
            bufferSize: 256 * 1024,
          );
          return null;
        } catch (e) {
          return 'Falha ao preparar o modelo neural: $e';
        }
      });
      if (installError != null) {
        throw StateError(installError);
      }

      onProgress?.call(
        const NeuralModelProgress(.94, 'Validando arquivos do modelo…'),
      );
      final extracted = Directory(p.join(staging.path, modelFolderName));
      if (!await extracted.exists()) {
        throw StateError('O pacote da voz neural não contém a pasta esperada.');
      }
      for (final name in _requiredFiles) {
        final file = File(p.join(extracted.path, name));
        if (!await file.exists() || await file.length() == 0) {
          throw StateError('Arquivo obrigatório ausente no modelo: $name');
        }
      }

      await stop();
      _resetWorker();
      if (await target.exists()) await target.delete(recursive: true);
      await extracted.rename(target.path);
      onProgress?.call(const NeuralModelProgress(.98, 'Finalizando instalação…'));

      if (!await isInstalled()) {
        throw StateError('A voz neural foi extraída, mas a instalação não pôde ser validada.');
      }
      onProgress?.call(const NeuralModelProgress(1, 'Voz neural pronta para uso.'));
    } finally {
      _downloading = false;
      if (await archiveFile.exists()) {
        try {
          await archiveFile.delete();
        } catch (_) {}
      }
      if (await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<void> _download(
    File destination,
    void Function(NeuralModelProgress progress)? onProgress,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(modelUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'Auralis-Reader/1.2');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Falha ao baixar o modelo: HTTP ${response.statusCode}.',
          uri: Uri.parse(modelUrl),
        );
      }
      final total = response.contentLength > 0
          ? response.contentLength
          : modelArchiveBytes;
      var received = 0;
      final output = destination.openWrite();
      sink = output;
      await for (final bytes in response) {
        output.add(bytes);
        received += bytes.length;
        final networkProgress = (received / total).clamp(0.0, 1.0).toDouble();
        onProgress?.call(
          NeuralModelProgress(
            networkProgress * .8,
            'Baixando modelo neural… ${(networkProgress * 100).round()}%',
          ),
        );
      }
      await output.flush();
      await output.close();
      sink = null;
    } finally {
      if (sink != null) await sink.close();
      client.close(force: true);
    }
  }

  Future<void> deleteModel() async {
    await stop();
    _resetWorker();
    final dir = await modelDirectory();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> speak(
    String text, {
    required String language,
    required double rate,
    required int voiceId,
    required int numSteps,
  }) async {
    if (text.trim().isEmpty) return;
    if (!supportsLanguage(language)) {
      throw UnsupportedError('O $modelName não oferece o idioma $language.');
    }
    if (!await isInstalled()) {
      throw StateError('Baixe a voz neural nas configurações antes de usá-la.');
    }

    await _player.stop();
    final dir = await modelDirectory();
    try {
      await _ensureWorker(dir.path);
    } on _NeuralCancelled {
      return;
    }

    final temp = await getTemporaryDirectory();
    final id = ++_requestId;
    final output = p.join(temp.path, 'auralis-neural-$id.wav');
    final completer = Completer<String>();
    _pending[id] = completer;

    _workerPort!.send(
      _NeuralGenerate(
        id: id,
        text: text,
        outputPath: output,
        language: _languageCode(language),
        sid: voiceId.clamp(0, 9).toInt(),
        speed: (rate / .5).clamp(.6, 1.6).toDouble(),
        numSteps: numSteps.clamp(4, 16).toInt(),
      ),
    );

    String path;
    try {
      path = await completer.future;
    } on _NeuralCancelled {
      final cancelledFile = File(output);
      if (await cancelledFile.exists()) {
        try {
          await cancelledFile.delete();
        } catch (_) {}
      }
      return;
    }

    final cancelled = Completer<void>();
    _playbackCancelled = cancelled;
    try {
      final playbackDone = _player.onPlayerComplete.first;
      await _player.play(DeviceFileSource(path));
      await Future.any<void>([playbackDone, cancelled.future]);
    } finally {
      if (identical(_playbackCancelled, cancelled)) {
        _playbackCancelled = null;
      }
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _ensureWorker(String modelDir) async {
    if (_workerPort != null && _readyCompleter == null) return;
    if (_readyCompleter != null) return _readyCompleter!.future;

    final ready = Completer<void>();
    _readyCompleter = ready;
    final receive = ReceivePort();
    _receivePort = receive;

    receive.listen((message) {
      if (message is SendPort) {
        _workerPort = message;
      } else if (message is _NeuralReady) {
        if (!ready.isCompleted) ready.complete();
        _readyCompleter = null;
      } else if (message is _NeuralGenerated) {
        final pending = _pending.remove(message.id);
        if (pending != null && !pending.isCompleted) {
          pending.complete(message.path);
        }
      } else if (message is _NeuralWorkerError) {
        if (message.id == null) {
          if (!ready.isCompleted) ready.completeError(StateError(message.message));
          _readyCompleter = null;
          _resetWorker();
        } else {
          final pending = _pending.remove(message.id);
          if (pending != null && !pending.isCompleted) {
            pending.completeError(StateError(message.message));
          }
        }
      }
    });

    final generation = _workerGeneration;
    final spawned = await Isolate.spawn(
      _neuralWorkerMain,
      _NeuralBootstrap(receive.sendPort, modelDir),
      debugName: 'auralis-supertonic',
    );
    if (generation != _workerGeneration) {
      spawned.kill(priority: Isolate.immediate);
      return ready.future;
    }
    _worker = spawned;
    return ready.future;
  }

  Future<void> stop() async {
    final initializing = _readyCompleter;
    if (initializing != null && !initializing.isCompleted) {
      initializing.completeError(const _NeuralCancelled());
      _resetWorker();
    }
    final playbackCancelled = _playbackCancelled;
    if (playbackCancelled != null && !playbackCancelled.isCompleted) {
      playbackCancelled.complete();
    }
    _playbackCancelled = null;
    await _player.stop();
    if (_pending.isNotEmpty) {
      for (final completer in _pending.values) {
        if (!completer.isCompleted) completer.completeError(const _NeuralCancelled());
      }
      _pending.clear();
      _resetWorker();
    }
  }

  void _resetWorker() {
    _workerGeneration++;
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    _workerPort = null;
    _receivePort?.close();
    _receivePort = null;
    _readyCompleter = null;
  }

  Future<void> dispose() async {
    await stop();
    _workerPort?.send(const _NeuralDispose());
    _resetWorker();
    await _player.dispose();
  }

  static String _languageCode(String locale) =>
      locale.toLowerCase().replaceAll('_', '-').split('-').first;

  static const _requiredFiles = <String>[
    'duration_predictor.int8.onnx',
    'text_encoder.int8.onnx',
    'vector_estimator.int8.onnx',
    'vocoder.int8.onnx',
    'tts.json',
    'unicode_indexer.bin',
    'voice.bin',
  ];
}

class _NeuralBootstrap {
  const _NeuralBootstrap(this.mainPort, this.modelDir);
  final SendPort mainPort;
  final String modelDir;
}

class _NeuralGenerate {
  const _NeuralGenerate({
    required this.id,
    required this.text,
    required this.outputPath,
    required this.language,
    required this.sid,
    required this.speed,
    required this.numSteps,
  });

  final int id;
  final String text;
  final String outputPath;
  final String language;
  final int sid;
  final double speed;
  final int numSteps;
}

class _NeuralReady {
  const _NeuralReady(this.numSpeakers);
  final int numSpeakers;
}

class _NeuralGenerated {
  const _NeuralGenerated(this.id, this.path);
  final int id;
  final String path;
}

class _NeuralWorkerError {
  const _NeuralWorkerError(this.message, {this.id});
  final String message;
  final int? id;
}

class _NeuralDispose {
  const _NeuralDispose();
}

class _NeuralCancelled implements Exception {
  const _NeuralCancelled();
}

void _neuralWorkerMain(_NeuralBootstrap bootstrap) {
  final receive = ReceivePort();
  bootstrap.mainPort.send(receive.sendPort);
  sherpa_onnx.OfflineTts? tts;

  try {
    sherpa_onnx.initBindings();
    final dir = bootstrap.modelDir;
    final model = sherpa_onnx.OfflineTtsSupertonicModelConfig(
      durationPredictor: p.join(dir, 'duration_predictor.int8.onnx'),
      textEncoder: p.join(dir, 'text_encoder.int8.onnx'),
      vectorEstimator: p.join(dir, 'vector_estimator.int8.onnx'),
      vocoder: p.join(dir, 'vocoder.int8.onnx'),
      ttsJson: p.join(dir, 'tts.json'),
      unicodeIndexer: p.join(dir, 'unicode_indexer.bin'),
      voiceStyle: p.join(dir, 'voice.bin'),
    );
    final config = sherpa_onnx.OfflineTtsConfig(
      model: sherpa_onnx.OfflineTtsModelConfig(
        supertonic: model,
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      ),
      maxNumSenetences: 1,
    );
    tts = sherpa_onnx.OfflineTts(config);
    bootstrap.mainPort.send(_NeuralReady(tts.numSpeakers));
  } catch (e) {
    bootstrap.mainPort.send(_NeuralWorkerError('Falha ao iniciar $e'));
    receive.close();
    return;
  }

  receive.listen((message) {
    if (message is _NeuralGenerate) {
      try {
        final config = sherpa_onnx.OfflineTtsGenerationConfig(
          sid: message.sid,
          speed: message.speed,
          numSteps: message.numSteps,
          silenceScale: .2,
          extra: <String, Object>{'lang': message.language},
        );
        final audio = tts!.generateWithConfig(text: message.text, config: config);
        final ok = sherpa_onnx.writeWave(
          filename: message.outputPath,
          samples: audio.samples,
          sampleRate: audio.sampleRate,
        );
        if (!ok) {
          throw StateError('Não foi possível gravar o áudio temporário.');
        }
        bootstrap.mainPort.send(_NeuralGenerated(message.id, message.outputPath));
      } catch (e) {
        bootstrap.mainPort.send(_NeuralWorkerError('$e', id: message.id));
      }
    } else if (message is _NeuralDispose) {
      tts?.free();
      tts = null;
      receive.close();
    }
  });
}
