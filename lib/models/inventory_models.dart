class MaterialItem {
  final String code;
  final String name;
  final String unit;
  final String category;
  final double onHand;
  final double minStock;
  final String warehouseName;
  final String status; // 'NORMAL' | 'LOW_STOCK' | 'OUT_OF_STOCK'

  MaterialItem({
    required this.code,
    required this.name,
    required this.unit,
    required this.category,
    required this.onHand,
    required this.minStock,
    required this.warehouseName,
    required this.status,
  });

  bool get isLowStock => onHand <= minStock;

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    final onHandVal = (json['onHand'] as num?)?.toDouble() ?? 0.0;
    final minVal = (json['minStock'] as num?)?.toDouble() ?? 10.0;
    return MaterialItem(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'Cái',
      category: json['category']?.toString() ?? 'Phụ tùng',
      onHand: onHandVal,
      minStock: minVal,
      warehouseName: json['warehouseName']?.toString() ?? 'Kho Tổng',
      status: onHandVal <= 0 ? 'OUT_OF_STOCK' : onHandVal <= minVal ? 'LOW_STOCK' : 'NORMAL',
    );
  }
}

class StockTransaction {
  final String id;
  final String code;
  final String type; // 'RECEIPT' (Nhập) | 'ISSUE' (Xuất) | 'TRANSFER' (Điều chuyển)
  final String materialCode;
  final String materialName;
  final double quantity;
  final String date;
  final String createdBy;
  final String? note;

  StockTransaction({
    required this.id,
    required this.code,
    required this.type,
    required this.materialCode,
    required this.materialName,
    required this.quantity,
    required this.date,
    required this.createdBy,
    this.note,
  });

  factory StockTransaction.fromJson(Map<String, dynamic> json) {
    return StockTransaction(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? 'TRX-001',
      type: json['type']?.toString() ?? 'RECEIPT',
      materialCode: json['materialCode']?.toString() ?? '',
      materialName: json['materialName']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      date: json['date']?.toString() ?? json['createdAt']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? 'Thủ kho',
      note: json['note']?.toString(),
    );
  }
}
