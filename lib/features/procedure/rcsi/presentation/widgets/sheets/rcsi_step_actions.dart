import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_board_helpers.dart';
import '../../../domain/logic/rcsi_board_ops.dart';
import '../../../domain/logic/rcsi_flow_edit.dart';
import '../../../domain/logic/rcsi_labels.dart';
import '../../rcsi_editor_hooks.dart';
import '../components/rcsi_common.dart';

// Thao tác luồng của một bước — tương ứng `addStep` / `renameStep` / `removeStep`,
// `onAddGateway`, `onAddBranchStep` (BranchAddRow) của `rcsi-board.tsx`. Ô nhập
// tên inline của web thành bottom sheet; tên mặc định server lưu theo câu chữ web
// (`defaultRcsiLabels`) bất kể ngôn ngữ app.

/// Hook `addStep`: [RcsiEditContext.branch] null = thêm trên trục chính, ngược lại thêm vào cuối nhánh.
Future<void> rcsiAddStepHook(BuildContext context, RcsiEditContext edit) async {
  final definition = edit.definition;
  if (definition == null || !edit.editable || edit.store.busy) return;
  final target = edit.branch;
  if (target == null) {
    final flow = flowRowInfo(definition);
    final number = definition.steps.where((step) => flow[step.id]?.branch == null).length + 1;
    final name = await _showStepNameSheet(
      context,
      title: 'procedure.rcsi.add_step.title_trunk'.tr(args: {'number': number}),
      badge: '+$number',
      placeholder: (definition.gateways?.isNotEmpty ?? false)
          ? 'procedure.rcsi.add_step.placeholder_trunk_after_branches'.tr(args: {'number': number})
          : 'procedure.rcsi.add_step.placeholder_trunk'.tr(args: {'number': number}),
      submitLabel: 'procedure.rcsi.add_step.submit_trunk'.tr(),
      allowEmpty: true,
    );
    if (name == null) return;
    final latest = edit.definition;
    if (latest == null) return;
    if (name.isEmpty) {
      await edit.store.updateDefinition(latest.id, rcsiAddStep(latest, labels: defaultRcsiLabels));
    } else {
      await edit.store.addStep(latest, name: name);
    }
    return;
  }

  final gateway = definition.gatewayById(target.gatewayId);
  final branchIndex = gateway?.branches.indexWhere((branch) => branch.id == target.branchId) ?? -1;
  if (gateway == null || branchIndex < 0) return;
  final branch = gateway.branches[branchIndex];
  final letter = branchLetters(definition)['${gateway.id}:$branchIndex'] ?? '?';
  final code = '$letter${branch.stepIds.length + 1}';
  final name = await _showStepNameSheet(
    context,
    title: 'procedure.rcsi.add_step.title_branch'.tr(args: {'code': code, 'label': branch.label}),
    badge: '+$code',
    placeholder: branch.stepIds.isEmpty
        ? 'procedure.rcsi.add_step.placeholder_branch_empty'.tr(args: {'letter': letter})
        : 'procedure.rcsi.add_step.placeholder_branch'.tr(args: {'code': code, 'label': branch.label}),
    submitLabel: 'procedure.rcsi.add_step.submit_branch'.tr(),
    allowEmpty: true,
  );
  if (name == null) return;
  final latest = edit.definition;
  if (latest == null) return;
  await edit.store.addBranchStep(
    latest,
    target,
    name.isNotEmpty ? name : RcsiLabels.fill(defaultRcsiLabels.defaultStepName, {'number': code}),
  );
}

/// Hook `renameStep`: tên rỗng hoặc không đổi thì bỏ qua (như ô đổi tên inline của web).
Future<void> rcsiRenameStepHook(BuildContext context, RcsiEditContext edit) async {
  final step = edit.step;
  if (step == null || !edit.editable || edit.store.busy) return;
  final name = await _showStepNameSheet(
    context,
    title: 'procedure.rcsi.rename_step.title'.tr(),
    placeholder: 'procedure.rcsi.rename_step.placeholder'.tr(),
    submitLabel: 'procedure.rcsi.rename_step.save'.tr(),
    initial: step.name,
  );
  if (name == null || name.isEmpty || name == step.name) return;
  final latest = edit.definition;
  if (latest == null) return;
  await edit.store.renameStep(latest, step.id, name);
}

/// Hook `removeStep`: như web — xoá ngay (dọn khỏi nhánh, điểm quay về của C, gỡ
/// gateway đặt sau bước); quy trình chỉ còn một bước thì báo lỗi.
Future<void> rcsiRemoveStepHook(BuildContext context, RcsiEditContext edit) async {
  final definition = edit.definition;
  final stepId = edit.stepId;
  if (definition == null || stepId == null || !edit.editable || edit.store.busy) return;
  await edit.store.removeStep(definition, stepId);
}

/// Hook `addGateway`: thêm điểm rẽ nhánh sau một bước trục chính chưa có rẽ nhánh.
Future<void> rcsiAddGatewayHook(BuildContext context, RcsiEditContext edit) async {
  final definition = edit.definition;
  final stepId = edit.stepId;
  if (definition == null || stepId == null || !edit.editable || edit.store.busy) return;
  final onTrunk = branchOfStep(definition, stepId) == null;
  final hasGateway = definition.gateways?.any((gateway) => gateway.afterStepId == stepId) ?? false;
  if (!onTrunk || hasGateway) return;
  await edit.store.applyFlow(definition, addGateway(definition, stepId, toStepInput, labels: defaultRcsiLabels));
}

/// Sheet nhập tên bước. Trả null khi huỷ; chuỗi đã cắt khoảng trắng (có thể rỗng khi [allowEmpty]).
Future<String?> _showStepNameSheet(
  BuildContext context, {
  required String title,
  required String placeholder,
  required String submitLabel,
  String? badge,
  String initial = '',
  bool allowEmpty = false,
}) =>
    showRcsiSheet<String>(
      context,
      (_) => _StepNameSheet(
        title: title,
        placeholder: placeholder,
        submitLabel: submitLabel,
        badge: badge,
        initial: initial,
        allowEmpty: allowEmpty,
      ),
    );

class _StepNameSheet extends StatefulWidget {
  final String title;
  final String placeholder;
  final String submitLabel;
  final String? badge;
  final String initial;
  final bool allowEmpty;

  const _StepNameSheet({
    required this.title,
    required this.placeholder,
    required this.submitLabel,
    required this.badge,
    required this.initial,
    required this.allowEmpty,
  });

  @override
  State<_StepNameSheet> createState() => _StepNameSheetState();
}

class _StepNameSheetState extends State<_StepNameSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => widget.allowEmpty || _name.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return RcsiSheetFrame(
      title: widget.title,
      footer: Row(
        children: [
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('procedure.rcsi.common.cancel'.tr()),
          ),
          const SizedBox(width: 6),
          FilledButton(onPressed: _valid ? _submit : null, child: Text(widget.submitLabel)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(
          children: [
            if (widget.badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  widget.badge!,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: TextField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.placeholder,
                  hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13.5),
                  hintMaxLines: 2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
