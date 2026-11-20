import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/features/expenses/services/expense_export_file_saver.dart';
import 'package:hesab/features/expenses/models/expense_export_models.dart';

void main() {
  test(
    'writes bytes after a path is chosen and adds the required extension',
    () async {
      final directory = await Directory.systemTemp.createTemp('hesab-export-');
      addTearDown(() => directory.delete(recursive: true));
      final pathWithoutExtension =
          '${directory.path}${Platform.pathSeparator}report';
      final bundle = ExpenseExportBundle(
        fileName: 'report.xlsx',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final saver = ExpenseExportFileSaver(
        pickLocation: (_, _) async => pathWithoutExtension,
      );

      expect(await saver.save(bundle), isTrue);
      expect(await File('$pathWithoutExtension.xlsx').readAsBytes(), [1, 2, 3]);
    },
  );

  test('cancelled save does not create a file', () async {
    final directory = await Directory.systemTemp.createTemp('hesab-export-');
    addTearDown(() => directory.delete(recursive: true));
    final saver = ExpenseExportFileSaver(pickLocation: (_, _) async => null);

    expect(
      await saver.save(
        ExpenseExportBundle(
          fileName: 'cancelled.csv',
          bytes: Uint8List.fromList([1]),
        ),
      ),
      isFalse,
    );
    expect(directory.listSync(), isEmpty);
  });

  test('reports a file-writing failure instead of claiming success', () async {
    final directory = await Directory.systemTemp.createTemp('hesab-export-');
    addTearDown(() => directory.delete(recursive: true));
    final missingParent = '${directory.path}${Platform.pathSeparator}missing';
    final saver = ExpenseExportFileSaver(
      pickLocation: (_, _) async =>
          '$missingParent${Platform.pathSeparator}file.csv',
    );

    await expectLater(
      saver.save(
        ExpenseExportBundle(
          fileName: 'file.csv',
          bytes: Uint8List.fromList([1, 2]),
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
