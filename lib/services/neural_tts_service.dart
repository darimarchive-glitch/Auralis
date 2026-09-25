import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audioplayers/audioplayers.dart';
import 'package:convert/convert.dart';
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

  // Pinamos o commit exato do espelho mantido pelo sherpa-onnx. Em vez de
  // baixar um .tar.bz2 e descompactá-lo no Android, o Auralis baixa os
  // arquivos finais diretamente. Isso elimina o pico de CPU/espaço temporário
  // que fazia alguns aparelhos fecharem durante "Verificando download…".
  static const _modelRevision =
      'cca5a0e6c96e1d2c720986bf7e75fcc81dee3ae4';
  static const _modelBaseUrl =
      'https://huggingface.co/csukuangfj2/'
      'sherpa-onnx-supertonic-3-tts-int8-2026-05-11/resolve/'
      '$_modelRevision';

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

  static const _assets = <_ModelAsset>[
    _ModelAsset(
      name: 'duration_predictor.int8.onnx',
      size: 3700147,
      sha256:
          'c3eb91414d5ff8a7a239b7fe9e34e7e2bf8a8140d8375ffb14718b1c639325db',
    ),
    _ModelAsset(
      name: 'text_encoder.int8.onnx',
      size: 36416150,
      sha256:
          'c7befd5ea8c3119769e8a6c1486c4edc6a3bc8365c67621c881bbb774b9902ff',
    ),
    _ModelAsset(name: 'tts.json', size: 8448),
    _ModelAsset(
      name: 'unicode_indexer.bin',
      size: 262144,
      sha256:
          '8402ca48e5189a8950138580b0fff64db6f072f24ac07cd54ba8b2fbb9883b30',
    ),
    _ModelAsset(
      name: 'vector_estimator.int8.onnx',
      size: 78400833,
      sha256:
          '20cd86fa5c6effedfda0e7cffe5b0569ca401c440a0c3a1d72bf39286c0db3fd',
    ),
    _ModelAsset(
      name: 'vocoder.int8.onnx',
      size: 25991073,
      sha256:
          'e923d60f53f95eb1ce235f1dc33ec56d9c057823c96fa6f8acf98f32b0da6152',
    ),
    _ModelAsset(
      name: 'voice.bin',
      size: 517168,
      sha256:
          '67d5209b0ee8ce6c74105ffbe12fe6a7628aea3b4ba2fcb308a4a67938a93ce8',
    ),
  ];

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
    for (final asset in _assets) {
      final file = File(p.join(dir.path, asset.name));
      if (!await file.exists()) return false;
      final length = await file.length();
      if (length <= 0) return false;
      if (asset.name != 'tts.json' && length != asset.size) return false;
    }
    return true;
  }

  Future<void> downloadModel({
    void Function(NeuralModelProgress progress)? onProgress,
  }) async {
    if (!supportedPlatform) {
      throw UnsupportedError(
        'A voz neural ainda não está disponível nesta plataforma.',
      );
    }
    if (_downloading) {
      throw StateError('O download da voz neural já está em andamento.');
    }
    if (await isInstalled()) {
      onProgress?.call(const NeuralModelProgress(1, 'Voz offline instalada.'));
      return;
    }

    _downloading = true;
    final root = await _ttsRoot();
    await root.create(recursive: true);

    // Limpa resíduos do instalador 2.0.x. Se o Android encerrasse o processo
    // durante a antiga etapa de verificação/descompactação, o arquivo de
    // ~123 MiB e a pasta de staging podiam permanecer ocupando espaço.
    final legacyArchive = File(
      p.join(
        root.path,
        'sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2',
      ),
    );
    final legacyStaging = Directory(
      p.join(root.path, '.supertonic3-staging'),
    );
    if (await legacyArchive.exists()) {
      try {
        await legacyArchive.delete();
      } catch (_) {}
    }
    if (await legacyStaging.exists()) {
      try {
        await legacyStaging.delete(recursive: true);
      } catch (_) {}
    }

    final staging = Directory(p.join(root.path, '.supertonic3-download'));
    final target = await modelDirectory();

    try {
      if (await staging.exists()) await staging.delete(recursive: true);
      await staging.create(recursive: true);

      final totalWeight = _assets.fold<int>(0, (sum, asset) => sum + asset.size);
      var finishedWeight = 0;

      for (var i = 0; i < _assets.length; i++) {
        final asset = _assets[i];
        onProgress?.call(
          NeuralModelProgress(
            finishedWeight / totalWeight,
            'Baixando voz offline • arquivo ${i + 1} de ${_assets.length}',
          ),
        );

        await _downloadAsset(
          asset,
          File(p.join(staging.path, asset.name)),
          onProgress: (received) {
            final current = received.clamp(0, asset.size);
            final progress =
                ((finishedWeight + current) / totalWeight).clamp(0.0, .97);
            onProgress?.call(
              NeuralModelProgress(
                progress,
                'Baixando e verificando • ${i + 1}/${_assets.length}',
              ),
            );
          },
        );
        finishedWeight += asset.size;
      }

      onProgress?.call(
        const NeuralModelProgress(.98, 'Finalizando instalação…'),
      );

      await stop();
      _resetWorker();
      if (await target.exists()) await target.delete(recursive: true);
      await staging.rename(target.path);

      if (!await isInstalled()) {
        throw StateError(
          'A voz offline foi baixada, mas a instalação não pôde ser validada.',
        );
      }

      onProgress?.call(
        const NeuralModelProgress(1, 'Voz offline pronta para uso.'),
      );
    } finally {
      _downloading = false;
      if (await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<void> _downloadAsset(
    _ModelAsset asset,
    File destination, {
    required void Function(int received) onProgress,
  }) async {
    final partial = File('${destination.path}.part');
    if (await partial.exists()) await partial.delete();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);
    IOSink? sink;

    try {
      final uri = Uri.parse('$_modelBaseUrl/${asset.name}?download=true');
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 8;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Auralis-Reader/2.1',
      );

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Falha ao baixar ${asset.name}: HTTP ${response.statusCode}.',
          uri: uri,
        );
      }

      final digestOutput = AccumulatorSink<Digest>();
      final digestInput = sha256.startChunkedConversion(digestOutput);
      final output = partial.openWrite();
      sink = output;
      var received = 0;

      await for (final bytes in response) {
        output.add(bytes);
        digestInput.add(bytes);
        received += bytes.length;
        onProgress(received);
      }

      digestInput.close();
      await output.flush();
      await output.close();
      sink = null;

      if (received != asset.size) {
        throw StateError(
          'Download incompleto de ${asset.name}: '
          '$received de ${asset.size} bytes.',
        );
      }

      if (asset.sha256 != null) {
        final digest = digestOutput.events.single.toString();
        if (digest != asset.sha256) {
          throw StateError(
            'A verificação de integridade de ${asset.name} falhou.',
          );
        }
      }

      await partial.rename(destination.path);
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close(force: true);
      if (await partial.exists() && !await destination.exists()) {
        try {
          await partial.delete();
        } catch (_) {}
      }
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
      throw StateError(
        'Baixe a voz offline nas configurações antes de usá-la.',
      );
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
        speed: (rate / .5).clamp(.65, 1.45).toDouble(),
        numSteps: numSteps.clamp(6, 16).toInt(),
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
          if (!ready.isCompleted) {
            ready.completeError(StateError(message.message));
          }
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
        if (!completer.isCompleted) {
          completer.completeError(const _NeuralCancelled());
        }
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
}

class _ModelAsset {
  const _ModelAsset({
    required this.name,
    required this.size,
    this.sha256,
  });

  final String name;
  final int size;
  final String? sha256;
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
    bootstrap.mainPort.send(_NeuralWorkerError('Falha ao iniciar: $e'));
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
          silenceScale: .18,
          extra: <String, Object>{'lang': message.language},
        );
        final audio = tts!.generateWithConfig(
          text: message.text,
          config: config,
        );
        final ok = sherpa_onnx.writeWave(
          filename: message.outputPath,
          samples: audio.samples,
          sampleRate: audio.sampleRate,
        );
        if (!ok) {
          throw StateError('Não foi possível gravar o áudio temporário.');
        }
        bootstrap.mainPort.send(
          _NeuralGenerated(message.id, message.outputPath),
        );
      } catch (e) {
        bootstrap.mainPort.send(
          _NeuralWorkerError('$e', id: message.id),
        );
      }
    } else if (message is _NeuralDispose) {
      tts?.free();
      tts = null;
      receive.close();
    }
  });
}
