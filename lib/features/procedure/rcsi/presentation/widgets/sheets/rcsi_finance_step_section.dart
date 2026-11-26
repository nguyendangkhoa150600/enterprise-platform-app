import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_finance_step.dart';
import '../../../domain/rcsi_definition_models.dart';
import 'rcsi_option_picker_sheet.dart';

/// Vai được phép ở bước Tài chính: không có pha nào cần người bấm hoàn thành.
const Set<String> _financeAllowedRoles = {'R', 'I'};

/// Giá trị của ô ánh xạ khi để server tự khớp theo mã chuẩn (web `AUTO`).
const String _auto = '';

/// Vai đang gán ở bước mà bước Tài chính không cho phép (giữ thứ tự xuất hiện như web).
List<String> rcsiFinanceExtraRoles(ProcedureStepDefinition step) {
  final seen = <String>{};
  return [
    for (final assignment in step.assignments)
      if (seen.add(assignment.role) && !_financeAllowedRoles.contains(assignment.role)) assignment.role,
  ];
}

/// Khối "Bước Tài chính" của Dialog cấu hình bước (web `financeSection`): bật/tắt,
/// loại phiếu, ánh xạ trường phiếu ← thuộc tính hồ sơ, bước nhận hồ sơ khi kế toán trả.
class RcsiFinanceStepSection extends StatelessWidget {
  final ProcedureDefinition definition;
  final ProcedureStepDefinition step;

  /// Cấu hình đang sửa; null = bước thường.
  final ProcedureStepIntegration? finance;
  final List<FinanceAttributeCandidate> candidates;
  final bool readOnly;
  final ValueChanged<ProcedureStepIntegration?> onChanged;

  const RcsiFinanceStepSection({
    super.key,
    required this.definition,
    required this.step,
    required this.finance,
    required this.candidates,
    required this.readOnly,
    required this.onChanged,
  });

  void _toggle(bool on) => onChanged(on ? const ProcedureStepIntegration(voucherKind: 'PAYMENT') : null);

  void _setMapping(ProcedureStepIntegration current, String field, String key) {
    final mapping = Map<String, String>.of(current.mapping ?? const {});
    if (key.isEmpty) {
      mapping.remove(field);
    } else {
      mapping[field] = key;
    }
    onChanged(ProcedureStepIntegration(
      voucherKind: current.voucherKind,
      mapping: mapping,
      returnToStepId: current.returnToStepId,
    ));
  }

