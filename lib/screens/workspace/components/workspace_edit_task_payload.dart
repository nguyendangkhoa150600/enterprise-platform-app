import 'dart:convert';

import '../../../core/i18n/app_i18n.dart';

/// Quy tắc dựng PATCH /work-items/:id khi "Sửa công việc", bám web
/// `work-item-form.tsx` (runUpdate), `completion-draft.ts` và `progress-method-fields.tsx`.

/// `MAX_COMPLETION_CONDITIONS` / `MAX_COMPLETION_CONDITION_LENGTH` của contracts-workspace.
const int kMaxCompletionConditions = 20;
const int kMaxCompletionConditionLength = 300;

/// `DEFAULT_WORK_ITEM_REOPEN_POLICY`.
String reopenPolicyOf(String? policy) => (policy == null || policy.isEmpty) ? 'assignee' : policy;

/// Một điều kiện đang soạn; `id` có khi là điều kiện đã lưu.
class EditCompletionCondition {
  final String? id;
  final String label;
  const EditCompletionCondition({this.id, required this.label});
}

/// Bản nháp "Điều kiện hoàn thành" (web `CompletionDraft`).
class EditCompletionDraft {
  final String rule;
  final int minRequired;
  final List<EditCompletionCondition> conditions;
  const EditCompletionDraft({required this.rule, required this.minRequired, required this.conditions});

  /// Web `completionDraftOf`: bản nháp từ điều kiện đã lưu.
  factory EditCompletionDraft.fromSaved(Map<String, dynamic>? saved) {
    final raw = saved?['conditions'];
    final conditions = <EditCompletionCondition>[];
    if (raw is List) {
      for (final c in raw) {
        if (c is Map && c['label'] != null) {
          conditions.add(EditCompletionCondition(id: c['id']?.toString(), label: c['label'].toString()));
        }
      }
    }
    if (conditions.isEmpty) return const EditCompletionDraft(rule: 'all', minRequired: 1, conditions: []);
    return EditCompletionDraft(
      rule: saved?['rule']?.toString() ?? 'all',
      minRequired: int.tryParse(saved?['minRequired']?.toString() ?? '') ?? 1,
      conditions: conditions,
    );
  }

  List<EditCompletionCondition> get filled => conditions.where((c) => c.label.trim().isNotEmpty).toList();
}

int? _minOf(EditCompletionDraft draft, int total) {
  final min = draft.minRequired;
  return min >= 1 && min <= total ? min : null;
}

/// Web `completionProblem`: lỗi cần sửa trước khi lưu, hoặc null.
String? completionProblem(EditCompletionDraft draft) {
  final conditions = draft.filled;
  if (conditions.isEmpty) return null;
  if (conditions.length > kMaxCompletionConditions) {
    return 'workspace.edit_task.completion_too_many'.tr(args: {'max': kMaxCompletionConditions});
  }
  if (conditions.any((c) => c.label.trim().length > kMaxCompletionConditionLength)) {
    return 'workspace.edit_task.completion_too_long'.tr(args: {'max': kMaxCompletionConditionLength});
  }
  final seen = <String>{};
  for (final c in conditions) {
    final key = c.label.trim().toLowerCase();
    if (!seen.add(key)) return 'workspace.edit_task.completion_duplicate'.tr(args: {'label': c.label.trim()});
  }
  if (draft.rule == 'at_least' && _minOf(draft, conditions.length) == null) {
    return 'workspace.edit_task.completion_min_invalid'.tr(args: {'count': conditions.length});
  }
  return null;
}

/// Web `completionInputOf`: khối gửi lên server; null khi không có điều kiện nào.
Map<String, dynamic>? completionInputOf(EditCompletionDraft draft) {
  final conditions = draft.filled
      .map((c) => <String, dynamic>{if (c.id != null && c.id!.isNotEmpty) 'id': c.id, 'label': c.label.trim()})
      .toList();
  if (conditions.isEmpty) return null;
  if (draft.rule == 'at_least') {
    return {'rule': 'at_least', 'minRequired': _minOf(draft, conditions.length), 'conditions': conditions};
  }
  return {'rule': draft.rule, 'conditions': conditions};
}

/// Web `completionPatchOf`: `changed = false` khi không đổi (không gửi trường);
/// còn lại `value` là bản mới, hoặc null nghĩa là bỏ hết điều kiện.
({bool changed, Map<String, dynamic>? value}) completionPatchOf(
  EditCompletionDraft draft,
  Map<String, dynamic>? saved,
) {
  final next = completionInputOf(draft);
  final before = completionInputOf(EditCompletionDraft.fromSaved(saved));
  if (jsonEncode(next) == jsonEncode(before)) return (changed: false, value: null);
  return (changed: true, value: next);
}

/// Web `progressMethodProblem`.
String? progressMethodProblem(String method, String quantityTarget, String quantityUnit) {
  if (method != 'quantity') return null;
  final target = double.tryParse(quantityTarget.trim());
  if (quantityTarget.trim().isEmpty || target == null || !target.isFinite || target <= 0) {
    return 'workspace.edit_task.quantity_target_invalid'.tr();
  }
  if (quantityUnit.trim().isEmpty) return 'workspace.edit_task.quantity_unit_required'.tr();
  return null;
}

/// Giá trị gốc của công việc để so khi dựng PATCH.
class EditTaskOriginal {
  final String? progressMethod;
  final double? quantityTarget;
  final String? quantityUnit;
  final bool? equalChildWeight;
  final double? weight;
  final String? reopenPolicy;
  final Map<String, dynamic>? completion;

  /// 'COMPANY_VEHICLE' | 'EXTERNAL' | null (chưa có phương tiện).
  final String? transportMode;
  final String? transportDetail;

