import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/data/database/database_maintenance_service.dart';
import 'package:hesab/data/database/hesab_database.dart';
import 'package:hesab/data/repositories/catalog_repository.dart';
import 'package:hesab/domain/services/catalog_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates a new backup', () async {
    final fixture = await _createBackupFixture();
    addTearDown(() async {
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });

    final service = DatabaseMaintenanceService(fixture.database);
    await service.createBackup(fixture.backupPath);

    expect(await File(fixture.backupPath).exists(), isTrue);
    expect(await _backupCategoryNames(fixture.backupPath), ['داده نخست']);
    expect(await _backupTemporaryFiles(fixture), isEmpty);
  });

  test('replaces an existing backup with the new snapshot', () async {
    final fixture = await _createBackupFixture();
    addTearDown(() async {
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });
    final service = DatabaseMaintenanceService(fixture.database);

    await service.createBackup(fixture.backupPath);
    await _addCategory(fixture.database, 'داده دوم');
    await service.createBackup(fixture.backupPath);

    expect(await _backupCategoryNames(fixture.backupPath), [
      'داده نخست',
      'داده دوم',
    ]);
    expect(await _backupTemporaryFiles(fixture), isEmpty);
  });

  test(
    'preserves the existing backup and cleans staging after promotion fails',
    () async {
      final fixture = await _createBackupFixture();
      addTearDown(() async {
        await fixture.database.close();
        await fixture.directory.delete(recursive: true);
      });
      final service = DatabaseMaintenanceService(fixture.database);
      await service.createBackup(fixture.backupPath);
      final previousBytes = await File(fixture.backupPath).readAsBytes();
      await _addCategory(fixture.database, 'داده تازه');

      final failingService = DatabaseMaintenanceService(
        fixture.database,
        backupFileInstaller: (source, destinationPath) async {
          throw FileSystemException('Simulated promotion failure', source.path);
        },
      );
      await expectLater(
        failingService.createBackup(fixture.backupPath),
        throwsA(isA<FileSystemException>()),
      );

      expect(await File(fixture.backupPath).readAsBytes(), previousBytes);
      expect(await _backupCategoryNames(fixture.backupPath), ['داده نخست']);
      expect(await _backupTemporaryFiles(fixture), isEmpty);
    },
  );

  test(
    'restore replaces the database with data from its backup file',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('hesab-restore-');
      addTearDown(() => directory.delete(recursive: true));

      final backupDatabase = HesabDatabase.atPath(
        '${directory.path}${Platform.pathSeparator}backup-source.sqlite3',
      );
      final activeDatabase = HesabDatabase.atPath(
        '${directory.path}${Platform.pathSeparator}active.sqlite3',
      );
      addTearDown(backupDatabase.close);
      addTearDown(activeDatabase.close);

      final backupCatalog = CatalogService(
        CatalogRepository(await backupDatabase.database),
      );
      await backupCatalog.createCategory('داده پشتیبان');
      final backupPath =
          '${directory.path}${Platform.pathSeparator}hesab_backup.sqlite3';
      await DatabaseMaintenanceService(backupDatabase).createBackup(backupPath);

      final activeCatalog = CatalogService(
        CatalogRepository(await activeDatabase.database),
      );
      await activeCatalog.createCategory('داده فعلی');
      await DatabaseMaintenanceService(activeDatabase).restore(backupPath);

      final restoredRows = await (await activeDatabase.database).query(
        'category',
        columns: ['category_name'],
      );
      expect(restoredRows, hasLength(1));
      expect(restoredRows.single['category_name'], 'داده پشتیبان');
    },
  );

  test(
    'restore rejects backups missing the purchase allocation table',
    () async {
      final fixture = await _createBackupFixture();
      addTearDown(() async {
        await fixture.database.close();
        await fixture.directory.delete(recursive: true);
      });
      final service = DatabaseMaintenanceService(fixture.database);
      await service.createBackup(fixture.backupPath);

      final damagedBackup = await databaseFactoryFfi.openDatabase(
        fixture.backupPath,
      );
      await damagedBackup.execute('DROP TABLE purchase_wallet_allocation');
      await damagedBackup.close();
      await _addCategory(fixture.database, 'داده فعال');

      await expectLater(
        service.restore(fixture.backupPath),
        throwsA(isA<FormatException>()),
      );
      expect(await _backupCategoryNames(await fixture.database.path), [
        'داده نخست',
        'داده فعال',
      ]);
    },
  );

  test('restore rejects backups missing the wallet balance view', () async {
    final fixture = await _createBackupFixture();
    addTearDown(() async {
      await fixture.database.close();
      await fixture.directory.delete(recursive: true);
    });
    final service = DatabaseMaintenanceService(fixture.database);
    await service.createBackup(fixture.backupPath);

    final damagedBackup = await databaseFactoryFfi.openDatabase(
      fixture.backupPath,
    );
    await damagedBackup.execute('DROP VIEW wallet_balances');
    await damagedBackup.close();
    await _addCategory(fixture.database, 'داده فعال');

    await expectLater(
      service.restore(fixture.backupPath),
      throwsA(isA<FormatException>()),
    );
    expect(await _backupCategoryNames(await fixture.database.path), [
      'داده نخست',
      'داده فعال',
    ]);
  });
}

Future<_BackupFixture> _createBackupFixture() async {
  sqfliteFfiInit();
  final directory = await Directory.systemTemp.createTemp('hesab-backup-');
  final database = HesabDatabase.atPath(
    '${directory.path}${Platform.pathSeparator}source.sqlite3',
  );
  await _addCategory(database, 'داده نخست');
  return _BackupFixture(
    directory: directory,
    database: database,
    backupPath:
        '${directory.path}${Platform.pathSeparator}hesab_backup.sqlite3',
  );
}

Future<void> _addCategory(HesabDatabase database, String name) async {
  final service = CatalogService(CatalogRepository(await database.database));
  await service.createCategory(name);
}

Future<List<String>> _backupCategoryNames(String path) async {
  final database = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(readOnly: true),
  );
  try {
    final rows = await database.query(
      'category',
      columns: ['category_name'],
      orderBy: 'category_id',
    );
    return rows.map((row) => row['category_name']! as String).toList();
  } finally {
    await database.close();
  }
}

Future<List<FileSystemEntity>> _backupTemporaryFiles(
  _BackupFixture fixture,
) async {
  final prefix = '${fixture.backupPath}.';
  return Directory(fixture.directory.path)
      .listSync()
      .where((entry) => entry.path.startsWith(prefix))
      .toList();
}

class _BackupFixture {
  const _BackupFixture({
    required this.directory,
    required this.database,
    required this.backupPath,
  });

  final Directory directory;
  final HesabDatabase database;
  final String backupPath;
}
