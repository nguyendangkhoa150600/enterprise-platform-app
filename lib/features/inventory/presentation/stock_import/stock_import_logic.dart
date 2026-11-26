import '../../../../core/i18n/app_i18n.dart';
import '../../domain/ledger/movement_models.dart';
import '../goods/goods_format.dart';
import '../utils/inventory_number.dart';
export '../utils/inventory_number.dart' show parseVnNumber;

// Quy tắc của hộp "Nhập Excel" vật tư & tồn kho — web components/excel-import-dialog.tsx
// (ExcelImportDialog): nhận cột thông minh, mẫu liên kết cột, đọc số kiểu Việt Nam, kiểm từng dòng.

/// Vật tư trong danh mục để khớp mã (web `Material`).
class StockImportMaterial {
  final String code;
  final String name;
  final String? type;
  final String unit;
  final String? barcode;
  final String? manufacturer;
  const StockImportMaterial({
    required this.code,
    required this.name,
    this.type,
    this.unit = '',
    this.barcode,
    this.manufacturer,
  });
}

class StockImportWarehouse {
  final String code;
  final String name;
  const StockImportWarehouse({required this.code, required this.name});
}

/// Các trường hệ thống cần ánh xạ cột (web `ColumnMapping`).
enum StockImportField {
  materialCode,
  barcode,
  materialName,
  materialType,
  manufacturer,
  unit,
  warehouseCode,
  locationId,
  quantity,
  unitCost,
  vatRate,
  minStock,
  maxStock,
  lotNumber,
  expiryDate,
  lineNote,
}

/// Độ tin cậy khớp cột (web `ConfidenceLevel`).
enum StockImportConfidence { exact, high, auto, none }

enum StockImportCategory { identity, stock, cost }

class StockImportFieldRule {
  final StockImportField key;
  final bool required;
  final StockImportCategory category;
  final List<String> positiveKeywords;
  final List<String> negativeKeywords;
  const StockImportFieldRule(this.key, this.required, this.category, this.positiveKeywords,
      [this.negativeKeywords = const []]);

  String get label => 'inventory.stock_import.field_${key.name}'.tr();
}

