import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/receivables/receivables_repository.dart';
import '../../domain/receivables/crm_receivable_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_receivables_labels.dart';

/// Ô nhập phân bổ (web `AllocationTable`): mỗi khoản còn phân bổ được (hoặc đang có số) một ô số tiền.
class CrmAllocationEditor extends StatefulWidget {
  final List<CrmReceivableOpenItem> items;
  final Map<String, double> allocations;
  final ValueChanged<Map<String, double>> onChanged;
  const CrmAllocationEditor({super.key, required this.items, required this.allocations, required this.onChanged});

  @override
  State<CrmAllocationEditor> createState() => _CrmAllocationEditorState();
}

class _CrmAllocationEditorState extends State<CrmAllocationEditor> {
  final Map<String, TextEditingController> _ctrls = {};

  String _text(double? v) => (v == null || v == 0) ? '' : formatCrmQuantity(v);

  TextEditingController _ctrl(String entryId) =>
      _ctrls.putIfAbsent(entryId, () => TextEditingController(text: _text(widget.allocations[entryId])));

  @override
  void didUpdateWidget(covariant CrmAllocationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Phân bổ tự động đổi số từ ngoài: đồng bộ ô khi số khác số đang gõ.
    _ctrls.forEach((id, ctrl) {
      final next = widget.allocations[id] ?? 0;
      if ((parseCrmNumber(ctrl.text) ?? 0) != next) ctrl.text = _text(next);
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.items
        .where((i) => i.allocatableAmount > 0 || (widget.allocations[i.entryId] ?? 0) != 0)
        .toList();
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'crm.receivables.allocation_empty'.tr(),
          style: const TextStyle(fontSize: 13, color: CrmColors.muted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: CrmColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crmOpenItemLabel(item),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CrmColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (item.dueDate != null)
                            'crm.receivables.due_on'.tr(args: {'date': formatCrmDay(item.dueDate)}),
                          'crm.receivables.allocatable'.tr(args: {'amount': formatCrmMoney(item.allocatableAmount)}),
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _ctrl(item.entryId),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    decoration: crmInputDecoration(hint: 'crm.receivables.col.allocate'.tr()),
                    onChanged: (v) => widget.onChanged({...widget.allocations, item.entryId: parseCrmNumber(v) ?? 0}),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ghi nhận thu tiền (web `ReceiptDialog`). Trả true khi đã ghi nhận.
class CrmReceiptCreateSheet extends StatefulWidget {
  final CrmCustomerLedger ledger;
  const CrmReceiptCreateSheet({super.key, required this.ledger});

  @override
  State<CrmReceiptCreateSheet> createState() => _CrmReceiptCreateSheetState();
}

class _CrmReceiptCreateSheetState extends State<CrmReceiptCreateSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _method = 'BANK_TRANSFER';
  String? _date;
  Map<String, double> _allocations = {};
  bool _saving = false;
  String? _error;

  double get _value => parseCrmNumber(_amount.text) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseCrmDay(_date) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = crmApiDate(picked));
  }

  Future<void> _save() async {
    final ledger = widget.ledger;
    final problem = crmAllocationError(_value, _allocations, ledger.openItems);
    if (problem != null) {
      setState(() => _error = crmAllocationErrorText(problem));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final note = _note.text.trim();
      final created = await CrmReceivablesRepository.instance.createReceipt(
        customerId: ledger.customerId,
        amount: _value,
        method: _method,
        receiptDate: _date,
        note: note.isEmpty ? null : note,
        allocations: crmAllocationRequests(_allocations),
      );
      if (!mounted) return;
      showCrmSnack(
        context,
        created.status == 'VOUCHER_DRAFT'
            ? 'crm.receivables.toast.receipt_draft'.tr(
                args: {'code': created.code, 'voucher': created.financeVoucherCode ?? ''},
              )
            : 'crm.receivables.toast.receipt_pending'.tr(args: {'code': created.code}),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = crmErrorMessage(e, 'crm.receivables.error.receipt_create');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = widget.ledger;
    final value = _value;
    final allocated = _allocations.values.fold<double>(0, (s, v) => s + v);
    return CrmFormSheet(
      title: 'crm.receivables.receipt_title'.tr(),
      subtitle: 'crm.receivables.receipt_subtitle'.tr(
        args: {'customer': '${ledger.customerCode} - ${ledger.customerName}'},
      ),
      submitLabel: 'crm.receivables.record'.tr(),
      submitting: _saving,
      error: _error,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.receivables.field.amount'.tr(),
          required: true,
          child: TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: crmInputDecoration(),
            onChanged: (_) => setState(() {}),
          ),
        ),
        CrmField(
          label: 'crm.receivables.field.method'.tr(),
          child: CrmSelectField(
            value: _method,
            options: crmOptionsOf(kCrmReceiptMethods, crmReceiptMethodLabel),
            onChanged: (s) => setState(() => _method = s.value ?? 'BANK_TRANSFER'),
          ),
        ),
        CrmField(
          label: 'crm.receivables.field.receipt_date'.tr(),
          hint: 'crm.receivables.field.receipt_date_hint'.tr(),
          child: InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: crmInputDecoration(
                suffixIcon: _date == null
                    ? const Icon(Icons.calendar_today_outlined, size: 18)
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _date = null),
                      ),
              ),
              child: Text(_date == null ? '' : formatCrmDay(_date), style: const TextStyle(fontSize: 14)),
            ),
          ),
        ),
        CrmField(
          label: 'crm.receivables.field.note'.tr(),
          child: TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            decoration: crmInputDecoration(),
          ),
        ),
        Row(
          children: [
            OutlinedButton(
              onPressed: value == 0
                  ? null
                  : () => setState(() => _allocations = crmAutoAllocate(ledger.openItems, value)),
              child: Text('crm.receivables.auto_allocate'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          [
            'crm.receivables.allocated_of'.tr(
              args: {'allocated': formatCrmMoney(allocated), 'amount': formatCrmMoney(value)},
            ),
            if (value > allocated)
              'crm.receivables.unallocated'.tr(args: {'amount': formatCrmMoney(value - allocated)}),
          ].join(' · '),
          style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
        ),
        const SizedBox(height: 10),
        CrmAllocationEditor(
          items: ledger.openItems,
          allocations: _allocations,
          onChanged: (next) => setState(() => _allocations = next),
        ),
      ],
    );
  }
}

