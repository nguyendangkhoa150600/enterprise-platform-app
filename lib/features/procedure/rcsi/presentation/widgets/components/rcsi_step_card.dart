import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_board_helpers.dart';
import '../../../domain/logic/rcsi_columns.dart';
import '../../../domain/logic/rcsi_finance_step.dart';
import '../../../domain/logic/rcsi_flow_edit.dart';
import '../../../domain/rcsi_definition_models.dart';
import '../../rcsi_editor_hooks.dart';
import 'rcsi_common.dart';
import 'rcsi_flow_rows.dart';

/// Mở một trình sửa cho bước này (tuỳ chọn kèm cột).
typedef RcsiStepOpen = void Function(RcsiEditorHook hook, {MatrixColumn? column});

/// Một bước trên luồng: số hiển thị (1, A1…), tên, thẻ tóm tắt, và danh sách
/// vai trò → đối tượng theo các cột đang hiển thị (thay hàng ô của ma trận web).
class RcsiStepCard extends StatelessWidget {
  final ProcedureDefinition definition;
  final ProcedureStepDefinition step;
  final FlowRowInfo? info;
  final List<MatrixColumn> columns;
  final bool editable;
  final bool busy;
  final List<ProcedureDefinition> linkTargets;
  final RcsiEditorHooks hooks;
  final RcsiStepOpen onOpen;

  const RcsiStepCard({
    super.key,
    required this.definition,
    required this.step,
    required this.info,
    required this.columns,
    required this.editable,
    required this.busy,
    required this.linkTargets,
    required this.hooks,
    required this.onOpen,
  });

