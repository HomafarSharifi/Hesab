import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/errors/app_failure.dart';
import '../../core/finance/amount_codec.dart';
import '../../core/text/name_normalizer.dart';
import '../../data/models/financial_models.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/financial_repository.dart';

class TransactionService {
  const TransactionService(this._database);

  final Database _database;

  Future<int> deposit({
    required int walletId,
    required DateTime date,
    required int amountMinor,
    String? note,
  }) => _recordSimpleTransaction(
    walletId: walletId,
    date: date,
    amountMinor: amountMinor,
    type: 'deposit',
    note: note,
  );

  Future<int> withdrawal({
    required int walletId,
    required DateTime date,
    required int amountMinor,
    String? note,
  }) => _recordSimpleTransaction(
    walletId: walletId,
    date: date,
    amountMinor: amountMinor,
    type: 'withdrawal',
    note: note,
  );

  Future<int> purchase({
    required int walletId,
    required int itemId,
    required DateTime date,
    required int quantityCenti,
    required int unitPriceMinor,
    String? note,
  }) async {
    final totalMinor = AmountCodec.calculatePurchaseTotalMinor(
      quantityCenti: quantityCenti,
      unitPriceMinor: unitPriceMinor,
    );
    return _database.transaction(
      (transaction) => _recordPurchase(
        transaction,
        walletId: walletId,
        itemId: itemId,
        date: date,
        quantityCenti: quantityCenti,
        unitPriceMinor: unitPriceMinor,
        totalMinor: totalMinor,
        note: note,
      ),
    );
  }

  Future<int> purchaseWithNewProduct({
    required int walletId,
    required String productName,
    required DateTime date,
    required int quantityCenti,
    required int unitPriceMinor,
    int? categoryId,
    String? newCategoryName,
    int? unitId,
    String? newUnitName,
    String? note,
  }) async {
    final name = _validateName(productName, 45, 'نام جنس');
    final normalizedName = NameNormalizer.normalize(name);
    final totalMinor = AmountCodec.calculatePurchaseTotalMinor(
      quantityCenti: quantityCenti,
      unitPriceMinor: unitPriceMinor,
    );

    return _database.transaction((transaction) async {
      final catalog = CatalogRepository(transaction);
      if (await catalog.activeWallet(walletId) == null) {
        throw const AppFailure('کیف پول انتخاب‌شده فعال نیست.');
      }
      final resolvedCategoryId = await _resolveCategory(
        catalog,
        categoryId: categoryId,
        newName: newCategoryName,
      );
      final resolvedUnitId = await _resolveUnit(
        catalog,
        unitId: unitId,
        newName: newUnitName,
      );

      final existing = await catalog.activeItemByKey(
        normalizedName: normalizedName,
        categoryId: resolvedCategoryId,
        unitId: resolvedUnitId,
      );
      final int resolvedItemId;
      if (existing != null) {
        resolvedItemId = existing.id;
      } else {
        if (await catalog.itemNameExists(
          normalizedName: normalizedName,
          categoryId: resolvedCategoryId,
          unitId: resolvedUnitId,
        )) {
          throw const AppFailure(
            'جنس هم‌نام در بایگانی موجود است؛ جنس دیگری انتخاب کنید.',
          );
        }
        resolvedItemId = await catalog.createItem(
          name: name,
          normalizedName: normalizedName,
          categoryId: resolvedCategoryId,
          unitId: resolvedUnitId,
        );
      }

      return _recordPurchase(
        transaction,
        walletId: walletId,
        itemId: resolvedItemId,
        date: date,
        quantityCenti: quantityCenti,
        unitPriceMinor: unitPriceMinor,
        totalMinor: totalMinor,
        note: note,
      );
    });
  }

  Future<int> _recordPurchase(
    DatabaseExecutor transaction, {
    required int walletId,
    required int itemId,
    required DateTime date,
    required int quantityCenti,
    required int unitPriceMinor,
    required int totalMinor,
    String? note,
  }) async {
    final catalog = CatalogRepository(transaction);
    if (await catalog.activeWallet(walletId) == null) {
      throw const AppFailure('کیف پول انتخاب‌شده فعال نیست.');
    }
    if (await catalog.activeItem(itemId) == null) {
      throw const AppFailure('جنس انتخاب‌شده فعال نیست.');
    }
    final financial = FinancialRepository(transaction);
    if (await financial.balanceMinor(walletId) < totalMinor) {
      throw const AppFailure('موجودی کیف پول برای این خرید کافی نیست.');
    }
    final cleanNote = _cleanNote(note);
    final transactionId = await financial.insertTransaction(
      walletId: walletId,
      date: _dateOnly(date),
      type: 'purchase',
      amountMinor: totalMinor,
      note: cleanNote,
    );
    await financial.insertExpense(
      transactionId: transactionId,
      itemId: itemId,
      quantityCenti: quantityCenti,
      unitPriceMinor: unitPriceMinor,
      note: cleanNote,
    );
    return transactionId;
  }

