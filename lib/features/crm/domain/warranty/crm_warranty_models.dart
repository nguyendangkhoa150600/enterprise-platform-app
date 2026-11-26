import '../common/crm_json.dart';
import '../crm_capabilities.dart';

/// Bảo hành, đổi trả (contracts `warranty.ts`).

const List<String> kCrmWarrantyCauses = ['TECHNICAL_FAULT', 'WRONG_ITEM', 'SHORTAGE', 'CHANGE_OF_MIND', 'POLICY_RETURN'];
const List<String> kCrmWarrantyStatuses = [
  'RECEIVED',
  'AWAITING_GOODS',
  'INSPECTING',
  'RESOLVING',
  'RESOLVED',
  'REJECTED',
  'CLOSED',
];
const List<String> kCrmWarrantyInspectionResults = ['PASSED', 'DEFECTIVE'];
const List<String> kCrmWarrantyRemedies = ['NONE', 'REPLACE', 'REFUND', 'CREDIT'];

/// Hạn bảo hành (contracts `WarrantyCoverage`).
class CrmWarrantyCoverage {
  final String? deliveredOn;
  final int? months;
  final String source;
  final String? warrantyUntil;
  final int remainingDays;
  final bool expired;

  const CrmWarrantyCoverage({
    this.deliveredOn,
    this.months,
    required this.source,
    this.warrantyUntil,
    required this.remainingDays,
    required this.expired,
  });

  factory CrmWarrantyCoverage.fromJson(Object? raw) {
    final json = CrmJson.map(raw);
    return CrmWarrantyCoverage(
      deliveredOn: CrmJson.strOrNull(json['deliveredOn']),
      months: CrmJson.intOrNull(json['months']),
      source: CrmJson.str(json['source'], 'NONE'),
      warrantyUntil: CrmJson.strOrNull(json['warrantyUntil']),
      remainingDays: CrmJson.integer(json['remainingDays']),
      expired: CrmJson.boolean(json['expired']),
    );
  }
}

/// Kết quả tra cứu serial (contracts `WarrantyLookupItem`).
class CrmWarrantyLookupItem {
  final String? serial;
  final String materialCode;
  final String materialName;
  final String customerCode;
  final String customerName;
  final String? orderCode;
  final String? contractCode;
  final String? deliveryCode;
  final CrmWarrantyCoverage coverage;
  final String? replacementOfCaseCode;
  final String? replacementOfSerial;
  final String? openCaseId;

  const CrmWarrantyLookupItem({
    this.serial,
    required this.materialCode,
    required this.materialName,
    required this.customerCode,
    required this.customerName,
    this.orderCode,
    this.contractCode,
    this.deliveryCode,
    required this.coverage,
    this.replacementOfCaseCode,
    this.replacementOfSerial,
    this.openCaseId,
  });

  factory CrmWarrantyLookupItem.fromJson(Map<String, dynamic> json) {
    final replacement = json['replacementOf'] is Map ? CrmJson.map(json['replacementOf']) : null;
    return CrmWarrantyLookupItem(
      serial: CrmJson.strOrNull(json['serial']),
      materialCode: CrmJson.str(json['materialCode']),
      materialName: CrmJson.str(json['materialName']),
      customerCode: CrmJson.str(json['customerCode']),
      customerName: CrmJson.str(json['customerName']),
      orderCode: CrmJson.strOrNull(json['orderCode']),
      contractCode: CrmJson.strOrNull(json['contractCode']),
      deliveryCode: CrmJson.strOrNull(json['deliveryCode']),
      coverage: CrmWarrantyCoverage.fromJson(json['coverage']),
      replacementOfCaseCode: replacement == null ? null : CrmJson.str(replacement['caseCode']),
      replacementOfSerial: replacement == null ? null : CrmJson.strOrNull(replacement['serial']),
      openCaseId: CrmJson.strOrNull(json['openCaseId']),
    );
  }
}

/// Yêu cầu bảo hành trong danh sách (contracts `WarrantyCaseSummary`).
class CrmWarrantyCaseSummary {
  final String id;
  final String code;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String? orderId;
  final String? orderCode;
  final String cause;
  final String status;
  final bool chargeable;
  final int lineCount;
  final List<String> serials;
  final String ownerUserId;
  final String? assigneeUserId;
  final String createdAt;

