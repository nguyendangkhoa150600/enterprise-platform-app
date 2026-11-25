// Dữ liệu của trang Kho hàng, tab Hàng hóa và Nhà kho (web `Material`, `Warehouse`,
// `MaterialInventory`, `InventoryTransaction`, `InventoryTradeCatalog`).

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

String? _str(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() : const <String>[];

/// Một mặt hàng (hàng hóa hoặc dịch vụ) trong danh mục Kho.
class GoodsMaterial {
  final String id;
  final String code;
  final String name;
  final String unit;
  final String kind;
  final bool isActive;
  final String? barcode;
  final String? tradeCategory;
  final String? tradeMode;
  final double? salePrice;
  final double? vatRate;
  final String? description;
  final String? createdBy;
  final String? createdAt;
  final double minStock;
  final double maxStock;

  const GoodsMaterial({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.kind,
    required this.isActive,
    this.barcode,
    this.tradeCategory,
    this.tradeMode,
    this.salePrice,
    this.vatRate,
    this.description,
    this.createdBy,
    this.createdAt,
    this.minStock = 0,
    this.maxStock = 0,
  });

  bool get isService => kind == 'SERVICE';

  factory GoodsMaterial.fromJson(Map<String, dynamic> j) => GoodsMaterial(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        unit: j['unit']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'STOCK',
        isActive: j['isActive'] != false,
        barcode: _str(j['barcode']),
        tradeCategory: _str(j['tradeCategory']),
        tradeMode: _str(j['tradeMode']),
        salePrice: _numOrNull(j['salePrice']),
        vatRate: _numOrNull(j['vatRate']),
        description: _str(j['description']),
        createdBy: _str(j['createdBy']),
        createdAt: _str(j['createdAt']),
        minStock: _num(j['minStock']),
        maxStock: _num(j['maxStock']),
      );
}

class GoodsWarehouse {
  final String id;
  final String code;
  final String name;

  const GoodsWarehouse({required this.id, required this.code, required this.name});

  factory GoodsWarehouse.fromJson(Map<String, dynamic> j) => GoodsWarehouse(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
      );
}

/// Dòng tồn của một mặt hàng ở một kho (`GET /warehouses/:code/stock`).
class GoodsStockRow {
  final String id;
  final String warehouseId;
  final String materialId;
  final double quantity;
  final double quantityReserved;
  final double quantityBlocked;
  final double available;
  final String? warehouseCode;
  final String? materialCode;

  const GoodsStockRow({
    required this.id,
    required this.warehouseId,
    required this.materialId,
    required this.quantity,
    required this.quantityReserved,
    required this.quantityBlocked,
    required this.available,
    this.warehouseCode,
    this.materialCode,
  });

  factory GoodsStockRow.fromJson(Map<String, dynamic> j, {String? warehouseCode, String? materialCode}) =>
      GoodsStockRow(
        id: j['id']?.toString() ?? '',
        warehouseId: j['warehouseId']?.toString() ?? '',
        materialId: j['materialId']?.toString() ?? '',
        quantity: _num(j['quantity']),
        quantityReserved: _num(j['quantityReserved']),
        quantityBlocked: _num(j['quantityBlocked']),
        available: _num(j['available']),
        warehouseCode: warehouseCode,
        materialCode: materialCode,
      );
}

/// Một bút toán trong lịch sử xuất nhập của một mã (`GET /materials/:code/history`).
class GoodsLedgerRow {
  final String id;
  final String transactionCode;
  final String warehouseId;
  final String type;
  final double quantity;
  final String? documentNumber;
  final String? createdBy;
  final String? createdAt;

  const GoodsLedgerRow({
    required this.id,
    required this.transactionCode,
    required this.warehouseId,
    required this.type,
    required this.quantity,
    this.documentNumber,
    this.createdBy,
    this.createdAt,
  });

  factory GoodsLedgerRow.fromJson(Map<String, dynamic> j) => GoodsLedgerRow(
        id: j['id']?.toString() ?? '',
        transactionCode: j['transactionCode']?.toString() ?? '',
        warehouseId: j['warehouseId']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        quantity: _num(j['quantity']),
        documentNumber: _str(j['documentNumber']),
        createdBy: _str(j['createdBy']),
        createdAt: _str(j['createdAt']),
      );
}

/// Danh mục khai ở Cài đặt: `catalog.trade` (phân loại, sử dụng) và `catalog.unit` (đơn vị tính).
class GoodsCatalog {
  final List<String> goodsCategories;
  final List<String> serviceCategories;
  final List<String> usageModes;
  final List<String> units;

  const GoodsCatalog({
    this.goodsCategories = const [],
    this.serviceCategories = const [],
    this.usageModes = const [],
    this.units = const [],
  });

  static const empty = GoodsCatalog();

  factory GoodsCatalog.fromSettings(Map<String, dynamic> settings) {
    Map<String, dynamic> valueOf(String key) {
      final entry = settings[key];
      if (entry is Map && entry['value'] is Map) return Map<String, dynamic>.from(entry['value'] as Map);
      return const {};
    }

    final trade = valueOf('catalog.trade');
    final unit = valueOf('catalog.unit');
    return GoodsCatalog(
      goodsCategories: _strings(trade['goodsCategories']),
      serviceCategories: _strings(trade['serviceCategories']),
      usageModes: _strings(trade['usageModes']),
      units: _strings(unit['units']),
    );
  }
}

/// Dữ liệu dùng chung của hai tab (web `InventoryWorkspace`: warehouses, materials, stock).
class GoodsWorkspace {
  final List<GoodsMaterial> materials;
  final List<GoodsWarehouse> warehouses;
  final List<GoodsStockRow> stock;

  const GoodsWorkspace({required this.materials, required this.warehouses, required this.stock});

  static const empty = GoodsWorkspace(materials: [], warehouses: [], stock: []);
}

/// Một dòng nhập Excel không thành công (web `ImportFailure`). `duplicate` là trùng mã với hàng đã có,
/// để tách khỏi lỗi dữ liệu khi xuất lại các dòng chưa nhập. `line` 0 là lỗi không gắn với dòng nào.
class GoodsImportFailure {
  final int line;
  final String message;
  final bool duplicate;

  const GoodsImportFailure(this.line, this.message, {this.duplicate = false});

  factory GoodsImportFailure.fromJson(Map<String, dynamic> j) => GoodsImportFailure(
        (j['line'] as num?)?.toInt() ?? 0,
        j['message']?.toString() ?? '',
        duplicate: j['duplicate'] == true,
      );
}

/// Kết quả nhập hàng hóa từ Excel (web `ImportMaterialsResult`, cộng dồn qua các lô).
class GoodsImportResult {
  final int created;

  /// Số dòng đã cập nhật vào mã có sẵn (chỉ khi xử lý trùng mã là UPDATE).
  final int updated;

  /// Dòng bỏ qua có chủ đích (mã đã có và giữ bản cũ); không phải lỗi.
  final List<GoodsImportFailure> skipped;
  final List<GoodsImportFailure> failures;

  const GoodsImportResult({
    this.created = 0,
    this.updated = 0,
    this.skipped = const [],
    this.failures = const [],
  });

  factory GoodsImportResult.fromJson(Map<String, dynamic> j) {
    List<GoodsImportFailure> list(dynamic v) => v is List
        ? v.whereType<Map>().map((e) => GoodsImportFailure.fromJson(Map<String, dynamic>.from(e))).toList()
        : const [];
    return GoodsImportResult(
      created: (j['created'] as num?)?.toInt() ?? 0,
      updated: (j['updated'] as num?)?.toInt() ?? 0,
      skipped: list(j['skipped']),
      failures: list(j['failures']),
    );
  }
}
