import 'package:flutter/material.dart';

enum TtsBackend { neural, system }
enum TranslationProvider { auto, literaryAi, quick }

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
    this.voiceModeVersion = 3,
    this.autoCovers = true,
    this.translationProvider = TranslationProvider.auto,
    this.translationTarget = 'pt',
    this.translationProfile = 'faithful',
    this.aiEndpoint = '',
    this.aiModel = 'qwen2.5:7b',
    this.aiApiKey = '',
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
  final bool autoCovers;
  final TranslationProvider translationProvider;
  final String translationTarget;
  final String translationProfile;
  final String aiEndpoint;
  final String aiModel;
  final String aiApiKey;

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
    bool? autoCovers,
    TranslationProvider? translationProvider,
    String? translationTarget,
    String? translationProfile,
    String? aiEndpoint,
    String? aiModel,
    String? aiApiKey,
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
        autoCovers: autoCovers ?? this.autoCovers,
        translationProvider: translationProvider ?? this.translationProvider,
        translationTarget: translationTarget ?? this.translationTarget,
        translationProfile: translationProfile ?? this.translationProfile,
        aiEndpoint: aiEndpoint ?? this.aiEndpoint,
        aiModel: aiModel ?? this.aiModel,
        aiApiKey: aiApiKey ?? this.aiApiKey,
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
        'autoCovers': autoCovers,
        'translationProvider': translationProvider.name,
        'translationTarget': translationTarget,
        'translationProfile': translationProfile,
        'aiEndpoint': aiEndpoint,
        'aiModel': aiModel,
        'aiApiKey': aiApiKey,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    TtsBackend backend = TtsBackend.system;
    final backendName = json['ttsBackend'] as String?;
    if (backendName != null) {
      backend = TtsBackend.values.where((e) => e.name == backendName).firstOrNull ?? backend;
    }

    TranslationProvider provider = TranslationProvider.auto;
    final providerName = json['translationProvider'] as String?;
    if (providerName != null) {
      provider = TranslationProvider.values.where((e) => e.name == providerName).firstOrNull ?? provider;
    }

    return AppSettings(
      themeMode: ThemeMode.values.where(
            (e) => e.name == (json['themeMode'] as String? ?? 'system'),
          ).firstOrNull ??
          ThemeMode.system,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.46,
      defaultLanguage: json['defaultLanguage'] as String? ?? 'pt-BR',
      ttsBackend: backend,
      neuralVoiceId: (json['neuralVoiceId'] as num?)?.toInt() ?? 0,
      neuralSteps: (json['neuralSteps'] as num?)?.toInt() ?? 12,
      voiceName: json['voiceName'] as String?,
      voiceLocale: json['voiceLocale'] as String?,
      ttsEngine: json['ttsEngine'] as String?,
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      voiceModeVersion: (json['voiceModeVersion'] as num?)?.toInt() ?? 0,
      autoCovers: json['autoCovers'] as bool? ?? true,
      translationProvider: provider,
      translationTarget: json['translationTarget'] as String? ?? 'pt',
      translationProfile: json['translationProfile'] as String? ?? 'faithful',
      aiEndpoint: json['aiEndpoint'] as String? ?? '',
      aiModel: json['aiModel'] as String? ?? 'qwen2.5:7b',
      aiApiKey: json['aiApiKey'] as String? ?? '',
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
