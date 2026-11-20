import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/data/models/financial_models.dart';
import 'package:hesab/features/expenses/services/expense_excel_exporter.dart';
import 'package:hesab/features/expenses/models/expense_export_models.dart';

void main() {
  test('builds one typed worksheet per selected page with continuous rows', () {
    final selection = ExpenseExportSelection(
      format: ExpenseExportFormat.excel,
      pageIndexes: [1, 4],
      pageSize: 50,
      expectedTotalCount: 237,
      search: null,
      categoryName: null,
      walletId: null,
      fromDate: DateTime(2025, 1, 1),
      toDate: null,
    );
    final recordsByPage = {
      1: [_expense(id: 22, amountMinor: 12345)],
      4: [_expense(id: 23, amountMinor: 500)],
    };

    final bytes = ExpenseExcelExporter().buildWorkbook(
      selection: selection,
      recordsByPage: recordsByPage,
    );
    final workbook = Excel.decodeBytes(bytes);

    expect(workbook.tables.keys.toList(), ['Page 2', 'Page 5']);
    final secondPage = workbook['Page 2'];
    expect(secondPage.rows, hasLength(2));
    expect(secondPage.rows[1], hasLength(10));
    expect(secondPage.rows[0][0]?.value, isA<TextCellValue>());
    expect(secondPage.rows[1][0]?.value, isA<IntCellValue>());
    expect((secondPage.rows[1][0]!.value as IntCellValue).value, 51);
    final headers = secondPage.rows[0]
        .map((cell) => (cell!.value as TextCellValue).value.text!)
        .toList();
    expect(headers, hasLength(10));
    expect(headers.any((header) => header.contains('شناسه')), isFalse);
    expect(headers.any((header) => header.contains('میلادی')), isFalse);
    expect(
      (secondPage.rows[1][1]!.value as TextCellValue).value.text,
      '۱ حمل ۱۴۰۳',
    );
    expect(_numberValue(secondPage.rows[1][5]!.value), 2.5);
    expect(_numberValue(secondPage.rows[1][7]!.value), 50.0);
    expect(_numberValue(secondPage.rows[1][8]!.value), 123.45);
    expect((secondPage.rows[1][9]!.value as TextCellValue).value.text, '');
    expect(headers.any((header) => header.contains('وضعیت')), isFalse);

    final fifthPage = workbook['Page 5'];
    expect((fifthPage.rows[1][0]!.value as IntCellValue).value, 201);
  });
}

num _numberValue(CellValue? value) => switch (value) {
  IntCellValue(:final value) => value,
  DoubleCellValue(:final value) => value,
  _ => throw StateError('Expected an Excel numeric cell, got $value.'),
};

ExpenseRecord _expense({required int id, required int amountMinor}) =>
    ExpenseRecord(
      id: id,
      transactionId: id + 100,
      walletId: 1,
      walletName: 'کیف پول',
      date: '2024-03-20',
      amountMinor: amountMinor,
      itemId: id + 200,
      itemName: 'برنج',
      categoryName: 'خوراکه',
      unitName: 'کیلوگرام',
      quantityCenti: 250,
      unitPriceMinor: 5000,
      isReversed: true,
    );
