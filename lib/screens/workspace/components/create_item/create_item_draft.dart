import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_reverse_api.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import '../workspace_create_item_helpers.dart';

/// Một công việc sẽ tạo trong form "Công việc mới", đủ mọi trường của riêng nó
/// (web `DraftRow` trong work-item-draft.tsx).
class CreateItemDraft {
  static int _lastKey = 0;

  final int key;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController estHoursCtrl;
  final TextEditingController qtyTargetCtrl;
  final TextEditingController qtyUnitCtrl;
  final TextEditingController checklistCtrl;
  final List<TextEditingController> conditionControllers;

  String priority;
  String assigneeUserId;
  DateTime? startDate;
  DateTime? dueDate;
  String itemType;
  String executionMethod;
  String progressMethod;
  bool equalChildWeight;
  final List<String> participantUserIds;
  final List<String> tagIds;
  String completionRule;
  int completionMinRequired;
  String reopenPolicy;
  String parentId;
  String parentTitle;
  bool reopenParent;
  String procedureId;

  CreateItemDraft({
    String title = '',
    String description = '',
    String estHours = '',
    String qtyTarget = '',
    String qtyUnit = '',
    String checklist = '',
    List<String> conditionLabels = const [],
    this.priority = 'normal',
    this.assigneeUserId = '',
    this.startDate,
    this.dueDate,
    this.itemType = 'task',
    this.executionMethod = 'manual',
    this.progressMethod = 'manual',
    this.equalChildWeight = true,
    List<String> participantUserIds = const [],
    List<String> tagIds = const [],
    this.completionRule = 'all',
    this.completionMinRequired = 1,
    this.reopenPolicy = 'assignee',
    this.parentId = '',
    this.parentTitle = '',
    this.reopenParent = false,
    this.procedureId = '',
  })  : key = ++_lastKey,
        titleCtrl = TextEditingController(text: title),
        descCtrl = TextEditingController(text: description),
        estHoursCtrl = TextEditingController(text: estHours),
        qtyTargetCtrl = TextEditingController(text: qtyTarget),
        qtyUnitCtrl = TextEditingController(text: qtyUnit),
        checklistCtrl = TextEditingController(text: checklist),
        conditionControllers = conditionLabels.map((l) => TextEditingController(text: l)).toList(),
        participantUserIds = [...participantUserIds],
        tagIds = [...tagIds];

  /// Web `adjustmentOf`: điều chỉnh làm lại phần việc cũ — giữ nội dung, người làm và lịch,
  /// còn cách thực hiện để thủ công (quy trình gắn công việc gốc đã huỷ).
  factory CreateItemDraft.adjustmentOf(StandaloneTaskItem item, {String parentId = '', String parentTitle = ''}) {
    final title = 'workspace.adjustment.prefill_title'.tr(args: {'code': item.code, 'title': item.title});
    final completion = item.completion;
    final labels = <String>[];
    if (completion != null && completion['conditions'] is List) {
      for (final c in completion['conditions'] as List) {
        final label = c is Map ? c['label']?.toString() : null;
        if (label != null && label.trim().isNotEmpty) labels.add(label);
      }
    }
    final rule = completion?['rule']?.toString();
    final hours = item.estimatedHours;
    return CreateItemDraft(
      title: title.length > 200 ? title.substring(0, 200) : title,
      description: item.description ?? '',
      itemType: item.meta.isMilestone ? 'milestone' : 'task',
      priority: item.priority,
      assigneeUserId: item.assigneeUserId,
      participantUserIds: item.participantUserIds,
      tagIds: item.tagIds,
      startDate: item.plannedStart,
      dueDate: item.dueDate,
      estHours: hours == null ? '' : (hours == hours.roundToDouble() ? '${hours.toInt()}' : '$hours'),
      conditionLabels: labels,
      completionRule: labels.isNotEmpty && (rule == 'any' || rule == 'at_least') ? rule! : 'all',
      completionMinRequired: int.tryParse('${completion?['minRequired'] ?? ''}') ?? 1,
      parentId: parentId,
      parentTitle: parentTitle,
    );
  }

