import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/reader_controller.dart';
import '../models/book.dart';
import 'audiobook_page.dart';
import 'translation_page.dart';
import 'widgets/voice_sheet.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.app, required this.book});
  final AppController app;
  final BookMetadata book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final ReaderController controller;
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};
  int _lastChunk = -1;

  @override
  void initState() {
    super.initState();
    controller = ReaderController(widget.app, widget.book);
    controller.addListener(_onReaderChanged);
    controller.init();
  }

  @override
  void dispose() {
    controller.removeListener(_onReaderChanged);
    controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onReaderChanged() {
    if (controller.loading || controller.chunks.isEmpty) return;
    if (_lastChunk == controller.chunkIndex) return;
    _lastChunk = controller.chunkIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _keys[controller.chunkIndex]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: .34,
        );
      }
    });
  }

  Future<void> _chooseBook() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .4,
        maxChildSize: .92,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          itemCount: widget.app.books.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                child: Text('Trocar de livro', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              );
            }
            final book = widget.app.books[index - 1];
            return ListTile(
              selected: book.id == controller.book.id,
              leading: CircleAvatar(child: Text('$index')),
              title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(book.author ?? book.format.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: book.hasTranslation ? const Icon(Icons.translate_rounded) : null,
              onTap: () => Navigator.pop(context, book.id),
            );
          },
        ),
      ),
    );
    if (!mounted || chosen == null || chosen == controller.book.id) return;
    final book = widget.app.bookById(chosen);
    if (book == null) return;
    await controller.pause();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReaderPage(app: widget.app, book: book)),
    );
  }

  Future<void> _chooseChapter() async {
    final content = controller.content;
    if (content == null) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView.builder(
        itemCount: content.chapters.length,
        itemBuilder: (context, index) => ListTile(
          selected: index == controller.chapterIndex,
          leading: CircleAvatar(radius: 16, child: Text('${index + 1}')),
          title: Text(content.chapters[index].title),
          onTap: () => Navigator.pop(context, index),
        ),
      ),
    );
    if (selected != null) {
      _keys.clear();
      await controller.selectChapter(selected);
    }
  }

  Future<void> _openTranslation() async {
    await controller.pause();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TranslationPage(app: widget.app, book: controller.book),
      ),
    );
    final updated = widget.app.bookById(controller.book.id);
    if (updated != null) await controller.refreshBook(updated);
  }

  Future<void> _openAudiobook() async {
    await controller.pause();
    final current = widget.app.bookById(controller.book.id) ?? controller.book;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AudiobookPage(app: widget.app, book: current)),
    );
    final updated = widget.app.bookById(controller.book.id);
    if (updated != null) await controller.refreshBook(updated);
  }

  TextSpan _richChunk(BuildContext context, String text, bool active) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 18.5 * widget.app.settings.fontScale,
              height: 1.7,
              letterSpacing: .05,
            ) ??
        const TextStyle(fontSize: 18.5, height: 1.7);

    if (!active || !controller.wordTrackingActive) {
      return TextSpan(
        text: text,
        style: base.copyWith(
          color: active ? scheme.onSurface : scheme.onSurface.withValues(alpha: controller.playing ? .48 : .88),
        ),
      );
    }
    final start = controller.spokenStart.clamp(0, text.length);
    final end = controller.spokenEnd.clamp(start, text.length);
    return TextSpan(
      style: base,
      children: [
        TextSpan(text: text.substring(0, start), style: TextStyle(color: scheme.onSurface.withValues(alpha: .62))),
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            color: scheme.onPrimary,
            backgroundColor: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextSpan(text: text.substring(end), style: TextStyle(color: scheme.onSurface)),
      ],
    );
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
            titleSpacing: 4,
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
              if (controller.translationAvailable)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FilterChip(
                    selected: controller.useTranslation,
                    label: Text(controller.useTranslation ? 'Traduzido' : 'Original'),
                    avatar: const Icon(Icons.translate_rounded, size: 17),
                    onSelected: controller.setUseTranslation,
                  ),
                ),
              IconButton(tooltip: 'Capítulos', onPressed: _chooseChapter, icon: const Icon(Icons.toc_rounded)),
            ],
          ),
          body: Column(
            children: [
              LinearProgressIndicator(value: controller.chapterProgress, minHeight: 3),
              if (controller.error != null)
                MaterialBanner(
                  content: Text(controller.error!),
                  leading: const Icon(Icons.error_outline_rounded),
                  actions: [TextButton(onPressed: () {}, child: const Text('OK'))],
                ),
              Expanded(
                child: SelectionArea(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 130),
                    itemCount: controller.chunks.length,
                    itemBuilder: (context, index) {
                      final active = index == controller.chunkIndex;
                      final key = _keys.putIfAbsent(index, GlobalKey.new);
                      return Center(
                        key: key,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => controller.selectChunk(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: active ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: active
                                    ? Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3))
                                    : null,
                              ),
                              child: Text.rich(_richChunk(context, controller.chunks[index], active)),
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
          bottomNavigationBar: _ReaderDock(
            controller: controller,
            onBooks: _chooseBook,
            onTranslation: _openTranslation,
            onAudiobook: _openAudiobook,
            onVoice: () => showVoiceSheet(context, widget.app),
          ),
        );
      },
    );
  }
}

class _ReaderDock extends StatelessWidget {
  const _ReaderDock({
    required this.controller,
    required this.onBooks,
    required this.onTranslation,
    required this.onAudiobook,
    required this.onVoice,
  });

  final ReaderController controller;
  final VoidCallback onBooks;
  final VoidCallback onTranslation;
  final VoidCallback onAudiobook;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 18,
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
          child: Row(
            children: [
              _DockButton(icon: Icons.library_books_rounded, label: 'Livros', onTap: onBooks),
              _DockButton(icon: Icons.translate_rounded, label: 'Traduzir', onTap: onTranslation),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: FilledButton(
                      style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                      onPressed: controller.togglePlay,
                      child: Icon(controller.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                    ),
                  ),
                ),
              ),
              _DockButton(icon: Icons.headphones_rounded, label: 'Audiobook', onTap: onAudiobook),
              _DockButton(icon: Icons.record_voice_over_rounded, label: 'Voz', onTap: onVoice),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 23),
              const SizedBox(height: 3),
              Text(label, style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.fade),
            ],
          ),
        ),
      ),
    );
  }
}
