import '../../domain/procedure_steps_model.dart';
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

  /// Các bước hồ sơ quy trình gắn với công việc (web `getWorkItemProcedureSteps` /
  /// `getStandaloneTaskProcedureSteps`). [standalone] = công việc ngoài dự án.
  Future<WorkspaceApiResult<WorkItemProcedureSteps>> procedureSteps(String id, {bool standalone = false}) => send(
        'GET',
        '${WorkspaceApiBase.root}/${standalone ? 'standalone-tasks' : 'work-items'}/$id/procedure-steps',
        parse: (data) => WorkItemProcedureSteps.fromJson(
            data is Map ? Map<String, dynamic>.from(data['data'] is Map ? data['data'] as Map : data) : const {}),
      );

  /// Tin nhắn nằm ở node nào (web `getChatMessageLocation`), để mở đúng dự án từ thông báo nhắc tên.
  Future<WorkspaceApiResult<Map<String, dynamic>>> chatMessageLocation(String messageId) => send(
        'GET',
        '${WorkspaceApiBase.root}/chat/messages/${Uri.encodeComponent(messageId)}/location',
        parse: (data) => data is Map ? Map<String, dynamic>.from(data['data'] is Map ? data['data'] as Map : data) : {},
      );
}
