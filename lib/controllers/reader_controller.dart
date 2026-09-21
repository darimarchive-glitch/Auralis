import 'package:flutter/foundation.dart';

import '../models/book.dart';
import '../services/text_normalizer.dart';
import 'app_controller.dart';

class ReaderController extends ChangeNotifier {
  ReaderController(this.app, this.book);
  final AppController app;
  BookMetadata book;

  BookContent? content;
  List<String> chunks = [];
  int chapterIndex = 0;
  int chunkIndex = 0;
  bool playing = false;
  bool loading = true;
  String? error;
  int _playGeneration = 0;

  BookChapter? get chapter => content == null || content!.chapters.isEmpty ? null : content!.chapters[chapterIndex];
  double get chapterProgress => chunks.isEmpty ? 0 : (chunkIndex / chunks.length).clamp(0.0, 1.0).toDouble();

  Future<void> init() async {
    try {
      content = await app.repository.loadContent(book);
      chapterIndex = book.currentChapter.clamp(0, content!.chapters.length - 1).toInt();
      _loadChapterChunks(book.currentChunk);
      book = book.copyWith(lastOpenedAt: DateTime.now());
      await app.updateBook(book);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _loadChapterChunks(int preferredChunk) {
    chunks = TextNormalizer.speechChunks(content!.chapters[chapterIndex].text);
    chunkIndex = chunks.isEmpty ? 0 : preferredChunk.clamp(0, chunks.length - 1).toInt();
  }

  Future<void> togglePlay() => playing ? pause() : play();

  Future<void> play() async {
    if (chunks.isEmpty || playing) return;
    playing = true;
    final generation = ++_playGeneration;
    notifyListeners();
    try {
      while (playing && generation == _playGeneration) {
        final language = book.language ?? app.settings.defaultLanguage;
        await app.tts.speak(
          chunks[chunkIndex],
          language: language,
          rate: app.settings.speechRate,
          backend: app.settings.ttsBackend,
          neuralVoiceId: app.settings.neuralVoiceId,
          neuralSteps: app.settings.neuralSteps,
          voiceName: app.settings.voiceName,
          voiceLocale: app.settings.voiceLocale,
          engine: app.settings.ttsEngine,
        );
        if (!playing || generation != _playGeneration) break;
        if (chunkIndex + 1 < chunks.length) {
          chunkIndex++;
        } else if (content != null && chapterIndex + 1 < content!.chapters.length) {
          chapterIndex++;
          _loadChapterChunks(0);
        } else {
          playing = false;
          break;
        }
        await _persistProgress();
        notifyListeners();
      }
    } catch (e) {
      error = e.toString();
      playing = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    playing = false;
    _playGeneration++;
    await app.tts.stop();
    await _persistProgress();
    notifyListeners();
  }

  Future<void> selectChunk(int index) async {
    final wasPlaying = playing;
    await pause();
    chunkIndex = index.clamp(0, chunks.length - 1).toInt();
    await _persistProgress();
    notifyListeners();
    if (wasPlaying) await play();
  }

  Future<void> selectChapter(int index) async {
    final wasPlaying = playing;
    await pause();
    chapterIndex = index.clamp(0, content!.chapters.length - 1).toInt();
    _loadChapterChunks(0);
    await _persistProgress();
    notifyListeners();
    if (wasPlaying) await play();
  }

  Future<void> skip(int delta) => selectChunk((chunkIndex + delta).clamp(0, chunks.length - 1).toInt());

  Future<void> _persistProgress() async {
    book = book.copyWith(
      lastOpenedAt: DateTime.now(),
      currentChapter: chapterIndex,
      currentChunk: chunkIndex,
    );
    await app.updateBook(book);
  }

  @override
  void dispose() {
    playing = false;
    _playGeneration++;
    app.tts.stop();
    super.dispose();
  }
}
