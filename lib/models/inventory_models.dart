import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';

class WarehouseItem {
  final String id;
  final String code;
  final String name;
  final String type;
  final String? location;
  final bool? _isActive;
  bool get isActive => _isActive ?? true;
  final double totalItems;
  final int materialCount;

  WarehouseItem({
    required this.id,
    required this.code,
    required this.name,
    this.type = 'PHYSICAL',
    this.location,
    bool isActive = true,
    this.totalItems = 0.0,
    this.materialCount = 0,
  }) : _isActive = isActive;

  WarehouseItem copyWith({
    double? totalItems,
    int? materialCount,
  }) {
    return WarehouseItem(
      id: id,
      code: code,
      name: name,
      type: type,
      location: location,
      isActive: isActive,
      totalItems: totalItems ?? this.totalItems,
      materialCount: materialCount ?? this.materialCount,
    );
  }

  factory WarehouseItem.fromJson(Map<String, dynamic> json) {
    return WarehouseItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Kho lưu trữ',
      type: json['type']?.toString() ?? 'PHYSICAL',
      location: json['location']?.toString(),
      isActive: json['isActive'] == null ? true : (json['isActive'] == true),
      totalItems: (json['totalItems'] as num?)?.toDouble() ?? 0.0,
      materialCount: (json['materialCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class StockInventoryRow {
  final String id;
  final String warehouseId;
  final String? warehouseCode;
  final String materialId;
  final String? materialCode;
  final double quantity;
  final double quantityReserved;
  final double quantityBlocked;
  final double available;

  StockInventoryRow({
    required this.id,
    required this.warehouseId,
    this.warehouseCode,
    required this.materialId,
    this.materialCode,
    required this.quantity,
    this.quantityReserved = 0.0,
    this.quantityBlocked = 0.0,
    required this.available,
  });

  factory StockInventoryRow.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toDouble() ?? 0.0;
    final rsv = (json['quantityReserved'] as num?)?.toDouble() ?? 0.0;
    final blk = (json['quantityBlocked'] as num?)?.toDouble() ?? 0.0;
    final avail = json['available'] != null ? (json['available'] as num).toDouble() : (qty - rsv - blk);
    return StockInventoryRow(
      id: json['id']?.toString() ?? '',
      warehouseId: json['warehouseId']?.toString() ?? '',
      warehouseCode: json['warehouseCode']?.toString(),
      materialId: json['materialId']?.toString() ?? '',
      materialCode: json['materialCode']?.toString(),
      quantity: qty,
      quantityReserved: rsv,
      quantityBlocked: blk,
      available: avail,
    );
  }
}

class AssetItem {
  final String id;
  final String code;
  final String? internalCode;
  final String name;
  final String? parentId;
  final String? type;
  final String? status;
  final String? criticality;
  final String? serialNumber;
  final Map<String, dynamic>? specs;
  final List<dynamic>? taskTemplate;
  final String? qrCode;
  final double? purchasePrice;
  final int? manufactureYear;
  final String? manufacturer;
  final String? supplier;
  final DateTime? createdAt;

  AssetItem({
    required this.id,
    required this.code,
    this.internalCode,
    required this.name,
    this.parentId,
    this.type,
    this.status,
    this.criticality,
    this.serialNumber,
    this.specs,
    this.taskTemplate,
    this.qrCode,
    this.purchasePrice,
    this.manufactureYear,
    this.manufacturer,
    this.supplier,
    this.createdAt,
  });

  String get typeLabel => type == 'LOCATION' ? 'Vị trí' : 'Thiết bị';

  String get statusLabel {
    switch (status) {
      case 'OPERATING':
        return 'Đang vận hành';
      case 'MAINTENANCE':
        return 'Bảo trì';
      case 'DISPOSED':
        return 'Thanh lý';
      case 'IDLE':
        return 'Chờ vận hành';
      default:
        return status ?? 'Đang vận hành';
    }
  }

  String get criticalityLabel {
    switch (criticality) {
      case 'CRITICAL':
        return 'Cấp Nghiêm trọng';
      case 'HIGH':
        return 'Cấp Cao';
      case 'MEDIUM':
        return 'Cấp Trung bình';
      case 'LOW':
        return 'Cấp Thấp';
      default:
        return 'Cấp Trung bình';
    }
  }

  Map<String, String> get resolvedSpecs {
    if (specs != null && specs!.isNotEmpty) {
      return specs!.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    }
    return {};
  }

  factory AssetItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedSpecs;
    if (json['specs'] is Map) {
      parsedSpecs = Map<String, dynamic>.from(json['specs'] as Map);
    }

    DateTime? parsedCreatedAt;
    final cRaw = json['createdAt'] ?? json['created_at'];
    if (cRaw != null) {
      parsedCreatedAt = DateTime.tryParse(cRaw.toString());
    }

    return AssetItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      internalCode: json['internalCode']?.toString() ?? json['internal_code']?.toString(),
      name: json['name']?.toString() ?? '',
      parentId: json['parentId']?.toString() ?? json['parent_id']?.toString(),
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      criticality: json['criticality']?.toString(),
      serialNumber: json['serialNumber']?.toString() ?? json['serial_number']?.toString(),
      specs: parsedSpecs,
      taskTemplate: json['taskTemplate'] is List ? json['taskTemplate'] as List : null,
      qrCode: json['qrCode']?.toString() ?? json['qr_code']?.toString(),
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? (json['purchase_price'] as num?)?.toDouble(),
      manufactureYear: (json['manufactureYear'] as num?)?.toInt() ?? (json['manufacture_year'] as num?)?.toInt(),
      manufacturer: json['manufacturer']?.toString(),
      supplier: json['supplier']?.toString(),
      createdAt: parsedCreatedAt,
    );
  }
}