  Future<int> _resolveCategory(
    CatalogRepository catalog, {
    required int? categoryId,
    required String? newName,
  }) async {
    if (categoryId != null) {
      if (!await catalog.activeCategoryExists(categoryId)) {
        throw const AppFailure('دسته‌بندی انتخاب‌شده فعال نیست.');
      }
      return categoryId;
    }
    if (newName == null) {
      throw const AppFailure('دسته‌بندی جنس را انتخاب کنید.');
    }
    final name = _validateName(newName, 45, 'نام دسته‌بندی');
    final normalized = NameNormalizer.normalize(name);
    final activeId = await catalog.activeCategoryIdByNormalizedName(normalized);
    if (activeId != null) return activeId;
    if (await catalog.categoryNameExists(normalized)) {
      throw const AppFailure('دسته‌بندی هم‌نام در بایگانی موجود است.');
    }
    return catalog.createCategory(name, normalized);
  }

  Future<int> _resolveUnit(
    CatalogRepository catalog, {
    required int? unitId,
    required String? newName,
  }) async {
    if (unitId != null) {
      if (!await catalog.activeUnitExists(unitId)) {
        throw const AppFailure('واحد انتخاب‌شده فعال نیست.');
      }
      return unitId;
    }
    if (newName == null) throw const AppFailure('واحد جنس را انتخاب کنید.');
    final name = _validateName(newName, 30, 'نام واحد');
    final normalized = NameNormalizer.normalize(name);
    final activeId = await catalog.activeUnitIdByNormalizedName(normalized);
    if (activeId != null) return activeId;
    if (await catalog.unitNameExists(normalized)) {
      throw const AppFailure('واحد هم‌نام در بایگانی موجود است.');
    }
    return catalog.createUnit(name, normalized);
  }

  static String _validateName(String input, int maximum, String field) {
    final value = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty || value.runes.length > maximum) {
      throw AppFailure('$field را درست وارد کنید.');
    }
    return value;
  }

  Future<int> reverse({
    required int transactionId,
    required DateTime date,
    String? note,
  }) => _database.transaction((transaction) async {
    final financial = FinancialRepository(transaction);
    final original = await financial.transactionById(transactionId);
    if (original == null || original['transaction_type'] == 'reversal') {
      throw const AppFailure('تراکنش اصلی برای برگشت معتبر نیست.');
    }
    if (await financial.hasReversal(transactionId)) {
      throw const AppFailure('این تراکنش پیش از این برگشت داده شده است.');
    }
    return financial.insertTransaction(
      walletId: original['wallet_id']! as int,
      date: _dateOnly(date),
      type: 'reversal',
      amountMinor: original['amount_minor']! as int,
      note: _cleanNote(note),
      reversalOfId: transactionId,
    );
  });

  Future<List<FinancialTransactionRecord>> transactions({
    int? walletId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 500,
    int offset = 0,
  }) => FinancialRepository(_database).transactions(
    walletId: walletId,
    type: type,
    fromDate: fromDate == null ? null : _dateOnly(fromDate),
    toDate: toDate == null ? null : _dateOnly(toDate),
    limit: limit,
    offset: offset,
  );

  Future<List<ExpenseRecord>> expenses({
    String? normalizedSearch,
    int? walletId,
    String? categoryName,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 500,
    int offset = 0,
  }) => FinancialRepository(_database).expenses(
    normalizedSearch: normalizedSearch == null
        ? null
        : NameNormalizer.normalize(normalizedSearch),
    walletId: walletId,
    categoryName: categoryName,
    fromDate: fromDate == null ? null : _dateOnly(fromDate),
    toDate: toDate == null ? null : _dateOnly(toDate),
    limit: limit,
    offset: offset,
  );

  Future<int> _recordSimpleTransaction({
    required int walletId,
    required DateTime date,
    required int amountMinor,
    required String type,
    String? note,
  }) {
    _validateAmount(amountMinor);
    return _database.transaction((transaction) async {
      if (await CatalogRepository(transaction).activeWallet(walletId) == null) {
        throw const AppFailure('کیف پول انتخاب‌شده فعال نیست.');
      }
      return FinancialRepository(transaction).insertTransaction(
        walletId: walletId,
        date: _dateOnly(date),
        type: type,
        amountMinor: amountMinor,
        note: _cleanNote(note),
      );
    });
  }

  static void _validateAmount(int amountMinor) {
    if (amountMinor <= 0 || amountMinor > AmountLimit.maximumMinor) {
      throw const AppFailure('مبلغ باید بیشتر از صفر و در محدوده مجاز باشد.');
    }
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String? _cleanNote(String? note) {
    final value = note?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

abstract final class AmountLimit {
  static const maximumMinor = 9999999999;
}