/// Từ khoá nhận diện tiêu đề cột — giữ nguyên thứ tự và nội dung như web `FIELD_RULES`.
const stockImportFieldRules = <StockImportFieldRule>[
  // 1. Nhóm định danh hàng hoá
  StockImportFieldRule(StockImportField.materialCode, true, StockImportCategory.identity, [
    'ma vat tu', 'ma vt', 'ma hang hoa', 'ma hang', 'sku', 'part number', 'part no', 'item code', 'ma sp', //
    'ma san pham', 'ma vthh', 'internal reference', 'item no', 'code', 'material code',
  ], [
    'kho', 'nhom', 'loai', 'dvt', 'don vi', 'vach', 'barcode', 'gia', 'cost', 'tien', 'so luong', 'sl', 'ten', 'name',
  ]),
  StockImportFieldRule(StockImportField.barcode, false, StockImportCategory.identity, [
    'ma vach', 'barcode', 'bar code', 'qr code', 'ma vach/barcode', 'ma vach (barcode)', 'qr', 'upc', 'ean',
  ], [
    'kho', 'nhom', 'don vi', 'so luong', 'gia', 'tien',
  ]),
  StockImportFieldRule(StockImportField.materialName, false, StockImportCategory.identity, [
    'ten vat tu', 'ten vt', 'ten hang hoa', 'ten hang', 'ten san pham', 'ten sp', 'ten vthh', 'dien giai', //
    'description', 'product name', 'item description', 'quy cach', 'ten mat hang', 'material name', 'item name',
  ], [
    'nhom', 'kho', 'loai', 'dvt', 'don vi', 'gia', 'cost', 'ma', 'sku', 'code',
  ]),
  StockImportFieldRule(StockImportField.materialType, false, StockImportCategory.identity, [
    'nhom vat tu', 'nhom hang hoa', 'nhom hang', 'nhom hh/dv', 'nhom vthh', 'ten nhom', 'thuoc nhom', //
    'loai vat tu', 'loai hang', 'phan loai', 'category', 'product category', 'item group', 'material type', //
    'type', 'nhom',
  ], [
    'kho', 'gia', 'tien', 'dvt', 'don vi', 'ten hang',
  ]),
  StockImportFieldRule(StockImportField.manufacturer, false, StockImportCategory.identity, [
    'nha san xuat', 'hang san xuat', 'thuong hieu', 'nha sx', 'hang sx', 'brand', 'manufacturer', 'hang',
  ], [
    'kho', 'gia', 'nhom', 'ten hang',
  ]),
  StockImportFieldRule(StockImportField.unit, false, StockImportCategory.identity, [
    'don vi tinh', 'dvt', 'don vi', 'dvt chinh', 'unit', 'uom', 'unit of measure', 'uom name',
  ], [
    'gia', 'cost', 'tien', 'don gia', 'gia von',
  ]),
  // 2. Nhóm kho bãi & số lượng
  StockImportFieldRule(StockImportField.quantity, true, StockImportCategory.stock, [
    'so luong', 'sl', 'ton kho', 'so luong ton', 'ton thuc te', 'thuc te', 'thuc nhan', 'thuc xuat', 'quantity', //
    'qty', 'on-hand', 'on hand', 'on hand quantity', 'in stock', 'amount', 'so luong nhap',
  ], [
    'gia', 'cost', 'don gia', 'dvt', 'don vi', 'tien',
  ]),
  StockImportFieldRule(StockImportField.warehouseCode, false, StockImportCategory.stock, [
    'kho', 'kho nhan', 'kho xuat', 'ma kho', 'ten kho', 'kho hang', 'warehouse', 'warehouse code', 'whse', //
    'vi tri kho', 'location',
  ], [
    'ke', 'o ke', 'bin', 'rack', 'gia', 'cost',
  ]),
  StockImportFieldRule(StockImportField.locationId, false, StockImportCategory.stock, [
    'vi tri ke', 'ke', 'o ke', 'bin', 'rack', 'bin rack', 'vi tri luu kho', 'bin location', 'ngan chua', 'vi tri',
  ], [
    'ma kho', 'ten kho', 'kho hang',
  ]),
  StockImportFieldRule(StockImportField.minStock, false, StockImportCategory.stock, [
    'ton toi thieu', 'dinh muc ton toi thieu', 'min stock', 'min',
  ], [
    'toi da', 'max',
  ]),
  StockImportFieldRule(StockImportField.maxStock, false, StockImportCategory.stock, [
    'ton toi da', 'dinh muc ton toi da', 'max stock', 'max',
  ], [
    'toi thieu', 'min',
  ]),
  // 3. Nhóm giá vốn & lô / hạn dùng
  StockImportFieldRule(StockImportField.unitCost, false, StockImportCategory.cost, [
    'don gia', 'don gia nhap', 'don gia von', 'gia von', 'gia nhap', 'gia mua', 'don gia binh quan', 'unit cost', //
    'cost', 'price', 'unit price', 'avg price', 'purchase price', 'gia',
  ], [
    'so luong', 'sl', 'thue', 'vat', 'don vi tinh', 'dvt',
  ]),
  StockImportFieldRule(StockImportField.vatRate, false, StockImportCategory.cost, [
    'thue suat', 'thue vat', 'vat', '% vat', 'thue', 'vat rate', 'tax rate', '% thue',
  ], [
    'don gia', 'gia', 'tien',
  ]),
  StockImportFieldRule(StockImportField.lotNumber, false, StockImportCategory.cost, [
    'so lo', 'lo', 'lot', 'lot number', 'batch', 'batch no', 'so lo sx', 'ma lo',
  ], [
    'loai', 'nhom',
  ]),
  StockImportFieldRule(StockImportField.expiryDate, false, StockImportCategory.cost, [
    'han su dung', 'han dung', 'hsd', 'expiry', 'exp date', 'expiry date', 'ngay het han',
  ], [
    'ngay sx', 'ngay tao',
  ]),
  StockImportFieldRule(StockImportField.lineNote, false, StockImportCategory.cost, [
    'ghi chu', 'note', 'dien giai dong', 'dien giai', 'remark', 'comments',
  ], [
    'ten hang', 'ma hang',
  ]),
];

