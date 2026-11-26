import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_board_ops.dart';
import '../../../domain/logic/rcsi_finance_step.dart';
import '../../../domain/logic/rcsi_flow_edit.dart';
import '../../../domain/rcsi_definition_models.dart';
import '../../../domain/rcsi_flow_models.dart';
import '../../rcsi_editor_hooks.dart';
import '../../rcsi_editor_registry.dart';
import '../components/rcsi_common.dart';
import '../dialogs/rcsi_confirm_dialog.dart';
import 'rcsi_finance_step_section.dart';
import 'rcsi_option_picker_sheet.dart';

/// Hook `stepConfig` — "Cấu hình bước" (web `StepConfigDialog` + `saveStepConfig` của
/// `rcsi-board.tsx`): SLA, quy trình nối tiếp, nhánh chứa bước, lối vào thuộc tính
/// và bước Tài chính. Chỉ xem khi không sửa được (không có quyền / không phải bản nháp).
Future<void> rcsiStepConfigHook(BuildContext context, RcsiEditContext edit) async {
  final definition = edit.definition;
  final step = edit.step;
  if (definition == null || step == null) return;
  final readOnly = !edit.editable;
  final store = edit.store;

  final result = await showModalBottomSheet<_StepConfigResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Vuốt xuống đóng thẳng route (bỏ qua PopScope) nên chỉ cho vuốt khi chỉ xem.
    enableDrag: readOnly,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => _StepConfigSheet(
      definition: definition,
      step: step,
      // Chỉ quy trình đã công bố mới mở hồ sơ được, nên chỉ chúng làm đích nối tiếp.
      linkTargets: store.publishedDefinitions,
      allDefinitions: store.definitions,
      candidates: financeAttributeCandidates(definition, step.id, store.labels),
      readOnly: readOnly,
      canOpenAttributes: rcsiEditorHooks.attributeEditor != null,
    ),
  );
  if (result == null || !context.mounted) return;

  final change = result.change;
  if (change != null) {
    if (readOnly) return;
    // Đọc lại quy trình mới nhất trước khi ghi (store có thể vừa nạp lại nền).
    final latest = edit.definition;
    if (latest == null || latest.stepById(step.id) == null) return;
    await store.saveStepConfig(latest, step.id, change);
    return;
  }
  if (result.openAttributes) {
    final attributeEditor = rcsiEditorHooks.attributeEditor;
    if (attributeEditor == null) return;
    await attributeEditor(
      context,
      RcsiEditContext(store: store, definitionId: definition.id, stepId: step.id, columns: edit.columns),
    );
  }
}

class _StepConfigResult {
  final StepConfigChange? change;
  final bool openAttributes;

  const _StepConfigResult.save(StepConfigChange this.change) : openAttributes = false;
  const _StepConfigResult.attributes()
      : change = null,
        openAttributes = true;
}

/// Giá trị "Trục chính" của ô chọn nhánh (web `TRUNK`).
const String _trunk = '__trunk__';

String _branchValue(BranchTarget? target) => target == null ? _trunk : '${target.gatewayId}:${target.branchId}';

class _BranchOption {
  final String value;
  final String label;
  final String? description;
  final bool disabled;

  const _BranchOption(this.value, this.label, {this.description, this.disabled = false});
}

class _StepConfigSheet extends StatefulWidget {
  final ProcedureDefinition definition;
  final ProcedureStepDefinition step;
  final List<ProcedureDefinition> linkTargets;
  final List<ProcedureDefinition> allDefinitions;
  final List<FinanceAttributeCandidate> candidates;
  final bool readOnly;
  final bool canOpenAttributes;

  const _StepConfigSheet({
    required this.definition,
    required this.step,
    required this.linkTargets,
    required this.allDefinitions,
    required this.candidates,
    required this.readOnly,
    required this.canOpenAttributes,
  });

  @override
  State<_StepConfigSheet> createState() => _StepConfigSheetState();
}

class _StepConfigSheetState extends State<_StepConfigSheet> {
  late final TextEditingController _sla;
  late String _link;
  late String _branch;
  late final String _initialSla;
  late final String _initialLink;
  late final String _initialBranch;
  late final String _initialFinance;
  ProcedureStepIntegration? _finance;
  String? _error;

  /// Đang đóng theo ý người dùng (đã lưu / đã xác nhận bỏ thay đổi) → không hỏi lại.
  bool _closing = false;

