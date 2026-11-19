import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../../core/calendar/jalali_date.dart';
import '../../../data/models/financial_models.dart';
import '../widgets/expense_export_dialog.dart';

class ExpenseExcelExporter {
  Uint8List buildWorkbook({
    required ExpenseExportSelection selection,
    required Map<int, List<ExpenseRecord>> recordsByPage,
  }) {
    if (selection.pageIndexes.isEmpty) {
      throw ArgumentError('At least one expense page must be selected.');
    }

    final workbook = Excel.createExcel();
    final firstPage = selection.pageIndexes.first;
    final firstSheetName = _sheetName(firstPage);
    workbook.rename('Sheet1', firstSheetName);

    for (final pageIndex in selection.pageIndexes) {
      final records = recordsByPage[pageIndex];
      if (records == null) {
        throw ArgumentError('Missing records for selected page $pageIndex.');
      }
      final sheet = pageIndex == firstPage
          ? workbook[firstSheetName]
          : workbook[_sheetName(pageIndex)];
      _writePage(sheet, pageIndex, selection.pageSize, records);
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('Could not encode the expense workbook.');
    }
    return Uint8List.fromList(bytes);
  }

  void _writePage(
    Sheet sheet,
    int pageIndex,
    int pageSize,
    List<ExpenseRecord> records,
  ) {
    final headers = <String>[
      'شماره',
      'تاریخ',
      'تاریخ میلادی',
      'جنس',
      'دسته‌بندی',
      'کیف پول',
      'مقدار',
      'واحد',
      'قیمت فی واحد (AFN)',
      'مجموع (AFN)',
      'یادداشت',
      'وضعیت',
      'شناسه خرید',
      'شناسه مصرف',
      'شناسه کیف پول',
      'شناسه جنس',
    ];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (var column = 0; column < headers.length; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
      );
    }

    for (var localIndex = 0; localIndex < records.length; localIndex++) {
      final expense = records[localIndex];
      final gregorianDate = DateTime.parse(expense.date);
      sheet.appendRow([
        IntCellValue(pageIndex * pageSize + localIndex + 1),
        TextCellValue(JalaliDate.fromGregorian(gregorianDate).fullDate),
        DateCellValue(
          year: gregorianDate.year,
          month: gregorianDate.month,
          day: gregorianDate.day,
        ),
        TextCellValue(expense.itemName),
        TextCellValue(expense.categoryName),
        TextCellValue(expense.walletName),
        DoubleCellValue(expense.quantityCenti / 100),
        TextCellValue(expense.unitName),
        DoubleCellValue(expense.unitPriceMinor / 100),
        DoubleCellValue(expense.amountMinor / 100),
        TextCellValue(expense.note ?? ''),
        TextCellValue(expense.isReversed ? 'برگشت‌شده' : 'تکمیل‌شده'),
        IntCellValue(expense.transactionId),
        IntCellValue(expense.id),
        IntCellValue(expense.walletId),
        IntCellValue(expense.itemId),
      ]);
      final rowIndex = localIndex + 1;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .cellStyle = CellStyle(
        numberFormat: CustomNumericNumFormat(formatCode: '#,##0.##'),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .cellStyle = CellStyle(
        numberFormat: CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd'),
      );
      for (final column in [8, 9]) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: rowIndex,
              ),
            )
            .cellStyle = CellStyle(
          numberFormat: CustomNumericNumFormat(formatCode: '#,##0.00'),
        );
      }
    }

    const widths = <double>[
      10,
      16,
      18,
      24,
      20,
      20,
      14,
      14,
      22,
      20,
      30,
      18,
      16,
      16,
      18,
      16,
    ];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
  }

  String _sheetName(int pageIndex) => 'Page ${pageIndex + 1}';
}
