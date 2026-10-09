import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/book.dart';
import '../models/settings.dart';
import '../services/book_importer.dart';
import '../services/book_repository.dart';
import '../services/cover_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository, this.tts)
      : covers = CoverService(),
        translator = TranslationService();

  final BookRepository repository;
  final LocalTtsService tts;
  final CoverService covers;
  final TranslationService translator;

  List<BookMetadata> books = [];
  AppSettings settings = const AppSettings();
  bool busy = false;
  String? status;
  double? taskProgress;

  Future<void> init() async {
    books = await repository.loadLibrary();
    settings = await repository.loadSettings();

    if (Platform.isAndroid && settings.voiceModeVersion < 3) {
      settings = settings.copyWith(
        ttsBackend: TtsBackend.system,
        clearVoice: true,
        voiceModeVersion: 3,
      );
      await repository.saveSettings(settings);
    }
  }

  BookMetadata? bookById(String id) {
    for (final book in books) {
      if (book.id == id) return book;
    }
    return null;
  }

  Future<BookMetadata?> importBook() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: BookImporter.supportedExtensions,
    );
    if (picked == null) return null;

    busy = true;
    status = 'Importando e interpretando o livro…';
    taskProgress = null;
    notifyListeners();
    try {
      var book = await repository.importPlatformFile(picked);
      if (settings.autoCovers && !book.hasCover) {
        status = 'Procurando a capa correta…';
        notifyListeners();
        final cover = await covers.resolve(book);
        if (cover != null) book = book.copyWith(coverPath: cover);
      }
      books = [book, ...books.where((item) => item.id != book.id)];
      await repository.saveLibrary(books);
      return book;
    } finally {
      busy = false;
      status = null;
      taskProgress = null;
      notifyListeners();
    }
  }

  Future<void> updateBook(BookMetadata updated) async {
    final index = books.indexWhere((book) => book.id == updated.id);
    if (index == -1) return;
    books[index] = updated;
    await repository.saveLibrary(books);
    notifyListeners();
  }

  Future<BookMetadata> refreshCover(BookMetadata book) async {
    busy = true;
    status = 'Buscando uma capa compatível…';
    notifyListeners();
    try {
      final cover = await covers.resolve(book.copyWith(clearCover: true));
      if (cover == null) throw StateError('Nenhuma capa confiável foi encontrada.');
      final updated = book.copyWith(coverPath: cover);
      await updateBook(updated);
      return updated;
    } finally {
      busy = false;
      status = null;
      notifyListeners();
    }
  }

  Future<BookMetadata> translateBook(
    BookMetadata book, {
    required String targetLanguage,
    required String profile,
    required bool literaryAi,
  }) async {
    if (busy) throw StateError('O Auralis já está processando outra tarefa.');
    busy = true;
    taskProgress = 0;
    status = 'Preparando tradução…';
    notifyListeners();

    try {
      final original = await repository.loadContent(book);
      final effectiveSettings = settings.copyWith(
        translationTarget: targetLanguage,
        translationProfile: profile,
        translationProvider: literaryAi
            ? TranslationProvider.literaryAi
            : TranslationProvider.auto,
      );
      settings = effectiveSettings;
      await repository.saveSettings(settings);

      final translated = await translator.translateBook(
        original,
        sourceLanguage: book.language ?? 'auto',
        targetLanguage: targetLanguage,
        profile: profile,
        settings: settings,
        onProgress: (progress) {
          taskProgress = progress.total <= 0 ? null : progress.chapter / progress.total;
          status = '${progress.message} • ${progress.chapter}/${progress.total}';
          notifyListeners();
        },
      );

      var updated = await repository.saveTranslation(book, targetLanguage, translated);
      final index = books.indexWhere((item) => item.id == book.id);
      if (index >= 0) books[index] = updated;
      await repository.saveLibrary(books);
      notifyListeners();
      return updated;
    } finally {
      busy = false;
      status = null;
      taskProgress = null;
      notifyListeners();
    }
  }

  Future<void> deleteBook(BookMetadata book) async {
    await tts.stop();
    await repository.deleteBook(book);
    books.removeWhere((item) => item.id == book.id);
    await repository.saveLibrary(books);
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings value) async {
    settings = value;
    await repository.saveSettings(settings);
    notifyListeners();
  }

  @override
  void dispose() {
    tts.dispose();
    covers.dispose();
    translator.dispose();
    super.dispose();
  }
}
