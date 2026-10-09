class TextNormalizer {
  static final RegExp _letter = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]');
  static final Set<String> _abbreviations = <String>{
    'sr.', 'sra.', 'srta.', 'dr.', 'dra.', 'prof.', 'profa.', 'etc.', 'ex.',
    'mr.', 'mrs.', 'ms.', 'st.', 'vs.', 'e.g.', 'i.e.',
    'p.', 'pp.', 'vol.', 'cap.', 'fig.', 'nº', 'no.',
  };

  static String clean(String input) {
    var text = input
        .replaceAll('\u00ad', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    text = text.replaceAllMapped(
      RegExp(r'([A-Za-zÀ-ÖØ-öø-ÿ])-\s*\n\s*([A-Za-zÀ-ÖØ-öø-ÿ])'),
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

  static List<String> speechChunks(String input, {int maxChars = 260}) {
    final text = clean(input);
    if (text.isEmpty) return const [];

    final sentences = _splitSentences(text);
    final chunks = <String>[];
    for (final sentence in sentences) {
      if (sentence.length <= maxChars) {
        chunks.add(sentence);
      } else {
        chunks.addAll(_splitLongSentence(sentence, maxChars));
      }
    }
    return chunks.isEmpty ? _hardSplit(text, maxChars) : chunks;
  }

  static List<String> _splitSentences(String text) {
    final out = <String>[];
    final current = StringBuffer();

    bool isSentenceEnd(int index) {
      final ch = text[index];
      if (!'.!?…'.contains(ch)) return false;
      if (ch == '.' && index > 0 && index + 1 < text.length) {
        final prev = text[index - 1];
        final next = text[index + 1];
        if (RegExp(r'\d').hasMatch(prev) && RegExp(r'\d').hasMatch(next)) return false;
      }
      final candidate = current.toString().trim().toLowerCase();
      final last = candidate.split(RegExp(r'\s+')).lastOrNull ?? '';
      if (_abbreviations.contains(last)) return false;
      if (last.length == 2 && last.endsWith('.') && _letter.hasMatch(last[0])) return false;
      return true;
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      current.write(ch);
      if (isSentenceEnd(i)) {
        var j = i + 1;
        while (j < text.length && '”"’)]'.contains(text[j])) {
          current.write(text[j]);
          i = j;
          j++;
        }
        final value = current.toString().trim();
        if (value.isNotEmpty) out.add(value);
        current.clear();
      }
    }
    final tail = current.toString().trim();
    if (tail.isNotEmpty) out.add(tail);
    return out;
  }

  static List<String> _splitLongSentence(String sentence, int maxChars) {
    final clauses = RegExp(r'[^,;:—–]+(?:[,;:—–]+|$)')
        .allMatches(sentence)
        .map((m) => m.group(0)!.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (clauses.length <= 1) return _hardSplit(sentence, maxChars);

    final result = <String>[];
    var current = StringBuffer();
    void flush() {
      final value = current.toString().trim();
      if (value.isNotEmpty) result.add(value);
      current = StringBuffer();
    }

    for (final clause in clauses) {
      if (clause.length > maxChars) {
        flush();
        result.addAll(_hardSplit(clause, maxChars));
        continue;
      }
      if (current.isNotEmpty && current.length + clause.length + 1 > maxChars) flush();
      if (current.isNotEmpty) current.write(' ');
      current.write(clause);
    }
    flush();
    return result;
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
      'pt-BR': [' de ', ' que ', ' não ', ' para ', ' uma ', ' com ', ' os ', ' as ', ' por '],
      'en-US': [' the ', ' and ', ' that ', ' with ', ' from ', ' this ', ' was ', ' are ', ' of '],
      'es-ES': [' que ', ' de ', ' para ', ' una ', ' los ', ' las ', ' con ', ' por ', ' el '],
      'fr-FR': [' le ', ' la ', ' les ', ' des ', ' une ', ' que ', ' dans ', ' avec ', ' et '],
      'de-DE': [' der ', ' die ', ' das ', ' und ', ' ist ', ' mit ', ' ein ', ' nicht ', ' von '],
      'it-IT': [' che ', ' di ', ' la ', ' il ', ' una ', ' con ', ' per ', ' non ', ' e '],
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
    final cleaned = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final lines = cleaned.split('\n');
    final heading = RegExp(
      r'^\s*(cap[ií]tulo|chapter|parte|part|livro|book)\b.{0,80}$',
      caseSensitive: false,
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
    if (result.isEmpty && cleaned.isNotEmpty) return [MapEntry('Texto', clean(cleaned))];
    return result;
  }
}

