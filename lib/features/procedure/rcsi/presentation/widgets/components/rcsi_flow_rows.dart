import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_board_helpers.dart';
import '../../../domain/logic/rcsi_columns.dart';
import '../../../domain/logic/rcsi_flow_edit.dart';
import '../../../domain/rcsi_definition_models.dart';
import '../../../domain/rcsi_flow_models.dart';
import '../../rcsi_editor_hooks.dart';
import '../../state/rcsi_store.dart';
import 'rcsi_step_card.dart';

/// Các hàng luồng của một quy trình theo đúng thứ tự `DefinitionRows` (web): bước
/// → hàng thêm bước vào nhánh / nhánh rỗng → hàng điểm rẽ nhánh → … → thêm bước
/// trục chính. Lối vào trình sửa chỉ hiện khi có hook tương ứng.
List<Widget> buildRcsiFlowRows({
  required BuildContext context,
  required RcsiStore store,
  required ProcedureDefinition definition,
  required List<MatrixColumn> columns,
  required RcsiEditorHooks hooks,
}) {
  final editable = store.isEditable(definition);
  final flow = flowRowInfo(definition);
  final letters = branchLetters(definition);
  final ordered = definition.orderedSteps;
  final trunkCount = ordered.where((step) => flow[step.id]?.branch == null).length;

  RcsiEditContext edit({String? stepId, String? gatewayId, MatrixColumn? column, BranchTarget? branch}) =>
      RcsiEditContext(
        store: store,
        definitionId: definition.id,
        stepId: stepId,
        gatewayId: gatewayId,
        column: column,
        branch: branch,
        columns: columns,
      );

  VoidCallback? open(RcsiEditorHook? hook, RcsiEditContext Function() target) =>
      hook == null ? null : () => hook(context, target());

  Widget branchRow(ProcedureGatewayDefinition gateway, int branchIndex) {
    final branch = gateway.branches[branchIndex];
    final target = BranchTarget(gatewayId: gateway.id, branchId: branch.id);
    return RcsiBranchAddRow(
      letter: letters['${gateway.id}:$branchIndex'] ?? '?',
      branchIndex: branchIndex,
      label: branch.label,
      nextNumber: branch.stepIds.length + 1,
      busy: store.busy,
      onAdd: editable ? open(hooks.addStep, () => edit(branch: target)) : null,
    );
  }

  List<Widget> emptyBranchRows(ProcedureGatewayDefinition gateway, int from) => [
        for (var index = from; index < gateway.branches.length && gateway.branches[index].stepIds.isEmpty; index += 1)
          branchRow(gateway, index),
      ];

  final rows = <Widget>[];
  for (final step in ordered) {
    final info = flow[step.id];
    final gatewayAfter = info?.gatewayAfter;
    rows.add(RcsiStepCard(
      definition: definition,
      step: step,
      info: info,
      columns: columns,
      editable: editable,
      busy: store.busy,
      linkTargets: store.publishedDefinitions,
      hooks: hooks,
      onOpen: (hook, {column}) => hook(context, edit(stepId: step.id, column: column)),
    ));
    final branch = info?.branch;
    if (branch != null && branch.isLast) {
      if (editable && hooks.addStep != null) rows.add(branchRow(branch.gateway, branch.branchIndex));
      rows.addAll(emptyBranchRows(branch.gateway, branch.branchIndex + 1));
    }
    if (gatewayAfter != null) {
      rows.add(RcsiGatewayRow(
        gateway: gatewayAfter,
        definition: definition,
        editable: editable,
        busy: store.busy,
        onEdit: open(hooks.gatewayEditor, () => edit(gatewayId: gatewayAfter.id)),
      ));
      rows.addAll(emptyBranchRows(gatewayAfter, 0));
    }
  }
  if (editable && hooks.addStep != null) {
    rows.add(RcsiTrunkAddRow(
      nextNumber: trunkCount + 1,
      busy: store.busy,
      onAdd: () => hooks.addStep!(context, edit()),
    ));
  }
  return rows;
}

/// Lề trái của một hàng luồng: trục chính xám, nhánh tô màu nhánh.
class RcsiFlowGutter extends StatelessWidget {
  final Color? branchColor;
  final bool dashed;
  final bool diamond;

  const RcsiFlowGutter({super.key, this.branchColor, this.dashed = false, this.diamond = false});