class MaterialItem {
  final String id;
  final String code;
  final String name;
  final String unit;
  final String category;
  final double onHand;
  final double minStock;
  final double maxStock;
  final String warehouseName;
  final String? status;
  final double? purchasePrice;
  final double? salePrice;
  final String? barcode;
  final String? tradeCategory;
  final String? tradeMode;
  final String kind;
  final String? currency;
  final bool? _isActive;
  bool get isActive => _isActive ?? true;
  final bool? _isSerialized;
  bool get isSerialized => _isSerialized ?? false;
  final String? type;
  final String? usageState;
  final String? description;
  final DateTime? createdAt;
  final String? createdBy;

  MaterialItem({
    this.id = '',
    required this.code,
    required this.name,
    required this.unit,
    required this.category,
    required this.onHand,
    required this.minStock,
    this.maxStock = 9999.0,
    required this.warehouseName,
    this.status,
    this.purchasePrice,
    this.salePrice,
    this.barcode,
    this.tradeCategory,
    this.tradeMode,
    this.kind = 'STOCK',
    this.currency,
    bool isActive = true,
    bool isSerialized = false,
    this.type,
    this.usageState,
    this.description,
    this.createdAt,
    this.createdBy,
  })  : _isActive = isActive,
        _isSerialized = isSerialized;

  bool get isLowStock => onHand <= minStock;
  bool get isService => kind.toUpperCase() == 'SERVICE';
  String get groupLabel => isService ? 'Dịch vụ' : 'Hàng hóa';
  String get statusLabel => isActive ? 'Đang dùng' : 'Ngừng dùng';

