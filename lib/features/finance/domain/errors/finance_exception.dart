/// Lỗi gọi API Tài chính. [message] là lời nhắn tiếng Việt của server (hiện thẳng như web);
/// [details] là danh sách lỗi chi tiết (ví dụ từng điều kiện gửi duyệt chưa đạt).
class FinanceException implements Exception {
  final String? message;
  final String? code;
  final int? statusCode;
  final List<String> details;

  const FinanceException({this.message, this.code, this.statusCode, this.details = const []});

  /// Web `financeErrorMessage`: nhiều lỗi chi tiết thì gộp từng dòng, không thì câu chính.
  String? get displayMessage => details.length > 1 ? details.join('\n') : message;

  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'FinanceException($statusCode, $code): $message';
}