  Future<void> _pickMapping(BuildContext context, ProcedureStepIntegration current, String field) async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: financeVoucherSourceFieldLabelKey(field).tr(),
      selected: current.mapping?[field] ?? _auto,
      options: [
        RcsiOption(_auto, _autoLabel(field)),
        for (final candidate in candidatesForField(field, candidates))
          RcsiOption(
            candidate.key,
            candidate.attribute.name,
            subtitle: '${candidate.attribute.code} · ${candidate.scopeLabel}',
          ),
      ],
    );
    if (picked == null || !context.mounted) return;
    _setMapping(current, field, picked.value);
  }

  Future<void> _pickReturnStep(BuildContext context, ProcedureStepIntegration current) async {
    final targets = financeReturnTargets(definition, step.id);
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.step_config.return_label'.tr(),
      selected: current.returnToStepId ?? '',
      options: [
        RcsiOption('', 'procedure.rcsi.step_config.return_placeholder'.tr()),
        for (final target in targets) RcsiOption(target.id, target.name, subtitle: target.key),
      ],
    );
    if (picked == null || !context.mounted) return;
    onChanged(ProcedureStepIntegration(
      voucherKind: current.voucherKind,
      mapping: current.mapping,
      returnToStepId: picked.value.isEmpty ? null : picked.value,
    ));
  }

  String _autoLabel(String field) {
    final auto = autoMatchedCandidate(field, candidates);
    if (auto != null) {
      return 'procedure.rcsi.step_config.mapping_auto_matched'
          .tr(args: {'name': auto.attribute.name, 'code': auto.attribute.code});
    }
    return 'procedure.rcsi.step_config.mapping_auto_none'
        .tr(args: {'codes': (financeVoucherSourceAttributeCodes[field] ?? const <String>[]).join(', ')});
  }

  String _mappingValueLabel(ProcedureStepIntegration current, String field) {
    final key = current.mapping?[field];
    if (key == null || key.isEmpty) return _autoLabel(field);
    for (final candidate in candidates) {
      if (candidate.key == key) return candidate.attribute.name;
    }
    return key;
  }

  String _returnLabel(ProcedureStepIntegration current) {
    final id = current.returnToStepId;
    if (id == null || id.isEmpty) return 'procedure.rcsi.step_config.return_placeholder'.tr();
    return definition.stepById(id)?.name ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final current = finance;
    final extraRoles = rcsiFinanceExtraRoles(step);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: readOnly ? null : () => _toggle(current == null),
            child: Row(
              children: [
                Checkbox(
                  value: current != null,
                  visualDensity: VisualDensity.compact,
                  onChanged: readOnly ? null : (value) => _toggle(value ?? false),
                ),
                const Icon(Icons.account_balance_outlined, size: 16, color: AppColors.slate700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'procedure.rcsi.step_config.finance_toggle'.tr(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800),
                  ),
                ),
              ],
            ),
          ),
          _hint('procedure.rcsi.step_config.finance_hint'.tr()),
          if (current != null) ...[
            const SizedBox(height: 12),
            _label('procedure.rcsi.step_config.voucher_kind_label'.tr()),
            Wrap(
              spacing: 8,
              children: [
                for (final kind in procedureFinanceVoucherKinds)
                  ChoiceChip(
                    label: Text(financeVoucherKindLabelKey(kind).tr()),
                    selected: current.voucherKind == kind,
                    onSelected: readOnly
                        ? null
                        : (_) => onChanged(ProcedureStepIntegration(
                              voucherKind: kind,
                              mapping: current.mapping,
                              returnToStepId: current.returnToStepId,
                            )),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _label('procedure.rcsi.step_config.mapping_label'.tr()),
            for (final field in financeVoucherSourceFields)
              _MappingTile(
                label: financeVoucherSourceFieldLabelKey(field).tr(),
                required: field == 'amount',
                value: _mappingValueLabel(current, field),
                isAuto: (current.mapping?[field] ?? _auto).isEmpty,
                onTap: readOnly ? null : () => _pickMapping(context, current, field),
              ),
            _hint('procedure.rcsi.step_config.mapping_hint'.tr()),
            const SizedBox(height: 12),
            _label('procedure.rcsi.step_config.return_label'.tr()),
            RcsiConfigSelectField(
              value: _returnLabel(current),
              placeholder: current.returnToStepId == null,
              onTap: readOnly ? null : () => _pickReturnStep(context, current),
            ),
            const SizedBox(height: 10),
            if (extraRoles.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  border: Border.all(color: AppColors.warningBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'procedure.rcsi.step_config.roles_warning'.tr(args: {'roles': extraRoles.join(', ')}),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.warningFg),
                ),
              )
            else
              _hint('procedure.rcsi.step_config.roles_hint'.tr()),
          ],
        ],
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

/// Ô chọn dạng `<select>` mở bộ chọn bottom sheet (web `SearchableSelect`).
class RcsiConfigSelectField extends StatelessWidget {
  final String value;
  final String? description;

  /// Hiển thị chữ nhạt khi đang là giá trị trống / placeholder.
  final bool placeholder;
  final VoidCallback? onTap;

  const RcsiConfigSelectField({super.key, required this.value, this.description, this.placeholder = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.surface : AppColors.slate100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        color: placeholder ? AppColors.slate400 : AppColors.slate800,
                      ),
                    ),
                    if (description != null && description!.isNotEmpty)
                      Text(description!, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  ],
                ),
              ),
              if (enabled) const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

class _MappingTile extends StatelessWidget {
  final String label;
  final bool required;
  final String value;
  final bool isAuto;
  final VoidCallback? onTap;

  const _MappingTile({
    required this.label,
    required this.required,
    required this.value,
    required this.isAuto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(
            text: label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate600),
            children: [
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.errorFg),
                ),
            ],
          )),
          const SizedBox(height: 4),
          RcsiConfigSelectField(value: value, placeholder: isAuto, onTap: onTap),
        ],
      ),
    );
  }
}