  MaterialItem copyWith({
    String? name,
    String? unit,
    String? category,
    String? description,
    double? onHand,
    double? minStock,
    double? maxStock,
    String? warehouseName,
    String? status,
    bool? isActive,
    bool? isSerialized,
    String? type,
    String? usageState,
    DateTime? createdAt,
    String? createdBy,
    double? purchasePrice,
    double? salePrice,
    String? barcode,
    String? tradeCategory,
    String? tradeMode,
    String? kind,
    String? currency,
  }) {
    return MaterialItem(
      id: id,
      code: code,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      onHand: onHand ?? this.onHand,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      warehouseName: warehouseName ?? this.warehouseName,
      status: status ?? this.status,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      barcode: barcode ?? this.barcode,
      tradeCategory: tradeCategory ?? this.tradeCategory,
      tradeMode: tradeMode ?? this.tradeMode,
      kind: kind ?? this.kind,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      isSerialized: isSerialized ?? this.isSerialized,
      type: type ?? this.type,
      usageState: usageState ?? this.usageState,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    final onHandVal = (json['onHand'] as num?)?.toDouble() ??
        (json['available'] as num?)?.toDouble() ??
        (json['quantity'] as num?)?.toDouble() ??
        0.0;
    final minVal = (json['minStock'] as num?)?.toDouble() ?? 10.0;
    final maxVal = (json['maxStock'] as num?)?.toDouble() ?? 9999.0;

    DateTime? parsedCreatedAt;
    final cRaw = json['createdAt'] ?? json['created_at'];
    if (cRaw != null) {
      parsedCreatedAt = DateTime.tryParse(cRaw.toString());
    }

    return MaterialItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'models.inventory.default_unit'.tr(),
      category: json['category']?.toString() ?? 'models.inventory.default_category'.tr(),
      onHand: onHandVal,
      minStock: minVal,
      maxStock: maxVal,
      warehouseName: json['warehouseName']?.toString() ?? 'models.inventory.default_warehouse'.tr(),
      status: json['status']?.toString(),
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? (json['unitPrice'] as num?)?.toDouble(),
      salePrice: (json['salePrice'] as num?)?.toDouble() ?? (json['sale_price'] as num?)?.toDouble(),
      barcode: json['barcode']?.toString(),
      tradeCategory: json['tradeCategory']?.toString() ?? json['trade_category']?.toString(),
      tradeMode: json['tradeMode']?.toString() ?? json['trade_mode']?.toString(),
      kind: json['kind']?.toString() ?? 'STOCK',
      currency: json['currency']?.toString() ?? 'VND',
      isActive: json['isActive'] == null ? true : (json['isActive'] == true),
      isSerialized: json['isSerialized'] == true,
      type: json['type']?.toString(),
      usageState: json['usageState']?.toString() ?? json['usage_state']?.toString(),
      description: json['description']?.toString(),
      createdAt: parsedCreatedAt,
      createdBy: json['createdBy']?.toString() ?? json['created_by']?.toString(),
    );
  }
}

class StockTransaction {
  final String id;
  final String code;
  final String type; // 'RECEIPT' | 'ISSUE' | 'TRANSFER' | 'IMPORT' | 'EXPORT'
  final String materialId;
  final String materialCode;
  final String materialName;
  final double quantity;
  final String unit;
  final String date;
  final String createdBy;
  final String? note;
  final String? warehouseCode;
  final String? warehouseName;
  final String? referenceCode;

  StockTransaction({
    required this.id,
    required this.code,
    required this.type,
    this.materialId = '',
    required this.materialCode,
    required this.materialName,
    required this.quantity,
    this.unit = '',
    required this.date,
    required this.createdBy,
    this.note,
    this.warehouseCode,
    this.warehouseName,
    this.referenceCode,
  });

  String get description => note ?? '';
  String get typeDisplay => typeLabel;

  bool get isReceipt =>
      quantity > 0 ||
      type == 'RECEIPT' ||
      type == 'IMPORT' ||
      type == 'TRANSFER_IN';

  String get typeLabel {
    switch (type.toUpperCase()) {
      case 'RECEIPT':
      case 'IMPORT':
      case 'TRANSFER_IN':
        return 'Nhập kho';
      case 'ISSUE':
      case 'EXPORT':
      case 'TRANSFER_OUT':
        return 'Xuất kho';
      case 'TRANSFER':
        return 'Điều chuyển';
      case 'BORROW':
        return 'Mượn';
      case 'RETURN':
        return 'Trả';
      case 'ADJUST':
        return 'Điều chỉnh';
      default:
        return type;
    }
  }

  factory StockTransaction.fromJson(Map<String, dynamic> json) {
    final rawQty = (json['quantity'] as num?)?.toDouble() ?? 0.0;
    final rawType = json['type']?.toString() ?? 'RECEIPT';
    final rawCode = json['transactionCode']?.toString() ?? json['code']?.toString() ?? 'TRX-001';
    final rawDate = json['createdAt']?.toString() ?? json['date']?.toString() ?? '';

    String formattedDate = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        final parsed = DateTime.parse(rawDate).toLocal();
        final day = parsed.day.toString().padLeft(2, '0');
        final month = parsed.month.toString().padLeft(2, '0');
        final year = parsed.year;
        final hour = parsed.hour.toString().padLeft(2, '0');
        final minute = parsed.minute.toString().padLeft(2, '0');
        formattedDate = '$day/$month/$year $hour:$minute';
      } catch (_) {
        formattedDate = rawDate;
      }
    }

    return StockTransaction(
      id: json['id']?.toString() ?? '',
      code: rawCode,
      type: rawType,
      materialId: json['materialId']?.toString() ?? '',
      materialCode: json['materialCode']?.toString() ?? '',
      materialName: json['materialName']?.toString() ?? '',
      quantity: rawQty,
      unit: json['unit']?.toString() ?? '',
      date: formattedDate,
      createdBy: json['createdBy']?.toString() ?? 'models.inventory.default_keeper'.tr(),
      note: json['note']?.toString(),
      warehouseCode: json['warehouseCode']?.toString() ?? json['warehouse_code']?.toString() ?? json['warehouseId']?.toString(),
      warehouseName: json['warehouseName']?.toString() ?? json['warehouse_name']?.toString(),
      referenceCode: json['referenceCode']?.toString() ?? json['reference_code']?.toString() ?? json['documentCode']?.toString(),
    );
  }
}

