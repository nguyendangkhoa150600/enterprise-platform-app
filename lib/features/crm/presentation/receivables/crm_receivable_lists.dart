import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/receivables/receivables_repository.dart';
import '../../domain/receivables/crm_receivable_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_pager.dart';
import '../common/crm_paging.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_receivables_labels.dart';

/// Danh sách lần thu (web `ReceiptsTable` / `CustomerReceipts`): có [customerId] thì chỉ lần thu của khách đó và
/// không có bộ lọc trạng thái (như web). Không tự cuộn: đặt trong ListView của màn.
class CrmReceiptsSection extends StatefulWidget {
  final String? customerId;
  final ValueChanged<CrmReceipt> onTap;
  const CrmReceiptsSection({super.key, this.customerId, required this.onTap});

  @override
  State<CrmReceiptsSection> createState() => CrmReceiptsSectionState();
}

class CrmReceiptsSectionState extends State<CrmReceiptsSection> {
  String? _status;
  late final CrmPagedListController<CrmReceipt> _list = CrmPagedListController<CrmReceipt>(
    load: (page) =>
        CrmReceivablesRepository.instance.listReceipts(customerId: widget.customerId, status: _status, page: page),
  );

  @override
  void initState() {
    super.initState();
    _list.addListener(_changed);
    _list.reload();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> reload() => _list.reload();

  @override
  void dispose() {
    _list.removeListener(_changed);
    _list.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final withCustomer = widget.customerId == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (withCustomer)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: CrmFilterChip(
                placeholder: 'crm.receivables.all_statuses'.tr(),
                value: _status,
                options: crmOptionsOf(kCrmReceiptStatuses, crmReceiptStatusLabel),
                onChanged: (v) {
                  _status = v;
                  _list.setKey(v ?? '');
                },
              ),
            ),
          ),
        if (_list.error != null) CrmBanner(message: _list.error!),
        if (_list.loading && _list.items.isEmpty)
          const CrmStateView(loading: true)
        else if (_list.items.isEmpty)
          CrmStateView(emptyText: 'crm.receivables.receipts_empty'.tr())
        else
          for (final r in _list.items)
            _ReceiptCard(receipt: r, withCustomer: withCustomer, onTap: () => widget.onTap(r)),
        CrmPagerBar.of(_list, noun: 'crm.receivables.noun_receipt'.tr()),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final CrmReceipt receipt;
  final bool withCustomer;
  final VoidCallback onTap;
  const _ReceiptCard({required this.receipt, required this.withCustomer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    return CrmCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CrmCodeBadge(r.code),
              const SizedBox(width: 8),
              Flexible(
                child: CrmStatusPill(label: crmReceiptStatusLabel(r.status), tone: crmReceiptStatusTone(r.status)),
              ),
            ],
          ),
          if (withCustomer) ...[
            const SizedBox(height: 6),
            Text(
              '${r.customerCode} - ${r.customerName}',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.text),
            ),
          ],
          const SizedBox(height: 4),
          CrmInfoRow(label: 'crm.receivables.col.receipt_date'.tr(), value: formatCrmDay(r.receiptDate)),
          CrmInfoRow(label: 'crm.receivables.col.method'.tr(), value: crmReceiptMethodLabel(r.method)),
          CrmInfoRow(label: 'crm.receivables.col.amount'.tr(), value: formatCrmMoney(r.amount)),
          CrmInfoRow(label: 'crm.receivables.col.allocated'.tr(), value: formatCrmMoney(r.allocatedAmount)),
          CrmInfoRow(
            label: 'crm.receivables.col.voucher'.tr(),
            value: r.financeVoucherCode ?? (withCustomer ? 'crm.receivables.no_voucher'.tr() : ''),
          ),
          CrmInfoRow(label: 'crm.receivables.col.collector'.tr(), value: CrmScope.instance.personName(r.createdBy)),
        ],
      ),
    );
  }
}

/// Danh sách điều chỉnh công nợ (web `AdjustmentsTable`): dùng ở trang công nợ (mọi khách, chạm mở sổ nợ) và sổ nợ
/// của một khách ([customerId]). Duyệt / huỷ theo [crmAdjustmentActions]. Không tự cuộn.
class CrmAdjustmentsSection extends StatefulWidget {
  final String? customerId;
  final ValueChanged<String>? onOpenCustomer;
  final VoidCallback? onChanged;
  const CrmAdjustmentsSection({super.key, this.customerId, this.onOpenCustomer, this.onChanged});

  @override
  State<CrmAdjustmentsSection> createState() => CrmAdjustmentsSectionState();
}

class CrmAdjustmentsSectionState extends State<CrmAdjustmentsSection> {
  String? _status;
  late final CrmPagedListController<CrmReceivableAdjustment> _list = CrmPagedListController(
    load: (page) =>
        CrmReceivablesRepository.instance.listAdjustments(customerId: widget.customerId, status: _status, page: page),
  );

