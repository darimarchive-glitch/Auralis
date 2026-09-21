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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderPage(app: controller, book: book)));
  }

  Future<void> _delete(BuildContext context, BookMetadata book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover livro?'),
        content: Text('“${book.title}” e sua cópia local serão removidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok == true) await controller.deleteBook(book);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Auralis'),
          actions: [
            IconButton(
              tooltip: 'Configurações',
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage(controller: controller)),
              ),
            ),
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
                        const Icon(Icons.auto_stories_outlined, size: 72),
                        const SizedBox(height: 20),
                        Text('Sua biblioteca está vazia', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        const Text(
                          'Importe PDF, EPUB, TXT, HTML, Markdown, DOCX, FB2 ou RTF. O arquivo fica no seu dispositivo.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(onPressed: () => _import(context), icon: const Icon(Icons.add), label: const Text('Adicionar livro')),
                      ],
                    ),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final count = width >= 1100 ? 5 : width >= 800 ? 4 : width >= 560 ? 3 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: width < 560 ? .62 : .72,
                    ),
                    itemCount: controller.books.length,
                    itemBuilder: (context, index) {
                      final book = controller.books[index];
                      return BookCard(book: book, onOpen: () => _open(context, book), onDelete: () => _delete(context, book));
                    },
                  );
                },
              ),
            if (controller.busy)
              ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(controller.status ?? 'Processando…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: controller.books.isEmpty
            ? null
            : FloatingActionButton.extended(onPressed: () => _import(context), icon: const Icon(Icons.add), label: const Text('Adicionar')),
      ),
    );
  }
}
