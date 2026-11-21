import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/data/database/migrations/hesab_migrations.dart';
import 'package:hesab/data/repositories/catalog_repository.dart';
import 'package:hesab/domain/services/catalog_service.dart';
import 'package:hesab/domain/services/transaction_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wallet creation, funding, and edits are audited atomically', () async {
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

    final transactions = TransactionService(database);
    final catalog = CatalogService(CatalogRepository(database));
    await transactions.createWalletWithInitialDeposit(
      walletName: 'اصلی',
      amountMinor: 0,
      description: 'کیف روزانه',
    );
    var wallet = (await catalog.wallets()).single;
    expect(wallet.balanceMinor, 0);
    expect(await transactions.walletActivities(wallet.id), hasLength(1));

    await transactions.deposit(
      walletId: wallet.id,
      date: DateTime(2026, 11, 20),
      amountMinor: 1250,
      note: 'پس‌انداز',
    );
    wallet = (await catalog.wallets()).single;
    expect(wallet.balanceMinor, 1250);
    expect(await database.query('wallet_transaction'), hasLength(1));
    expect(await transactions.walletActivities(wallet.id), hasLength(2));

    await transactions.updateWalletProfile(
      walletId: wallet.id,
      name: 'کیف خانه',
      description: 'هزینه‌های روزانه',
    );
    final afterEdit = (await catalog.wallets()).single;
    expect(afterEdit.name, 'کیف خانه');
    expect(afterEdit.balanceMinor, 1250);
    expect(await database.query('wallet_transaction'), hasLength(1));
    expect(await transactions.walletActivities(wallet.id), hasLength(3));

    await transactions.updateWalletProfile(
      walletId: wallet.id,
      name: 'کیف خانه',
      description: 'هزینه‌های روزانه',
    );
    expect(await transactions.walletActivities(wallet.id), hasLength(3));
  });
}
