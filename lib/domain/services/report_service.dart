import '../../core/calendar/jalali_date.dart';
import '../../data/models/financial_models.dart';
import '../../data/repositories/report_repository.dart';

class ReportService {
  const ReportService(this._repository);

  final ReportRepository _repository;

  Future<Map<String, int>> itemExpensesByMonth({
    required int itemId,
    required int jalaliYear,
  }) async {
    final rows = await _repository.itemPurchaseAmounts(itemId: itemId);
    final totals = <String, int>{};
    for (final row in rows) {
      final jalali = JalaliDate.fromGregorian(DateTime.parse(row.date));
      if (jalali.year != jalaliYear) continue;
      final key = jalali.month.toString().padLeft(2, '0');
      totals.update(
        key,
        (value) => value + row.amountMinor,
        ifAbsent: () => row.amountMinor,
      );
    }
    return totals;
  }

  Future<Map<String, int>> expensesByDate({
    DateTime? fromDate,
    DateTime? toDate,
  }) => _repository.expensesByDate(fromDate: fromDate, toDate: toDate);

  Future<ReportSummary> summary({DateTime? fromDate, DateTime? toDate}) async {
    final data = await _repository.summary(fromDate: fromDate, toDate: toDate);
    final monthlyTotals = <String, int>{};
    for (final purchase in data.purchases) {
      final gregorian = DateTime.parse(purchase.date);
      final jalali = JalaliDate.fromGregorian(gregorian);
      final key =
          '${jalali.year.toString().padLeft(4, '0')}-'
          '${jalali.month.toString().padLeft(2, '0')}';
      monthlyTotals.update(
        key,
        (amount) => amount + purchase.amountMinor,
        ifAbsent: () => purchase.amountMinor,
      );
    }

    return ReportSummary(
      totalExpenseMinor: data.totalExpenseMinor,
      totalReceivedMinor: data.totalReceivedMinor,
      purchaseCount: data.purchaseCount,
      highestPurchaseMinor: data.highestPurchaseMinor,
      mostPurchasedItem: data.mostPurchasedItem,
      expenseByCategory: data.expenseByCategory,
      purchaseCountByCategory: data.purchaseCountByCategory,
      expensesByMonth: monthlyTotals,
    );
  }
}
