import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/procedure_models.dart';
import '../../../models/workspace_models.dart';

/// Giới hạn điều kiện hoàn thành — contracts-workspace `MAX_COMPLETION_CONDITIONS`,
/// `MAX_COMPLETION_CONDITION_LENGTH`.
const int kMaxCompletionConditions = 20;
const int kMaxCompletionConditionLength = 300;

/// Port của web `completionProblem` (completion-draft.ts): lỗi cần sửa, hoặc null khi hợp lệ.
String? createItemCompletionProblem({
  required List<String> labels,
  required String rule,
  required int minRequired,
}) {
  final conditions = labels.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (conditions.isEmpty) return null;
  if (conditions.length > kMaxCompletionConditions) {
    return 'workspace.create_item.err_completion_max_count'
        .tr(args: {'max': '$kMaxCompletionConditions'});
  }
  if (conditions.any((c) => c.length > kMaxCompletionConditionLength)) {
    return 'workspace.create_item.err_completion_max_length'
        .tr(args: {'max': '$kMaxCompletionConditionLength'});
  }
  final seen = <String>{};
  for (final c in conditions) {
    if (!seen.add(c.toLowerCase())) {
      return 'workspace.create_item.err_completion_duplicate'.tr(args: {'label': c});
    }
  }
  if (rule == 'at_least' && (minRequired < 1 || minRequired > conditions.length)) {
    return 'workspace.create_item.err_completion_min'.tr(args: {'max': '${conditions.length}'});
  }
  return null;
}

/// Port của web `mergeNewProjectMembers` (project-tree.model.ts) cho trường hợp thêm
/// người ngoài dự án với vai 'member': giữ vai cũ, chỉ thêm người chưa có.
List<Map<String, String>> mergeOutsideProjectMembers(
  List<ProjectMemberItem> existing,
  List<String> addUserIds,
) {
  final byId = <String, String>{};
  for (final m in existing) {
    if (m.userId.isEmpty) continue;
    var role = m.role.toLowerCase();
    if (role == 'technician') role = 'member';
    if (role == 'pm') role = 'manager';
    byId[m.userId] = role;
  }
  for (final id in addUserIds) {
    byId.putIfAbsent(id, () => 'member');
  }
  return byId.entries.map((e) => {'userId': e.key, 'role': e.value}).toList();
}

/// Hộp xác nhận thêm người ngoài dự án (web `ConfirmBox` trong work-item-form.tsx).
Future<bool> confirmAddOutsideMembers(
  BuildContext context,
  List<WorkspaceDirectoryPerson> people,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        people.length > 1
            ? 'workspace.create_item.outside_confirm_title_many'.tr(args: {'count': '${people.length}'})
            : 'workspace.create_item.outside_confirm_title_one'.tr(),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'workspace.create_item.outside_confirm_message'.tr(),
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          ...people.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(p.displayName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      (p.positionName ?? '').isNotEmpty
                          ? p.positionName!
                          : 'workspace.create_item.no_position'.tr(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('workspace.create_item.outside_confirm_ok'.tr()),
        ),
      ],
    ),
  );
  return result == true;
}

/// Ô "Quy trình" khi chọn "Theo quy trình" (web work-item-draft.tsx).
/// [procedures] null = đang tải; rỗng = không đọc được quy trình nào.
class CreateItemProcedureField extends StatelessWidget {
  final List<ProcedureDefinition>? procedures;
  final String selectedId;
  final ValueChanged<String> onChanged;

