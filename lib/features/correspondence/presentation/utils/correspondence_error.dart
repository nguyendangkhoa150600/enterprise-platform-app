import '../../domain/errors/correspondence_exception.dart';

/// Lời nhắn lỗi để hiện thẳng cho người dùng (giống `errorMessage` bên web):
/// ưu tiên `message` máy chủ trả về, không có thì dùng [fallback] (đã dịch).
String correspondenceErrorMessage(Object? cause, String fallback) {
  if (cause is CorrespondenceException) {
    final message = cause.message;
    if (message != null && message.isNotEmpty) return message;
  }
  return fallback;
}