  const CrmWarrantyCaseSummary({
    required this.id,
    required this.code,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    this.orderId,
    this.orderCode,
    required this.cause,
    required this.status,
    required this.chargeable,
    required this.lineCount,
    required this.serials,
    required this.ownerUserId,
    this.assigneeUserId,
    required this.createdAt,
  });

  factory CrmWarrantyCaseSummary.fromJson(Map<String, dynamic> json) => CrmWarrantyCaseSummary(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        orderId: CrmJson.strOrNull(json['orderId']),
        orderCode: CrmJson.strOrNull(json['orderCode']),
        cause: CrmJson.str(json['cause']),
        status: CrmJson.str(json['status']),
        chargeable: CrmJson.boolean(json['chargeable']),
        lineCount: CrmJson.integer(json['lineCount']),
        serials: CrmJson.strings(json['serials']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        assigneeUserId: CrmJson.strOrNull(json['assigneeUserId']),
        createdAt: CrmJson.str(json['createdAt']),
      );
}

/// Dòng yêu cầu (contracts `WarrantyCaseLine`).
class CrmWarrantyCaseLine {
  final String id;
  final int lineNo;
  final String? serial;
  final String materialCode;
  final String materialName;
  final String unit;
  final double quantity;
  final String? orderLineId;
  final CrmWarrantyCoverage coverage;
  final String? receivedAt;
  final String? deliveryWarehouseCode;
  final String? inspectionResult;
  final String? inspectionNote;
  final String? disposition;
  final String? remedy;
  final List<String> replacementSerials;
  final String? replacementWarrantyUntil;
  final double? creditAmount;

  const CrmWarrantyCaseLine({
    required this.id,
    required this.lineNo,
    this.serial,
    required this.materialCode,
    required this.materialName,
    required this.unit,
    required this.quantity,
    this.orderLineId,
    required this.coverage,
    this.receivedAt,
    this.deliveryWarehouseCode,
    this.inspectionResult,
    this.inspectionNote,
    this.disposition,
    this.remedy,
    this.replacementSerials = const [],
    this.replacementWarrantyUntil,
    this.creditAmount,
  });

  factory CrmWarrantyCaseLine.fromJson(Map<String, dynamic> json) => CrmWarrantyCaseLine(
        id: CrmJson.str(json['id']),
        lineNo: CrmJson.integer(json['lineNo']),
        serial: CrmJson.strOrNull(json['serial']),
        materialCode: CrmJson.str(json['materialCode']),
        materialName: CrmJson.str(json['materialName']),
        unit: CrmJson.str(json['unit']),
        quantity: CrmJson.number(json['quantity']),
        orderLineId: CrmJson.strOrNull(json['orderLineId']),
        coverage: CrmWarrantyCoverage.fromJson(json['coverage']),
        receivedAt: CrmJson.strOrNull(json['receivedAt']),
        deliveryWarehouseCode: CrmJson.strOrNull(json['deliveryWarehouseCode']),
        inspectionResult: CrmJson.strOrNull(json['inspectionResult']),
        inspectionNote: CrmJson.strOrNull(json['inspectionNote']),
        disposition: CrmJson.strOrNull(json['disposition']),
        remedy: CrmJson.strOrNull(json['remedy']),
        replacementSerials: CrmJson.strings(json['replacementSerials']),
        replacementWarrantyUntil: CrmJson.strOrNull(json['replacementWarrantyUntil']),
        creditAmount: CrmJson.numOrNull(json['creditAmount']),
      );
}

/// Chứng từ ở Kho / sổ công nợ (contracts `WarrantyDocument`).
class CrmWarrantyDocument {
  final String id;
  final String? lineId;
  final String kind;
  final String status;
  final String? documentCode;
  final double? amount;
  final String? lastError;

  const CrmWarrantyDocument({
    required this.id,
    this.lineId,
    required this.kind,
    required this.status,
    this.documentCode,
    this.amount,
    this.lastError,
  });

  factory CrmWarrantyDocument.fromJson(Map<String, dynamic> json) => CrmWarrantyDocument(
        id: CrmJson.str(json['id']),
        lineId: CrmJson.strOrNull(json['lineId']),
        kind: CrmJson.str(json['kind']),
        status: CrmJson.str(json['status']),
        documentCode: CrmJson.strOrNull(json['documentCode']),
        amount: CrmJson.numOrNull(json['amount']),
        lastError: CrmJson.strOrNull(json['lastError']),
      );
}

/// Một dòng nhật ký (contracts `WarrantyHistoryEntry`).
class CrmWarrantyHistoryEntry {
  final String id;
  final String at;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String? actorId;
  final String? reason;