typedef StockImportMapping = Map<StockImportField, String>;
typedef StockImportConfidences = Map<StockImportField, StockImportConfidence>;

StockImportMapping emptyStockImportMapping() => {for (final f in StockImportField.values) f: ''};
StockImportConfidences emptyStockImportConfidences() =>
    {for (final f in StockImportField.values) f: StockImportConfidence.none};

/// Chuẩn hoá không dấu, chữ thường để so khớp (web `normalize`).
String stockImportNormalize(String? value) =>
    GoodsFormat.fold((value ?? '').trim()).replaceAll(RegExp('[̀-ͯ]'), '');

/// Như `String(x)` của JavaScript cho giá trị ô (số nguyên không có `.0`). Ô ngày → `yyyy-MM-dd`.
String stockImportCellText(Object? v) {
  if (v == null) return '';
  if (v is double && v.isFinite && v == v.truncateToDouble() && v.abs() < 1e15) return v.toInt().toString();
  if (v is DateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${v.year.toString().padLeft(4, '0')}-${two(v.month)}-${two(v.day)}';
  }
  return v.toString();
}

/// Web `parseNumericValue`: ô số dùng thẳng, chuỗi đọc kiểu Việt Nam; không đọc được → null.
double? stockImportNumber(Object? val) {
  if (val == null || (val is String && val.isEmpty)) return null;
  if (val is num) return val.isFinite ? val.toDouble() : null;
  if (val is DateTime || val is bool) return null;
  return parseVnNumber(val.toString().replaceAll(RegExp(r'[$€¥]'), ''));
}

/// Thuật toán liên kết cột đa tầng (web `detectSmartColumnMapping`).
({StockImportMapping mapping, StockImportConfidences confidences}) detectStockImportMapping(List<String> headers) {
  final mapping = emptyStockImportMapping();
  final confidences = emptyStockImportConfidences();
  final assigned = <String>{};

  // Tầng 1: khớp chính xác.
  for (final rule in stockImportFieldRules) {
    for (final h in headers) {
      if (assigned.contains(h)) continue;
      final normH = stockImportNormalize(h);
      if (rule.positiveKeywords.any((k) => normH == k)) {
        mapping[rule.key] = h;
        confidences[rule.key] = StockImportConfidence.exact;
        assigned.add(h);
        break;
      }
    }
  }

  // Tầng 2: khớp cụm từ có trọng số, loại trừ từ khoá xung đột.
  for (final rule in stockImportFieldRules) {
    if (mapping[rule.key]!.isNotEmpty) continue;
    var bestScore = 0.0;
    var bestHeader = '';
    for (final h in headers) {
      if (assigned.contains(h)) continue;
      final normH = stockImportNormalize(h);
      final hasNegative = rule.negativeKeywords.any((neg) =>
          normH == neg || normH.startsWith('$neg ') || normH.endsWith(' $neg') || normH.contains(' $neg '));
      if (hasNegative) continue;
      for (final kw in rule.positiveKeywords) {
        var score = 0.0;
        if (normH == kw) {
          score = 100;
        } else if (normH.startsWith(kw) || normH.endsWith(kw)) {
          score = 85 + (kw.length / normH.length) * 10;
        } else if (normH.contains(kw)) {
          score = 70 + (kw.length / normH.length) * 10;
        }
        if (score > bestScore) {
          bestScore = score;
          bestHeader = h;
        }
      }
    }
    if (bestScore >= 70 && bestHeader.isNotEmpty) {
      mapping[rule.key] = bestHeader;
      confidences[rule.key] = bestScore >= 85 ? StockImportConfidence.high : StockImportConfidence.auto;
      assigned.add(bestHeader);
    }
  }
  return (mapping: mapping, confidences: confidences);
}

