import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/reader_controller.dart';
import '../models/book.dart';
import '../models/settings.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.app,
    required this.book,
  });

  final AppController app;
  final BookMetadata book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final ReaderController controller;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _chunkKeys = <int, GlobalKey>{};
  int _lastChunkIndex = -1;

  @override
  void initState() {
    super.initState();
    controller = ReaderController(widget.app, widget.book);
    controller.addListener(_syncReadingPosition);
    controller.init();
  }

  void _syncReadingPosition() {
    if (controller.loading || controller.chunks.isEmpty) return;
    if (_lastChunkIndex == controller.chunkIndex) return;
    _lastChunkIndex = controller.chunkIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bringCurrentIntoView();
    });
  }

  Future<void> _bringCurrentIntoView() async {
    final key = _chunkKeys[controller.chunkIndex];
    final itemContext = key?.currentContext;
    if (itemContext != null) {
      await Scrollable.ensureVisible(
        itemContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: .42,
      );
      return;
    }

    if (!_scrollController.hasClients || controller.chunks.length <= 1) {
      return;
    }

    final ratio =
        controller.chunkIndex / (controller.chunks.length - 1);
    final estimate =
        _scrollController.position.maxScrollExtent * ratio;
    await _scrollController.animateTo(
      estimate.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _chunkKeys[controller.chunkIndex]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: .42,
        );
      }
    });
  }

  @override
  void dispose() {
    controller.removeListener(_syncReadingPosition);
    controller.dispose();
    _scrollController.dispose();
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
            leading: CircleAvatar(
              radius: 16,
              child: Text('${index + 1}'),
            ),
            title: Text(controller.content!.chapters[index].title),
            onTap: () => Navigator.pop(context, index),
          ),
        ),
      ),
    );

    if (selected != null) {
      _chunkKeys.clear();
      await controller.selectChapter(selected);
    }
  }

  TextSpan _spokenTextSpan(
    BuildContext context,
    String text, {
    required bool active,
    required TextStyle baseStyle,
  }) {
    final scheme = Theme.of(context).colorScheme;

    if (!active || !controller.wordTrackingActive) {
      return TextSpan(
        text: text,
        style: baseStyle.copyWith(
          color: active
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      );
    }

    final start = controller.spokenStart.clamp(0, text.length);
    final end = controller.spokenEnd.clamp(start, text.length);

    return TextSpan(
      style: baseStyle,
      children: [
        TextSpan(
          text: text.substring(0, start),
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: .68),
          ),
        ),
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            color: scheme.onPrimary,
            backgroundColor: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(
          text: text.substring(end),
          style: TextStyle(color: scheme.onSurface),
        ),
      ],
    );
  }

  Widget _focusCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNatural =
        widget.app.settings.ttsBackend == TtsBackend.system;
    final baseStyle =
        Theme.of(context).textTheme.titleLarge?.copyWith(
              height: 1.5,
              fontSize: 21 * widget.app.settings.fontScale,
              letterSpacing: .05,
            ) ??
            const TextStyle(fontSize: 21, height: 1.5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: controller.playing
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: controller.playing
              ? scheme.primary.withValues(alpha: .38)
              : scheme.outlineVariant,
        ),
        boxShadow: controller.playing
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: controller.playing
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                ),
                child: Icon(
                  controller.playing
                      ? Icons.graphic_eq_rounded
                      : Icons.menu_book_rounded,
                  color: controller.playing
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.playing
                          ? 'OUVINDO AGORA'
                          : 'TRECHO ATUAL',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isNatural
                          ? 'Voz natural • acompanhamento palavra a palavra'
                          : 'Voz offline • acompanhamento por frase',
                      style:
                          Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${controller.chunkIndex + 1}/${controller.chunks.length}',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: Text.rich(
              _spokenTextSpan(
                context,
                controller.currentChunk,
                active: true,
                baseStyle: baseStyle,
              ),
              key: ValueKey(controller.chunkIndex),
            ),
          ),
          if (controller.wordTrackingActive &&
              controller.spokenWord.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.hearing_rounded,
                  size: 17,
                  color: scheme.primary,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    controller.spokenWord,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (controller.content == null || controller.chapter == null) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.book.title)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  controller.error ??
                      'Não foi possível abrir este livro.',
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 4,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  controller.chapter!.title,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Capítulos',
                onPressed: () => _chooseChapter(context),
                icon: const Icon(Icons.toc_rounded),
              ),
            ],
          ),
          body: Column(
            children: [
              LinearProgressIndicator(
                value: controller.chapterProgress,
                minHeight: 3,
              ),
              if (controller.error != null)
                Container(
                  width: double.infinity,
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded),
                      const SizedBox(width: 10),
                      Expanded(child: Text(controller.error!)),
                    ],
                  ),
                ),
              _focusCard(context),
              Expanded(
                child: SelectionArea(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.fromLTRB(18, 6, 18, 150),
                    itemCount: controller.chunks.length,
                    itemBuilder: (context, index) {
                      final active =
                          index == controller.chunkIndex;
                      final key = _chunkKeys.putIfAbsent(
                        index,
                        GlobalKey.new,
                      );
                      final baseStyle = Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                height: 1.72,
                                fontSize: 18 *
                                    widget.app.settings.fontScale,
                              ) ??
                          const TextStyle(
                            fontSize: 18,
                            height: 1.72,
                          );

                      return Center(
                        key: key,
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 760),
                          child: AnimatedOpacity(
                            duration:
                                const Duration(milliseconds: 180),
                            opacity: controller.playing && !active
                                ? .54
                                : 1,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(14),
                                onTap: () =>
                                    controller.selectChunk(index),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                        : Colors.transparent,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: active
                                        ? Border(
                                            left: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              width: 3,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Text.rich(
                                    _spokenTextSpan(
                                      context,
                                      controller.chunks[index],
                                      active: active,
                                      baseStyle: baseStyle,
                                    ),
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
          bottomNavigationBar:
              _PlayerBar(controller: controller),
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
    final scheme = Theme.of(context).colorScheme;
    final max = controller.chunks.isEmpty
        ? 1.0
        : (controller.chunks.length - 1)
            .toDouble()
            .clamp(1.0, double.infinity)
            .toDouble();
    final current =
        controller.chunkIndex.toDouble().clamp(0.0, max).toDouble();

    return Material(
      elevation: 18,
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0,
                max: max,
                value: current,
                onChanged: controller.chunks.length <= 1
                    ? null
                    : (value) =>
                        controller.selectChunk(value.round()),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.chapter?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  Text(
                    '${(controller.chapterProgress * 100).round()}%',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Frase anterior',
                    onPressed: () => controller.skip(-1),
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: controller.togglePlay,
                      child: Icon(
                        controller.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  IconButton.filledTonal(
                    tooltip: 'Próxima frase',
                    onPressed: () => controller.skip(1),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