  const CrmWarrantyHistoryEntry({
    required this.id,
    required this.at,
    required this.action,
    this.fromStatus,
    this.toStatus,
    this.actorId,
    this.reason,
  });

  factory CrmWarrantyHistoryEntry.fromJson(Map<String, dynamic> json) => CrmWarrantyHistoryEntry(
        id: CrmJson.str(json['id']),
        at: CrmJson.str(json['at']),
        action: CrmJson.str(json['action']),
        fromStatus: CrmJson.strOrNull(json['fromStatus']),
        toStatus: CrmJson.strOrNull(json['toStatus']),
        actorId: CrmJson.strOrNull(json['actorId']),
        reason: CrmJson.strOrNull(json['reason']),
      );
}

/// Chi tiết yêu cầu (contracts `WarrantyCaseDetail`).
class CrmWarrantyCaseDetail {
  final CrmWarrantyCaseSummary summary;
  final String? description;
  final String? quarantineWarehouseCode;
  final String? rejectReason;
  final int revision;
  final List<CrmWarrantyCaseLine> lines;
  final List<CrmWarrantyDocument> documents;
  final List<CrmWarrantyHistoryEntry> history;

  const CrmWarrantyCaseDetail({
    required this.summary,
    this.description,
    this.quarantineWarehouseCode,
    this.rejectReason,
    required this.revision,
    required this.lines,
    required this.documents,
    required this.history,
  });

  factory CrmWarrantyCaseDetail.fromJson(Map<String, dynamic> json) => CrmWarrantyCaseDetail(
        summary: CrmWarrantyCaseSummary.fromJson(json),
        description: CrmJson.strOrNull(json['description']),
        quarantineWarehouseCode: CrmJson.strOrNull(json['quarantineWarehouseCode']),
        rejectReason: CrmJson.strOrNull(json['rejectReason']),
        revision: CrmJson.integer(json['revision']),
        lines: CrmJson.list(json['lines'], CrmWarrantyCaseLine.fromJson),
        documents: CrmJson.list(json['documents'], CrmWarrantyDocument.fromJson),
        history: CrmJson.list(json['history'], CrmWarrantyHistoryEntry.fromJson),
      );

  String get id => summary.id;
  String get code => summary.code;
  String get status => summary.status;
}

/// Kho bảo hành (contracts `WarrantySettings`).
class CrmWarrantySettings {
  final String? quarantineWarehouseCode;
  final String? defectWarehouseCode;
  final String? restockWarehouseCode;

  const CrmWarrantySettings({this.quarantineWarehouseCode, this.defectWarehouseCode, this.restockWarehouseCode});

  factory CrmWarrantySettings.fromJson(Map<String, dynamic> json) => CrmWarrantySettings(
        quarantineWarehouseCode: CrmJson.strOrNull(json['quarantineWarehouseCode']),
        defectWarehouseCode: CrmJson.strOrNull(json['defectWarehouseCode']),
        restockWarehouseCode: CrmJson.strOrNull(json['restockWarehouseCode']),
      );
}

/// Bước kho của serial (contracts `WarrantySerialMovement`).
class CrmWarrantySerialMovement {
  final String movementType;
  final String? documentCode;
  final String? fromWarehouseCode;
  final String? toWarehouseCode;
  final String? reason;
  final String occurredAt;

  const CrmWarrantySerialMovement({
    required this.movementType,
    this.documentCode,
    this.fromWarehouseCode,
    this.toWarehouseCode,
    this.reason,
    required this.occurredAt,
  });

  factory CrmWarrantySerialMovement.fromJson(Map<String, dynamic> json) => CrmWarrantySerialMovement(
        movementType: CrmJson.str(json['movementType']),
        documentCode: CrmJson.strOrNull(json['documentCode']),
        fromWarehouseCode: CrmJson.strOrNull(json['fromWarehouseCode']),
        toWarehouseCode: CrmJson.strOrNull(json['toWarehouseCode']),
        reason: CrmJson.strOrNull(json['reason']),
        occurredAt: CrmJson.str(json['occurredAt']),
      );
}

/// Yêu cầu bảo hành có serial (trong lịch sử serial).
class CrmWarrantySerialCase {
  final String caseId;
  final String caseCode;
  final String status;
  final String role;
  final String at;

