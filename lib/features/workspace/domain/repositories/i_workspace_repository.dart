import '../../../../models/workspace_models.dart';
import '../models/workspace_report_models.dart';

/// Contract định nghĩa toàn bộ thao tác dữ liệu của phân hệ Workspace
/// Tuân thủ chuẩn 76 API theo tài liệu workspace-api-for-app.docx
abstract class IWorkspaceRepository {
  /// Lấy danh sách khách hàng: GET /customers
  Future<List<CustomerItem>> getCustomers({String? query});

  /// Lấy hợp đồng của khách hàng: GET /customers/{id}/contracts
  Future<List<ContractItem>> getCustomerContracts(String customerId, {Map<String, String>? projectMap});

  /// Lấy danh sách dự án (có hỗ trợ lọc & phân trang): GET /projects
  Future<List<ProjectItem>> getProjects({
    Map<String, String>? customerMap,
    String? search,
    String? status,
    String? projectType,
    String? archived,
    int? page,
    int? pageSize,
  });

  /// Lấy chi tiết dự án: GET /projects/{id}
  Future<ProjectItem?> getProjectDetail(String id, {Map<String, String>? customerMap});

  /// Tạo dự án mới: POST /projects
  Future<Map<String, dynamic>?> createProject({
    required String name,
    required String code,
    String? description,
    String? projectType,
    String? customerId,
    String? startDate,
    String? endDate,
    double? contractValue,
  });

  /// Cập nhật thông tin dự án: PATCH /projects/{id}
  Future<bool> updateProject(String id, Map<String, dynamic> data);

  /// Cập nhật trạng thái dự án: POST /projects/{id}/archive, etc.
  Future<bool> updateProjectStatus(String id, String status);

  /// Xóa / hủy dự án: DELETE /projects/{id}
  Future<bool> deleteProject(String id);

  /// Lấy tổng hợp công việc của tôi (theo dõi dự án + việc con): GET /my-work
  Future<Map<String, dynamic>> getMyWork({Map<String, String>? customerMap});

  /// Lấy cây công việc của dự án: GET /projects/{id}/work-items
  Future<List<StandaloneTaskItem>> getProjectWorkItems(String projectId);

  /// Thông điệp lỗi gần nhất (nếu có)
  String? get lastError;

  /// Tạo công việc trong dự án: POST /work-items
  Future<bool> createWorkItem({
    required String projectId,
    required String title,
    String? description,
    String priority = 'normal',
    String itemType = 'task',
    String? assigneeUserId,
    String? startDate,
    String? dueDate,
    double? estimatedHours,
    String? parentId,
    String? executionType,
    List<String>? participantUserIds,
    String? progressMethod,
    double? quantityTarget,
    String? quantityUnit,
    bool? equalChildWeight,
    List<String>? tagIds,
    List<String>? checklistTitles,
    String? procedureDefinitionId,
    Map<String, dynamic>? completion,
    String? reopenPolicy,
    /// Việc cha đã hoàn thành: mở lại cha rồi tạo (web `reopenParent`).
    bool reopenParent = false,
  });

  /// Lấy danh sách nhãn (tags): GET /tags
  Future<List<Map<String, dynamic>>> getTags();

  /// Tạo nhãn mới: POST /tags
  Future<Map<String, dynamic>?> createTag(String name);

  /// Lấy danh sách tên công việc đã dùng gần đây (gợi ý): GET /work-item-titles
  Future<List<String>> getRecentWorkItemTitles();

  /// Cập nhật trạng thái công việc dự án: PATCH /work-items/{id}/status
  Future<bool> updateWorkItemStatus(
    String workItemId,
    String status, {
    String? note,
    List<String>? confirmedConditionIds,
  });

  /// Chỉnh sửa thông tin công việc (tiêu đề, mô tả, ưu tiên, phụ trách, giờ ước lượng): PATCH /work-items/{id}
  Future<bool> updateWorkItem(String workItemId, Map<String, dynamic> data);

  /// Sửa "Công việc khác" (việc ngoài dự án); lỗi server ở [lastError].
  Future<bool> updateStandaloneTask(String taskId, Map<String, dynamic> data);

  /// Lấy cấu hình điều kiện hoàn thành của công việc: GET /work-items/{id}
  Future<WorkItemCompletionPolicy?> getWorkItemCompletionPolicy(String workItemId);

  /// Chi tiết công việc dự án: GET /work-items/{id}
  Future<Map<String, dynamic>?> getWorkItemDetail(String workItemId);

  /// Lấy chi tiết công việc thống nhất (tự động nhận diện công việc dự án hoặc việc ngoài dự án)
  Future<Map<String, dynamic>?> getUnifiedTaskDetail(
    String taskId, {
    String? projectId,
    bool isProjectTask = false,
  });

  /// Xoá công việc dự án: DELETE /work-items/{id}
  Future<bool> deleteWorkItem(String workItemId);

  /// Huỷ hiệu lực công việc dự án: POST /work-items/{id}/reverse
  Future<bool> reverseWorkItem(String workItemId, String reason);

  /// Báo cáo tiến độ công việc dự án: POST /work-items/{id}/progress-reports
  Future<bool> reportWorkItemProgress(
    String workItemId, {
    required double percent,
    double? actualHours,
    String? note,
  });

  /// Lấy danh sách checklist tiến độ của công việc: GET /work-items/{id}/checklist
  Future<List<Map<String, dynamic>>> getWorkItemChecklist(String workItemId);

  /// Thêm các mục checklist tiến độ: POST /work-items/{id}/checklist
  Future<bool> addWorkItemChecklist(String workItemId, List<String> titles);