class ItemWarehouseStock {
  final String warehouseCode;
  final String warehouseName;
  final double quantity;
  final double available;
  final double reserved;

  ItemWarehouseStock({
    required this.warehouseCode,
    required this.warehouseName,
    required this.quantity,
    required this.available,
    this.reserved = 0.0,
  });
}

class InventoryItem {
  final String code;
  final String name;
  final String kind; // 'STOCK' | 'ASSET'
  final String unit;
  final String? category;
  final String? type;
  final String? status;
  final String? usageState;
  final double available;
  final double onHand;
  final double inUse;
  final double reserved;
  final double blocked;
  final double totalOwned;
  final String? trackingType; // 'SERIAL' | 'LOT' | 'NONE'
  final bool? _isSerialized;
  bool get isSerialized => _isSerialized ?? false;
  final String? installedAtCode;
  final String? installedAtName;
  final String? rootCode;
  final String? rootName;
  final List<ItemWarehouseStock> warehouseStocks;
  final double? minStock;
  final double? maxStock;
  final DateTime? createdAt;

  InventoryItem({
    required this.code,
    required this.name,
    this.kind = 'STOCK',
    this.unit = '',
    this.category,
    this.type,
    this.status,
    this.usageState,
    required this.available,
    this.onHand = 0.0,
    this.inUse = 0.0,
    this.reserved = 0.0,
    this.blocked = 0.0,
    this.totalOwned = 0.0,
    this.trackingType,
    bool isSerialized = false,
    this.installedAtCode,
    this.installedAtName,
    this.rootCode,
    this.rootName,
    this.warehouseStocks = const [],
    this.minStock,
    this.maxStock,
    this.createdAt,
  }) : _isSerialized = isSerialized;

  bool get isInStock => (kind ?? 'STOCK') == 'STOCK';
  bool get isAsset => (kind ?? '') == 'ASSET';

  String get displayCategoryOrType {
    if (type != null && type!.trim().isNotEmpty) return type!;
    if (category != null && category!.trim().isNotEmpty) return category!;
    return '—';
  }

  String get displayTrackingBadge {
    if (trackingType == 'SERIAL') return 'Theo Sê-ri';
    if (trackingType == 'LOT') return 'Theo Lô hàng';
    if (status != null && status!.trim().isNotEmpty) return status!;
    return '—';
  }

  String get displayUsageLocation {
    if (isSerialized == true) return 'theo sê-ri';
    if (usageState != null && usageState!.trim().isNotEmpty) return usageState!;
    if (installedAtName != null && installedAtName!.trim().isNotEmpty) return installedAtName!;
    return '—';
  }

