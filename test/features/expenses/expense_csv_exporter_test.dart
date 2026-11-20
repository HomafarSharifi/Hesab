import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/data/models/financial_models.dart';
import 'package:hesab/features/expenses/services/expense_csv_exporter.dart';
import 'package:hesab/features/expenses/models/expense_export_models.dart';

void main() {
  test('writes one BOM CSV with escaped Dari text and safe formula fields', () {
    final selection = _selection([1]);
    final bundle = ExpenseCsvExporter().build(
      selection: selection,
      recordsByPage: {
        1: [
          _expense(
            itemName: '=HYPERLINK("https://example.test", "open")',
            note: 'line 1, "quoted"\nخط دوم',
          ),
        ],
      },
    );
    final csv = utf8.decode(bundle.bytes);

    expect(bundle.fileName, 'hesab_expenses_page_2.csv');
    expect(bundle.bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(csv, contains('شماره,تاریخ,جنس'));
    expect(csv, isNot(contains('شناسه')));
    expect(csv, isNot(contains('میلادی')));
    expect(csv, isNot(contains('وضعیت')));
    expect(csv, isNot(contains('برگشت‌شده')));
    expect(csv, contains("'=HYPERLINK("));
    expect(csv, contains('"line 1, ""quoted""\nخط دوم"'));
    expect(csv, contains('\r\n51,'));
    expect(csv, contains('123.45'));
  });

  test('packages selected CSV pages into a ZIP archive', () {
    final bundle = ExpenseCsvExporter().build(
      selection: _selection([0, 2]),
      recordsByPage: {
        0: [_expense(itemName: 'برنج')],
        2: [_expense(itemName: 'روغن')],
      },
    );
    final archive = ZipDecoder().decodeBytes(bundle.bytes);
    final files = {for (final file in archive.files) file.name: file};

    expect(bundle.fileName, 'hesab_expenses_pages.zip');
    expect(files.keys.toSet(), {
      'hesab_expenses_page_1.csv',
      'hesab_expenses_page_3.csv',
    });
    expect(
      utf8.decode(files['hesab_expenses_page_3.csv']!.content as List<int>),
      contains('\r\n101,'),
    );
  });
}

ExpenseExportSelection _selection(List<int> pages) => ExpenseExportSelection(
  format: ExpenseExportFormat.csv,
  pageIndexes: pages,
  pageSize: 50,
  expectedTotalCount: 237,
  search: null,
  categoryName: null,
  walletId: null,
  fromDate: DateTime(2024, 1, 1),
  toDate: null,
);

ExpenseRecord _expense({required String itemName, String? note}) =>
    ExpenseRecord(
      id: 22,
      transactionId: 122,
      walletId: 1,
      walletName: 'کیف پول',
      date: '2024-03-20',
      amountMinor: 12345,
      itemId: 222,
      itemName: itemName,
      categoryName: 'خوراکه',
      unitName: 'کیلوگرام',
      quantityCenti: 250,
      unitPriceMinor: 5000,
      isReversed: true,
      note: note,
    );
