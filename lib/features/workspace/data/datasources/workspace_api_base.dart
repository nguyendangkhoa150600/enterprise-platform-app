import 'package:dio/dio.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/api_client_helper.dart';

/// Kết quả một lời gọi API Workspace: dữ liệu khi thành công, hoặc lời nhắn lỗi của server
/// (`{code, message}` tiếng Việt, hiện thẳng như web) khi thất bại.
class WorkspaceApiResult<T> {
  final T? data;
  final String? error;
  final bool ok;

  const WorkspaceApiResult.success(this.data)
      : ok = true,
        error = null;
  const WorkspaceApiResult.failure(this.error)
      : ok = false,
        data = null;
}

/// Lớp nền cho các API Workspace tách theo tính năng (lịch, tài chính, đơn từ, phụ thuộc...),
/// để không dồn thêm vào `WorkspaceRemoteDataSource` (giới hạn 1.500 dòng).
abstract class WorkspaceApiBase {
  static const String root = '/api/workspace/v1';

  final Dio dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 25),
  ));

  WorkspaceApiBase() {
    ApiClientHelper.configureDio(dio);
  }

  static final Options _lenient = Options(validateStatus: (s) => s != null && s < 500);

  /// Gọi API, đổi phản hồi 2xx bằng [parse]; còn lại trả lời nhắn lỗi của server (hoặc null).
  Future<WorkspaceApiResult<T>> send<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final res = await dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: _lenient.copyWith(method: method),
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return WorkspaceApiResult.success(parse(res.data));
      return WorkspaceApiResult.failure(messageOf(res.data));
    } on DioException catch (e) {
      return WorkspaceApiResult.failure(messageOf(e.response?.data));
    } catch (_) {
      return const WorkspaceApiResult.failure(null);
    }
  }

  static String? messageOf(dynamic data) {
    if (data is Map) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }

  /// `{items: [...]}` hoặc mảng trần → danh sách map.
  static List<Map<String, dynamic>> itemsOf(dynamic data) {
    final raw = data is Map ? (data['items'] ?? data['data']) : data;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
