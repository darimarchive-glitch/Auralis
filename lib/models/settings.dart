import 'package:flutter/material.dart';

enum TtsBackend { neural, system }

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.speechRate = 0.46,
    this.defaultLanguage = 'pt-BR',
    this.ttsBackend = TtsBackend.system,
    this.neuralVoiceId = 0,
    this.neuralSteps = 12,
    this.voiceName,
    this.voiceLocale,
    this.ttsEngine,
    this.fontScale = 1.0,
    this.voiceModeVersion = 2,
  });

  final ThemeMode themeMode;
  final double speechRate;
  final String defaultLanguage;
  final TtsBackend ttsBackend;
  final int neuralVoiceId;
  final int neuralSteps;
  final String? voiceName;
  final String? voiceLocale;
  final String? ttsEngine;
  final double fontScale;
  final int voiceModeVersion;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? speechRate,
    String? defaultLanguage,
    TtsBackend? ttsBackend,
    int? neuralVoiceId,
    int? neuralSteps,
    String? voiceName,
    String? voiceLocale,
    String? ttsEngine,
    bool clearVoice = false,
    double? fontScale,
    int? voiceModeVersion,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        speechRate: speechRate ?? this.speechRate,
        defaultLanguage: defaultLanguage ?? this.defaultLanguage,
        ttsBackend: ttsBackend ?? this.ttsBackend,
        neuralVoiceId: neuralVoiceId ?? this.neuralVoiceId,
        neuralSteps: neuralSteps ?? this.neuralSteps,
        voiceName: clearVoice ? null : voiceName ?? this.voiceName,
        voiceLocale: clearVoice ? null : voiceLocale ?? this.voiceLocale,
        ttsEngine: ttsEngine ?? this.ttsEngine,
        fontScale: fontScale ?? this.fontScale,
        voiceModeVersion: voiceModeVersion ?? this.voiceModeVersion,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'speechRate': speechRate,
        'defaultLanguage': defaultLanguage,
        'ttsBackend': ttsBackend.name,
        'neuralVoiceId': neuralVoiceId,
        'neuralSteps': neuralSteps,
        'voiceName': voiceName,
        'voiceLocale': voiceLocale,
        'ttsEngine': ttsEngine,
        'fontScale': fontScale,
        'voiceModeVersion': voiceModeVersion,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final backendName =
        json['ttsBackend'] as String? ?? TtsBackend.system.name;
    var backend = TtsBackend.system;
    for (final item in TtsBackend.values) {
      if (item.name == backendName) {
        backend = item;
        break;
      }
    }

    return AppSettings(
      themeMode: ThemeMode.values.byName(
        json['themeMode'] as String? ?? ThemeMode.system.name,
      ),
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.46,
      defaultLanguage: json['defaultLanguage'] as String? ?? 'pt-BR',
      ttsBackend: backend,
      neuralVoiceId: (json['neuralVoiceId'] as num?)?.toInt() ?? 0,
      neuralSteps: (json['neuralSteps'] as num?)?.toInt() ?? 12,
      voiceName: json['voiceName'] as String?,
      voiceLocale: json['voiceLocale'] as String?,
      ttsEngine: json['ttsEngine'] as String?,
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      voiceModeVersion:
          (json['voiceModeVersion'] as num?)?.toInt() ?? 0,
    );
  }
}
