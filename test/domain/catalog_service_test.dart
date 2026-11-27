import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/core/errors/app_failure.dart';
import 'package:hesab/data/database/migrations/hesab_migrations.dart';
import 'package:hesab/data/repositories/catalog_repository.dart';
import 'package:hesab/domain/services/catalog_service.dart';
import 'package:hesab/domain/services/transaction_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('item update also works after the item has purchase history', () async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: HesabMigrations.currentVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: HesabMigrations.onCreate,
      ),
    );
    addTearDown(database.close);

    final catalog = CatalogService(CatalogRepository(database));
    await catalog.createCategory('خوراکی');
    await catalog.createCategory('نوشیدنی');
    await catalog.createUnit('کیلوگرام');
    await catalog.createUnit('بسته');
    await catalog.createItem(name: 'برنج', categoryId: 1, unitId: 1);
    await catalog.createWallet('اصلی');

    final transactions = TransactionService(database);
    await transactions.deposit(
      walletId: 1,
      date: DateTime(2026, 11, 21),
      amountMinor: 10000,
    );
    await transactions.purchase(
      walletId: 1,
      itemId: 1,
      date: DateTime(2026, 11, 21),
      quantityCenti: 100,
      unitPriceMinor: 100,
    );

    await catalog.updateItem(id: 1, name: 'چای', categoryId: 2, unitId: 2);

    final updated = (await catalog.items()).single;
    expect(updated.name, 'چای');
    expect(updated.categoryId, 2);
    expect(updated.unitId, 2);

    final historicalExpense = (await transactions.expenses()).single;
    expect(historicalExpense.itemName, 'چای');
    expect(historicalExpense.categoryName, 'نوشیدنی');
    expect(historicalExpense.unitName, 'بسته');
  });

  test('item uniqueness is normalized name plus category regardless of unit', () async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: HesabMigrations.currentVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: HesabMigrations.onCreate,
      ),
    );
    addTearDown(database.close);

    final catalog = CatalogService(CatalogRepository(database));
    await catalog.createCategory('خوراکی');
    await catalog.createCategory('نوشیدنی');
    await catalog.createUnit('کیلوگرام');
    await catalog.createUnit('بسته');

    await catalog.createItem(name: 'شیر', categoryId: 1, unitId: 1);

    await expectLater(
      catalog.createItem(name: 'شیر', categoryId: 1, unitId: 2),
      throwsA(isA<AppFailure>()),
    );

    await catalog.createItem(name: 'شیر', categoryId: 2, unitId: 2);
    expect((await catalog.items()).length, 2);

    await expectLater(
      catalog.updateItem(id: 2, name: 'شیر', categoryId: 1, unitId: 2),
      throwsA(isA<AppFailure>()),
    );
  });

  test('v6 migration deduplicates items by normalized name and category', () async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) =>
            HesabMigrations.migrate(db, fromVersion: 0, toVersion: 5),
      ),
    );
    addTearDown(database.close);

    await database.insert('category', {
      'category_name': 'خوراکی',
      'normalized_name': 'خوراکی',
    });
    await database.insert('unit', {'unit_name': 'کیلوگرام', 'normalized_name': 'کیلوگرام'});
    await database.insert('unit', {'unit_name': 'بسته', 'normalized_name': 'بسته'});
    await database.insert('item', {
      'item_name': 'شیر',
      'normalized_name': 'شیر',
      'category_id': 1,
      'unit_id': 1,
    });
    await database.insert('item', {
      'item_name': 'شیر',
      'normalized_name': 'شیر',
      'category_id': 1,
      'unit_id': 2,
    });
    await database.insert('wallet', {
      'wallet_name': 'اصلی',
      'normalized_name': 'اصلی',
    });
    await database.insert('wallet_transaction', {
      'wallet_id': 1,
      'transaction_date': '2026-11-21',
      'transaction_type': 'purchase',
      'amount_minor': 500,
    });
    await database.insert('expense', {
      'transaction_id': 1,
      'item_id': 2,
      'quantity_centi': 100,
      'unit_price_minor': 500,
    });

    await HesabMigrations.migrate(database, fromVersion: 5, toVersion: 6);

    final items = await database.query('item');
    expect(items.length, 1);
    expect(items.single['item_id'], 1);

    final expense = (await database.query('expense')).single;
    expect(expense['item_id'], 1);

    await expectLater(
      database.insert('item', {
        'item_name': 'شیر',
        'normalized_name': 'شیر',
        'category_id': 1,
        'unit_id': 2,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