  /// Mọi trường trừ tên — để nhân bản hay dán nhiều dòng (web `copyOf`).
  CreateItemDraft copy({String title = ''}) => CreateItemDraft(
        title: title,
        description: descCtrl.text,
        estHours: estHoursCtrl.text,
        qtyTarget: qtyTargetCtrl.text,
        qtyUnit: qtyUnitCtrl.text,
        checklist: checklistCtrl.text,
        conditionLabels: conditionControllers.map((c) => c.text).toList(),
        priority: priority,
        assigneeUserId: assigneeUserId,
        startDate: startDate,
        dueDate: dueDate,
        itemType: itemType,
        executionMethod: executionMethod,
        progressMethod: progressMethod,
        equalChildWeight: equalChildWeight,
        participantUserIds: participantUserIds,
        tagIds: tagIds,
        completionRule: completionRule,
        completionMinRequired: completionMinRequired,
        reopenPolicy: reopenPolicy,
        parentId: parentId,
        parentTitle: parentTitle,
        reopenParent: reopenParent,
        procedureId: procedureId,
      );

  /// "Thêm công việc": chép công việc cha, loại, ưu tiên, người phụ trách và ngày của việc cuối (web `addRow`).
  CreateItemDraft next() => CreateItemDraft(
        parentId: parentId,
        parentTitle: parentTitle,
        itemType: itemType,
        priority: priority,
        assigneeUserId: assigneeUserId,
        startDate: startDate,
        dueDate: dueDate,
        reopenPolicy: reopenPolicy,
        reopenParent: reopenParent,
      );

  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    estHoursCtrl.dispose();
    qtyTargetCtrl.dispose();
    qtyUnitCtrl.dispose();
    checklistCtrl.dispose();
    for (final c in conditionControllers) {
      c.dispose();
    }
  }

  bool get isPhase => itemType == 'phase';
  String get title => titleCtrl.text.trim();
  bool get filled => title.isNotEmpty;

  /// Nhóm công việc chỉ nhận `manual` / `child_weight` (web `progressOf`).
  String get effectiveProgressMethod =>
      (!isPhase || progressMethod == 'manual' || progressMethod == 'child_weight') ? progressMethod : 'manual';

  int get _minRequired => conditionControllers.isEmpty
      ? 1
      : completionMinRequired.clamp(1, conditionControllers.length);

  double? get _estHours {
    final text = estHoursCtrl.text.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  /// Lỗi cần sửa của việc này, hoặc null (thứ tự kiểm như form cũ / web `submit`).
  String? problem({required bool inProject, required bool parentDone}) {
    if (!isPhase && executionMethod == 'procedure' && procedureId.isEmpty) {
      return 'workspace.create_item.err_procedure_required'.tr();
    }
    if (!isPhase) {
      final conditionProblem = createItemCompletionProblem(
        labels: conditionControllers.map((c) => c.text).toList(),
        rule: completionRule,
        minRequired: _minRequired,
      );
      if (conditionProblem != null) return conditionProblem;
    }
    if (effectiveProgressMethod == 'quantity') {
      final target = double.tryParse(qtyTargetCtrl.text.trim());
      if (target == null || target <= 0) return 'workspace.create_item.err_quantity_target'.tr();
      if (qtyUnitCtrl.text.trim().isEmpty) return 'workspace.create_item.err_quantity_unit'.tr();
    }
    final hoursText = estHoursCtrl.text.trim();
    final hours = _estHours;
    if (!isPhase && hoursText.isNotEmpty && (hours == null || hours <= 0)) {
      return 'workspace.create_item.err_estimate_positive'.tr();
    }
    if (inProject && parentDone && !reopenParent) return 'workspace.create_item.err_parent_done'.tr();
    return null;
  }

  Map<String, dynamic>? get _completionPayload {
    final conditions = conditionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .map((label) => {'label': label})
        .toList();
    if (conditions.isEmpty) return null;
    return {
      'rule': completionRule,
      if (completionRule == 'at_least') 'minRequired': _minRequired,
      'conditions': conditions,
    };
  }

  List<String>? get _checklistTitles => (!isPhase && effectiveProgressMethod == 'checklist')
      ? checklistCtrl.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList()
      : null;

  static String? _day(DateTime? d) => d?.toIso8601String().substring(0, 10);

  /// POST /work-items cho việc này. Trả null khi thành công, lời nhắn lỗi khi thất bại.
  /// [adjustmentOfId] có thì gửi qua [reverseApi] (thêm `adjustmentOfId`), payload giữ nguyên.
  Future<String?> createInProject({
    required WorkspaceService service,
    required String projectId,
    required bool parentDone,
    String? adjustmentOfId,
    WorkspaceReverseApi? reverseApi,
  }) async {
    final progress = effectiveProgressMethod;
    final participants = participantUserIds.where((id) => id != assigneeUserId).toList();
    final description = descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null;
    final assignee = (!isPhase && assigneeUserId.isNotEmpty) ? assigneeUserId : null;
    final hours = isPhase ? null : _estHours;
    final execution = isPhase ? 'manual' : executionMethod;
    final qtyTarget = progress == 'quantity' ? double.tryParse(qtyTargetCtrl.text.trim()) : null;
    final qtyUnit = progress == 'quantity' ? qtyUnitCtrl.text.trim() : null;
    final equal = progress == 'child_weight' ? equalChildWeight : null;
    final tags = tagIds.isNotEmpty ? [...tagIds] : null;
    final procedure = (!isPhase && executionMethod == 'procedure') ? procedureId : null;
    final completion = isPhase ? null : _completionPayload;
    final reopen = isPhase ? null : reopenPolicy;
    final reopenParentFlag = parentDone && reopenParent;
    final parent = parentId.isNotEmpty ? parentId : null;

    if (adjustmentOfId != null && reverseApi != null) {
      final res = await reverseApi.createAdjustmentWorkItem(
        WorkspaceReverseApi.createPayload(
          projectId: projectId,
          title: title,
          description: description,
          priority: priority,
          itemType: itemType,
          assigneeUserId: assignee,
          startDate: _day(startDate),
          dueDate: _day(dueDate),
          estimatedHours: hours,
          parentId: parent,
          executionType: execution,
          participantUserIds: (!isPhase && participants.isNotEmpty) ? participants : null,
          progressMethod: progress,
          quantityTarget: qtyTarget,
          quantityUnit: qtyUnit,
          equalChildWeight: equal,
          tagIds: tags,
          checklistTitles: _checklistTitles,
          procedureDefinitionId: procedure,
          completion: completion,
          reopenPolicy: reopen,
          reopenParent: reopenParentFlag,
        ),
        adjustmentOfId: adjustmentOfId,
      );
      return res.ok ? null : (res.error ?? 'workspace.create_item.err_create_failed'.tr());
    }

    final ok = await service.createWorkItem(
      projectId: projectId,
      title: title,
      description: description,
      priority: priority,
      type: itemType,
      assigneeUserId: assignee,
      startDate: startDate,
      dueDate: dueDate,
      estimatedHours: hours,
      parentTaskId: parent,
      executionMethod: execution,
      participantUserIds: (!isPhase && participants.isNotEmpty) ? participants : null,
      progressMethod: progress,
      quantityTarget: qtyTarget,
      quantityUnit: qtyUnit,
      equalChildWeight: equal,
      tagIds: tags,
      checklistTitles: _checklistTitles,
      procedureDefinitionId: procedure,
      completion: completion,
      reopenPolicy: reopen,
      reopenParent: reopenParentFlag,
    );
    if (ok) return null;
    final error = service.lastError;
    return (error != null && error.isNotEmpty) ? error : 'workspace.create_item.err_create_failed'.tr();
  }

  /// Việc lẻ (không thuộc dự án): giữ đúng cách tạo một việc như trước.
  Future<String?> createStandalone({required WorkspaceService service, String? fallbackAssignee}) async {
    final res = await service.createStandaloneTask(
      title: title,
      description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
      priority: priority,
      assigneeUserId: (!isPhase && assigneeUserId.isNotEmpty) ? assigneeUserId : (fallbackAssignee ?? ''),
      dueDate: dueDate,
      plannedStart: startDate,
      participantUserIds: (!isPhase && participantUserIds.isNotEmpty) ? participantUserIds : null,
      executionType: isPhase ? 'manual' : executionMethod,
      procedureDefinitionId: (!isPhase && executionMethod == 'procedure') ? procedureId : null,
      parentId: parentId.isNotEmpty ? parentId : null,
    );
    if (res.success) return null;
    final error = res.error ?? service.lastError;
    return (error != null && error.isNotEmpty) ? error : 'workspace.create_item.err_create_failed'.tr();
  }
}
