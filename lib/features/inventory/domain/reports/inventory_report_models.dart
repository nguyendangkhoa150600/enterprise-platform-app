/// Model báo cáo kho, khớp contracts-inventory (`GET v1/reports/stock|movements|approvals`).
/// Đọc phòng thủ: số có thể về dạng chuỗi (numeric của Postgres), trường thiếu thì để trống.
library;

num _num(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

int _int(dynamic v) => _num(v).toInt();

String _str(dynamic v) => v?.toString() ?? '';

String? _opt(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

int? _optInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const {};

/// Ba kiểu xem của báo cáo tồn.
enum StockReportGroupBy { warehouse, lot, serial }

extension StockReportGroupByX on StockReportGroupBy {
  String get api => switch (this) {
    StockReportGroupBy.warehouse => 'WAREHOUSE',
    StockReportGroupBy.lot => 'LOT',
    StockReportGroupBy.serial => 'SERIAL',
  };
}

/// Kho tối thiểu cho bộ lọc (`GET /warehouses`).
class ReportWarehouse {
  final String code;
  final String name;
  const ReportWarehouse({required this.code, required this.name});

  factory ReportWarehouse.fromJson(Map<String, dynamic> j) =>
      ReportWarehouse(code: _str(j['code']), name: _str(j['name']));
}

/// Bốn loại tồn: thực tế, đã giữ, chờ kiểm định / không đạt, khả dụng.
class StockQuantities {
  final num onHand;
  final num reserved;
  final num blocked;
  final num available;
  const StockQuantities({this.onHand = 0, this.reserved = 0, this.blocked = 0, this.available = 0});

  factory StockQuantities.fromJson(Map<String, dynamic> j) => StockQuantities(
    onHand: _num(j['onHand']),
    reserved: _num(j['reserved']),
    blocked: _num(j['blocked']),
    available: _num(j['available']),
  );
}

class StockReportWarehouseRow {
  final String warehouseId, warehouseCode, warehouseName;
  final String materialId, materialCode, materialName;
  final String? unit, category;
  final StockQuantities qty;
  final num avgCost, stockValue;

  const StockReportWarehouseRow({
    required this.warehouseId,
    required this.warehouseCode,
    required this.warehouseName,
    required this.materialId,
    required this.materialCode,
    required this.materialName,
    this.unit,
    this.category,
    required this.qty,
    required this.avgCost,
    required this.stockValue,
  });

  factory StockReportWarehouseRow.fromJson(Map<String, dynamic> j) => StockReportWarehouseRow(
    warehouseId: _str(j['warehouseId']),
    warehouseCode: _str(j['warehouseCode']),
    warehouseName: _str(j['warehouseName']),
    materialId: _str(j['materialId']),
    materialCode: _str(j['materialCode']),
    materialName: _str(j['materialName']),
    unit: _opt(j['unit']),
    category: _opt(j['category']),
    qty: StockQuantities.fromJson(j),
    avgCost: _num(j['avgCost']),
    stockValue: _num(j['stockValue']),
  );
}

class StockReportLotRow {
  final String lotId, lotNo, warehouseId, warehouseCode, warehouseName;
  final String materialCode, materialName;
  final String? unit, expiresOn;
  final int? daysToExpiry;
  final String qualityStatus;
  final StockQuantities qty;

  const StockReportLotRow({
    required this.lotId,
    required this.lotNo,
    required this.warehouseId,
    required this.warehouseCode,
    required this.warehouseName,
    required this.materialCode,
    required this.materialName,
    this.unit,
    this.expiresOn,
    this.daysToExpiry,
    required this.qualityStatus,
    required this.qty,
  });

  factory StockReportLotRow.fromJson(Map<String, dynamic> j) => StockReportLotRow(
    lotId: _str(j['lotId']),
    lotNo: _str(j['lotNo']),
    warehouseId: _str(j['warehouseId']),
    warehouseCode: _str(j['warehouseCode']),
    warehouseName: _str(j['warehouseName']),
    materialCode: _str(j['materialCode']),
    materialName: _str(j['materialName']),
    unit: _opt(j['unit']),
    expiresOn: _opt(j['expiresOn']),
    daysToExpiry: _optInt(j['daysToExpiry']),
    qualityStatus: _str(j['qualityStatus']),
    qty: StockQuantities.fromJson(j),
  );
}

class StockReportSerialRow {
  final String serialId, serialNumber, materialCode, materialName;
  final String? category, warehouseCode, stockState;
  final String qualityStatus, updatedAt;

  const StockReportSerialRow({
    required this.serialId,
    required this.serialNumber,
    required this.materialCode,
    required this.materialName,
    this.category,
    this.warehouseCode,
    this.stockState,
    required this.qualityStatus,
    required this.updatedAt,
  });

  factory StockReportSerialRow.fromJson(Map<String, dynamic> j) => StockReportSerialRow(
    serialId: _str(j['serialId']),
    serialNumber: _str(j['serialNumber']),
    materialCode: _str(j['materialCode']),
    materialName: _str(j['materialName']),
    category: _opt(j['category']),
    warehouseCode: _opt(j['warehouseCode']),
    stockState: _opt(j['stockState']),
    qualityStatus: _str(j['qualityStatus']),
    updatedAt: _str(j['updatedAt']),
  );
}

/// Tổng của báo cáo serial: đếm số serial.
class SerialReportTotals {
  final num serials, inStock, blocked, available;
  const SerialReportTotals({this.serials = 0, this.inStock = 0, this.blocked = 0, this.available = 0});

  factory SerialReportTotals.fromJson(Map<String, dynamic> j) => SerialReportTotals(
    serials: _num(j['serials']),
    inStock: _num(j['inStock']),
    blocked: _num(j['blocked']),
    available: _num(j['available']),
  );
}

/// Một trang báo cáo tồn; tổng là của cả tập đã lọc.
class StockReport {
  final StockReportGroupBy groupBy;
  final int total;
  final String asOf;
  final List<StockReportWarehouseRow> warehouseRows;
  final List<StockReportLotRow> lotRows;
  final List<StockReportSerialRow> serialRows;

  /// Tổng kho/lô (thiếu khi xem serial).
  final StockQuantities quantityTotals;

  /// Chỉ báo cáo theo kho có giá trị tồn.
  final num? stockValueTotal;
  final SerialReportTotals serialTotals;

  const StockReport({
    required this.groupBy,
    required this.total,
    required this.asOf,
    this.warehouseRows = const [],
    this.lotRows = const [],
    this.serialRows = const [],
    this.quantityTotals = const StockQuantities(),
    this.stockValueTotal,
    this.serialTotals = const SerialReportTotals(),
  });

  int get rowCount => switch (groupBy) {
    StockReportGroupBy.warehouse => warehouseRows.length,
    StockReportGroupBy.lot => lotRows.length,
    StockReportGroupBy.serial => serialRows.length,
  };

  factory StockReport.fromJson(Map<String, dynamic> j, StockReportGroupBy requested) {
    final raw = _str(j['groupBy']);
    final groupBy = StockReportGroupBy.values.firstWhere((g) => g.api == raw, orElse: () => requested);
    final rows = _list(j['rows']);
    final totals = _map(j['totals']);
    return StockReport(
      groupBy: groupBy,
      total: _int(j['total']),
      asOf: _str(j['asOf']),
      warehouseRows: groupBy == StockReportGroupBy.warehouse
          ? rows.map(StockReportWarehouseRow.fromJson).toList()
          : const [],
      lotRows: groupBy == StockReportGroupBy.lot ? rows.map(StockReportLotRow.fromJson).toList() : const [],
      serialRows: groupBy == StockReportGroupBy.serial ? rows.map(StockReportSerialRow.fromJson).toList() : const [],
      quantityTotals: StockQuantities.fromJson(totals),
      stockValueTotal: totals['stockValue'] == null ? null : _num(totals['stockValue']),
      serialTotals: SerialReportTotals.fromJson(totals),
    );
  }
}

/// Sáu nhóm nhập xuất, thứ tự như `STOCK_MOVEMENT_CATEGORIES`.
const List<String> kStockMovementCategories = [
  'RECEIPT',
  'ISSUE',
  'TRANSFER',
  'SALES_RETURN',
  'ADJUSTMENT',
  'REVERSAL',
];

class StockMovementAmounts {
  final num quantityIn, quantityOut, valueIn, valueOut, entries;
  const StockMovementAmounts({
    this.quantityIn = 0,
    this.quantityOut = 0,
    this.valueIn = 0,
    this.valueOut = 0,
    this.entries = 0,
  });

  factory StockMovementAmounts.fromJson(Map<String, dynamic> j) => StockMovementAmounts(
    quantityIn: _num(j['quantityIn']),
    quantityOut: _num(j['quantityOut']),
    valueIn: _num(j['valueIn']),
    valueOut: _num(j['valueOut']),
    entries: _num(j['entries']),
  );

  List<Object> get cells => [quantityIn, quantityOut, valueIn, valueOut, entries];
}

class StockMovementSummaryRow {
  final String category;
  final StockMovementAmounts amounts;
  const StockMovementSummaryRow({required this.category, required this.amounts});

  factory StockMovementSummaryRow.fromJson(Map<String, dynamic> j) =>
      StockMovementSummaryRow(category: _str(j['category']), amounts: StockMovementAmounts.fromJson(j));
}

class StockMovementBreakdownRow {
  final String category;
  final String? docType;
  final String warehouseCode, warehouseName;
  final StockMovementAmounts amounts;
  const StockMovementBreakdownRow({
    required this.category,
    this.docType,
    required this.warehouseCode,
    required this.warehouseName,
    required this.amounts,
  });

  factory StockMovementBreakdownRow.fromJson(Map<String, dynamic> j) => StockMovementBreakdownRow(
    category: _str(j['category']),
    docType: _opt(j['docType']),
    warehouseCode: _str(j['warehouseCode']),
    warehouseName: _str(j['warehouseName']),
    amounts: StockMovementAmounts.fromJson(j),
  );
}

/// Một bút toán sổ kho trong kỳ; `quantity` âm là xuất.
class StockMovementLine {
  final String transactionId, transactionCode, postedAt, category;
  final String? documentCode, docType, reversesDocumentCode, unit, note;
  final String warehouseCode, materialCode, materialName;
  final num quantity, unitCost, value;

  const StockMovementLine({
    required this.transactionId,
    required this.transactionCode,
    required this.postedAt,
    required this.category,
    this.documentCode,
    this.docType,
    this.reversesDocumentCode,
    this.unit,
    this.note,
    required this.warehouseCode,
    required this.materialCode,
    required this.materialName,
    required this.quantity,
    required this.unitCost,
    required this.value,
  });

  factory StockMovementLine.fromJson(Map<String, dynamic> j) => StockMovementLine(
    transactionId: _str(j['transactionId']),
    transactionCode: _str(j['transactionCode']),
    postedAt: _str(j['postedAt']),
    category: _str(j['category']),
    documentCode: _opt(j['documentCode']),
    docType: _opt(j['docType']),
    reversesDocumentCode: _opt(j['reversesDocumentCode']),
    unit: _opt(j['unit']),
    note: _opt(j['note']),
    warehouseCode: _str(j['warehouseCode']),
    materialCode: _str(j['materialCode']),
    materialName: _str(j['materialName']),
    quantity: _num(j['quantity']),
    unitCost: _num(j['unitCost']),
    value: _num(j['value']),
  );
}

class StockMovementReport {
  final String fromDate, toDate;
  final List<StockMovementSummaryRow> summary;
  final List<StockMovementBreakdownRow> breakdown;
  final StockMovementAmounts totals;
  final List<StockMovementLine> lines;
  final int total;

  const StockMovementReport({
    required this.fromDate,
    required this.toDate,
    required this.summary,
    required this.breakdown,
    required this.totals,
    required this.lines,
    required this.total,
  });

  factory StockMovementReport.fromJson(Map<String, dynamic> j) => StockMovementReport(
    fromDate: _str(j['fromDate']),
    toDate: _str(j['toDate']),
    summary: _list(j['summary']).map(StockMovementSummaryRow.fromJson).toList(),
    breakdown: _list(j['breakdown']).map(StockMovementBreakdownRow.fromJson).toList(),
    totals: StockMovementAmounts.fromJson(_map(j['totals'])),
    lines: _list(j['lines']).map(StockMovementLine.fromJson).toList(),
    total: _int(j['total']),
  );
}

/// Một chứng từ phải duyệt; người thực hiện là id người dùng.
class StockApprovalReportRow {
  final String documentId, documentCode, docType, status, documentDate, warehouseCode;
  final String? reason, rejectReason;
  final String createdBy, createdAt;
  final String? submittedAt, approvedBy, approvedAt, rejectedBy, rejectedAt, postedBy, postedAt;
  final num quantityIn, quantityOut, value;

  const StockApprovalReportRow({
    required this.documentId,
    required this.documentCode,
    required this.docType,
    required this.status,
    required this.documentDate,
    required this.warehouseCode,
    this.reason,
    this.rejectReason,
    required this.createdBy,
    required this.createdAt,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.postedBy,
    this.postedAt,
    required this.quantityIn,
    required this.quantityOut,
    required this.value,
  });

  factory StockApprovalReportRow.fromJson(Map<String, dynamic> j) => StockApprovalReportRow(
    documentId: _str(j['documentId']),
    documentCode: _str(j['documentCode']),
    docType: _str(j['docType']),
    status: _str(j['status']),
    documentDate: _str(j['documentDate']),
    warehouseCode: _str(j['warehouseCode']),
    reason: _opt(j['reason']),
    rejectReason: _opt(j['rejectReason']),
    createdBy: _str(j['createdBy']),
    createdAt: _str(j['createdAt']),
    submittedAt: _opt(j['submittedAt']),
    approvedBy: _opt(j['approvedBy']),
    approvedAt: _opt(j['approvedAt']),
    rejectedBy: _opt(j['rejectedBy']),
    rejectedAt: _opt(j['rejectedAt']),
    postedBy: _opt(j['postedBy']),
    postedAt: _opt(j['postedAt']),
    quantityIn: _num(j['quantityIn']),
    quantityOut: _num(j['quantityOut']),
    value: _num(j['value']),
  );
}

class StockApprovalReport {
  final List<StockApprovalReportRow> rows;
  final int total;
  const StockApprovalReport({required this.rows, required this.total});

  factory StockApprovalReport.fromJson(Map<String, dynamic> j) => StockApprovalReport(
    rows: _list(j['rows']).map(StockApprovalReportRow.fromJson).toList(),
    total: _int(j['total']),
  );
}
