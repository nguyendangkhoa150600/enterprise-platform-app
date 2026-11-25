import 'workspace_api_base.dart';

/// Số liệu tiến độ của dự án mà `ProjectItem` chưa mang (web project-progress-bar.tsx).
class ProjectProgressInfo {
  final double? expectedProgressPercent;
  final String? progressMethod;

  /// Mốc tạo dự án (ISO) cho dòng "Dự án được tạo" của tab Hoạt động.
  final String? createdAt;

  const ProjectProgressInfo({this.expectedProgressPercent, this.progressMethod, this.createdAt});
}

/// Các lệnh cấp dự án của trang chi tiết dự án (web workspace-api.ts).
class WorkspaceProjectApi extends WorkspaceApiBase {
  /// GET /projects/:id — chỉ đọc tiến độ dự kiến, cách tính và ngày tạo.
  Future<WorkspaceApiResult<ProjectProgressInfo>> getProgressInfo(String projectId) {
    return send(
      'GET',
      '${WorkspaceApiBase.root}/projects/$projectId',
      parse: (data) {
        final map = data is Map ? (data['data'] is Map ? data['data'] as Map : data) : const {};
        final expected = map['expectedProgressPercent'];
        return ProjectProgressInfo(
          expectedProgressPercent: expected is num ? expected.toDouble() : double.tryParse('${expected ?? ''}'),
          progressMethod: map['progressMethod']?.toString(),
          createdAt: map['createdAt']?.toString(),
        );
      },
    );
  }

  /// PATCH /projects/:id `{status}` (web `updateProject(id, { status })`).
  Future<WorkspaceApiResult<bool>> updateStatus(String projectId, String status) {
    return send(
      'PATCH',
      '${WorkspaceApiBase.root}/projects/$projectId',
      body: {'status': status},
      parse: (_) => true,
    );
  }

  /// POST /projects/:id/unarchive (web `unarchiveProject`).
  Future<WorkspaceApiResult<bool>> unarchive(String projectId) {
    return send(
      'POST',
      '${WorkspaceApiBase.root}/projects/$projectId/unarchive',
      parse: (_) => true,
    );
  }
}
