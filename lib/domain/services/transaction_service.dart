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

  Future<void> createWalletWithInitialDeposit({
    required String walletName,
    required int amountMinor,
    String? description,
  }) async {
    final name = _validateName(walletName, 45, 'نام کیف پول');
    if (amountMinor < 0 || amountMinor > AmountCodec.maximumMinorUnits) {
      throw const AppFailure('مبلغ باید بیشتر از صفر و در محدوده مجاز باشد.');
    }
    await _database.transaction((transaction) async {
      final catalog = CatalogRepository(transaction);
      final normalizedName = NameNormalizer.normalize(name);
      if (await catalog.walletNameExists(normalizedName)) {
        throw const AppFailure('این کیف پول پیش از این ثبت شده است.');
      }
      final walletId = await catalog.createWallet(name, normalizedName);
      await transaction.update(
        'wallet',
        {'description': _cleanNote(description)},
        where: 'wallet_id = ?',
        whereArgs: [walletId],
      );
      await transaction.insert('wallet_activity', {
        'wallet_id': walletId,
        'event_type': 'created',
        'details': description,
      });
      if (amountMinor > 0) {
        final transactionId = await FinancialRepository(transaction)
            .insertTransaction(
              walletId: walletId,
              date: _dateOnly(DateTime.now()),
              type: 'deposit',
              amountMinor: amountMinor,
              note: 'موجودی آغازین',
            );
        await transaction.insert('wallet_activity', {
          'wallet_id': walletId,
          'event_type': 'deposit',
          'transaction_id': transactionId,
          'details': 'موجودی آغازین',
        });
      }
    });
  }

  Future<void> updateWalletProfile({
    required int walletId,
    required String name,
    required String? description,
  }) async {
    final cleanName = _validateName(name, 45, 'نام کیف پول');
    await _database.transaction((transaction) async {
      final rows = await transaction.query(
        'wallet',
        where: 'wallet_id = ? AND archived_at IS NULL',
        whereArgs: [walletId],
        limit: 1,
      );
      if (rows.isEmpty) throw const AppFailure('کیف پول انتخاب‌شده فعال نیست.');
      final old = rows.single;
      final oldName = old['wallet_name']! as String;
      final oldDescription = old['description'] as String?;
      final cleanDescription = _cleanNote(description);
      if (oldName == cleanName && oldDescription == cleanDescription) return;
      final normalized = NameNormalizer.normalize(cleanName);
      final existing = await transaction.query(
        'wallet',
        columns: ['wallet_id'],
        where: 'normalized_name = ? AND wallet_id <> ?',
        whereArgs: [normalized, walletId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw const AppFailure('این کیف پول پیش از این ثبت شده است.');
      }
      await transaction.update(
        'wallet',
        {
          'wallet_name': cleanName,
          'normalized_name': normalized,
          'description': cleanDescription,
        },
        where: 'wallet_id = ?',
        whereArgs: [walletId],
      );
      final changes = <String>[];
      if (oldName != cleanName) changes.add('نام: $oldName ← $cleanName');
      if (oldDescription != cleanDescription) {
        changes.add(
          'توضیحات: ${oldDescription ?? '—'} ← ${cleanDescription ?? '—'}',
        );
      }
      await transaction.insert('wallet_activity', {
        'wallet_id': walletId,
        'event_type': 'updated',
        'details': changes.join('\n'),
      });
    });
  }

  Future<List<Map<String, Object?>>> walletActivities(
    int walletId, {
    int? limit,
  }) async {
    final suffix = limit == null ? '' : ' LIMIT $limit';
    return _database.rawQuery(
      '''
      SELECT * FROM (
        SELECT a.activity_id, a.wallet_id, a.event_type, a.occurred_at, a.details,
          t.transaction_date, t.amount_minor, t.note
        FROM wallet_activity a LEFT JOIN wallet_transaction t ON t.transaction_id = a.transaction_id
        WHERE a.wallet_id = ?
        UNION ALL
        SELECT t.transaction_id, t.wallet_id, t.transaction_type, t.created_at,
          t.note, t.transaction_date, t.amount_minor, t.note
        FROM wallet_transaction t
        WHERE t.wallet_id = ? AND t.transaction_type IN ('purchase', 'withdrawal', 'reversal')
      ) activity
      ORDER BY occurred_at DESC, activity_id DESC$suffix
    ''',
      [walletId, walletId],
    );
  }

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
    List<int>? walletIds,
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
        walletIds: walletIds,
        itemId: resolvedItemId,
        date: date,
        quantityCenti: quantityCenti,
        unitPriceMinor: unitPriceMinor,
        totalMinor: totalMinor,
        note: note,
      );
    });
  }

  Future<int> correctPurchaseWithNewProduct({
    required int originalTransactionId,
    required int walletId,
    required String productName,
    required DateTime correctionDate,
    required DateTime purchaseDate,
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
      final financial = FinancialRepository(transaction);
      final original = await financial.transactionById(originalTransactionId);
      if (original == null || original['transaction_type'] != 'purchase') {
        throw const AppFailure('خرید اصلی برای اصلاح معتبر نیست.');
      }
      if (await financial.hasReversal(originalTransactionId)) {
        throw const AppFailure('این خرید پیش از این برگشت داده شده است.');
      }

      await financial.insertTransaction(
        walletId: original['wallet_id']! as int,
        date: _dateOnly(correctionDate),
        type: 'reversal',
        amountMinor: original['amount_minor']! as int,
        note: _cleanNote('برگشت خرید برای اصلاح $originalTransactionId'),
        reversalOfId: originalTransactionId,
      );

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
        date: purchaseDate,
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
    List<int>? walletIds,
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
    final selectedWalletIds = walletIds ?? [walletId];
    if (selectedWalletIds.isEmpty ||
        selectedWalletIds.toSet().length != selectedWalletIds.length) {
      throw const AppFailure('کیف پول‌های انتخاب‌شده معتبر نیستند.');
    }
    var remaining = totalMinor;
    final allocations = <int, int>{};
    for (final selectedWalletId in selectedWalletIds) {
      if (await catalog.activeWallet(selectedWalletId) == null) {
        throw const AppFailure('یکی از کیف پول‌های انتخاب‌شده فعال نیست.');
      }
      final available = await financial.balanceMinor(selectedWalletId);
      final allocated = available < remaining ? available : remaining;
      if (allocated > 0) allocations[selectedWalletId] = allocated;
      remaining -= allocated;
      if (remaining == 0) break;
    }
    if (remaining > 0) {
      throw const AppFailure(
        'مجموع موجودی کیف پول‌های انتخاب‌شده برای این خرید کافی نیست.',
      );
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
    await financial.insertPurchaseAllocations(
      transactionId: transactionId,
      amountsByWallet: allocations,
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

  Future<ExpensePageResult> expensesPage({
    String? normalizedSearch,
    int? walletId,
    String? categoryName,
    DateTime? fromDate,
    DateTime? toDate,
    required int pageIndex,
    int pageSize = ExpensePageResult.defaultPageSize,
  }) => FinancialRepository(_database).expensesPage(
    normalizedSearch: normalizedSearch == null
        ? null
        : NameNormalizer.normalize(normalizedSearch),
    walletId: walletId,
    categoryName: categoryName,
    fromDate: fromDate == null ? null : _dateOnly(fromDate),
    toDate: toDate == null ? null : _dateOnly(toDate),
    pageIndex: pageIndex,
    pageSize: pageSize,
  );

  Future<int> countExpenses({
    String? normalizedSearch,
    int? walletId,
    String? categoryName,
    DateTime? fromDate,
    DateTime? toDate,
  }) => FinancialRepository(_database).countExpenses(
    normalizedSearch: normalizedSearch == null
        ? null
        : NameNormalizer.normalize(normalizedSearch),
    walletId: walletId,
    categoryName: categoryName,
    fromDate: fromDate == null ? null : _dateOnly(fromDate),
    toDate: toDate == null ? null : _dateOnly(toDate),
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
      final id = await FinancialRepository(transaction).insertTransaction(
        walletId: walletId,
        date: _dateOnly(date),
        type: type,
        amountMinor: amountMinor,
        note: _cleanNote(note),
      );
      if (type == 'deposit') {
        await transaction.insert('wallet_activity', {
          'wallet_id': walletId,
          'event_type': 'deposit',
          'transaction_id': id,
          'details': _cleanNote(note),
        });
      }
      return id;
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
