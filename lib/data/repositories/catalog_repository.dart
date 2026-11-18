import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/catalog_models.dart';

class CatalogRepository {
  const CatalogRepository(this._database);

  final DatabaseExecutor _database;

  Future<List<CategoryRecord>> categories() async {
    final rows = await _database.query(
      'category',
      where: 'archived_at IS NULL',
      orderBy: 'category_name COLLATE NOCASE',
    );
    return rows.map(CategoryRecord.fromMap).toList();
  }

  Future<int> createCategory(String name, String normalizedName) =>
      _database.insert('category', {
        'category_name': name,
        'normalized_name': normalizedName,
      });

  Future<void> archiveCategory(int id, String archivedAt) async {
    await _database.update(
      'category',
      {'archived_at': archivedAt},
      where: 'category_id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<bool> activeCategoryExists(int id) async =>
      ((await _database.rawQuery(
            'SELECT COUNT(*) FROM category WHERE category_id = ? AND archived_at IS NULL',
            [id],
          )).single.values.first
          as int) ==
      1;

  Future<List<UnitRecord>> units() async {
    final rows = await _database.query(
      'unit',
      where: 'archived_at IS NULL',
      orderBy: 'unit_name COLLATE NOCASE',
    );
    return rows.map(UnitRecord.fromMap).toList();
  }

  Future<int> createUnit(String name, String normalizedName) => _database
      .insert('unit', {'unit_name': name, 'normalized_name': normalizedName});

  Future<void> archiveUnit(int id, String archivedAt) async {
    await _database.update(
      'unit',
      {'archived_at': archivedAt},
      where: 'unit_id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<bool> activeUnitExists(int id) async =>
      ((await _database.rawQuery(
            'SELECT COUNT(*) FROM unit WHERE unit_id = ? AND archived_at IS NULL',
            [id],
          )).single.values.first
          as int) ==
      1;

  Future<List<ItemRecord>> items({String? normalizedSearch}) async {
    final search = normalizedSearch?.trim() ?? '';
    final rows = await _database.rawQuery(
      '''
      SELECT i.item_id, i.item_name, i.category_id, c.category_name,
             i.unit_id, u.unit_name, i.archived_at
      FROM item i
      JOIN category c ON c.category_id = i.category_id
      JOIN unit u ON u.unit_id = i.unit_id
      WHERE i.archived_at IS NULL
        AND c.archived_at IS NULL
        AND u.archived_at IS NULL
        AND (? = '' OR instr(i.normalized_name, ?) > 0)
      ORDER BY i.item_name COLLATE NOCASE
      ''',
      [search, search],
    );
    return rows.map(ItemRecord.fromMap).toList();
  }

  Future<List<ItemRecord>> itemsForPurchase() => items();

  Future<ItemRecord?> activeItem(int id) async {
    final rows = await _database.rawQuery(
      '''
      SELECT i.item_id, i.item_name, i.category_id, c.category_name,
             i.unit_id, u.unit_name, i.archived_at
      FROM item i
      JOIN category c ON c.category_id = i.category_id
      JOIN unit u ON u.unit_id = i.unit_id
      WHERE i.item_id = ? AND i.archived_at IS NULL
        AND c.archived_at IS NULL AND u.archived_at IS NULL
      LIMIT 1
      ''',
      [id],
    );
    return rows.isEmpty ? null : ItemRecord.fromMap(rows.single);
  }

  Future<ItemRecord?> activeItemByKey({
    required String normalizedName,
    required int categoryId,
    required int unitId,
  }) async {
    final rows = await _database.rawQuery(
      '''
      SELECT i.item_id, i.item_name, i.category_id, c.category_name,
             i.unit_id, u.unit_name, i.archived_at
      FROM item i
      JOIN category c ON c.category_id = i.category_id
      JOIN unit u ON u.unit_id = i.unit_id
      WHERE i.normalized_name = ? AND i.category_id = ? AND i.unit_id = ?
        AND i.archived_at IS NULL AND c.archived_at IS NULL
        AND u.archived_at IS NULL
      LIMIT 1
      ''',
      [normalizedName, categoryId, unitId],
    );
    return rows.isEmpty ? null : ItemRecord.fromMap(rows.single);
  }

  Future<int?> activeCategoryIdByNormalizedName(String normalizedName) async {
    final rows = await _database.query(
      'category',
      columns: ['category_id'],
      where: 'normalized_name = ? AND archived_at IS NULL',
      whereArgs: [normalizedName],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['category_id']! as int;
  }

  Future<int?> activeUnitIdByNormalizedName(String normalizedName) async {
    final rows = await _database.query(
      'unit',
      columns: ['unit_id'],
      where: 'normalized_name = ? AND archived_at IS NULL',
      whereArgs: [normalizedName],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['unit_id']! as int;
  }

  Future<int> createItem({
    required String name,
    required String normalizedName,
    required int categoryId,
    required int unitId,
  }) => _database.insert('item', {
    'item_name': name,
    'normalized_name': normalizedName,
    'category_id': categoryId,
    'unit_id': unitId,
  });

  Future<void> archiveItem(int id, String archivedAt) async {
    await _database.update(
      'item',
      {'archived_at': archivedAt},
      where: 'item_id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<bool> categoryNameExists(String normalizedName) async =>
      _exists('category', 'normalized_name = ?', [normalizedName]);

  Future<bool> unitNameExists(String normalizedName) async =>
      _exists('unit', 'normalized_name = ?', [normalizedName]);

  Future<bool> walletNameExists(String normalizedName) async =>
      _exists('wallet', 'normalized_name = ?', [normalizedName]);

  Future<bool> itemNameExists({
    required String normalizedName,
    required int categoryId,
    required int unitId,
  }) => _exists(
    'item',
    'normalized_name = ? AND category_id = ? AND unit_id = ?',
    [normalizedName, categoryId, unitId],
  );

  Future<bool> _exists(
    String table,
    String where,
    List<Object?> arguments,
  ) async =>
      ((await _database.rawQuery(
            'SELECT COUNT(*) FROM $table WHERE $where',
            arguments,
          )).single.values.first
          as int) !=
      0;

  Future<List<WalletRecord>> wallets({bool includeArchived = false}) async {
    final rows = await _database.rawQuery('''
      SELECT w.wallet_id, w.wallet_name, w.archived_at, b.balance_minor
      FROM wallet w
      JOIN wallet_balances b ON b.wallet_id = w.wallet_id
      ${includeArchived ? '' : 'WHERE w.archived_at IS NULL'}
      ORDER BY w.wallet_name COLLATE NOCASE
      ''');
    return rows.map(WalletRecord.fromMap).toList();
  }

  Future<WalletRecord?> activeWallet(int id) async {
    final rows = await _database.rawQuery(
      '''
      SELECT w.wallet_id, w.wallet_name, w.archived_at, b.balance_minor
      FROM wallet w
      JOIN wallet_balances b ON b.wallet_id = w.wallet_id
      WHERE w.wallet_id = ? AND w.archived_at IS NULL
      LIMIT 1
      ''',
      [id],
    );
    return rows.isEmpty ? null : WalletRecord.fromMap(rows.single);
  }

  Future<int> createWallet(String name, String normalizedName) =>
      _database.insert('wallet', {
        'wallet_name': name,
        'normalized_name': normalizedName,
      });

  Future<void> archiveWallet(int id, String archivedAt) async {
    await _database.update(
      'wallet',
      {'archived_at': archivedAt},
      where: 'wallet_id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
  }
}
