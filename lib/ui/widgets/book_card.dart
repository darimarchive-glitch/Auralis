import 'package:flutter/material.dart';

import '../../models/book.dart';

class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book, required this.onOpen, required this.onDelete});
  final BookMetadata book;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 112,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        book.format.label,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              if (book.author != null) ...[
                const SizedBox(height: 4),
                Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              LinearProgressIndicator(value: book.roughProgress),
              Row(
                children: [
                  Expanded(child: Text('${book.chapterCount} capítulos • ${book.language ?? 'idioma automático'}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(tooltip: 'Remover', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
