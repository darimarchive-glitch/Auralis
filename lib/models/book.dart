enum BookFormat {
  pdf,
  epub,
  txt,
  html,
  markdown,
  docx,
  fb2,
  rtf,
}

extension BookFormatX on BookFormat {
  String get label => switch (this) {
        BookFormat.pdf => 'PDF',
        BookFormat.epub => 'EPUB',
        BookFormat.txt => 'TXT',
        BookFormat.html => 'HTML',
        BookFormat.markdown => 'Markdown',
        BookFormat.docx => 'DOCX',
        BookFormat.fb2 => 'FB2',
        BookFormat.rtf => 'RTF',
      };

  static BookFormat? fromExtension(String extension) {
    final ext = extension.toLowerCase().replaceFirst('.', '');
    return switch (ext) {
      'pdf' => BookFormat.pdf,
      'epub' => BookFormat.epub,
      'txt' => BookFormat.txt,
      'html' || 'htm' => BookFormat.html,
      'md' || 'markdown' => BookFormat.markdown,
      'docx' => BookFormat.docx,
      'fb2' => BookFormat.fb2,
      'rtf' => BookFormat.rtf,
      _ => null,
    };
  }
}

class BookChapter {
  const BookChapter({required this.id, required this.title, required this.text});

  final String id;
  final String title;
  final String text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
      };

  factory BookChapter.fromJson(Map<String, dynamic> json) => BookChapter(
        id: json['id'] as String,
        title: json['title'] as String,
        text: json['text'] as String,
      );
}

class BookContent {
  const BookContent({required this.chapters});

  final List<BookChapter> chapters;

  Map<String, dynamic> toJson() => {
        'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
      };

  factory BookContent.fromJson(Map<String, dynamic> json) => BookContent(
        chapters: (json['chapters'] as List<dynamic>? ?? const [])
            .map((item) => BookChapter.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class ParsedBook {
  const ParsedBook({
    required this.title,
    required this.author,
    required this.language,
    required this.chapters,
  });

  final String title;
  final String? author;
  final String? language;
  final List<BookChapter> chapters;
}

class BookMetadata {
  const BookMetadata({
    required this.id,
    required this.title,
    required this.author,
    required this.language,
    required this.format,
    required this.originalFileName,
    required this.storedFilePath,
    required this.contentFilePath,
    required this.chapterCount,
    required this.totalCharacters,
    required this.addedAt,
    this.lastOpenedAt,
    this.currentChapter = 0,
    this.currentChunk = 0,
  });

  final String id;
  final String title;
  final String? author;
  final String? language;
  final BookFormat format;
  final String originalFileName;
  final String storedFilePath;
  final String contentFilePath;
  final int chapterCount;
  final int totalCharacters;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final int currentChapter;
  final int currentChunk;

  double get roughProgress {
    if (chapterCount <= 0) return 0;
    return (currentChapter / chapterCount).clamp(0.0, 1.0).toDouble();
  }

  BookMetadata copyWith({
    String? title,
    String? author,
    String? language,
    DateTime? lastOpenedAt,
    int? currentChapter,
    int? currentChunk,
  }) =>
      BookMetadata(
        id: id,
        title: title ?? this.title,
        author: author ?? this.author,
        language: language ?? this.language,
        format: format,
        originalFileName: originalFileName,
        storedFilePath: storedFilePath,
        contentFilePath: contentFilePath,
        chapterCount: chapterCount,
        totalCharacters: totalCharacters,
        addedAt: addedAt,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
        currentChapter: currentChapter ?? this.currentChapter,
        currentChunk: currentChunk ?? this.currentChunk,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'language': language,
        'format': format.name,
        'originalFileName': originalFileName,
        'storedFilePath': storedFilePath,
        'contentFilePath': contentFilePath,
        'chapterCount': chapterCount,
        'totalCharacters': totalCharacters,
        'addedAt': addedAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
        'currentChapter': currentChapter,
        'currentChunk': currentChunk,
      };

  factory BookMetadata.fromJson(Map<String, dynamic> json) => BookMetadata(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String?,
        language: json['language'] as String?,
        format: BookFormat.values.byName(json['format'] as String),
        originalFileName: json['originalFileName'] as String,
        storedFilePath: json['storedFilePath'] as String,
        contentFilePath: json['contentFilePath'] as String,
        chapterCount: json['chapterCount'] as int,
        totalCharacters: json['totalCharacters'] as int,
        addedAt: DateTime.parse(json['addedAt'] as String),
        lastOpenedAt: json['lastOpenedAt'] == null
            ? null
            : DateTime.parse(json['lastOpenedAt'] as String),
        currentChapter: json['currentChapter'] as int? ?? 0,
        currentChunk: json['currentChunk'] as int? ?? 0,
      );
}
