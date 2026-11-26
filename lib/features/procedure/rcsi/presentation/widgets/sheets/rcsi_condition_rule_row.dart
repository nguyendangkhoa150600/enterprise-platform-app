import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/procedure_condition.dart';
import '../../../domain/logic/procedure_host_attributes.dart';
import '../../../domain/logic/rcsi_labels.dart';
import '../../../domain/rcsi_flow_models.dart';
import 'rcsi_option_picker_sheet.dart';

/// Mô tả một lựa chọn thuộc tính như web: "Thuộc tính quy trình · Lấy từ đơn HRM: …"
/// hoặc "Bước 2 · Duyệt · Lấy từ đơn HRM: …".
String rcsiConditionChoiceDescription(ConditionAttributeChoice choice, RcsiLabels labels) {
  final step = choice.step;
  final head = step == null
      ? 'procedure.rcsi.gateway.process_attribute'.tr()
      : 'procedure.rcsi.gateway.step_attribute'.tr(args: {'label': choice.stepLabel, 'name': step.name});
  return [head, ?hostAttributeSourceLabel(choice.definition.code, labels)].join(' · ');
}

/// Một luật điều kiện (`RuleRow` của web): thuộc tính · phép so sánh · giá trị · xoá.
class RcsiConditionRuleRow extends StatelessWidget {
  final ProcedureConditionRule rule;
  final List<ConditionAttributeChoice> choices;
  final RcsiLabels labels;
  final ProcedureConditionLabels conditionLabels;
  final bool enabled;
  final ValueChanged<ProcedureConditionRule> onChange;
  final VoidCallback onRemove;

  const RcsiConditionRuleRow({
    super.key,
    required this.rule,
    required this.choices,
    required this.labels,
    required this.conditionLabels,
    required this.enabled,
    required this.onChange,
    required this.onRemove,
  });

  ConditionAttributeChoice? get _choice {
    for (final choice in choices) {
      if (choice.value == rule.attribute.valueKey) return choice;
    }
    return null;
  }

  Future<void> _pickAttribute(BuildContext context) async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.gateway.attribute_placeholder'.tr(),
      selected: _choice?.value,
      options: [
        for (final choice in choices)
          RcsiOption(choice.value, choice.definition.name, subtitle: rcsiConditionChoiceDescription(choice, labels)),
      ],
    );
    if (picked == null || !context.mounted) return;
    ConditionAttributeChoice? next;
    for (final choice in choices) {
      if (choice.value == picked.value) next = choice;
    }
    if (next == null) return;
    final allowed = operatorsForType(next.definition.type);
    onChange(ProcedureConditionRule(
      id: rule.id,
      attribute: next.ref,
      operator: allowed.contains(rule.operator) ? rule.operator : (allowed.isEmpty ? 'not_empty' : allowed.first),
    ));
  }

  Future<void> _pickOperator(BuildContext context, List<String> operators) async {
    final picked = await showRcsiOptionPicker<String>(
      context,
      title: 'procedure.rcsi.gateway.operator'.tr(),
      selected: rule.operator,
      options: [for (final operator in operators) RcsiOption(operator, conditionLabels.operator(operator))],
    );
    if (picked == null || !context.mounted) return;
    onChange(ProcedureConditionRule(id: rule.id, attribute: rule.attribute, operator: picked.value));
  }

  @override
  Widget build(BuildContext context) {
    final choice = _choice;
    final operators = choice == null ? const <String>[] : operatorsForType(choice.definition.type);
    final multiSelect = rule.operator == 'in' && choice?.definition.type == 'select';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PickerField(
                  text: choice?.definition.name,
                  placeholder: 'procedure.rcsi.gateway.attribute_placeholder'.tr(),
                  onTap: enabled ? () => _pickAttribute(context) : null,
                ),
                const SizedBox(height: 6),
                _PickerField(
                  text: conditionLabels.operator(rule.operator),
                  placeholder: 'procedure.rcsi.gateway.operator'.tr(),
                  onTap: enabled && choice != null ? () => _pickOperator(context, operators) : null,
                ),
                if (choice != null && operatorNeedsValue(rule.operator)) ...[
                  const SizedBox(height: 6),
                  if (multiSelect)
                    _MultiSelect(rule: rule, definition: choice.definition, enabled: enabled, onChange: onChange)
                  else ...[
                    _ValueInput(
                      key: ValueKey('${rule.id}:${rule.attribute.valueKey}:${rule.operator}:from'),
                      definition: choice.definition,
                      value: rule.value,
                      enabled: enabled,
                      conditionLabels: conditionLabels,
                      onChange: (value) => onChange(rule.copyWith(value: value)),
                    ),
                    if (operatorNeedsUpperBound(rule.operator)) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'procedure.rcsi.gateway.range_to'.tr(),
                          style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                        ),
                      ),
                      _ValueInput(
                        key: ValueKey('${rule.id}:${rule.attribute.valueKey}:${rule.operator}:to'),
                        definition: choice.definition,
                        value: rule.valueTo,
                        enabled: enabled,
                        conditionLabels: conditionLabels,
                        onChange: (value) =>
                            onChange(rule.copyWith(valueTo: value is num || value is String ? value : null)),
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
          if (enabled)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'procedure.rcsi.gateway.remove_rule'.tr(),
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.slate500),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// Ô bấm mở bộ chọn (thay `SearchableSelect`).
class _PickerField extends StatelessWidget {
  final String? text;
  final String placeholder;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _PickerField({required this.text, required this.placeholder, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final empty = text == null || text!.isEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.slate100 : AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                empty ? placeholder : text!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: empty ? AppColors.slate400 : AppColors.slate800),
              ),
            ),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.slate400)),
          ],
        ),
      ),
    );
  }
}