  @override
  void initState() {
    super.initState();
    _list.addListener(_changed);
    _list.reload();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> reload() => _list.reload();

  @override
  void dispose() {
    _list.removeListener(_changed);
    _list.dispose();
    super.dispose();
  }

  Future<void> _act(CrmReceivableAdjustment adjustment, String action) async {
    final done = await showCrmSheet<bool>(
      context,
      builder: (_) => _AdjustmentActionSheet(adjustment: adjustment, action: action),
    );
    if (done != true || !mounted) return;
    _list.reload();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scope = CrmScope.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CrmFilterChip(
              placeholder: 'crm.receivables.all_statuses'.tr(),
              value: _status,
              options: crmOptionsOf(kCrmAdjustmentStatuses, crmAdjustmentStatusLabel),
              onChanged: (v) {
                _status = v;
                _list.setKey(v ?? '');
              },
            ),
          ),
        ),
        if (_list.error != null) CrmBanner(message: _list.error!),
        if (_list.loading && _list.items.isEmpty)
          const CrmStateView(loading: true)
        else if (_list.items.isEmpty)
          CrmStateView(emptyText: 'crm.receivables.adjustments_empty'.tr())
        else
          for (final a in _list.items)
            _AdjustmentCard(
              adjustment: a,
              withCustomer: widget.customerId == null,
              actions: crmAdjustmentActions(a, scope.capabilities, scope.currentUserId),
              onTap: widget.onOpenCustomer == null ? null : () => widget.onOpenCustomer!(a.customerId),
              onAction: (action) => _act(a, action),
            ),
        CrmPagerBar.of(_list, noun: 'crm.receivables.noun_adjustment'.tr()),
      ],
    );
  }
}

class _AdjustmentCard extends StatelessWidget {
  final CrmReceivableAdjustment adjustment;
  final bool withCustomer;
  final List<String> actions;
  final VoidCallback? onTap;
  final ValueChanged<String> onAction;

  const _AdjustmentCard({
    required this.adjustment,
    required this.withCustomer,
    required this.actions,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final a = adjustment;
    final scope = CrmScope.instance;
    return CrmCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CrmCodeBadge(a.code),
              const SizedBox(width: 8),
              Flexible(
                child: CrmStatusPill(
                  label: crmAdjustmentStatusLabel(a.status),
                  tone: crmAdjustmentStatusTone(a.status),
                ),
              ),
            ],
          ),
          if (withCustomer) ...[
            const SizedBox(height: 6),
            Text(
              '${a.customerCode} - ${a.customerName}',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.text),
            ),
          ],
          const SizedBox(height: 4),
          CrmInfoRow(label: 'crm.receivables.col.direction'.tr(), value: crmAdjustmentDirectionLabel(a.direction)),
          CrmInfoRow(label: 'crm.receivables.col.amount'.tr(), value: formatCrmMoney(a.amount)),
          CrmInfoRow(label: 'crm.receivables.col.order'.tr(), value: a.orderCode ?? ''),
          CrmInfoRow(label: 'crm.receivables.col.reason'.tr(), value: a.reason),
          CrmInfoRow(label: 'crm.receivables.col.created_by'.tr(), value: scope.personName(a.createdBy)),
          CrmInfoRow(label: 'crm.receivables.col.approved_by'.tr(), value: scope.personName(a.approvedBy)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (final action in actions) ...[
                  Expanded(
                    child: CrmButton(
                      label: action == 'approve' ? 'crm.receivables.approve'.tr() : 'crm.receivables.cancel'.tr(),
                      outlined: action != 'approve',
                      danger: action != 'approve',
                      onPressed: () => onAction(action),
                    ),
                  ),
                  if (action != actions.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Duyệt / huỷ điều chỉnh (web `AdjustmentActionDialog`); trả true khi xong.
class _AdjustmentActionSheet extends StatefulWidget {
  final CrmReceivableAdjustment adjustment;
  final String action;
  const _AdjustmentActionSheet({required this.adjustment, required this.action});

  @override
  State<_AdjustmentActionSheet> createState() => _AdjustmentActionSheetState();
}

class _AdjustmentActionSheetState extends State<_AdjustmentActionSheet> {
  final TextEditingController _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _approve => widget.action == 'approve';

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final a = widget.adjustment;
    final reason = _reason.text.trim();
    if (!_approve && reason.isEmpty) {
      setState(() => _error = 'crm.receivables.error.cancel_reason'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CrmReceivablesRepository.instance.adjustmentAction(
        a.id,
        widget.action,
        revision: a.revision,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      showCrmSnack(
        context,
        _approve
            ? 'crm.receivables.toast.adjustment_approved'.tr(args: {'code': a.code})
            : 'crm.receivables.toast.adjustment_cancelled'.tr(args: {'code': a.code}),
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
    final a = widget.adjustment;
    return CrmFormSheet(
      title: (_approve ? 'crm.receivables.approve_title' : 'crm.receivables.cancel_title').tr(args: {'code': a.code}),
      subtitle: '${crmAdjustmentDirectionLabel(a.direction)} ${formatCrmMoney(a.amount)} · ${a.reason}',
      submitLabel: _approve ? 'crm.receivables.approve'.tr() : 'crm.receivables.cancel_adjustment'.tr(),
      danger: !_approve,
      submitting: _saving,
      error: _error,
      onSubmit: _submit,
      children: [
        if (_approve)
          Text('crm.receivables.approve_hint'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted))
        else
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
          ),
      ],
    );
  }
}