  @override
  Widget build(BuildContext context) {
    final color = branchColor ?? AppColors.slate300;
    return SizedBox(
      width: 18,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                width: dashed ? 0 : 2.5,
                decoration: dashed
                    ? BoxDecoration(border: Border(left: BorderSide(color: color, width: 2)))
                    : BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: diamond
                ? Transform.rotate(
                    angle: 0.785398,
                    child: Container(width: 10, height: 10, color: AppColors.amber),
                  )
                : dashed
                    ? const SizedBox.shrink()
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: branchColor ?? AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: branchColor ?? AppColors.slate400, width: 2),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Chip chữ nhánh (A, B…) tô màu nhánh.
class RcsiBranchChip extends StatelessWidget {
  final String letter;
  final int branchIndex;

  const RcsiBranchChip({super.key, required this.letter, required this.branchIndex});

  @override
  Widget build(BuildContext context) {
    final color = Color(rcsiBranchColor(branchIndex));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(letter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// Hàng "Điểm rẽ nhánh": không có ô vai trò, chỉ tên + điều kiện + lối vào trình sửa.
class RcsiGatewayRow extends StatelessWidget {
  final ProcedureGatewayDefinition gateway;
  final ProcedureDefinition definition;
  final bool editable;
  final bool busy;
  final VoidCallback? onEdit;

  const RcsiGatewayRow({
    super.key,
    required this.gateway,
    required this.definition,
    required this.editable,
    required this.busy,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final names = <String>{};
    for (final branch in gateway.branches) {
      for (final rule in branch.condition?.rules ?? const <ProcedureConditionRule>[]) {
        final ref = rule.attribute;
        final owner = ref.isProcess ? definition.attributes : definition.stepById(ref.stepId ?? '')?.attributes;
        var name = ref.code;
        for (final attribute in owner ?? const <ProcedureAttributeDefinition>[]) {
          if (attribute.code == ref.code) name = attribute.name;
        }
        names.add(name);
      }
    }
    final summary = names.isEmpty
        ? 'procedure.rcsi.flow.no_condition'.tr()
        : 'procedure.rcsi.flow.by_attributes'.tr(args: {'names': names.join(', ')});
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RcsiFlowGutter(diamond: true),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                border: Border.all(color: AppColors.warningBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(gateway.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Text(
                          '$summary · ${'procedure.rcsi.flow.branch_count'.tr(args: {'count': gateway.branches.length})}',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    TextButton(
                      onPressed: busy ? null : onEdit,
                      child: Text(
                        editable ? 'procedure.rcsi.flow.edit_condition'.tr() : 'procedure.rcsi.flow.view_condition'.tr(),
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
}

/// Hàng cuối nhánh: thêm bước vào nhánh, hoặc ghi chú nhánh rỗng đi thẳng tới bước hợp.
class RcsiBranchAddRow extends StatelessWidget {
  final String letter;
  final int branchIndex;
  final String label;
  final int nextNumber;
  final bool busy;
  final VoidCallback? onAdd;

  const RcsiBranchAddRow({
    super.key,
    required this.letter,
    required this.branchIndex,
    required this.label,
    required this.nextNumber,
    required this.busy,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(rcsiBranchColor(branchIndex));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RcsiFlowGutter(branchColor: color, dashed: true),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Tooltip(
                    message: 'procedure.rcsi.flow.branch_title'.tr(args: {'letter': letter, 'label': label}),
                    child: RcsiBranchChip(letter: letter, branchIndex: branchIndex),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: onAdd != null
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: busy ? null : onAdd,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text('procedure.rcsi.flow.add_to_branch'.tr(
                                args: {'number': '$letter$nextNumber'},
                              )),
                            ),
                          )
                        : Text(
                            'procedure.rcsi.flow.empty_branch'.tr(),
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontStyle: FontStyle.italic),
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
}

/// Hàng "Thêm bước" trên trục chính.
class RcsiTrunkAddRow extends StatelessWidget {
  final int nextNumber;
  final bool busy;
  final VoidCallback onAdd;

  const RcsiTrunkAddRow({super.key, required this.nextNumber, required this.busy, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 18, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: busy ? null : onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text('procedure.rcsi.flow.add_step'.tr(args: {'number': nextNumber})),
        ),
      ),
    );
  }
}
