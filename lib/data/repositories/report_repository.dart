import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ReportRepository {
  const ReportRepository(this._database);

  final DatabaseExecutor _database;

  Future<Map<int, ({int receivedMinor, int spentMinor, int activityMinor})>>
  walletPeriodTotals({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final dateClauses = [
      if (fromDate != null) 'AND t.transaction_date >= ?',
      if (toDate != null) 'AND t.transaction_date <= ?',
    ].join(' ');
    final dateArguments = [
      if (fromDate != null) _dateOnly(fromDate),
      if (toDate != null) _dateOnly(toDate),
    ];
    final rows = await _database.rawQuery(
      '''
      WITH wallet_totals AS (
        SELECT t.wallet_id,
          SUM(CASE WHEN NOT EXISTS (
            SELECT 1 FROM wallet_transaction reversal
            WHERE reversal.reversal_of_transaction_id = t.transaction_id
          ) THEN t.amount_minor ELSE 0 END) AS received_minor,
          0 AS spent_minor, SUM(t.amount_minor) AS activity_minor
        FROM wallet_transaction t
        WHERE t.transaction_type = 'deposit'
          AND NOT EXISTS (
            SELECT 1 FROM wallet_transaction reversal
            WHERE reversal.reversal_of_transaction_id = t.transaction_id
          )
          $dateClauses
        GROUP BY t.wallet_id

        UNION ALL

        SELECT allocation.wallet_id, 0 AS received_minor,
          SUM(CASE WHEN NOT EXISTS (
            SELECT 1 FROM wallet_transaction reversal
            WHERE reversal.reversal_of_transaction_id = t.transaction_id
          ) THEN allocation.amount_minor ELSE 0 END) AS spent_minor,
          SUM(allocation.amount_minor) AS activity_minor
        FROM purchase_wallet_allocation allocation
        JOIN wallet_transaction t ON t.transaction_id = allocation.transaction_id
        WHERE t.transaction_type = 'purchase'
          AND NOT EXISTS (
            SELECT 1 FROM wallet_transaction reversal
            WHERE reversal.reversal_of_transaction_id = t.transaction_id
          )
          $dateClauses
        GROUP BY allocation.wallet_id

        UNION ALL

        SELECT t.wallet_id, 0 AS received_minor, 0 AS spent_minor,
          SUM(t.amount_minor) AS activity_minor
        FROM wallet_transaction t
        WHERE t.transaction_type = 'withdrawal'
          $dateClauses
        GROUP BY t.wallet_id
      )
      SELECT wallet_id, SUM(received_minor) AS received_minor,
        SUM(spent_minor) AS spent_minor, SUM(activity_minor) AS activity_minor
      FROM wallet_totals
      GROUP BY wallet_id
      ''',
      [...dateArguments, ...dateArguments, ...dateArguments],
    );
    return {
      for (final row in rows)
        row['wallet_id']! as int: (
          receivedMinor: row['received_minor']! as int,
          spentMinor: row['spent_minor']! as int,
          activityMinor: row['activity_minor']! as int,
        ),
    };
  }

  Future<List<ReportDatedAmount>> itemPurchaseAmounts({
    required int itemId,
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
    return [
      for (final row in rows)
        ReportDatedAmount(
          date: row['transaction_date']! as String,
          amountMinor: row['amount_minor']! as int,
        ),
    ];
  }

  Future<Map<String, int>> expensesByDate({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final filter = _purchaseFilter(fromDate: fromDate, toDate: toDate);
    final rows = await _database.rawQuery('''
      SELECT t.transaction_date, SUM(t.amount_minor) AS amount_minor
      FROM wallet_transaction t
      WHERE ${filter.where}
      GROUP BY t.transaction_date
      ORDER BY t.transaction_date
    ''', filter.arguments);
    return {
      for (final row in rows)
        row['transaction_date']! as String: row['amount_minor']! as int,
    };
  }

  Future<ReportSummaryData> summary({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final filter = _purchaseFilter(fromDate: fromDate, toDate: toDate);
    final totals = await _database.rawQuery('''
      SELECT COALESCE(SUM(t.amount_minor), 0) AS total_minor,
             COUNT(*) AS purchase_count,
             MAX(t.amount_minor) AS highest_minor
      FROM wallet_transaction t
      WHERE ${filter.where}
      ''', filter.arguments);
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
      WHERE ${filter.where}
      GROUP BY c.category_id, c.category_name
      ORDER BY total_minor DESC, c.category_name COLLATE NOCASE
      ''', filter.arguments);
    final itemRows = await _database.rawQuery('''
      SELECT i.item_name, COUNT(*) AS purchase_count
      FROM wallet_transaction t
      JOIN expense e ON e.transaction_id = t.transaction_id
      JOIN item i ON i.item_id = e.item_id
      WHERE ${filter.where}
      GROUP BY i.item_id, i.item_name
      ORDER BY purchase_count DESC, i.item_name COLLATE NOCASE
      LIMIT 1
      ''', filter.arguments);
    final purchaseRows = await _database.rawQuery('''
      SELECT t.transaction_date, t.amount_minor
      FROM wallet_transaction t
      WHERE ${filter.where}
      ''', filter.arguments);

    final totalRow = totals.single;
    return ReportSummaryData(
      totalExpenseMinor: totalRow['total_minor']! as int,
      totalReceivedMinor: receivedRows.single['total_minor']! as int,
      purchaseCount: totalRow['purchase_count']! as int,
      highestPurchaseMinor: totalRow['highest_minor'] as int?,
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
      purchases: [
        for (final row in purchaseRows)
          ReportDatedAmount(
            date: row['transaction_date']! as String,
            amountMinor: row['amount_minor']! as int,
          ),
      ],
    );
  }

  ({String where, List<Object?> arguments}) _purchaseFilter({
    DateTime? fromDate,
    DateTime? toDate,
  }) {
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
    return (where: clauses.join(' AND '), arguments: arguments);
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class ReportDatedAmount {
  const ReportDatedAmount({required this.date, required this.amountMinor});

  final String date;
  final int amountMinor;
}

class ReportSummaryData {
  const ReportSummaryData({
    required this.totalExpenseMinor,
    required this.totalReceivedMinor,
    required this.purchaseCount,
    required this.highestPurchaseMinor,
    required this.mostPurchasedItem,
    required this.expenseByCategory,
    required this.purchaseCountByCategory,
    required this.purchases,
  });

  final int totalExpenseMinor;
  final int totalReceivedMinor;
  final int purchaseCount;
  final int? highestPurchaseMinor;
  final String? mostPurchasedItem;
  final Map<String, int> expenseByCategory;
  final Map<String, int> purchaseCountByCategory;
  final List<ReportDatedAmount> purchases;
}
