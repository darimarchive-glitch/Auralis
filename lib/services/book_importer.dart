import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

import '../models/book.dart';
import 'text_normalizer.dart';

class BookImportException implements Exception {
  const BookImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BookImporter {
  static const supportedExtensions = <String>[
    'pdf',
    'epub',
    'txt',
    'html',
    'htm',
    'md',
    'markdown',
    'docx',
    'fb2',
    'rtf',
  ];

  Future<ParsedBook> parse(String filePath) async {
    final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
    final format = BookFormatX.fromExtension(extension);
    if (format == null) {
      throw BookImportException('Formato .$extension ainda não é suportado.');
    }

    return switch (format) {
      BookFormat.pdf => _parsePdf(filePath),
      BookFormat.epub => _parseEpub(filePath),
      BookFormat.txt => _parsePlain(filePath, markdown: false),
      BookFormat.markdown => _parsePlain(filePath, markdown: true),
      BookFormat.html => _parseHtml(filePath),
      BookFormat.docx => _parseDocx(filePath),
      BookFormat.fb2 => _parseFb2(filePath),
      BookFormat.rtf => _parseRtf(filePath),
    };
  }

  Future<ParsedBook> _parsePdf(String path) async {
    final document = await PdfDocument.openFile(path);
    final pageTexts = <String>[];
    try {
      for (final page in document.pages) {
        final loadedPage = await page.ensureLoaded();
        final raw = await loadedPage.loadText();
        pageTexts.add(TextNormalizer.clean(raw?.fullText ?? ''));
      }
    } finally {
      await document.dispose();
    }

    final nonEmpty = pageTexts.where((value) => value.trim().length > 20).length;
    if (pageTexts.isEmpty || nonEmpty == 0) {
      throw const BookImportException(
        'Este PDF parece ser escaneado e não possui camada de texto. '
        'OCR local entra na próxima etapa do Auralis.',
      );
    }

    final chapters = <BookChapter>[];
    const pagesPerChapter = 12;
    for (var start = 0; start < pageTexts.length; start += pagesPerChapter) {
      final end = (start + pagesPerChapter).clamp(0, pageTexts.length).toInt();
      final body = pageTexts.sublist(start, end).where((e) => e.isNotEmpty).join('\n\n');
      if (body.isEmpty) continue;
      chapters.add(
        BookChapter(
          id: 'pdf-${start + 1}',
          title: end - start == 1
              ? 'Página ${start + 1}'
              : 'Páginas ${start + 1}–$end',
          text: body,
        ),
      );
    }

    final title = p.basenameWithoutExtension(path);
    final language = TextNormalizer.guessLanguage(
      chapters.take(2).map((chapter) => chapter.text).join(' '),
    );
    return ParsedBook(title: title, author: null, language: language, chapters: chapters);
  }

  Future<ParsedBook> _parseEpub(String path) async {
    final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final entries = <String, ArchiveFile>{
      for (final file in archive) _normalizeZipPath(file.name): file,
    };

    final container = entries['META-INF/container.xml'];
    if (container == null) {
      throw const BookImportException('EPUB inválido: META-INF/container.xml ausente.');
    }
    final containerXml = XmlDocument.parse(utf8.decode(container.readBytes()!));
    final rootfile = _elementsByLocalName(containerXml, 'rootfile').firstOrNull;
    final opfPath = rootfile?.getAttribute('full-path');
    if (opfPath == null) throw const BookImportException('EPUB inválido: OPF não encontrado.');

    final normalizedOpf = _normalizeZipPath(opfPath);
    final opfEntry = entries[normalizedOpf];
    if (opfEntry == null) throw const BookImportException('EPUB inválido: pacote OPF ausente.');
    final opf = XmlDocument.parse(utf8.decode(opfEntry.readBytes()!));

    final title = _firstText(opf, 'title')?.trim().isNotEmpty == true
        ? _firstText(opf, 'title')!.trim()
        : p.basenameWithoutExtension(path);
    final author = _firstText(opf, 'creator')?.trim();
    final language = _normalizeLocale(_firstText(opf, 'language')?.trim());

    final manifest = <String, String>{};
    for (final item in _elementsByLocalName(opf, 'item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) manifest[id] = href;
    }

    final opfDir = p.posix.dirname(normalizedOpf);
    final chapters = <BookChapter>[];
    var index = 1;
    for (final itemRef in _elementsByLocalName(opf, 'itemref')) {
      final idref = itemRef.getAttribute('idref');
      final href = idref == null ? null : manifest[idref];
      if (href == null) continue;
      final itemPath = _normalizeZipPath(
        opfDir == '.' ? href : p.posix.join(opfDir, Uri.decodeComponent(href.split('#').first)),
      );
      final entry = entries[itemPath];
      if (entry == null || !entry.isFile) continue;
      final markup = utf8.decode(entry.readBytes()!, allowMalformed: true);
      final extracted = _extractHtml(markup);
      if (extracted.text.length < 20) continue;
      chapters.add(
        BookChapter(
          id: 'epub-$index',
          title: extracted.title ?? 'Capítulo $index',
          text: extracted.text,
        ),
      );
      index++;
    }

    if (chapters.isEmpty) throw const BookImportException('Não foi possível extrair texto deste EPUB.');
    return ParsedBook(
      title: title,
      author: author?.isEmpty == true ? null : author,
      language: language ?? TextNormalizer.guessLanguage(chapters.first.text),
      chapters: chapters,
    );
  }

  Future<ParsedBook> _parsePlain(String path, {required bool markdown}) async {
    var text = await File(path).readAsString();
    if (markdown) {
      text = text
          .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
          .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
          .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1) ?? '')
          .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
          .replaceAll(RegExp(r'[*_~`]'), '');
    }
    return _fromPlainText(path, text);
  }

