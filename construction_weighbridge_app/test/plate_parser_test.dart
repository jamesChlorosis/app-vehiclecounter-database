import 'package:flutter_test/flutter_test.dart';
import 'package:construction_weighbridge_app/src/services/plate_parser.dart';

void main() {
  test('extracts compact Indian plate numbers', () {
    expect(PlateParser.extract('KL10AD868'), 'KL10AD868');
  });

  test('extracts spaced Indian plate numbers', () {
    expect(PlateParser.extract('KL 10 AD 868'), 'KL10AD868');
  });

  test('corrects common OCR mistakes in number groups', () {
    expect(PlateParser.extract('KL IO AD 86B'), 'KL10AD868');
  });

  test('ignores unrelated OCR text', () {
    expect(PlateParser.extract('SAND 20MM CASH'), isNull);
  });
}
