/// Lỗi gọi Inventory API: giữ lời nhắn server (`message`, có thể là mảng lỗi kiểm tra dữ liệu) và mã HTTP.
class InventoryException implements Exception {
  final String? message;
  final String? code;
  final int? statusCode;

  const InventoryException({this.message, this.code, this.statusCode});

  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'InventoryException($statusCode, $code, $message)';
}
