import 'package:auralis_reader/services/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repara hifenização de quebra de linha sem regex inválida', () {
    expect(TextNormalizer.clean('inter-\nnacional'), 'internacional');
  });

  test('não corta abreviações comuns como frase inteira', () {
    final chunks = TextNormalizer.speechChunks('O Dr. Silva chegou cedo. Depois saiu.');
    expect(chunks.length, 2);
    expect(chunks.first, contains('Dr. Silva'));
  });

  test('divide texto longo em blocos narráveis', () {
    final chunks = TextNormalizer.speechChunks('Olá mundo. Este é outro período!');
    expect(chunks, hasLength(2));
  });

  test('identifica português por heurística', () {
    expect(TextNormalizer.guessLanguage('Este é um texto que foi escrito para uma pessoa.'), 'pt-BR');
  });
}
