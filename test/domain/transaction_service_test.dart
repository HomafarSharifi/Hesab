import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/core/errors/app_failure.dart';
import 'package:hesab/data/database/migrations/hesab_migrations.dart';
import 'package:hesab/data/repositories/catalog_repository.dart';
import 'package:hesab/domain/services/catalog_service.dart';
import 'package:hesab/domain/services/transaction_service.dart';
import 'package:hesab/domain/services/report_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'purchase creates one expense atomically and enforces available funds',
    () async {
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
      await catalog.createUnit('کیلوگرام');
      await catalog.createItem(name: 'برنج', categoryId: 1, unitId: 1);
      await catalog.createWallet('اصلی');

      final service = TransactionService(database);
      await service.deposit(
        walletId: 1,
        date: DateTime(2026, 11, 18),
        amountMinor: 5000,
      );
      await service.purchase(
        walletId: 1,
        itemId: 1,
        date: DateTime(2026, 11, 18),
        quantityCenti: 125,
        unitPriceMinor: 200,
      );

      expect(
        await CatalogRepository(database)
            .activeWallet(1)
            .then((v) => v!.balanceMinor),
        4750,
      );
      expect(await service.expenses(), hasLength(1));

      await expectLater(
        service.purchase(
          walletId: 1,
          itemId: 1,
          date: DateTime(2026, 11, 18),
          quantityCenti: 1000,
          unitPriceMinor: 100,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(await database.query('wallet_transaction'), hasLength(2));
      expect(await service.expenses(), hasLength(1));

      await service.reverse(
        transactionId: 2,
        date: DateTime(2026, 11, 19),
        note: 'برگشت خرید',
      );
      expect(
        await CatalogRepository(database)
            .activeWallet(1)
            .then((v) => v!.balanceMinor),
        5000,
      );
      expect((await service.expenses()).single.isReversed, isTrue);
      expect((await ReportService(database).summary()).totalExpenseMinor, 0);

      await expectLater(
        service.purchaseWithNewProduct(
          walletId: 1,
          productName: 'چای',
          newCategoryName: 'نوشیدنی',
          newUnitName: 'بسته',
          date: DateTime(2026, 11, 20),
          quantityCenti: 100,
          unitPriceMinor: 6000,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(await database.query('category'), hasLength(1));
      expect(await database.query('unit'), hasLength(1));
      expect(await database.query('item'), hasLength(1));

      await service.purchaseWithNewProduct(
        walletId: 1,
        productName: 'چای',
        newCategoryName: 'نوشیدنی',
        newUnitName: 'بسته',
        date: DateTime(2026, 11, 20),
        quantityCenti: 100,
        unitPriceMinor: 1000,
      );
      expect(await database.query('category'), hasLength(2));
      expect(await database.query('unit'), hasLength(2));
      expect(await database.query('item'), hasLength(2));

      await service.purchaseWithNewProduct(
        walletId: 1,
        productName: 'بِرنج',
        categoryId: 1,
        unitId: 1,
        date: DateTime(2026, 11, 21),
        quantityCenti: 100,
        unitPriceMinor: 100,
      );
      expect(await database.query('item'), hasLength(2));
      expect(await service.expenses(), hasLength(3));
    },
  );
}
