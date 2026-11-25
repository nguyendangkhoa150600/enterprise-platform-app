/// Mô hình dữ liệu của tab "Xuất/nhập kho" (web `contracts-inventory`: StockDocument, StockMovementEntry,
/// Reservation, Lot, SerialTracking). Chỉ đọc JSON thô từ Inventory API; không gọi API ở đây.
library;

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
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// Ngày `YYYY-MM-DD` (cắt phần giờ nếu server trả ISO đầy đủ).
String? _date(dynamic v) {
  final s = _str(v);
  if (s == null) return null;
  return s.length >= 10 ? s.substring(0, 10) : s;
}

List<Map<String, dynamic>> _maps(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

class StockDocLine {
  final String id;
  final int lineNo;
  final String materialId;
  final String materialCode;
  final String materialName;
  final String? unit;
  final double quantity;

  /// `IN` hoặc `OUT`.
  final String direction;
  final double unitCost;
  final double? costAmount;
  final String? reservationId;
  final String? lotNo;
  final String? lotExpiresOn;
  final List<String> serials;
  final String? sourceLineId;
  final String? note;

  const StockDocLine({
    required this.id,
    required this.lineNo,
    required this.materialId,
    required this.materialCode,
    required this.materialName,
    this.unit,
    required this.quantity,
    required this.direction,
    this.unitCost = 0,
    this.costAmount,
    this.reservationId,
    this.lotNo,
    this.lotExpiresOn,
    this.serials = const [],
    this.sourceLineId,
    this.note,
  });

  factory StockDocLine.fromJson(Map<String, dynamic> j) => StockDocLine(
        id: j['id']?.toString() ?? '',
        lineNo: _num(j['lineNo']).toInt(),
        materialId: j['materialId']?.toString() ?? '',
        materialCode: j['materialCode']?.toString() ?? '',
        materialName: j['materialName']?.toString() ?? '',
        unit: _str(j['unit']),
        quantity: _num(j['quantity']),
        direction: j['direction']?.toString() ?? 'OUT',
        unitCost: _num(j['unitCost']),
        costAmount: _numOrNull(j['costAmount']),
        reservationId: _str(j['reservationId']),
        lotNo: _str(j['lotNo']),
        lotExpiresOn: _date(j['lotExpiresOn']),
        serials: (j['serials'] is List) ? (j['serials'] as List).map((e) => e.toString()).toList() : const [],
        sourceLineId: _str(j['sourceLineId']),
        note: _str(j['note']),
      );
}

class StockDoc {
  final String id;
  final String code;
  final String docType;
  final String status;
  final String warehouseId;
  final String warehouseCode;
  final String? targetWarehouseCode;
  final String? sourceType;
  final String? sourceId;
  final String documentDate;
  final String? note;
  final String? rejectReason;
  final String? reversesDocumentId;
  final String? createdBy;
  final String? createdAt;
  final String? submittedBy;
  final String? submittedAt;
  final String? approvedBy;
  final String? approvedAt;
  final String? rejectedBy;
  final String? rejectedAt;
  final String? postedBy;
  final String? postedAt;
  final String? cancelledBy;
  final String? cancelledAt;
  final String? updatedAt;
  final List<StockDocLine> lines;

  const StockDoc({
    required this.id,
    required this.code,
    required this.docType,
    required this.status,
    required this.warehouseId,
    required this.warehouseCode,
    this.targetWarehouseCode,
    this.sourceType,
    this.sourceId,
    required this.documentDate,
    this.note,
    this.rejectReason,
    this.reversesDocumentId,
    this.createdBy,
    this.createdAt,
    this.submittedBy,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.postedBy,
    this.postedAt,
    this.cancelledBy,
    this.cancelledAt,
    this.updatedAt,
    this.lines = const [],
  });

  double get totalQuantity => lines.fold(0, (s, l) => s + l.quantity);
  double get totalCost => lines.fold(0, (s, l) => s + (l.costAmount ?? 0));

  factory StockDoc.fromJson(Map<String, dynamic> j) => StockDoc(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        docType: j['docType']?.toString() ?? '',
        status: j['status']?.toString() ?? 'DRAFT',
        warehouseId: j['warehouseId']?.toString() ?? '',
        warehouseCode: j['warehouseCode']?.toString() ?? '',
        targetWarehouseCode: _str(j['targetWarehouseCode']),
        sourceType: _str(j['sourceType']),
        sourceId: _str(j['sourceId']),
        documentDate: _date(j['documentDate']) ?? '',
        note: _str(j['note']),
        rejectReason: _str(j['rejectReason']),
        reversesDocumentId: _str(j['reversesDocumentId']),
        createdBy: _str(j['createdBy']),
        createdAt: _str(j['createdAt']),
        submittedBy: _str(j['submittedBy']),
        submittedAt: _str(j['submittedAt']),
        approvedBy: _str(j['approvedBy']),
        approvedAt: _str(j['approvedAt']),
        rejectedBy: _str(j['rejectedBy']),
        rejectedAt: _str(j['rejectedAt']),
        postedBy: _str(j['postedBy']),
        postedAt: _str(j['postedAt']),
        cancelledBy: _str(j['cancelledBy']),
        cancelledAt: _str(j['cancelledAt']),
        updatedAt: _str(j['updatedAt']),
        lines: _maps(j['lines']).map(StockDocLine.fromJson).toList(),
      );
}

class StockDocPage {
  final List<StockDoc> items;
  final int total;
  const StockDocPage(this.items, this.total);

  factory StockDocPage.fromJson(dynamic j) {
    if (j is List) {
      final items = _maps(j).map(StockDoc.fromJson).toList();
      return StockDocPage(items, items.length);
    }
    final m = j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
    final items = _maps(m['items']).map(StockDoc.fromJson).toList();
    return StockDocPage(items, _numOrNull(m['total'])?.toInt() ?? items.length);
  }
}

/// Một dòng của danh sách gộp: chứng từ (`document`) hoặc bút toán cũ (`legacy`).
class StockMovementRow {
  final String kind;
  final String id;
  final String code;
  final String type;
  final String status;
  final String warehouseCode;
  final String? targetWarehouseCode;
  final String? occurredAt;
  final String movementDate;
  final String sourceType;
  final String? sourceId;
  final int lineCount;
  final double quantityTotal;
  final String? materialCode;
  final String? materialName;
  final String? createdBy;
  final String? note;

  const StockMovementRow({
    required this.kind,
    required this.id,
    required this.code,
    required this.type,
    required this.status,
    required this.warehouseCode,
    this.targetWarehouseCode,
    this.occurredAt,
    required this.movementDate,
    required this.sourceType,
    this.sourceId,
    required this.lineCount,
    required this.quantityTotal,
    this.materialCode,
    this.materialName,
    this.createdBy,
    this.note,
  });

  bool get isLegacy => kind == 'legacy';

  factory StockMovementRow.fromJson(Map<String, dynamic> j) => StockMovementRow(
        kind: j['kind']?.toString() ?? 'document',
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        warehouseCode: j['warehouseCode']?.toString() ?? '',
        targetWarehouseCode: _str(j['targetWarehouseCode']),
        occurredAt: _str(j['occurredAt']),
        movementDate: _date(j['movementDate']) ?? '',
        sourceType: j['sourceType']?.toString() ?? 'manual',
        sourceId: _str(j['sourceId']),
        lineCount: _num(j['lineCount']).toInt(),
        quantityTotal: _num(j['quantityTotal']),
        materialCode: _str(j['materialCode']),
        materialName: _str(j['materialName']),
        createdBy: _str(j['createdBy']),
        note: _str(j['note']),
      );
}

class StockMovementPage {
  final List<StockMovementRow> rows;
  final int total;
  final int pendingCount;
  const StockMovementPage(this.rows, this.total, this.pendingCount);

  factory StockMovementPage.fromJson(dynamic j) {
    final m = j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
    final rows = _maps(m['rows']).map(StockMovementRow.fromJson).toList();
    return StockMovementPage(
      rows,
      _numOrNull(m['total'])?.toInt() ?? rows.length,
      _numOrNull(m['pendingCount'])?.toInt() ?? 0,
    );
  }
}

class ReservationItemRow {
  final String warehouseId;
  final String materialId;
  final double quantityReserved;
  final double quantityIssued;
  const ReservationItemRow(this.warehouseId, this.materialId, this.quantityReserved, this.quantityIssued);

  factory ReservationItemRow.fromJson(Map<String, dynamic> j) => ReservationItemRow(
        j['warehouseId']?.toString() ?? '',
        j['materialId']?.toString() ?? '',
        _num(j['quantityReserved']),
        _num(j['quantityIssued']),
      );
}

class ReservationRow {
  final String id;
  final String reservationCode;
  final String status;
  final String? expiresAt;
  final List<ReservationItemRow> items;
  const ReservationRow({
    required this.id,
    required this.reservationCode,
    required this.status,
    this.expiresAt,
    this.items = const [],
  });

  factory ReservationRow.fromJson(Map<String, dynamic> j) => ReservationRow(
        id: j['id']?.toString() ?? '',
        reservationCode: j['reservationCode']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        expiresAt: _str(j['expiresAt']),
        items: _maps(j['items']).map(ReservationItemRow.fromJson).toList(),
      );
}

/// Mặt hàng (web `Material`) — chỉ các trường form chứng từ cần.
class DocMaterial {
  final String id;
  final String code;
  final String name;
  final String unit;
  final bool isSerialized;
  final bool isActive;

  /// `GOODS` hoặc `SERVICE`.
  final String kind;
  const DocMaterial({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.isSerialized,
    required this.isActive,
    required this.kind,
  });

  factory DocMaterial.fromJson(Map<String, dynamic> j) => DocMaterial(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        unit: j['unit']?.toString() ?? '',
        isSerialized: j['isSerialized'] == true,
        isActive: j['isActive'] != false,
        kind: j['kind']?.toString() ?? 'GOODS',
      );
}

class DocWarehouse {
  final String id;
  final String code;
  final String name;
  final bool isActive;
  const DocWarehouse({required this.id, required this.code, required this.name, required this.isActive});

  String get label => '$code - $name';

  factory DocWarehouse.fromJson(Map<String, dynamic> j) => DocWarehouse(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        isActive: j['isActive'] != false,
      );
}

class LotBalanceRow {
  final String warehouseCode;
  final double quantity;
  final double available;
  const LotBalanceRow(this.warehouseCode, this.quantity, this.available);

  factory LotBalanceRow.fromJson(Map<String, dynamic> j) =>
      LotBalanceRow(j['warehouseCode']?.toString() ?? '', _num(j['quantity']), _num(j['available']));
}

class LotRow {
  final String lotNo;
  final String? expiresOn;
  final String? manufacturedOn;
  final String qualityStatus;
  final List<LotBalanceRow> balances;
  const LotRow({
    required this.lotNo,
    this.expiresOn,
    this.manufacturedOn,
    required this.qualityStatus,
    this.balances = const [],
  });

  factory LotRow.fromJson(Map<String, dynamic> j) => LotRow(
        lotNo: j['lotNo']?.toString() ?? '',
        expiresOn: _date(j['expiresOn']),
        manufacturedOn: _date(j['manufacturedOn']),
        qualityStatus: j['qualityStatus']?.toString() ?? 'PASSED',
        balances: _maps(j['balances']).map(LotBalanceRow.fromJson).toList(),
      );
}

class SerialRow {
  final String serialNumber;
  final String? currentWarehouseId;
  final String? qualityStatus;
  final String? stockState;
  const SerialRow(this.serialNumber, this.currentWarehouseId, this.qualityStatus, this.stockState);

  factory SerialRow.fromJson(Map<String, dynamic> j) => SerialRow(
        j['serialNumber']?.toString() ?? '',
        _str(j['currentWarehouseId']),
        _str(j['qualityStatus']),
        _str(j['stockState']),
      );
}