/// Mẫu liên kết cột dựng sẵn cho các phần mềm phổ biến (web `BUILT_IN_PRESETS`).
/// Tiêu đề cột là nội dung tệp xuất của từng phần mềm nên giữ nguyên văn.
class StockImportPreset {
  final String id;
  final String software;
  final Map<StockImportField, String> mapping;
  const StockImportPreset(this.id, this.software, this.mapping);

  String get name => 'inventory.stock_import.preset_${id}_name'.tr();
}

const stockImportPresets = <StockImportPreset>[
  StockImportPreset('kiotviet', 'KiotViet', {
    StockImportField.materialCode: 'Mã hàng',
    StockImportField.barcode: 'Mã vạch',
    StockImportField.materialName: 'Tên hàng',
    StockImportField.materialType: 'Tên nhóm',
    StockImportField.manufacturer: 'Thương hiệu',
    StockImportField.unit: 'ĐVT',
    StockImportField.quantity: 'Tồn kho',
    StockImportField.unitCost: 'Giá vốn',
    StockImportField.locationId: 'Vị trí',
  }),
  StockImportPreset('misa', 'MISA', {
    StockImportField.materialCode: 'Mã hàng',
    StockImportField.materialName: 'Tên hàng',
    StockImportField.materialType: 'Nhóm VTHH',
    StockImportField.unit: 'ĐVT chính',
    StockImportField.warehouseCode: 'Mã kho',
    StockImportField.quantity: 'Số lượng tồn',
    StockImportField.unitCost: 'Đơn giá bình quân',
    StockImportField.lotNumber: 'Số lô',
    StockImportField.expiryDate: 'Hạn sử dụng',
  }),
  StockImportPreset('odoo', 'Odoo', {
    StockImportField.materialCode: 'Internal Reference',
    StockImportField.barcode: 'Barcode',
    StockImportField.materialName: 'Product Name',
    StockImportField.materialType: 'Product Category',
    StockImportField.unit: 'Unit of Measure',
    StockImportField.warehouseCode: 'Location',
    StockImportField.quantity: 'On Hand Quantity',
    StockImportField.unitCost: 'Cost',
  }),
  StockImportPreset('sap', 'SAP', {
    StockImportField.materialCode: 'Item No.',
    StockImportField.barcode: 'Bar Code',
    StockImportField.materialName: 'Item Description',
    StockImportField.materialType: 'Item Group',
    StockImportField.unit: 'UoM Name',
    StockImportField.warehouseCode: 'Whse',
    StockImportField.quantity: 'In Stock',
    StockImportField.unitCost: 'Avg. Price',
  }),
  StockImportPreset('universal', 'ERP', {
    StockImportField.materialCode: 'Mã hàng hóa (SKU)',
    StockImportField.barcode: 'Mã vạch (Barcode)',
    StockImportField.materialName: 'Tên hàng hóa',
    StockImportField.materialType: 'Nhóm hàng hóa (Category)',
    StockImportField.manufacturer: 'Hãng sản xuất',
    StockImportField.unit: 'Đơn vị tính (UoM)',
    StockImportField.warehouseCode: 'Mã kho',
    StockImportField.locationId: 'Vị trí kệ / ô (Bin Rack)',
    StockImportField.quantity: 'Tồn thực tế (On-hand)',
    StockImportField.unitCost: 'Đơn giá vốn (VNĐ)',
    StockImportField.minStock: 'Định mức tồn tối thiểu (Min)',
    StockImportField.maxStock: 'Định mức tồn tối đa (Max)',
    StockImportField.lineNote: 'Ghi chú / Nơi lắp đặt',
  }),
];

/// Áp mẫu dựng sẵn: mỗi trường tìm cột có tên trùng hoặc chứa tên mong đợi (web `handleSelectPreset`).
({StockImportMapping mapping, StockImportConfidences confidences}) applyStockImportPreset(
    StockImportPreset preset, List<String> headers, StockImportConfidences current) {
  final mapping = emptyStockImportMapping();
  final conf = Map.of(current);
  for (final e in preset.mapping.entries) {
    final expected = stockImportNormalize(e.value);
    for (final h in headers) {
      final n = stockImportNormalize(h);
      if (n == expected || n.contains(expected)) {
        mapping[e.key] = h;
        conf[e.key] = StockImportConfidence.high;
        break;
      }
    }
  }
  return (mapping: mapping, confidences: conf);
}

