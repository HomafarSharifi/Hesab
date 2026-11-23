import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/data/database/migrations/hesab_migrations.dart';
import 'package:hesab/data/repositories/catalog_repository.dart';
import 'package:hesab/data/repositories/report_repository.dart';
import 'package:hesab/domain/services/catalog_service.dart';
import 'package:hesab/domain/services/report_service.dart';
import 'package:hesab/domain/services/transaction_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late ReportService reports;
  late int teaId;
  late int breadId;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: HesabMigrations.currentVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: HesabMigrations.onCreate,
      ),
    );
    reports = ReportService(ReportRepository(database));

    final catalog = CatalogService(CatalogRepository(database));
    await catalog.createCategory('خوراکی');
    await catalog.createCategory('نوشیدنی');
    await catalog.createUnit('عدد');
    await catalog.createItem(name: 'نان', categoryId: 1, unitId: 1);
    await catalog.createItem(name: 'چای', categoryId: 2, unitId: 1);
    await catalog.createWallet('اصلی');
    breadId = 1;
    teaId = 2;

    final transactions = TransactionService(database);
    await transactions.deposit(
      walletId: 1,
      date: DateTime(2024, 3, 19),
      amountMinor: 5000,
    );
    await transactions.deposit(
      walletId: 1,
      date: DateTime(2024, 3, 20),
      amountMinor: 500,
    );
    final reversedDeposit = await transactions.deposit(
      walletId: 1,
      date: DateTime(2024, 4, 20),
      amountMinor: 600,
    );
    await _purchase(
      transactions,
      itemId: teaId,
      date: DateTime(2024, 3, 19),
      amountMinor: 100,
    );
    await _purchase(
      transactions,
      itemId: teaId,
      date: DateTime(2024, 3, 20),
      amountMinor: 200,
    );
    await _purchase(
      transactions,
      itemId: teaId,
      date: DateTime(2024, 3, 20),
      amountMinor: 50,
    );
    await _purchase(
      transactions,
      itemId: breadId,
      date: DateTime(2024, 4, 20),
      amountMinor: 300,
    );
    final reversedPurchase = await _purchase(
      transactions,
      itemId: breadId,
      date: DateTime(2024, 4, 21),
      amountMinor: 400,
    );
    await transactions.reverse(
      transactionId: reversedDeposit,
      date: DateTime(2024, 4, 21),
    );
    await transactions.reverse(
      transactionId: reversedPurchase,
      date: DateTime(2024, 4, 22),
    );
  });

  tearDown(() => database.close());

  test(
    'summary preserves totals, grouping, reversals, and inclusive dates',
    () async {
      final allTime = await reports.summary();
      expect(allTime.totalExpenseMinor, 650);
      expect(allTime.totalReceivedMinor, 5500);
      expect(allTime.purchaseCount, 4);
      expect(allTime.highestPurchaseMinor, 300);
      expect(allTime.mostPurchasedItem, 'چای');
      expect(allTime.expenseByCategory, {'نوشیدنی': 350, 'خوراکی': 300});
      expect(allTime.purchaseCountByCategory, {'نوشیدنی': 3, 'خوراکی': 1});
      expect(allTime.expensesByMonth, {
        '1402-12': 100,
        '1403-01': 250,
        '1403-02': 300,
      });

      final bounded = await reports.summary(
        fromDate: DateTime(2024, 3, 20),
        toDate: DateTime(2024, 4, 20),
      );
      expect(bounded.totalExpenseMinor, 550);
      expect(bounded.totalReceivedMinor, 500);
      expect(bounded.purchaseCount, 3);
      expect(bounded.expensesByMonth, {'1403-01': 250, '1403-02': 300});
    },
  );

  test(
    'daily totals respect inclusive Gregorian bounds and reversals',
    () async {
      expect(
        await reports.expensesByDate(
          fromDate: DateTime(2024, 3, 20),
          toDate: DateTime(2024, 4, 20),
        ),
        {'2024-03-20': 250, '2024-04-20': 300},
      );
    },
  );

  test(
    'item totals group by Jalali year and month and omit reversals',
    () async {
      expect(
        await reports.itemExpensesByMonth(itemId: teaId, jalaliYear: 1402),
        {'12': 100},
      );
      expect(
        await reports.itemExpensesByMonth(itemId: teaId, jalaliYear: 1403),
        {'01': 250},
      );
      expect(
        await reports.itemExpensesByMonth(itemId: breadId, jalaliYear: 1403),
        {'02': 300},
      );
    },
  );
}

Future<int> _purchase(
  TransactionService transactions, {
  required int itemId,
  required DateTime date,
  required int amountMinor,
}) => transactions.purchase(
  walletId: 1,
  itemId: itemId,
  date: date,
  quantityCenti: 100,
  unitPriceMinor: amountMinor,
);