  InventoryItem copyWith({
    String? name,
    String? unit,
    String? category,
    String? type,
    String? status,
    String? usageState,
    double? onHand,
    double? inUse,
    double? available,
    double? reserved,
    double? blocked,
    double? totalOwned,
    String? trackingType,
    bool? isSerialized,
    List<ItemWarehouseStock>? warehouseStocks,
    double? minStock,
    double? maxStock,
    DateTime? createdAt,
  }) {
    return InventoryItem(
      code: code,
      name: name ?? this.name,
      kind: kind,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      type: type ?? this.type,
      status: status ?? this.status,
      usageState: usageState ?? this.usageState,
      available: available ?? this.available,
      onHand: onHand ?? this.onHand,
      inUse: inUse ?? this.inUse,
      reserved: reserved ?? this.reserved,
      blocked: blocked ?? this.blocked,
      totalOwned: totalOwned ?? this.totalOwned,
      trackingType: trackingType ?? this.trackingType,
      isSerialized: isSerialized ?? this.isSerialized,
      installedAtCode: installedAtCode,
      installedAtName: installedAtName,
      rootCode: rootCode,
      rootName: rootName,
      warehouseStocks: warehouseStocks ?? this.warehouseStocks,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    final cRaw = json['createdAt'] ?? json['created_at'];
    if (cRaw != null) {
      parsedCreatedAt = DateTime.tryParse(cRaw.toString());
    }

    return InventoryItem(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'STOCK',
      unit: json['unit']?.toString() ?? 'Cái',
      category: json['category']?.toString(),
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      usageState: json['usage_state']?.toString() ?? json['usageState']?.toString(),
      available: (json['available'] as num?)?.toDouble() ?? 0.0,
      onHand: (json['onHand'] as num?)?.toDouble() ?? (json['quantity'] as num?)?.toDouble() ?? 0.0,
      inUse: (json['inUse'] as num?)?.toDouble() ?? 0.0,
      reserved: (json['reserved'] as num?)?.toDouble() ?? (json['quantityReserved'] as num?)?.toDouble() ?? 0.0,
      blocked: (json['blocked'] as num?)?.toDouble() ?? (json['quantityBlocked'] as num?)?.toDouble() ?? 0.0,
      totalOwned: (json['totalOwned'] as num?)?.toDouble() ?? 0.0,
      trackingType: json['trackingType']?.toString(),
      isSerialized: json['isSerialized'] == true,
      installedAtCode: json['installed_at_code']?.toString() ?? json['installedAtCode']?.toString(),
      installedAtName: json['installed_at_name']?.toString() ?? json['installedAtName']?.toString(),
      rootCode: json['root_code']?.toString() ?? json['rootCode']?.toString(),
      rootName: json['root_name']?.toString() ?? json['rootName']?.toString(),
      minStock: (json['minStock'] as num?)?.toDouble() ?? (json['min_stock'] as num?)?.toDouble(),
      maxStock: (json['maxStock'] as num?)?.toDouble() ?? (json['max_stock'] as num?)?.toDouble(),
      createdAt: parsedCreatedAt,
    );
  }
}

class InventoryOverviewData {
  final double availableStock;
  final int activeWarehousesCount;
  final int installedAssetsCount;
  final List<WarehouseItem> warehouses;
  final List<StockTransaction> recentTransactions;
  final List<MaterialItem> materials;
  final List<InventoryItem> items;

  InventoryOverviewData({
    required this.availableStock,
    required this.activeWarehousesCount,
    required this.installedAssetsCount,
    required this.warehouses,
    required this.recentTransactions,
    required this.materials,
    this.items = const [],
  });

  factory InventoryOverviewData.empty() {
    return InventoryOverviewData(
      availableStock: 0.0,
      activeWarehousesCount: 0,
      installedAssetsCount: 0,
      warehouses: [],
      recentTransactions: [],
      materials: [],
      items: [],
    );
  }
}

enum CustodyState {
  inUse,
  maintenance,
  inStock,
  stopped,
  disposed,
}

class CustodyAssetItem {
  final String id;
  final String code;
  final String name;
  final String status;
  final String? assetCategory;
  final String? serialNumber;
  final String? unit;
  final double? purchasePrice;
  final String? assignedEmployeeId;
  final String? assignedEmployeeName;
  final DateTime? assignedAt;

  CustodyAssetItem({
    required this.id,
    required this.code,
    required this.name,
    this.status = 'OPERATING',
    this.assetCategory,
    this.serialNumber,
    this.unit,
    this.purchasePrice,
    this.assignedEmployeeId,
    this.assignedEmployeeName,
    this.assignedAt,
  });

  CustodyState get custodyState {
    if (assignedEmployeeId != null && assignedEmployeeId!.isNotEmpty) {
      return CustodyState.inUse;
    }
    if (status == 'MAINTENANCE') return CustodyState.maintenance;
    if (status == 'STOPPED') return CustodyState.stopped;
    if (status == 'DISPOSED') return CustodyState.disposed;
    return CustodyState.inStock;
  }

  String get custodyStateLabel => stateLabel;

  String get stateLabel {
    switch (custodyState) {
      case CustodyState.inUse:
        return 'Đang sử dụng';
      case CustodyState.maintenance:
        return 'Bảo trì';
      case CustodyState.inStock:
        return 'Tồn kho';
      case CustodyState.stopped:
        return 'Ngừng hoạt động';
      case CustodyState.disposed:
        return 'Đã thanh lý';
    }
  }

