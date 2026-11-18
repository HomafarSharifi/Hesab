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
    expect(find.text('حمل ۱۴۰۳'), findsOneWidget);
    expect(find.textContaining('۱ حمل ۱۴۰۳'), findsOneWidget);

    await tester.tap(find.text('۲'));
    await tester.pumpAndSettle();
    expect(find.textContaining('۲ حمل ۱۴۰۳'), findsOneWidget);
    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();

    expect(result, DateTime(2024, 3, 21));
  });
}
