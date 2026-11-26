import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_client_helper.dart';
import '../domain/crm_exception.dart';

/// Gọi thẳng CRM API `/api/crm/v1` (như web `crm-api.ts`, cùng phiên đăng nhập qua [ApiClientHelper]).
/// Trả JSON thô khi 2xx (204 → null), ném [CrmException] (mang `message`/`code`/thân lỗi của server) khi lỗi.
///
/// Truy vấn: truyền Map, giá trị null / chuỗi rỗng bị bỏ (web `toQuery`); giá trị khác đổi `toString()`.
class CrmApiClient {
  CrmApiClient._() {
    ApiClientHelper.configureDio(_dio);
  }
  static final CrmApiClient instance = CrmApiClient._();

  /// Gốc API (contracts `CRM_API_ROOT`).
  static const String root = '/api/crm/v1';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Dio riêng cho URL ký của kho lưu trữ: KHÔNG gắn cookie / `x-csrf-token` (header lạ làm sai chữ ký).
  final Dio _plain = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 5),
    sendTimeout: const Duration(minutes: 5),
  ));

  static final Options _lenient = Options(validateStatus: (s) => s != null && s < 500);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body ?? const <String, dynamic>{});
  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body ?? const <String, dynamic>{});
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body ?? const <String, dynamic>{});
  Future<dynamic> delete(String path, {Object? body}) => _send('DELETE', path, body: body);

  /// Gọi API module khác (vd. `/api/auth/v1/me`, `/api/inventory/v1/...`) với cùng phiên đăng nhập.
  Future<dynamic> getAbsolute(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query, absolute: true);

  /// Ghi (POST/PATCH/PUT/DELETE) vào API module khác.
  Future<dynamic> sendAbsolute(String method, String path, {Object? body, Map<String, dynamic>? query}) =>
      _send(method, path, body: body, query: query, absolute: true);

  /// Đoạn đường dẫn an toàn (web `encodeURIComponent`): `'/customers/${CrmApiClient.seg(id)}'`.
  static String seg(String value) => Uri.encodeComponent(value);

  /// Bỏ giá trị rỗng khỏi truy vấn (web `toQuery`).
  static Map<String, dynamic>? cleanQuery(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      final text = value.toString();
      if (text.isEmpty) return;
      out[key] = text;
    });
    return out;
  }

  Future<dynamic> _send(String method, String path,
      {Object? body, Map<String, dynamic>? query, bool absolute = false}) async {
    try {
      final res = await _dio.request<dynamic>(
        absolute ? path : '$root$path',
        data: body,
        queryParameters: cleanQuery(query),
        options: _lenient.copyWith(method: method),
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return code == 204 ? null : res.data;
      throw _toException(res.data, code);
    } on DioException catch (e) {
      final response = e.response;
      if (response == null) throw const CrmException(code: CrmException.clientNetwork);
      throw _toException(response.data, response.statusCode);
    }
  }

  /// PUT file thẳng lên URL ký (web `putFileToSignedUrl`), không qua máy chủ CRM. Luồng tài liệu 3 bước: xin URL ký
  /// (`POST /documents` hoặc `/documents/:id/versions`) → [putSignedUrl] → `POST .../versions/:versionId/complete`.
  /// Lỗi: [CrmException] với `code` `clientUpload*` (403 → hết hạn; khác 2xx → bị từ chối, `statusCode` là mã của
  /// kho lưu trữ; mất mạng; huỷ qua [cancelToken]).
  Future<void> putSignedUrl(
    String uploadUrl,
    Uint8List bytes,
    String contentType, {
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _plain.put<dynamic>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        cancelToken: cancelToken,
        onSendProgress: onProgress,
        options: Options(
          headers: {Headers.contentTypeHeader: contentType, Headers.contentLengthHeader: bytes.length},
          validateStatus: (_) => true,
        ),
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return;
      if (code == 403) throw CrmException(code: CrmException.clientUploadExpired, statusCode: code);
      throw CrmException(code: CrmException.clientUploadRejected, statusCode: code);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) throw const CrmException(code: CrmException.clientUploadCancelled);
      throw const CrmException(code: CrmException.clientUploadNetwork);
    }
  }

  static CrmException _toException(dynamic data, int? status) {
    String? message;
    String? code;
    var body = const <String, dynamic>{};
    if (data is Map) {
      body = Map<String, dynamic>.from(data);
      final raw = body['message'];
      message = raw is List ? raw.map((e) => e.toString()).join(' ') : raw?.toString();
      if (message != null && message.isEmpty) message = null;
      code = body['code']?.toString();
    }
    return CrmException(message: message, code: code, statusCode: status, data: body);
  }
}
