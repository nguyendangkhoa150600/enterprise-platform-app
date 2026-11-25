import 'workspace_api_base.dart';

/// Huỷ hiệu lực công việc và lập công việc điều chỉnh — web `workspace-api.ts`
/// (`reverseWorkItem`, `createWorkItem` có `adjustmentOfId`, `listProjectDependencies`,
/// `listProjectExternalReferences`).
class WorkspaceReverseApi extends WorkspaceApiBase {
  static const int reasonMinLength = 3;
  static const int reasonMaxLength = 1000;

  /// POST /work-items/:id/reverse `{reason, createAdjustment}`.
  Future<WorkspaceApiResult<Map<String, dynamic>>> reverseWorkItem(
    String id, {
    required String reason,
    required bool createAdjustment,
  }) =>
      send(
        'POST',
        '${WorkspaceApiBase.root}/work-items/$id/reverse',
        body: {'reason': reason, 'createAdjustment': createAdjustment},
        parse: (data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
      );

  /// GET /projects/:id/dependencies → các cạnh phụ thuộc của cả dự án.
  Future<WorkspaceApiResult<List<Map<String, dynamic>>>> projectDependencies(String projectId) => send(
        'GET',
        '${WorkspaceApiBase.root}/projects/$projectId/dependencies',
        parse: WorkspaceApiBase.itemsOf,
      );

  /// GET /projects/:id/external-references → con trỏ sang module khác (hồ sơ Quy trình...).
  Future<WorkspaceApiResult<List<Map<String, dynamic>>>> projectExternalReferences(String projectId) => send(
        'GET',
        '${WorkspaceApiBase.root}/projects/$projectId/external-references',
        parse: WorkspaceApiBase.itemsOf,
      );

  /// POST /work-items cho công việc điều chỉnh: payload y như tạo thường, thêm `adjustmentOfId`.
  Future<WorkspaceApiResult<Map<String, dynamic>>> createAdjustmentWorkItem(
    Map<String, dynamic> payload, {
    required String adjustmentOfId,
  }) =>
      send(
        'POST',
        '${WorkspaceApiBase.root}/work-items',
        body: {...payload, 'adjustmentOfId': adjustmentOfId},
        parse: (data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
      );

  /// Payload POST /work-items — cùng quy tắc với `WorkspaceRepositoryImpl.createWorkItem`
  /// để công việc điều chỉnh gửi đúng như tạo thường.
  static Map<String, dynamic> createPayload({
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
    bool reopenParent = false,
  }) {
    final payload = <String, dynamic>{
      'projectId': projectId,
      'title': title.trim(),
      'priority': priority,
      'itemType': itemType,
    };
    if (description != null && description.trim().isNotEmpty) payload['description'] = description.trim();
    if (assigneeUserId != null && assigneeUserId.isNotEmpty) payload['assigneeUserId'] = assigneeUserId;
    if (participantUserIds != null && participantUserIds.isNotEmpty) {
      payload['participantUserIds'] = participantUserIds;
    }
    if (executionType != null && executionType.isNotEmpty) payload['executionType'] = executionType;
    if (progressMethod != null && progressMethod.isNotEmpty) payload['progressMethod'] = progressMethod;
    if (quantityTarget != null && quantityTarget > 0) payload['quantityTarget'] = quantityTarget;
    if (quantityUnit != null && quantityUnit.trim().isNotEmpty) payload['quantityUnit'] = quantityUnit.trim();
    if (equalChildWeight != null) payload['equalChildWeight'] = equalChildWeight;
    if (tagIds != null && tagIds.isNotEmpty) payload['tagIds'] = tagIds;
    if (checklistTitles != null && checklistTitles.isNotEmpty) payload['checklistTitles'] = checklistTitles;
    if (procedureDefinitionId != null && procedureDefinitionId.isNotEmpty) {
      payload['procedureDefinitionId'] = procedureDefinitionId;
    }
    if (completion != null) payload['completion'] = completion;
    if (reopenPolicy != null && reopenPolicy.isNotEmpty) payload['reopenPolicy'] = reopenPolicy;
    if (reopenParent) payload['reopenParent'] = true;
    if (startDate != null && startDate.isNotEmpty) payload['plannedStart'] = startDate;
    if (dueDate != null && dueDate.isNotEmpty) {
      payload['dueDate'] = dueDate;
      payload['plannedEnd'] = dueDate;
    }
    if (itemType == 'phase') {
      payload.remove('assigneeUserId');
      payload.remove('participantUserIds');
      payload.remove('completion');
      payload.remove('reopenPolicy');
      payload['executionType'] = 'manual';
    } else if (estimatedHours != null && estimatedHours > 0) {
      payload['estimatedHours'] = estimatedHours;
      payload['estimateHours'] = estimatedHours;
    }
    if (parentId != null && parentId.isNotEmpty) {
      payload['parentId'] = parentId;
      payload['parentTaskId'] = parentId;
    }
    return payload;
  }
}
