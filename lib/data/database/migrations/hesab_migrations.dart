import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Schema changes are append-only. Increment [currentVersion] and add a
/// migration case whenever the persisted schema changes.
abstract final class HesabMigrations {
  static const currentVersion = 2;

  static Future<void> onCreate(Database database, int version) =>
      migrate(database, fromVersion: 0, toVersion: version);

  static Future<void> onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) => migrate(database, fromVersion: oldVersion, toVersion: newVersion);

  static Future<void> migrate(
    DatabaseExecutor database, {
    required int fromVersion,
    required int toVersion,
  }) async {
    if (fromVersion < 0 || toVersion < fromVersion) {
      throw ArgumentError('Invalid database migration range.');
    }

    for (var version = fromVersion + 1; version <= toVersion; version++) {
      switch (version) {
        case 1:
          await _createVersion1(database);
          break;
        case 2:
          await _migrateVersion2(database);
          break;
        default:
          throw StateError('No Hesab database migration exists for v$version.');
      }
    }
  }

  static Future<void> _createVersion1(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE category (
        category_id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL
          CHECK(length(trim(category_name)) BETWEEN 1 AND 45),
        normalized_name TEXT NOT NULL UNIQUE
          CHECK(length(trim(normalized_name)) BETWEEN 1 AND 45),
        archived_at TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');

    await database.execute('''
      CREATE TABLE unit (
        unit_id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_name TEXT NOT NULL
          CHECK(length(trim(unit_name)) BETWEEN 1 AND 30),
        normalized_name TEXT NOT NULL UNIQUE
          CHECK(length(trim(normalized_name)) BETWEEN 1 AND 30),
        archived_at TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');

    await database.execute('''
      CREATE TABLE item (
        item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name TEXT NOT NULL
          CHECK(length(trim(item_name)) BETWEEN 1 AND 45),
        normalized_name TEXT NOT NULL
          CHECK(length(trim(normalized_name)) BETWEEN 1 AND 45),
        category_id INTEGER NOT NULL,
        unit_id INTEGER NOT NULL,
        archived_at TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        UNIQUE(normalized_name, category_id, unit_id),
        FOREIGN KEY(category_id) REFERENCES category(category_id) ON DELETE RESTRICT,
        FOREIGN KEY(unit_id) REFERENCES unit(unit_id) ON DELETE RESTRICT
      )
    ''');

    await database.execute('''
      CREATE TABLE wallet (
        wallet_id INTEGER PRIMARY KEY AUTOINCREMENT,
        wallet_name TEXT NOT NULL
          CHECK(length(trim(wallet_name)) BETWEEN 1 AND 45),
        normalized_name TEXT NOT NULL UNIQUE
          CHECK(length(trim(normalized_name)) BETWEEN 1 AND 45),
        archived_at TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');

    await database.execute('''
      CREATE TABLE wallet_transaction (
        transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
        wallet_id INTEGER NOT NULL,
        transaction_date TEXT NOT NULL
          CHECK(
            length(transaction_date) = 10
            AND transaction_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
          ),
        transaction_type TEXT NOT NULL
          CHECK(transaction_type IN ('deposit', 'purchase', 'withdrawal', 'reversal')),
        amount_minor INTEGER NOT NULL
          CHECK(amount_minor BETWEEN 1 AND 9999999999),
        note TEXT,
        reversal_of_transaction_id INTEGER UNIQUE,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        CHECK(
          (transaction_type = 'reversal' AND reversal_of_transaction_id IS NOT NULL)
          OR
          (transaction_type <> 'reversal' AND reversal_of_transaction_id IS NULL)
        ),
        FOREIGN KEY(wallet_id) REFERENCES wallet(wallet_id) ON DELETE RESTRICT,
        FOREIGN KEY(reversal_of_transaction_id)
          REFERENCES wallet_transaction(transaction_id) ON DELETE RESTRICT
      )
    ''');

    await database.execute('''
      CREATE TABLE expense (
        expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL UNIQUE,
        item_id INTEGER NOT NULL,
        quantity_milli INTEGER NOT NULL
          CHECK(quantity_milli BETWEEN 1 AND 99999999999),
        unit_price_minor INTEGER NOT NULL
          CHECK(unit_price_minor BETWEEN 1 AND 9999999999),
        note TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        FOREIGN KEY(transaction_id)
          REFERENCES wallet_transaction(transaction_id) ON DELETE RESTRICT,
        FOREIGN KEY(item_id) REFERENCES item(item_id) ON DELETE RESTRICT
      )
    ''');

    await database.execute(
      'CREATE INDEX item_category_id_idx ON item(category_id)',
    );
    await database.execute('CREATE INDEX item_unit_id_idx ON item(unit_id)');
    await database.execute(
      'CREATE INDEX transaction_wallet_date_idx '
      'ON wallet_transaction(wallet_id, transaction_date DESC, transaction_id DESC)',
    );
    await database.execute(
      'CREATE INDEX expense_item_id_idx ON expense(item_id)',
    );

    await database.execute('''
      CREATE TRIGGER expense_requires_purchase_insert
      BEFORE INSERT ON expense
      WHEN COALESCE(
        (SELECT transaction_type FROM wallet_transaction
         WHERE transaction_id = NEW.transaction_id),
        ''
      ) <> 'purchase'
      BEGIN
        SELECT RAISE(ABORT, 'expense_requires_purchase');
      END
    ''');
    await database.execute('''
      CREATE TRIGGER expense_requires_purchase_update
      BEFORE UPDATE OF transaction_id ON expense
      WHEN COALESCE(
        (SELECT transaction_type FROM wallet_transaction
         WHERE transaction_id = NEW.transaction_id),
        ''
      ) <> 'purchase'
      BEGIN
        SELECT RAISE(ABORT, 'expense_requires_purchase');
      END
    ''');
    await database.execute('''
      CREATE TRIGGER validate_reversal_insert
      BEFORE INSERT ON wallet_transaction
      WHEN NEW.transaction_type = 'reversal'
        AND NOT EXISTS (
          SELECT 1 FROM wallet_transaction original
          WHERE original.transaction_id = NEW.reversal_of_transaction_id
            AND original.transaction_type IN ('deposit', 'purchase', 'withdrawal')
            AND original.wallet_id = NEW.wallet_id
            AND original.amount_minor = NEW.amount_minor
        )
      BEGIN
        SELECT RAISE(ABORT, 'invalid_reversal');
      END
    ''');
    await database.execute('''
      CREATE TRIGGER wallet_transaction_immutable_update
      BEFORE UPDATE ON wallet_transaction
      BEGIN
        SELECT RAISE(ABORT, 'financial_transaction_is_immutable');
      END
    ''');
    await database.execute('''
      CREATE TRIGGER wallet_transaction_immutable_delete
      BEFORE DELETE ON wallet_transaction
      BEGIN
        SELECT RAISE(ABORT, 'financial_transaction_is_immutable');
      END
    ''');
    await database.execute('''
      CREATE TRIGGER expense_immutable_update
      BEFORE UPDATE ON expense
      BEGIN
        SELECT RAISE(ABORT, 'financial_expense_is_immutable');
      END
    ''');
    await database.execute('''
      CREATE TRIGGER expense_immutable_delete
      BEFORE DELETE ON expense
      BEGIN
        SELECT RAISE(ABORT, 'financial_expense_is_immutable');
      END
    ''');

    await database.execute('''
      CREATE VIEW wallet_balances AS
      SELECT
        wallet.wallet_id,
        COALESCE(SUM(
          CASE wallet_transaction.transaction_type
            WHEN 'deposit' THEN wallet_transaction.amount_minor
            WHEN 'purchase' THEN -wallet_transaction.amount_minor
            WHEN 'withdrawal' THEN -wallet_transaction.amount_minor
            WHEN 'reversal' THEN
              CASE original.transaction_type
                WHEN 'deposit' THEN -wallet_transaction.amount_minor
                ELSE wallet_transaction.amount_minor
              END
          END
        ), 0) AS balance_minor
      FROM wallet
      LEFT JOIN wallet_transaction
        ON wallet_transaction.wallet_id = wallet.wallet_id
      LEFT JOIN wallet_transaction AS original
        ON original.transaction_id = wallet_transaction.reversal_of_transaction_id
      GROUP BY wallet.wallet_id
    ''');
  }

  /// Converts the persisted quantity from thousandths to hundredths. Legacy
  /// values are rounded to the nearest hundredth using positive half-up.
  static Future<void> _migrateVersion2(DatabaseExecutor database) async {
    await database.execute('DROP TRIGGER expense_immutable_update');
    await database.execute('DROP TRIGGER expense_immutable_delete');
    await database.execute('''
      CREATE TABLE expense_v2 (
        expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL UNIQUE,
        item_id INTEGER NOT NULL,
        quantity_centi INTEGER NOT NULL
          CHECK(quantity_centi BETWEEN 1 AND 10000000000),
        unit_price_minor INTEGER NOT NULL
          CHECK(unit_price_minor BETWEEN 1 AND 9999999999),
        note TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        FOREIGN KEY(transaction_id)
          REFERENCES wallet_transaction(transaction_id) ON DELETE RESTRICT,
        FOREIGN KEY(item_id) REFERENCES item(item_id) ON DELETE RESTRICT
      )
    ''');
    await database.execute('''
      INSERT INTO expense_v2 (
        expense_id, transaction_id, item_id, quantity_centi,
        unit_price_minor, note, created_at
      )
      SELECT expense_id, transaction_id, item_id,
             CAST((quantity_milli + 5) / 10 AS INTEGER),
             unit_price_minor, note, created_at
      FROM expense
    ''');
    await database.execute('DROP TABLE expense');
    await database.execute('ALTER TABLE expense_v2 RENAME TO expense');
    await database.execute(
      'CREATE INDEX expense_item_id_idx ON expense(item_id)',
    );
    await database.execute('''
      CREATE TRIGGER expense_requires_purchase_insert
      BEFORE INSERT ON expense
      WHEN COALESCE(
        (SELECT transaction_type FROM wallet_transaction
         WHERE transaction_id = NEW.transaction_id),
        ''
      ) <> 'purchase'
      BEGIN
        SELECT RAISE(ABORT, 'expense_requires_purchase');
      END
    ''');
    await database.execute('''
      CREATE TRIGGER expense_requires_purchase_update
      BEFORE UPDATE OF transaction_id ON expense
      WHEN COALESCE(
        (SELECT transaction_type FROM wallet_transaction
         WHERE transaction_id = NEW.transaction_id),
        ''
      ) <> 'purchase'
      BEGIN
        SELECT RAISE(ABORT, 'expense_requires_purchase');
      END
    ''');
    await database.execute('''
      CREATE TRIGGER expense_immutable_update
      BEFORE UPDATE ON expense
      BEGIN
        SELECT RAISE(ABORT, 'financial_expense_is_immutable');
      END
    ''');
    await database.execute('''
      CREATE TRIGGER expense_immutable_delete
      BEFORE DELETE ON expense
      BEGIN
        SELECT RAISE(ABORT, 'financial_expense_is_immutable');
      END
    ''');
  }
}
