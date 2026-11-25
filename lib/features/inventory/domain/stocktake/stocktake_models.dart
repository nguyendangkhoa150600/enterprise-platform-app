/// Model kiểm kê kho theo hợp đồng web `contracts-inventory.ts` (StocktakeSession, StocktakeLine, ...).
/// Tên có tiền tố `Inv` để không đụng model cũ trong `lib/models/inventory_models.dart`.
library;

double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

/// Trạng thái đợt kiểm kê (web `StocktakeStatus`).
class StocktakeStatuses {
  StocktakeStatuses._();
  static const draft = 'DRAFT';
  static const counting = 'COUNTING';
  static const pendingApproval = 'PENDING_APPROVAL';
  static const approved = 'APPROVED';
  static const posted = 'POSTED';
  static const cancelled = 'CANCELLED';
  static const all = [draft, counting, pendingApproval, approved, posted, cancelled];
}

class InvStocktakeLotAllocation {
  final String lotNumber;
  final double systemQty;
  final double actualQty;
  final String? expiryDate;

  const InvStocktakeLotAllocation({
    required this.lotNumber,
    required this.systemQty,
    required this.actualQty,
    this.expiryDate,
  });

  factory InvStocktakeLotAllocation.fromJson(Map<String, dynamic> j) => InvStocktakeLotAllocation(
        lotNumber: j['lotNumber']?.toString() ?? '',
        systemQty: _num(j['systemQty']) ?? 0,
        actualQty: _num(j['actualQty']) ?? 0,
        expiryDate: _str(j['expiryDate']),
      );

  InvStocktakeLotAllocation copyWith({double? actualQty}) => InvStocktakeLotAllocation(
        lotNumber: lotNumber,
        systemQty: systemQty,
        actualQty: actualQty ?? this.actualQty,
        expiryDate: expiryDate,
      );

  Map<String, dynamic> toJson() => {
        'lotNumber': lotNumber,
        'systemQty': systemQty,
        'actualQty': actualQty,
        if (expiryDate != null) 'expiryDate': expiryDate,
      };
}

class InvStocktakeSerialAllocation {
  final String serialNumber;

  /// FOUND | MISSING | EXTRA
  final String status;

  const InvStocktakeSerialAllocation({required this.serialNumber, required this.status});

  factory InvStocktakeSerialAllocation.fromJson(Map<String, dynamic> j) => InvStocktakeSerialAllocation(
        serialNumber: j['serialNumber']?.toString() ?? '',
        status: j['status']?.toString() ?? 'FOUND',
      );

  Map<String, dynamic> toJson() => {'serialNumber': serialNumber, 'status': status};
}

class InvStocktakeLineAudit {
  final double? previousQuantity;
  final double newQuantity;
  final String operator;
  final String timestamp;
  final String? reason;

  const InvStocktakeLineAudit({
    this.previousQuantity,
    required this.newQuantity,
    required this.operator,
    required this.timestamp,
    this.reason,
  });

  factory InvStocktakeLineAudit.fromJson(Map<String, dynamic> j) => InvStocktakeLineAudit(
        previousQuantity: _num(j['previousQuantity']),
        newQuantity: _num(j['newQuantity']) ?? 0,
        operator: j['operator']?.toString() ?? '',
        timestamp: j['timestamp']?.toString() ?? '',
        reason: _str(j['reason']),
      );
}

class InvStocktakeLine {
  final String id;
  final String sessionId;
  final String materialId;
  final String materialCode;
  final String materialName;
  final String unit;
  final String? binLocation;
  final bool isSerialized;
  final bool isLotTracked;
  final double systemQuantity;
  final double? countRound1;
  final double? countRound2;
  final double? actualQuantity;
  final double difference;
  final double? unitCost;
  final double? differenceValue;
  final String? reason;

  /// UNCOUNTED | MATCHED | SURPLUS | DEFICIT
  final String status;
  final List<InvStocktakeLotAllocation>? lotAllocations;
  final List<InvStocktakeSerialAllocation>? serialAllocations;
  final String? note;
  final List<InvStocktakeLineAudit> audits;

  const InvStocktakeLine({
    required this.id,
    required this.sessionId,
    required this.materialId,
    required this.materialCode,
    required this.materialName,
    required this.unit,
    this.binLocation,
    this.isSerialized = false,
    this.isLotTracked = false,
    required this.systemQuantity,
    this.countRound1,
    this.countRound2,
    this.actualQuantity,
    this.difference = 0,
    this.unitCost,
    this.differenceValue,
    this.reason,
    this.status = 'UNCOUNTED',
    this.lotAllocations,
    this.serialAllocations,
    this.note,
    this.audits = const [],
  });

  bool get isCounted => actualQuantity != null;
  bool get hasDiff => difference != 0 && actualQuantity != null;
  bool get isLotOrSerial => isLotTracked || isSerialized;

