class CategoryRecord {
  const CategoryRecord({required this.id, required this.name, this.archivedAt});

  final int id;
  final String name;
  final String? archivedAt;

  factory CategoryRecord.fromMap(Map<String, Object?> map) => CategoryRecord(
    id: map['category_id']! as int,
    name: map['category_name']! as String,
    archivedAt: map['archived_at'] as String?,
  );
}

class UnitRecord {
  const UnitRecord({required this.id, required this.name, this.archivedAt});

  final int id;
  final String name;
  final String? archivedAt;

  factory UnitRecord.fromMap(Map<String, Object?> map) => UnitRecord(
    id: map['unit_id']! as int,
    name: map['unit_name']! as String,
    archivedAt: map['archived_at'] as String?,
  );
}

class ItemRecord {
  const ItemRecord({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.unitId,
    required this.unitName,
    this.archivedAt,
  });

  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final int unitId;
  final String unitName;
  final String? archivedAt;

  factory ItemRecord.fromMap(Map<String, Object?> map) => ItemRecord(
    id: map['item_id']! as int,
    name: map['item_name']! as String,
    categoryId: map['category_id']! as int,
    categoryName: map['category_name']! as String,
    unitId: map['unit_id']! as int,
    unitName: map['unit_name']! as String,
    archivedAt: map['archived_at'] as String?,
  );
}

class WalletRecord {
  const WalletRecord({
    required this.id,
    required this.name,
    required this.balanceMinor,
    this.purchaseCount = 0,
    this.archivedAt,
    this.createdAt,
    this.description,
  });

  final int id;
  final String name;
  final int balanceMinor;
  final int purchaseCount;
  final String? archivedAt;
  final String? createdAt;
  final String? description;

  factory WalletRecord.fromMap(Map<String, Object?> map) => WalletRecord(
    id: map['wallet_id']! as int,
    name: map['wallet_name']! as String,
    balanceMinor: map['balance_minor']! as int,
    purchaseCount: map['purchase_count'] as int? ?? 0,
    archivedAt: map['archived_at'] as String?,
    createdAt: map['created_at'] as String?,
    description: map['description'] as String?,
  );
}