/// Chi tiết lần thu (web `ReceiptDetailDialog`): xem phân bổ; bị trả lại / Tài chính từ chối → sửa và gửi lại hoặc
/// huỷ. Trả true khi đã thay đổi.
class CrmReceiptDetailSheet extends StatefulWidget {
  final String receiptId;
  final CrmCustomerLedger ledger;
  const CrmReceiptDetailSheet({super.key, required this.receiptId, required this.ledger});

  @override
  State<CrmReceiptDetailSheet> createState() => _CrmReceiptDetailSheetState();
}

class _CrmReceiptDetailSheetState extends State<CrmReceiptDetailSheet> {
  CrmReceipt? _receipt;
  String _mode = 'view';
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  Map<String, double> _allocations = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final next = await CrmReceivablesRepository.instance.getReceipt(widget.receiptId);
      if (!mounted) return;
      setState(() {
        _receipt = next;
        _amount.text = formatCrmQuantity(next.amount);
        _allocations = {for (final l in next.allocations) l.entryId: l.amount};
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.receivables.error.receipt_load'));
    }
  }

  /// Khoản nợ khi sửa: phần đang giữ của chính lần thu này được cộng lại vào số phân bổ được.
  List<CrmReceivableOpenItem> _editable(CrmReceipt receipt) => [
    for (final item in widget.ledger.openItems)
      item.withAllocatable(
        item.allocatableAmount +
            receipt.allocations.where((l) => l.entryId == item.entryId).fold<double>(0, (s, l) => s + l.amount),
      ),
  ];

