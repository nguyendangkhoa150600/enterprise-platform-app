import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/procedure_condition.dart';
import '../../../domain/logic/rcsi_labels.dart';
import '../../../domain/rcsi_definition_models.dart';
import '../../../domain/rcsi_flow_models.dart';
import '../../rcsi_editor_hooks.dart';
import '../components/rcsi_common.dart';
import '../dialogs/rcsi_confirm_dialog.dart';
import 'rcsi_condition_rule_row.dart';

/// Hook `gatewayEditor`: mở trình sửa điểm rẽ nhánh (`GatewayEditor` của web),
/// lưu qua `saveGateway` hoặc xoá qua `deleteGateway`.
Future<void> rcsiGatewayEditorHook(BuildContext context, RcsiEditContext edit) async {
  final definition = edit.definition;
  final gateway = edit.gateway;
  if (definition == null || gateway == null) return;
  final result = await showRcsiSheet<_GatewayEditorResult>(
    context,
    (_) => _GatewayEditorSheet(
      definition: definition,
      gateway: gateway,
      editable: edit.editable,
      labels: edit.store.labels,
    ),
  );
  if (result == null) return;
  final latest = edit.definition;
  if (latest == null) return;
  final next = result.gateway;
  if (next != null) {
    await edit.store.saveGateway(latest, next);
  } else {
    await edit.store.deleteGateway(latest, gateway.id);
  }
}

/// `gateway` khác null = lưu; null = xoá điểm rẽ nhánh.
class _GatewayEditorResult {
  final ProcedureGatewayDefinition? gateway;

  const _GatewayEditorResult(this.gateway);
}

/// Nhãn mặc định của nhánh mới — server lưu nguyên văn nên giữ đúng câu chữ web
/// bất kể ngôn ngữ app (như `defaultRcsiLabels`).
const String _webBranchLabel = 'Nhánh {number}';

var _localCounter = 0;

/// Id tạm của nhánh/luật mới (`localId` của web); bỏ đi khi lưu để server cấp id thật.
String _localId() {
  _localCounter += 1;
  return 'new-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-$_localCounter';
}

class _GatewayEditorSheet extends StatefulWidget {
  final ProcedureDefinition definition;
  final ProcedureGatewayDefinition gateway;
  final bool editable;
  final RcsiLabels labels;

  const _GatewayEditorSheet({
    required this.definition,
    required this.gateway,
    required this.editable,
    required this.labels,
  });

  @override
  State<_GatewayEditorSheet> createState() => _GatewayEditorSheetState();
}

class _GatewayEditorSheetState extends State<_GatewayEditorSheet> {
  late ProcedureGatewayDefinition _draft = widget.gateway;
  late final List<ConditionAttributeChoice> _choices =
      conditionAttributeChoices(widget.definition, widget.gateway.afterStepId);
  final ProcedureConditionLabels _conditionLabels = ProcedureConditionLabels.fromTranslate((key) => key.tr());

  bool get _editable => widget.editable;

  List<ProcedureBranchDefinition> get _conditional => _draft.branches.where((branch) => !branch.isDefault).toList();

  ProcedureBranchDefinition? get _fallback {
    for (final branch in _draft.branches) {
      if (branch.isDefault) return branch;
    }
    return null;
  }

  String _stepName(String id) => widget.definition.stepById(id)?.name ?? id;

  ProcedureAttributeDefinition? _definitionOf(ProcedureAttributeRef ref) {
    for (final choice in _choices) {
      if (choice.value == ref.valueKey) return choice.definition;
    }
    return null;
  }

  /// Nhánh mặc định luôn đứng cuối — nó chỉ được xét khi mọi nhánh khác trượt.
  void _setBranches(List<ProcedureBranchDefinition> branches) => setState(() {
        _draft = _draft.copyWith(branches: [
          ...branches.where((branch) => !branch.isDefault),
          ...branches.where((branch) => branch.isDefault),
        ]);
      });

  void _updateBranch(String branchId, ProcedureBranchDefinition Function(ProcedureBranchDefinition) change) =>
      _setBranches([for (final branch in _draft.branches) branch.id == branchId ? change(branch) : branch]);

  void _updateRules(String branchId, List<ProcedureConditionRule> Function(List<ProcedureConditionRule>) change) =>
      _updateBranch(
        branchId,
        (item) => item.copyWith(
          condition: ProcedureConditionGroup(
            combinator: item.condition?.combinator ?? 'and',
            rules: change(item.condition?.rules ?? const []),
          ),
        ),
      );

