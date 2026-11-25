import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/procedure_models.dart';
import '../../../../models/workspace_models.dart';
import '../workspace_assignee_picker.dart';
import '../workspace_create_item_helpers.dart';
import '../workspace_tag_picker.dart';
import '../workspace_task_options_card.dart';
import 'create_item_draft.dart';
import 'create_item_draft_fields.dart';
import 'create_item_form_widgets.dart';
import 'create_item_title_field.dart';

/// Dữ liệu dùng chung cho mọi dòng của form tạo nhiều việc.
class CreateItemDraftContext {
  final List<String> history;
  final List<ProjectMemberItem> members;
  final List<WorkspaceDirectoryPerson> directoryPeople;
  final Set<String> memberIds;
  final List<Map<String, dynamic>> availableTags;
  final ValueChanged<Map<String, dynamic>> onTagCreated;
  final Future<Map<String, dynamic>?> Function(String name) createTag;
  final List<ProcedureDefinition>? procedures;
  final VoidCallback ensureProcedures;
  final String Function(String userId) nameOf;
  final bool inProject;

  const CreateItemDraftContext({
    required this.history,
    required this.members,
    required this.directoryPeople,
    required this.memberIds,
    required this.availableTags,
    required this.onTagCreated,
    required this.createTag,
    required this.procedures,
    required this.ensureProcedures,
    required this.nameOf,
    required this.inProject,
  });
}

