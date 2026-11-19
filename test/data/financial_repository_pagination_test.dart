import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/data/database/migrations/hesab_migrations.dart';
import 'package:hesab/data/models/financial_models.dart';
import 'package:hesab/domain/services/catalog_service.dart';
import 'package:hesab/data/repositories/catalog_repository.dart';
import 'package:hesab/domain/services/transaction_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('expense page counts and row ranges cover boundary totals', () {
    const expectedPageCounts = <int, int>{
      0: 0,
      1: 1,
      49: 1,
      50: 1,
      51: 2,
      100: 2,
      101: 3,
      237: 5,
      501: 11,
    };

    for (final entry in expectedPageCounts.entries) {
      final page = ExpensePageResult(
        records: const [],
        totalCount: entry.key,
        pageIndex: 0,
        pageSize: ExpensePageResult.defaultPageSize,
      );
      expect(page.pageCount, entry.value, reason: '${entry.key} records');
    }

    final finalPage = ExpensePageResult(
      records: List<ExpenseRecord>.filled(37, _expenseRecord()),
      totalCount: 237,
      pageIndex: 4,
      pageSize: ExpensePageResult.defaultPageSize,
    );
    expect(finalPage.firstRowNumber, 201);
    expect(finalPage.lastRowNumber, 237);
  });

  test(
    'repository returns ordered 50-row pages beyond the old 500 limit',
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
      await catalog.createUnit('بسته');
      await catalog.createItem(name: 'چای', categoryId: 1, unitId: 1);
      await catalog.createWallet('اصلی');

      await database.transaction((transaction) async {
        await transaction.insert('wallet_transaction', {
          'wallet_id': 1,
          'transaction_date': '2026-11-17',
          'transaction_type': 'deposit',
          'amount_minor': 1000,
        });
        for (var index = 0; index < 501; index++) {
          final transactionId = await transaction.insert('wallet_transaction', {
            'wallet_id': 1,
            'transaction_date': '2026-11-18',
            'transaction_type': 'purchase',
            'amount_minor': 1,
          });
          await transaction.insert('expense', {
            'transaction_id': transactionId,
            'item_id': 1,
            'quantity_centi': 100,
            'unit_price_minor': 1,
            if (index.isEven) 'note': null,
          });
        }
      });

      final service = TransactionService(database);
      final firstPage = await service.expensesPage(pageIndex: 0);
      expect(firstPage.totalCount, 501);
      expect(firstPage.pageCount, 11);
      expect(firstPage.records, hasLength(50));
      expect(firstPage.records.first.transactionId, 502);
      expect(firstPage.records.last.transactionId, 453);

      final pageTen = await service.expensesPage(pageIndex: 9);
      expect(pageTen.records, hasLength(50));
      expect(pageTen.records.first.transactionId, 52);

      final lastPage = await service.expensesPage(pageIndex: 10);
      expect(lastPage.records, hasLength(1));
      expect(lastPage.firstRowNumber, 501);
      expect(lastPage.lastRowNumber, 501);
      expect(lastPage.records.single.transactionId, 2);

      final inclusiveDateFilter = await service.expensesPage(
        pageIndex: 0,
        fromDate: DateTime(2026, 11, 18),
        toDate: DateTime(2026, 11, 18),
        walletId: 1,
        categoryName: 'خوراکی',
        normalizedSearch: 'چای',
      );
      expect(inclusiveDateFilter.totalCount, 501);
      expect(inclusiveDateFilter.records, hasLength(50));

      final emptyFilter = await service.expensesPage(
        pageIndex: 0,
        normalizedSearch: 'پیدانمی‌شود',
      );
      expect(emptyFilter.totalCount, 0);
      expect(emptyFilter.records, isEmpty);

      final invalidPage = await service.expensesPage(pageIndex: 11);
      expect(invalidPage.totalCount, 501);
      expect(invalidPage.records, isEmpty);
    },
  );
}

ExpenseRecord _expenseRecord() => const ExpenseRecord(
  id: 1,
  transactionId: 1,
  walletId: 1,
  walletName: 'اصلی',
  date: '2026-11-18',
  amountMinor: 100,
  itemId: 1,
  itemName: 'چای',
  categoryName: 'خوراکی',
  unitName: 'بسته',
  quantityCenti: 100,
  unitPriceMinor: 100,
  isReversed: false,
);
