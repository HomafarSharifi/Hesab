import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/core/finance/amount_codec.dart';
import 'package:hesab/core/errors/app_failure.dart';

void main() {
  test('parses Dari digits into exact minor units and milli quantities', () {
    expect(AmountCodec.parseMoneyMinor('۱۲۳۴٫۵'), 123450);
    expect(AmountCodec.parseQuantityMilli('۲٫۰۵'), 2050);
    expect(AmountCodec.formatMoneyMinor(123450), '1,234.50');
  });

  test('rejects excess precision', () {
    expect(
      () => AmountCodec.parseMoneyMinor('1.001'),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => AmountCodec.parseQuantityMilli('1.0001'),
      throwsA(isA<AppFailure>()),
    );
  });
}
