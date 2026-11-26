import '../../../../core/i18n/app_i18n.dart';
import 'stock_document_models.dart';

/// Logic thuần của chứng từ kho (web `stock-document.model.ts`, `stock-movement.model.ts`): nhãn, nút theo
/// trạng thái và quyền, kiểm form, chia lô FEFO, serial, tiến độ yêu cầu xuất. Server vẫn kiểm lại mọi quy tắc.

const List<String> kStockDocumentTypes = [
  'RECEIPT_PURCHASE',
  'RECEIPT_SALES_RETURN',
  'RECEIPT_TRANSFER',
  'RECEIPT_OTHER',
  'ISSUE_SALES',
  'ISSUE_PROJECT',
  'ISSUE_WARRANTY',
  'ISSUE_TRANSFER',
  'ISSUE_OTHER',
  'ADJUSTMENT',
  'TRANSFER',
];

const List<String> kStockDocumentStatuses = ['DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'POSTED', 'CANCELLED'];

/// Loại chứng từ người dùng tự lập trên màn Kho.
const List<String> kManualDocumentTypes = [
  'RECEIPT_PURCHASE',
  'RECEIPT_OTHER',
  'ISSUE_PROJECT',
  'ISSUE_OTHER',
  'TRANSFER',
  'ADJUSTMENT',
];

/// Loại chứng từ xuất do Bán hàng yêu cầu.
const List<String> kIssueRequestTypes = ['ISSUE_SALES', 'ISSUE_WARRANTY'];

/// Nguồn phát sinh hay gặp, cho bộ lọc danh sách gộp.
const List<String> kMovementSourceCodes = [
  'manual',
  'crm_sales_order',
  'crm_delivery',
  'crm_warranty',
  'crm_return',
  'procedure',
  'maintenance',
  'stocktake',
  'asset',
  'opening_balance',
];

String docTypeLabel(String type) =>
    kStockDocumentTypes.contains(type) ? 'inventory.documents.type.$type'.tr() : type;

String docStatusLabel(String status) =>
    kStockDocumentStatuses.contains(status) ? 'inventory.documents.status.$status'.tr() : status;

const Map<String, String> _sourceKey = {
  'manual': 'manual',
  'crm_order': 'crm_sales_order',
  'crm_sales_order': 'crm_sales_order',
  'crm_delivery': 'crm_delivery',
  'crm_warranty': 'crm_warranty',
  'crm_return': 'crm_return',
  'procedure': 'procedure',
  'maintenance': 'maintenance',
  'stocktake': 'stocktake',
  'asset': 'asset',
  'opening_balance': 'opening_balance',
};

/// Nguồn phát sinh; trống là Thủ công, mã lạ hiện nguyên văn.
String sourceTypeLabel(String? value) {
  final code = value?.trim() ?? '';
  if (code.isEmpty) return 'inventory.documents.source.manual'.tr();
  final key = _sourceKey[code.toLowerCase()];
  return key == null ? code : 'inventory.documents.source.$key'.tr();
}

const List<String> _txTypes = ['IMPORT', 'EXPORT', 'TRANSFER_OUT', 'TRANSFER_IN', 'BORROW', 'RETURN', 'ADJUST'];

/// Loại của một dòng danh sách gộp: nhãn loại chứng từ, hoặc nhãn loại bút toán cho dòng cũ.
String movementTypeLabel(StockMovementRow row) {
  if (row.kind == 'document' && kStockDocumentTypes.contains(row.type)) return docTypeLabel(row.type);
  return _txTypes.contains(row.type) ? 'inventory.documents.tx_type.${row.type}'.tr() : row.type;
}

String warehousePairLabel(String code, String? target) =>
    (target != null && target.isNotEmpty) ? '$code → $target' : code;

String movementMaterialLabel(StockMovementRow row) {
  final code = row.materialCode;
  if (code == null || code.isEmpty) return '—';
  final first = (row.materialName?.isNotEmpty ?? false) ? '$code - ${row.materialName}' : code;
  return row.lineCount > 1
      ? 'inventory.documents.material_and_more'.tr(args: {'first': first, 'n': row.lineCount - 1})
      : first;
}

String reservationStatusLabel(String status) {
  const known = ['PENDING', 'RESERVED', 'PARTIALLY_ISSUED', 'COMPLETED', 'CANCELLED', 'EXPIRED'];
  return known.contains(status) ? 'inventory.documents.reservation_status.$status'.tr() : status;
}

String qualityStatusLabel(String status) {
  const known = ['PASSED', 'QUARANTINE', 'DEFECTIVE', 'PENDING_INSPECTION'];
  return known.contains(status) ? 'inventory.documents.quality.$status'.tr() : status;
}

// ---------------------------------------------------------------- Quy tắc theo loại

const Set<String> _approvalRequired = {'RECEIPT_OTHER', 'ISSUE_OTHER', 'ADJUSTMENT'};
const Set<String> _approvalWithoutSource = {'RECEIPT_PURCHASE', 'ISSUE_PROJECT'};
const Set<String> _serialsRequired = {'ISSUE_SALES', 'ISSUE_WARRANTY', 'RECEIPT_SALES_RETURN'};

bool requiresApproval(String docType, [String? sourceId]) {
  if (_approvalRequired.contains(docType)) return true;
  return _approvalWithoutSource.contains(docType) && (sourceId?.trim() ?? '').isEmpty;
}

bool requiresSerials(String docType) => _serialsRequired.contains(docType);

bool isReceiptType(String docType) => docType.startsWith('RECEIPT_');

/// Chiều của dòng: nhập luôn IN, xuất và điều chuyển luôn OUT, điều chỉnh theo người lập chọn.
String? lineDirection(String docType, [String? chosen]) {
  if (docType == 'ADJUSTMENT') return chosen;
  return isReceiptType(docType) ? 'IN' : 'OUT';
}

// ---------------------------------------------------------------- Nút theo trạng thái

enum DocAction { edit, submit, post, cancel, approve, reject, reverse }

String docActionLabel(DocAction a) => 'inventory.documents.action.${a.name}'.tr();

List<DocAction> availableDocumentActions(StockDoc doc, {required bool canWrite, required bool canApprove}) {
  final actions = <DocAction>[];
  switch (doc.status) {
    case 'DRAFT':
      if (canWrite) {
        actions.add(DocAction.edit);
        actions.add(requiresApproval(doc.docType, doc.sourceId) ? DocAction.submit : DocAction.post);
        actions.add(DocAction.cancel);
      }
      break;
    case 'REJECTED':
      if (canWrite) actions.add(DocAction.edit);
      break;
    case 'PENDING':
      if (canApprove) actions.addAll([DocAction.approve, DocAction.reject]);
      if (canWrite) actions.add(DocAction.cancel);
      break;
    case 'APPROVED':
      if (canWrite) actions.addAll([DocAction.post, DocAction.cancel]);
      break;
    case 'POSTED':
      if (canApprove && (doc.reversesDocumentId ?? '').isEmpty) actions.add(DocAction.reverse);
      break;
  }
  return actions;
}

// ---------------------------------------------------------------- Bản nháp

int _lineSeq = 0;
String newLineKey() {
  _lineSeq += 1;
  return 'line-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$_lineSeq';
}

class DraftLine {
  final String key;
  final String materialCode;
  final double quantity;
  final String? direction;
  final double? unitCost;
  final String? lotNo;
  final String? lotExpiresOn;
  final String? lotManufacturedOn;
  final List<String> serials;
  final String? reservationId;
  final String? sourceLineId;
  final String? note;

  const DraftLine({
    required this.key,
    this.materialCode = '',
    this.quantity = 1,
    this.direction,
    this.unitCost,
    this.lotNo,
    this.lotExpiresOn,
    this.lotManufacturedOn,
    this.serials = const [],
    this.reservationId,
    this.sourceLineId,
    this.note,
  });

  factory DraftLine.empty() => DraftLine(key: newLineKey());

  factory DraftLine.fromLine(StockDocLine l) => DraftLine(
        key: newLineKey(),
        materialCode: l.materialCode,
        quantity: l.quantity,
        direction: l.direction,
        unitCost: l.unitCost == 0 ? null : l.unitCost,
        lotNo: l.lotNo,
        lotExpiresOn: l.lotExpiresOn,
        serials: List.of(l.serials),
        reservationId: l.reservationId,
        sourceLineId: l.sourceLineId,
        note: l.note,
      );

  static const _keep = Object();

  DraftLine copyWith({
    String? key,
    String? materialCode,
    double? quantity,
    Object? direction = _keep,
    Object? unitCost = _keep,
    Object? lotNo = _keep,
    Object? lotExpiresOn = _keep,
    List<String>? serials,
    Object? note = _keep,
  }) =>
      DraftLine(
        key: key ?? this.key,
        materialCode: materialCode ?? this.materialCode,
        quantity: quantity ?? this.quantity,
        direction: identical(direction, _keep) ? this.direction : direction as String?,
        unitCost: identical(unitCost, _keep) ? this.unitCost : unitCost as double?,
        lotNo: identical(lotNo, _keep) ? this.lotNo : lotNo as String?,
        lotExpiresOn: identical(lotExpiresOn, _keep) ? this.lotExpiresOn : lotExpiresOn as String?,
        lotManufacturedOn: lotManufacturedOn,
        serials: serials ?? this.serials,
        reservationId: reservationId,
        sourceLineId: sourceLineId,
        note: identical(note, _keep) ? this.note : note as String?,
      );
}

class DocumentDraft {
  final String docType;
  final String warehouseCode;
  final String? targetWarehouseCode;
  final String documentDate;
  final String? note;
  final String? sourceType;
  final String? sourceId;
  final List<DraftLine> lines;

  const DocumentDraft({
    required this.docType,
    required this.warehouseCode,
    this.targetWarehouseCode,
    required this.documentDate,
    this.note,
    this.sourceType,
    this.sourceId,
    required this.lines,
  });

  factory DocumentDraft.empty([String docType = 'RECEIPT_PURCHASE', String warehouseCode = '']) =>
      DocumentDraft(docType: docType, warehouseCode: warehouseCode, documentDate: todayIso(), lines: [DraftLine.empty()]);

  factory DocumentDraft.fromDocument(StockDoc d) => DocumentDraft(
        docType: d.docType,
        warehouseCode: d.warehouseCode,
        targetWarehouseCode: d.targetWarehouseCode,
        documentDate: d.documentDate,
        note: d.note,
        sourceType: d.sourceType,
        sourceId: d.sourceId,
        lines: d.lines.map(DraftLine.fromLine).toList(),
      );

  static const _keep = Object();

  DocumentDraft copyWith({
    String? docType,
    String? warehouseCode,
    Object? targetWarehouseCode = _keep,
    String? documentDate,
    Object? note = _keep,
    Object? sourceType = _keep,
    List<DraftLine>? lines,
  }) =>
      DocumentDraft(
        docType: docType ?? this.docType,
        warehouseCode: warehouseCode ?? this.warehouseCode,
        targetWarehouseCode:
            identical(targetWarehouseCode, _keep) ? this.targetWarehouseCode : targetWarehouseCode as String?,
        documentDate: documentDate ?? this.documentDate,
        note: identical(note, _keep) ? this.note : note as String?,
        sourceType: identical(sourceType, _keep) ? this.sourceType : sourceType as String?,
        sourceId: sourceId,
        lines: lines ?? this.lines,
      );
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String todayIso() => isoDate(DateTime.now());

/// Số gửi API: số nguyên gửi int để JSON gọn như web.
num jsonNumber(double v) => v == v.truncateToDouble() ? v.toInt() : v;

Map<String, dynamic> draftLineToInput(String docType, DraftLine line) {
  final direction = lineDirection(docType, line.direction);
  final inbound = direction == 'IN';
  final lotNo = line.lotNo?.trim() ?? '';
  final note = line.note?.trim() ?? '';
  return {
    'materialCode': line.materialCode.trim(),
    'quantity': jsonNumber(line.quantity),
    if (docType == 'ADJUSTMENT' && direction != null) 'direction': direction,
    if (inbound && line.unitCost != null) 'unitCost': jsonNumber(line.unitCost!),
    if (lotNo.isNotEmpty)
      'lot': {
        'lotNo': lotNo,
        if (inbound && (line.lotExpiresOn ?? '').isNotEmpty) 'expiresOn': line.lotExpiresOn,
        if (inbound && (line.lotManufacturedOn ?? '').isNotEmpty) 'manufacturedOn': line.lotManufacturedOn,
      },
    if (line.serials.isNotEmpty) 'serials': List.of(line.serials),
    if ((line.reservationId ?? '').isNotEmpty) 'reservationId': line.reservationId,
    if ((line.sourceLineId ?? '').isNotEmpty) 'sourceLineId': line.sourceLineId,
    if (note.isNotEmpty) 'note': note,
  };
}

Map<String, dynamic> draftToCreateRequest(DocumentDraft d) {
  final note = d.note?.trim() ?? '';
  final sourceType = d.sourceType?.trim() ?? '';
  final sourceId = d.sourceId?.trim() ?? '';
  return {
    'docType': d.docType,
    'warehouseCode': d.warehouseCode.trim(),
    if (d.docType == 'TRANSFER' && (d.targetWarehouseCode ?? '').isNotEmpty)
      'targetWarehouseCode': d.targetWarehouseCode!.trim(),
    'documentDate': d.documentDate,
    if (note.isNotEmpty) 'note': note,
    if (sourceType.isNotEmpty) 'sourceType': sourceType,
    if (sourceId.isNotEmpty) 'sourceId': sourceId,
    'lines': d.lines.map((l) => draftLineToInput(d.docType, l)).toList(),
  };
}

// ---------------------------------------------------------------- Kiểm form

class DraftValidation {
  final List<String> header;
  final Map<String, List<String>> lines;
  const DraftValidation(this.header, this.lines);
  bool get valid => header.isEmpty && lines.isEmpty;
  List<String> get messages => [...header, ...lines.values.expand((e) => e)];
}

final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _uuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

String _v(String key, [Map<String, Object?>? args]) => 'inventory.documents.validate.$key'.tr(args: args);

String _qty(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

DraftValidation validateDraft(DocumentDraft draft, Map<String, DocMaterial> materials, {bool forPosting = false}) {
  final header = <String>[];
  final lines = <String, List<String>>{};
  if (draft.docType.isEmpty) header.add(_v('choose_type'));
  if (draft.warehouseCode.trim().isEmpty) header.add(_v('choose_warehouse'));
  if (draft.docType == 'TRANSFER') {
    final target = draft.targetWarehouseCode?.trim() ?? '';
    if (target.isEmpty) {
      header.add(_v('transfer_target'));
    } else if (target == draft.warehouseCode.trim()) {
      header.add(_v('transfer_same'));
    }
  }
  if (!_datePattern.hasMatch(draft.documentDate)) header.add(_v('bad_date'));
  final sourceId = draft.sourceId?.trim() ?? '';
  if (sourceId.isNotEmpty && !_uuidPattern.hasMatch(sourceId)) header.add(_v('bad_source'));
  if (draft.lines.isEmpty) header.add(_v('no_lines'));

  final serialOwner = <String, int>{};
  for (var i = 0; i < draft.lines.length; i++) {
    final line = draft.lines[i];
    final lineNo = i + 1;
    final errors = <String>[];
    final code = line.materialCode.trim();
    final material = code.isEmpty ? null : materials[code];
    final direction = lineDirection(draft.docType, line.direction);
    if (code.isEmpty) {
      errors.add(_v('choose_material'));
    } else if (material == null) {
      errors.add(_v('material_not_found', {'code': code}));
    } else if (material.kind == 'SERVICE') {
      errors.add(_v('service_material'));
    }
    final quantity = line.quantity;
    final qtyOk = quantity.isFinite && quantity > 0;
    if (!qtyOk) errors.add(_v('quantity_positive'));
    if (draft.docType == 'ADJUSTMENT' && direction == null) errors.add(_v('choose_direction'));
    if (line.unitCost != null && (!line.unitCost!.isFinite || line.unitCost! < 0)) errors.add(_v('negative_cost'));
    final lotNo = line.lotNo?.trim() ?? '';
    if (lotNo.isNotEmpty && line.serials.isNotEmpty) errors.add(_v('lot_and_serial'));
    if (direction == 'IN' &&
        ((line.lotExpiresOn ?? '').isNotEmpty || (line.lotManufacturedOn ?? '').isNotEmpty) &&
        lotNo.isEmpty) {
      errors.add(_v('expiry_needs_lot'));
    }
    if ((line.lotExpiresOn ?? '').isNotEmpty &&
        (line.lotManufacturedOn ?? '').isNotEmpty &&
        line.lotManufacturedOn!.compareTo(line.lotExpiresOn!) > 0) {
      errors.add(_v('mfg_after_expiry'));
    }
    if (material != null && material.isSerialized && qtyOk) {
      if (quantity != quantity.truncateToDouble()) errors.add(_v('serial_integer'));
      final picked = line.serials.length;
      final mustHave = forPosting && requiresSerials(draft.docType);
      if (picked > 0 && picked != quantity) {
        errors.add(_v('serial_count', {'picked': picked, 'qty': _qty(quantity)}));
      } else if (picked == 0 && mustHave) {
        errors.add(_v('serial_missing', {'qty': _qty(quantity)}));
      }
    } else if (material != null && !material.isSerialized && line.serials.isNotEmpty) {
      errors.add(_v('not_serialized'));
    }
    for (final serial in line.serials) {
      final key = '$code::${serial.toUpperCase()}';
      final owner = serialOwner[key];
      if (owner != null && owner != lineNo) {
        errors.add(_v('serial_duplicate', {'serial': serial, 'line': owner}));
      } else {
        serialOwner[key] = lineNo;
      }
    }
    if (errors.isNotEmpty) {
      lines[line.key] = errors.map((m) => _v('line_prefix', {'n': lineNo, 'message': m})).toList();
    }
  }
  return DraftValidation(header, lines);
}

// ---------------------------------------------------------------- Lô theo FEFO

class LotOption {
  final String lotNo;
  final String? expiresOn;
  final String qualityStatus;
  final double available;
  final String? blockedReason;
  const LotOption({
    required this.lotNo,
    this.expiresOn,
    required this.qualityStatus,
    required this.available,
    this.blockedReason,
  });
}

class LotAllocation {
  final String lotNo;
  final String? expiresOn;
  final double quantity;
  const LotAllocation(this.lotNo, this.expiresOn, this.quantity);
}

int _compareFefo(String? le, String ln, String? re, String rn) {
  final byExpiry = (le ?? '9999-12-31').compareTo(re ?? '9999-12-31');
  return byExpiry != 0 ? byExpiry : ln.compareTo(rn);
}

List<LotOption> lotOptionsForWarehouse(List<LotRow> lots, String warehouseCode, String today) {
  final options = lots
      .where((lot) => lot.balances.any((b) => b.warehouseCode == warehouseCode && b.quantity > 0))
      .map((lot) {
    final balance = lot.balances.where((b) => b.warehouseCode == warehouseCode).firstOrNull;
    final available = balance?.available ?? 0;
    String? blocked;
    if (lot.expiresOn != null && lot.expiresOn!.compareTo(today) < 0) {
      blocked = 'inventory.documents.lot.blocked_expired'.tr();
    } else if (lot.qualityStatus != 'PASSED') {
      blocked = 'inventory.documents.lot.blocked_quality'.tr();
    } else if (available <= 0) {
      blocked = 'inventory.documents.lot.blocked_empty'.tr();
    }
    return LotOption(
      lotNo: lot.lotNo,
      expiresOn: lot.expiresOn,
      qualityStatus: lot.qualityStatus,
      available: available,
      blockedReason: blocked,
    );
  }).toList();
  options.sort((a, b) => _compareFefo(a.expiresOn, a.lotNo, b.expiresOn, b.lotNo));
  return options;
}

({List<LotAllocation> allocations, double allocated, double shortage}) allocateFefo(
    List<LotOption> options, double quantity) {
  var remaining = quantity;
  final allocations = <LotAllocation>[];
  final sorted = [...options]..sort((a, b) => _compareFefo(a.expiresOn, a.lotNo, b.expiresOn, b.lotNo));
  for (final option in sorted) {
    if (remaining <= 0) break;
    if (option.blockedReason != null || option.available <= 0) continue;
    final take = option.available < remaining ? option.available : remaining;
    allocations.add(LotAllocation(option.lotNo, option.expiresOn, take));
    remaining -= take;
  }
  final shortage = remaining > 0 ? remaining : 0.0;
  return (allocations: allocations, allocated: quantity - shortage, shortage: shortage);
}

/// Một dòng xuất lấy từ nhiều lô thành nhiều dòng, mỗi dòng một lô; không phân bổ thì bỏ lô.
List<DraftLine> splitLineByLots(DraftLine line, List<LotAllocation> allocations) {
  final used = allocations.where((a) => a.quantity > 0).toList();
  if (used.isEmpty) return [line.copyWith(lotNo: null, lotExpiresOn: null)];
  return [
    for (var i = 0; i < used.length; i++)
      line.copyWith(
        key: i == 0 ? line.key : newLineKey(),
        quantity: used[i].quantity,
        lotNo: used[i].lotNo,
        lotExpiresOn: used[i].expiresOn,
        serials: const [],
      ),
  ];
}

// ---------------------------------------------------------------- Serial

List<String> parseSerialInput(String text) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in text.split(RegExp(r'[\s,;]+'))) {
    final serial = raw.trim();
    if (serial.isEmpty) continue;
    if (!seen.add(serial.toUpperCase())) continue;
    result.add(serial);
  }
  return result;
}

({List<String> serials, List<({String serial, String reason})> rejected}) addScannedSerials(
  List<String> current,
  List<String> scanned, {
  required int limit,
  List<String>? allowed,
}) {
  final serials = [...current];
  final taken = current.map((s) => s.toUpperCase()).toSet();
  final allowedMap = allowed == null ? null : {for (final s in allowed) s.toUpperCase(): s};
  final rejected = <({String serial, String reason})>[];
  for (final raw in scanned) {
    final key = raw.toUpperCase();
    if (taken.contains(key)) {
      rejected.add((serial: raw, reason: 'inventory.documents.serial.reject_taken'.tr()));
      continue;
    }
    if (allowedMap != null && !allowedMap.containsKey(key)) {
      rejected.add((serial: raw, reason: 'inventory.documents.serial.reject_unknown'.tr()));
      continue;
    }
    if (serials.length >= limit) {
      rejected.add((serial: raw, reason: 'inventory.documents.serial.reject_limit'.tr()));
      continue;
    }
    serials.add(allowedMap?[key] ?? raw);
    taken.add(key);
  }
  return (serials: serials, rejected: rejected);
}

// ---------------------------------------------------------------- Yêu cầu xuất từ đơn bán

class IssueLineProgress {
  final StockDocLine line;
  final String? reservationCode;
  final double? outstanding;
  final double? reserved;
  final double? issued;
  final int missingSerials;
  const IssueLineProgress({
    required this.line,
    this.reservationCode,
    this.outstanding,
    this.reserved,
    this.issued,
    required this.missingSerials,
  });
}

List<IssueLineProgress> issueLineProgress(
  String warehouseId,
  List<StockDocLine> lines,
  List<ReservationRow> reservations,
  Set<String> serializedCodes,
) {
  final byId = {for (final r in reservations) r.id: r};
  return lines.map((line) {
    final reservation = line.reservationId == null ? null : byId[line.reservationId];
    final items = reservation?.items ?? const <ReservationItemRow>[];
    final item = items.where((c) => c.materialId == line.materialId && c.warehouseId == warehouseId).firstOrNull ??
        items.where((c) => c.materialId == line.materialId).firstOrNull;
    final missing = serializedCodes.contains(line.materialCode)
        ? (line.quantity.truncate() - line.serials.length).clamp(0, 1 << 30)
        : 0;
    return IssueLineProgress(
      line: line,
      reservationCode: reservation?.reservationCode,
      reserved: item?.quantityReserved,
      issued: item?.quantityIssued,
      outstanding: item == null ? null : item.quantityReserved - item.quantityIssued,
      missingSerials: missing,
    );
  }).toList();
}

List<String> issueReadiness(List<IssueLineProgress> progress) {
  final problems = <String>[];
  final totals = <String, ({double quantity, IssueLineProgress item})>{};
  for (final item in progress) {
    if (item.missingSerials > 0) {
      problems.add('inventory.documents.issue.missing_serials'.tr(args: {
        'line': item.line.lineNo,
        'code': item.line.materialCode,
        'n': item.missingSerials,
      }));
    }
    if (item.outstanding == null || (item.line.reservationId ?? '').isEmpty) continue;
    final key = '${item.line.reservationId}::${item.line.materialId}';
    final total = totals[key];
    totals[key] = (quantity: (total?.quantity ?? 0) + item.line.quantity, item: total?.item ?? item);
  }
  for (final entry in totals.values) {
    final item = entry.item;
    if (item.outstanding != null && entry.quantity > item.outstanding!) {
      problems.add('inventory.documents.issue.over_reserved'.tr(args: {
        'code': item.line.materialCode,
        'qty': _qty(entry.quantity),
        'reservation': item.reservationCode ?? '',
        'left': _qty(item.outstanding!),
      }));
    }
  }
  return problems;
}
