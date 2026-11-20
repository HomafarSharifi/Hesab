import '../../../core/calendar/jalali_date.dart';
import '../../../data/models/financial_models.dart';

class ExpenseExportTable {
  const ExpenseExportTable._();

  static const headers = <String>[
    'شماره',
    'تاریخ',
    'جنس',
    'دسته‌بندی',
    'کیف پول',
    'مقدار',
    'واحد',
    'قیمت فی واحد (AFN)',
    'مجموع (AFN)',
    'یادداشت',
  ];

  static List<Object> valuesFor(ExpenseRecord expense, int rowNumber) {
    final date = DateTime.parse(expense.date);
    return [
      rowNumber,
      JalaliDate.fromGregorian(date).fullDate,
      expense.itemName,
      expense.categoryName,
      expense.walletName,
      expense.quantityCenti / 100,
      expense.unitName,
      expense.unitPriceMinor / 100,
      expense.amountMinor / 100,
      expense.note ?? '',
    ];
  }
}
