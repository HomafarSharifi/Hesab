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
    'history merges ledger and profile events with wallet allocations',
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
      final purchaseReversalId = await transactions.reverse(
        transactionId: purchaseId,
        date: DateTime(2026, 11, 4),
        note: 'برگشت خرید',
      );
      final depositReversalId = await transactions.reverse(
        transactionId: depositId,
        date: DateTime(2026, 11, 5),
        note: 'برگشت افزودن پول',
      );
      final withdrawalReversalId = await transactions.reverse(
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
      final replacementId = await transactions.correctPurchaseWithNewProduct(
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
      expect(
        mainHistory.where((row) => row['event_type'] == 'withdrawal'),
        hasLength(1),
      );
      final withdrawal = mainHistory.singleWhere(
        (row) => row['transaction_id'] == withdrawalId,
      );
      expect(WalletActivityPresentation.label(withdrawal), 'برداشت پول');
      expect(WalletActivityPresentation.amountLabel(withdrawal), '−95 ؋');

      final mainPurchases = mainHistory
          .where((row) => row['event_type'] == 'purchase')
          .toList();
      final allocatedPurchase = mainPurchases.singleWhere(
        (row) => row['transaction_id'] == purchaseId,
      );
      expect(allocatedPurchase['amount_minor'], 1500);
      expect(allocatedPurchase['item_name'], 'برنج');
      expect(allocatedPurchase['is_reversed'], 1);
      expect(
        WalletActivityPresentation.label(allocatedPurchase),
        'خرید (برگشت‌شده)',
      );
      expect(
        WalletActivityPresentation.amountLabel(allocatedPurchase),
        '−15 ؋',
      );
      final correctedPurchase = mainPurchases.singleWhere(
        (row) => row['transaction_id'] == originalCorrectionId,
      );
      expect(correctedPurchase['is_reversed'], 1);
      expect(
        WalletActivityPresentation.label(correctedPurchase),
        'خرید (برگشت‌شده)',
      );
      expect(
        WalletActivityPresentation.amountLabel(correctedPurchase),
        '−10 ؋',
      );
      expect(
        mainPurchases.singleWhere(
          (row) => row['transaction_id'] == replacementId,
        )['is_reversed'],
        0,
      );
      expect(
        WalletActivityPresentation.label(
          mainPurchases.singleWhere(
            (row) => row['transaction_id'] == replacementId,
          ),
        ),
        'خرید',
      );
      expect(
        WalletActivityPresentation.amountLabel(
          mainPurchases.singleWhere(
            (row) => row['transaction_id'] == replacementId,
          ),
        ),
        '−9 ؋',
      );

      final mainReversals = mainHistory
          .where((row) => row['event_type'] == 'reversal')
          .toList();
      final correctionReversal = mainReversals.singleWhere(
        (row) => row['reversal_of_transaction_id'] == originalCorrectionId,
      );
      expect(correctionReversal['original_type'], 'purchase');
      expect(correctionReversal['amount_minor'], 1000);
      expect(
        WalletActivityPresentation.label(correctionReversal),
        'برگشت خرید',
      );
      expect(
        WalletActivityPresentation.amountLabel(correctionReversal),
        '+10 ؋',
      );
      final allocatedReversal = mainReversals.singleWhere(
        (row) => row['transaction_id'] == purchaseReversalId,
      );
      expect(allocatedReversal['original_type'], 'purchase');
      expect(allocatedReversal['amount_minor'], 1500);
      expect(allocatedReversal['item_name'], 'برنج');
      expect(WalletActivityPresentation.label(allocatedReversal), 'برگشت خرید');
      expect(
        WalletActivityPresentation.amountLabel(allocatedReversal),
        '+15 ؋',
      );
      final depositReversal = mainReversals.singleWhere(
        (row) => row['transaction_id'] == depositReversalId,
      );
      expect(depositReversal['original_type'], 'deposit');
      expect(
        WalletActivityPresentation.label(depositReversal),
        'برگشت پول افزوده‌شده',
      );
      expect(WalletActivityPresentation.amountLabel(depositReversal), '−10 ؋');
      final withdrawalReversal = mainReversals.singleWhere(
        (row) => row['transaction_id'] == withdrawalReversalId,
      );
      expect(withdrawalReversal['original_type'], 'withdrawal');
      expect(
        WalletActivityPresentation.label(withdrawalReversal),
        'برگشت برداشت',
      );
      expect(
        WalletActivityPresentation.amountLabel(withdrawalReversal),
        '+95 ؋',
      );

      final secondHistory = await transactions.walletActivities(2);
      final secondPurchase = secondHistory.singleWhere(
        (row) => row['transaction_id'] == purchaseId,
      );
      final secondReversal = secondHistory.singleWhere(
        (row) => row['transaction_id'] == purchaseReversalId,
      );
      expect(secondPurchase['amount_minor'], 2000);
      expect(secondPurchase['is_reversed'], 1);
      expect(secondReversal['amount_minor'], 2000);
      expect(secondReversal['original_type'], 'purchase');
      expect(WalletActivityPresentation.amountLabel(secondPurchase), '−20 ؋');
      expect(WalletActivityPresentation.amountLabel(secondReversal), '+20 ؋');
      expect(
        secondHistory.where((row) => row['event_type'] == 'deposit'),
        hasLength(1),
      );

      final recent = await transactions.walletActivities(1, limit: 3);
      expect(recent, hasLength(3));
      expect(
        recent.map((row) => row['history_id']).toList(),
        mainHistory.take(3).map((row) => row['history_id']).toList(),
      );
      expect(mainHistory.length, greaterThan(3));
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
