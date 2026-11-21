import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/data/database/database_maintenance_service.dart';
import 'package:hesab/data/database/hesab_database.dart';
import 'package:hesab/data/repositories/catalog_repository.dart';
import 'package:hesab/domain/services/catalog_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