  ProcedureDefinition get _definition => widget.definition;
  ProcedureStepDefinition get _step => widget.step;
  List<ProcedureGatewayDefinition> get _gateways => _definition.gateways ?? const [];

  @override
  void initState() {
    super.initState();
    final slaHours = _step.slaHours;
    _initialSla = slaHours != null && slaHours != 0 ? '$slaHours' : '';
    _sla = TextEditingController(text: _initialSla)..addListener(_onSlaChanged);
    _link = _initialLink = _step.linkedDefinitionId ?? '';
    _branch = _initialBranch = _branchValue(branchOfStep(_definition, _step.id));
    _finance = _step.integration;
    _initialFinance = _financeSignature(_finance);
  }

  @override
  void dispose() {
    _sla.dispose();
    super.dispose();
  }

  void _onSlaChanged() => setState(() {});

  static String _financeSignature(ProcedureStepIntegration? finance) {
    if (finance == null) return '';
    final clean = cleanIntegration(finance);
    final mapping = (clean.mapping?.entries.toList() ?? <MapEntry<String, String>>[])
      ..sort((left, right) => left.key.compareTo(right.key));
    return jsonEncode([
      clean.voucherKind,
      clean.returnToStepId,
      [for (final entry in mapping) '${entry.key}=${entry.value}'],
    ]);
  }

  bool get _dirty =>
      !widget.readOnly &&
      (_sla.text != _initialSla ||
          _link != _initialLink ||
          _branch != _initialBranch ||
          _financeSignature(_finance) != _initialFinance);

  /// Bước có điểm rẽ nhánh đứng sau thì không đưa vào nhánh được (rẽ nhánh lồng nhau).
  bool get _hasGatewayAfter => _gateways.any((gateway) => gateway.afterStepId == _step.id);

  List<_BranchOption> get _branchOptions {
    String stepName(String id) => _definition.stepById(id)?.name ?? '';
    final nested = _hasGatewayAfter;
    return [
      _BranchOption(_trunk, 'procedure.rcsi.step_config.branch_trunk'.tr()),
      for (final gateway in _gateways)
        for (final item in gateway.branches)
          _BranchOption(
            '${gateway.id}:${item.id}',
            item.label,
            description: 'procedure.rcsi.step_config.branch_option_desc'
                .tr(args: {'gateway': gateway.name, 'step': stepName(gateway.afterStepId)}),
            disabled: nested || gateway.afterStepId == _step.id,
          ),
    ];
  }

  // ---------------------------------------------------------------- Đóng / lưu

  Future<bool> _confirmDiscard() => showRcsiConfirmDialog(
        context,
        title: 'procedure.rcsi.step_config.discard_title'.tr(),
        message: 'procedure.rcsi.step_config.discard_message'.tr(),
        confirmLabel: 'procedure.rcsi.step_config.discard_confirm'.tr(),
        cancelLabel: 'procedure.rcsi.step_config.discard_keep'.tr(),
        danger: true,
      );