  const CreateItemProcedureField({
    super.key,
    required this.procedures,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final list = procedures;
    Widget body;
    if (list == null) {
      body = Text('workspace.create_item.procedure_loading'.tr(),
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
    } else if (list.isEmpty) {
      body = Text('workspace.create_item.procedure_empty'.tr(),
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
    } else {
      body = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: list.any((p) => p.id == selectedId) ? selectedId : null,
            isExpanded: true,
            hint: Text('workspace.create_item.procedure_placeholder'.tr(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            items: list
                .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.code} · ${p.name}', overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (val) => onChanged(val ?? ''),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('workspace.create_item.procedure_label'.tr(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        body,
      ],
    );
  }
}

/// Thông báo "Công việc cha đã hoàn thành" kèm lựa chọn mở lại cha (web work-item-draft.tsx).
class CreateItemParentDoneNotice extends StatelessWidget {
  final bool reopenParent;
  final ValueChanged<bool> onChanged;

  const CreateItemParentDoneNotice({
    super.key,
    required this.reopenParent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text('workspace.create_item.parent_done_title'.tr(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('workspace.create_item.parent_done_hint'.tr(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: Text('workspace.create_item.parent_done_reopen'.tr(), style: const TextStyle(fontSize: 12)),
                selected: reopenParent,
                onSelected: (_) => onChanged(true),
              ),
              ChoiceChip(
                label: Text('workspace.create_item.parent_done_block'.tr(), style: const TextStyle(fontSize: 12)),
                selected: !reopenParent,
                onSelected: (_) => onChanged(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mục menu có dấu tích khi đang chọn (dùng chung cho các ô chọn của form tạo công việc).
PopupMenuItem<String> buildCheckedMenuItem(String value, String label, bool isSelected) {
  return PopupMenuItem<String>(
    value: value,
    height: 38,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        if (isSelected) const Icon(Icons.check, size: 16, color: Color(0xFF2563EB)),
      ],
    ),
  );
}

String createItemItemTypeLabel(String type) {
  switch (type) {
    case 'phase':
      return 'Nhóm công việc';
    case 'milestone':
      return 'Cột mốc';
    case 'task':
    default:
      return 'Công việc';
  }
}

String createItemExecutionMethodLabel(String method) {
  switch (method) {
    case 'procedure':
      return 'Theo quy trình';
    case 'manual':
    default:
      return 'Thủ công';
  }
}

String createItemProgressMethodLabel(String method) {
  switch (method) {
    case 'quantity':
      return 'Theo tỷ lệ hoàn thành khối lượng';
    case 'checklist':
      return 'Theo tỷ lệ hoàn thành đầu việc';
    case 'child_weight':
      return 'Theo tỷ trọng công việc con';
    case 'manual':
    default:
      return 'Theo % người dùng tự cập nhật';
  }
}

String createItemProgressMethodHint(String method) {
  switch (method) {
    case 'quantity':
      return 'Người làm báo khối lượng đã hoàn thành; tiến độ là khối lượng đã làm chia cho khối lượng cần làm.';
    case 'checklist':
      return 'Tiến độ là số đầu việc đã tích chia cho tổng số đầu việc. Đủ đầu việc thì công việc theo cài đặt báo hoàn thành.';
    case 'child_weight':
      return 'Tiến độ của việc cha là bình quân tiến độ các việc con theo tỷ trọng (hoặc chia đều).';
    case 'manual':
    default:
      return 'Người làm báo tiến độ ở thanh tiến độ. Công việc có việc con thì tự tính từ các việc con.';
  }
}

String createItemReopenPolicyLabel(String policy) {
  switch (policy) {
    case 'manager':
      return 'Chỉ quản lý dự án được hoàn tác';
    case 'none':
      return 'Không cho hoàn tác';
    case 'assignee':
    default:
      return 'Người thực hiện và quản lý được hoàn tác';
  }
}

String createItemReopenPolicyHint(String policy) {
  switch (policy) {
    case 'manager':
      return 'Sau khi hoàn thành, chỉ quản lý hoặc chủ nhiệm dự án đưa được công việc về "Đang làm".';
    case 'none':
      return '"Hoàn thành" là chốt. Chỉ chủ nhiệm dự án huỷ hiệu lực rồi lập công việc điều chỉnh được.';
    case 'assignee':
    default:
      return 'Sau khi hoàn thành, người phụ trách hoặc cùng thực hiện có thể đưa công việc về "Đang làm".';
  }
}
