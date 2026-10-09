import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/reader_controller.dart';
import '../models/book.dart';
import 'widgets/voice_sheet.dart';

class AudiobookPage extends StatefulWidget {
  const AudiobookPage({super.key, required this.app, required this.book});
  final AppController app;
  final BookMetadata book;

  @override
  State<AudiobookPage> createState() => _AudiobookPageState();
}

class _AudiobookPageState extends State<AudiobookPage> {
  late final ReaderController controller;
  Timer? sleepTimer;
  int? sleepMinutes;

  @override
  void initState() {
    super.initState();
    controller = ReaderController(widget.app, widget.book);
    controller.init();
  }

  @override
  void dispose() {
    sleepTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _setSleep(int? minutes) {
    sleepTimer?.cancel();
    if (minutes == null) {
      setState(() => sleepMinutes = null);
      return;
    }
    sleepTimer = Timer(Duration(minutes: minutes), () {
      controller.pause();
      if (mounted) setState(() => sleepMinutes = null);
    });
    setState(() => sleepMinutes = minutes);
  }

  Future<void> _chooseSleep() async {
    final value = await showModalBottomSheet<int?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Temporizador', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final minutes in [15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('$minutes minutos'),
                onTap: () => Navigator.pop(context, minutes),
              ),
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text('Desligado'),
              onTap: () => Navigator.pop(context, -1),
            ),
          ],
        ),
      ),
    );
    if (value == null) return;
    _setSleep(value < 0 ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final cover = controller.book.coverPath == null ? null : File(controller.book.coverPath!);
        final hasCover = cover != null && cover.existsSync();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Audiobook'),
            actions: [
              IconButton(
                tooltip: 'Temporizador',
                onPressed: _chooseSleep,
                icon: Icon(sleepMinutes == null ? Icons.timer_outlined : Icons.timer_rounded),
              ),
              IconButton(
                tooltip: 'Voz',
                onPressed: () => showVoiceSheet(context, widget.app),
                icon: const Icon(Icons.record_voice_over_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: .7,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 430),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: hasCover
                                ? Image.file(cover, fit: BoxFit.cover)
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Theme.of(context).colorScheme.primaryContainer,
                                          Theme.of(context).colorScheme.secondaryContainer,
                                        ],
                                      ),
                                    ),
                                    child: const Center(child: Icon(Icons.headphones_rounded, size: 100)),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        controller.book.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (controller.book.author != null) ...[
                        const SizedBox(height: 6),
                        Text(controller.book.author!, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        controller.chapter?.title ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(value: controller.chapterProgress, minHeight: 5),
                      const SizedBox(height: 10),
                      Text(
                        controller.currentChunk,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Trecho anterior',
                            onPressed: () => controller.skip(-1),
                            icon: const Icon(Icons.replay_10_rounded),
                          ),
                          const SizedBox(width: 22),
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: FilledButton(
                              style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                              onPressed: controller.togglePlay,
                              child: Icon(controller.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40),
                            ),
                          ),
                          const SizedBox(width: 22),
                          IconButton.filledTonal(
                            tooltip: 'Próximo trecho',
                            onPressed: () => controller.skip(1),
                            icon: const Icon(Icons.forward_10_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.record_voice_over_rounded, size: 18),
                            label: Text('Voz • ${(widget.app.settings.speechRate / .46).toStringAsFixed(2)}×'),
                            onPressed: () => showVoiceSheet(context, widget.app),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.timer_outlined, size: 18),
                            label: Text(sleepMinutes == null ? 'Timer' : '$sleepMinutes min'),
                            onPressed: _chooseSleep,
                          ),
                          if (controller.translationAvailable)
                            FilterChip(
                              avatar: const Icon(Icons.translate_rounded, size: 18),
                              label: Text(controller.useTranslation ? 'Traduzido' : 'Original'),
                              selected: controller.useTranslation,
                              onSelected: controller.setUseTranslation,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