  Future<ParsedBook> _parseHtml(String path) async {
    final markup = await File(path).readAsString();
    final extracted = _extractHtml(markup);
    final title = extracted.title ?? p.basenameWithoutExtension(path);
    final chapterPairs = TextNormalizer.splitPlainTextChapters(extracted.text);
    return ParsedBook(
      title: title,
      author: null,
      language: TextNormalizer.guessLanguage(extracted.text),
      chapters: _pairsToChapters(chapterPairs, 'html'),
    );
  }

  Future<ParsedBook> _parseDocx(String path) async {
    final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    ArchiveFile? find(String name) {
      for (final entry in archive) {
        if (_normalizeZipPath(entry.name) == name) return entry;
      }
      return null;
    }

    final documentFile = find('word/document.xml');
    if (documentFile == null) throw const BookImportException('DOCX inválido: document.xml ausente.');
    final document = XmlDocument.parse(utf8.decode(documentFile.readBytes()!));

    String? title;
    String? author;
    final core = find('docProps/core.xml');
    if (core != null) {
      final coreXml = XmlDocument.parse(utf8.decode(core.readBytes()!));
      title = _firstText(coreXml, 'title')?.trim();
      author = _firstText(coreXml, 'creator')?.trim();
    }

    final paragraphs = <String>[];
    for (final paragraph in _elementsByLocalName(document, 'p')) {
      final text = _elementsByLocalName(paragraph, 't').map((e) => e.innerText).join();
      if (text.trim().isNotEmpty) paragraphs.add(text.trim());
    }
    final body = paragraphs.join('\n\n');
    if (body.trim().isEmpty) throw const BookImportException('DOCX sem texto legível.');
    final pairs = TextNormalizer.splitPlainTextChapters(body);
    return ParsedBook(
      title: title?.isNotEmpty == true ? title! : p.basenameWithoutExtension(path),
      author: author?.isNotEmpty == true ? author : null,
      language: TextNormalizer.guessLanguage(body),
      chapters: _pairsToChapters(pairs, 'docx'),
    );
  }

