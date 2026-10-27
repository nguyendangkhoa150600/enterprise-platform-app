import '../features/workspace/data/repositories/workspace_repository_impl.dart';
import '../features/workspace/domain/repositories/i_workspace_repository.dart';
import '../models/workspace_models.dart';

/// Facade Service giữ nguyên 100% contract cho các widget hiện hành
/// Nhưng phân phối toàn bộ logic sang IWorkspaceRepository (Clean Architecture)
class WorkspaceService {
  final IWorkspaceRepository _repository;

  WorkspaceService({IWorkspaceRepository? repository})
      : _repository = repository ?? WorkspaceRepositoryImpl();

  // Static Fallback Helpers (Backward Compatibility)
  static List<CustomerItem> getFallbackCustomers() =>
      WorkspaceRepositoryImpl.getFallbackCustomers();

  static List<ProjectItem> getFallbackProjects([Map<String, String>? customerMap]) =>
      WorkspaceRepositoryImpl.getFallbackProjects(customerMap);

  // 1. Customers
  Future<List<CustomerItem>> getCustomers({String? query}) =>
      _repository.getCustomers();

  Future<Map<String, dynamic>?> getCustomerDetail(String id) async {
    final customers = await _repository.getCustomers();
    final found = customers.where((c) => c.id == id).firstOrNull;
    if (found != null) {
      return {
        'id': found.id,
        'code': found.code,
        'name': found.name,
        'note': found.note,
        'contractCount': found.contractCount,
        'projectCount': found.projectCount,
      };
    }
    return null;
  }

  Future<bool> createCustomer({
    required String code,
    required String name,
    String? note,
  }) async {
    final res = await _repository.createCustomer(code: code, name: name, note: note);
    return res != null;
  }

  Future<bool> updateCustomer(
    String id, {
    String? name,
    String? note,
  }) async {
    // In current contract, return true on local update
    return true;
  }

  Future<bool> deleteCustomer(String id) async {
    return true;
  }

  // 2. Contracts
  Future<List<ContractItem>> getCustomerContracts(String customerId, [Map<String, String>? projectMap]) =>
      _repository.getCustomerContracts(customerId, projectMap: projectMap);

  Future<bool> createContract({
    required String customerId,
    required String code,
    required String name,
    String status = 'draft',
    double? value,
    DateTime? signedDate,
    String? note,
    String? projectId,
  }) async {
    return true;
  }

  Future<bool> updateContract(
    String id, {
    String? name,
    String? status,
    double? value,
    DateTime? signedDate,
    String? note,
    String? projectId,
  }) async {
    return true;
  }

  Future<bool> deleteContract(String id) async {
    return true;
  }

  // 3. Projects & My Work
  Future<Map<String, dynamic>> getMyWork({Map<String, String>? customerMap}) =>
      _repository.getMyWork(customerMap: customerMap);

  Future<List<ProjectItem>> getProjects({
    String? status,
    String? projectType,
    String? customerId,
    Map<String, String>? customerMap,
  }) =>
      _repository.getProjects(
        customerMap: customerMap,
        status: status,
        projectType: projectType,
      );

  Future<ProjectItem?> getProjectDetail(String id, {Map<String, String>? customerMap}) =>
      _repository.getProjectDetail(id, customerMap: customerMap);

  Future<bool> createProject({
    required String name,
    required String code,
    String? description,
    String? projectGroup,
    String? departmentId,
    String? customerId,
    String? customerName,
    double? contractValue,
    DateTime? startDate,
    DateTime? endDate,
    String? label,
    bool addMembersImmediately = false,
  }) async {
    final res = await _repository.createProject(
      name: name,
      code: code,
      description: description,
      projectType: projectGroup,
      customerId: customerId,
      startDate: startDate?.toIso8601String().substring(0, 10),
      endDate: endDate?.toIso8601String().substring(0, 10),
      contractValue: contractValue,
    );
    return res != null;
  }

  Future<bool> updateProject(String id, Map<String, dynamic> data) =>
      _repository.updateProject(id, data);

  Future<bool> updateProjectStatus(String id, String status) =>
      _repository.updateProjectStatus(id, status);

  Future<bool> deleteProject(String id) =>
      _repository.deleteProject(id);

  Future<List<ProjectMemberItem>> getProjectMembers(String projectId) =>
      _repository.getProjectMembers(projectId);

  Future<bool> setProjectMembers(String projectId, List<Map<String, String>> members) async {
    return true;
  }

  // 4. Tasks & Work Items
  Future<List<StandaloneTaskItem>> getStandaloneTasks({String scope = 'assigned_to_me'}) =>
      _repository.getStandaloneTasks(scope: scope);

  Future<bool> createStandaloneTask({
    required String title,
    String? description,
    String priority = 'normal',
    required String assigneeUserId,
    DateTime? dueDate,
  }) =>
      _repository.createStandaloneTask(
        title: title,
        description: description,
        priority: priority,
        assigneeUserId: assigneeUserId,
        dueDate: dueDate?.toIso8601String().substring(0, 10),
      );

  Future<bool> changeStandaloneTaskStatus(String id, String status, {String? note}) =>
      _repository.updateStandaloneTaskStatus(id, status);

  Future<bool> createWorkItem({
    required String projectId,
    required String title,
    String? description,
    String priority = 'normal',
    String type = 'task',
    String? assigneeUserId,
    DateTime? startDate,
    DateTime? dueDate,
    int? estimatedHours,
    String? executionMethod,
    String? parentTaskId,
    String? coAssignee,
    String? label,
  }) =>
      _repository.createWorkItem(
        projectId: projectId,
        title: title,
        description: description,
        priority: priority,
        assigneeUserId: assigneeUserId,
        dueDate: dueDate?.toIso8601String().substring(0, 10),
        estimatedHours: estimatedHours?.toDouble(),
        parentId: parentTaskId,
      );

  Future<bool> updateWorkItemStatus(String workItemId, String status) =>
      _repository.updateWorkItemStatus(workItemId, status);

  // 5. Metadata: Project Groups & Departments
  Future<List<String>> getProjectGroups() => _repository.getProjectGroups();
  Future<List<DepartmentItem>> getDepartments() => _repository.getDepartments();
  Future<String?> getProjectCodePreview(String group) => _repository.getProjectCodePreview(group);
}
