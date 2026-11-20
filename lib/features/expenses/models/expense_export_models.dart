import 'dart:typed_data';

enum ExpenseExportFormat { excel, csv }

class ExpenseExportSelection {
  ExpenseExportSelection({
    required this.format,
    required List<int> pageIndexes,
    required this.pageSize,
    required this.expectedTotalCount,
    required this.search,
    required this.categoryName,
    required this.walletId,
    required this.fromDate,
    required this.toDate,
  }) : pageIndexes = List.unmodifiable(pageIndexes);

  final ExpenseExportFormat format;
  final List<int> pageIndexes;
  final int pageSize;
  final int expectedTotalCount;
  final String? search;
  final String? categoryName;
  final int? walletId;
  final DateTime fromDate;
  final DateTime? toDate;
}

class ExpenseExportBundle {
  const ExpenseExportBundle({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  String get extension => fileName.split('.').last;
}