  const EditTaskOriginal({
    this.progressMethod,
    this.quantityTarget,
    this.quantityUnit,
    this.equalChildWeight,
    this.weight,
    this.reopenPolicy,
    this.completion,
    this.transportMode,
    this.transportDetail,
  });
}

/// Giá trị đang soạn trong form.
class EditTaskForm {
  final String title;
  final String description;
  final String priority;
  final String assigneeUserId;
  final List<String> participantUserIds;
  final List<String> tagIds;
  final String? plannedStart;
  final String? plannedEnd;
  final String estimateHours;
  final String weight;
  final String progressMethod;
  final String quantityTarget;
  final String quantityUnit;
  final EditCompletionDraft completion;
  final String reopenPolicy;

  /// '' (không cần phương tiện) | 'COMPANY_VEHICLE' | 'EXTERNAL'.
  final String transportMode;
  final String transportDetail;

  const EditTaskForm({
    required this.title,
    required this.description,
    required this.priority,
    required this.assigneeUserId,
    required this.participantUserIds,
    required this.tagIds,
    required this.plannedStart,
    required this.plannedEnd,
    required this.estimateHours,
    required this.weight,
    required this.progressMethod,
    required this.quantityTarget,
    required this.quantityUnit,
    required this.completion,
    required this.reopenPolicy,
    required this.transportMode,
    required this.transportDetail,
  });
}

/// Dựng PATCH như web `runUpdate`:
/// - trường cơ bản luôn gửi như web; `description` rỗng thì không gửi;
/// - nhóm công việc: không người phụ trách, không người cùng làm, không giờ ước lượng,
///   không điều kiện / hoàn tác / phương tiện;
/// - `weight` chỉ khi [weightApplies] (null = chưa biết cha → chỉ gửi khi người dùng đổi);
/// - cách tính tiến độ và khối lượng chỉ khi đổi;
/// - `completion`, `reopenPolicy` chỉ khi đổi và không bị khoá ([conditionsLocked]);
/// - phương tiện: không đổi thì không gửi; bỏ chọn thì `null`; ngoài thì `{mode: EXTERNAL, detail}`.
///   Xe công ty mới phải đủ xe, tài xế và giờ nên form chặn trước khi gọi hàm này.
Map<String, dynamic> buildEditTaskPatch({
  required EditTaskForm form,
  required EditTaskOriginal original,
  required bool isPhase,
  required bool conditionsLocked,
  required bool? weightApplies,
}) {
  final hours = form.estimateHours.trim().isEmpty ? null : double.tryParse(form.estimateHours.trim());
  final originalMethod = original.progressMethod ?? 'manual';
  final quantityTarget = double.tryParse(form.quantityTarget.trim());
  final progressChanged =
      form.progressMethod != originalMethod ||
      (form.progressMethod == 'quantity' &&
          (quantityTarget != original.quantityTarget || form.quantityUnit.trim() != (original.quantityUnit ?? '')));
  final weightText = form.weight.trim();
  final weight = weightText.isEmpty ? null : double.tryParse(weightText);
  final sendWeight = weightApplies ?? (weight != original.weight);
  final participants = form.participantUserIds.where((id) => id != form.assigneeUserId).toSet().toList();

  final patch = <String, dynamic>{
    'title': form.title.trim(),
    if (form.description.trim().isNotEmpty) 'description': form.description,
    'priority': form.priority,
    'assigneeUserId': isPhase ? null : (form.assigneeUserId.isNotEmpty ? form.assigneeUserId : null),
    'participantUserIds': isPhase ? <String>[] : participants,
    'tagIds': form.tagIds,
    'plannedStart': form.plannedStart,
    'plannedEnd': form.plannedEnd,
    'estimateHours': isPhase ? null : hours,
    if (sendWeight) 'weight': weight,
  };

  if (progressChanged) {
    patch['progressMethod'] = form.progressMethod;
    if (form.progressMethod == 'quantity') {
      patch['quantityTarget'] = quantityTarget;
      patch['quantityUnit'] = form.quantityUnit.trim();
    }
    if (form.progressMethod == 'child_weight') {
      patch['equalChildWeight'] = original.equalChildWeight != false;
    }
  }

  if (!isPhase) {
    final transportBefore = original.transportMode ?? '';
    final transportChanged =
        form.transportMode != transportBefore ||
        (form.transportMode == 'EXTERNAL' && form.transportDetail.trim() != (original.transportDetail ?? '').trim());
    if (transportChanged) {
      if (form.transportMode.isEmpty) {
        patch['transport'] = null;
      } else if (form.transportMode == 'EXTERNAL') {
        patch['transport'] = {'mode': 'EXTERNAL', 'detail': form.transportDetail.trim()};
      }
    }

    if (!conditionsLocked) {
      final completion = completionPatchOf(form.completion, original.completion);
      if (completion.changed) patch['completion'] = completion.value;
      if (form.reopenPolicy != reopenPolicyOf(original.reopenPolicy)) {
        patch['reopenPolicy'] = form.reopenPolicy;
      }
    }
  }
  return patch;
}

/// Web `mergeNewProjectMembers`: giữ vai người cũ, thêm người mới với vai được chọn.
List<Map<String, String>> mergeNewProjectMembers(
  List<({String userId, String role})> existing,
  List<String> addedUserIds, {
  String role = 'member',
}) {
  final byId = <String, String>{};
  for (final m in existing) {
    if (m.userId.isNotEmpty) byId[m.userId] = m.role;
  }
  for (final id in addedUserIds) {
    byId[id] = role;
  }
  return byId.entries.map((e) => {'userId': e.key, 'role': e.value}).toList();
}
