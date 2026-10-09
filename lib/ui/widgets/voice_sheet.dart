import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../models/settings.dart';
import '../../services/neural_tts_service.dart';
import '../../services/tts_service.dart';

Future<void> showVoiceSheet(BuildContext context, AppController app) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _VoiceSheet(app: app),
  );
}

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet({required this.app});
  final AppController app;

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  List<TtsVoice>? voices;
  List<String> engines = const [];
  bool? neuralInstalled;
  bool downloading = false;
  double downloadProgress = 0;
  String? error;

  AppSettings get settings => widget.app.settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      engines = await widget.app.tts.engines();
      voices = await widget.app.tts.voices(engine: settings.ttsEngine);
      neuralInstalled = await widget.app.tts.neuralModelInstalled();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> _save(AppSettings value) async {
    await widget.app.updateSettings(value);
    if (mounted) setState(() {});
  }

  Future<void> _preview({TtsVoice? voice, int? neuralId}) async {
    try {
      await widget.app.tts.preview(
        language: settings.defaultLanguage,
        rate: settings.speechRate,
        backend: neuralId == null ? TtsBackend.system : TtsBackend.neural,
        neuralVoiceId: neuralId ?? settings.neuralVoiceId,
        neuralSteps: settings.neuralSteps,
        voiceName: voice?.name ?? settings.voiceName,
        voiceLocale: voice?.locale ?? settings.voiceLocale,
        engine: settings.ttsEngine,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _installNeural() async {
    setState(() {
      downloading = true;
      downloadProgress = 0;
      error = null;
    });
    try {
      await widget.app.tts.downloadNeuralModel(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => downloadProgress = progress.value);
        },
      );
      neuralInstalled = true;
    } catch (e) {
      error = e.toString();
    } finally {
      downloading = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = (voices ?? const <TtsVoice>[])
        .where((voice) => _sameLanguage(voice.locale, settings.defaultLanguage))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .82,
      minChildSize: .48,
      maxChildSize: .94,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Voz da narração', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Escolha uma voz e ouça antes de usar.', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 18),
          SegmentedButton<TtsBackend>(
            segments: const [
              ButtonSegment(value: TtsBackend.system, icon: Icon(Icons.record_voice_over_rounded), label: Text('Natural')),
              ButtonSegment(value: TtsBackend.neural, icon: Icon(Icons.auto_awesome_rounded), label: Text('Offline neural')),
            ],
            selected: {settings.ttsBackend},
            onSelectionChanged: (value) => _save(settings.copyWith(ttsBackend: value.first)),
          ),
          const SizedBox(height: 18),
          Text('Velocidade', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: settings.speechRate.clamp(.2, .85),
                  min: .2,
                  max: .85,
                  divisions: 26,
                  onChanged: (value) => _save(settings.copyWith(speechRate: value)),
                ),
              ),
              SizedBox(width: 60, child: Text('${(settings.speechRate / .46).toStringAsFixed(2)}×', textAlign: TextAlign.end)),
            ],
          ),
          if (settings.ttsBackend == TtsBackend.system) ...[
            if (engines.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: engines.contains(settings.ttsEngine) ? settings.ttsEngine : null,
                decoration: const InputDecoration(labelText: 'Mecanismo de voz'),
                items: engines.map((engine) => DropdownMenuItem(value: engine, child: Text(_engineLabel(engine), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (engine) async {
                  if (engine == null) return;
                  await widget.app.tts.setEngine(engine);
                  await _save(settings.copyWith(ttsEngine: engine, clearVoice: true));
                  setState(() => voices = null);
                  await _load();
                },
              ),
            ],
            const SizedBox(height: 18),
            Text('Vozes disponíveis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (voices == null)
              const LinearProgressIndicator()
            else if (filtered.isEmpty)
              const Text('Nenhuma voz compatível encontrada para este idioma.')
            else
              ...filtered.take(24).map((voice) {
                final selected = voice.name == settings.voiceName && voice.locale == settings.voiceLocale;
                return Card(
                  child: ListTile(
                    selected: selected,
                    leading: CircleAvatar(
                      child: Icon(voice.isEnhanced ? Icons.auto_awesome_rounded : Icons.graphic_eq_rounded),
                    ),
                    title: Text(voice.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${voice.locale}${voice.isEnhanced ? ' • alta qualidade' : ''}${voice.networkRequired ? ' • online' : ''}'),
                    trailing: IconButton(
                      tooltip: 'Ouvir amostra',
                      onPressed: () => _preview(voice: voice),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                    ),
                    onTap: () async {
                      await _save(settings.copyWith(voiceName: voice.name, voiceLocale: voice.locale, ttsBackend: TtsBackend.system));
                      await _preview(voice: voice);
                    },
                  ),
                );
              }),
          ] else ...[
            if (neuralInstalled == null)
              const LinearProgressIndicator()
            else if (neuralInstalled != true) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Supertonic 3', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 7),
                      const Text('Voz neural local. O modelo é baixado uma vez e depois funciona sem tokens nem API.'),
                      const SizedBox(height: 14),
                      if (downloading) ...[
                        LinearProgressIndicator(value: downloadProgress),
                        const SizedBox(height: 8),
                        Text('${(downloadProgress * 100).round()}%'),
                      ] else
                        FilledButton.icon(
                          onPressed: _installNeural,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Baixar voz neural'),
                        ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text('Vozes neurais', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...NeuralTtsService.voices.map((voice) {
                final selected = voice.id == settings.neuralVoiceId;
                return Card(
                  child: ListTile(
                    selected: selected,
                    leading: CircleAvatar(child: Text(voice.name)),
                    title: Text(voice.label),
                    trailing: IconButton(
                      tooltip: 'Ouvir amostra',
                      onPressed: () => _preview(neuralId: voice.id),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                    ),
                    onTap: () async {
                      await _save(settings.copyWith(ttsBackend: TtsBackend.neural, neuralVoiceId: voice.id));
                      await _preview(neuralId: voice.id);
                    },
                  ),
                );
              }),
            ],
          ],
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }

  static bool _sameLanguage(String voiceLocale, String language) {
    if (voiceLocale == 'system') return true;
    final a = voiceLocale.toLowerCase().replaceAll('_', '-').split('-').first;
    final b = language.toLowerCase().replaceAll('_', '-').split('-').first;
    return a == b;
  }

  static String _engineLabel(String engine) => switch (engine) {
        'com.google.android.tts' => 'Google Speech Services',
        'com.samsung.SMT' => 'Samsung TTS',
        'com.microsoft.tts' => 'Microsoft TTS',
        _ => engine,
      };
}
