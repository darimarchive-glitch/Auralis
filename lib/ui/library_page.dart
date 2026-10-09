import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/book.dart';
import 'reader_page.dart';
import 'settings_page.dart';
import 'widgets/book_card.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.controller});
  final AppController controller;

  Future<void> _import(BuildContext context) async {
    try {
      final book = await controller.importBook();
      if (book != null && context.mounted) _open(context, book);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _open(BuildContext context, BookMetadata book) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderPage(app: controller, book: book)),
    );
  }

  Future<void> _delete(BuildContext context, BookMetadata book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover livro?'),
        content: Text('“${book.title}” e seus dados locais serão removidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok == true) await controller.deleteBook(book);
  }

  Future<void> _refreshCover(BuildContext context, BookMetadata book) async {
    try {
      await controller.refreshCover(book);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Auralis'),
              Text('Sua biblioteca', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Configurações',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage(controller: controller)),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Stack(
          children: [
            if (controller.books.isEmpty)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Icon(Icons.auto_stories_rounded, size: 48),
                        ),
                        const SizedBox(height: 22),
                        Text('Comece sua biblioteca', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        const Text(
                          'Importe EPUB, PDF, DOCX, TXT, HTML, Markdown, FB2 ou RTF. Capas, progresso e traduções ficam organizados no Auralis.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _import(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Adicionar livro'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final count = width >= 1200 ? 6 : width >= 900 ? 5 : width >= 680 ? 4 : width >= 430 ? 3 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: width < 560 ? .58 : .64,
                    ),
                    itemCount: controller.books.length,
                    itemBuilder: (context, index) {
                      final book = controller.books[index];
                      return BookCard(
                        book: book,
                        onOpen: () => _open(context, book),
                        onDelete: () => _delete(context, book),
                        onRefreshCover: () => _refreshCover(context, book),
                      );
                    },
                  );
                },
              ),
            if (controller.busy)
              ColoredBox(
                color: Colors.black.withValues(alpha: .55),
                child: Center(
                  child: Card(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            controller.taskProgress == null
                                ? const CircularProgressIndicator()
                                : CircularProgressIndicator(value: controller.taskProgress),
                            const SizedBox(height: 16),
                            Text(controller.status ?? 'Processando…', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: controller.books.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _import(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar'),
              ),
      ),
    );
  }
}
