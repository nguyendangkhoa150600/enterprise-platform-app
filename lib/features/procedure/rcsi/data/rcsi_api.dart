import 'package:dio/dio.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../services/api_client_helper.dart';
import '../domain/logic/rcsi_board_ops.dart';
import '../domain/organization_snapshot.dart';
import '../domain/rcsi_definition_models.dart';
import '../domain/rcsi_flow_models.dart';
import '../domain/rcsi_json.dart';
import '../domain/rcsi_repository.dart';
import '../domain/rcsi_workspace_models.dart';

/// Gọi thẳng Procedure API `/api/procedure/v1` cho Ma trận RCSI — đúng endpoint
/// và payload của `procedure-api.ts` / `organization-api.ts` (web).
class RcsiApi implements RcsiRepository {
  static const String root = '/api/procedure/v1';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    contentType: Headers.jsonContentType,
  ));

  RcsiApi() {
    ApiClientHelper.configureDio(_dio);
  }

  static final Options _lenient = Options(validateStatus: (status) => status != null && status < 500);

  Future<dynamic> _send(String method, String path, {Object? body}) async {
    try {
      final response = await _dio.request<dynamic>(
        '$root$path',
        data: body,
        options: _lenient.copyWith(method: method),
      );
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300) return response.data;
      throw _toException(response.data, code);
    } on DioException catch (error) {
      throw _toException(error.response?.data, error.response?.statusCode);
    }
  }

  /// Web `request()`: `message` có thể là mảng (lỗi kiểm tra của Nest) → nối ", ".
  static RcsiApiException _toException(dynamic data, int? status) {
    String? message;
    if (data is Map) {
      final raw = data['message'];
      message = raw is List ? raw.map((item) => item.toString()).join(', ') : raw?.toString();
      if (message != null && message.isEmpty) message = null;
    }
    return RcsiApiException(message: message, statusCode: status);
  }

  static String _id(String value) => Uri.encodeComponent(value);

  @override
  Future<RcsiWorkspace> loadWorkspace() async =>
      RcsiWorkspace.fromJson(jsonMap(await _send('GET', '/workspace')));

  @override
  Future<TenantOrganizationSnapshot> loadOrganization() async =>
      TenantOrganizationSnapshot.fromJson(jsonMap(await _send('GET', '/organization-context')));

  @override
  Future<List<MaterialCatalogItem>> loadMaterialCatalog() async {
    try {
      final data = await _send('GET', '/material-catalog');
      return jsonList(data, MaterialCatalogItem.fromJson);
    } catch (_) {
      // Kho chưa chạy thì vẫn thiết kế được quy trình, chỉ là không chọn được vật tư.
      return const [];
    }
  }

  @override
  Future<ProcedureGroupCatalog> loadGroupCatalog() async {
    final snapshot = jsonMap(await _send('GET', '/settings'));
    return ProcedureGroupCatalog.fromJson(jsonMap(jsonMap(snapshot['catalog.group'])['value']));
  }

  @override
  Future<ProcedureDefinition> createDefinition({
    required String code,
    required String name,
    String kind = 'process',
    String? category,
    required List<CreateProcedureStepInput> steps,
  }) async {
    final body = compactJson({
      'code': code,
      'name': name,
      'kind': kind,
      'category': (category?.isEmpty ?? true) ? null : category,
      'steps': steps.map((step) => step.toJson()).toList(),
    });
    return ProcedureDefinition.fromJson(jsonMap(await _send('POST', '/definitions', body: body)));
  }

  @override
  Future<ProcedureDefinition> updateDefinition(String definitionId, RcsiDefinitionUpdate update) async =>
      ProcedureDefinition.fromJson(
        jsonMap(await _send('PATCH', '/definitions/${_id(definitionId)}', body: update.toJson())),
      );

  @override
  Future<ProcedureValidationReport> validateDefinition(String definitionId) async =>
      ProcedureValidationReport.fromJson(
        jsonMap(await _send('POST', '/definitions/${_id(definitionId)}/validate')),
      );

  @override
  Future<ProcedureDefinition> setDefinitionCategory(String definitionId, String? category) async {
    // `category || undefined`: bỏ nhóm thì không gửi khoá.
    final body = compactJson({'category': (category?.isEmpty ?? true) ? null : category});
    return ProcedureDefinition.fromJson(
      jsonMap(await _send('PATCH', '/definitions/${_id(definitionId)}/category', body: body)),
    );
  }

  @override
  Future<ProcedureDefinition> reviseDefinition(String definitionId) async =>
      ProcedureDefinition.fromJson(jsonMap(await _send('POST', '/definitions/${_id(definitionId)}/revise')));

  @override
  Future<ProcedureDefinition> publishDefinition(String definitionId) async =>
      ProcedureDefinition.fromJson(jsonMap(await _send('POST', '/definitions/${_id(definitionId)}/publish')));

  @override
  Future<void> archiveDefinition(String definitionId) async {
    await _send('POST', '/definitions/${_id(definitionId)}/archive', body: const <String, dynamic>{});
  }

  @override
  Future<void> deleteDefinition(String definitionId) async {
    await _send('DELETE', '/definitions/${_id(definitionId)}');
  }
}
