# SQLite storage

## Location and lifecycle

Hesab opens one SQLite database at startup and keeps the connection for the app session. On Windows, the file is stored at `%LOCALAPPDATA%/Hesab/hesab.sqlite3`, outside the repository and in local per-user app data. `sqflite_common_ffi` supplies the sqflite API backed by bundled SQLite for Windows desktop.

The database is initialized by `HesabDatabase`. It enables and checks SQLite foreign-key enforcement on every opened connection. Version upgrades are append-only in `HesabMigrations`; the current schema version is 6. Never edit a migration that has shipped. Add a new numbered migration and raise `currentVersion` instead.

## Version 1 schema and later changes

The migration adapts the logical tables in `database schema.txt`:

- `category`, `unit`, `item`, and `wallet` retain their parent/child relationships and add normalized names plus nullable `archived_at` timestamps.
- Categories and units are unique by normalized name. Wallets are unique by normalized name. Items are unique by normalized name and category.
- `wallet_transaction` stores a constrained transaction type and optional `reversal_of_transaction_id`. A reversal must point to an unreversed deposit, purchase, or withdrawal in the same wallet for the same amount. Reversals are unique per original transaction.
- `expense.transaction_id` is unique, and triggers reject expenses attached to non-purchase transactions. Transactions and expense rows are immutable after insertion; corrections are represented with reversal rows.
- `wallet_balances` computes each balance in integer minor units, including the inverse effect of a reversal. New wallets therefore have a zero balance without an opening-balance field.
- Version 4 adds optional wallet descriptions and an append-only `wallet_activity` audit table. Wallet creation, deposits, and metadata edits are logged transactionally; existing wallets and deposits are backfilled. The wallet activity screen shows only those profile and deposit events. Purchases, withdrawals, and reversals remain in the financial transaction ledger for balance, expense, and correction accounting, but are not shown as wallet activity.
- Version 5 corrects `wallet_balances` so a reversed purchase offsets its original allocation exactly once.
- Version 6 deduplicates any existing items sharing `(normalized_name, category_id)` (repointing historical expenses to the canonical item) and adds a unique index on `item(normalized_name, category_id)`.
- Foreign keys use `ON DELETE RESTRICT` so referenced categories, units, items, wallets, and transactions must be archived instead of removed.

The application has one currency (AFN), so currency is not repeated in each row. Dates are stored as ISO `YYYY-MM-DD` Gregorian dates; the UI converts them to the Afghan Jalali calendar for display.

## Exact number representation

- Money is stored as integer minor units: 100 minor units equal 1 AFN. The version 1 range matches the positive `DECIMAL(10,2)` range from the logical schema.
- Quantity is stored as integer hundredths: 100 units equal quantity 1.00. The v2 migration converts prior thousandths to hundredths using nearest rounding, with positive ties rounded up.
- Unit price is stored as integer minor units. The database does not use SQLite `REAL` for money.
- For a purchase, calculate `quantity_centi × unit_price_minor` with arbitrary-precision integer arithmetic in the service layer. Divide by 100 and round to the nearest minor unit, with exact ties rounded away from zero (for positive purchases, half-up). For example, 1.25 × 12.50 AFN is 15.63 AFN. Validate the rounded result against the transaction amount before writing.

SQLite cannot express a cross-table requirement that every purchase has at least one expense at commit time using the current transaction-first schema. The database enforces at most one expense per transaction and rejects expenses for other transaction types. `TransactionService.purchase` inserts the transaction and its one expense in the same database transaction so the pair commits or rolls back together. The service test verifies an insufficient-funds purchase creates neither record.

## Dependencies

- `sqflite_common_ffi`: Windows-compatible SQLite access using sqflite's database, transaction, and migration APIs; SQLite is bundled by the package's current 3.x native build hooks.

## Known boundaries

Repositories, local name normalization, validation, financial services, and reversals sit above the migration layer. `ReportRepository` owns report SQL queries; `ReportService` applies Jalali date conversion and monthly aggregation. Settings can create a consistent SQLite snapshot, validate and restore a selected backup, or reset the database. Backup creation uses `VACUUM INTO` for a sibling staging file, validates it, and then promotes it to the selected destination. When replacing an existing backup, the previous file is moved aside and the service attempts to put it back if promotion fails. Restore checks the supported schema version, required Hesab tables and balance view, foreign-key consistency, and SQLite integrity before changing the active file. It stages the selected file and retains a rollback copy until the replacement opens successfully. On caught failures, the service attempts to restore the prior file; filesystem failures during replacement or recovery can prevent that attempt from completing and may leave `.rollback`, `.restore`, or uniquely named staging files. An abrupt process exit after the active file is moved can also leave the database unavailable with a `.rollback` file; startup does not automatically recover that file, so manual recovery may be needed before reopening the app. File rename behavior is filesystem-dependent and is not assumed to be atomic. Transaction dates are accepted as Dart `DateTime` values and stored as ISO Gregorian calendar dates; dashboard period selection converts Afghan Jalali dates at the service boundary. Keep all SQL parameterized in repositories and never run SQL from widgets.
