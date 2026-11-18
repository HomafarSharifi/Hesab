class FinancialTransactionRecord {
  const FinancialTransactionRecord({
    required this.id,
    required this.walletId,
    required this.walletName,
    required this.date,
    required this.type,
    required this.amountMinor,
    this.note,
    this.reversalOfId,
  });

  final int id;
  final int walletId;
  final String walletName;
  final String date;
  final String type;
  final int amountMinor;
  final String? note;
  final int? reversalOfId;

  factory FinancialTransactionRecord.fromMap(Map<String, Object?> map) =>
      FinancialTransactionRecord(
        id: map['transaction_id']! as int,
        walletId: map['wallet_id']! as int,
        walletName: map['wallet_name']! as String,
        date: map['transaction_date']! as String,
        type: map['transaction_type']! as String,
        amountMinor: map['amount_minor']! as int,
        note: map['note'] as String?,
        reversalOfId: map['reversal_of_transaction_id'] as int?,
      );
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.transactionId,
    required this.walletId,
    required this.walletName,
    required this.date,
    required this.amountMinor,
    required this.itemId,
    required this.itemName,
    required this.categoryName,
    required this.unitName,
    required this.quantityCenti,
    required this.unitPriceMinor,
    required this.isReversed,
    this.note,
  });

  final int id;
  final int transactionId;
  final int walletId;
  final String walletName;
  final String date;
  final int amountMinor;
  final int itemId;
  final String itemName;
  final String categoryName;
  final String unitName;
  final int quantityCenti;
  final int unitPriceMinor;
  final bool isReversed;
  final String? note;

  factory ExpenseRecord.fromMap(Map<String, Object?> map) => ExpenseRecord(
    id: map['expense_id']! as int,
    transactionId: map['transaction_id']! as int,
    walletId: map['wallet_id']! as int,
    walletName: map['wallet_name']! as String,
    date: map['transaction_date']! as String,
    amountMinor: map['amount_minor']! as int,
    itemId: map['item_id']! as int,
    itemName: map['item_name']! as String,
    categoryName: map['category_name']! as String,
    unitName: map['unit_name']! as String,
    quantityCenti: map['quantity_centi']! as int,
    unitPriceMinor: map['unit_price_minor']! as int,
    isReversed: map['is_reversed'] == 1,
    note: map['note'] as String?,
  );
}

class ReportSummary {
  const ReportSummary({
    required this.totalExpenseMinor,
    required this.totalReceivedMinor,
    required this.purchaseCount,
    required this.highestPurchaseMinor,
    required this.mostPurchasedItem,
    required this.expenseByCategory,
    required this.purchaseCountByCategory,
    required this.expensesByMonth,
  });

  final int totalExpenseMinor;
  final int totalReceivedMinor;
  final int purchaseCount;
  final int? highestPurchaseMinor;
  final String? mostPurchasedItem;
  final Map<String, int> expenseByCategory;
  final Map<String, int> purchaseCountByCategory;
  final Map<String, int> expensesByMonth;
}
