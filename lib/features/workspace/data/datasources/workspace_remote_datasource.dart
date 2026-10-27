import 'package:dio/dio.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/api_client_helper.dart';

/// Remote Datasource chịu trách nhiệm giao tiếp trực tiếp với Workspace REST API
/// Tiền tố chung: /api/workspace/v1
/// Tuân thủ chuẩn hợp đồng theo tài liệu workspace-api-for-app.docx
class WorkspaceRemoteDataSource {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 25),
  ));

  WorkspaceRemoteDataSource() {
    ApiClientHelper.configureDio(_dio);
  }

  // Tài liệu
  Future<dynamic> getDocumentsRaw({String? search, String? projectId}) async {
    final res = await _dio.get(
      '/api/workspace/v1/documents',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.statusCode == 200 ? res.data : null;
  }

  /// Signed download URL of the current version of a document.
  Future<String?> getDocumentDownloadUrl(String id) async {
    final res = await _dio.get(
      '/api/workspace/v1/documents/$id/download',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
      final data = res.data['data'] ?? res.data;
      if (data is Map<String, dynamic>) return data['downloadUrl']?.toString();
    }
    return null;
  }

  // 1. Khách hàng & Hợp đồng
  Future<dynamic> getCustomersRaw({String? query}) async {
    final res = await _dio.get(
      '/api/workspace/v1/customers',
      queryParameters: query != null && query.isNotEmpty ? {'query': query} : null,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<dynamic> getCustomerContractsRaw(String customerId) async {
    final res = await _dio.get(
      '/api/workspace/v1/customers/$customerId/contracts',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<dynamic> createCustomerRaw({
    required String code,
    required String name,
    String? note,
  }) async {
    final res = await _dio.post(
      '/api/workspace/v1/customers',
      data: {
        'code': code.trim(),
        'name': name.trim(),
        if (note != null && note.isNotEmpty) 'note': note.trim(),
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  // 2. Dự án
  Future<dynamic> getProjectsRaw({
    String? search,
    String? status,
    String? projectType,
    int? page,
    int? pageSize,
  }) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status != 'ALL') query['status'] = status;
    if (projectType != null && projectType != 'ALL') query['projectType'] = projectType;
    if (page != null) query['page'] = page;
    if (pageSize != null) query['pageSize'] = pageSize;

    final res = await _dio.get(
      '/api/workspace/v1/projects',
      queryParameters: query.isNotEmpty ? query : null,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<dynamic> getProjectDetailRaw(String id) async {
    final res = await _dio.get(
      '/api/workspace/v1/projects/$id',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<Response> createProjectRaw(Map<String, dynamic> data) async {
    return await _dio.post(
      '/api/workspace/v1/projects',
      data: data,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  Future<Response> updateProjectRaw(String id, Map<String, dynamic> data) async {
    return await _dio.patch(
      '/api/workspace/v1/projects/$id',
      data: data,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  Future<Response> updateProjectStatusRaw(String id, String status) async {
    final ep = status.toLowerCase() == 'archived' || status.toLowerCase() == 'completed'
        ? '/api/workspace/v1/projects/$id/archive'
        : '/api/workspace/v1/projects/$id';
    return await _dio.post(
      ep,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  Future<Response> deleteProjectRaw(String id) async {
    return await _dio.delete(
      '/api/workspace/v1/projects/$id',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  // 3. Công việc của tôi & Công việc dự án
  Future<dynamic> getMyWorkRaw() async {
    final res = await _dio.get(
      '/api/workspace/v1/my-work',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<dynamic> getProjectWorkItemsRaw(String projectId) async {
    final res = await _dio.get(
      '/api/workspace/v1/projects/$projectId/work-items',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<Response> createWorkItemRaw(Map<String, dynamic> data) async {
    return await _dio.post(
      '/api/workspace/v1/work-items',
      data: data,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  Future<Response> updateWorkItemStatusRaw(String workItemId, String status) async {
    return await _dio.patch(
      '/api/workspace/v1/work-items/$workItemId/status',
      data: {'status': status},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  // 4. Công việc ngoài dự án (Standalone Tasks)
  Future<dynamic> getStandaloneTasksRaw({String scope = 'all'}) async {
    final res = await _dio.get(
      '/api/workspace/v1/standalone-tasks',
      queryParameters: {'scope': scope},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<Response> createStandaloneTaskRaw(Map<String, dynamic> data) async {
    return await _dio.post(
      '/api/workspace/v1/standalone-tasks',
      data: data,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  Future<Response> updateStandaloneTaskStatusRaw(String taskId, String status) async {
    return await _dio.patch(
      '/api/workspace/v1/standalone-tasks/$taskId/status',
      data: {'status': status},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  // 5. Thành viên dự án
  Future<dynamic> getProjectMembersRaw(String projectId) async {
    final res = await _dio.get(
      '/api/workspace/v1/projects/$projectId/members',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  // 6. Nhóm dự án, Phân loại & Mã dự án
  Future<dynamic> getProjectGroupsRaw() async {
    final res = await _dio.get(
      '/api/workspace/v1/project-groups',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<dynamic> getProjectTypesRaw() async {
    final res = await _dio.get(
      '/api/workspace/v1/project-types',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<dynamic> getTagsRaw() async {
    final res = await _dio.get(
      '/api/workspace/v1/tags',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<dynamic> getProjectCodePreviewRaw({String? group, String? projectType}) async {
    final q = <String, dynamic>{};
    if (group != null && group.isNotEmpty) q['group'] = group;
    if (projectType != null && projectType.isNotEmpty) q['projectType'] = projectType;

    final res = await _dio.get(
      '/api/workspace/v1/project-code-preview',
      queryParameters: q.isNotEmpty ? q : null,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }
}
