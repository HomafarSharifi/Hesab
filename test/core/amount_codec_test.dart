import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/core/finance/amount_codec.dart';
import 'package:hesab/core/errors/app_failure.dart';

void main() {
  test('parses Dari digits into exact minor units and centi quantities', () {
    expect(AmountCodec.parseMoneyMinor('۱۲۳۴٫۵'), 123450);
    expect(AmountCodec.parseQuantityCenti('۲٫۰۵'), 205);
    expect(AmountCodec.parseQuantityCenti('2'), 200);
    expect(AmountCodec.formatMoneyMinor(123400), '1,234 ؋');
    expect(AmountCodec.formatMoneyMinor(123450), '1,234.5 ؋');
    expect(AmountCodec.formatQuantityCenti(200), '2');
    expect(AmountCodec.formatQuantityCenti(205), '2.05');
  });

  test('rejects excess precision', () {
    expect(
      () => AmountCodec.parseMoneyMinor('1.001'),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => AmountCodec.parseQuantityCenti('1.0001'),
      throwsA(isA<AppFailure>()),
    );
  });
}
