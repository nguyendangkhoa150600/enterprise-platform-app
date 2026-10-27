import '../../../../models/workspace_models.dart';

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

  /// Tạo công việc trong dự án: POST /work-items
  Future<bool> createWorkItem({
    required String projectId,
    required String title,
    String? description,
    String priority = 'normal',
    String? assigneeUserId,
    String? dueDate,
    double? estimatedHours,
    String? parentId,
  });

  /// Cập nhật trạng thái công việc dự án: PATCH /work-items/{id}/status
  Future<bool> updateWorkItemStatus(String workItemId, String status);

  /// Lấy danh sách việc ngoài dự án (việc giao lẻ): GET /standalone-tasks
  Future<List<StandaloneTaskItem>> getStandaloneTasks({
    String scope = 'all',
    Map<String, String>? projectMap,
  });

  /// Tạo việc ngoài dự án: POST /standalone-tasks
  Future<bool> createStandaloneTask({
    required String title,
    String? description,
    String priority = 'normal',
    String? dueDate,
    String? assigneeUserId,
  });

  /// Cập nhật trạng thái việc ngoài dự án: PATCH /standalone-tasks/{id}/status
  Future<bool> updateStandaloneTaskStatus(String taskId, String status);

  /// Lấy danh sách thành viên dự án: GET /projects/{id}/members
  Future<List<ProjectMemberItem>> getProjectMembers(String projectId);

  /// Tạo nhanh khách hàng mới: POST /customers
  Future<CustomerItem?> createCustomer({
    required String code,
    required String name,
    String? note,
  });

  /// Lấy danh sách nhóm dự án: GET /project-groups
  Future<List<String>> getProjectGroups();

  /// Lấy danh sách phòng ban cây tổ chức
  Future<List<DepartmentItem>> getDepartments();

  /// Xem trước mã dự án được sinh tự động theo quy tắc: GET /project-code-preview
  Future<String?> getProjectCodePreview(String group);
}
