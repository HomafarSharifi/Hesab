import '../errors/app_failure.dart';

class AmountCodec {
  const AmountCodec._();

  static const int maximumMinorUnits = 9999999999;
  static const int maximumQuantityMilli = 99999999999;

  static int parseMoneyMinor(String input) {
    final value = _asciiDigits(input)
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll('٫', '.');
    if (!RegExp(r'^\d+(?:\.\d{0,2})?$').hasMatch(value)) {
      throw const AppFailure('مبلغ را با حداکثر دو رقم اعشار وارد کنید.');
    }
    final parts = value.split('.');
    final whole = BigInt.parse(parts[0]);
    final fraction = parts.length == 1 ? '' : parts[1];
    final minor =
        whole * BigInt.from(100) + BigInt.parse(fraction.padRight(2, '0'));
    if (minor <= BigInt.zero || minor > BigInt.from(maximumMinorUnits)) {
      throw const AppFailure('مبلغ باید بیشتر از صفر و در محدوده مجاز باشد.');
    }
    return minor.toInt();
  }

  static int parseQuantityMilli(String input) {
    final value = _asciiDigits(input)
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll('٫', '.');
    if (!RegExp(r'^\d+(?:\.\d{0,3})?$').hasMatch(value)) {
      throw const AppFailure('مقدار را با حداکثر سه رقم اعشار وارد کنید.');
    }
    final parts = value.split('.');
    final whole = BigInt.parse(parts[0]);
    final fraction = parts.length == 1 ? '' : parts[1];
    final milli =
        whole * BigInt.from(1000) + BigInt.parse(fraction.padRight(3, '0'));
    if (milli <= BigInt.zero || milli > BigInt.from(maximumQuantityMilli)) {
      throw const AppFailure('مقدار باید بیشتر از صفر و در محدوده مجاز باشد.');
    }
    return milli.toInt();
  }

  static String formatMoneyMinor(int minor) {
    final value = BigInt.from(minor).abs();
    final whole = value ~/ BigInt.from(100);
    final fraction = (value % BigInt.from(100)).toString().padLeft(2, '0');
    final grouped = _groupDigits(whole.toString());
    return '${minor < 0 ? '−' : ''}$grouped.$fraction';
  }

  static String formatQuantityMilli(int milli) {
    final value = BigInt.from(milli).abs();
    final whole = value ~/ BigInt.from(1000);
    final fraction = (value % BigInt.from(1000)).toString().padLeft(3, '0');
    return '${milli < 0 ? '−' : ''}${_groupDigits(whole.toString())}.$fraction';
  }

  static int calculatePurchaseTotalMinor({
    required int quantityMilli,
    required int unitPriceMinor,
  }) {
    if (quantityMilli <= 0 || quantityMilli > maximumQuantityMilli) {
      throw const AppFailure('مقدار باید بیشتر از صفر و در محدوده مجاز باشد.');
    }
    if (unitPriceMinor <= 0 || unitPriceMinor > maximumMinorUnits) {
      throw const AppFailure('قیمت باید بیشتر از صفر و در محدوده مجاز باشد.');
    }
    final product = BigInt.from(quantityMilli) * BigInt.from(unitPriceMinor);
    final total = (product + BigInt.from(500)) ~/ BigInt.from(1000);
    if (total <= BigInt.zero || total > BigInt.from(maximumMinorUnits)) {
      throw const AppFailure('مجموع خرید در محدوده مجاز نیست.');
    }
    return total.toInt();
  }

  static String _asciiDigits(String input) =>
      input.replaceAllMapped(RegExp(r'[0-9٠-٩۰-۹]'), (match) {
        final code = match.group(0)!.runes.single;
        if (code >= 0x0660 && code <= 0x0669) {
          return String.fromCharCode(code - 0x0660 + 0x30);
        }
        if (code >= 0x06F0 && code <= 0x06F9) {
          return String.fromCharCode(code - 0x06F0 + 0x30);
        }
        return match.group(0)!;
      });

  static String _groupDigits(String input) =>
      input.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
