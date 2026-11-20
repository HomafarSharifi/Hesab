import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hesab/features/expenses/models/expense_export_models.dart';

import 'package:hesab/features/expenses/widgets/expense_export_dialog.dart';

void main() {
  testWidgets('selection validates refreshed count before returning pages', (
    tester,
  ) async {
    var latestCount = 151;
    ExpenseExportSelection? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<ExpenseExportSelection>(
                  context: context,
                  builder: (_) => ExpenseExportDialog(
                    totalCount: 101,
                    pageSize: 50,
                    filterSummary: 'دسته‌بندی: همه',
                    search: null,
                    categoryName: null,
                    walletId: null,
                    fromDate: DateTime(2025, 1, 1),
                    toDate: null,
                    refreshTotalCount: () async => latestCount,
                  ),
                );
              },
              child: const Text('بازکردن'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('بازکردن'));
    await tester.pumpAndSettle();

    expect(find.text('۳ صفحه، ۱۰۱ مورد'), findsOneWidget);
    expect(find.text('صفحه ۳: ۱۰۱–۱۰۱'), findsOneWidget);

    await tester.tap(find.text('پاک‌کردن انتخاب'));
    await tester.pump();
    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'خروجی گرفتن'),
    );
    expect(confirmButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('export-page-1')));
    await tester.pump();
    expect(find.text('انتخاب‌شده: ۱ صفحه، ۵۰ مورد'), findsOneWidget);

    await tester.tap(find.text('CSV (.csv)'));
    await tester.pump();
    await tester.tap(find.text('خروجی گرفتن'));
    await tester.pumpAndSettle();

    expect(
      find.text('معلومات تازه شد؛ صفحه‌ها و شمارش‌ها را بازبینی کنید.'),
      findsOneWidget,
    );
    expect(find.text('۴ صفحه، ۱۵۱ مورد'), findsOneWidget);
    expect(find.text('صفحه ۴: ۱۵۱–۱۵۱'), findsOneWidget);

    await tester.tap(find.text('خروجی گرفتن'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.format, ExpenseExportFormat.csv);
    expect(result!.pageIndexes, [1]);
    expect(result!.expectedTotalCount, 151);
    expect(result!.pageSize, 50);
  });
}
