import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'migrations/hesab_migrations.dart';

/// Owns Hesab's single local database connection.
///
/// Repositories should receive [database] through their constructors. UI
/// widgets must not import this class or issue SQL queries directly.
class HesabDatabase {
  HesabDatabase._();

  static final HesabDatabase instance = HesabDatabase._();

  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    try {
      sqfliteFfiInit();

      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null || localAppData.isEmpty) {
        throw StateError('Windows LOCALAPPDATA is not available.');
      }
      final databaseDirectory = Directory(
        '$localAppData${Platform.pathSeparator}Hesab',
      );
      await databaseDirectory.create(recursive: true);

      final databasePath =
          '${databaseDirectory.path}${Platform.pathSeparator}hesab.sqlite3';

      return await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: HesabMigrations.currentVersion,
          onConfigure: _configure,
          onCreate: HesabMigrations.onCreate,
          onUpgrade: HesabMigrations.onUpgrade,
        ),
      );
    } on Object {
      // Do not retain a failed Future: callers can retry after fixing a
      // filesystem or database problem.
      _opening = null;
      rethrow;
    }
  }

  Future<void> _configure(Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
    final rows = await database.rawQuery('PRAGMA foreign_keys');
    final enabled = rows.isNotEmpty && rows.first.values.first == 1;
    if (!enabled) {
      throw StateError('SQLite foreign key enforcement could not be enabled.');
    }
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) {
      await (await opening).close();
    }
  }
}
