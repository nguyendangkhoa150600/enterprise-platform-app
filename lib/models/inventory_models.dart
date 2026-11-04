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
  final String name;
  final String? type;
  final String? status;
  final String? serialNumber;

  AssetItem({
    required this.id,
    required this.code,
    required this.name,
    this.type,
    this.status,
    this.serialNumber,
  });

  factory AssetItem.fromJson(Map<String, dynamic> json) {
    return AssetItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      serialNumber: json['serialNumber']?.toString(),
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
  final String? currency;
  final bool? _isActive;
  bool get isActive => _isActive ?? true;
  final bool? _isSerialized;
  bool get isSerialized => _isSerialized ?? false;
  final String? type;
  final String? usageState;

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
    this.currency,
    bool isActive = true,
    bool isSerialized = false,
    this.type,
    this.usageState,
  })  : _isActive = isActive,
        _isSerialized = isSerialized;

  bool get isLowStock => onHand <= minStock;

  MaterialItem copyWith({
    double? onHand,
    String? warehouseName,
    String? status,
    bool? isSerialized,
    String? type,
    String? usageState,
  }) {
    return MaterialItem(
      id: id,
      code: code,
      name: name,
      unit: unit,
      category: category,
      onHand: onHand ?? this.onHand,
      minStock: minStock,
      maxStock: maxStock,
      warehouseName: warehouseName ?? this.warehouseName,
      status: status ?? this.status,
      purchasePrice: purchasePrice,
      currency: currency,
      isActive: isActive,
      isSerialized: isSerialized ?? this.isSerialized,
      type: type ?? this.type,
      usageState: usageState ?? this.usageState,
    );
  }

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    final onHandVal = (json['onHand'] as num?)?.toDouble() ??
        (json['available'] as num?)?.toDouble() ??
        (json['quantity'] as num?)?.toDouble() ??
        0.0;
    final minVal = (json['minStock'] as num?)?.toDouble() ?? 10.0;
    final maxVal = (json['maxStock'] as num?)?.toDouble() ?? 9999.0;
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
      currency: json['currency']?.toString() ?? 'VND',
      isActive: json['isActive'] == null ? true : (json['isActive'] == true),
      isSerialized: json['isSerialized'] == true,
      type: json['type']?.toString(),
      usageState: json['usageState']?.toString() ?? json['usage_state']?.toString(),
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
  final double? minStock;
  final double? maxStock;
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

  InventoryItem({
    required this.code,
    required this.name,
    this.kind = 'STOCK',
    this.unit = '',
    this.category,
    this.type,
    this.status,
    this.usageState,
    this.minStock,
    this.maxStock,
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
    double? minStock,
    double? maxStock,
    double? onHand,
    double? inUse,
    double? available,
    double? reserved,
    double? blocked,
    double? totalOwned,
    String? trackingType,
    bool? isSerialized,
    List<ItemWarehouseStock>? warehouseStocks,
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
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
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
    );
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'STOCK',
      unit: json['unit']?.toString() ?? 'Cái',
      category: json['category']?.toString(),
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      usageState: json['usage_state']?.toString() ?? json['usageState']?.toString(),
      minStock: (json['min_stock'] as num?)?.toDouble() ?? (json['minStock'] as num?)?.toDouble(),
      maxStock: (json['max_stock'] as num?)?.toDouble() ?? (json['maxStock'] as num?)?.toDouble(),
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