  /// Cập nhật trạng thái mục checklist: PATCH /work-items/{id}/checklist/{itemId}
  Future<bool> updateWorkItemChecklist(String workItemId, String itemId, {String? title, bool? done});

  /// Xoá mục checklist: DELETE /work-items/{id}/checklist/{itemId}
  Future<bool> removeWorkItemChecklist(String workItemId, String itemId);

  /// Di chuyển công việc sang cha khác hoặc về gốc: POST /work-items/{id}/move
  Future<bool> moveWorkItem(String workItemId, {String? parentId});

  /// Lấy danh sách báo cáo tiến độ: GET /work-items/{id}/progress-reports
  Future<List<Map<String, dynamic>>> getWorkItemProgressReports(String workItemId);

  /// Lấy danh sách phụ thuộc: GET /work-items/{id}/dependencies
  Future<List<Map<String, dynamic>>> getWorkItemDependencies(String workItemId);

  /// Lấy danh sách việc ngoài dự án (việc giao lẻ): GET /standalone-tasks
  Future<List<StandaloneTaskItem>> getStandaloneTasks({
    String scope = 'all',
    Map<String, String>? projectMap,
  });

  /// Tạo việc ngoài dự án: POST /standalone-tasks
  Future<({bool success, String? error})> createStandaloneTask({
    required String title,
    String? description,
    String priority = 'normal',
    String? dueDate,
    String? plannedStart,
    required String assigneeUserId,
    List<String>? participantUserIds,
    List<String>? followerUserIds,
    String? executionType,
    String? procedureDefinitionId,
    String? parentId,
  });

  /// Chi tiết việc ngoài dự án: GET /standalone-tasks/{id}
  Future<Map<String, dynamic>?> getStandaloneTaskDetail(String taskId);

  /// Cập nhật trạng thái việc ngoài dự án: PATCH /standalone-tasks/{id}/status
  Future<bool> updateStandaloneTaskStatus(String taskId, String status, {String? note});

  /// Xoá việc ngoài dự án: DELETE /standalone-tasks/{id}
  Future<bool> deleteStandaloneTask(String taskId);

  /// Danh bạ tổ chức Workspace: GET /directory
  Future<WorkspaceDirectoryResponse?> getDirectory();

  /// Lấy danh sách thành viên dự án: GET /projects/{id}/members
  Future<List<ProjectMemberItem>> getProjectMembers(String projectId);

  /// Cập nhật toàn bộ danh sách thành viên: PUT /projects/{id}/members
  Future<bool> setProjectMembers(String projectId, List<Map<String, String>> members);

  /// Cập nhật toàn bộ danh sách thành viên kèm thông báo lỗi chi tiết: PUT /projects/{id}/members
  Future<({bool success, String? errorMessage})> setProjectMembersWithResult(
    String projectId,
    List<Map<String, String>> members,
  );

  /// Thêm thành viên vào dự án: POST /projects/{id}/members
  Future<bool> addProjectMember(String projectId, {required String userId, required String role});

  /// Cập nhật vai trò thành viên: PATCH /projects/{id}/members/{memberId}
  Future<bool> updateProjectMemberRole(String projectId, {required String memberId, required String role});

  /// Xoá thành viên khỏi dự án: DELETE /projects/{id}/members/{memberId}
  Future<bool> removeProjectMember(String projectId, String memberId);

  /// Tạo nhanh khách hàng mới: POST /customers
  Future<CustomerItem?> createCustomer({
    required String code,
    required String name,
    String? note,
  });

  /// Lấy danh sách nhóm dự án: GET /project-groups
  Future<List<String>> getProjectGroups();

  /// Thêm nhanh nhóm dự án mới: POST /project-groups
  Future<bool> createProjectGroup(String name, String code);

  /// Lấy danh sách phòng ban cây tổ chức
  Future<List<DepartmentItem>> getDepartments();

  /// Xem trước mã dự án được sinh tự động theo quy tắc: GET /project-code-preview
  Future<String?> getProjectCodePreview(String group);

  /// Lấy trang trao đổi của các công việc trong dự án: GET /projects/{id}/chat-feed
  Future<ProjectChatFeedPage> getProjectChatFeed(
    String projectId, {
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? onlyWithChat,
  });

  /// Lấy tin nhắn trao đổi của một công việc: GET /projects/{id}/chat-feed/{workItemId}
  Future<ProjectChatThread> getProjectChatFeedThread(
    String projectId,
    String workItemId, {
    String? before,
  });

  /// Lấy luồng tin trao đổi trực tiếp: GET /chat/{entityType}/{entityId}
  Future<ProjectChatThread> getChatThread(
    String entityType,
    String entityId, {
    String? before,
  });

  /// Gửi tin nhắn trao đổi: POST /chat/messages
  Future<bool> sendChatMessage({
    required String entityType,
    required String entityId,
    required String body,
    List<String>? mentions,
    List<String>? attachmentDocumentIds,
  });

  /// Tải gói báo cáo tổng hợp: GET /reports
  Future<ReportBundle?> getWorkspaceReports({
    String? from,
    String? to,
    List<String>? projectIds,
    List<String>? groups,
    List<String>? tagIds,
    String? userId,
  });

  /// Tải danh sách công việc chi tiết sau một con số báo cáo: GET /reports/items
  Future<ReportItemList?> getWorkspaceReportItems({
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
  });

  /// Lấy danh sách nhãn dự án: GET /tags
  Future<List<TagItem>> getWorkspaceTags();
}