  void _move(String branchId, int delta) {
    final list = _conditional;
    final from = list.indexWhere((branch) => branch.id == branchId);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) return;
    final item = list.removeAt(from);
    list.insert(to, item);
    _setBranches([...list, ?_fallback]);
  }

  void _addBranch() {
    final taken = _draft.branches.map((branch) => branch.key).toSet();
    var counter = _conditional.length + 1;
    while (taken.contains('N$counter')) {
      counter += 1;
    }
    _setBranches([
      ..._conditional,
      ProcedureBranchDefinition(
        id: _localId(),
        key: 'N$counter',
        label: RcsiLabels.fill(_webBranchLabel, {'number': counter}),
        isDefault: false,
        condition: const ProcedureConditionGroup(combinator: 'and', rules: []),
      ),
      ?_fallback,
    ]);
  }

  void _addRule(String branchId) {
    if (_choices.isEmpty) return;
    final first = _choices.first;
    final operators = operatorsForType(first.definition.type);
    _updateRules(branchId, (rules) => [
          ...rules,
          ProcedureConditionRule(
            id: _localId(),
            attribute: first.ref,
            operator: operators.isEmpty ? 'not_empty' : operators.first,
          ),
        ]);
  }

  Future<void> _removeBranch(ProcedureBranchDefinition branch) async {
    final confirmed = await showRcsiConfirmDialog(
      context,
      title: 'procedure.rcsi.gateway.remove_branch_title'.tr(args: {'label': branch.label}),
      message: branch.stepIds.isNotEmpty
          ? 'procedure.rcsi.gateway.remove_branch_steps'.tr(args: {'count': branch.stepIds.length})
          : 'procedure.rcsi.gateway.remove_branch_empty'.tr(),
      confirmLabel: 'procedure.rcsi.gateway.remove'.tr(),
      danger: true,
    );
    if (!mounted || !confirmed) return;
    _setBranches(_draft.branches.where((item) => item.id != branch.id).toList());
  }

  Future<void> _removeGateway() async {
    final confirmed = await showRcsiConfirmDialog(
      context,
      title: 'procedure.rcsi.gateway.remove_gateway_title'.tr(),
      message: 'procedure.rcsi.gateway.remove_gateway_message'.tr(),
      confirmLabel: 'procedure.rcsi.gateway.remove'.tr(),
      danger: true,
    );
    if (!mounted || !confirmed) return;
    Navigator.of(context).pop(const _GatewayEditorResult(null));
  }

  void _save() {
    String stripId(String id) => id.startsWith('new-') ? '' : id;
    ProcedureConditionGroup? stripRules(ProcedureConditionGroup? group) => group?.copyWith(
          rules: [for (final rule in group.rules) rule.copyWith(id: stripId(rule.id))],
        );
    Navigator.of(context).pop(_GatewayEditorResult(_draft.copyWith(
      branches: [
        for (final branch in _draft.branches)
          branch.copyWith(id: stripId(branch.id), condition: stripRules(branch.condition)),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final overlaps = findBranchOverlaps(_draft);
    final fallback = _fallback;
    final conditional = _conditional;
    return RcsiSheetFrame(
      title: 'procedure.rcsi.gateway.title'.tr(),
      subtitle: 'procedure.rcsi.gateway.subtitle'.tr(args: {'name': _stepName(widget.gateway.afterStepId)}),
      footer: _editable ? _footer() : null,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _fieldLabel('procedure.rcsi.gateway.name_label'.tr()),
          TextFormField(
            initialValue: _draft.name,
            enabled: _editable,
            style: const TextStyle(fontSize: 14),
            decoration: _inputDecoration(),
            onChanged: (value) => setState(() => _draft = _draft.copyWith(name: value)),
          ),
          if (_choices.isEmpty) _note('procedure.rcsi.gateway.no_choices'.tr(), warning: true),
          for (final (position, branch) in conditional.indexed)
            _branchCard(branch, position, conditional.length),
          if (fallback != null) _defaultCard(fallback),
          if (_editable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addBranch,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('procedure.rcsi.gateway.add_branch'.tr()),
              ),
            ),
          for (final overlap in overlaps) _note(_overlapText(overlap), warning: true),
          _note('procedure.rcsi.gateway.hint'.tr()),
        ],
      ),
    );
  }

  String _overlapText(ProcedureBranchOverlap overlap) {
    String label(String id) {
      for (final branch in _draft.branches) {
        if (branch.id == id) return branch.label;
      }
      return '';
    }

    return (overlap.shadowed ? 'procedure.rcsi.gateway.overlap_shadowed' : 'procedure.rcsi.gateway.overlap_partial')
        .tr(args: {'branch': label(overlap.branchId), 'other': label(overlap.overlapsBranchId)});
  }

  String _stepsText(ProcedureBranchDefinition branch) => branch.stepIds.isEmpty
      ? 'procedure.rcsi.gateway.no_steps'.tr()
      : branch.stepIds.map(_stepName).join(' → ');

  Widget _branchCard(ProcedureBranchDefinition branch, int position, int count) {
    final rules = branch.condition?.rules ?? const <ProcedureConditionRule>[];
    final joiner = branch.condition?.combinator == 'or'
        ? 'procedure.rcsi.gateway.join_or'.tr()
        : 'procedure.rcsi.gateway.join_and'.tr();
    final preview = rules
        .map((rule) => describeConditionRule(rule, _definitionOf(rule.attribute), labels: _conditionLabels))
        .join(joiner);
    return _card(
      key: ValueKey('branch-${branch.id.isEmpty ? branch.key : branch.id}'),
      children: [
        Row(
          children: [
            _indexBadge('${position + 1}'),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                key: ValueKey('label-${branch.id}'),
                initialValue: branch.label,
                enabled: _editable,
                style: const TextStyle(fontSize: 14),
                decoration: _inputDecoration(hint: 'procedure.rcsi.gateway.branch_label'.tr()),
                onChanged: (value) => _updateBranch(branch.id, (item) => item.copyWith(label: value)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final value in const ['and', 'or'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(value == 'and'
                      ? 'procedure.rcsi.gateway.combinator_and'.tr()
                      : 'procedure.rcsi.gateway.combinator_or'.tr()),
                  selected: branch.condition?.combinator == value,
                  onSelected: !_editable
                      ? null
                      : (_) => _updateBranch(
                            branch.id,
                            (item) => item.copyWith(
                              condition: ProcedureConditionGroup(combinator: value, rules: item.condition?.rules ?? const []),
                            ),
                          ),
                ),
              ),
            const Spacer(),
            if (_editable) ...[
              _iconButton(Icons.arrow_upward_rounded, 'procedure.rcsi.gateway.move_up'.tr(),
                  position == 0 ? null : () => _move(branch.id, -1)),
              _iconButton(Icons.arrow_downward_rounded, 'procedure.rcsi.gateway.move_down'.tr(),
                  position == count - 1 ? null : () => _move(branch.id, 1)),
              _iconButton(Icons.delete_outline_rounded, 'procedure.rcsi.gateway.remove_branch'.tr(),
                  () => _removeBranch(branch)),
            ],
          ],
        ),
        for (final rule in rules)
          RcsiConditionRuleRow(
            key: ValueKey('rule-${rule.id}'),
            rule: rule,
            choices: _choices,
            labels: widget.labels,
            conditionLabels: _conditionLabels,
            enabled: _editable,
            onChange: (next) => _updateRules(
              branch.id,
              (list) => [for (final candidate in list) candidate.id == rule.id ? next : candidate],
            ),
            onRemove: () => _updateRules(branch.id, (list) => list.where((candidate) => candidate.id != rule.id).toList()),
          ),
        if (_editable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _choices.isEmpty ? null : () => _addRule(branch.id),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('procedure.rcsi.gateway.add_rule'.tr()),
            ),
          ),
        _previewText(preview.isEmpty ? 'procedure.rcsi.gateway.no_rule'.tr() : preview),
        _stepsLine(_stepsText(branch)),
      ],
    );
  }

  Widget _defaultCard(ProcedureBranchDefinition fallback) => _card(
        key: ValueKey('branch-default-${fallback.id}'),
        background: AppColors.slate50,
        children: [
          Row(
            children: [
              _indexBadge('—'),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: ValueKey('label-${fallback.id}'),
                  initialValue: fallback.label,
                  enabled: _editable,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(hint: 'procedure.rcsi.gateway.default_branch_label'.tr()),
                  onChanged: (value) => _updateBranch(fallback.id, (item) => item.copyWith(label: value)),
                ),
              ),
              const SizedBox(width: 8),
              RcsiTag('procedure.rcsi.gateway.default_tag'.tr()),
            ],
          ),
          const SizedBox(height: 8),
          _previewText('procedure.rcsi.gateway.default_preview'.tr()),
          _stepsLine(_stepsText(fallback)),
        ],
      );

  Widget _footer() => Row(
        children: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.errorFg),
            onPressed: _removeGateway,
            child: Text('procedure.rcsi.gateway.remove_gateway'.tr()),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('procedure.rcsi.common.cancel'.tr()),
          ),
          const SizedBox(width: 6),
          FilledButton(onPressed: _save, child: Text('procedure.rcsi.gateway.save'.tr())),
        ],
      );

  // ---------------------------------------------------------------- khối nhỏ

  Widget _card({required Key key, required List<Widget> children, Color background = AppColors.surface}) => Container(
        key: key,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _indexBadge(String text) => Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(13)),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
      );

  Widget _iconButton(IconData icon, String tooltip, VoidCallback? onPressed) => IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        icon: Icon(icon, size: 19),
        color: AppColors.slate600,
        onPressed: onPressed,
      );

  Widget _previewText(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.slate700, fontStyle: FontStyle.italic)),
      );

  Widget _stepsLine(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700)),
      );

  Widget _note(String text, {bool warning = false}) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: warning ? AppColors.warningBg : AppColors.slate50,
          border: Border.all(color: warning ? AppColors.warningBorder : AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12.5, color: warning ? AppColors.warningFg : AppColors.slate600),
        ),
      );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.slate400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );
}