  Future<ParsedBook> _parseFb2(String path) async {
    final xml = XmlDocument.parse(await File(path).readAsString());
    final title = _firstText(xml, 'book-title')?.trim() ?? p.basenameWithoutExtension(path);
    final firstName = _firstText(xml, 'first-name')?.trim() ?? '';
    final lastName = _firstText(xml, 'last-name')?.trim() ?? '';
    final author = '$firstName $lastName'.trim();
    final lang = _normalizeLocale(_firstText(xml, 'lang')?.trim());

    final chapters = <BookChapter>[];
    var i = 1;
    for (final section in _elementsByLocalName(xml, 'section')) {
      final paragraphs = _elementsByLocalName(section, 'p')
          .map((e) => e.innerText.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (paragraphs.isEmpty) continue;
      final sectionTitle = _elementsByLocalName(section, 'title')
          .expand((e) => _elementsByLocalName(e, 'p'))
          .map((e) => e.innerText.trim())
          .where((e) => e.isNotEmpty)
          .firstOrNull;
      chapters.add(
        BookChapter(
          id: 'fb2-$i',
          title: sectionTitle ?? 'Capítulo $i',
          text: TextNormalizer.clean(paragraphs.join('\n\n')),
        ),
      );
      i++;
    }
    if (chapters.isEmpty) throw const BookImportException('FB2 sem texto legível.');
    return ParsedBook(
      title: title,
      author: author.isEmpty ? null : author,
      language: lang ?? TextNormalizer.guessLanguage(chapters.first.text),
      chapters: chapters,
    );
  }

  Future<ParsedBook> _parseRtf(String path) async {
    var rtf = utf8.decode(await File(path).readAsBytes(), allowMalformed: true);
    rtf = rtf.replaceAllMapped(RegExp(r"\\'([0-9a-fA-F]{2})"), (match) {
      final code = int.tryParse(match.group(1)!, radix: 16);
      return code == null ? '' : String.fromCharCode(code);
    });
    final plain = rtf
        .replaceAll(RegExp(r'\\par\b'), '\n\n')
        .replaceAll(RegExp(r'\\tab\b'), ' ')
        .replaceAll(RegExp(r'\\[a-zA-Z]+-?\d*\s?'), '')
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll(r'\{', '{')
        .replaceAll(r'\}', '}')
        .replaceAll(r'\\', '\\');
    return _fromPlainText(path, plain);
  }

  ParsedBook _fromPlainText(String path, String text) {
    final pairs = TextNormalizer.splitPlainTextChapters(text);
    if (pairs.isEmpty) throw const BookImportException('O arquivo não contém texto legível.');
    final chapters = _pairsToChapters(pairs, 'text');
    return ParsedBook(
      title: p.basenameWithoutExtension(path),
      author: null,
      language: TextNormalizer.guessLanguage(chapters.first.text),
      chapters: chapters,
    );
  }

  List<BookChapter> _pairsToChapters(List<MapEntry<String, String>> pairs, String prefix) => [
        for (var i = 0; i < pairs.length; i++)
          BookChapter(id: '$prefix-${i + 1}', title: pairs[i].key, text: pairs[i].value),
      ];

  _HtmlExtraction _extractHtml(String markup) {
    final document = html_parser.parse(markup);
    document.querySelectorAll('script, style, noscript, svg').forEach((element) => element.remove());
    final title = document.querySelector('h1')?.text.trim().isNotEmpty == true
        ? document.querySelector('h1')!.text.trim()
        : document.querySelector('title')?.text.trim();
    final body = document.body?.text ?? document.documentElement?.text ?? '';
    return _HtmlExtraction(title: title?.isEmpty == true ? null : title, text: TextNormalizer.clean(body));
  }

  Iterable<XmlElement> _elementsByLocalName(XmlNode node, String localName) =>
      node.descendants.whereType<XmlElement>().where((element) => element.name.local == localName);

  String? _firstText(XmlNode node, String localName) =>
      _elementsByLocalName(node, localName).firstOrNull?.innerText;

  String _normalizeZipPath(String value) => p.posix.normalize(value.replaceAll('\\', '/'));

  String? _normalizeLocale(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.replaceAll('_', '-');
    final parts = normalized.split('-');
    if (parts.length == 1) {
      return switch (parts.first.toLowerCase()) {
        'pt' => 'pt-BR',
        'en' => 'en-US',
        'es' => 'es-ES',
        'fr' => 'fr-FR',
        'de' => 'de-DE',
        'it' => 'it-IT',
        _ => normalized,
      };
    }
    return '${parts.first.toLowerCase()}-${parts[1].toUpperCase()}';
  }
}

class _HtmlExtraction {
  const _HtmlExtraction({required this.title, required this.text});
  final String? title;
  final String text;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
