import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/book.dart';

class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.onOpen,
    required this.onDelete,
    this.onRefreshCover,
  });

  final BookMetadata book;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback? onRefreshCover;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = book.coverPath == null ? null : File(book.coverPath!);
    final hasCover = cover != null && cover.existsSync();

    return Semantics(
      button: true,
      label: '${book.title}${book.author == null ? '' : ', ${book.author}'}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasCover)
                      Image.file(cover, fit: BoxFit.cover)
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [scheme.primaryContainer, scheme.secondaryContainer],
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_stories_rounded, size: 52, color: scheme.onPrimaryContainer),
                                const SizedBox(height: 12),
                                Text(
                                  book.title,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: scheme.onPrimaryContainer,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .68),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          child: Text(
                            book.format.label,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: PopupMenuButton<String>(
                        color: scheme.surfaceContainerHigh,
                        iconColor: Colors.white,
                        onSelected: (value) {
                          if (value == 'cover') onRefreshCover?.call();
                          if (value == 'delete') onDelete();
                        },
                        itemBuilder: (_) => [
                          if (onRefreshCover != null)
                            const PopupMenuItem(value: 'cover', child: Text('Buscar capa novamente')),
                          const PopupMenuItem(value: 'delete', child: Text('Remover livro')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.author?.trim().isNotEmpty == true ? book.author! : 'Autor não identificado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: book.roughProgress, minHeight: 4),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${(book.roughProgress * 100).round()}% • ${book.chapterCount} cap.',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        if (book.hasTranslation)
                          Icon(Icons.translate_rounded, size: 15, color: scheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
