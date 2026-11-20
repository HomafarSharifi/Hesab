import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/expense_export_models.dart';

class ExpenseExportFileSaver {
  ExpenseExportFileSaver({ExportSaveLocationPicker? pickLocation})
    : _pickLocation = pickLocation ?? _pickNativeLocation;

  final ExportSaveLocationPicker _pickLocation;

  Future<bool> save(ExpenseExportBundle bundle) async {
    final path = await _pickLocation(bundle.fileName, bundle.extension);
    if (path == null) return false;

    final targetPath = path.toLowerCase().endsWith('.${bundle.extension}')
        ? path
        : '$path.${bundle.extension}';
    await File(targetPath)
        .writeAsBytes(Uint8List.fromList(bundle.bytes), flush: true);
    return true;
  }

  static Future<String?> _pickNativeLocation(
    String fileName,
    String extension,
  ) => FilePicker.platform.saveFile(
    dialogTitle: 'خروجی گرفتن مصارف',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: [extension],
    lockParentWindow: true,
  );
}

typedef ExportSaveLocationPicker = Future<String?> Function(
  String fileName,
  String extension,
);
