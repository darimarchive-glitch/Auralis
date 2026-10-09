import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import '../models/settings.dart';
import 'book_importer.dart';

class BookRepository {
  BookRepository._(this.root, this._importer);

  final Directory root;
  final BookImporter _importer;
  File get _libraryFile => File(p.join(root.path, 'library.json'));
  File get _settingsFile => File(p.join(root.path, 'settings.json'));
  Directory get _booksDir => Directory(p.join(root.path, 'books'));

  static Future<BookRepository> create() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'auralis_reader'));
    await root.create(recursive: true);
    await Directory(p.join(root.path, 'books')).create(recursive: true);
    return BookRepository._(root, BookImporter());
  }

  Future<List<BookMetadata>> loadLibrary() async {
    if (!await _libraryFile.exists()) return [];
    try {
      final decoded = jsonDecode(await _libraryFile.readAsString()) as List<dynamic>;
      final books = decoded
          .map((e) => BookMetadata.fromJson(e as Map<String, dynamic>))
          .toList();
      books.sort(
        (a, b) => (b.lastOpenedAt ?? b.addedAt).compareTo(a.lastOpenedAt ?? a.addedAt),
      );
      return books;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLibrary(List<BookMetadata> books) async {
    await _libraryFile.writeAsString(
      const JsonEncoder.withIndent(' ').convert(books.map((e) => e.toJson()).toList()),
      flush: true,
    );
  }

  Future<AppSettings> loadSettings() async {
    if (!await _settingsFile.exists()) return const AppSettings();
    try {
      return AppSettings.fromJson(
        jsonDecode(await _settingsFile.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _settingsFile.writeAsString(
      const JsonEncoder.withIndent(' ').convert(settings.toJson()),
      flush: true,
    );
  }

  Future<BookMetadata> importPlatformFile(PlatformFile picked) async {
    final ext = p.extension(picked.name).toLowerCase().replaceFirst('.', '');
    final format = BookFormatX.fromExtension(ext);
    if (format == null) {
      throw BookImportException('Formato .$ext não suportado nesta versão.');
    }

    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final dir = Directory(p.join(_booksDir.path, id));
    await dir.create(recursive: true);
    final safeName = picked.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final stored = File(p.join(dir.path, safeName));

    try {
      final bytes = await picked.readAsBytes();
      await stored.writeAsBytes(bytes, flush: true);
    } catch (_) {
      if (picked.path != null) {
        await File(picked.path!).copy(stored.path);
      } else {
        rethrow;
      }
    }

    try {
      final parsed = await _importer.parse(stored.path);
      final content = BookContent(chapters: parsed.chapters);
      final contentFile = File(p.join(dir.path, 'content.json'));
      await contentFile.writeAsString(jsonEncode(content.toJson()), flush: true);

      String? coverPath;
      if (parsed.coverBytes != null && parsed.coverBytes!.isNotEmpty) {
        final ext = (parsed.coverExtension ?? 'jpg').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final cover = File(p.join(dir.path, 'cover.${ext.isEmpty ? 'jpg' : ext}'));
        await cover.writeAsBytes(parsed.coverBytes!, flush: true);
        coverPath = cover.path;
      }

      return BookMetadata(
        id: id,
        title: parsed.title,
        author: parsed.author,
        language: parsed.language,
        format: format,
        originalFileName: picked.name,
        storedFilePath: stored.path,
        contentFilePath: contentFile.path,
        coverPath: coverPath,
        chapterCount: parsed.chapters.length,
        totalCharacters: parsed.chapters.fold(0, (sum, c) => sum + c.text.length),
        addedAt: DateTime.now(),
      );
    } catch (_) {
      if (await dir.exists()) await dir.delete(recursive: true);
      rethrow;
    }
  }

  Future<BookContent> loadContent(BookMetadata book) async {
    final file = File(book.contentFilePath);
    if (!await file.exists()) {
      throw const BookImportException('Conteúdo extraído do livro não foi encontrado.');
    }
    return BookContent.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<BookContent?> loadTranslation(BookMetadata book, String language) async {
    final path = book.translationFiles[language];
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      return BookContent.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<BookMetadata> saveTranslation(
    BookMetadata book,
    String language,
    BookContent content,
  ) async {
    final safeLanguage = language.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '_');
    final file = File(
      p.join(p.dirname(book.storedFilePath), 'translation_$safeLanguage.json'),
    );
    await file.writeAsString(jsonEncode(content.toJson()), flush: true);
    final files = Map<String, String>.from(book.translationFiles)..[language] = file.path;
    return book.copyWith(
      activeTranslationLanguage: language,
      translationFiles: files,
    );
  }

  Future<void> deleteTranslation(BookMetadata book, String language) async {
    final path = book.translationFiles[language];
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> deleteBook(BookMetadata book) async {
    final dir = Directory(p.dirname(book.storedFilePath));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