String createItemFormatDate(DateTime? dt) {
  if (dt == null) return 'dd/mm/yyyy';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

/// Một công việc trong form "Công việc mới" (web `WorkItemDraftEditor`, work-item-draft.tsx).
/// Từ hai việc trở lên ([multi]) mỗi việc là một thẻ có thanh tiêu đề (số thứ tự, tên, nút) và thu gọn được.
class CreateItemDraftEditor extends StatelessWidget {
  final CreateItemDraft draft;
  final int index;
  final bool multi;
  final bool collapsed;
  final bool parentDone;
  final String parentLabel;
  final CreateItemDraftContext ctx;
  final VoidCallback onChanged;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onDuplicate;
  final VoidCallback onRemove;
  final ValueChanged<List<String>>? onPasteLines;
  final VoidCallback onPickParent;

  const CreateItemDraftEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.multi,
    required this.collapsed,
    required this.parentDone,
    required this.parentLabel,
    required this.ctx,
    required this.onChanged,
    required this.onToggleCollapsed,
    required this.onDuplicate,
    required this.onRemove,
    required this.onPasteLines,
    required this.onPickParent,
  });

  CreateItemDraft get d => draft;

  void _set(VoidCallback change) {
    change();
    onChanged();
  }

  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final initial = isStart ? (d.startDate ?? DateTime.now()) : (d.dueDate ?? DateTime.now().add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    _set(() => isStart ? d.startDate = picked : d.dueDate = picked);
  }

  Widget _actions() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CreateItemIconButton(
            icon: Icons.copy_outlined,
            tooltip: 'workspace.create_item.duplicate'.tr(),
            color: const Color(0xFF2563EB),
            onTap: onDuplicate,
          ),
          const SizedBox(width: 6),
          CreateItemIconButton(
            icon: Icons.delete_outline,
            tooltip: 'workspace.create_item.remove_row'.tr(),
            color: const Color(0xFFDC2626),
            onTap: multi ? onRemove : null,
          ),
        ],
      );

  Widget _header() {
    final title = d.title;
    final meta = [
      d.assigneeUserId.isNotEmpty ? ctx.nameOf(d.assigneeUserId) : 'workspace.create_item.unassigned'.tr(),
      if (d.dueDate != null) 'workspace.create_item.due_on'.tr(args: {'date': createItemFormatDate(d.dueDate)}),
      'workspace.priority.${d.priority}'.tr(),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          InkWell(
            onTap: onToggleCollapsed,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(collapsed ? Icons.chevron_right : Icons.expand_more, size: 18, color: kCreateItemMuted),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: const Color(0xFFFEF3C7),
                    child: Text('${index + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: onToggleCollapsed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isNotEmpty ? title : 'workspace.create_item.untitled'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: title.isNotEmpty ? kCreateItemText : const Color(0xFF94A3B8),
                      fontStyle: title.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                  if (collapsed)
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: kCreateItemMuted)),
                ],
              ),
            ),
          ),
          _actions(),
        ],
      ),
    );
  }

  Widget _typeField() => CreateItemField(
        label: 'workspace.create_item.field_type'.tr(),
        child: PopupMenuButton<String>(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (val) => _set(() {
            d.itemType = val;
            if (val == 'phase') {
              d.assigneeUserId = '';
              d.executionMethod = 'manual';
              // Nhóm công việc chỉ nhận manual / child_weight (web progressOf).
              if (d.progressMethod != 'manual' && d.progressMethod != 'child_weight') d.progressMethod = 'manual';
            }
          }),
          itemBuilder: (_) => [
            for (final t in const ['phase', 'task', 'milestone'])
              buildCheckedMenuItem(t, createItemItemTypeLabel(t), d.itemType == t),
          ],
          child: CreateItemBox(text: createItemItemTypeLabel(d.itemType)),
        ),
      );

  Widget _executionField() => CreateItemField(
        label: 'workspace.create_item.field_execution'.tr(),
        child: d.isPhase
            ? CreateItemNone('workspace.create_item.phase_no_execution'.tr())
            : PopupMenuButton<String>(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (val) {
                  _set(() => d.executionMethod = val);
                  if (val == 'procedure') ctx.ensureProcedures();
                },
                itemBuilder: (_) => [
                  for (final m in const ['manual', 'procedure'])
                    buildCheckedMenuItem(m, createItemExecutionMethodLabel(m), d.executionMethod == m),
                ],
                child: CreateItemBox(text: createItemExecutionMethodLabel(d.executionMethod)),
              ),
      );

  Widget _body(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CreateItemLabel('workspace.create_item.field_title'.tr()),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CreateItemTitleField(
                controller: d.titleCtrl,
                history: ctx.history,
                placeholder: index == 0 && ctx.inProject ? 'workspace.create_item.title_placeholder'.tr() : null,
                onPasteLines: onPasteLines,
                onChanged: onChanged,
              ),
            ),
            if (!multi && ctx.inProject) ...[const SizedBox(width: 8), _actions()],
          ],
        ),
        gap,
        CreateItemPair(
          left: CreateItemField(
            label: 'workspace.create_item.field_assignee'.tr(),
            child: d.isPhase
                ? CreateItemNone('workspace.create_item.phase_no_assignee'.tr())
                : WorkspaceAssigneePicker(
                    selectedUserId: d.assigneeUserId,
                    members: ctx.members,
                    directoryPeople: ctx.directoryPeople,
                    onChanged: (val) => _set(() => d.assigneeUserId = val),
                  ),
          ),
          right: CreateItemField(
            label: 'workspace.create_item.field_priority'.tr(),
            child: PopupMenuButton<String>(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onSelected: (val) => _set(() => d.priority = val),
              itemBuilder: (_) => [
                for (final p in const ['urgent', 'high', 'normal', 'low'])
                  buildCheckedMenuItem(p, 'workspace.priority.$p'.tr(), d.priority == p),
              ],
              child: CreateItemBox(text: 'workspace.priority.${d.priority}'.tr()),
            ),
          ),
        ),
        gap,
        CreateItemPair(
          left: CreateItemField(
            label: 'workspace.create_item.field_start'.tr(),
            child: InkWell(
              onTap: () => _pickDate(context, isStart: true),
              child: CreateItemBox(
                text: createItemFormatDate(d.startDate),
                placeholder: d.startDate == null,
                trailing: Icons.calendar_today_outlined,
              ),
            ),
          ),
          right: CreateItemField(
            label: 'workspace.create_item.field_end'.tr(),
            child: InkWell(
              onTap: () => _pickDate(context, isStart: false),
              child: CreateItemBox(
                text: createItemFormatDate(d.dueDate),
                placeholder: d.dueDate == null,
                trailing: Icons.calendar_today_outlined,
              ),
            ),
          ),
        ),
        gap,
        CreateItemPair(
          left: _typeField(),
          right: CreateItemField(
            label: 'workspace.create_item.field_parent'.tr(),
            child: InkWell(
              onTap: onPickParent,
              child: CreateItemBox(
                text: d.parentId.isEmpty ? 'workspace.create_item.project_root'.tr() : parentLabel,
                leading: Icons.search,
              ),
            ),
          ),
        ),
        gap,
        CreateItemPair(
          left: _executionField(),
          right: CreateItemField(
            label: 'workspace.create_item.field_hours'.tr(),
            child: d.isPhase
                ? const CreateItemNone('—', italic: false)
                : TextField(
                    controller: d.estHoursCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: createItemInputDecoration(hint: '0'),
                  ),
          ),
        ),
        gap,
        CreateItemProgressFields(draft: d, onChanged: onChanged),
        gap,
        if (!d.isPhase && d.executionMethod == 'procedure') ...[
          CreateItemProcedureField(
            procedures: ctx.procedures,
            selectedId: d.procedureId,
            onChanged: (v) => _set(() => d.procedureId = v),
          ),
          gap,
        ],
        if (ctx.inProject && parentDone) ...[
          CreateItemParentDoneNotice(
            reopenParent: d.reopenParent,
            onChanged: (v) => _set(() => d.reopenParent = v),
          ),
          gap,
        ],
        if (!d.isPhase) ...[
          CreateItemLabel('workspace.create_item.field_participants'.tr()),
          CreateItemParticipantsField(draft: d, ctx: ctx, onChanged: onChanged),
          gap,
        ],
        CreateItemLabel('workspace.create_item.field_tags'.tr()),
        WorkspaceTagPicker(
          selectedTagIds: d.tagIds,
          availableTags: ctx.availableTags,
          onChanged: (ids) {
            final next = [...ids];
            _set(() => d.tagIds
              ..clear()
              ..addAll(next));
          },
          onTagCreated: ctx.onTagCreated,
          createTagAction: ctx.createTag,
        ),
        gap,
        CreateItemLabel('workspace.create_item.field_description'.tr()),
        TextField(
          controller: d.descCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: createItemInputDecoration(hint: 'workspace.create_item.description_hint'.tr()),
        ),
        if (!d.isPhase) ...[
          const SizedBox(height: 16),
          WorkspaceTaskOptionsCard(
            conditionControllers: d.conditionControllers,
            completionRule: d.completionRule,
            onCompletionRuleChanged: (val) => _set(() => d.completionRule = val),
            completionMinRequired: d.completionMinRequired,
            onCompletionMinRequiredChanged: (val) => _set(() => d.completionMinRequired = val),
            onAddCondition: () => _set(() => d.conditionControllers.add(TextEditingController())),
            onRemoveCondition: (idx) => _set(() => d.conditionControllers.removeAt(idx).dispose()),
            reopenPolicy: d.reopenPolicy,
            onReopenPolicyChanged: (val) => _set(() => d.reopenPolicy = val),
            getReopenPolicyLabel: createItemReopenPolicyLabel,
            getReopenPolicyHint: createItemReopenPolicyHint,
            buildReopenPolicyMenuItem: (value, label) => buildCheckedMenuItem(value, label, d.reopenPolicy == value),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!multi) return _body(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (!collapsed) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 14), child: _body(context)),
          ],
        ],
      ),
    );
  }
}