  /// Thao tác của menu bước (menu chuột phải QT-U13 của web), theo đúng điều kiện web.
  List<({String id, String label, RcsiEditorHook hook, bool enabled, bool danger})> _menuActions() {
    final approver = step.dynamicApprover;
    final isTrunk = info?.branch == null;
    return [
      if (hooks.stepConfig != null)
        (
          id: 'configure',
          label: editable ? 'procedure.rcsi.step.configure'.tr() : 'procedure.rcsi.step.view_config'.tr(),
          hook: hooks.stepConfig!,
          enabled: true,
          danger: false,
        ),
      if (editable && hooks.bulkAssign != null)
        (id: 'bulk', label: 'procedure.rcsi.step.bulk'.tr(), hook: hooks.bulkAssign!, enabled: true, danger: false),
      if (hooks.dynamicApprover != null && (editable || approver != null))
        (
          id: 'dynamic',
          label: approver != null
              ? 'procedure.rcsi.step.dynamic_with_role'.tr(args: {'role': approver.role})
              : 'procedure.rcsi.step.dynamic'.tr(),
          hook: hooks.dynamicApprover!,
          enabled: editable,
          danger: false,
        ),
      if (editable && isTrunk && info?.gatewayAfter == null && hooks.addGateway != null)
        (id: 'gateway', label: 'procedure.rcsi.step.add_gateway'.tr(), hook: hooks.addGateway!, enabled: true, danger: false),
      if (editable && hooks.renameStep != null)
        (id: 'rename', label: 'procedure.rcsi.step.rename'.tr(), hook: hooks.renameStep!, enabled: true, danger: false),
      if (editable && hooks.removeStep != null)
        (id: 'remove', label: 'procedure.rcsi.step.remove'.tr(), hook: hooks.removeStep!, enabled: true, danger: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final branch = info?.branch;
    final branchColor = branch == null ? null : Color(rcsiBranchColor(branch.branchIndex));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RcsiFlowGutter(branchColor: branchColor),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: branchColor?.withValues(alpha: 0.6) ?? AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  _tags(),
                  const SizedBox(height: 8),
                  _roles(),
                  if (editable && hooks.cellEditor != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: busy ? null : () => onOpen(hooks.cellEditor!),
                        icon: const Icon(Icons.grid_on_rounded, size: 16),
                        label: Text('procedure.rcsi.step.assign_roles'.tr()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final branch = info?.branch;
    final actions = _menuActions();
    String? linkedName;
    if (step.linkedDefinitionId != null) {
      linkedName = 'procedure.rcsi.step.linked_other'.tr();
      for (final candidate in linkTargets) {
        if (candidate.id == step.linkedDefinitionId) linkedName = candidate.name;
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (branch != null) ...[
          Tooltip(
            message: 'procedure.rcsi.flow.branch_title'.tr(args: {'letter': branch.letter, 'label': branch.branch.label}),
            child: RcsiBranchChip(letter: branch.letter, branchIndex: branch.branchIndex),
          ),
          const SizedBox(width: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(6)),
          child: Text(
            info?.label ?? '${step.order}',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.slate700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            step.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate900),
          ),
        ),
        if (linkedName != null)
          Tooltip(
            message: 'procedure.rcsi.step.linked'.tr(args: {'name': linkedName}),
            child: const Padding(
              padding: EdgeInsets.only(left: 4, top: 2),
              child: Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
            ),
          ),
        if (actions.isNotEmpty)
          SizedBox(
            height: 28,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.slate500),
              tooltip: 'procedure.rcsi.step.menu'.tr(),
              enabled: !busy,
              onSelected: (id) {
                for (final action in actions) {
                  if (action.id == id) onOpen(action.hook);
                }
              },
              itemBuilder: (_) => [
                for (final action in actions)
                  PopupMenuItem<String>(
                    value: action.id,
                    enabled: action.enabled,
                    child: Text(
                      action.label,
                      style: TextStyle(color: action.danger ? AppColors.errorFg : null),
                    ),
                  ),
              ],
            ),
          )
        else
          const SizedBox(width: 8),
      ],
    );
  }

  Widget _tags() {
    final approver = step.dynamicApprover;
    final tags = <Widget>[
      if (step.slaHours != null && step.slaHours != 0) RcsiTag('procedure.rcsi.step.sla'.tr(args: {'hours': step.slaHours})),
      if (step.attributes?.isNotEmpty ?? false)
        RcsiTag('procedure.rcsi.step.attributes'.tr(args: {'count': step.attributes!.length})),
      if (step.materials?.isNotEmpty ?? false)
        RcsiTag('procedure.rcsi.step.materials'.tr(args: {'count': step.materials!.length})),
      if (approver != null) RcsiTag('procedure.rcsi.step.dynamic_tag'.tr(args: {'role': approver.role})),
      if (step.integration?.module == 'finance')
        RcsiTag(
          'procedure.rcsi.step.finance'.tr(args: {'kind': financeVoucherKindLabelKey(step.integration!.voucherKind).tr()}),
          color: AppColors.emerald700,
          background: AppColors.emerald50,
        ),
    ];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 8),
      child: Wrap(spacing: 6, runSpacing: 4, children: tags),
    );
  }

  Widget _roles() {
    final keyById = {for (final item in definition.steps) item.id: item.key};
    final byRole = <String, List<({MatrixColumn column, ProcedureRaciAssignment assignment})>>{};
    for (final column in columns) {
      final owned = assignmentsOfColumn(step, column);
      if (owned.isEmpty) continue;
      byRole.putIfAbsent(owned.first.role, () => []).add((column: column, assignment: owned.first));
    }
    if (byRole.isEmpty) {
      return Text(
        'procedure.rcsi.step.no_roles'.tr(),
        style: const TextStyle(fontSize: 12, color: AppColors.slate400, fontStyle: FontStyle.italic),
      );
    }
    final canEditCell = editable && hooks.cellEditor != null && !busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in rcsiRoleOrder)
          if (byRole[role] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(message: rcsiRoleLabelKey(role).tr(), child: RcsiRoleBadge(role)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final entry in byRole[role]!)
                          _subjectChip(entry.column, entry.assignment, keyById, role, canEditCell),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _subjectChip(
    MatrixColumn column,
    ProcedureRaciAssignment assignment,
    Map<String, String> keyById,
    String role,
    bool canEditCell,
  ) {
    final palette = RcsiRolePalette.of(role);
    final rollbackKey = assignment.fixedRollbackStepId == null ? null : keyById[assignment.fixedRollbackStepId];
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.55),
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          text: column.label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.foreground),
          children: [
            if (rollbackKey != null)
              TextSpan(
                text: ' ↩ $rollbackKey',
                style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
    );
    if (!canEditCell) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onOpen(hooks.cellEditor!, column: column),
      child: chip,
    );
  }
}
