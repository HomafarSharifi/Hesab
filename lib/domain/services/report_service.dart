import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/calendar/jalali_date.dart';
import '../../data/models/financial_models.dart';

class ReportService {
  const ReportService(this._database);

  final Database _database;

  Future<Map<String, int>> itemExpensesByMonth({
    required int itemId,
    required int jalaliYear,
  }) async {
    final rows = await _database.rawQuery(
      '''
      SELECT t.transaction_date, t.amount_minor
      FROM wallet_transaction t
      JOIN expense e ON e.transaction_id = t.transaction_id
      WHERE e.item_id = ?
        AND t.transaction_type = 'purchase'
        AND NOT EXISTS (
          SELECT 1 FROM wallet_transaction reversal
          WHERE reversal.reversal_of_transaction_id = t.transaction_id
        )
    ''',
      [itemId],
    );
    final totals = <String, int>{};
    for (final row in rows) {
      final jalali = JalaliDate.fromGregorian(
        DateTime.parse(row['transaction_date']! as String),
      );
      if (jalali.year != jalaliYear) continue;
      final key = jalali.month.toString().padLeft(2, '0');
      totals.update(
        key,
        (value) => value + (row['amount_minor']! as int),
        ifAbsent: () => row['amount_minor']! as int,
      );
    }
    return totals;
  }

  Future<Map<String, int>> expensesByDate({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final clauses = <String>[
      "t.transaction_type = 'purchase'",
      '''NOT EXISTS (
      SELECT 1 FROM wallet_transaction reversal
      WHERE reversal.reversal_of_transaction_id = t.transaction_id
    )''',
    ];
    final args = <Object?>[];
    if (fromDate != null) {
      clauses.add('t.transaction_date >= ?');
      args.add(_dateOnly(fromDate));
    }
    if (toDate != null) {
      clauses.add('t.transaction_date <= ?');
      args.add(_dateOnly(toDate));
    }
    final rows = await _database.rawQuery('''
      SELECT t.transaction_date, SUM(t.amount_minor) AS amount_minor
      FROM wallet_transaction t
      WHERE ${clauses.join(' AND ')}
      GROUP BY t.transaction_date
      ORDER BY t.transaction_date
    ''', args);
    return {
      for (final row in rows)
        row['transaction_date']! as String: row['amount_minor']! as int,
    };
  }

  Future<ReportSummary> summary({DateTime? fromDate, DateTime? toDate}) async {
    final clauses = <String>[
      "t.transaction_type = 'purchase'",
      '''NOT EXISTS (
        SELECT 1 FROM wallet_transaction reversal
        WHERE reversal.reversal_of_transaction_id = t.transaction_id
      )''',
    ];
    final arguments = <Object?>[];
    if (fromDate != null) {
      clauses.add('t.transaction_date >= ?');
      arguments.add(_dateOnly(fromDate));
    }
    if (toDate != null) {
      clauses.add('t.transaction_date <= ?');
      arguments.add(_dateOnly(toDate));
    }
    final where = clauses.join(' AND ');
    final totals = await _database.rawQuery('''
      SELECT COALESCE(SUM(t.amount_minor), 0) AS total_minor,
             COUNT(*) AS purchase_count,
             MAX(t.amount_minor) AS highest_minor
      FROM wallet_transaction t
      WHERE $where
      ''', arguments);
    final receivedRows = await _database.rawQuery(
      '''
      SELECT COALESCE(SUM(t.amount_minor), 0) AS total_minor
      FROM wallet_transaction t
      WHERE t.transaction_type = 'deposit'
        AND NOT EXISTS (
          SELECT 1 FROM wallet_transaction reversal
          WHERE reversal.reversal_of_transaction_id = t.transaction_id
        )
        ${fromDate == null ? '' : 'AND t.transaction_date >= ?'}
        ${toDate == null ? '' : 'AND t.transaction_date <= ?'}
      ''',
      [
        if (fromDate != null) _dateOnly(fromDate),
        if (toDate != null) _dateOnly(toDate),
      ],
    );
    final categoryRows = await _database.rawQuery('''
      SELECT c.category_name, COALESCE(SUM(t.amount_minor), 0) AS total_minor,
             COUNT(*) AS purchase_count
      FROM wallet_transaction t
      JOIN expense e ON e.transaction_id = t.transaction_id
      JOIN item i ON i.item_id = e.item_id
      JOIN category c ON c.category_id = i.category_id
      WHERE $where
      GROUP BY c.category_id, c.category_name
      ORDER BY total_minor DESC, c.category_name COLLATE NOCASE
      ''', arguments);
    final itemRows = await _database.rawQuery('''
      SELECT i.item_name, COUNT(*) AS purchase_count
      FROM wallet_transaction t
      JOIN expense e ON e.transaction_id = t.transaction_id
      JOIN item i ON i.item_id = e.item_id
      WHERE $where
      GROUP BY i.item_id, i.item_name
      ORDER BY purchase_count DESC, i.item_name COLLATE NOCASE
      LIMIT 1
      ''', arguments);
    final monthRows = await _database.rawQuery('''
      SELECT t.transaction_date, t.amount_minor
      FROM wallet_transaction t
      WHERE $where
      ''', arguments);

    final monthlyTotals = <String, int>{};
    for (final row in monthRows) {
      final gregorian = DateTime.parse(row['transaction_date']! as String);
      final jalali = JalaliDate.fromGregorian(gregorian);
      final key =
          '${jalali.year.toString().padLeft(4, '0')}-'
          '${jalali.month.toString().padLeft(2, '0')}';
      monthlyTotals.update(
        key,
        (amount) => amount + (row['amount_minor']! as int),
        ifAbsent: () => row['amount_minor']! as int,
      );
    }

    final result = totals.single;
    return ReportSummary(
      totalExpenseMinor: result['total_minor']! as int,
      totalReceivedMinor: receivedRows.single['total_minor']! as int,
      purchaseCount: result['purchase_count']! as int,
      highestPurchaseMinor: result['highest_minor'] as int?,
      mostPurchasedItem: itemRows.isEmpty
          ? null
          : itemRows.single['item_name']! as String,
      expenseByCategory: {
        for (final row in categoryRows)
          row['category_name']! as String: row['total_minor']! as int,
      },
      purchaseCountByCategory: {
        for (final row in categoryRows)
          row['category_name']! as String: row['purchase_count']! as int,
      },
      expensesByMonth: monthlyTotals,
    );
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
