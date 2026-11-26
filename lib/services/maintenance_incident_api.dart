import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

/// Người phụ trách chọn được trên form "Tạo sự cố" (web `loadTenantMembers`: `members[]` của `/organization-context`).
class MaintenanceMember {
  final String userId;
  final String displayName;

  const MaintenanceMember({required this.userId, required this.displayName});
}

/// Các lời gọi của form "Tạo sự cố" theo web `maintenance-api.ts` (`/api/maintenance/v1`).
/// Tách riêng để không dồn thêm vào `ModuleBusinessService` (đã quá giới hạn 1.500 dòng).
class MaintenanceIncidentApi {
  static const String _root = '/api/maintenance/v1';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  MaintenanceIncidentApi() {
    ApiClientHelper.configureDio(_dio);
  }

  static final Options _lenient = Options(validateStatus: (s) => s != null && s < 500);

  static String? _message(dynamic data) {
    if (data is Map) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }

  /// Web `loadTenantMembers`: lỗi → rỗng.
  Future<List<MaintenanceMember>> members() async {
    try {
      final res = await _dio.get<dynamic>('$_root/organization-context', options: _lenient);
      final raw = res.data is Map ? (res.data as Map)['members'] : null;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => MaintenanceMember(
                userId: m['userId']?.toString() ?? '',
                displayName: m['displayName']?.toString() ?? '',
              ))
          .where((m) => m.userId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Web `loadAssistantActionKeys`: mã các thao tác Trợ lý người đang đăng nhập làm được. Null khi không tải được.
  Future<Set<String>?> assistantActionKeys() async {
    try {
      final res = await _dio.get<dynamic>('$_root/assistant/actions', options: _lenient);
      final code = res.statusCode ?? 0;
      if (code < 200 || code >= 300) return null;
      final raw = res.data is Map ? (res.data as Map)['actions'] : null;
      if (raw is! List) return <String>{};
      return raw.whereType<Map>().map((a) => a['key']?.toString() ?? '').where((k) => k.isNotEmpty).toSet();
    } catch (_) {
      return null;
    }
  }

  /// Web `createMaintenanceIncident` (`POST /occurrences/incidents`, body `CreateMaintenanceIncidentRequest`).
  /// Trả phiếu vừa tạo (`MaintenanceOccurrence`), hoặc lời nhắn lỗi của server.
  Future<({Map<String, dynamic>? occurrence, String? error})> createIncident(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<dynamic>('$_root/occurrences/incidents', data: body, options: _lenient);
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300 && res.data is Map) {
        return (occurrence: Map<String, dynamic>.from(res.data as Map), error: null);
      }
      return (occurrence: null, error: _message(res.data));
    } on DioException catch (e) {
      return (occurrence: null, error: _message(e.response?.data));
    } catch (_) {
      return (occurrence: null, error: null);
    }
  }
}
