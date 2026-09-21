import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/reader_controller.dart';
import '../models/book.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.app, required this.book});
  final AppController app;
  final BookMetadata book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final ReaderController controller;

  @override
  void initState() {
    super.initState();
    controller = ReaderController(widget.app, widget.book)..init();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _chooseChapter(BuildContext context) async {
    if (controller.content == null) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: controller.content!.chapters.length,
          itemBuilder: (context, index) => ListTile(
            selected: index == controller.chapterIndex,
            leading: Text('${index + 1}'),
            title: Text(controller.content!.chapters[index].title),
            onTap: () => Navigator.pop(context, index),
          ),
        ),
      ),
    );
    if (selected != null) await controller.selectChapter(selected);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (controller.content == null || controller.chapter == null) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.book.title)),
            body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(controller.error ?? 'Não foi possível abrir este livro.'))),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  controller.chapter!.title,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              IconButton(tooltip: 'Capítulos', onPressed: () => _chooseChapter(context), icon: const Icon(Icons.toc)),
            ],
          ),
          body: Column(
            children: [
              if (controller.error != null)
                MaterialBanner(
                  content: Text(controller.error!),
                  actions: [TextButton(onPressed: () {}, child: const Text('Fechar'))],
                ),
              Expanded(
                child: SelectionArea(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
                    itemCount: controller.chunks.length,
                    itemBuilder: (context, index) {
                      final active = index == controller.chunkIndex;
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => controller.selectChunk(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: active ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  controller.chunks[index],
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        height: 1.65,
                                        fontSize: 18 * widget.app.settings.fontScale,
                                        color: active ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _PlayerBar(controller: controller),
        );
      },
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.controller});
  final ReaderController controller;

  @override
  Widget build(BuildContext context) {
    final max = controller.chunks.isEmpty ? 1.0 : (controller.chunks.length - 1).toDouble().clamp(1.0, double.infinity).toDouble();
    final current = controller.chunkIndex.toDouble().clamp(0.0, max).toDouble();
    return Material(
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0,
                max: max,
                value: current,
                onChanged: controller.chunks.length <= 1 ? null : (value) => controller.selectChunk(value.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(tooltip: 'Voltar', onPressed: () => controller.skip(-3), icon: const Icon(Icons.replay_10)),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: controller.togglePlay,
                    icon: Icon(controller.playing ? Icons.pause : Icons.play_arrow),
                    label: Text(controller.playing ? 'Pausar' : 'Ouvir'),
                  ),
                  const SizedBox(width: 10),
                  IconButton(tooltip: 'Avançar', onPressed: () => controller.skip(3), icon: const Icon(Icons.forward_10)),
                  const SizedBox(width: 16),
                  Text('${controller.chunkIndex + 1}/${controller.chunks.length}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
