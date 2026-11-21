import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'hesab_database.dart';
import 'migrations/hesab_migrations.dart';

/// Creates and installs complete, validated local database backups.
class DatabaseMaintenanceService {
  DatabaseMaintenanceService(this._database);

  final HesabDatabase _database;

  Future<void> createBackup(String destinationPath) async {
    final destination = File(destinationPath);
    await _rejectDatabasePath(destination.path);
    final partial = File('$destinationPath.partial');
    if (await partial.exists()) await partial.delete();
    final escapedPath = partial.path.replaceAll("'", "''");
    await (await _database.database).execute("VACUUM INTO '$escapedPath'");
    if (await destination.exists()) await destination.delete();
    await partial.rename(destinationPath);
  }

  Future<void> clear() async {
    final path = await _database.path;
    final original = File(path);
    final rollback = File('$path.rollback');
    await _database.close();
    try {
      if (await rollback.exists()) await rollback.delete();
      if (await original.exists()) await original.copy(rollback.path);
      await _removeSidecars(path);
      if (await original.exists()) await original.delete();
      await _database.database;
      if (await rollback.exists()) await rollback.delete();
    } on Object {
      await _database.close();
      await _removeSidecars(path);
      if (await rollback.exists()) {
        if (await original.exists()) await original.delete();
        await rollback.rename(path);
      }
      rethrow;
    }
  }

  Future<void> restore(String sourcePath) async {
    await _rejectDatabasePath(sourcePath);
    await _validateBackup(sourcePath);
    final path = await _database.path;
    final original = File(path);
    final rollback = File('$path.rollback');
    final staging = File('$path.restore');

    await _database.close();
    try {
      if (await rollback.exists()) await rollback.delete();
      if (await original.exists()) await original.rename(rollback.path);
      await _removeSidecars(path);
      if (await staging.exists()) await staging.delete();
      await File(sourcePath).copy(staging.path);
      await staging.rename(path);
      await _database.database;
      if (await rollback.exists()) await rollback.delete();
    } on Object {
      await _database.close();
      await _removeSidecars(path);
      if (await original.exists()) await original.delete();
      if (await rollback.exists()) await rollback.rename(path);
      if (await staging.exists()) await staging.delete();
      rethrow;
    }
  }

  Future<void> _rejectDatabasePath(String candidate) async {
    final databasePath = await _database.path;
    final normalizedCandidate = File(candidate).absolute.path.toLowerCase();
    final normalizedDatabase = File(databasePath).absolute.path.toLowerCase();
    if (normalizedCandidate == normalizedDatabase) {
      throw const FormatException(
        'Choose a separate file for backup or restoration.',
      );
    }
  }

  Future<void> _validateBackup(String path) async {
    final file = File(path);
    if (!await file.exists() || await file.length() < 100) {
      throw const FormatException('Backup file is missing or too small.');
    }

    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final version = await database.getVersion();
      if (version != HesabMigrations.currentVersion) {
        throw FormatException('Unsupported Hesab backup version: $version.');
      }
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      const required = {
        'category',
        'unit',
        'item',
        'wallet',
        'wallet_activity',
        'wallet_transaction',
        'expense',
      };
      final found = tables.map((row) => row['name'] as String).toSet();
      if (!found.containsAll(required)) {
        throw const FormatException('Backup does not contain Hesab data.');
      }
      final violations = await database.rawQuery('PRAGMA foreign_key_check');
      if (violations.isNotEmpty) {
        throw const FormatException('Backup contains invalid relationships.');
      }
      final integrity = await database.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const FormatException('Backup integrity check failed.');
      }
    } finally {
      await database.close();
    }
  }

  Future<void> _removeSidecars(String path) async {
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('$path$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
  }
}
