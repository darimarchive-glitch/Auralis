import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/book.dart';

class CoverService {
  CoverService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String?> resolve(BookMetadata book) async {
    if (book.coverPath != null && await File(book.coverPath!).exists()) {
      return book.coverPath;
    }

    final target = File(p.join(p.dirname(book.storedFilePath), 'cover.jpg'));
    final candidate = await _openLibrary(book) ?? await _googleBooks(book);
    if (candidate == null) return null;

    try {
      final response = await _client.get(candidate).timeout(const Duration(seconds: 18));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      if (response.bodyBytes.length < 2000) return null;
      await target.writeAsBytes(response.bodyBytes, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  Future<Uri?> _openLibrary(BookMetadata book) async {
    try {
      final query = <String, String>{'title': book.title, 'limit': '8'};
      if ((book.author ?? '').trim().isNotEmpty) query['author'] = book.author!.trim();
      final uri = Uri.https('openlibrary.org', '/search.json', query);
      final response = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final docs = (data['docs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      docs.sort((a, b) => _score(book, b).compareTo(_score(book, a)));
      for (final doc in docs) {
        if (_score(book, doc) < .64) continue;
        final cover = doc['cover_i'];
        if (cover is num) {
          return Uri.parse('https://covers.openlibrary.org/b/id/${cover.toInt()}-L.jpg');
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Uri?> _googleBooks(BookMetadata book) async {
    try {
      final q = <String>['intitle:${book.title}'];
      if ((book.author ?? '').trim().isNotEmpty) q.add('inauthor:${book.author}');
      final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
        'q': q.join('+'),
        'maxResults': '8',
        'printType': 'books',
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      Map<String, dynamic>? best;
      double bestScore = 0;
      for (final item in items) {
        final info = item['volumeInfo'];
        if (info is! Map<String, dynamic>) continue;
        final score = _scoreGoogle(book, info);
        if (score > bestScore) {
          bestScore = score;
          best = info;
        }
      }
      if (best == null || bestScore < .64) return null;
      final links = best['imageLinks'];
      if (links is! Map<String, dynamic>) return null;
      final raw = links['extraLarge'] ?? links['large'] ?? links['medium'] ?? links['thumbnail'];
      if (raw is! String || raw.isEmpty) return null;
      return Uri.parse(raw.replaceFirst('http://', 'https://'));
    } catch (_) {}
    return null;
  }

  double _score(BookMetadata book, Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? '';
    final authors = item['author_name'];
    final author = authors is List && authors.isNotEmpty ? authors.first.toString() : '';
    return _similarity(book.title, title) * .78 +
        _similarity(book.author ?? '', author) * .22;
  }

  double _scoreGoogle(BookMetadata book, Map<String, dynamic> info) {
    final title = info['title']?.toString() ?? '';
    final authors = info['authors'];
    final author = authors is List && authors.isNotEmpty ? authors.first.toString() : '';
    return _similarity(book.title, title) * .78 +
        _similarity(book.author ?? '', author) * .22;
  }

  double _similarity(String a, String b) {
    final left = _tokens(a);
    final right = _tokens(b);
    if (left.isEmpty || right.isEmpty) return a.trim().isEmpty ? 1 : 0;
    final intersection = left.intersection(right).length;
    final union = left.union(right).length;
    return union == 0 ? 0 : intersection / union;
  }

  Set<String> _tokens(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9À-ÿ]+', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((e) => e.length > 1)
      .toSet();

  void dispose() => _client.close();
}
