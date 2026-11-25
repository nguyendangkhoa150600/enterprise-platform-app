// Phiếu nhập/xuất/chuyển kho (web movement-form.tsx `MovementInput`, `MovementLineItem`).

enum MovementKind { receipt, issue, transfer }

MovementKind movementKindFrom(String? raw) {
  switch (raw) {
    case 'issue':
      return MovementKind.issue;
    case 'transfer':
      return MovementKind.transfer;
    default:
      return MovementKind.receipt;
  }
}

/// Đối tượng nhận khi xuất kho.
enum IssueTargetType { department, asset, customer, project }

class LotAllocation {
  final String lotId;
  final String lotNumber;
  final double quantity;
  const LotAllocation({required this.lotId, required this.lotNumber, required this.quantity});
}

class ReceiptLot {
  final String lotNumber;
  final String? manufactureDate;
  final String? expiryDate;
  final String? supplier;
  final String? coCqNumber;
  const ReceiptLot({
    required this.lotNumber,
    this.manufactureDate,
    this.expiryDate,
    this.supplier,
    this.coCqNumber,
  });

  Map<String, dynamic> toJson() => {
        'lotNo': lotNumber,
        if (manufactureDate != null) 'manufacturedOn': manufactureDate,
        if (expiryDate != null) 'expiresOn': expiryDate,
        if (supplier != null) 'supplier': supplier,
        if (coCqNumber != null) 'certificateNo': coCqNumber,
      };
}

class NewMaterialDraft {
  final String code;
  final String name;
  final String? type;
  final String unit;
  final double minStock;
  final double? maxStock;
  final String? barcode;
  final String? manufacturer;
  const NewMaterialDraft({
    required this.code,
    required this.name,
    this.type,
    required this.unit,
    this.minStock = 0,
    this.maxStock,
    this.barcode,
    this.manufacturer,
  });
}

/// Một dòng vật tư của phiếu. Mutable để form chỉnh trực tiếp.
class MovementLine {
  final String id;
  final String materialCode;
  final String materialName;
  final String? materialType;
  final String unit;
  double quantity;
  double? unitCost;
  List<String> serialNumbers;
  List<LotAllocation> lotAllocations;
  ReceiptLot? receiptLot;
  String lineNote;
  final NewMaterialDraft? newMaterial;

  /// Các trường dưới đây chỉ có ở dòng nạp từ Excel (web `MovementLineItem`): kho riêng của dòng
  /// (nạp đa kho), mã vạch, hãng, vị trí, VAT và định mức đọc từ tệp.
  final String? warehouseCode;
  final String? barcode;
  final String? manufacturer;
  final String? locationId;
  final double? vatRate;
  final double? minStock;
  final double? maxStock;

  MovementLine({
    required this.id,
    required this.materialCode,
    required this.materialName,
    this.materialType,
    required this.unit,
    this.quantity = 1,
    this.unitCost,
    List<String>? serialNumbers,
    List<LotAllocation>? lotAllocations,
    this.receiptLot,
    this.lineNote = '',
    this.newMaterial,
    this.warehouseCode,
    this.barcode,
    this.manufacturer,
    this.locationId,
    this.vatRate,
    this.minStock,
    this.maxStock,
  })  : serialNumbers = serialNumbers ?? [],
        lotAllocations = lotAllocations ?? [];
}

class MovementCounterparty {
  final String type;
  final String name;
  final String? address;
  final String? documentNumber;
  const MovementCounterparty({required this.type, required this.name, this.address, this.documentNumber});
  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        if (address != null) 'address': address,
        if (documentNumber != null) 'documentNumber': documentNumber,
      };
}

class MovementInput {
  final MovementKind kind;
  final String warehouseCode;
  final String? toWarehouseCode;
  final String note;
  final String? supplierName;
  final String? supplierAddress;
  final String? invoiceNumber;
  final String? procedureDefinitionId;
  final String? targetAssetCode;
  final MovementCounterparty? counterparty;
  final List<MovementLine> items;

  const MovementInput({
    required this.kind,
    required this.warehouseCode,
    this.toWarehouseCode,
    required this.note,
    this.supplierName,
    this.supplierAddress,
    this.invoiceNumber,
    this.procedureDefinitionId,
    this.targetAssetCode,
    this.counterparty,
    required this.items,
  });
}

/// Kết quả ghi phiếu: các bút toán đã ghi sổ và các chứng từ Chờ duyệt.
class MovementOutcome {
  final List<String> transactionCodes;
  final List<String> pendingCodes;
  final int serialsAdded;
  final String? workOrderCode;
  final String? workOrderError;
  const MovementOutcome({
    this.transactionCodes = const [],
    this.pendingCodes = const [],
    this.serialsAdded = 0,
    this.workOrderCode,
    this.workOrderError,
  });
}