  String get categoryLabel {
    switch (assetCategory) {
      case 'INDUSTRIAL':
        return 'Thiết bị công nghiệp';
      case 'IT_OFFICE':
        return 'Thiết bị CNTT, văn phòng';
      case 'TOOL_PPE':
        return 'Dụng cụ, bảo hộ';
      case 'VEHICLE':
        return 'Phương tiện';
      default:
        return assetCategory ?? '—';
    }
  }

  factory CustodyAssetItem.fromJson(Map<String, dynamic> json, {String? employeeNameFallback}) {
    DateTime? parsedAssignedAt;
    final assignedAtRaw = json['assignedAt'] ?? json['assigned_at'];
    if (assignedAtRaw != null) {
      parsedAssignedAt = DateTime.tryParse(assignedAtRaw.toString());
    }

    return CustodyAssetItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPERATING',
      assetCategory: json['assetCategory']?.toString() ?? json['asset_category']?.toString(),
      serialNumber: json['serialNumber']?.toString() ?? json['serial_number']?.toString(),
      unit: json['unit']?.toString() ?? 'Cái',
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? (json['purchase_price'] as num?)?.toDouble(),
      assignedEmployeeId: json['assignedEmployeeId']?.toString() ?? json['assigned_employee_id']?.toString(),
      assignedEmployeeName: employeeNameFallback ?? json['assignedEmployeeName']?.toString() ?? json['employeeName']?.toString(),
      assignedAt: parsedAssignedAt,
    );
  }
}



class StockDocumentLineItem {
  final String id;
  final String? documentId;
  final int lineNo;
  final String materialId;
  final String materialCode;
  final String materialName;
  final String unit;
  final double quantity;
  final double? unitPrice;
  final double? amount;
  final String? lotNumber;
  final String? direction;
  final List<String> serials;

  StockDocumentLineItem({
    required this.id,
    this.documentId,
    this.lineNo = 1,
    this.materialId = '',
    required this.materialCode,
    required this.materialName,
    this.unit = 'Cái',
    required this.quantity,
    this.unitPrice,
    this.amount,
    this.lotNumber,
    this.direction,
    this.serials = const [],
  });

  factory StockDocumentLineItem.fromJson(Map<String, dynamic> json) {
    List<String> parsedSerials = [];
    if (json['serials'] is List) {
      parsedSerials = (json['serials'] as List).map((e) => e.toString()).toList();
    }
    return StockDocumentLineItem(
      id: json['id']?.toString() ?? '',
      documentId: json['documentId']?.toString() ?? json['document_id']?.toString(),
      lineNo: (json['lineNo'] as num?)?.toInt() ?? (json['line_no'] as num?)?.toInt() ?? 1,
      materialId: json['materialId']?.toString() ?? json['material_id']?.toString() ?? '',
      materialCode: json['materialCode']?.toString() ?? json['material_code']?.toString() ?? '',
      materialName: json['materialName']?.toString() ?? json['material_name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'Cái',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? (json['unit_price'] as num?)?.toDouble(),
      amount: (json['amount'] as num?)?.toDouble(),
      lotNumber: json['lotNumber']?.toString() ?? json['lot_number']?.toString(),
      direction: json['direction']?.toString(),
      serials: parsedSerials,
    );
  }
}

class StockDocumentItem {
  final String id;
  final String code;
  final String docType;
  final String status;
  final String warehouseId;
  final String warehouseCode;
  final String? targetWarehouseId;
  final String? targetWarehouseCode;
  final String? sourceType;
  final String? sourceId;
  final String documentDate;
  final String? note;
  final String? rejectReason;
  final String? reversesDocumentId;
  final String createdBy;
  final String? submittedBy;
  final String? approvedBy;
  final String? rejectedBy;
  final String? postedBy;
  final DateTime? postedAt;
  final DateTime createdAt;
  final List<StockDocumentLineItem> lines;

  StockDocumentItem({
    required this.id,
    required this.code,
    required this.docType,
    required this.status,
    required this.warehouseId,
    required this.warehouseCode,
    this.targetWarehouseId,
    this.targetWarehouseCode,
    this.sourceType,
    this.sourceId,
    required this.documentDate,
    this.note,
    this.rejectReason,
    this.reversesDocumentId,
    required this.createdBy,
    this.submittedBy,
    this.approvedBy,
    this.rejectedBy,
    this.postedBy,
    this.postedAt,
    required this.createdAt,
    this.lines = const [],
  });

