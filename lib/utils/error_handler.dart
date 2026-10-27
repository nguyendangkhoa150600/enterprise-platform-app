import 'package:power_quality_analysis/core/i18n/app_i18n.dart';
import 'package:dio/dio.dart';

class ApiErrorHandler {
  static String parse(dynamic error, {String? defaultMessage}) {
    defaultMessage ??= 'core_misc.err.default'.tr();
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
        return 'core_misc.err.unauth_long'.tr();
      }

      // 403 Forbidden
      if (statusCode == 403 || (rawMsg != null && rawMsg.toLowerCase().contains('forbidden'))) {
        return 'core_misc.err.forbidden_403'.tr();
      }

      // 404 Not Found
      if (statusCode == 404) {
        return 'core_misc.err.not_found'.tr();
      }

      // 409 Conflict / Duplication
      if (statusCode == 409 || (rawMsg != null && rawMsg.toLowerCase().contains('already exists'))) {
        if (rawMsg != null && rawMsg.toLowerCase().contains('email')) {
          return 'core_misc.err.email_exists'.tr();
        }
        if (rawMsg != null && rawMsg.isNotEmpty) {
          return rawMsg;
        }
        return 'core_misc.err.duplicate'.tr();
      }

      // 400 Bad Request / 422 Unprocessable Entity
      if (statusCode == 400 || statusCode == 422) {
        if (rawMsg != null && rawMsg.isNotEmpty) {
          return rawMsg;
        }
        return 'core_misc.err.invalid_input'.tr();
      }

      // 500+ Server Error
      if (statusCode != null && statusCode >= 500) {
        return 'core_misc.err.server_error'.tr(args: {'code': statusCode});
      }

      // Network / Timeouts
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'core_misc.err.timeout'.tr();
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'core_misc.err.conn_error'.tr();
      }

      if (rawMsg != null && rawMsg.trim().isNotEmpty) {
        return rawMsg;
      }
    }

    final str = error.toString();
    final lowerStr = str.toLowerCase();
    if (lowerStr.contains('unauthorized') || str.contains('401')) {
      return 'core_misc.err.unauth'.tr();
    }
    if (lowerStr.contains('forbidden') || str.contains('403')) {
      return 'core_misc.err.forbidden_account'.tr();
    }
    if (lowerStr.contains('socketexception') || lowerStr.contains('failed host lookup')) {
      return 'core_misc.err.no_connection'.tr();
    }

    return defaultMessage;
  }

  static String _translateValidationMessage(String msg) {
    final lower = msg.toLowerCase();
    if (lower == 'unauthorized') {
      return 'core_misc.err.unauth'.tr();
    }
    if (lower == 'forbidden' || lower.contains('forbidden resource')) {
      return 'core_misc.err.forbidden_short'.tr();
    }
    if (lower.contains('password') && (lower.contains('12') || lower.contains('short') || lower.contains('longer') || lower.contains('characters'))) {
      return 'core_misc.err.password_len'.tr();
    }
    if (lower.contains('email') && (lower.contains('must be an email') || lower.contains('invalid email') || lower.contains('format'))) {
      return 'core_misc.err.email_format'.tr();
    }
    if (lower.contains('already exists') || lower.contains('duplicate')) {
      return 'core_misc.err.data_exists'.tr();
    }
    if (msg.contains('Gán role qua API')) {
      return 'core_misc.err.role_assign'.tr();
    }
    if (lower.contains('fullname') && lower.contains('empty')) {
      return 'core_misc.err.fullname_empty'.tr();
    }
    return msg;
  }
}
