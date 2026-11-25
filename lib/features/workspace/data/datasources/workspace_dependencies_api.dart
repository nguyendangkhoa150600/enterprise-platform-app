import 'workspace_api_base.dart';

/// Phụ thuộc giữa công việc (web `workspace-api.ts`: listDependencies / addDependency / removeDependency).
class WorkspaceDependenciesApi extends WorkspaceApiBase {
  /// Các cạnh mà [workItemId] là việc sau (việc phải đi trước nó).
  Future<WorkspaceApiResult<List<Map<String, dynamic>>>> list(String workItemId) => send(
        'GET',
        '${WorkspaceApiBase.root}/work-items/$workItemId/dependencies',
        parse: WorkspaceApiBase.itemsOf,
      );

  Future<WorkspaceApiResult<void>> add(
    String workItemId, {
    required String predecessorId,
    required String dependencyType,
    required int lagDays,
  }) =>
      send(
        'POST',
        '${WorkspaceApiBase.root}/work-items/$workItemId/dependencies',
        body: {'predecessorId': predecessorId, 'dependencyType': dependencyType, 'lagDays': lagDays},
        parse: (_) {},
      );

  Future<WorkspaceApiResult<void>> remove(String workItemId, String dependencyId) => send(
        'DELETE',
        '${WorkspaceApiBase.root}/work-items/$workItemId/dependencies/$dependencyId',
        parse: (_) {},
      );
}
