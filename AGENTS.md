# Hesab project instructions

## Product and current status

- Hesab is a Dari-first Flutter and Dart application with a responsive Windows desktop shell and compact navigation at narrow window widths.
- Hesab uses a local SQLite database. The RTL Dari shell, dashboard, database bootstrap/schema, repositories, catalog management, wallet deposits/withdrawals, atomic purchases, purchase reversals, and Jalali reports are implemented. Import/export and backup/restore remain planned.
- Treat the supplied UI reference (`UI refence.png`) as the visual source of truth. Implement it with real Flutter widgets and preserve its RTL composition.
- Use Dari throughout the product interface. Use the Jalali calendar with Afghan month names: حمل، ثور، جوزا، سرطان، اسد، سنبله، میزان، عقرب، قوس، جدی، دلو، حوت.
- Use the supplied Yekan Bakh font assets under `asset/YekanBakh/`; do not substitute a generic font without approval.
- Keep light and dark themes complete: surfaces, cards, selections, dialogs, text, controls, and navigation must use theme colors. The shared custom-range selector uses a single start/end dialog with Afghan Jalali date pickers.
- Use the piggy-bank mark for both the in-app brand and the Windows application icon.
- The product uses one application-wide currency: Afghan Afghani (AFN).

## Confirmed business rules

- Wallets start at zero; initial funds are deposits.
- Every purchase has exactly one expense. Deposits and withdrawals have no expense records.
- Save purchase and expense atomically. Reject purchases that exceed the wallet balance by default.
- Quantity and money have two decimal places. Display whole numbers without a decimal part and trim insignificant trailing zeros. Purchases use arbitrary-precision integer arithmetic; positive half-minor-unit ties round up (half-up), as documented in `docs/database.md`.
- Category and unit names are unique. Wallet names are unique after normalization. Item uniqueness is normalized name + category + unit.
- Archive referenced records rather than hard-deleting them. Correct committed transactions through a documented reversal workflow.
- Support local Dari/Persian text normalization, search, fuzzy suggestions, and duplicate prevention without cloud AI.
- Keep report import/export separate from complete backup/restore. Validate backups and protect against partial restoration.

## Architecture and code conventions

- Keep screens in separate files. Separate presentation, business services, repositories/data access, database setup/migrations, and import/export/backup code.
- Widgets must not access SQLite directly. Use parameterized queries, enabled foreign keys, transactions, validation, and the append-only migration strategy documented in `docs/database.md`.
- Preserve schema relationships and financial invariants. Do not invent business rules or redesign referenced screens without approval.
- Keep dependencies small and explain each major dependency in project documentation when introduced.
- Keep source code, tests, shared configuration, and this `AGENTS.md` tracked. Never commit secrets, private agent instructions, local financial databases, or user backup/export data.

## Verification expectations

- Before a bounded task, inspect the relevant instructions and Git status. State the objective, files in scope, and acceptance criteria before editing.
- After changes, run only relevant formatting, analysis, and tests when the Flutter/Dart toolchain is available. Report commands and actual outcomes; do not claim unverified success.
- For UI work, compare the running app against the supplied reference at a matching viewport. For data work, test the relevant integrity and rollback behavior.
- Do not commit or push unless explicitly requested.

## Handoff

- Keep the README's development status current and distinguish implemented behavior from planned requirements.
- At each task handoff, report completed work, unresolved issues, and one exact next task. Current next task: implement safe local database backup/restore with validation and rollback protection, then add recovery tests.
