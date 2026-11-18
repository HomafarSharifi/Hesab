import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/errors/app_failure.dart';
import '../../core/text/name_normalizer.dart';
import '../../data/models/catalog_models.dart';
import '../../data/repositories/catalog_repository.dart';

class CatalogService {
  const CatalogService(this._repository);

  final CatalogRepository _repository;

  Future<List<CategoryRecord>> categories() => _repository.categories();
  Future<List<UnitRecord>> units() => _repository.units();
  Future<List<ItemRecord>> items({String? search}) async {
    final normalized = search == null ? null : NameNormalizer.normalize(search);
    return _repository.items(normalizedSearch: normalized);
  }

  Future<List<WalletRecord>> wallets({bool includeArchived = false}) =>
      _repository.wallets(includeArchived: includeArchived);

  Future<void> createCategory(String value) async {
    final name = _validateName(value, 45);
    final normalized = NameNormalizer.normalize(name);
    if (await _repository.categoryNameExists(normalized)) {
      throw const AppFailure('این دسته‌بندی پیش از این ثبت شده است.');
    }
    await _insert(
      () => _repository.createCategory(name, normalized),
      'دسته‌بندی',
    );
  }

  Future<void> createUnit(String value) async {
    final name = _validateName(value, 30);
    final normalized = NameNormalizer.normalize(name);
    if (await _repository.unitNameExists(normalized)) {
      throw const AppFailure('این واحد پیش از این ثبت شده است.');
    }
    await _insert(() => _repository.createUnit(name, normalized), 'واحد');
  }

  Future<void> createItem({
    required String name,
    required int categoryId,
    required int unitId,
  }) async {
    final itemName = _validateName(name, 45);
    final normalized = NameNormalizer.normalize(itemName);
    if (!await _repository.activeCategoryExists(categoryId) ||
        !await _repository.activeUnitExists(unitId)) {
      throw const AppFailure('دسته‌بندی یا واحد انتخاب‌شده معتبر نیست.');
    }
    if (await _repository.itemNameExists(
      normalizedName: normalized,
      categoryId: categoryId,
      unitId: unitId,
    )) {
      throw const AppFailure('این جنس با همین دسته‌بندی و واحد ثبت شده است.');
    }
    await _insert(
      () => _repository.createItem(
        name: itemName,
        normalizedName: normalized,
        categoryId: categoryId,
        unitId: unitId,
      ),
      'جنس',
    );
  }

  Future<void> createWallet(String value) async {
    final name = _validateName(value, 45);
    final normalized = NameNormalizer.normalize(name);
    if (await _repository.walletNameExists(normalized)) {
      throw const AppFailure('این کیف پول پیش از این ثبت شده است.');
    }
    await _insert(() => _repository.createWallet(name, normalized), 'کیف پول');
  }

  Future<void> archiveCategory(int id) =>
      _repository.archiveCategory(id, _now());
  Future<void> archiveUnit(int id) => _repository.archiveUnit(id, _now());
  Future<void> archiveItem(int id) => _repository.archiveItem(id, _now());
  Future<void> archiveWallet(int id) => _repository.archiveWallet(id, _now());

  Future<List<String>> itemNameSuggestions(String query) async {
    final values = (await _repository.items()).map((item) => item.name);
    return NameNormalizer.suggestions(query, values);
  }

  Future<void> _insert(Future<int> Function() action, String recordType) async {
    try {
      await action();
    } on DatabaseException catch (error) {
      if (error.toString().contains('UNIQUE constraint failed')) {
        throw AppFailure('$recordType تکراری است.');
      }
      rethrow;
    }
  }

  static String _validateName(String input, int maximumLength) {
    final name = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) throw const AppFailure('نام را وارد کنید.');
    if (name.runes.length > maximumLength) {
      throw AppFailure('نام نمی‌تواند بیشتر از $maximumLength حرف باشد.');
    }
    if (NameNormalizer.normalize(name).isEmpty) {
      throw const AppFailure('نام واردشده معتبر نیست.');
    }
    return name;
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();
}