  Future<void> _submit() async {
    final receipt = _receipt;
    if (receipt == null || _mode == 'view') {
      Navigator.of(context).pop();
      return;
    }
    final repo = CrmReceivablesRepository.instance;
    final value = parseCrmNumber(_amount.text) ?? 0;
    if (_mode == 'resend') {
      final problem = crmAllocationError(value, _allocations, _editable(receipt));
      if (problem != null) {
        setState(() => _error = crmAllocationErrorText(problem));
        return;
      }
    } else if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'crm.receivables.error.cancel_reason'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_mode == 'resend') {
        await repo.resendReceipt(
          receipt.id,
          revision: receipt.revision,
          amount: value,
          allocations: crmAllocationRequests(_allocations),
        );
      } else {
        await repo.cancelReceipt(receipt.id, revision: receipt.revision, reason: _reason.text.trim());
      }
      if (!mounted) return;
      showCrmSnack(
        context,
        (_mode == 'resend' ? 'crm.receivables.toast.receipt_resent' : 'crm.receivables.toast.receipt_cancelled').tr(
          args: {'code': receipt.code},
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = crmErrorMessage(e, 'crm.receivables.error.action');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    if (receipt == null) {
      return CrmFormSheet(
        title: 'crm.receivables.receipt'.tr(),
        hideCancel: true,
        submitLabel: 'crm.common.close'.tr(),
        onSubmit: () => Navigator.of(context).pop(),
        children: [if (_error != null) CrmBanner(message: _error!) else const CrmStateView(loading: true)],
      );
    }
    final actions = crmReceiptActions(receipt, CrmScope.instance.capabilities);
    return CrmFormSheet(
      title: 'crm.receivables.receipt_code'.tr(args: {'code': receipt.code}),
      subtitle: [
        crmReceiptStatusLabel(receipt.status),
        if (receipt.financeVoucherCode != null)
          'crm.receivables.voucher_code'.tr(args: {'code': receipt.financeVoucherCode}),
      ].join(' · '),
      submitLabel: switch (_mode) {
        'resend' => 'crm.receivables.resend_finance'.tr(),
        'cancel' => 'crm.receivables.cancel_receipt'.tr(),
        _ => 'crm.common.close'.tr(),
      },
      hideCancel: _mode == 'view',
      danger: _mode == 'cancel',
      submitting: _saving,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmInfoRow(label: 'crm.receivables.col.amount'.tr(), value: formatCrmMoney(receipt.amount)),
        CrmInfoRow(label: 'crm.receivables.col.method'.tr(), value: crmReceiptMethodLabel(receipt.method)),
        CrmInfoRow(label: 'crm.receivables.col.receipt_date'.tr(), value: formatCrmDay(receipt.receiptDate)),
        CrmInfoRow(label: 'crm.receivables.col.collector'.tr(), value: CrmScope.instance.personName(receipt.createdBy)),
        if (receipt.returnReason != null)
          CrmInfoRow(
            label: 'crm.receivables.return_reason'.tr(),
            child: Text(receipt.returnReason!, style: const TextStyle(fontSize: 13, color: CrmColors.danger)),
          ),
        if (receipt.voucherError != null)
          CrmInfoRow(
            label: 'crm.receivables.voucher_error'.tr(),
            child: Text(receipt.voucherError!, style: const TextStyle(fontSize: 13, color: CrmColors.danger)),
          ),
        if (receipt.note != null) CrmInfoRow(label: 'crm.receivables.field.note'.tr(), value: receipt.note),
        const SizedBox(height: 10),
        if (_mode == 'resend') ...[
          CrmField(
            label: 'crm.receivables.field.amount'.tr(),
            required: true,
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: crmInputDecoration(),
            ),
          ),
          CrmAllocationEditor(
            items: _editable(receipt),
            allocations: _allocations,
            onChanged: (next) => setState(() => _allocations = next),
          ),
        ] else if (_mode == 'cancel')
          CrmField(
            label: 'crm.receivables.field.cancel_reason'.tr(),
            required: true,
            child: TextField(
              controller: _reason,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              decoration: crmInputDecoration(),
            ),
          )
        else ...[
          CrmSectionTitle('crm.receivables.allocations'.tr()),
          if (receipt.allocations.isEmpty)
            Text('crm.receivables.allocations_empty'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted))
          else
            for (final line in receipt.allocations)
              CrmCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      line.entryDescription ?? line.orderCode ?? '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    CrmInfoRow(label: 'crm.receivables.col.due'.tr(), value: formatCrmDay(line.dueDate)),
                    CrmInfoRow(label: 'crm.receivables.col.allocate'.tr(), value: formatCrmMoney(line.amount)),
                    CrmInfoRow(
                      label: 'crm.receivables.col.effective'.tr(),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CrmStatusPill(
                          label: (line.effective ? 'crm.receivables.posted' : 'crm.receivables.pending_post').tr(),
                          tone: line.effective ? CrmTone.success : CrmTone.neutral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (actions.contains('resend'))
                  Expanded(
                    child: CrmButton(
                      label: 'crm.receivables.edit_resend'.tr(),
                      onPressed: () => setState(() => _mode = 'resend'),
                    ),
                  ),
                if (actions.length > 1) const SizedBox(width: 8),
                if (actions.contains('cancel'))
                  Expanded(
                    child: CrmButton(
                      label: 'crm.receivables.cancel_receipt'.tr(),
                      outlined: true,
                      danger: true,
                      onPressed: () => setState(() => _mode = 'cancel'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Lập điều chỉnh công nợ (web `AdjustmentDialog`). Trả true khi đã lập.
class CrmAdjustmentCreateSheet extends StatefulWidget {
  final CrmCustomerLedger ledger;
  const CrmAdjustmentCreateSheet({super.key, required this.ledger});

  @override
  State<CrmAdjustmentCreateSheet> createState() => _CrmAdjustmentCreateSheetState();
}

class _CrmAdjustmentCreateSheetState extends State<CrmAdjustmentCreateSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String _direction = 'DECREASE';
  String? _entryId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = parseCrmNumber(_amount.text) ?? 0;
    if (!(value > 0)) {
      setState(() => _error = 'crm.receivables.error.adjustment_amount'.tr());
      return;
    }
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'crm.receivables.error.adjustment_reason'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ledger = widget.ledger;
      CrmReceivableOpenItem? item;
      for (final candidate in ledger.openItems) {
        if (candidate.entryId == _entryId) item = candidate;
      }
      final created = await CrmReceivablesRepository.instance.createAdjustment(
        customerId: ledger.customerId,
        direction: _direction,
        amount: value,
        reason: reason,
        entryId: _direction == 'DECREASE' ? _entryId : null,
        orderId: item?.orderId,
      );
      if (!mounted) return;
      showCrmSnack(context, 'crm.receivables.toast.adjustment_created'.tr(args: {'code': created.code}));
      Navigator.of(context).pop(true);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = crmErrorMessage(e, 'crm.receivables.error.adjustment_create');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final openOptions = [
      for (final item in widget.ledger.openItems)
        if (item.openAmount > 0)
          CrmSelectOption(
            value: item.entryId,
            label: crmOpenItemLabel(item),
            badge: formatCrmMoney(item.openAmount),
            description: item.dueDate == null
                ? null
                : 'crm.receivables.due_on'.tr(args: {'date': formatCrmDay(item.dueDate)}),
          ),
    ];
    return CrmFormSheet(
      title: 'crm.receivables.adjustment_title'.tr(),
      subtitle: 'crm.receivables.adjustment_subtitle'.tr(),
      submitLabel: 'crm.receivables.create_adjustment'.tr(),
      submitting: _saving,
      error: _error,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.receivables.field.direction'.tr(),
          required: true,
          child: CrmSelectField(
            value: _direction,
            options: crmOptionsOf(kCrmAdjustmentDirections, crmAdjustmentDirectionLabel),
            onChanged: (s) => setState(() => _direction = s.value ?? 'DECREASE'),
          ),
        ),
        CrmField(
          label: 'crm.receivables.col.amount'.tr(),
          required: true,
          child: TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: crmInputDecoration(),
          ),
        ),
        if (_direction == 'DECREASE')
          CrmField(
            label: 'crm.receivables.field.entry'.tr(),
            hint: 'crm.receivables.field.entry_hint'.tr(),
            child: CrmSelectField(
              value: _entryId,
              options: openOptions,
              placeholder: 'crm.receivables.all_open_items'.tr(),
              clearable: true,
              onChanged: (s) => setState(() => _entryId = s.value),
            ),
          ),
        CrmField(
          label: 'crm.receivables.col.reason'.tr(),
          required: true,
          child: TextField(
            controller: _reason,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}
