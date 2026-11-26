/// Lỗi gọi CRM API (web `CrmApiError`): giữ `message` tiếng Việt của server, `code`, mã HTTP và thân lỗi thô
/// ([data]) để đọc dữ liệu thêm như `matches` (trùng MST), `missing` (điều kiện chuyển giai đoạn), `errors`,
/// `fieldErrors`.
///
/// Lỗi phía app (mạng, URL ký tải lên) không có [message]; [code] là một trong các hằng `client*` bên dưới và
/// `crmErrorMessage` đổi sang lời nhắn đã dịch.
class CrmException implements Exception {
  final String? message;
  final String? code;
  final int? statusCode;

  /// Thân lỗi JSON của server (rỗng khi lỗi mạng).
  final Map<String, dynamic> data;

  const CrmException({this.message, this.code, this.statusCode, this.data = const {}});

  /// Không kết nối được máy chủ.
  static const String clientNetwork = 'CLIENT_NETWORK';

  /// Tải file lên URL ký: liên kết hết hạn / không hợp lệ (403).
  static const String clientUploadExpired = 'CLIENT_UPLOAD_EXPIRED';

  /// Tải file lên URL ký: kho lưu trữ từ chối (mã HTTP khác 2xx, 403).
  static const String clientUploadRejected = 'CLIENT_UPLOAD_REJECTED';

  /// Tải file lên URL ký: mất kết nối.
  static const String clientUploadNetwork = 'CLIENT_UPLOAD_NETWORK';

  /// Tải file lên URL ký: người dùng huỷ.
  static const String clientUploadCancelled = 'CLIENT_UPLOAD_CANCELLED';

  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isUnauthenticated => statusCode == 401;

  /// Danh sách đối tượng trong thân lỗi (vd. `matches`, `missing`, `errors`, `fieldErrors`).
  List<Map<String, dynamic>> listOf(String key) {
    final raw = data[key];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  String toString() => 'CrmException($statusCode, $code, $message)';
}
