import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../../data/models/financial_models.dart';
import '../models/expense_export_models.dart';
import 'expense_export_table.dart';

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
    const headers = ExpenseExportTable.headers;
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
      final rowValues = ExpenseExportTable.valuesFor(
        expense,
        pageIndex * pageSize + localIndex + 1,
      );
      sheet.appendRow(rowValues.map(_cellValue).toList());
      final rowIndex = localIndex + 1;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .cellStyle = CellStyle(
        numberFormat: CustomNumericNumFormat(formatCode: '#,##0.##'),
      );
      for (final column in [7, 8]) {
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

    const widths = <double>[10, 16, 24, 20, 20, 14, 14, 22, 20, 30, 18];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
  }

  String _sheetName(int pageIndex) => 'Page ${pageIndex + 1}';

  CellValue _cellValue(Object value) => switch (value) {
    final String text => TextCellValue(text),
    final int integer => IntCellValue(integer),
    final double decimal => DoubleCellValue(decimal),
    _ => TextCellValue(value.toString()),
  };
}
