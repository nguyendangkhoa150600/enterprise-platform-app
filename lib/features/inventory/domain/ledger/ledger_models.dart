// Mô hình dữ liệu của tab "Lịch sử xuất nhập" và phiếu nhập/xuất/chuyển kho
// (web: inventory-api.ts `InventoryWorkspace`, `InventoryLedgerRow`, `ProcedureRequisition`;
// contracts-inventory `InventoryTransaction`, `Lot`, `SerialTracking`).

String _str(dynamic v) => v == null ? '' : v.toString();
String? _strOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

List<Map<String, dynamic>> asMapList(dynamic raw, [String? key]) {
  dynamic list = raw;
  if (list is Map && key != null) list = list[key];
  if (list is! List) return const [];
  return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// Một dòng sổ cái (`InventoryTransaction`).
class LedgerRow {
  final String id;
  final String transactionCode;
  final String warehouseId;
  final String? locationId;
  final String materialId;
  final String? serialNumber;
  final String type;
  final double quantity;
  final double unitCost;
  final String? referenceType;
  final String? referenceId;
  final String? workflowStatus;
  final String? note;
  final String? counterpartyType;
  final String? counterpartyName;
  final String? counterpartyAddress;
  final String? counterpartyWarehouseId;
  final String? documentNumber;
  final String createdBy;
  final String createdAt;

  const LedgerRow({
    required this.id,
    required this.transactionCode,
    required this.warehouseId,
    this.locationId,
    required this.materialId,
    this.serialNumber,
    required this.type,
    required this.quantity,
    this.unitCost = 0,
    this.referenceType,
    this.referenceId,
    this.workflowStatus,
    this.note,
    this.counterpartyType,
    this.counterpartyName,
    this.counterpartyAddress,
    this.counterpartyWarehouseId,
    this.documentNumber,
    this.createdBy = '',
    this.createdAt = '',
  });

  factory LedgerRow.fromJson(Map<String, dynamic> j) => LedgerRow(
        id: _str(j['id']),
        transactionCode: _str(j['transactionCode']),
        warehouseId: _str(j['warehouseId']),
        locationId: _strOrNull(j['locationId']),
        materialId: _str(j['materialId']),
        serialNumber: _strOrNull(j['serialNumber']),
        type: _str(j['type']),
        quantity: _num(j['quantity']),
        unitCost: _num(j['unitCost']),
        referenceType: _strOrNull(j['referenceType']),
        referenceId: _strOrNull(j['referenceId']),
        workflowStatus: _strOrNull(j['workflowStatus']),
        note: _strOrNull(j['note']),
        counterpartyType: _strOrNull(j['counterpartyType']),
        counterpartyName: _strOrNull(j['counterpartyName']),
        counterpartyAddress: _strOrNull(j['counterpartyAddress']),
        counterpartyWarehouseId: _strOrNull(j['counterpartyWarehouseId']),
        documentNumber: _strOrNull(j['documentNumber']),
        createdBy: _str(j['createdBy']),
        createdAt: _str(j['createdAt']),
      );

  /// Như web: số dương hoặc loại nhập (IMPORT/RECEIPT/TRANSFER_IN/RETURN).
  bool get isReceiptRow =>
      quantity > 0 || const ['IMPORT', 'RECEIPT', 'TRANSFER_IN', 'RETURN'].contains(type);
}

class LedgerMaterial {
  final String id;
  final String code;
  final String name;
  final String unit;
  final String? type;
  final String? category;
  final String? tradeCategory;
  final bool isActive;
  final bool isSerialized;

  const LedgerMaterial({
    required this.id,
    required this.code,
    required this.name,
    this.unit = '',
    this.type,
    this.category,
    this.tradeCategory,
    this.isActive = true,
    this.isSerialized = false,
  });

  factory LedgerMaterial.fromJson(Map<String, dynamic> j) => LedgerMaterial(
        id: _str(j['id']),
        code: _str(j['code']),
        name: _str(j['name']),
        unit: _str(j['unit']),
        type: _strOrNull(j['type']),
        category: _strOrNull(j['category']),
        tradeCategory: _strOrNull(j['tradeCategory']),
        isActive: j['isActive'] != false,
        isSerialized: j['isSerialized'] == true,
      );
}

class LedgerWarehouse {
  final String id;
  final String code;
  final String name;
  const LedgerWarehouse({required this.id, required this.code, required this.name});
  factory LedgerWarehouse.fromJson(Map<String, dynamic> j) =>
      LedgerWarehouse(id: _str(j['id']), code: _str(j['code']), name: _str(j['name']));
}

class LedgerAsset {
  final String code;
  final String name;
  const LedgerAsset({required this.code, required this.name});
  factory LedgerAsset.fromJson(Map<String, dynamic> j) =>
      LedgerAsset(code: _str(j['code']), name: _str(j['name']));
}

/// Một dòng tồn (`MaterialInventory` + mã kho/mã vật tư ghép sẵn).
class LedgerStock {
  final String warehouseId;
  final String warehouseCode;
  final String materialId;
  final String? materialCode;
  final double quantity;
  final double quantityReserved;
  final double available;

  const LedgerStock({
    required this.warehouseId,
    required this.warehouseCode,
    required this.materialId,
    this.materialCode,
    required this.quantity,
    required this.quantityReserved,
    required this.available,
  });

  factory LedgerStock.fromJson(Map<String, dynamic> j, {required String warehouseCode, String? materialCode}) =>
      LedgerStock(
        warehouseId: _str(j['warehouseId']),
        warehouseCode: warehouseCode,
        materialId: _str(j['materialId']),
        materialCode: materialCode,
        quantity: _num(j['quantity']),
        quantityReserved: _num(j['quantityReserved']),
        available: _num(j['available']),
      );
}

/// Dữ liệu chung của màn (web `InventoryWorkspace`).
class LedgerWorkspace {
  final List<LedgerWarehouse> warehouses;
  final List<LedgerMaterial> materials;
  final List<LedgerAsset> assets;
  final List<LedgerStock> stock;

  const LedgerWorkspace({
    this.warehouses = const [],
    this.materials = const [],
    this.assets = const [],
    this.stock = const [],
  });

  static const empty = LedgerWorkspace();

  LedgerMaterial? materialById(String id) {
    for (final m in materials) {
      if (m.id == id) return m;
    }
    return null;
  }

  LedgerMaterial? materialByCode(String code) {
    for (final m in materials) {
      if (m.code == code) return m;
    }
    return null;
  }

  LedgerWarehouse? warehouseById(String id) {
    for (final w in warehouses) {
      if (w.id == id) return w;
    }
    return null;
  }

  LedgerWarehouse? warehouseByCode(String code) {
    for (final w in warehouses) {
      if (w.code == code) return w;
    }
    return null;
  }
}

class RequisitionLine {
  final String materialCode;
  final double quantity;
  final String? materialName;
  final String? unit;
  const RequisitionLine({required this.materialCode, required this.quantity, this.materialName, this.unit});
  factory RequisitionLine.fromJson(Map<String, dynamic> j) => RequisitionLine(
        materialCode: _str(j['materialCode']),
        quantity: _num(j['quantity']),
        materialName: _strOrNull(j['materialName']),
        unit: _strOrNull(j['unit']),
      );
}

/// Yêu cầu cấp vật tư từ Quy trình (web `ProcedureRequisition`).
class ProcedureRequisition {
  final String id;
  final String code;
  final String title;
  final String status;
  final String startedAt;
  final String? assetCode;
  final List<RequisitionLine> lines;
  final String csvFileName;
  final String? fulfilmentStatus;

  const ProcedureRequisition({
    required this.id,
    required this.code,
    required this.title,
    required this.status,
    required this.startedAt,
    this.assetCode,
    this.lines = const [],
    required this.csvFileName,
    this.fulfilmentStatus,
  });

  factory ProcedureRequisition.fromListItem(Map<String, dynamic> j) {
    final code = _str(j['orderCode']);
    final fulfilment = j['fulfilment'];
    return ProcedureRequisition(
      id: _strOrNull(j['instanceId']) ?? code,
      code: code,
      title: _str(j['title']),
      status: _str(j['procedureStatus']),
      startedAt: _str(j['createdAt']),
      assetCode: _strOrNull(j['assetCode']),
      lines: asMapList(j['lines']).map(RequisitionLine.fromJson).toList(),
      csvFileName: 'bang-ke-vat-tu-$code.csv',
      fulfilmentStatus: fulfilment is Map ? _strOrNull(fulfilment['status']) : null,
    );
  }

  /// Hồ sơ Quy trình đã duyệt xong thì mới cấp được (web `isRequisitionApproved`).
  bool get isApproved => status == 'completed' && id != code;
}

class ProcedureOption {
  final String id;
  final String code;
  final String name;
  const ProcedureOption({required this.id, required this.code, required this.name});
}

class ProcedureWorkOrder {
  final String id;
  final String code;
  final String title;
  const ProcedureWorkOrder({required this.id, required this.code, required this.title});
}

/// Phiếu giữ chỗ (chỉ các trường form xuất cần để cảnh báo).
class LedgerReservation {
  final String reservationCode;
  final String status;
  final String? referenceId;
  final List<({String materialId, double reserved, double issued})> items;
  const LedgerReservation({
    required this.reservationCode,
    required this.status,
    this.referenceId,
    this.items = const [],
  });
  factory LedgerReservation.fromJson(Map<String, dynamic> j) => LedgerReservation(
        reservationCode: _str(j['reservationCode']),
        status: _str(j['status']),
        referenceId: _strOrNull(j['referenceId']),
        items: asMapList(j['items'])
            .map((i) => (
                  materialId: _str(i['materialId']),
                  reserved: _num(i['quantityReserved']),
                  issued: _num(i['quantityIssued']),
                ))
            .toList(),
      );
}

class LotBalance {
  final String warehouseCode;
  final double quantity;
  final double available;
  const LotBalance({required this.warehouseCode, required this.quantity, required this.available});
}

class LedgerLot {
  final String id;
  final String lotNo;
  final String? expiresOn;
  final String qualityStatus;
  final List<LotBalance> balances;
  const LedgerLot({
    required this.id,
    required this.lotNo,
    this.expiresOn,
    required this.qualityStatus,
    this.balances = const [],
  });
  factory LedgerLot.fromJson(Map<String, dynamic> j) => LedgerLot(
        id: _str(j['id']),
        lotNo: _str(j['lotNo']),
        expiresOn: _strOrNull(j['expiresOn']),
        qualityStatus: _strOrNull(j['qualityStatus']) ?? 'PASSED',
        balances: asMapList(j['balances'])
            .map((b) => LotBalance(
                  warehouseCode: _str(b['warehouseCode']),
                  quantity: _num(b['quantity']),
                  available: _num(b['available']),
                ))
            .toList(),
      );
}

class LedgerSerial {
  final String serialNumber;
  final String? stockState;
  final String? currentWarehouseId;
  final String? qualityStatus;
  const LedgerSerial({required this.serialNumber, this.stockState, this.currentWarehouseId, this.qualityStatus});
  factory LedgerSerial.fromJson(Map<String, dynamic> j) => LedgerSerial(
        serialNumber: _str(j['serialNumber']),
        stockState: _strOrNull(j['stockState']),
        currentWarehouseId: _strOrNull(j['currentWarehouseId']),
        qualityStatus: _strOrNull(j['qualityStatus']),
      );
}

/// Kết quả `POST /requisitions/:mã/fulfil`.
class FulfilResult {
  final List<String> documentCodes;
  final bool replayed;
  const FulfilResult({required this.documentCodes, required this.replayed});
  factory FulfilResult.fromJson(dynamic raw) {
    final j = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return FulfilResult(
      documentCodes: asMapList(j['documents']).map((d) => _str(d['code'])).toList(),
      replayed: j['replayed'] == true,
    );
  }
}