/// `ValueInput` của web theo kiểu thuộc tính: chọn / Có-Không / ngày / số.
class _ValueInput extends StatelessWidget {
  final ProcedureAttributeDefinition definition;
  final Object? value;
  final bool enabled;
  final ProcedureConditionLabels conditionLabels;
  final ValueChanged<Object?> onChange;

  const _ValueInput({
    super.key,
    required this.definition,
    required this.value,
    required this.enabled,
    required this.conditionLabels,
    required this.onChange,
  });

  Widget _clear() => IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        tooltip: 'procedure.rcsi.gateway.clear_value'.tr(),
        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.slate400),
        onPressed: () => onChange(null),
      );

  @override
  Widget build(BuildContext context) {
    switch (definition.type) {
      case 'select':
        final options = definition.options ?? const <ProcedureAttributeOption>[];
        String? label;
        for (final option in options) {
          if (option.code == value) label = option.label;
        }
        return _PickerField(
          text: label,
          placeholder: 'procedure.rcsi.gateway.select_placeholder'.tr(),
          trailing: enabled && value != null ? _clear() : null,
          onTap: !enabled
              ? null
              : () async {
                  final picked = await showRcsiOptionPicker<String>(
                    context,
                    title: definition.name,
                    selected: value is String ? value as String : null,
                    options: [for (final option in options) RcsiOption(option.code, option.label)],
                  );
                  if (picked != null && context.mounted) onChange(picked.value.isEmpty ? null : picked.value);
                },
        );
      case 'boolean':
        return _PickerField(
          text: value == true
              ? conditionLabels.yes
              : value == false
                  ? conditionLabels.no
                  : null,
          placeholder: 'procedure.rcsi.gateway.select_placeholder'.tr(),
          onTap: !enabled
              ? null
              : () async {
                  final picked = await showRcsiOptionPicker<bool>(
                    context,
                    title: definition.name,
                    selected: value is bool ? value as bool : null,
                    options: [RcsiOption(true, conditionLabels.yes), RcsiOption(false, conditionLabels.no)],
                  );
                  if (picked != null && context.mounted) onChange(picked.value);
                },
        );
      case 'date':
        final text = value is String ? value as String : null;
        final parsed = text == null ? null : DateTime.tryParse(text);
        return _PickerField(
          text: parsed == null ? null : _dateLabel(text!),
          placeholder: 'procedure.rcsi.gateway.date_placeholder'.tr(),
          trailing: enabled && text != null ? _clear() : null,
          onTap: !enabled
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: parsed ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100, 12, 31),
                  );
                  if (picked == null || !context.mounted) return;
                  String two(int part) => part.toString().padLeft(2, '0');
                  onChange('${picked.year.toString().padLeft(4, '0')}-${two(picked.month)}-${two(picked.day)}');
                },
        );
      default:
        return _NumberInput(definition: definition, value: value is num ? value as num : null, enabled: enabled, onChange: onChange);
    }
  }
}

/// "2026-10-31" → "31/10/2026".
String _dateLabel(String value) {
  final parts = value.split('-');
  return parts.length >= 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : value;
}

/// Ô số: đọc như web (bỏ `.`, `,` → thập phân), định dạng lại khi rời ô.
class _NumberInput extends StatefulWidget {
  final ProcedureAttributeDefinition definition;
  final num? value;
  final bool enabled;
  final ValueChanged<Object?> onChange;

  const _NumberInput({required this.definition, required this.value, required this.enabled, required this.onChange});

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  late final TextEditingController _controller = TextEditingController(text: _format(widget.value));
  final FocusNode _focus = FocusNode();

  static String _format(num? value) => value == null ? '' : formatViNumber(value, maxFractionDigits: 3);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _controller.text = _format(parseViNumber(_controller.text));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.definition.type;
    final hint = type == 'money'
        ? 'procedure.rcsi.gateway.value_money'.tr()
        : type == 'percent'
            ? 'procedure.rcsi.gateway.value_percent'.tr()
            : 'procedure.rcsi.gateway.value_number'.tr();
    return TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: const TextStyle(fontSize: 13.5),
      onChanged: (text) => widget.onChange(parseViNumber(text)),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.slate400),
        filled: true,
        fillColor: widget.enabled ? AppColors.surface : AppColors.slate100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

/// "thuộc một trong": danh sách đánh dấu các lựa chọn.
class _MultiSelect extends StatelessWidget {
  final ProcedureConditionRule rule;
  final ProcedureAttributeDefinition definition;
  final bool enabled;
  final ValueChanged<ProcedureConditionRule> onChange;

  const _MultiSelect({required this.rule, required this.definition, required this.enabled, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final raw = rule.value;
    final current = raw is List ? raw.map((item) => '$item').toList() : const <String>[];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (final option in definition.options ?? const <ProcedureAttributeOption>[])
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              controlAffinity: ListTileControlAffinity.leading,
              value: current.contains(option.code),
              title: Text(option.label, style: const TextStyle(fontSize: 13.5)),
              onChanged: !enabled
                  ? null
                  : (checked) => onChange(rule.copyWith(
                        value: checked == true
                            ? [...current, option.code]
                            : current.where((code) => code != option.code).toList(),
                      )),
            ),
        ],
      ),
    );
  }
}
