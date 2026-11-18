import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/data/database/migrations/hesab_migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v2 migration rounds legacy thousandth quantities half-up', () async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) =>
            HesabMigrations.migrate(db, fromVersion: 0, toVersion: version),
      ),
    );
    addTearDown(database.close);

    final categoryId = await database.insert('category', {
      'category_name': 'خوراکی',
      'normalized_name': 'خوراکی',
    });
    final unitId = await database.insert('unit', {
      'unit_name': 'کیلو',
      'normalized_name': 'کیلو',
    });
    final itemId = await database.insert('item', {
      'item_name': 'برنج',
      'normalized_name': 'برنج',
      'category_id': categoryId,
      'unit_id': unitId,
    });
    final walletId = await database.insert('wallet', {
      'wallet_name': 'اصلی',
      'normalized_name': 'اصلی',
    });
    final transactionId = await database.insert('wallet_transaction', {
      'wallet_id': walletId,
      'transaction_date': '2026-11-18',
      'transaction_type': 'purchase',
      'amount_minor': 1,
    });
    await database.insert('expense', {
      'transaction_id': transactionId,
      'item_id': itemId,
      'quantity_milli': 105,
      'unit_price_minor': 1,
    });

    await database.transaction(
      (txn) => HesabMigrations.migrate(txn, fromVersion: 1, toVersion: 2),
    );

    final migrated = await database.query('expense');
    expect(migrated.single['quantity_centi'], 11);
    expect(migrated.single.containsKey('quantity_milli'), isFalse);
  });
}
