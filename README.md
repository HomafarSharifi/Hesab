# Hesab

Hesab is a Dari-first financial management application for Windows desktop, built with Flutter and Dart. Its interface uses right-to-left Dari, the Jalali calendar with Afghan month names, and the supplied Yekan Bakh fonts in `asset/YekanBakh/`.

## Product scope

Implemented workflows include local wallets, deposits and withdrawals, atomic purchases with matching expenses, purchase reversal, category/unit/item management, normalized Dari/Persian names, Jalali period reports, dashboard summaries/charts, and validated local database backup/restore. Settings also provides a confirmed database reset and app version display. The Expenses screen supports filtered 50-row pagination and page-based XLSX/CSV export; multiple CSV pages are packaged into one ZIP file. Purchase entry supports selecting or creating a product, category, and unit within the atomic purchase workflow. All tabs share a responsive Jalali month/year/custom-range header; the custom range uses one dialog with start and end date pickers. The RTL shell supports compact and desktop navigation, and both light and dark themes use the supplied Yekan Bakh font. The piggy-bank mark is used in the app shell and Windows app icon. The application uses one currency, Afghan Afghani (AFN).

Wallet management also supports wallet details, initial funding, audited metadata edits, and chronological wallet activity history with deposit, purchase, withdrawal, and reversal records.

Confirmed financial rules include zero-balance wallets funded by deposits; atomic purchases with exactly one matching expense; rejection of insufficient-funds purchases by default; and reversal workflows for correcting committed transactions. See [AGENTS.md](AGENTS.md) for the full project conventions and confirmed rules.

## Technology

- Flutter and Dart
- SQLite for local storage
- `excel` for typed XLSX workbook generation and `file_picker` for the native Windows save dialog
- `archive` for packaging multiple selected CSV pages into one ZIP file
- Windows desktop as the initial target

## Development status

The repository includes the supplied dashboard reference (`UI refence.png`), logical schema (`database schema.txt`), and Yekan Bakh font assets. The application opens a local SQLite database at schema version 5. Financial records are immutable; corrections use reversal transactions. Purchase totals use arbitrary-precision integer arithmetic and round positive half-minor-unit ties up. Backups use consistent SQLite snapshots. Restore validates the supported schema version, required tables, foreign-key relationships, and database integrity before replacing the active database. Replacement keeps a rollback copy while the new database is opened, and attempts recovery if replacement fails; filesystem failures can also prevent rollback and may leave recovery files. See [docs/database.md](docs/database.md) for details.

Empty screens now use a shared Dari message, flow-specific action, and a cohesive set of SVG illustrations in `asset/illustrations/`. See [docs/empty_states.md](docs/empty_states.md) for the filenames and directions.

## Setup

From the project directory, run `flutter pub get`, then `flutter build windows`. A Windows Release build has been verified with the Flutter SDK installed on this machine; the executable is written to `build/windows/x64/runner/Release/hesab.exe`.

Run `flutter test` for the test suite and `flutter analyze` for static analysis. See [docs/database.md](docs/database.md) for the version 1 SQLite schema baseline, current schema version, exact-number rules, migration strategy, and current boundaries.

## License

No project license has been selected yet.
