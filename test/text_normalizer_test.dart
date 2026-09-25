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

  test('mantém blocos de fala curtos para acompanhamento visual', () {
    final chunks = TextNormalizer.speechChunks(
      'Uma frase curta. Outra frase curta. Esta frase é muito longa, possui uma pausa, continua depois da vírgula, e deve ser dividida de forma legível para acompanhar a narração.',
      maxChars: 70,
    );
    expect(chunks.length, greaterThan(2));
    expect(chunks.every((chunk) => chunk.length <= 70), isTrue);
  });
}