/// Dòng tiêu đề tự phát hiện: dòng đầu (trong 10 dòng) có ít nhất 2 ô chữ dài hơn 1 ký tự.
int detectStockImportHeaderRow(List<List<Object?>> rows) {
  for (var i = 0; i < rows.length && i < 10; i++) {
    if (rows[i].where((c) => c is String && c.trim().length > 1).length >= 2) return i;
  }
  return 0;
}

/// Tên các cột theo dòng tiêu đề; ô trống thành "Cột N".
List<String> stockImportHeaders(List<List<Object?>> rows, int headerRow) {
  final row = headerRow < rows.length ? rows[headerRow] : const <Object?>[];
  return [
    for (var i = 0; i < row.length; i++)
      stockImportCellText(row[i]).trim().isNotEmpty
          ? stockImportCellText(row[i]).trim()
          : 'inventory.stock_import.col_n'.tr(args: {'n': i + 1}),
  ];
}

/// Như `sheet_to_json(header: 1, defval: '', blankrows: false)`: mọi dòng cùng độ rộng, bỏ dòng trống.
List<List<Object?>> stockImportRawRows(List<List<Object?>> rows) {
  bool blank(Object? c) => c == null || (c is String && c.isEmpty);
  final kept = rows.where((r) => r.any((c) => !blank(c))).toList();
  final width = kept.fold<int>(0, (w, r) => r.length > w ? r.length : w);
  return [for (final r in kept) List<Object?>.generate(width, (i) => i < r.length ? r[i] : null)];
}

enum StockImportRowStatus { valid, warning, error }

/// Một dòng tệp sau khi kiểm (web `ParsedRowResult`).
class StockImportRow {
  final int rowIndex;
  final String materialCode;
  final String? barcode;
  final String materialName;
  final String materialType;
  final String manufacturer;
  final String unit;
  final String warehouseCode;
  final String? locationId;
  final double quantity;
  final double? unitCost;
  final double? vatRate;
  final double? minStock;
  final double? maxStock;
  final String? lotNumber;
  final String? expiryDate;
  final String? lineNote;
  final StockImportRowStatus status;
  final bool isNew;
  final List<String> errors;

  const StockImportRow({
    required this.rowIndex,
    required this.materialCode,
    this.barcode,
    required this.materialName,
    required this.materialType,
    required this.manufacturer,
    required this.unit,
    required this.warehouseCode,
    this.locationId,
    required this.quantity,
    this.unitCost,
    this.vatRate,
    this.minStock,
    this.maxStock,
    this.lotNumber,
    this.expiryDate,
    this.lineNote,
    required this.status,
    required this.isNew,
    required this.errors,
  });
}

