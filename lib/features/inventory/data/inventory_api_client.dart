import 'package:dio/dio.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_client_helper.dart';
import '../domain/inventory_exception.dart';

/// Gọi thẳng Inventory API `/api/inventory/v1` (như web `inventory-api.ts`).
/// Trả JSON thô khi 2xx (204 → null), ném [InventoryException] khi lỗi.
class InventoryApiClient {
  InventoryApiClient._() {
    ApiClientHelper.configureDio(_dio);
  }
  static final InventoryApiClient instance = InventoryApiClient._();

  static const String root = '/api/inventory/v1';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static final Options _lenient = Options(validateStatus: (s) => s != null && s < 500);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body ?? const <String, dynamic>{});
  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body: body);
  Future<dynamic> put(String path, Object body) => _send('PUT', path, body: body);
  Future<dynamic> delete(String path, {Object? body}) => _send('DELETE', path, body: body);

  /// Gọi một API module khác (vd. `/api/procedure/v1/...`, `/api/workspace/v1/directory`) với cùng phiên đăng nhập.
  Future<dynamic> getAbsolute(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query, absolute: true);

  Future<dynamic> _send(String method, String path,
      {Object? body, Map<String, dynamic>? query, bool absolute = false}) async {
    try {
      final res = await _dio.request<dynamic>(
        absolute ? path : '$root$path',
        data: body,
        queryParameters: query,
        options: _lenient.copyWith(method: method),
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return code == 204 ? null : res.data;
      throw _toException(res.data, code);
    } on DioException catch (e) {
      throw _toException(e.response?.data, e.response?.statusCode);
    }
  }

  static InventoryException _toException(dynamic data, int? status) {
    String? message;
    String? code;
    if (data is Map) {
      final raw = data['message'];
      message = raw is List ? raw.map((e) => e.toString()).join(' ') : raw?.toString();
      if (message != null && message.isEmpty) message = null;
      code = data['code']?.toString();
    }
    return InventoryException(message: message, code: code, statusCode: status);
  }
}
