import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/financial_models.dart';

class FinancialRepository {
  const FinancialRepository(this._database);

  final DatabaseExecutor _database;

  Future<int> balanceMinor(int walletId) async {
    final rows = await _database.query(
      'wallet_balances',
      columns: ['balance_minor'],
      where: 'wallet_id = ?',
      whereArgs: [walletId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return rows.single['balance_minor']! as int;
  }

  Future<int> insertTransaction({
    required int walletId,
    required String date,
    required String type,
    required int amountMinor,
    String? note,
    int? reversalOfId,
  }) => _database.insert('wallet_transaction', {
    'wallet_id': walletId,
    'transaction_date': date,
    'transaction_type': type,
    'amount_minor': amountMinor,
    'note': note,
    'reversal_of_transaction_id': reversalOfId,
  });

  Future<int> insertExpense({
    required int transactionId,
    required int itemId,
    required int quantityMilli,
    required int unitPriceMinor,
    String? note,
  }) => _database.insert('expense', {
    'transaction_id': transactionId,
    'item_id': itemId,
    'quantity_milli': quantityMilli,
    'unit_price_minor': unitPriceMinor,
    'note': note,
  });

  Future<Map<String, Object?>?> transactionById(int transactionId) async {
    final rows = await _database.query(
      'wallet_transaction',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<bool> hasReversal(int transactionId) async =>
      ((await _database.rawQuery(
            'SELECT COUNT(*) FROM wallet_transaction WHERE reversal_of_transaction_id = ?',
            [transactionId],
          )).single.values.first
          as int) !=
      0;

  Future<List<FinancialTransactionRecord>> transactions({
    int? walletId,
    String? type,
    String? fromDate,
    String? toDate,
    int limit = 500,
    int offset = 0,
  }) async {
    final clauses = <String>[];
    final arguments = <Object?>[];
    if (walletId != null) {
      clauses.add('t.wallet_id = ?');
      arguments.add(walletId);
    }
    if (type != null) {
      clauses.add('t.transaction_type = ?');
      arguments.add(type);
    }
    if (fromDate != null) {
      clauses.add('t.transaction_date >= ?');
      arguments.add(fromDate);
    }
    if (toDate != null) {
      clauses.add('t.transaction_date <= ?');
      arguments.add(toDate);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = await _database.rawQuery(
      '''
      SELECT t.transaction_id, t.wallet_id, w.wallet_name,
             t.transaction_date, t.transaction_type, t.amount_minor,
             t.note, t.reversal_of_transaction_id
      FROM wallet_transaction t
      JOIN wallet w ON w.wallet_id = t.wallet_id
      $where
      ORDER BY t.transaction_date DESC, t.transaction_id DESC
      LIMIT ? OFFSET ?
      ''',
      [...arguments, limit, offset],
    );
    return rows.map(FinancialTransactionRecord.fromMap).toList();
  }

  Future<List<ExpenseRecord>> expenses({
    String? normalizedSearch,
    int? walletId,
    String? categoryName,
    String? fromDate,
    String? toDate,
    int limit = 500,
    int offset = 0,
  }) async {
    final clauses = <String>["t.transaction_type = 'purchase'"];
    final arguments = <Object?>[];
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      clauses.add('instr(i.normalized_name, ?) > 0');
      arguments.add(normalizedSearch);
    }
    if (walletId != null) {
      clauses.add('t.wallet_id = ?');
      arguments.add(walletId);
    }
    if (categoryName != null) {
      clauses.add('c.category_name = ?');
      arguments.add(categoryName);
    }
    if (fromDate != null) {
      clauses.add('t.transaction_date >= ?');
      arguments.add(fromDate);
    }
    if (toDate != null) {
      clauses.add('t.transaction_date <= ?');
      arguments.add(toDate);
    }
    final rows = await _database.rawQuery(
      '''
      SELECT e.expense_id, e.transaction_id, t.wallet_id, w.wallet_name,
             t.transaction_date, t.amount_minor, e.item_id, i.item_name,
             c.category_name, u.unit_name, e.quantity_milli,
             e.unit_price_minor, e.note,
             CASE WHEN EXISTS (
               SELECT 1 FROM wallet_transaction reversal
               WHERE reversal.reversal_of_transaction_id = t.transaction_id
             ) THEN 1 ELSE 0 END AS is_reversed
      FROM expense e
      JOIN wallet_transaction t ON t.transaction_id = e.transaction_id
      JOIN wallet w ON w.wallet_id = t.wallet_id
      JOIN item i ON i.item_id = e.item_id
      JOIN category c ON c.category_id = i.category_id
      JOIN unit u ON u.unit_id = i.unit_id
      WHERE ${clauses.join(' AND ')}
      ORDER BY t.transaction_date DESC, t.transaction_id DESC
      LIMIT ? OFFSET ?
      ''',
      [...arguments, limit, offset],
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }
}
