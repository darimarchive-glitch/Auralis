import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/book.dart';
import '../models/settings.dart';
import '../services/book_importer.dart';
import '../services/book_repository.dart';
import '../services/tts_service.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository, this.tts);

  final BookRepository repository;
  final LocalTtsService tts;
  List<BookMetadata> books = [];
  AppSettings settings = const AppSettings();
  bool busy = false;
  String? status;

  Future<void> init() async {
    books = await repository.loadLibrary();
    settings = await repository.loadSettings();

    // Auralis 2.1 muda a recomendação no Android: prioriza a melhor voz
    // natural instalada no sistema, que costuma soar mais humana e também
    // oferece marcação palavra a palavra. O Supertonic continua disponível
    // como opção 100% offline.
    if (Platform.isAndroid && settings.voiceModeVersion < 2) {
      settings = settings.copyWith(
        ttsBackend: TtsBackend.system,
        clearVoice: true,
        voiceModeVersion: 2,
      );
      await repository.saveSettings(settings);
    }
  }

  Future<BookMetadata?> importBook() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: BookImporter.supportedExtensions,
    );
    if (picked == null) return null;
    busy = true;
    status = 'Importando e extraindo o texto…';
    notifyListeners();
    try {
      final book = await repository.importPlatformFile(picked);
      books = [book, ...books];
      await repository.saveLibrary(books);
      return book;
    } finally {
      busy = false;
      status = null;
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
}
