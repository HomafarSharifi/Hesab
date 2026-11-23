import 'package:flutter/services.dart';

/// Formats money as it is typed while keeping the decimal portion editable.
class GroupedAmountInputFormatter extends TextInputFormatter {
  const GroupedAmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset
              .clamp(0, newValue.text.length)
              .toInt()
        : newValue.text.length;
    final beforeCursor = _clean(newValue.text.substring(0, cursor));
    final cleaned = _clean(newValue.text);
    final parts = cleaned.split('.');
    final whole = parts.first;
    final fraction = parts.length > 1 ? parts[1] : null;
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final formatted = fraction == null ? grouped : '$grouped.$fraction';

    final cursorLogicalOffset = beforeCursor.length;
    var mappedCursor = 0;
    var logicalOffset = 0;
    while (mappedCursor < formatted.length && logicalOffset < cursorLogicalOffset) {
      if (formatted[mappedCursor] != ',') logicalOffset++;
      mappedCursor++;
    }
    while (mappedCursor < formatted.length && formatted[mappedCursor] == ',') {
      mappedCursor++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: mappedCursor),
      composing: TextRange.empty,
    );
  }

  String _clean(String value) {
    final normalized = value
        .replaceAll('٬', ',')
        .replaceAll('٫', '.')
        .replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
          final code = match.group(0)!.runes.single;
          final start = code >= 0x06F0 ? 0x06F0 : 0x0660;
          return String.fromCharCode(code - start + 0x30);
        });
    final output = StringBuffer();
    var decimalSeen = false;
    var decimalDigits = 0;
    for (final rune in normalized.runes) {
      final character = String.fromCharCode(rune);
      if (character == '.' && !decimalSeen) {
        decimalSeen = true;
        output.write(character);
      } else if (rune >= 0x30 && rune <= 0x39) {
        if (!decimalSeen || decimalDigits < 2) {
          output.write(character);
          if (decimalSeen) decimalDigits++;
        }
      }
    }
    return output.toString();
  }
}
