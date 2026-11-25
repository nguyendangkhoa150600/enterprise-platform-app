import 'package:dio/dio.dart';
import '../../domain/errors/correspondence_exception.dart';

/// Đổi lỗi Dio thành [CorrespondenceException] để tầng trên không phụ thuộc Dio.
/// Thân lỗi API có dạng `{code, message}` (message tiếng Việt, hiện thẳng cho người dùng).
CorrespondenceException mapCorrespondenceDioError(DioException error) {
  final data = error.response?.data;
  String? message;
  String? code;
  if (data is Map) {
    final raw = data['message']?.toString();
    message = (raw != null && raw.isNotEmpty) ? raw : null;
    code = data['code']?.toString();
  }
  return CorrespondenceException(
    message: message,
    code: code,
    statusCode: error.response?.statusCode,
  );
}

/// Phản hồi với `validateStatus: s < 500` không ném lỗi ở 4xx: tự kiểm tra mã trạng thái.
dynamic ensureCorrespondenceOk(Response res) {
  final status = res.statusCode ?? 0;
  if (status >= 200 && status < 300) return res.data;
  throw mapCorrespondenceDioError(
    DioException(requestOptions: res.requestOptions, response: res, type: DioExceptionType.badResponse),
  );
}