  String get docTypeLabel {
    switch (docType) {
      case 'RECEIPT_PURCHASE':
        return 'Nhập mua hàng';
      case 'RECEIPT_SALES_RETURN':
        return 'Nhập trả hàng bán';
      case 'RECEIPT_TRANSFER':
        return 'Nhập điều chuyển';
      case 'RECEIPT_OTHER':
        return 'Nhập khác';
      case 'ISSUE_SALES':
        return 'Xuất bán hàng';
      case 'ISSUE_PROJECT':
        return 'Xuất cho dự án';
      case 'ISSUE_WARRANTY':
        return 'Xuất bảo hành';
      case 'ISSUE_TRANSFER':
        return 'Xuất điều chuyển';
      case 'ISSUE_OTHER':
        return 'Xuất khác';
      case 'ADJUSTMENT':
        return 'Điều chỉnh tồn';
      case 'TRANSFER':
        return 'Điều chuyển kho';
      default:
        return docType;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'POSTED':
        return 'Đã ghi sổ';
      case 'DRAFT':
        return 'Nháp';
      case 'PENDING':
        return 'Chờ duyệt';
      case 'APPROVED':
        return 'Đã duyệt';
      case 'REJECTED':
        return 'Từ chối';
      case 'CANCELLED':
        return 'Đã huỷ';
      default:
        return status;
    }
  }

  String get sourceLabel {
    if (sourceType == null || sourceType!.isEmpty) return 'Không có nguồn';
    switch (sourceType) {
      case 'crm_order':
      case 'crm_sales_order':
        return 'Đơn bán';
      case 'crm_delivery':
        return 'Đợt giao hàng';
      case 'crm_warranty':
        return 'Bảo hành';
      case 'crm_return':
        return 'Trả hàng';
      default:
        return sourceType!;
    }
  }

  double get totalQuantity {
    return lines.fold(0.0, (sum, l) => sum + l.quantity);
  }

  double get totalCost {
    return lines.fold(0.0, (sum, l) => sum + (l.amount ?? (l.quantity * (l.unitPrice ?? 0.0))));
  }

  bool get isReversal =>
      (reversesDocumentId != null && reversesDocumentId!.isNotEmpty) ||
      (note != null && note!.startsWith('Đảo chứng từ'));

  String get warehouseDisplay {
    if (targetWarehouseCode != null && targetWarehouseCode!.isNotEmpty) {
      return '$warehouseCode → $targetWarehouseCode';
    }
    return warehouseCode;
  }

