import 'package:auralis_reader/services/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repara hifenização de quebra de linha', () {
    expect(TextNormalizer.clean('pala-\nvra'), 'palavra');
    expect(TextNormalizer.clean('informa-\nção'), 'informação');
  });

  test('divide texto em blocos de fala', () {
    final chunks = TextNormalizer.speechChunks('Primeira frase. Segunda frase! Terceira?');
    expect(chunks, isNotEmpty);
    expect(chunks.join(' '), contains('Segunda frase'));
  });

  test('identifica português por heurística', () {
    expect(TextNormalizer.guessLanguage('Esta é uma história que foi escrita para as pessoas e com muito cuidado.'), 'pt-BR');
  });
}
