class TextNormalizer {
  static String clean(String input) {
    var text = input
        .replaceAll('\u00ad', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    // Repara palavras quebradas por hifenização de fim de linha.
    text = text.replaceAllMapped(
      RegExp(r'(\p{L})-\s*\n\s*(\p{L})', unicode: true),
      (match) => '${match.group(1)}${match.group(2)}',
    );

    final lines = text
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[\t ]+'), ' ').trimRight())
        .toList();

    final buffer = StringBuffer();
    var blank = false;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        if (!blank && buffer.isNotEmpty) buffer.write('\n\n');
        blank = true;
        continue;
      }
      if (buffer.isNotEmpty && !blank) buffer.write(' ');
      buffer.write(line.trim());
      blank = false;
    }

    return buffer
        .toString()
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static List<String> speechChunks(String input, {int maxChars = 360}) {
    final text = clean(input);
    if (text.isEmpty) return const [];

    final sentenceLike = RegExp(
      r'''\S[\s\S]*?(?:[.!?…]+[”"'’)]*|$)(?:\s+|$)''',
      dotAll: true,
      unicode: true,
    );
    final sentences = sentenceLike
        .allMatches(text)
        .map((match) => match.group(0)!.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (sentences.isEmpty) return _hardSplit(text, maxChars);

    final chunks = <String>[];
    var current = StringBuffer();
    for (final sentence in sentences) {
      if (sentence.length > maxChars) {
        if (current.isNotEmpty) {
          chunks.add(current.toString().trim());
          current = StringBuffer();
        }
        chunks.addAll(_hardSplit(sentence, maxChars));
        continue;
      }

      if (current.length + sentence.length + 1 > maxChars && current.isNotEmpty) {
        chunks.add(current.toString().trim());
        current = StringBuffer();
      }
      if (current.isNotEmpty) current.write(' ');
      current.write(sentence);
    }
    if (current.isNotEmpty) chunks.add(current.toString().trim());
    return chunks;
  }

  static List<String> _hardSplit(String text, int maxChars) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];
    var current = StringBuffer();
    for (final word in words) {
      if (current.length + word.length + 1 > maxChars && current.isNotEmpty) {
        chunks.add(current.toString().trim());
        current = StringBuffer();
      }
      if (current.isNotEmpty) current.write(' ');
      current.write(word);
    }
    if (current.isNotEmpty) chunks.add(current.toString().trim());
    return chunks;
  }

  static String guessLanguage(String text) {
    final sample = ' ${clean(text).toLowerCase()} ';
    final scores = <String, List<String>>{
      'pt-BR': [' de ', ' que ', ' não ', ' para ', ' uma ', ' com ', ' os ', ' as '],
      'en-US': [' the ', ' and ', ' that ', ' with ', ' from ', ' this ', ' was ', ' are '],
      'es-ES': [' que ', ' de ', ' para ', ' una ', ' los ', ' las ', ' con ', ' por '],
      'fr-FR': [' le ', ' la ', ' les ', ' des ', ' une ', ' que ', ' dans ', ' avec '],
      'de-DE': [' der ', ' die ', ' das ', ' und ', ' ist ', ' mit ', ' ein ', ' nicht '],
      'it-IT': [' che ', ' di ', ' la ', ' il ', ' una ', ' con ', ' per ', ' non '],
    };
    var best = 'pt-BR';
    var bestScore = -1;
    for (final entry in scores.entries) {
      final score = entry.value.where(sample.contains).length;
      if (score > bestScore) {
        best = entry.key;
        bestScore = score;
      }
    }
    return best;
  }

  static List<MapEntry<String, String>> splitPlainTextChapters(String text) {
    final cleaned = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    final lines = cleaned.split('\n');
    final heading = RegExp(
      r'^\s*(cap[ií]tulo|chapter|parte|part|livro|book)\b.{0,80}$',
      caseSensitive: false,
      unicode: true,
    );

    final result = <MapEntry<String, String>>[];
    var title = 'Texto';
    var body = StringBuffer();

    void flush() {
      final value = clean(body.toString());
      if (value.isNotEmpty) result.add(MapEntry(title, value));
      body = StringBuffer();
    }

    for (final line in lines) {
      if (heading.hasMatch(line.trim())) {
        flush();
        title = line.trim();
      } else {
        body.writeln(line);
      }
    }
    flush();

    if (result.isEmpty && cleaned.isNotEmpty) {
      return [MapEntry('Texto', clean(cleaned))];
    }
    return result;
  }
}
