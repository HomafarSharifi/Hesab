import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/data/database/migrations/hesab_migrations.dart';
import 'package:hesab/data/repositories/catalog_repository.dart';
import 'package:hesab/domain/services/catalog_service.dart';
import 'package:hesab/domain/services/transaction_service.dart';
import 'package:hesab/features/wallets/screens/wallet_screen.dart'
    show WalletActivityPresentation;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'wallet activity shows creation, deposits, and edits only',
    () async {
      final fixture = await _createFixture();
      addTearDown(fixture.database.close);
      final transactions = fixture.transactions;
      final catalog = fixture.catalog;

      await transactions.createWalletWithInitialDeposit(
        walletName: 'اصلی',
        amountMinor: 10000,
        description: 'کیف روزانه',
      );
      await transactions.createWalletWithInitialDeposit(
        walletName: 'دوم',
        amountMinor: 3000,
      );
      await transactions.updateWalletProfile(
        walletId: 1,
        name: 'اصلی',
        description: 'کیف روزانه ویرایش‌شده',
      );
      final depositId = await transactions.deposit(
        walletId: 1,
        date: DateTime(2026, 11, 1),
        amountMinor: 1000,
        note: 'افزودن پول',
      );
      final withdrawalId = await transactions.withdrawal(
        walletId: 1,
        date: DateTime(2026, 11, 2),
        amountMinor: 9500,
        note: 'برداشت',
      );

      await catalog.createCategory('خوراکی');
      await catalog.createUnit('بسته');
      final categoryId =
          (await fixture.database.query('category')).single['category_id']!
              as int;
      final unitId =
          (await fixture.database.query('unit')).single['unit_id']! as int;
      final purchaseId = await transactions.purchaseWithNewProduct(
        walletId: 1,
        walletIds: const [1, 2],
        productName: 'برنج',
        categoryId: categoryId,
        unitId: unitId,
        date: DateTime(2026, 11, 3),
        quantityCenti: 100,
        unitPriceMinor: 3500,
        note: 'خرید چندکیف پولی',
      );
      await transactions.reverse(
        transactionId: purchaseId,
        date: DateTime(2026, 11, 4),
        note: 'برگشت خرید',
      );
      await transactions.reverse(
        transactionId: depositId,
        date: DateTime(2026, 11, 5),
        note: 'برگشت افزودن پول',
      );
      await transactions.reverse(
        transactionId: withdrawalId,
        date: DateTime(2026, 11, 6),
        note: 'برگشت برداشت',
      );

      final originalCorrectionId = await transactions.purchaseWithNewProduct(
        walletId: 1,
        productName: 'برنج',
        categoryId: categoryId,
        unitId: unitId,
        date: DateTime(2026, 11, 7),
        quantityCenti: 100,
        unitPriceMinor: 1000,
      );
      await transactions.correctPurchaseWithNewProduct(
        originalTransactionId: originalCorrectionId,
        walletId: 1,
        productName: 'برنج',
        correctionDate: DateTime(2026, 11, 8),
        purchaseDate: DateTime(2026, 11, 8),
        categoryId: categoryId,
        unitId: unitId,
        quantityCenti: 100,
        unitPriceMinor: 900,
        note: 'خرید جایگزین',
      );

      final mainHistory = await transactions.walletActivities(1);
      expect(
        mainHistory.where((row) => row['event_type'] == 'created'),
        hasLength(1),
      );
      expect(
        mainHistory.where((row) => row['event_type'] == 'updated'),
        hasLength(1),
      );
      final deposits = mainHistory
          .where((row) => row['event_type'] == 'deposit')
          .toList();
      expect(deposits, hasLength(2));
      expect(
        deposits.map((row) => row['transaction_id']).toSet(),
        hasLength(2),
      );
      expect(deposits.where((row) => row['details'] == 'موجودی'), hasLength(1));
      final initialDeposit = deposits.singleWhere(
        (row) => row['details'] == 'موجودی',
      );
      expect(
        WalletActivityPresentation.label(initialDeposit),
        'پول آغازین افزوده شد',
      );
      expect(WalletActivityPresentation.amountLabel(initialDeposit), '+100 ؋');
      final regularDeposit = deposits.singleWhere(
        (row) => row['transaction_id'] == depositId,
      );
      expect(WalletActivityPresentation.label(regularDeposit), 'پول افزوده شد');
      expect(WalletActivityPresentation.amountLabel(regularDeposit), '+10 ؋');
      final secondHistory = await transactions.walletActivities(2);
      expect(secondHistory.map((row) => row['event_type']).toSet(), {
        'created',
        'deposit',
      });
      expect(secondHistory, hasLength(2));
      expect(
        secondHistory.where((row) => row['event_type'] == 'deposit'),
        hasLength(1),
      );
      expect(mainHistory.map((row) => row['event_type']).toSet(), {
        'created',
        'updated',
        'deposit',
      });
      expect(mainHistory, hasLength(4));
      expect(
        mainHistory.every((row) => row['event_type'] != 'purchase' &&
            row['event_type'] != 'withdrawal' &&
            row['event_type'] != 'reversal'),
        isTrue,
      );

      final recent = await transactions.walletActivities(1, limit: 3);
      expect(recent, hasLength(3));
      expect(
        recent.map((row) => row['history_id']).toList(),
        mainHistory.take(3).map((row) => row['history_id']).toList(),
      );
    },
  );

  test('equal event timestamps have deterministic order', () async {
    final fixture = await _createFixture();
    addTearDown(fixture.database.close);
    await fixture.transactions.createWalletWithInitialDeposit(
      walletName: 'اصلی',
      amountMinor: 0,
    );
    const timestamp = '2099-01-01T00:00:00.000Z';
    final firstId = await fixture.database.insert('wallet_activity', {
      'wallet_id': 1,
      'event_type': 'updated',
      'occurred_at': timestamp,
      'details': 'ویرایش نخست',
    });
    final secondId = await fixture.database.insert('wallet_activity', {
      'wallet_id': 1,
      'event_type': 'updated',
      'occurred_at': timestamp,
      'details': 'ویرایش دوم',
    });

    final history = await fixture.transactions.walletActivities(1);
    expect(
      history
          .where((row) => row['occurred_at'] == timestamp)
          .map((row) => row['history_id'])
          .toList(),
      ['0:$firstId', '0:$secondId'],
    );
  });
}

Future<_WalletHistoryFixture> _createFixture() async {
  sqfliteFfiInit();
  final database = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: HesabMigrations.currentVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: HesabMigrations.onCreate,
    ),
  );
  final repository = CatalogRepository(database);
  return _WalletHistoryFixture(
    database: database,
    catalog: CatalogService(repository),
    transactions: TransactionService(database),
  );
}

class _WalletHistoryFixture {
  const _WalletHistoryFixture({
    required this.database,
    required this.catalog,
    required this.transactions,
  });

  final Database database;
  final CatalogService catalog;
  final TransactionService transactions;
}