  void _close([_StepConfigResult? result]) {
    _closing = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _onPopBlocked() async {
    if (!await _confirmDiscard()) return;
    if (!mounted) return;
    _close();
  }

  Future<void> _openAttributes() async {
    if (_dirty) {
      if (!await _confirmDiscard()) return;
      if (!mounted) return;
    }
    _close(const _StepConfigResult.attributes());
  }

  void _save() {
    final trimmed = _sla.text.trim();
    int? slaHours;
    if (trimmed.isNotEmpty) {
      slaHours = int.tryParse(trimmed);
      if (slaHours == null || slaHours < 1 || slaHours > 8760) {
        setState(() => _error = 'procedure.rcsi.step_config.sla_error'.tr());
        return;
      }
    }
    final changeBranch = _branch != _initialBranch;
    BranchTarget? nextBranch;
    if (changeBranch && _branch != _trunk) {
      final separator = _branch.indexOf(':');
      nextBranch = BranchTarget(
        gatewayId: separator < 0 ? _branch : _branch.substring(0, separator),
        branchId: separator < 0 ? '' : _branch.substring(separator + 1),
      );
    }
    final finance = _finance;
    _close(_StepConfigResult.save(StepConfigChange(
      slaHours: slaHours,
      linkedDefinitionId: _link.isEmpty ? null : _link,
      integration: finance == null ? null : cleanIntegration(finance),
      changeBranch: changeBranch,
      branch: nextBranch,
    )));
  }

  // ---------------------------------------------------------------- Chọn

  Future<void> _pickLink() async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.step_config.link_label'.tr(),
      selected: _link,
      options: [
        RcsiOption('', 'procedure.rcsi.step_config.link_none'.tr()),
        for (final candidate in widget.linkTargets)
          if (candidate.id != _definition.id) RcsiOption(candidate.id, candidate.name, subtitle: candidate.code),
      ],
    );
    if (!mounted || picked == null) return;
    setState(() => _link = picked.value);
  }

  ProcedureDefinition? _definitionNamed(String id) {
    for (final item in widget.linkTargets) {
      if (item.id == id) return item;
    }
    for (final item in widget.allDefinitions) {
      if (item.id == id) return item;
    }
    return null;
  }

  // ---------------------------------------------------------------- Giao diện

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.readOnly;
    final linked = _link.isEmpty ? null : _definitionNamed(_link);
    final attributeCount = _step.attributes?.length ?? 0;
    return PopScope<Object?>(
      canPop: _closing || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onPopBlocked();
      },
      child: RcsiSheetFrame(
        title: 'procedure.rcsi.step_config.title'.tr(args: {'name': _step.name}),
        subtitle: 'procedure.rcsi.step_config.subtitle'.tr(),
        footer: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(readOnly ? 'procedure.rcsi.common.close'.tr() : 'procedure.rcsi.common.cancel'.tr()),
              ),
            ),
            if (!readOnly) ...[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text('procedure.rcsi.step_config.save'.tr()),
                ),
              ),
            ],
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('procedure.rcsi.step_config.sla_label'.tr()),
              TextField(
                controller: _sla,
                enabled: !readOnly,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'procedure.rcsi.step_config.sla_hint'.tr(),
                  hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              _label('procedure.rcsi.step_config.link_label'.tr()),
              RcsiConfigSelectField(
                value: _link.isEmpty ? 'procedure.rcsi.step_config.link_none'.tr() : (linked?.name ?? _link),
                description: linked?.code,
                placeholder: _link.isEmpty,
                onTap: readOnly ? null : _pickLink,
              ),
              _hint('procedure.rcsi.step_config.link_hint'.tr()),
              if (_gateways.isNotEmpty) ...[
                const SizedBox(height: 16),
                _label('procedure.rcsi.step_config.branch_label'.tr()),
                _BranchChooser(
                  options: _branchOptions,
                  value: _branch,
                  readOnly: readOnly,
                  onChanged: (value) => setState(() => _branch = value),
                ),
                _hint(_hasGatewayAfter
                    ? 'procedure.rcsi.step_config.branch_hint_nested'.tr()
                    : 'procedure.rcsi.step_config.branch_hint'.tr()),
              ],
              if (widget.canOpenAttributes) ...[
                const SizedBox(height: 16),
                _label('procedure.rcsi.step_config.attributes_label'.tr()),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                    onPressed: _openAttributes,
                    icon: const Icon(Icons.checklist_rounded, size: 16),
                    label: Text(
                      attributeCount > 0
                          ? 'procedure.rcsi.step_config.attributes_count'.tr(args: {'count': attributeCount})
                          : 'procedure.rcsi.step_config.attributes_declare'.tr(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              RcsiFinanceStepSection(
                definition: _definition,
                step: _step,
                finance: _finance,
                candidates: widget.candidates,
                readOnly: readOnly,
                onChanged: (value) => setState(() => _finance = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.errorFg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700)),
    );

Widget _hint(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
    );

/// Danh sách chọn nhánh (web `SearchableSelect` không xoá được, có mục bị khoá).
class _BranchChooser extends StatelessWidget {
  final List<_BranchOption> options;
  final String value;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  const _BranchChooser({required this.options, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: AppColors.slate100),
            _tile(options[index]),
          ],
        ],
      ),
    );
  }

  Widget _tile(_BranchOption option) {
    final selected = option.value == value;
    final enabled = !readOnly && !option.disabled;
    return InkWell(
      onTap: enabled && !selected ? () => onChanged(option.value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.primary : (enabled ? AppColors.slate400 : AppColors.slate300),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: option.disabled ? AppColors.slate400 : AppColors.slate800,
                    ),
                  ),
                  if (option.description != null)
                    Text(
                      option.description!,
                      style: TextStyle(fontSize: 12, color: option.disabled ? AppColors.slate300 : AppColors.slate500),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
