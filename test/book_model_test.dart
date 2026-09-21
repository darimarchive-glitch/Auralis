import 'package:auralis_reader/models/book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BookContent serializa e desserializa', () {
    const source = BookContent(chapters: [BookChapter(id: '1', title: 'Um', text: 'Texto')]);
    final decoded = BookContent.fromJson(source.toJson());
    expect(decoded.chapters.single.title, 'Um');
  });
}
