import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hesab/features/shared/widgets/jalali_date_picker_dialog.dart';

void main() {
  testWidgets('selects a precise Jalali date and confirms it as Gregorian', (
    tester,
  ) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showJalaliDatePicker(
                  context,
                  initialDate: DateTime(2024, 3, 20),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('حمل 1403'), findsOneWidget);
    expect(find.textContaining('1 حمل 1403'), findsOneWidget);

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 حمل 1403'), findsOneWidget);
    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();

    expect(result, DateTime(2024, 3, 21));
  });

  test('JalaliDateInputFormatter automatically separates year, month, and day with hyphens', () {
    final formatter = JalaliDateInputFormatter();

    TextEditingValue format(String oldText, String newText) {
      return formatter.formatEditUpdate(
        TextEditingValue(text: oldText),
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        ),
      );
    }

    // Typing digits step by step
    expect(format('', '1403').text, '1403');
    expect(format('1403', '14030').text, '1403-0');
    expect(format('1403-0', '1403-08').text, '1403-08');
    expect(format('1403-08', '1403-081').text, '1403-08-1');
    expect(format('1403-08-1', '1403-08-15').text, '1403-08-15');

    // Persian digits normalization
    expect(format('', '۱۴۰۳۰۸۱۵').text, '1403-08-15');

    // Backspacing over hyphen deletes character before hyphen as well
    final backspacedFromMonth = formatter.formatEditUpdate(
      const TextEditingValue(text: '1403-08-'),
      const TextEditingValue(
        text: '1403-08',
        selection: TextSelection.collapsed(offset: 7),
      ),
    );
    expect(backspacedFromMonth.text, '1403-0');

    final backspacedFromYear = formatter.formatEditUpdate(
      const TextEditingValue(text: '1403-'),
      const TextEditingValue(
        text: '1403',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    expect(backspacedFromYear.text, '140');
  });

  testWidgets('jumps to a specific Jalali date via date input dialog', (
    tester,
  ) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showJalaliDatePicker(
                  context,
                  initialDate: DateTime(2024, 3, 20),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap header month/year to open date input dialog
    await tester.tap(find.text('حمل 1403'));
    await tester.pumpAndSettle();

    expect(find.text('رفتن به تاریخ جلالی'), findsOneWidget);

    // Enter a new date e.g. 1403-08-15 (15 Aqrab 1403 = Nov 5, 2024)
    final textField = find.byType(TextField);
    await tester.enterText(textField, '14030815');
    await tester.pumpAndSettle();

    expect(find.text('1403-08-15'), findsOneWidget);

    await tester.tap(find.text('رفتن'));
    await tester.pumpAndSettle();

    // Verify calendar updated to Aqrab 1403 and selected day is 15
    expect(find.text('عقرب 1403'), findsOneWidget);
    expect(find.textContaining('15 عقرب 1403'), findsOneWidget);

    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();

    expect(result, DateTime(2024, 11, 5));
  });
}
