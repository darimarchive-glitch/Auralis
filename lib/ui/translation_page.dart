import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/book.dart';
import '../models/settings.dart';

class TranslationPage extends StatefulWidget {
  const TranslationPage({super.key, required this.app, required this.book});
  final AppController app;
  final BookMetadata book;

  @override
  State<TranslationPage> createState() => _TranslationPageState();
}

class _TranslationPageState extends State<TranslationPage> {
  late String target;
  late String profile;
  late bool literaryAi;
  late final TextEditingController endpoint;
  late final TextEditingController model;
  late final TextEditingController apiKey;
  String? preview;
  String? error;

  static const languages = <String, String>{
    'pt': 'Português',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
    'ru': 'Русский',
    'ar': 'العربية',
  };

  static const profiles = <String, String>{
    'faithful': 'Fiel à obra',
    'modern': 'Português moderno',
    'literal': 'Literal',
    'study': 'Estudo / clareza',
  };

  @override
  void initState() {
    super.initState();
    final settings = widget.app.settings;
    target = languages.containsKey(settings.translationTarget) ? settings.translationTarget : 'pt';
    profile = profiles.containsKey(settings.translationProfile) ? settings.translationProfile : 'faithful';
    literaryAi = settings.translationProvider == TranslationProvider.literaryAi;
    endpoint = TextEditingController(text: settings.aiEndpoint);
    model = TextEditingController(text: settings.aiModel);
    apiKey = TextEditingController(text: settings.aiApiKey);
    _loadPreview();
  }

  @override
  void dispose() {
    endpoint.dispose();
    model.dispose();
    apiKey.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final content = await widget.app.repository.loadContent(widget.book);
    if (!mounted || content.chapters.isEmpty) return;
    setState(() {
      preview = content.chapters.first.text.length > 1000
          ? '${content.chapters.first.text.substring(0, 1000)}…'
          : content.chapters.first.text;
    });
  }

  Future<void> _saveSettings() => widget.app.updateSettings(
        widget.app.settings.copyWith(
          translationTarget: target,
          translationProfile: profile,
          translationProvider: literaryAi ? TranslationProvider.literaryAi : TranslationProvider.auto,
          aiEndpoint: endpoint.text.trim(),
          aiModel: model.text.trim(),
          aiApiKey: apiKey.text.trim(),
        ),
      );

  Future<void> _translate() async {
    setState(() => error = null);
    await _saveSettings();
    if (literaryAi && endpoint.text.trim().isEmpty) {
      setState(() {
        error = 'Para IA literária, informe um endpoint OpenAI-compatible. Pode ser um servidor local como Ollama ou um provedor seu. Nenhuma chave fica no GitHub.';
      });
      return;
    }
    try {
      final updated = await widget.app.translateBook(
        widget.app.bookById(widget.book.id) ?? widget.book,
        targetLanguage: target,
        profile: profile,
        literaryAi: literaryAi,
      );
      final translated = await widget.app.repository.loadTranslation(updated, target);
      if (!mounted) return;
      setState(() {
        preview = translated?.chapters.firstOrNull?.text ?? 'Tradução concluída.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Livro traduzido e salvo no Auralis.')),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Traduzir livro')),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
              children: [
                Text(widget.book.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (widget.book.author != null) ...[
                  const SizedBox(height: 4),
                  Text(widget.book.author!, style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Idioma e estilo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: target,
                          decoration: const InputDecoration(labelText: 'Traduzir para'),
                          items: languages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                          onChanged: (value) => setState(() => target = value ?? target),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: profile,
                          decoration: const InputDecoration(labelText: 'Perfil literário'),
                          items: profiles.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                          onChanged: (value) => setState(() => profile = value ?? profile),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('IA literária', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  const Text('Usa um modelo configurado por você para preservar tom, época e diálogos.'),
                                ],
                              ),
                            ),
                            Switch(value: literaryAi, onChanged: (value) => setState(() => literaryAi = value)),
                          ],
                        ),
                        if (literaryAi) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: endpoint,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Endpoint OpenAI-compatible',
                              hintText: 'http://192.168.1.10:11434/v1/chat/completions',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: model,
                            decoration: const InputDecoration(labelText: 'Modelo', hintText: 'qwen2.5:7b'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: apiKey,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'API key (opcional)',
                              helperText: 'Fica somente nas configurações locais deste aparelho.',
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          const Text('Modo automático: usa IA quando configurada; caso contrário, usa tradução rápida online como fallback.'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: widget.app.busy ? null : _translate,
                  icon: const Icon(Icons.translate_rounded),
                  label: const Text('Traduzir livro completo'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 22),
                Text('Prévia', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: SelectableText(preview ?? 'Carregando trecho…', style: const TextStyle(height: 1.55)),
                  ),
                ),
              ],
            ),
            if (widget.app.busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: .55),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            widget.app.taskProgress == null
                                ? const CircularProgressIndicator()
                                : CircularProgressIndicator(value: widget.app.taskProgress),
                            const SizedBox(height: 14),
                            SizedBox(width: 280, child: Text(widget.app.status ?? 'Traduzindo…', textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