/// Phân tích và kiểm từng dòng theo ánh xạ cột (web `parsedDataResults`).
/// [movementKind] null = nạp tồn từ tab Nhà kho.
List<StockImportRow> parseStockImportRows({
  required List<List<Object?>> rawRows,
  required int headerRow,
  required List<String> headers,
  required StockImportMapping mapping,
  required List<StockImportMaterial> materials,
  required List<StockImportWarehouse> warehouses,
  required MovementKind? movementKind,
  required bool isSingleWarehouseOnly,
  required String defaultWarehouseCode,
  required String fallbackWarehouse,
}) {
  if (rawRows.length <= headerRow + 1 ||
      mapping[StockImportField.materialCode]!.isEmpty ||
      mapping[StockImportField.quantity]!.isEmpty) {
    return const [];
  }
  final materialMap = <String, StockImportMaterial>{};
  for (final m in materials) {
    materialMap[m.code.toUpperCase()] = m;
    materialMap[stockImportNormalize(m.code)] = m;
  }
  final warehouseMap = <String, String>{};
  for (final w in warehouses) {
    warehouseMap[w.code.toUpperCase()] = w.code;
    warehouseMap[stockImportNormalize(w.code)] = w.code;
    warehouseMap[w.name.toUpperCase()] = w.code;
    warehouseMap[stockImportNormalize(w.name)] = w.code;
  }
  final col = {
    for (final f in StockImportField.values) f: mapping[f]!.isEmpty ? -1 : headers.indexOf(mapping[f]!),
  };
  Object? cell(List<Object?> row, StockImportField f) {
    final i = col[f]!;
    return i >= 0 && i < row.length ? row[i] : null;
  }

  String text(List<Object?> row, StockImportField f) => stockImportCellText(cell(row, f)).trim();

  final results = <StockImportRow>[];
  for (var r = headerRow + 1; r < rawRows.length; r++) {
    final row = rawRows[r];
    if (row.isEmpty) continue;
    final rawCode = col[StockImportField.materialCode]! >= 0 ? text(row, StockImportField.materialCode) : '';
    if (rawCode.isEmpty && !row.any((c) => stockImportCellText(c).trim().isNotEmpty)) continue;

    final errors = <String>[];
    if (rawCode.isEmpty) errors.add('inventory.stock_import.err_missing_code'.tr());

    final normalizedCode = rawCode.toUpperCase();
    final existing = materialMap[normalizedCode] ?? materialMap[stockImportNormalize(rawCode)];
    final isNew = existing == null && rawCode.isNotEmpty;
    if (isNew && movementKind != null && movementKind != MovementKind.receipt) {
      errors.add('inventory.stock_import.err_code_not_found'.tr());
    }

    final rawBarcode = cell(row, StockImportField.barcode);
    final barcode = col[StockImportField.barcode]! >= 0 && _truthy(rawBarcode)
        ? stockImportCellText(rawBarcode).trim()
        : ((existing?.barcode ?? '').isNotEmpty ? existing!.barcode! : normalizedCode);

    var name = col[StockImportField.materialName]! >= 0 ? text(row, StockImportField.materialName) : '';
    if (name.isEmpty && existing != null) name = existing.name;
    if (name.isEmpty && existing == null) name = rawCode;

    var materialType = col[StockImportField.materialType]! >= 0 ? text(row, StockImportField.materialType) : '';
    if (materialType.isEmpty && (existing?.type ?? '').isNotEmpty) materialType = existing!.type!;

    var manufacturer = col[StockImportField.manufacturer]! >= 0 ? text(row, StockImportField.manufacturer) : '';
    if (manufacturer.isEmpty && (existing?.manufacturer ?? '').isNotEmpty) manufacturer = existing!.manufacturer!;

    var unit = col[StockImportField.unit]! >= 0 ? text(row, StockImportField.unit) : '';
    if (unit.isEmpty && (existing?.unit ?? '').isNotEmpty) unit = existing!.unit;
    if (unit.isEmpty) unit = 'Cái';

    final qty = stockImportNumber(cell(row, StockImportField.quantity));
    if (qty == null) {
      errors.add('inventory.stock_import.err_qty_invalid'.tr());
    } else if (qty <= 0) {
      errors.add('inventory.stock_import.err_qty_positive'.tr());
    }
    final cost = stockImportNumber(cell(row, StockImportField.unitCost));
    final vat = stockImportNumber(cell(row, StockImportField.vatRate));

    // Kho: chốt 1 kho - 1 phiếu, hoặc nạp đa kho theo cột kho.
    String rowWh;
    if (isSingleWarehouseOnly) {
      rowWh = defaultWarehouseCode.isNotEmpty ? defaultWarehouseCode : fallbackWarehouse;
    } else if (col[StockImportField.warehouseCode]! < 0) {
      rowWh = fallbackWarehouse.isNotEmpty ? fallbackWarehouse : defaultWarehouseCode;
    } else {
      // Có cột kho thì ô trống hoặc mã sai là lỗi, không rơi về kho mặc định.
      final rawWh = text(row, StockImportField.warehouseCode);
      final resolved = warehouseMap[rawWh.toUpperCase()] ?? warehouseMap[stockImportNormalize(rawWh)];
      if (rawWh.isEmpty) {
        errors.add('inventory.stock_import.err_missing_wh'.tr());
      } else if (resolved == null) {
        errors.add('inventory.stock_import.err_wh_not_found'.tr(args: {'wh': rawWh}));
      }
      rowWh = resolved ?? '';
    }

    final locationId = col[StockImportField.locationId]! >= 0 ? text(row, StockImportField.locationId) : null;
    final minStock = stockImportNumber(cell(row, StockImportField.minStock));
    final maxStock = stockImportNumber(cell(row, StockImportField.maxStock));
    if (isNew && maxStock != null && maxStock > 0 && (minStock ?? 0) > maxStock) {
      errors.add('inventory.stock_import.err_min_max'.tr());
    }

    final lot = col[StockImportField.lotNumber]! >= 0 ? text(row, StockImportField.lotNumber).toUpperCase() : null;
    final expiry = col[StockImportField.expiryDate]! >= 0 ? text(row, StockImportField.expiryDate) : null;
    final note = col[StockImportField.lineNote]! >= 0 ? text(row, StockImportField.lineNote) : null;

    results.add(StockImportRow(
      rowIndex: r + 1,
      materialCode: existing != null ? existing.code : (normalizedCode.isNotEmpty ? normalizedCode : rawCode),
      barcode: barcode,
      materialName: name,
      materialType: materialType,
      manufacturer: manufacturer,
      unit: unit,
      warehouseCode: rowWh,
      locationId: locationId,
      quantity: qty != null && qty != 0 ? qty : 0,
      unitCost: cost,
      vatRate: vat,
      minStock: minStock,
      maxStock: maxStock,
      lotNumber: (lot ?? '').isEmpty ? null : lot,
      expiryDate: (expiry ?? '').isEmpty ? null : expiry,
      lineNote: (note ?? '').isEmpty ? null : note,
      status: errors.isNotEmpty
          ? StockImportRowStatus.error
          : (isNew ? StockImportRowStatus.warning : StockImportRowStatus.valid),
      isNew: isNew,
      errors: errors,
    ));
  }
  return results;
}