  const CrmWarrantySerialCase(
      {required this.caseId, required this.caseCode, required this.status, required this.role, required this.at});

  factory CrmWarrantySerialCase.fromJson(Map<String, dynamic> json) => CrmWarrantySerialCase(
        caseId: CrmJson.str(json['caseId']),
        caseCode: CrmJson.str(json['caseCode']),
        status: CrmJson.str(json['status']),
        role: CrmJson.str(json['role']),
        at: CrmJson.str(json['at']),
      );
}

/// Lịch sử serial (contracts `WarrantySerialHistory`).
class CrmWarrantySerialHistory {
  final List<CrmWarrantySerialMovement> movements;
  final bool inventoryAvailable;
  final List<CrmWarrantySerialCase> cases;

  const CrmWarrantySerialHistory({required this.movements, required this.inventoryAvailable, required this.cases});

  factory CrmWarrantySerialHistory.fromJson(Map<String, dynamic> json) => CrmWarrantySerialHistory(
        movements: CrmJson.list(json['movements'], CrmWarrantySerialMovement.fromJson),
        inventoryAvailable: CrmJson.boolean(json['inventoryAvailable']),
        cases: CrmJson.list(json['cases'], CrmWarrantySerialCase.fromJson),
      );
}

/// Tài liệu thiết bị từ Kho (contracts `WarrantyDeviceDocument`), chỉ đọc.
class CrmWarrantyDeviceDocument {
  final String id;
  final String lineId;
  final String materialCode;
  final String materialName;
  final String? serial;
  final String fileName;
  final String? note;
  final String createdAt;
  final String downloadUrl;

  const CrmWarrantyDeviceDocument({
    required this.id,
    required this.lineId,
    required this.materialCode,
    required this.materialName,
    this.serial,
    required this.fileName,
    this.note,
    required this.createdAt,
    required this.downloadUrl,
  });

  factory CrmWarrantyDeviceDocument.fromJson(Map<String, dynamic> json) => CrmWarrantyDeviceDocument(
        id: CrmJson.str(json['id']),
        lineId: CrmJson.str(json['lineId']),
        materialCode: CrmJson.str(json['materialCode']),
        materialName: CrmJson.str(json['materialName']),
        serial: CrmJson.strOrNull(json['serial']),
        fileName: CrmJson.str(json['fileName']),
        note: CrmJson.strOrNull(json['note']),
        createdAt: CrmJson.str(json['createdAt']),
        downloadUrl: CrmJson.str(json['downloadUrl']),
      );
}

// ---------------------------------------------------------------------------
// Logic thuần (web `warranty.model.ts`)
// ---------------------------------------------------------------------------

/// Được tiếp nhận, xử lý bảo hành (`crm.warranty.write`).
bool crmCanWriteWarranty(CrmCapabilities c) => c.isTenantAdmin || c.canWriteWarranty;

/// Hướng xử lý chọn được theo kết quả kiểm định.
List<String> crmWarrantyDispositionsFor(String? result) => switch (result) {
      'PASSED' => const ['RESTOCK'],
      'DEFECTIVE' => const ['MOVE_TO_DEFECT', 'SCRAP'],
      _ => const [],
    };

/// Nút hiện trên yêu cầu theo trạng thái và quyền (web `warrantyActions`):
/// `receive`, `reject`, `inspect`, `resolve`, `sync`, `close`.
List<String> crmWarrantyActions(CrmWarrantyCaseDetail detail, CrmCapabilities c) {
  if (!crmCanWriteWarranty(c)) return const [];
  final status = detail.status;
  CrmWarrantyDocument? receipt;
  for (final d in detail.documents) {
    if (d.kind == 'RETURN_RECEIPT') {
      receipt = d;
      break;
    }
  }
  final resend = detail.documents.any((d) => d.status == 'PENDING' || d.status == 'PENDING_RECEIVABLE');
  return [
    if (status == 'RECEIVED') ...['receive', 'reject'],
    if (status == 'AWAITING_GOODS' && receipt?.status != 'POSTED') 'receive',
    if (status == 'INSPECTING') 'inspect',
    if (status == 'RESOLVING') 'resolve',
    if ((status == 'RESOLVING' || status == 'RESOLVED') && resend) 'sync',
    if (status == 'RESOLVED' || status == 'REJECTED') 'close',
  ];
}
