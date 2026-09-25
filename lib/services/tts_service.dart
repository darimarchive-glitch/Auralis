import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import '../models/settings.dart';
import 'neural_tts_service.dart';

typedef TtsProgressCallback = void Function(
  int start,
  int end,
  String word,
);

class TtsVoice {
  const TtsVoice({
    required this.name,
    required this.locale,
    this.quality,
    this.latency,
    this.networkRequired = false,
    this.features = const <String>[],
  });

  final String name;
  final String locale;
  final int? quality;
  final int? latency;
  final bool networkRequired;
  final List<String> features;

  bool get isEnhanced {
    final lower = name.toLowerCase();
    return (quality ?? 0) >= 400 ||
        lower.contains('neural') ||
        lower.contains('natural') ||
        lower.contains('wavenet') ||
        lower.contains('studio') ||
        lower.contains('enhanced') ||
        lower.contains('premium');
  }

  int get naturalScore {
    var score = quality ?? 0;
    if (isEnhanced) score += 500;
    if (networkRequired) score += 180;
    final lower = name.toLowerCase();
    if (lower.contains('studio')) score += 100;
    if (lower.contains('wavenet')) score += 90;
    if (lower.contains('neural')) score += 80;
    if (lower.contains('natural')) score += 70;
    return score;
  }

  String get label {
    final badges = <String>[];
    if (isEnhanced) badges.add('alta qualidade');
    if (networkRequired) badges.add('online');
    final suffix = badges.isEmpty ? '' : ' • ${badges.join(' • ')}';
    return '$name — $locale$suffix';
  }
}

class LocalTtsService {
  final FlutterTts _tts = FlutterTts();
  final NeuralTtsService neural = NeuralTtsService();
  Process? _linuxProcess;
  bool _configured = false;
  String? _activeEngine;
  TtsProgressCallback? _systemProgress;

  Future<bool> neuralModelInstalled() => neural.isInstalled();

  Future<void> downloadNeuralModel({
    void Function(NeuralModelProgress progress)? onProgress,
  }) =>
      neural.downloadModel(onProgress: onProgress);

  Future<void> deleteNeuralModel() => neural.deleteModel();

