import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/settings.dart';
import '../services/neural_tts_service.dart';
import '../services/tts_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<TtsVoice>? _voices;
  List<String> _engines = const [];
  String? _voiceError;
  bool _previewing = false;
  bool? _neuralInstalled;
  bool _downloadingNeural = false;
  double _neuralProgress = 0;
  String? _neuralStatus;

  @override
  void initState() {
    super.initState();
    _loadTtsOptions();
  }

  Future<void> _loadTtsOptions() async {
    try {
      final installed = await widget.controller.tts.neuralModelInstalled();
      var engine = widget.controller.settings.ttsEngine;
      if (Platform.isAndroid) {
        _engines = await widget.controller.tts.engines();
        engine ??= await widget.controller.tts.selectBestAndroidEngine();
        if (engine != null && widget.controller.settings.ttsEngine == null) {
          await widget.controller.updateSettings(
            widget.controller.settings.copyWith(ttsEngine: engine),
          );
        }
      }
      final voices = await widget.controller.tts.voices(engine: engine);
      if (mounted) {
        setState(() {
          _neuralInstalled = installed;
          _voices = voices;
          _voiceError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _voiceError = e.toString());
    }
  }

  Future<void> _save(AppSettings settings) =>
      widget.controller.updateSettings(settings);

  Future<void> _preview() async {
    final settings = widget.controller.settings;
    setState(() => _previewing = true);
    try {
      await widget.controller.tts.preview(
        language: settings.defaultLanguage,
        rate: settings.speechRate,
        backend: settings.ttsBackend,
        neuralVoiceId: settings.neuralVoiceId,
        neuralSteps: settings.neuralSteps,
        voiceName: settings.voiceName,
        voiceLocale: settings.voiceLocale,
        engine: settings.ttsEngine,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível testar a voz: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _downloadNeuralVoice() async {
    setState(() {
      _downloadingNeural = true;
      _neuralProgress = 0;
      _neuralStatus = 'Preparando download…';
    });
    try {
      await widget.controller.tts.downloadNeuralModel(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _neuralProgress = progress.value;
            _neuralStatus = progress.message;
          });
        },
      );
      if (!mounted) return;
      setState(() => _neuralInstalled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voz neural instalada e pronta para uso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao instalar a voz neural: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingNeural = false;
          _neuralStatus = null;
        });
      }
    }
  }

  Future<void> _deleteNeuralVoice() async {
    await widget.controller.tts.deleteNeuralModel();
    if (!mounted) return;
    setState(() => _neuralInstalled = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modelo neural removido do dispositivo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.settings;
    final neuralSelected = settings.ttsBackend == TtsBackend.neural;
    final selectedVoiceKey = settings.voiceName == null
        ? null
        : '${settings.voiceName}|${settings.voiceLocale}';
    final neuralAvailableForLanguage =
        widget.controller.tts.neural.supportsLanguage(settings.defaultLanguage);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Aparência', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Sistema'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Claro'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Escuro'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (value) =>
                _save(settings.copyWith(themeMode: value.first)),
          ),
          const SizedBox(height: 32),
          Text('Narração', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'O modo Neural usa o Supertonic 3 diretamente no aparelho. Depois do download inicial, o texto do livro não precisa ser enviado para um servidor de voz.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SegmentedButton<TtsBackend>(
            segments: const [
              ButtonSegment(
                value: TtsBackend.neural,
                label: Text('Neural'),
                icon: Icon(Icons.auto_awesome),
              ),
              ButtonSegment(
                value: TtsBackend.system,
                label: Text('Sistema'),
                icon: Icon(Icons.record_voice_over_outlined),
              ),
            ],
            selected: {settings.ttsBackend},
            onSelectionChanged: (value) =>
                _save(settings.copyWith(ttsBackend: value.first)),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: settings.defaultLanguage,
            decoration: const InputDecoration(labelText: 'Idioma padrão'),
            items: const [
              DropdownMenuItem(value: 'pt-BR', child: Text('Português (Brasil)')),
              DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
              DropdownMenuItem(value: 'es-ES', child: Text('Español')),
              DropdownMenuItem(value: 'fr-FR', child: Text('Français')),
              DropdownMenuItem(value: 'de-DE', child: Text('Deutsch')),
              DropdownMenuItem(value: 'it-IT', child: Text('Italiano')),
              DropdownMenuItem(value: 'ja-JP', child: Text('日本語')),
              DropdownMenuItem(value: 'ko-KR', child: Text('한국어')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              await _save(
                settings.copyWith(defaultLanguage: value, clearVoice: true),
              );
              await _loadTtsOptions();
            },
          ),
          const SizedBox(height: 20),
          if (neuralSelected)
            _buildNeuralSection(
              context,
              settings,
              neuralAvailableForLanguage,
            )
          else
            _buildSystemSection(context, settings, selectedVoiceKey),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: _previewing ||
                    (neuralSelected && _neuralInstalled != true) ||
                    (neuralSelected && !neuralAvailableForLanguage)
                ? null
                : _preview,
            icon: Icon(
              _previewing ? Icons.hourglass_top : Icons.volume_up_outlined,
            ),
            label: Text(_previewing ? 'Reproduzindo…' : 'Testar voz'),
          ),
          const SizedBox(height: 20),
          Text('Velocidade: ${_rateLabel(settings.speechRate)}'),
          Slider(
            value: settings.speechRate,
            min: .2,
            max: .8,
            divisions: 24,
            onChanged: (value) =>
                _save(settings.copyWith(speechRate: value)),
          ),
          const SizedBox(height: 12),
          Text('Tamanho do texto: ${(settings.fontScale * 100).round()}%'),
          Slider(
            value: settings.fontScale,
            min: .8,
            max: 1.6,
            divisions: 16,
            onChanged: (value) => _save(settings.copyWith(fontScale: value)),
          ),
          const SizedBox(height: 32),
          const Text(
            'Privacidade: a biblioteca e o progresso ficam no dispositivo. No modo Neural, a internet é usada apenas para baixar o modelo de voz; a síntese é feita localmente.',
          ),
        ],
      ),
    );
  }

  Widget _buildNeuralSection(
    BuildContext context,
    AppSettings settings,
    bool languageSupported,
  ) {
    if (!widget.controller.tts.neural.supportedPlatform) {
      return Text(
        'A voz neural ainda não está disponível nesta plataforma.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    if (!languageSupported) {
      return Text(
        'O Supertonic 3 não oferece o idioma selecionado. Escolha o modo Sistema para este idioma.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    if (_neuralInstalled == null) return const LinearProgressIndicator();

    if (_neuralInstalled != true) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Supertonic 3 — voz neural local',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '10 vozes e suporte a português. O download tem cerca de 123 MB e é feito uma única vez.',
              ),
              if (_downloadingNeural) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(value: _neuralProgress),
                const SizedBox(height: 8),
                Text(_neuralStatus ?? 'Instalando…'),
              ] else ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _downloadNeuralVoice,
                  icon: const Icon(Icons.download),
                  label: const Text('Baixar voz neural (~123 MB)'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          value: settings.neuralVoiceId.clamp(0, 9).toInt(),
          decoration: const InputDecoration(labelText: 'Voz neural'),
          items: NeuralTtsService.voices
              .map(
                (voice) => DropdownMenuItem<int>(
                  value: voice.id,
                  child: Text(voice.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              _save(settings.copyWith(neuralVoiceId: value));
            }
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: settings.neuralSteps,
          decoration: const InputDecoration(labelText: 'Síntese neural'),
          items: const [
            DropdownMenuItem(value: 6, child: Text('Rápida — 6 etapas')),
            DropdownMenuItem(value: 8, child: Text('Equilibrada — 8 etapas')),
            DropdownMenuItem(value: 12, child: Text('Detalhada — 12 etapas')),
          ],
          onChanged: (value) {
            if (value != null) _save(settings.copyWith(neuralSteps: value));
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text('Modelo instalado • funciona offline'),
            ),
            TextButton.icon(
              onPressed: _deleteNeuralVoice,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remover'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemSection(
    BuildContext context,
    AppSettings settings,
    String? selectedVoiceKey,
  ) {
    return Column(
      children: [
        Text(
          'Usa o mecanismo TTS instalado no sistema. A qualidade depende das vozes disponíveis no aparelho.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (Platform.isAndroid && _engines.isNotEmpty) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _engines.contains(settings.ttsEngine)
                ? settings.ttsEngine
                : null,
            decoration: const InputDecoration(labelText: 'Mecanismo de voz'),
            items: _engines
                .map(
                  (engine) => DropdownMenuItem(
                    value: engine,
                    child: Text(_engineLabel(engine)),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              await widget.controller.tts.setEngine(value);
              await _save(
                settings.copyWith(ttsEngine: value, clearVoice: true),
              );
              setState(() => _voices = null);
              await _loadTtsOptions();
            },
          ),
        ],
        const SizedBox(height: 16),
        if (_voiceError != null)
          Text(
            _voiceError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (_voices == null)
          const LinearProgressIndicator()
        else
          DropdownButtonFormField<String?>(
            value: selectedVoiceKey,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Voz do sistema'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Automática — melhor disponível'),
              ),
              ..._voices!
                  .where(
                    (voice) =>
                        _sameLanguage(voice.locale, settings.defaultLanguage),
                  )
                  .map(
                    (voice) => DropdownMenuItem<String?>(
                      value: '${voice.name}|${voice.locale}',
                      child: Text(
                        voice.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
            ],
            onChanged: (value) {
              if (value == null) {
                _save(settings.copyWith(clearVoice: true));
              } else {
                final voice = _voices!.firstWhere(
                  (v) => '${v.name}|${v.locale}' == value,
                );
                _save(
                  settings.copyWith(
                    voiceName: voice.name,
                    voiceLocale: voice.locale,
                  ),
                );
              }
            },
          ),
      ],
    );
  }

  static String _rateLabel(double rate) =>
      '${(rate / .5).toStringAsFixed(2)}×';

  static bool _sameLanguage(String voiceLocale, String language) {
    if (voiceLocale == 'system') return true;
    final a = voiceLocale.toLowerCase().replaceAll('_', '-').split('-').first;
    final b = language.toLowerCase().replaceAll('_', '-').split('-').first;
    return a == b;
  }

  static String _engineLabel(String engine) {
    switch (engine) {
      case 'com.google.android.tts':
        return 'Google Speech Services (recomendado)';
      case 'com.samsung.SMT':
        return 'Samsung TTS';
      case 'com.microsoft.tts':
        return 'Microsoft TTS';
      default:
        return engine;
    }
  }
}
