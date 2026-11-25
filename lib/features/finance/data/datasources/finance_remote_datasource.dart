import 'package:dio/dio.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/api_client_helper.dart';
import '../../domain/errors/finance_exception.dart';

/// Gọi thẳng Finance API `/api/finance/v1`. Trả JSON thô khi 2xx, ném [FinanceException] khi lỗi.
class FinanceRemoteDataSource {
  static const String root = '/api/finance/v1';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Dio trần (không cookie/CSRF) để PUT file lên link ký sẵn của kho lưu trữ.
  final Dio _storageDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(minutes: 5),
    receiveTimeout: const Duration(seconds: 60),
  ));

  FinanceRemoteDataSource() {
    ApiClientHelper.configureDio(_dio);
  }

  static final Options _lenient = Options(validateStatus: (s) => s != null && s < 500);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body ?? const <String, dynamic>{});
  Future<dynamic> put(String path, Object body) => _send('PUT', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.request<dynamic>(
        '$root$path',
        data: body,
        queryParameters: query,
        options: _lenient.copyWith(method: method),
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return res.data;
      throw _toException(res.data, code);
    } on DioException catch (e) {
      throw _toException(e.response?.data, e.response?.statusCode);
    }
  }

  /// PUT nội dung file lên link ký sẵn (bước 2 của tải đính kèm).
  Future<void> putToStorage(String url, List<int> bytes, String contentType) async {
    try {
      final res = await _storageDio.put<dynamic>(
        url,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {Headers.contentTypeHeader: contentType, Headers.contentLengthHeader: bytes.length},
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final code = res.statusCode ?? 0;
      if (code < 200 || code >= 300) throw FinanceException(statusCode: code);
    } on DioException catch (e) {
      throw FinanceException(statusCode: e.response?.statusCode);
    }
  }

  /// Thân lỗi `{code, message, details}`; message có thể là mảng (lỗi kiểm tra dữ liệu của Nest).
  static FinanceException _toException(dynamic data, int? status) {
    String? message;
    String? code;
    var details = const <String>[];
    if (data is Map) {
      final raw = data['message'];
      message = raw is List ? raw.map((e) => e.toString()).join(' ') : raw?.toString();
      if (message != null && message.isEmpty) message = null;
      code = data['code']?.toString();
      final d = data['details'];
      if (d is List) details = d.map((e) => e.toString()).toList();
    }
    return FinanceException(message: message, code: code, statusCode: status, details: details);
  }
}
