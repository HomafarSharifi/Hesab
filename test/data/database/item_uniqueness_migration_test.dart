import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/data/database/migrations/hesab_migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'migrating v5 to v6 succeeds when item_normalized_name_category_idx already exists',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 5,
          onConfigure: (database) async {
            await database.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: HesabMigrations.onCreate,
        ),
      );
      addTearDown(db.close);

      await db.execute(
        'CREATE UNIQUE INDEX item_normalized_name_category_idx '
        'ON item(normalized_name, category_id)',
      );

      await HesabMigrations.migrate(db, fromVersion: 5, toVersion: 6);

      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name = 'item_normalized_name_category_idx'",
      );
      expect(indexes, hasLength(1));
    },
  );
}
