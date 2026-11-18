import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/core/text/name_normalizer.dart';

void main() {
  test('normalizes Arabic forms, digits, marks and spacing', () {
    expect(NameNormalizer.normalize(' كِتاب  ۱۲٣ '), 'کتاب 123');
    expect(NameNormalizer.normalize('ي‌ك'), 'یک');
  });

  test('suggests close Dari names without duplicates', () {
    expect(NameNormalizer.suggestions('برنج', ['برنج', 'برنج', 'روغن']), [
      'برنج',
    ]);
  });
}