/// Giá trị "truthy" của JS cho ô: rỗng, 0, false là không có.
bool _truthy(Object? v) => !(v == null || v == false || (v is num && v == 0) || (v is String && v.isEmpty));

/// Thống kê bước 3 (web `stats`). Nạp cả kho là tất cả hoặc không: còn dòng lỗi thì chặn.
class StockImportStats {
  final int total;
  final int valid;
  final int warning;
  final int error;
  final double totalQty;
  final bool blockedByErrors;
  const StockImportStats(this.total, this.valid, this.warning, this.error, this.totalQty, this.blockedByErrors);

  int get readyToImport => valid + warning;

  factory StockImportStats.of(List<StockImportRow> rows, {required bool isSingleWarehouseOnly}) {
    final valid = rows.where((r) => r.status == StockImportRowStatus.valid).length;
    final warning = rows.where((r) => r.status == StockImportRowStatus.warning).length;
    final error = rows.where((r) => r.status == StockImportRowStatus.error).length;
    final qty = rows.where((r) => r.status != StockImportRowStatus.error).fold<double>(0, (s, r) => s + r.quantity);
    return StockImportStats(rows.length, valid, warning, error, qty, !isSingleWarehouseOnly && error > 0);
  }
}

/// Dòng hợp lệ → dòng phiếu (web `handleConfirmImport`).
List<MovementLine> buildStockImportLines(
  List<StockImportRow> rows, {
  required MovementKind? movementKind,
  required bool isSingleWarehouseOnly,
  required String defaultWarehouseCode,
}) {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final receiptLike = movementKind == null || movementKind == MovementKind.receipt;
  final valid = rows.where((r) => r.status != StockImportRowStatus.error).toList();
  return [
    for (var i = 0; i < valid.length; i++)
      MovementLine(
        id: 'imported-$stamp-$i',
        materialCode: valid[i].materialCode,
        materialName: valid[i].materialName,
        materialType: valid[i].materialType,
        unit: valid[i].unit,
        quantity: valid[i].quantity,
        unitCost: valid[i].unitCost,
        warehouseCode: isSingleWarehouseOnly ? defaultWarehouseCode : valid[i].warehouseCode,
        barcode: valid[i].barcode,
        manufacturer: valid[i].manufacturer,
        locationId: valid[i].locationId,
        vatRate: valid[i].vatRate,
        minStock: valid[i].minStock,
        maxStock: valid[i].maxStock,
        lineNote: valid[i].lineNote ?? (valid[i].isNew ? 'inventory.stock_import.new_material_note'.tr() : ''),
        receiptLot: receiptLike && valid[i].lotNumber != null
            ? ReceiptLot(lotNumber: valid[i].lotNumber!, expiryDate: valid[i].expiryDate)
            : null,
        newMaterial: receiptLike && valid[i].isNew
            ? NewMaterialDraft(
                code: valid[i].materialCode,
                name: valid[i].materialName,
                type: valid[i].materialType,
                unit: valid[i].unit,
                minStock: valid[i].minStock ?? 0,
                maxStock: valid[i].maxStock,
                barcode: valid[i].barcode,
                manufacturer: valid[i].manufacturer,
              )
            : null,
      ),
  ];
}

