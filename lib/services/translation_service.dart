import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book.dart';
import '../models/settings.dart';

class TranslationProgress {
  const TranslationProgress({required this.chapter, required this.total, required this.message});
  final int chapter;
  final int total;
  final String message;
}

class TranslationService {
  TranslationService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<BookContent> translateBook(
    BookContent source, {
    required String sourceLanguage,
    required String targetLanguage,
    required String profile,
    required AppSettings settings,
    void Function(TranslationProgress progress)? onProgress,
  }) async {
    final chapters = <BookChapter>[];
    for (var i = 0; i < source.chapters.length; i++) {
      final chapter = source.chapters[i];
      onProgress?.call(TranslationProgress(
        chapter: i + 1,
        total: source.chapters.length,
        message: 'Traduzindo ${chapter.title}',
      ));
      final translated = await translateText(
        chapter.text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        profile: profile,
        settings: settings,
      );
      chapters.add(BookChapter(id: chapter.id, title: chapter.title, text: translated));
    }
    return BookContent(chapters: chapters);
  }

  Future<String> translateText(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
    required String profile,
    required AppSettings settings,
  }) async {
    if (text.trim().isEmpty) return '';

    final shouldTryAi = settings.translationProvider != TranslationProvider.quick &&
        settings.aiEndpoint.trim().isNotEmpty;
    if (shouldTryAi) {
      try {
        return await _aiTranslate(
          text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          profile: profile,
          settings: settings,
        );
      } catch (_) {
        if (settings.translationProvider == TranslationProvider.literaryAi) rethrow;
      }
    }

    return _quickTranslate(
      text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  Future<String> _aiTranslate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
    required String profile,
    required AppSettings settings,
  }) async {
    final endpoint = _normalizeChatEndpoint(settings.aiEndpoint);
    final style = switch (profile) {
      'modern' => 'Use natural contemporary language while preserving every fact, paragraph and dialogue.',
      'literal' => 'Translate literally and conservatively. Do not paraphrase or embellish.',
      'study' => 'Prioritize clarity and precision while preserving structure and meaning.',
      _ => 'Preserve the literary voice, period, register, rhythm, dialogue and paragraph structure.',
    };
    final prompt = '''You are a professional literary translator.
Translate the complete passage from $sourceLanguage to $targetLanguage.
$style
Never summarize. Never omit lines. Never add commentary. Keep names and paragraph breaks stable.
Return only the translated passage.''';

    final chunks = _paragraphChunks(text, 7000);
    final out = <String>[];
    for (final chunk in chunks) {
      final headers = <String, String>{'content-type': 'application/json'};
      if (settings.aiApiKey.trim().isNotEmpty) {
        headers['authorization'] = 'Bearer ${settings.aiApiKey.trim()}';
      }
      final response = await _client
          .post(
            endpoint,
            headers: headers,
            body: jsonEncode({
              'model': settings.aiModel.trim().isEmpty ? 'qwen2.5:7b' : settings.aiModel.trim(),
              'temperature': profile == 'literal' ? 0.1 : 0.25,
              'messages': [
                {'role': 'system', 'content': prompt},
                {'role': 'user', 'content': chunk},
              ],
            }),
          )
          .timeout(const Duration(minutes: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('O tradutor IA respondeu HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw StateError('Resposta do tradutor IA sem conteúdo.');
      }
      final first = choices.first;
      if (first is! Map) throw StateError('Resposta do tradutor IA inválida.');
      final message = first['message'];
      final content = message is Map ? message['content']?.toString() : null;
      if (content == null || content.trim().isEmpty) {
        throw StateError('O tradutor IA retornou texto vazio.');
      }
      out.add(content.trim());
    }
    return out.join('\n\n');
  }

  Future<String> _quickTranslate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final chunks = _paragraphChunks(text, 2800);
    final out = <String>[];
    for (final chunk in chunks) {
      final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
        'client': 'gtx',
        'sl': _languageCode(sourceLanguage).isEmpty ? 'auto' : _languageCode(sourceLanguage),
        'tl': _languageCode(targetLanguage),
        'dt': 't',
        'q': chunk,
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('Tradução rápida indisponível (HTTP ${response.statusCode}).');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty || decoded.first is! List) {
        throw StateError('Resposta de tradução inválida.');
      }
      final buffer = StringBuffer();
      for (final item in decoded.first as List) {
        if (item is List && item.isNotEmpty && item.first != null) {
          buffer.write(item.first.toString());
        }
      }
      final translated = buffer.toString().trim();
      if (translated.isEmpty) throw StateError('A tradução retornou vazia.');
      out.add(translated);
    }
    return out.join('\n\n');
  }

  Uri _normalizeChatEndpoint(String value) {
    var raw = value.trim();
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'http://$raw';
    }
    var uri = Uri.parse(raw);
    if (uri.path.isEmpty || uri.path == '/') {
      uri = uri.replace(path: '/v1/chat/completions');
    }
    return uri;
  }

  String _languageCode(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('_', '-')
      .split('-')
      .first;

  List<String> _paragraphChunks(String text, int maxChars) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final paragraphs = normalized.split(RegExp(r'\n\s*\n'));
    final chunks = <String>[];
    var current = StringBuffer();

    void flush() {
      final value = current.toString().trim();
      if (value.isNotEmpty) chunks.add(value);
      current = StringBuffer();
    }

    for (final paragraph in paragraphs) {
      final value = paragraph.trim();
      if (value.isEmpty) continue;
      if (value.length > maxChars) {
        flush();
        for (var start = 0; start < value.length; start += maxChars) {
          final end = (start + maxChars).clamp(0, value.length).toInt();
          chunks.add(value.substring(start, end));
        }
        continue;
      }
      if (current.length + value.length + 2 > maxChars) flush();
      if (current.isNotEmpty) current.write('\n\n');
      current.write(value);
    }
    flush();
    return chunks.isEmpty ? <String>[normalized] : chunks;
  }

  void dispose() => _client.close();
}
