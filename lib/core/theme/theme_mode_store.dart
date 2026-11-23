import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Stores an explicit theme choice separately from the financial database.
class ThemeModeStore {
  const ThemeModeStore();

  Future<File> _file() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) {
      throw StateError('Windows LOCALAPPDATA is not available.');
    }
    final directory = Directory('$localAppData${Platform.pathSeparator}Hesab');
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}theme_mode');
  }

  Future<ThemeMode?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return switch ((await file.readAsString()).trim()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => null,
    };
  }

  Future<void> save(ThemeMode mode) async {
    if (mode == ThemeMode.system) return;
    final file = await _file();
    await file.writeAsString(mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
