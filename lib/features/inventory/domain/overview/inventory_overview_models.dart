// Dữ liệu màn Tổng quan Kho — khớp `InventoryWorkspace` + `InventoryLedgerRow` của web (inventory-api.ts).

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

double? _numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String _str(dynamic v) => v?.toString() ?? '';

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

List<Map<String, dynamic>> overviewJsonList(dynamic v) {
  if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  if (v is Map && v['items'] is List) return overviewJsonList(v['items']);
  return const [];
}

class OverviewWarehouse {
  final String id;
  final String code;
  final String name;

  const OverviewWarehouse({required this.id, required this.code, required this.name});

  factory OverviewWarehouse.fromJson(Map<String, dynamic> j) =>
      OverviewWarehouse(id: _str(j['id']), code: _str(j['code']), name: _str(j['name']));
}

class OverviewMaterial {
  final String id;
  final String code;
  final String name;
  final String category;
  final String unit;
  final double minStock;

  /// Giá nhập; `null` = chưa khai (khác 0).
  final double? purchasePrice;
  final bool isActive;

  const OverviewMaterial({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    required this.minStock,
    required this.purchasePrice,
    required this.isActive,
  });

  factory OverviewMaterial.fromJson(Map<String, dynamic> j) => OverviewMaterial(
        id: _str(j['id']),
        code: _str(j['code']),
        name: _str(j['name']),
        category: _str(j['category']),
        unit: _str(j['unit']),
        minStock: _num(j['minStock']),
        purchasePrice: _numOrNull(j['purchasePrice']),
        isActive: j['isActive'] != false,
      );
}

class OverviewAsset {
  final String id;
  final int taskTemplateCount;

  const OverviewAsset({required this.id, required this.taskTemplateCount});

  factory OverviewAsset.fromJson(Map<String, dynamic> j) {
    final tasks = j['taskTemplate'];
    return OverviewAsset(id: _str(j['id']), taskTemplateCount: tasks is List ? tasks.length : 0);
  }
}

/// Một dòng tồn (kho × vật tư) đã gắn lại mã kho, mã vật tư như web.
class OverviewStockRow {
  final String warehouseId;
  final String materialId;
  final double quantity;
  final double available;
  final String? warehouseCode;
  final String? materialCode;

  const OverviewStockRow({
    required this.warehouseId,
    required this.materialId,
    required this.quantity,
    required this.available,
    this.warehouseCode,
    this.materialCode,
  });

  factory OverviewStockRow.fromJson(Map<String, dynamic> j, {String? warehouseCode, String? materialCode}) =>
      OverviewStockRow(
        warehouseId: _str(j['warehouseId']),
        materialId: _str(j['materialId']),
        quantity: _num(j['quantity']),
        available: _num(j['available']),
        warehouseCode: warehouseCode,
        materialCode: materialCode,
      );
}

/// Bút toán sổ cái (`InventoryTransaction`).
class OverviewLedgerRow {
  final String id;
  final String transactionCode;
  final String materialId;
  final String type;
  final double quantity;
  final String createdAt;

  const OverviewLedgerRow({
    required this.id,
    required this.transactionCode,
    required this.materialId,
    required this.type,
    required this.quantity,
    required this.createdAt,
  });

  factory OverviewLedgerRow.fromJson(Map<String, dynamic> j) => OverviewLedgerRow(
        id: _str(j['id']),
        transactionCode: _str(j['transactionCode']),
        materialId: _str(j['materialId']),
        type: _str(j['type']),
        quantity: _num(j['quantity']),
        createdAt: _str(j['createdAt']),
      );
}

class InventoryOverviewWorkspace {
  final List<OverviewWarehouse> warehouses;
  final List<OverviewMaterial> materials;
  final List<OverviewAsset> assets;
  final List<OverviewStockRow> stock;
  late final Map<String, OverviewMaterial> materialByCode = {for (final m in materials) m.code: m};
  late final Map<String, OverviewMaterial> materialById = {for (final m in materials) m.id: m};

  InventoryOverviewWorkspace({
    required this.warehouses,
    required this.materials,
    required this.assets,
    required this.stock,
  });
}

/// Đọc `dashboard.cards` từ snapshot `/settings`: `{ 'dashboard.cards': { value: { cardIds: [...] } } }`.
List<String> parseDashboardCardIds(dynamic snapshot) {
  final entry = _map(_map(snapshot)['dashboard.cards']);
  final ids = _map(entry['value'])['cardIds'];
  if (ids is! List) return const [];
  return ids.map((e) => e.toString()).toList();
}
