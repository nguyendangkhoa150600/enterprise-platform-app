/// Lỗi nghiệp vụ của phân hệ Văn thư, độc lập với thư viện HTTP.
///
/// [message] là lời nhắn tiếng Việt máy chủ trả về (`{code, message}`), hiện thẳng cho
/// người dùng như bên web; `null` khi không có (mất mạng, timeout, tệp lỗi) để tầng
/// giao diện dùng câu mặc định đã dịch.
class CorrespondenceException implements Exception {
  final String? message;
  final String? code;
  final int? statusCode;

  const CorrespondenceException({this.message, this.code, this.statusCode});

  @override
  String toString() => 'CorrespondenceException($statusCode, $code): ${message ?? ''}';
}
