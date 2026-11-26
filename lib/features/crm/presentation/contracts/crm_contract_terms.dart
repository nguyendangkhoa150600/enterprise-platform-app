import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/contracts/crm_contract_models.dart';
import '../../domain/crm_capabilities.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_select.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_fulfillment_ui.dart';

/// Một dòng lưới đợt thanh toán đang sửa (web `TermDraft`, chuỗi như người dùng gõ).
class CrmTermDraft {
  final String key;
  final TextEditingController name;
  final TextEditingController value;
  final TextEditingController dueDays;
  final TextEditingController note;
  String mode;
  String condition;
  String dueDate;

  CrmTermDraft({
    required this.key,
    required String name,
    required this.mode,
    required String value,
    required this.condition,
    required this.dueDate,
    required String dueDays,
    required String note,
  }) : name = TextEditingController(text: name),
       value = TextEditingController(text: value),
       dueDays = TextEditingController(text: dueDays),
       note = TextEditingController(text: note);

  /// Web `termDraft(term)`.
  factory CrmTermDraft.fromTerm(CrmPaymentTerm term) => CrmTermDraft(
    key: term.id,
    name: term.name,
    mode: term.percent == null ? 'amount' : 'percent',
    value: _plain(term.percent ?? term.amount),
    condition: term.condition,
    dueDate: term.dueDate ?? '',
    dueDays: term.dueDays == null ? '' : '${term.dueDays}',
    note: term.note ?? '',
  );

  static String _plain(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  /// Chữ ký để so "đã sửa" (web so JSON của lưới).
  String get signature =>
      [key, name.text, mode, value.text, condition, dueDate, dueDays.text, note.text].join('\u0001');

  ({double? percent, double? amount}) get parsed {
    final number = parseCrmNumber(value.text);
    return mode == 'percent' ? (percent: number, amount: null) : (percent: null, amount: number);
  }

  /// Web `saveTerms` → `SavePaymentTermRequest` (số sai gửi NaN như web → để server báo; ở đây gửi null).
  Map<String, dynamic> toRequest(int index) {
    final number = parseCrmNumber(value.text);
    final n = name.text.trim();
    final t = note.text.trim();
    return {
      'name': n.isEmpty ? 'crm.contracts.terms.default_name'.tr(args: {'n': index + 1}) : n,
      'percent': mode == 'percent' ? number : null,
      'amount': mode == 'amount' ? number : null,
      'condition': condition,
      'dueDate': dueDate.isEmpty ? null : dueDate,
      'dueDays': dueDays.text.trim().isEmpty ? null : int.tryParse(dueDays.text.trim()),
      'note': t.isEmpty ? null : t,
    };
  }

  void dispose() {
    name.dispose();
    value.dispose();
    dueDays.dispose();
    note.dispose();
  }
}

/// Khối "Đợt thanh toán" (web lưới đợt thanh toán của chi tiết hợp đồng): sửa khi hợp đồng Nháp (tổng phải bằng
/// 100% giá trị), ghi nhận nghiệm thu / giao đủ khi được phép.
class CrmContractTermsCard extends StatelessWidget {
  final CrmContractDetail detail;
  final List<CrmTermDraft> terms;
  final bool editable;
  final bool dirty;
  final bool busy;
  final CrmCapabilities caps;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final ValueChanged<CrmPaymentTerm> onTrigger;

