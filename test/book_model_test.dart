import 'package:auralis_reader/models/book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BookContent serializa e desserializa', () {
    const content = BookContent(chapters: [BookChapter(id: '1', title: 'Capítulo', text: 'Texto')]);
    final decoded = BookContent.fromJson(content.toJson());
    expect(decoded.chapters.single.text, 'Texto');
  });

  test('metadata antiga continua compatível sem capa e tradução', () {
    final book = BookMetadata.fromJson({
      'id': '1',
      'title': 'Livro',
      'author': null,
      'language': 'pt-BR',
      'format': 'epub',
      'originalFileName': 'livro.epub',
      'storedFilePath': '/tmp/livro.epub',
      'contentFilePath': '/tmp/content.json',
      'chapterCount': 1,
      'totalCharacters': 10,
      'addedAt': DateTime(2026).toIso8601String(),
    });
    expect(book.coverPath, isNull);
    expect(book.translationFiles, isEmpty);
  });
}