  Future<void> _configure() async {
    if (_configured || Platform.isLinux) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1.0);
    _tts.setProgressHandler((text, start, end, word) {
      final callback = _systemProgress;
      if (callback != null) callback(start, end, word);
    });
    _configured = true;
  }

  Future<List<String>> engines() async {
    if (!Platform.isAndroid) return const [];
    await _configure();
    final raw = await _tts.getEngines;
    if (raw is! List) return const [];
    return raw
      .map((e) => e.toString())
      .where((e) => e.isNotEmpty)
      .toList()
      ..sort();
  }

  Future<String?> defaultEngine() async {
    if (!Platform.isAndroid) return null;
    await _configure();
    final raw = await _tts.getDefaultEngine;
    return raw?.toString();
  }

  Future<void> setEngine(String? engine) async {
    if (!Platform.isAndroid || engine == null || engine.isEmpty) return;
    await _configure();
    if (_activeEngine == engine) return;
    await _tts.setEngine(engine);
    _activeEngine = engine;
  }

  Future<String?> selectBestAndroidEngine() async {
    if (!Platform.isAndroid) return null;
    final available = await engines();
    if (available.isEmpty) return null;

    const preferred = <String>[
      'com.google.android.tts',
      'com.samsung.SMT',
      'com.microsoft.tts',
    ];
    for (final engine in preferred) {
      if (available.contains(engine)) {
        await setEngine(engine);
        return engine;
      }
    }

    final fallback = await defaultEngine() ?? available.first;
    await setEngine(fallback);
    return fallback;
  }

  Future<List<TtsVoice>> voices({String? engine}) async {
    if (Platform.isLinux) {
      return const [
        TtsVoice(name: 'Voz do sistema Linux', locale: 'system'),
      ];
    }

    await _configure();
    if (Platform.isAndroid) {
      if (engine != null) {
        await setEngine(engine);
      } else if (_activeEngine == null) {
        await selectBestAndroidEngine();
      }
    }

    final raw = await _tts.getVoices;
    if (raw is! List) return [];

    final result = <TtsVoice>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = item['name']?.toString();
      final locale = item['locale']?.toString();
      if (name == null || locale == null) continue;

      result.add(
        TtsVoice(
          name: name,
          locale: locale,
          quality: int.tryParse(item['quality']?.toString() ?? ''),
          latency: int.tryParse(item['latency']?.toString() ?? ''),
          networkRequired: item['network_required'] == true ||
              item['network_required']?.toString() == 'true',
          features: item['features'] is Iterable
              ? (item['features'] as Iterable)
                  .map((e) => e.toString())
                  .toList()
              : const <String>[],
        ),
      );
    }

    result.sort((a, b) {
      final quality = b.naturalScore.compareTo(a.naturalScore);
      if (quality != 0) return quality;
      final locale = a.locale.compareTo(b.locale);
      if (locale != 0) return locale;
      return a.name.compareTo(b.name);
    });
    return result;
  }

  TtsVoice? bestVoiceForLanguage(
    List<TtsVoice> voices,
    String language,
  ) {
    if (voices.isEmpty) return null;

    final normalized = language.toLowerCase().replaceAll('_', '-');
    final languageCode = normalized.split('-').first;
    final exact = voices
        .where(
          (voice) =>
              voice.locale.toLowerCase().replaceAll('_', '-') == normalized,
        )
        .toList()
      ..sort((a, b) => b.naturalScore.compareTo(a.naturalScore));
    if (exact.isNotEmpty) return exact.first;

    final sameLanguage = voices
        .where(
          (voice) =>
              voice.locale.toLowerCase().replaceAll('_', '-').startsWith(
                    languageCode,
                  ),
        )
        .toList()
      ..sort((a, b) => b.naturalScore.compareTo(a.naturalScore));
    return sameLanguage.isNotEmpty ? sameLanguage.first : null;
  }

  Future<void> speak(
    String text, {
    required String language,
    required double rate,
    TtsBackend backend = TtsBackend.system,
    int neuralVoiceId = 0,
    int neuralSteps = 12,
    String? voiceName,
    String? voiceLocale,
    String? engine,
    TtsProgressCallback? onProgress,
  }) async {
    if (text.trim().isEmpty) return;

    if (backend == TtsBackend.neural &&
        neural.supportedPlatform &&
        neural.supportsLanguage(language) &&
        await neural.isInstalled()) {
      await _stopSystemOnly();
      await neural.speak(
        text,
        language: language,
        rate: rate,
        voiceId: neuralVoiceId,
        numSteps: neuralSteps,
      );
      return;
    }

    await neural.stop();
    await _speakSystem(
      text,
      language: language,
      rate: rate,
      voiceName: voiceName,
      voiceLocale: voiceLocale,
      engine: engine,
      onProgress: onProgress,
    );
  }

  Future<void> _speakSystem(
    String text, {
    required String language,
    required double rate,
    String? voiceName,
    String? voiceLocale,
    String? engine,
    TtsProgressCallback? onProgress,
  }) async {
    if (Platform.isLinux) {
      await _speakLinux(text, language: language, rate: rate);
      return;
    }

    await _configure();
    if (Platform.isAndroid) {
      if (engine != null) {
        await setEngine(engine);
      } else if (_activeEngine == null) {
        await selectBestAndroidEngine();
      }
    }

    final selectedLocale = voiceLocale ?? language;
    await _tts.setLanguage(selectedLocale);
    await _tts.setSpeechRate(rate.clamp(0.15, 0.85).toDouble());
    await _tts.setPitch(1.0);

    if (voiceName != null && voiceLocale != null) {
      await _tts.setVoice({'name': voiceName, 'locale': voiceLocale});
    } else {
      final available = await voices(engine: engine);
      final best = bestVoiceForLanguage(available, language);
      if (best != null) {
        await _tts.setVoice({'name': best.name, 'locale': best.locale});
      }
    }

    _systemProgress = onProgress;
    try {
      await _tts.speak(text);
    } finally {
      _systemProgress = null;
    }
  }

  Future<void> preview({
    required String language,
    required double rate,
    TtsBackend backend = TtsBackend.system,
    int neuralVoiceId = 0,
    int neuralSteps = 12,
    String? voiceName,
    String? voiceLocale,
    String? engine,
  }) =>
      speak(
        _previewText(language),
        language: language,
        rate: rate,
        backend: backend,
        neuralVoiceId: neuralVoiceId,
        neuralSteps: neuralSteps,
        voiceName: voiceName,
        voiceLocale: voiceLocale,
        engine: engine,
      );

  String _previewText(String language) {
    final code = language.toLowerCase().split(RegExp('[-_]')).first;
    switch (code) {
      case 'en':
        return 'Auralis is ready to read your book with a smoother, more natural voice.';
      case 'es':
        return 'Auralis está listo para leer tu libro con una voz más natural y agradable.';
      case 'fr':
        return 'Auralis est prêt à lire votre livre avec une voix plus naturelle et agréable.';
      case 'de':
        return 'Auralis ist bereit, dein Buch mit einer natürlicheren Stimme vorzulesen.';
      case 'it':
        return 'Auralis è pronto a leggere il tuo libro con una voce più naturale e piacevole.';
      default:
        return 'O Auralis está pronto para ler seu livro com uma voz mais natural, expressiva e agradável.';
    }
  }

  Future<void> _speakLinux(
    String text, {
    required String language,
    required double rate,
  }) async {
    await _stopSystemOnly();
    final locale = language.toLowerCase().replaceAll('_', '-');
    final speed =
        (80 + rate.clamp(0.15, 0.85).toDouble() * 260).round();

    if (await _commandExists('spd-say')) {
      final spdRate = (((rate - 0.5) * 180).clamp(-100, 100)).round();
      _linuxProcess = await Process.start(
        'spd-say',
        ['-w', '-l', locale, '-r', '$spdRate', text],
      );
    } else if (await _commandExists('espeak-ng')) {
      _linuxProcess = await Process.start(
        'espeak-ng',
        ['-s', '$speed', '-v', locale, text],
      );
    } else if (await _commandExists('espeak')) {
      _linuxProcess = await Process.start(
        'espeak',
        ['-s', '$speed', '-v', locale, text],
      );
    } else {
      throw StateError(
        'Instale speech-dispatcher ou espeak-ng para ativar a narração do sistema no Linux.',
      );
    }

    await _linuxProcess!.exitCode;
    _linuxProcess = null;
  }

  Future<bool> _commandExists(String command) async {
    final result = await Process.run(
      'sh',
      ['-c', 'command -v $command >/dev/null 2>&1'],
    );
    return result.exitCode == 0;
  }

  Future<void> _stopSystemOnly() async {
    _systemProgress = null;
    if (Platform.isLinux) {
      _linuxProcess?.kill(ProcessSignal.sigterm);
      _linuxProcess = null;
      return;
    }
    await _configure();
    await _tts.stop();
  }

  Future<void> stop() async {
    await neural.stop();
    await _stopSystemOnly();
  }

  Future<void> dispose() async {
    await stop();
    await neural.dispose();
  }
}