  const CrmContractTermsCard({
    super.key,
    required this.detail,
    required this.terms,
    required this.editable,
    required this.dirty,
    required this.busy,
    required this.caps,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onSave,
    required this.onReset,
    required this.onTrigger,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = terms.map((t) => t.parsed).toList();
    final totals = crmPaymentTermTotals(parsed, detail.value);
    return CrmCard(
      title: 'crm.contracts.terms.title'.tr(),
      trailing: editable
          ? TextButton.icon(
              onPressed: busy ? null : onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('crm.contracts.terms.add'.tr()),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (terms.isEmpty)
            Text('crm.contracts.terms.empty'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted)),
          for (var i = 0; i < terms.length; i++) _termTile(context, i, parsed[i]),
          const SizedBox(height: 4),
          Text(
            '${'crm.contracts.terms.total'.tr(args: {'percent': formatCrmPercent(totals.percent), 'amount': formatCrmMoney(totals.amount), 'value': formatCrmMoney(detail.value)})}${totals.balanced ? '' : ' ${'crm.contracts.terms.unbalanced'.tr()}'}',
            style: TextStyle(
              fontSize: 12.5,
              color: totals.balanced ? CrmColors.muted : CrmColors.warning,
              fontWeight: totals.balanced ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
          if (editable && dirty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CrmButton(
                    label: 'crm.contracts.terms.reset'.tr(),
                    outlined: true,
                    onPressed: busy ? null : onReset,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CrmButton(label: 'crm.contracts.terms.save'.tr(), busy: busy, onPressed: onSave),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  CrmPaymentTerm? _saved(String key) {
    for (final t in detail.paymentTerms) {
      if (t.id == key) return t;
    }
    return null;
  }

  Widget _termTile(BuildContext context, int index, ({double? percent, double? amount}) parsed) {
    final term = terms[index];
    final saved = _saved(term.key);
    final amount = parsed.percent != null ? (detail.value * parsed.percent! / 100).roundToDouble() : parsed.amount;
    final header = Row(
      children: [
        CrmCodeBadge('#${index + 1}'),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            editable ? (amount == null ? '' : formatCrmMoney(amount)) : term.name.text,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: CrmColors.text),
          ),
        ),
        CrmStatusPill(
          dense: true,
          label: saved == null ? 'crm.contracts.terms.unsaved'.tr() : crmTermStatusLabel(saved.status),
        ),
        if (editable)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'crm.contracts.remove'.tr(),
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: CrmColors.danger),
            onPressed: busy ? null : () => onRemove(index),
          ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CrmColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CrmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 8),
          if (editable) ..._editFields(context, term) else ..._readFields(term, amount),
          if (!editable && saved != null && crmCanTriggerPaymentTerm(detail.status, saved, caps))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy ? null : () => onTrigger(saved),
                child: Text(crmTermTriggerLabels(saved).action),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _readFields(CrmTermDraft term, double? amount) => [
    CrmInfoRow(
      label: 'crm.contracts.terms.value'.tr(),
      value: term.mode == 'percent' ? '${term.value.text}%' : formatCrmMoney(parseCrmNumber(term.value.text) ?? 0),
    ),
    CrmInfoRow(label: 'crm.contracts.terms.amount'.tr(), value: amount == null ? '' : formatCrmMoney(amount)),
    CrmInfoRow(label: 'crm.contracts.terms.condition'.tr(), value: crmTermConditionLabel(term.condition)),
    CrmInfoRow(label: 'crm.contracts.terms.due_date'.tr(), value: formatCrmDay(term.dueDate)),
    CrmInfoRow(label: 'crm.contracts.terms.due_days'.tr(), value: term.dueDays.text),
  ];

  List<Widget> _editFields(BuildContext context, CrmTermDraft term) => [
    CrmField(
      label: 'crm.contracts.terms.name'.tr(),
      child: TextField(
        controller: term.name,
        maxLength: 200,
        onChanged: (_) => onChanged(),
        decoration: crmInputDecoration().copyWith(counterText: ''),
      ),
    ),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CrmField(
            label: 'crm.contracts.terms.mode'.tr(),
            child: CrmSelectField(
              value: term.mode,
              options: [
                CrmSelectOption(value: 'percent', label: 'crm.contracts.terms.mode_percent'.tr()),
                CrmSelectOption(value: 'amount', label: 'crm.contracts.terms.mode_amount'.tr()),
              ],
              onChanged: (s) {
                if (s.value == null) return;
                term.mode = s.value!;
                onChanged();
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CrmField(
            label: 'crm.contracts.terms.value'.tr(),
            child: TextField(
              controller: term.value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onChanged(),
              decoration: crmInputDecoration(),
            ),
          ),
        ),
      ],
    ),
    CrmField(
      label: 'crm.contracts.terms.condition'.tr(),
      child: CrmSelectField(
        value: term.condition,
        options: [
          for (final c in kCrmPaymentTermConditions) CrmSelectOption(value: c, label: crmTermConditionLabel(c)),
        ],
        onChanged: (s) {
          if (s.value == null) return;
          term.condition = s.value!;
          onChanged();
        },
      ),
    ),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CrmField(
            label: 'crm.contracts.terms.due_date'.tr(),
            child: CrmDateField(
              value: term.dueDate,
              onChanged: (v) {
                term.dueDate = v;
                onChanged();
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CrmField(
            label: 'crm.contracts.terms.due_days'.tr(),
            child: TextField(
              controller: term.dueDays,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              decoration: crmInputDecoration(),
            ),
          ),
        ),
      ],
    ),
  ];
}

/// Web `paymentTermTriggerLabels`: chữ nút, tiêu đề và ô ngày theo điều kiện của đợt.
({String action, String dateLabel}) crmTermTriggerLabels(CrmPaymentTerm term) => term.condition == 'FULL_DELIVERY'
    ? (action: 'crm.contracts.terms.trigger_full'.tr(), dateLabel: 'crm.contracts.terms.trigger_full_date'.tr())
    : (
        action: 'crm.contracts.terms.trigger_acceptance'.tr(),
        dateLabel: 'crm.contracts.terms.trigger_acceptance_date'.tr(),
      );

/// Hộp ghi nhận đợt đến hạn (web `CrmDialog` trigger): chọn ngày (trống là hôm nay); [onSubmit] gọi API.
Future<bool> showCrmTermTriggerSheet(
  BuildContext context, {
  required CrmPaymentTerm term,
  required Future<void> Function(String date) onSubmit,
}) async {
  final ok = await showCrmSheet<bool>(
    context,
    builder: (_) => _TriggerSheet(term: term, onSubmit: onSubmit),
  );
  return ok == true;
}

class _TriggerSheet extends StatefulWidget {
  final CrmPaymentTerm term;
  final Future<void> Function(String date) onSubmit;
  const _TriggerSheet({required this.term, required this.onSubmit});

  @override
  State<_TriggerSheet> createState() => _TriggerSheetState();
}

class _TriggerSheetState extends State<_TriggerSheet> {
  String _date = '';
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_date);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = crmErrorMessage(e, 'crm.contracts.action_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = crmTermTriggerLabels(widget.term);
    return CrmFormSheet(
      title: labels.action,
      subtitle: '${widget.term.name} · ${formatCrmMoney(widget.term.amount)}',
      submitLabel: 'crm.contracts.terms.trigger_submit'.tr(),
      submitting: _saving,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: labels.dateLabel,
          hint: 'crm.contracts.terms.trigger_hint'.tr(),
          child: CrmDateField(value: _date, onChanged: (v) => setState(() => _date = v)),
        ),
      ],
    );
  }
}
