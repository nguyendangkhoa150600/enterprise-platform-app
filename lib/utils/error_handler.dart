import 'package:dio/dio.dart';

class ApiErrorHandler {
  static String parse(dynamic error, {String defaultMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại.'}) {
    if (error == null) return defaultMessage;

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;

      String? rawMsg;
      if (data is Map) {
        final m = data['message'] ?? data['error'] ?? data['msg'];
        if (m is List) {
          rawMsg = m.map((item) => _translateValidationMessage(item.toString())).join('\n• ');
          if (m.length > 1) {
            rawMsg = '• $rawMsg';
          }
        } else if (m != null) {
          rawMsg = _translateValidationMessage(m.toString());
        }
      } else if (data is String && data.isNotEmpty) {
        rawMsg = _translateValidationMessage(data);
      }

      // 401 Unauthorized
      if (statusCode == 401 || (rawMsg != null && rawMsg.toLowerCase().contains('unauthorized'))) {
        return 'Phiên làm việc đã hết hạn hoặc chưa được xác thực (401). Vui lòng đăng xuất và đăng nhập lại để tiếp tục.';
      }

      // 403 Forbidden
      if (statusCode == 403 || (rawMsg != null && rawMsg.toLowerCase().contains('forbidden'))) {
        return 'Bạn không có quyền thực hiện thao tác này (403 Forbidden). Vui lòng liên hệ Quản trị viên để được cấp quyền tương ứng.';
      }

      // 404 Not Found
      if (statusCode == 404) {
        return 'Không tìm thấy dữ liệu yêu cầu hoặc tài nguyên đã bị xóa (404 Not Found).';
      }

      // 409 Conflict / Duplication
      if (statusCode == 409 || (rawMsg != null && rawMsg.toLowerCase().contains('already exists'))) {
        if (rawMsg != null && rawMsg.toLowerCase().contains('email')) {
          return 'Địa chỉ email này đã tồn tại trong hệ thống. Vui lòng sử dụng địa chỉ email khác.';
        }
        if (rawMsg != null && rawMsg.isNotEmpty) {
          return rawMsg;
        }
        return 'Dữ liệu này đã tồn tại trong hệ thống (bị trùng lặp). Vui lòng kiểm tra lại.';
      }

      // 400 Bad Request / 422 Unprocessable Entity
      if (statusCode == 400 || statusCode == 422) {
        if (rawMsg != null && rawMsg.isNotEmpty) {
          return rawMsg;
        }
        return 'Thông tin gửi lên chưa hợp lệ. Vui lòng kiểm tra lại các trường dữ liệu.';
      }

      // 500+ Server Error
      if (statusCode != null && statusCode >= 500) {
        return 'Máy chủ backend đang gặp sự cố xử lý (Mã lỗi $statusCode). Vui lòng thử lại sau.';
      }

      // Network / Timeouts
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Hết thời gian chờ kết nối máy chủ (Timeout). Vui lòng kiểm tra lại đường truyền mạng.';
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'Không thể kết nối đến máy chủ API. Vui lòng kiểm tra kết nối mạng của thiết bị hoặc trạng thái server.';
      }

      if (rawMsg != null && rawMsg.trim().isNotEmpty) {
        return rawMsg;
      }
    }

    final str = error.toString();
    final lowerStr = str.toLowerCase();
    if (lowerStr.contains('unauthorized') || str.contains('401')) {
      return 'Phiên làm việc đã hết hạn hoặc chưa được xác thực (401). Vui lòng đăng xuất và đăng nhập lại.';
    }
    if (lowerStr.contains('forbidden') || str.contains('403')) {
      return 'Tài khoản không đủ quyền hạn để thực hiện thao tác này.';
    }
    if (lowerStr.contains('socketexception') || lowerStr.contains('failed host lookup')) {
      return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.';
    }

    return defaultMessage;
  }

  static String _translateValidationMessage(String msg) {
    final lower = msg.toLowerCase();
    if (lower == 'unauthorized') {
      return 'Phiên làm việc đã hết hạn hoặc chưa được xác thực (401). Vui lòng đăng xuất và đăng nhập lại.';
    }
    if (lower == 'forbidden' || lower.contains('forbidden resource')) {
      return 'Bạn không có quyền thực hiện thao tác này.';
    }
    if (lower.contains('password') && (lower.contains('12') || lower.contains('short') || lower.contains('longer') || lower.contains('characters'))) {
      return 'Mật khẩu phải có độ dài từ 12 đến 128 ký tự theo quy định bảo mật.';
    }
    if (lower.contains('email') && (lower.contains('must be an email') || lower.contains('invalid email') || lower.contains('format'))) {
      return 'Địa chỉ email không đúng định dạng.';
    }
    if (lower.contains('already exists') || lower.contains('duplicate')) {
      return 'Dữ liệu hoặc email này đã tồn tại trên hệ thống.';
    }
    if (msg.contains('Gán role qua API')) {
      return 'Không thể gán vai trò trực tiếp khi tạo. Vui lòng gán sau tại mục Phân quyền.';
    }
    if (lower.contains('fullname') && lower.contains('empty')) {
      return 'Họ và tên không được để trống.';
    }
    return msg;
  }
}
