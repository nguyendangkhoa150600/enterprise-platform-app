import 'workspace_api_base.dart';

/// API của hộp chi tiết công việc: đọc đúng một công việc theo loại của nó
/// (việc dự án → `/work-items`, Công việc khác → `/standalone-tasks`), không rơi sang endpoint kia.
class WorkspaceTaskDetailApi extends WorkspaceApiBase {
  static Map<String, dynamic> _map(dynamic data) {
    if (data is Map) {
      final inner = data['data'];
      return Map<String, dynamic>.from(inner is Map ? inner : data);
    }
    return const {};
  }

  /// GET /work-items/:id — một công việc của dự án (contract `WorkItem`).
  Future<WorkspaceApiResult<Map<String, dynamic>>> getWorkItem(String id) =>
      send('GET', '${WorkspaceApiBase.root}/work-items/$id', parse: _map);

  /// GET /standalone-tasks/:id — `StandaloneTaskDetail` (việc, vai của tôi, bước chuyển được phép, việc con...).
  Future<WorkspaceApiResult<Map<String, dynamic>>> getStandaloneTask(String id) =>
      send('GET', '${WorkspaceApiBase.root}/standalone-tasks/$id', parse: _map);

  /// GET /projects/:id/unread — số tin chưa đọc đã cộng dồn nhánh (`rolledUp`) của một công việc.
  Future<WorkspaceApiResult<int>> getRolledUpUnread(String projectId, String workItemId) => send(
        'GET',
        '${WorkspaceApiBase.root}/projects/$projectId/unread',
        parse: (data) {
          final rolled = _map(data)['rolledUp'];
          if (rolled is! Map) return 0;
          return int.tryParse(rolled[workItemId]?.toString() ?? '') ?? 0;
        },
      );
}