/// Tệp mẫu chuẩn 16 cột (web `handleDownloadTemplate`): tiêu đề trùng mẫu "Chuẩn Bảng phẳng ERP nội bộ"
/// nên giữ nguyên văn; 3 dòng ví dụ là nội dung tệp mẫu của web.
const stockImportTemplateFileName = 'Mau_Nhap_Ton_Kho_Chuan_ERP';
const stockImportTemplateSheet = 'Mau_Ton_Kho_Chuan';
const stockImportTemplateWidths = <double>[18, 18, 34, 24, 16, 14, 14, 20, 18, 18, 14, 22, 22, 18, 16, 28];

List<List<Object?>> stockImportTemplateRows(String warehouseCode) {
  final wh = warehouseCode.isNotEmpty ? warehouseCode : 'KHO-01';
  return [
    [
      'Mã hàng hóa (SKU)', 'Mã vạch (Barcode)', 'Tên hàng hóa', 'Nhóm hàng hóa (Category)', 'Hãng sản xuất', //
      'Đơn vị tính (UoM)', 'Mã kho', 'Vị trí kệ / ô (Bin Rack)', 'Tồn thực tế (On-hand)', 'Đơn giá vốn (VNĐ)', //
      'Thuế suất VAT (%)', 'Định mức tồn tối thiểu (Min)', 'Định mức tồn tối đa (Max)', 'Số lô (Lot / Batch)', //
      'Hạn sử dụng', 'Ghi chú / Nơi lắp đặt',
    ],
    [
      'VT-001', 'VT-001', 'Dầu nhớt Castrol Magnatec 5W-30', 'Dầu mỡ phụ gia', 'Castrol', 'Lít', wh, 'Kệ A1-02', //
      50, 185000, 10, 10, 200, 'LOT-2026-001', '2028-12-31', 'Hàng nhập khẩu chính hãng',
    ],
    [
      'VT-002', 'VT-002', 'Lọc dầu nhớt xe nâng Toyota 2.5T', 'Phụ tùng thay thế', 'Toyota OEM', 'Cái', wh, //
      'Kệ B3-01', 20, 95000, 10, 5, 50, '', '', 'Phụ tùng định kỳ',
    ],
    [
      'VT-003', 'VT-003', 'Găng tay sợi bảo hộ lao động phủ hạt', 'Bảo hộ lao động', 'Việt Nam', 'Đôi', wh, //
      'Kệ C1-05', 200, 8500, 8, 50, 500, '', '', 'Vật tư tiêu hao',
    ],
  ];
}