  factory InvStocktakeLine.fromJson(Map<String, dynamic> j) {
    List<T>? list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
        v is List ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList() : null;
    return InvStocktakeLine(
      id: j['id']?.toString() ?? '',
      sessionId: j['sessionId']?.toString() ?? '',
      materialId: j['materialId']?.toString() ?? '',
      materialCode: j['materialCode']?.toString() ?? '',
      materialName: j['materialName']?.toString() ?? '',
      unit: j['unit']?.toString() ?? '',
      binLocation: _str(j['binLocation']),
      isSerialized: j['isSerialized'] == true,
      isLotTracked: j['isLotTracked'] == true,
      systemQuantity: _num(j['systemQuantity']) ?? 0,
      countRound1: _num(j['countRound1']),
      countRound2: _num(j['countRound2']),
      actualQuantity: _num(j['actualQuantity']),
      difference: _num(j['difference']) ?? 0,
      unitCost: _num(j['unitCost']),
      differenceValue: _num(j['differenceValue']),
      reason: j['reason']?.toString(),
      status: j['status']?.toString() ?? 'UNCOUNTED',
      lotAllocations: list(j['lotAllocations'], InvStocktakeLotAllocation.fromJson),
      serialAllocations: list(j['serialAllocations'], InvStocktakeSerialAllocation.fromJson),
      note: j['note']?.toString(),
      audits: list(j['audits'], InvStocktakeLineAudit.fromJson) ?? const [],
    );
  }

  /// Đổi số thực đếm trên máy, tính lại chênh lệch/trạng thái như web `handleLineCountChange`.
  InvStocktakeLine withCount(
    double? actual, {
    List<InvStocktakeLotAllocation>? lots,
    List<InvStocktakeSerialAllocation>? serials,
    bool replaceAllocations = false,
  }) {
    final diff = actual != null ? actual - systemQuantity : 0.0;
    var nextStatus = 'UNCOUNTED';
    if (actual != null) {
      if (diff == 0) {
        nextStatus = 'MATCHED';
      } else if (diff > 0) {
        nextStatus = 'SURPLUS';
      } else {
        nextStatus = 'DEFICIT';
      }
    }
    return _copy(
      actualQuantity: actual,
      clearActual: actual == null,
      difference: diff,
      differenceValue: diff * (unitCost ?? 0),
      status: nextStatus,
      lotAllocations: replaceAllocations ? lots : lotAllocations,
      serialAllocations: replaceAllocations ? serials : serialAllocations,
    );
  }

  InvStocktakeLine withReason(String value) => _copy(reason: value);

  /// Đổi vị trí kệ trên máy (web nạp từ cột "Vị trí kệ" khi Nhập Excel; server không lưu trường này).
  InvStocktakeLine withBinLocation(String value) => _copy(binLocation: value);

  InvStocktakeLine _copy({
    double? actualQuantity,
    bool clearActual = false,
    double? difference,
    double? differenceValue,
    String? status,
    String? reason,
    String? binLocation,
    List<InvStocktakeLotAllocation>? lotAllocations,
    List<InvStocktakeSerialAllocation>? serialAllocations,
  }) =>
      InvStocktakeLine(
        id: id,
        sessionId: sessionId,
        materialId: materialId,
        materialCode: materialCode,
        materialName: materialName,
        unit: unit,
        binLocation: binLocation ?? this.binLocation,
        isSerialized: isSerialized,
        isLotTracked: isLotTracked,
        systemQuantity: systemQuantity,
        countRound1: countRound1,
        countRound2: countRound2,
        actualQuantity: clearActual ? null : (actualQuantity ?? this.actualQuantity),
        difference: difference ?? this.difference,
        unitCost: unitCost,
        differenceValue: differenceValue ?? this.differenceValue,
        reason: reason ?? this.reason,
        status: status ?? this.status,
        lotAllocations: lotAllocations ?? this.lotAllocations,
        serialAllocations: serialAllocations ?? this.serialAllocations,
        note: note,
        audits: audits,
      );

  /// Dòng có dữ liệu người dùng nhập (web `hasCountData`).
  bool get hasCountData =>
      actualQuantity != null ||
      countRound1 != null ||
      countRound2 != null ||
      (reason?.trim().isNotEmpty ?? false) ||
      (note?.trim().isNotEmpty ?? false);

  /// Payload một dòng cho `PATCH /stocktakes/:id/lines` (web `toLineUpdate`; bỏ trường rỗng như JSON.stringify).
  Map<String, dynamic> toUpdateJson() => {
        'lineId': id,
        if (countRound1 != null) 'countRound1': countRound1,
        if (countRound2 != null) 'countRound2': countRound2,
        if (actualQuantity != null) 'actualQuantity': actualQuantity,
        if (reason != null) 'reason': reason,
        if (note != null) 'note': note,
        if (lotAllocations != null) 'lotAllocations': lotAllocations!.map((e) => e.toJson()).toList(),
        if (serialAllocations != null) 'serialAllocations': serialAllocations!.map((e) => e.toJson()).toList(),
      };
}

