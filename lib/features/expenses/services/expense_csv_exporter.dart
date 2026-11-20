import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../data/models/financial_models.dart';
import '../models/expense_export_models.dart';
import 'expense_export_table.dart';

class ExpenseCsvExporter {
  ExpenseExportBundle build({
    required ExpenseExportSelection selection,
    required Map<int, List<ExpenseRecord>> recordsByPage,
  }) {
    if (selection.pageIndexes.isEmpty) {
      throw ArgumentError('At least one expense page must be selected.');
    }

    final pageFiles = <String, Uint8List>{};
    for (final pageIndex in selection.pageIndexes) {
      final records = recordsByPage[pageIndex];
      if (records == null) {
        throw ArgumentError('Missing records for selected page $pageIndex.');
      }
      pageFiles[_pageFileName(pageIndex)] = _encodePage(
        pageIndex: pageIndex,
        pageSize: selection.pageSize,
        records: records,
      );
    }

    if (pageFiles.length == 1) {
      final entry = pageFiles.entries.single;
      return ExpenseExportBundle(fileName: entry.key, bytes: entry.value);
    }

    final archive = Archive();
    for (final entry in pageFiles.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('Could not encode the expense CSV archive.');
    }
    return ExpenseExportBundle(
      fileName: 'hesab_expenses_pages.zip',
      bytes: Uint8List.fromList(zipBytes),
    );
  }

  Uint8List _encodePage({
    required int pageIndex,
    required int pageSize,
    required List<ExpenseRecord> records,
  }) {
    final rows = <List<Object>>[ExpenseExportTable.headers];
    for (var localIndex = 0; localIndex < records.length; localIndex++) {
      rows.add(
        ExpenseExportTable.valuesFor(
          records[localIndex],
          pageIndex * pageSize + localIndex + 1,
        ),
      );
    }
    final csv = rows.map((row) => row.map(_encodeField).join(',')).join('\r\n');
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$csv\r\n')]);
  }

  String _encodeField(Object value) {
    final text = switch (value) {
      final DateTime date =>
        '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
      final String text when _formulaPrefix.hasMatch(text) => "'$text",
      final String text => text,
      _ => value.toString(),
    };
    final escaped = text.replaceAll('"', '""');
    return RegExp(r'[",\r\n]').hasMatch(text) ? '"$escaped"' : escaped;
  }

  String _pageFileName(int pageIndex) =>
      'hesab_expenses_page_${pageIndex + 1}.csv';

  static final _formulaPrefix = RegExp(r'^[\t\r\n ]*[=+\-@]');
}