  factory StockDocumentItem.fromJson(Map<String, dynamic> json) {
    List<StockDocumentLineItem> parsedLines = [];
    if (json['lines'] is List) {
      parsedLines = (json['lines'] as List)
          .map((e) => StockDocumentLineItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    DateTime parsedCreatedAt = DateTime.now();
    final createdRaw = json['createdAt'] ?? json['created_at'];
    if (createdRaw != null) {
      parsedCreatedAt = DateTime.tryParse(createdRaw.toString()) ?? DateTime.now();
    }

    DateTime? parsedPostedAt;
    final postedRaw = json['postedAt'] ?? json['posted_at'];
    if (postedRaw != null) {
      parsedPostedAt = DateTime.tryParse(postedRaw.toString());
    }

    return StockDocumentItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      docType: json['docType']?.toString() ?? json['doc_type']?.toString() ?? 'RECEIPT_PURCHASE',
      status: json['status']?.toString() ?? 'POSTED',
      warehouseId: json['warehouseId']?.toString() ?? json['warehouse_id']?.toString() ?? '',
      warehouseCode: json['warehouseCode']?.toString() ?? json['warehouse_code']?.toString() ?? '',
      targetWarehouseId: json['targetWarehouseId']?.toString() ?? json['target_warehouse_id']?.toString(),
      targetWarehouseCode: json['targetWarehouseCode']?.toString() ?? json['target_warehouse_code']?.toString(),
      sourceType: json['sourceType']?.toString() ?? json['source_type']?.toString(),
      sourceId: json['sourceId']?.toString() ?? json['source_id']?.toString(),
      documentDate: json['documentDate']?.toString() ?? json['document_date']?.toString() ?? '',
      note: json['note']?.toString(),
      rejectReason: json['rejectReason']?.toString() ?? json['reject_reason']?.toString(),
      reversesDocumentId: json['reversesDocumentId']?.toString() ?? json['reverses_document_id']?.toString(),
      createdBy: json['createdBy']?.toString() ?? json['created_by']?.toString() ?? '',
      submittedBy: json['submittedBy']?.toString() ?? json['submitted_by']?.toString(),
      approvedBy: json['approvedBy']?.toString() ?? json['approved_by']?.toString(),
      rejectedBy: json['rejectedBy']?.toString() ?? json['rejected_by']?.toString(),
      postedBy: json['postedBy']?.toString() ?? json['posted_by']?.toString(),
      postedAt: parsedPostedAt,
      createdAt: parsedCreatedAt,
      lines: parsedLines,
    );
  }
}

class StocktakeSession {
  final String id;
  final String code; // KK-YYYY-xxxxx
  final String title;
  final String warehouseId;
  final String warehouseCode;
  final String? warehouseName;
  final String status; // 'DRAFT', 'COUNTING', 'PENDING_APPROVAL', 'APPROVED', 'POSTED', 'CANCELLED'
  final String scopeType; // 'ALL', 'CATEGORY', 'SPECIFIC_ITEMS'
  final String? stocktakeDate;
  final String? leadAuditor;
  final int totalItems;
  final int countedItems;
  final int differenceItems;
  final double totalVarianceValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  StocktakeSession({
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
    this.totalItems = 0,
    this.countedItems = 0,
    this.differenceItems = 0,
    this.totalVarianceValue = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StocktakeSession.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreated = DateTime.now();
    final cRaw = json['createdAt'] ?? json['created_at'];
    if (cRaw != null) {
      parsedCreated = DateTime.tryParse(cRaw.toString()) ?? DateTime.now();
    }

    DateTime parsedUpdated = DateTime.now();
    final uRaw = json['updatedAt'] ?? json['updated_at'];
    if (uRaw != null) {
      parsedUpdated = DateTime.tryParse(uRaw.toString()) ?? DateTime.now();
    }

    return StocktakeSession(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Phiên kiểm kê',
      warehouseId: json['warehouseId']?.toString() ?? json['warehouse_id']?.toString() ?? '',
      warehouseCode: json['warehouseCode']?.toString() ?? json['warehouse_code']?.toString() ?? '',
      warehouseName: json['warehouseName']?.toString() ?? json['warehouse_name']?.toString(),
      status: json['status']?.toString() ?? 'DRAFT',
      scopeType: json['scopeType']?.toString() ?? json['scope_type']?.toString() ?? 'ALL',
      stocktakeDate: json['stocktakeDate']?.toString() ?? json['stocktake_date']?.toString(),
      leadAuditor: json['leadAuditor']?.toString() ?? json['lead_auditor']?.toString(),
      totalItems: (json['totalItems'] as num?)?.toInt() ?? (json['total_items'] as num?)?.toInt() ?? 0,
      countedItems: (json['countedItems'] as num?)?.toInt() ?? (json['counted_items'] as num?)?.toInt() ?? 0,
      differenceItems: (json['differenceItems'] as num?)?.toInt() ?? (json['difference_items'] as num?)?.toInt() ?? 0,
      totalVarianceValue: (json['totalVarianceValue'] as num?)?.toDouble() ?? (json['total_variance_value'] as num?)?.toDouble() ?? 0.0,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
    );
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'COUNTING':
        return 'Đang đếm';
      case 'PENDING_APPROVAL':
        return 'Chờ duyệt';
      case 'APPROVED':
        return 'Đã duyệt';
      case 'POSTED':
        return 'Đã hoàn tất';
      case 'CANCELLED':
        return 'Đã hủy';
      case 'DRAFT':
      default:
        return 'Dự thảo';
    }
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'COUNTING':
        return const Color(0xFF2563EB); // Blue
      case 'PENDING_APPROVAL':
        return const Color(0xFFD97706); // Amber
      case 'APPROVED':
      case 'POSTED':
        return const Color(0xFF059669); // Green
      case 'CANCELLED':
        return const Color(0xFFDC2626); // Red
      case 'DRAFT':
      default:
        return const Color(0xFF64748B); // Slate
    }
  }
}
