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

  Dio get dio => _dio;

  // 0. Danh bạ tổ chức Workspace: GET /api/workspace/v1/directory
  Future<dynamic> getDirectoryRaw() async {
    final res = await _dio.get(
      '/api/workspace/v1/directory',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  // Thư mục tài liệu (Folders)
  Future<dynamic> getFoldersRaw({String? projectId}) async {
    final res = await _dio.get(
      '/api/workspace/v1/folders',
      queryParameters: {
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.statusCode == 200 ? res.data : null;
  }

  Future<dynamic> createFolderRaw({
    required String name,
    String? parentId,
    String? projectId,
  }) async {
    final res = await _dio.post(
      '/api/workspace/v1/folders',
      data: {
        'name': name,
        if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.statusCode == 201 || res.statusCode == 200 ? res.data : null;
  }

  Future<({bool success, String? message})> deleteFolderRaw(String folderId) async {
    try {
      final res = await _dio.delete(
        '/api/workspace/v1/folders/$folderId',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (res.statusCode == 204 || res.statusCode == 200) {
        return (success: true, message: null);
      }
      String? msg;
      if (res.data is Map<String, dynamic>) {
        msg = res.data['message']?.toString();
      }
      return (success: false, message: msg ?? 'Không thể xoá thư mục (mã lỗi ${res.statusCode})');
    } catch (e) {
      return (success: false, message: 'Lỗi kết nối: ${e.toString()}');
    }
  }

  // Tài liệu
  Future<dynamic> getDocumentsRaw({
    String? search,
    String? projectId,
    String? folderId,
  }) async {
    final res = await _dio.get(
      '/api/workspace/v1/documents',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
        if (folderId != null && folderId.isNotEmpty) 'folderId': folderId,
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.statusCode == 200 ? res.data : null;
  }

  Future<dynamic> createDocumentRaw({
    required String folderId,
    required String name,
    required String fileName,
    required String contentType,
    required int sizeBytes,
    String? projectId,
  }) async {
    final res = await _dio.post(
      '/api/workspace/v1/documents',
      data: {
        'folderId': folderId,
        'name': name,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.statusCode == 201 || res.statusCode == 200 ? res.data : null;
  }

  Future<bool> completeDocumentUploadRaw(String documentId, String versionId, int sizeBytes) async {
    final res = await _dio.post(
      '/api/workspace/v1/documents/$documentId/versions/$versionId/complete',
      data: {'sizeBytes': sizeBytes},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  /// Quy trình 3 bước chuẩn tải tệp tài liệu (Đồng bộ 1:1 với Web React):
  /// Chặng 1: Ghi siêu dữ liệu vào cơ sở dữ liệu và nhận `uploadUrl` (Presigned URL) kèm `version`
  /// Chặng 2: Đẩy binary data trực tiếp lên kho lưu trữ (S3/MinIO) qua PUT
  /// Chặng 3: Báo máy chủ đã tải xong để chuyển trạng thái từ "Chưa tải lên xong" thành sẵn sàng
  Future<bool> uploadDocument({
    required String folderId,
    required String name,
    required String fileName,
    required String contentType,
    required List<int> bytes,
    String? projectId,
  }) async {
    // Chặng 1: Ghi siêu dữ liệu, nhận URL ký trước
    final created = await createDocumentRaw(
      folderId: folderId,
      name: name,
      fileName: fileName,
      contentType: contentType,
      sizeBytes: bytes.length,
      projectId: projectId,
    );

    if (created == null) return false;

    final data = created is Map<String, dynamic> ? (created['data'] ?? created) : null;
    if (data is! Map<String, dynamic>) return false;

    final uploadUrl = data['uploadUrl']?.toString();
    final documentId = (data['document'] is Map ? data['document']['id'] : data['id'])?.toString();
    final versionId = (data['version'] is Map
            ? data['version']['id']
            : (data['versionId'] ?? data['currentVersionId']))
        ?.toString();

    if (uploadUrl == null || uploadUrl.isEmpty || documentId == null || versionId == null) {
      return false;
    }

    // Chặng 2: PUT binary bytes thẳng lên kho lưu trữ (S3/MinIO)
    // KHÔNG đi qua API server và KHÔNG đính kèm header Authorization (URL đã ký tự mang quyền)
    final storageDio = Dio();
    final putRes = await storageDio.put(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length,
        },
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    if (putRes.statusCode != 200 && putRes.statusCode != 204) {
      return false;
    }

    // Chặng 3: Báo cho backend server đã upload xong để phiên bản thôi hiện "Chưa tải lên xong"
    return await completeDocumentUploadRaw(documentId, versionId, bytes.length);
  }

  Future<bool> deleteDocumentRaw(String documentId) async {
    final res = await _dio.delete(
      '/api/workspace/v1/documents/$documentId',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.statusCode == 200 || res.statusCode == 204;
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
    String? archived = 'exclude',
    int? page,
    int? pageSize,
  }) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status != 'ALL') query['status'] = status;
    if (projectType != null && projectType != 'ALL') query['projectType'] = projectType;
    if (archived != null && archived.isNotEmpty && archived != 'ALL') query['archived'] = archived;
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

  Future<dynamic> getWorkItemDetailRaw(String workItemId) async {
    final res = await _dio.get(
      '/api/workspace/v1/work-items/$workItemId',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<Response> updateWorkItemStatusRaw(
    String workItemId,
    String status, {
    String? note,
    List<String>? confirmedConditionIds,
  }) async {
    return await _dio.patch(
      '/api/workspace/v1/work-items/$workItemId/status',
      data: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
        if (confirmedConditionIds != null && confirmedConditionIds.isNotEmpty)
          'confirmedConditionIds': confirmedConditionIds,
      },
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

  Future<dynamic> getStandaloneTaskDetailRaw(String taskId) async {
    final res = await _dio.get(
      '/api/workspace/v1/standalone-tasks/$taskId',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<Response> updateStandaloneTaskStatusRaw(String taskId, String status, {String? note}) async {
    return await _dio.patch(
      '/api/workspace/v1/standalone-tasks/$taskId/status',
      data: {'status': status, if (note != null && note.isNotEmpty) 'note': note},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  Future<Response> deleteStandaloneTaskRaw(String taskId) async {
    return await _dio.delete(
      '/api/workspace/v1/standalone-tasks/$taskId',
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

  Future<Response> setProjectMembersRaw(String projectId, List<Map<String, String>> members) async {
    return await _dio.put(
      '/api/workspace/v1/projects/$projectId/members',
      data: {'members': members},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  Future<Response> addProjectMemberRaw(String projectId, Map<String, dynamic> data) async {
    return await _dio.post(
      '/api/workspace/v1/projects/$projectId/members',
      data: data,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  Future<Response> updateProjectMemberRoleRaw(String projectId, String memberId, String role) async {
    return await _dio.patch(
      '/api/workspace/v1/projects/$projectId/members/$memberId',
      data: {'role': role},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  Future<Response> removeProjectMemberRaw(String projectId, String memberId) async {
    return await _dio.delete(
      '/api/workspace/v1/projects/$projectId/members/$memberId',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  // 6. Nhóm dự án, Phân loại & Mã dự án
  Future<dynamic> getProjectGroupsRaw() async {
    final res = await _dio.get(
      '/api/workspace/v1/project-groups',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<Response> createProjectGroupRaw({required String name, required String code}) async {
    return await _dio.post(
      '/api/workspace/v1/project-groups',
      data: {'name': name.trim(), 'code': code.trim()},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
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

  // 7. Trao đổi công việc (Project Chat Feed)
  Future<dynamic> getProjectChatFeedRaw(
    String projectId, {
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? onlyWithChat,
  }) async {
    final q = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) q['q'] = search.trim();
    if (onlyWithChat == true) q['hasChat'] = '1';

    final res = await _dio.get(
      '/api/workspace/v1/projects/$projectId/chat-feed',
      queryParameters: q,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<dynamic> getProjectChatFeedThreadRaw(
    String projectId,
    String workItemId, {
    String? before,
  }) async {
    final q = <String, dynamic>{};
    if (before != null && before.isNotEmpty) q['before'] = before;

    final res = await _dio.get(
      '/api/workspace/v1/projects/$projectId/chat-feed/$workItemId',
      queryParameters: q.isNotEmpty ? q : null,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  // Báo cáo & Phân tích (Đồng bộ 1:1 với Web React)
  Future<dynamic> getReportsRaw({
    String? from,
    String? to,
    List<String>? projectIds,
    List<String>? groups,
    List<String>? tagIds,
    String? userId,
  }) async {
    final q = <String, dynamic>{};
    if (from != null && from.isNotEmpty) q['from'] = from;
    if (to != null && to.isNotEmpty) q['to'] = to;
    if (projectIds != null && projectIds.isNotEmpty) q['projectIds'] = projectIds.join(',');
    if (groups != null && groups.isNotEmpty) q['groups'] = groups.join(',');
    if (tagIds != null && tagIds.isNotEmpty) q['tagIds'] = tagIds.join(',');
    if (userId != null && userId.isNotEmpty) q['userId'] = userId;

    final res = await _dio.get(
      '/api/workspace/v1/reports',
      queryParameters: q.isNotEmpty ? q : null,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<dynamic> getReportItemsRaw({
    required String kind,
    String? from,
    String? to,
    List<String>? projectIds,
    List<String>? groups,
    List<String>? tagIds,
    String? userId,
    String? assigneeUserId,
    String? status,
    String? priority,
  }) async {
    final q = <String, dynamic>{'kind': kind};
    if (from != null && from.isNotEmpty) q['from'] = from;
    if (to != null && to.isNotEmpty) q['to'] = to;
    if (projectIds != null && projectIds.isNotEmpty) q['projectIds'] = projectIds.join(',');
    if (groups != null && groups.isNotEmpty) q['groups'] = groups.join(',');
    if (tagIds != null && tagIds.isNotEmpty) q['tagIds'] = tagIds.join(',');
    if (userId != null && userId.isNotEmpty) q['userId'] = userId;
    if (assigneeUserId != null && assigneeUserId.isNotEmpty) q['assigneeUserId'] = assigneeUserId;
    if (status != null && status.isNotEmpty) q['status'] = status;
    if (priority != null && priority.isNotEmpty) q['priority'] = priority;

    final res = await _dio.get(
      '/api/workspace/v1/reports/items',
      queryParameters: q,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  Future<dynamic> getWorkspaceTagsRaw() async {
    final res = await _dio.get(
      '/api/workspace/v1/tags',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }
}
