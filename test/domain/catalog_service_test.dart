import 'package:flutter_test/flutter_test.dart';
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
}
