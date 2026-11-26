import 'crm_json.dart';

/// Nhóm mặt hàng ở Kho (mã `kind`): hàng hoá có tồn, hoặc dịch vụ (contracts `CATALOG_MATERIAL_KINDS`).
class CrmCatalogKind {
  CrmCatalogKind._();
  static const String stock = 'STOCK';
  static const String service = 'SERVICE';
  static const List<String> values = [stock, service];
}

/// Tồn khả dụng của mặt hàng tại một kho.
class CrmCatalogMaterialStock {
  final String warehouseId;
  final String warehouseCode;
  final double available;

  const CrmCatalogMaterialStock({this.warehouseId = '', required this.warehouseCode, required this.available});

  factory CrmCatalogMaterialStock.fromJson(Map<String, dynamic> json) => CrmCatalogMaterialStock(
        warehouseId: CrmJson.str(json['warehouseId']),
        warehouseCode: CrmJson.str(json['warehouseCode']),
        available: CrmJson.number(json['available']),
      );
}

/// Mặt hàng trong danh mục Kho (`GET /catalog/materials`, contracts `CrmCatalogMaterial`).
class CrmCatalogMaterial {
  final String id;
  final String code;
  final String name;
  final String? unit;
  final String? kind;
  final String? category;

  /// Phân loại hàng hoá/dịch vụ khai ở Kho; rỗng là chưa khai.
  final String? tradeCategory;

  /// Giá bán khai ở Kho; rỗng là chưa khai.
  final double? salePrice;

  /// Thuế suất khai ở Kho (%); rỗng là chưa khai (tính 10%).
  final double? vatRate;

  /// Server có gửi trường `vatRate` không (web phân biệt `undefined` với `null` cho placeholder thuế suất).
  final bool hasVatRateField;

  /// Giá vốn bình quân hiện tại (ước tính); rỗng với dịch vụ.
  final double? avgCost;

  /// Tồn khả dụng gộp các kho; rỗng với dịch vụ.
  final double? totalAvailable;
  final List<CrmCatalogMaterialStock>? availableByWarehouse;

  const CrmCatalogMaterial({
    required this.id,
    required this.code,
    required this.name,
    this.unit,
    this.kind,
    this.category,
    this.tradeCategory,
    this.salePrice,
    this.vatRate,
    this.hasVatRateField = false,
    this.avgCost,
    this.totalAvailable,
    this.availableByWarehouse,
  });

  bool get isService => kind == CrmCatalogKind.service;

  factory CrmCatalogMaterial.fromJson(Map<String, dynamic> json) => CrmCatalogMaterial(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        unit: CrmJson.strOrNull(json['unit']),
        kind: CrmJson.strOrNull(json['kind']),
        category: CrmJson.strOrNull(json['category']),
        tradeCategory: CrmJson.strOrNull(json['tradeCategory']),
        salePrice: CrmJson.numOrNull(json['salePrice']),
        vatRate: CrmJson.numOrNull(json['vatRate']),
        hasVatRateField: json.containsKey('vatRate'),
        avgCost: CrmJson.numOrNull(json['avgCost']),
        totalAvailable: CrmJson.numOrNull(json['totalAvailable']),
        availableByWarehouse: json['availableByWarehouse'] is List
            ? CrmJson.list(json['availableByWarehouse'], CrmCatalogMaterialStock.fromJson)
            : null,
      );
}

/// Một trang tìm mặt hàng; `nextCursor` rỗng là hết (Kho không trả tổng số).
class CrmCatalogPage {
  final List<CrmCatalogMaterial> items;
  final String? nextCursor;

  const CrmCatalogPage({required this.items, this.nextCursor});

  factory CrmCatalogPage.fromJson(Object? raw) {
    final json = CrmJson.map(raw);
    final cursor = CrmJson.strOrNull(json['nextCursor']);
    return CrmCatalogPage(
      items: CrmJson.list(json['items'], CrmCatalogMaterial.fromJson),
      nextCursor: (cursor == null || cursor.isEmpty) ? null : cursor,
    );
  }
}

/// Kho của phân hệ Kho để chọn kho xuất/giữ hàng (`GET /catalog/warehouses`).
class CrmWarehouseOption {
  final String id;
  final String code;
  final String name;
  final bool isActive;

  const CrmWarehouseOption({required this.id, required this.code, required this.name, required this.isActive});

  factory CrmWarehouseOption.fromJson(Map<String, dynamic> json) => CrmWarehouseOption(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        isActive: CrmJson.boolean(json['isActive'], true),
      );
}

/// Tồn khả dụng theo kho của một mặt hàng (`GET /catalog/stock`).
class CrmMaterialStock {
  final String materialId;
  final String materialCode;
  final String? kind;
  final double? totalAvailable;
  final List<CrmCatalogMaterialStock> byWarehouse;

  const CrmMaterialStock({
    required this.materialId,
    required this.materialCode,
    this.kind,
    this.totalAvailable,
    this.byWarehouse = const [],
  });

  factory CrmMaterialStock.fromJson(Map<String, dynamic> json) => CrmMaterialStock(
        materialId: CrmJson.str(json['materialId']),
        materialCode: CrmJson.str(json['materialCode']),
        kind: CrmJson.strOrNull(json['kind']),
        totalAvailable: CrmJson.numOrNull(json['totalAvailable']),
        byWarehouse: CrmJson.list(json['byWarehouse'], CrmCatalogMaterialStock.fromJson),
      );
}
