import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'hesab_database.dart';
import 'migrations/hesab_migrations.dart';

/// Creates and installs complete, validated local database backups.
class DatabaseMaintenanceService {
  DatabaseMaintenanceService(
    this._database, {
    BackupFileInstaller? backupFileInstaller,
  }) : _backupFileInstaller = backupFileInstaller ?? _renameBackupFile;

  final HesabDatabase _database;
  final BackupFileInstaller _backupFileInstaller;

  Future<void> createBackup(String destinationPath) async {
    final destination = File(destinationPath);
    await _rejectDatabasePath(destination.path);
    final partial = await _uniqueSibling(destination, 'partial');
    File? previous;
    try {
      final escapedPath = partial.path.replaceAll("'", "''");
      await (await _database.database).execute("VACUUM INTO '$escapedPath'");
      await _validateBackup(partial.path);

      if (await destination.exists()) {
        previous = await _uniqueSibling(destination, 'previous');
        await destination.rename(previous.path);
      }

      try {
        await _backupFileInstaller(partial, destination.path);
      } on Object catch (promotionError, promotionStack) {
        final heldPrevious = previous;
        if (heldPrevious != null && await heldPrevious.exists()) {
          try {
            // Do not overwrite a file that may have appeared concurrently.
            if (!await destination.exists()) {
              await heldPrevious.rename(destination.path);
              previous = null;
            }
          } on Object catch (rollbackError) {
            Error.throwWithStackTrace(
              FileSystemException(
                'Backup replacement failed ($promotionError); the previous '
                'backup is preserved at ${heldPrevious.path}, but restoring it '
                'to ${destination.path} also failed: $rollbackError',
              ),
              promotionStack,
            );
          }
        }
        Error.throwWithStackTrace(promotionError, promotionStack);
      }

      // The new backup is in place. Failure to remove this extra old copy
      // must not turn a successful replacement into a reported failure.
      if (previous != null && await previous.exists()) {
        try {
          await previous.delete();
        } on FileSystemException {
          // Preserve the old copy if the filesystem will not remove it.
        }
      }
    } finally {
      if (await partial.exists()) {
        try {
          await partial.delete();
        } on FileSystemException {
          // A failed cleanup leaves only the uniquely named temporary file.
        }
      }
    }
  }

  static Future<File> _renameBackupFile(File source, String destination) =>
      source.rename(destination);

  Future<File> _uniqueSibling(File destination, String purpose) async {
    final base =
        '${destination.path}.$pid.${DateTime.now().microsecondsSinceEpoch}';
    var candidate = File('$base.$purpose');
    var suffix = 0;
    while (await candidate.exists()) {
      suffix++;
      candidate = File('$base.$suffix.$purpose');
    }
    return candidate;
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
      final schemaObjects = await database.rawQuery(
        "SELECT type, name FROM sqlite_master "
        "WHERE type IN ('table', 'view')",
      );
      const required = {
        'category',
        'unit',
        'item',
        'wallet',
        'wallet_activity',
        'wallet_transaction',
        'expense',
        'purchase_wallet_allocation',
      };
      final foundTables = schemaObjects
          .where((row) => row['type'] == 'table')
          .map((row) => row['name'] as String)
          .toSet();
      final foundViews = schemaObjects
          .where((row) => row['type'] == 'view')
          .map((row) => row['name'] as String)
          .toSet();
      if (!foundTables.containsAll(required) ||
          !foundViews.contains('wallet_balances')) {
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

/// Installs a completed backup file at its destination.
///
/// Injectable so backup promotion failures can be tested without relying on
/// platform-specific file locking or rename semantics.
typedef BackupFileInstaller = Future<File> Function(
  File source,
  String destinationPath,
);
