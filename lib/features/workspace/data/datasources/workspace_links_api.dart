import 'workspace_api_base.dart';

/// Danh sách hồ sơ liên kết (con trỏ sang module khác) — web `ExternalReferenceList`.
class WorkspaceLinkList {
  final List<Map<String, dynamic>> items;

  /// Không đọc được module gốc: trạng thái hiển thị là bản lưu gần nhất.
  final bool degraded;

  const WorkspaceLinkList(this.items, this.degraded);
}

/// Hồ sơ liên kết của công việc (web `listWorkItemLinks` / `unlinkWorkItem`).
class WorkspaceLinksApi extends WorkspaceApiBase {
  Future<WorkspaceApiResult<WorkspaceLinkList>> listWorkItemLinks(String workItemId) => send(
        'GET',
        '${WorkspaceApiBase.root}/work-items/$workItemId/links',
        parse: (data) => WorkspaceLinkList(
          WorkspaceApiBase.itemsOf(data),
          data is Map && data['degraded'] == true,
        ),
      );

  Future<WorkspaceApiResult<void>> unlink(String workItemId, String referenceId) => send(
        'DELETE',
        '${WorkspaceApiBase.root}/work-items/$workItemId/links/$referenceId',
        parse: (_) {},
      );
}