class InvStocktakeSession {
  final String id;
  final String code;
  final String title;
  final String warehouseId;
  final String warehouseCode;
  final String? warehouseName;
  final String status;
  final String scopeType;
  final String? stocktakeDate;
  final String? leadAuditor;
  final List<String> auditors;
  final String? note;
  final int totalItems;
  final int countedItems;
  final int differenceItems;
  final double totalVarianceValue;
  final String? createdBy;
  final String? submittedBy;
  final String? rejectReason;
  final String? cancelReason;
  final String? documentCode;

  const InvStocktakeSession({
    required this.id,
    required this.code,
    required this.title,
    required this.warehouseId,
    required this.warehouseCode,
    this.warehouseName,
    required this.status,
    this.scopeType = 'ALL',
    this.stocktakeDate,
    this.leadAuditor,
    this.auditors = const [],
    this.note,
    this.totalItems = 0,
    this.countedItems = 0,
    this.differenceItems = 0,
    this.totalVarianceValue = 0,
    this.createdBy,
    this.submittedBy,
    this.rejectReason,
    this.cancelReason,
    this.documentCode,
  });

  factory InvStocktakeSession.fromJson(Map<String, dynamic> j) => InvStocktakeSession(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        warehouseId: j['warehouseId']?.toString() ?? '',
        warehouseCode: j['warehouseCode']?.toString() ?? '',
        warehouseName: _str(j['warehouseName']),
        status: j['status']?.toString() ?? StocktakeStatuses.draft,
        scopeType: j['scopeType']?.toString() ?? 'ALL',
        stocktakeDate: _str(j['stocktakeDate']),
        leadAuditor: _str(j['leadAuditor']),
        auditors: _strList(j['auditors']),
        note: _str(j['note']),
        totalItems: (_num(j['totalItems']) ?? 0).toInt(),
        countedItems: (_num(j['countedItems']) ?? 0).toInt(),
        differenceItems: (_num(j['differenceItems']) ?? 0).toInt(),
        totalVarianceValue: _num(j['totalVarianceValue']) ?? 0,
        createdBy: _str(j['createdBy']),
        submittedBy: _str(j['submittedBy']),
        rejectReason: _str(j['rejectReason']),
        cancelReason: _str(j['cancelReason']),
        documentCode: _str(j['documentCode']),
      );

  /// Web `isSelfApprovalBlocked`: chỉ để ẩn nút, server vẫn chặn tự duyệt.
  bool isSelfApprovalBlocked(String? viewerId, bool allowSelfApproval) {
    if (allowSelfApproval || viewerId == null || viewerId.isEmpty) return false;
    return createdBy == viewerId || submittedBy == viewerId;
  }
}

/// Nhân sự có thể tham gia tổ kiểm kê (web `AuditorCandidate`).
class InvAuditorCandidate {
  final String id;
  final String name;
  final String? code;
  final String? department;
  final String? position;
  final String? email;
  final bool hasWarehouseAccess;

  const InvAuditorCandidate({
    required this.id,
    required this.name,
    this.code,
    this.department,
    this.position,
    this.email,
    this.hasWarehouseAccess = false,
  });

  factory InvAuditorCandidate.fromJson(Map<String, dynamic> j) => InvAuditorCandidate(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        code: _str(j['code']),
        department: _str(j['department']),
        position: _str(j['position']),
        email: _str(j['email']),
        hasWarehouseAccess: j['hasWarehouseAccess'] == true,
      );

  bool matches(String q) {
    final lower = q.trim().toLowerCase();
    if (lower.isEmpty) return true;
    return name.toLowerCase().contains(lower) ||
        (code?.toLowerCase().contains(lower) ?? false) ||
        (department?.toLowerCase().contains(lower) ?? false) ||
        (position?.toLowerCase().contains(lower) ?? false) ||
        (email?.toLowerCase().contains(lower) ?? false);
  }
}

/// Kho tối giản cho bộ lọc và form tạo đợt.
class InvStocktakeWarehouse {
  final String id;
  final String code;
  final String name;
  final String? location;

  const InvStocktakeWarehouse({required this.id, required this.code, required this.name, this.location});

  factory InvStocktakeWarehouse.fromJson(Map<String, dynamic> j) => InvStocktakeWarehouse(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        location: _str(j['location']),
      );
}

/// Vật tư tối giản cho form tạo đợt (phạm vi nhóm / vật tư cụ thể).
class InvStocktakeMaterial {
  final String id;
  final String code;
  final String name;
  final String unit;
  final String? type;

  const InvStocktakeMaterial({required this.id, required this.code, required this.name, required this.unit, this.type});

  factory InvStocktakeMaterial.fromJson(Map<String, dynamic> j) => InvStocktakeMaterial(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        unit: j['unit']?.toString() ?? '',
        type: _str(j['type']),
      );
}

/// Kết quả các thao tác trả về đợt + dòng (start, lưu số đếm).
class InvStocktakeLinesResult {
  final InvStocktakeSession session;
  final List<InvStocktakeLine> lines;
  const InvStocktakeLinesResult(this.session, this.lines);
}
