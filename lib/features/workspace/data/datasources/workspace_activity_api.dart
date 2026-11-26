import 'workspace_api_base.dart';

/// Nhật ký hoạt động của cả dự án (web `listProjectActivity`: `GET /projects/:id/activity`, không phân trang,
/// xếp mới → cũ). Client tự lọc theo nhánh công việc.
class WorkspaceActivityApi extends WorkspaceApiBase {
  Future<WorkspaceApiResult<List<Map<String, dynamic>>>> listProjectActivity(String projectId) => send(
        'GET',
        '${WorkspaceApiBase.root}/projects/$projectId/activity',
        parse: WorkspaceApiBase.itemsOf,
      );
}
