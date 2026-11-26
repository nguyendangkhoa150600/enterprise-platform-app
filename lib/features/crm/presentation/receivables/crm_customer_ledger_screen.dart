import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/receivables/receivables_repository.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/receivables/crm_receivable_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_pager.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../utils/crm_scope.dart';
import 'crm_receipt_sheets.dart';
import 'crm_receivable_lists.dart';
import 'crm_receivables_labels.dart';

/// Sổ công nợ của một khách (web `receivables/customer-ledger.tsx`): hạn mức, dư nợ, tuổi nợ; khoản nợ còn mở; lần
/// thu và trạng thái phiếu thu Tài chính; điều chỉnh; dòng sổ chỉ ghi thêm. Thu tiền phân bổ vào một hay nhiều khoản.
class CrmCustomerLedgerScreen extends StatefulWidget {
  final String customerId;
  const CrmCustomerLedgerScreen({super.key, required this.customerId});

  /// Màn đã dựng xong (chỉ để theo dõi; màn chi tiết không có ô Trang chủ).
  static const bool ready = true;

  @override
  State<CrmCustomerLedgerScreen> createState() => _CrmCustomerLedgerScreenState();
}

class _CrmCustomerLedgerScreenState extends State<CrmCustomerLedgerScreen> {
  CrmCustomerLedger? _ledger;
  String? _error;
  int _version = 0;
  int _entryPage = 1;

  Future<void> _load() async {
    try {
      final next = await CrmReceivablesRepository.instance.loadLedger(widget.customerId);
      if (!mounted) return;
      setState(() {
        _ledger = next;
        _error = null;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.receivables.error.ledger'));
    }
  }

  /// Web `refresh`: tải lại sổ và dựng lại danh sách lần thu, điều chỉnh.
  Future<void> _refresh() {
    setState(() => _version++);
    return _load();
  }

  /// Mở màn khác (khách, đơn); quay lại thì tải lại sổ (web dựng lại sổ khi quay về).
  Future<void> _openThen(Future<void> Function() open) async {
    await open();
    if (mounted) await _refresh();
  }

  Future<void> _openSheet(Widget sheet) async {
    final changed = await showCrmSheet<bool>(context, builder: (_) => sheet);
    if (changed == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _ledger;
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(
        context,
        'crm.receivables.ledger_title'.tr(),
        subtitle: ledger == null ? null : '${ledger.customerCode} - ${ledger.customerName}',
      ),
      body: CrmPageGuard(
        view: CrmView.receivables,
        onAllowed: _load,
        builder: (context, status) {
          if (ledger == null) {
            return _error != null ? CrmStateView(error: _error, onRetry: _load) : const CrmStateView(loading: true);
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_error != null) CrmBanner(message: _error!),
                _summary(ledger, crmCanWriteReceivable(status.capabilities)),
                _openItems(ledger),
                CrmSectionTitle('crm.receivables.tab.receipts'.tr()),
                CrmReceiptsSection(
                  key: ValueKey('receipts-$_version'),
                  customerId: widget.customerId,
                  onTap: (r) => _openSheet(CrmReceiptDetailSheet(receiptId: r.id, ledger: ledger)),
                ),
                const SizedBox(height: 8),
                CrmSectionTitle('crm.receivables.tab.adjustments'.tr()),
                CrmAdjustmentsSection(
                  key: ValueKey('adjustments-$_version'),
                  customerId: widget.customerId,
                  onChanged: _refresh,
                ),
                const SizedBox(height: 8),
                _entries(ledger),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summary(CrmCustomerLedger ledger, bool canWrite) {
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _openThen(() => CrmRoutes.openCustomer(context, ledger.customerId)),
            child: Text(
              '${ledger.customerCode} - ${ledger.customerName}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CrmColors.link),
            ),
          ),
          if (ledger.creditExceeded) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: CrmStatusPill(label: 'crm.receivables.credit_exceeded'.tr(), tone: CrmTone.danger),
            ),
          ],
          const SizedBox(height: 6),
          CrmInfoRow(
            label: 'crm.receivables.col.balance'.tr(),
            child: Text(
              formatCrmMoney(ledger.balance),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CrmColors.text),
            ),
          ),
          CrmInfoRow(label: 'crm.receivables.col.credit_limit'.tr(), value: crmCreditLimitText(ledger.creditLimit)),
          CrmInfoRow(
            label: 'crm.receivables.payment_term'.tr(),
            value: ledger.paymentTermDays == null
                ? 'crm.receivables.not_set'.tr()
                : 'crm.receivables.days'.tr(args: {'n': ledger.paymentTermDays}),
          ),
          CrmInfoRow(
            label: 'crm.receivables.overdue_amount'.tr(),
            child: Text(
              formatCrmMoney(ledger.overdueAmount),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ledger.overdueAmount != 0 ? CrmColors.danger : CrmColors.text,
              ),
            ),
          ),
          if (ledger.unappliedAmount != 0)
            CrmInfoRow(label: 'crm.receivables.unapplied'.tr(), value: formatCrmMoney(ledger.unappliedAmount)),
          for (final bucket in kCrmAgingBuckets)
            CrmInfoRow(label: crmAgingBucketLabel(bucket), value: formatCrmMoney(ledger.buckets[bucket])),
          if (canWrite) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CrmButton(
                    label: 'crm.receivables.record_receipt'.tr(),
                    icon: Icons.add_rounded,
                    onPressed: () => _openSheet(CrmReceiptCreateSheet(ledger: ledger)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CrmButton(
                    label: 'crm.receivables.adjustment_title'.tr(),
                    outlined: true,
                    onPressed: () => _openSheet(CrmAdjustmentCreateSheet(ledger: ledger)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _openItems(CrmCustomerLedger ledger) {
    return CrmCard(
      title: 'crm.receivables.open_items'.tr(),
      child: ledger.openItems.isEmpty
          ? Text('crm.receivables.open_items_empty'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in ledger.openItems) ...[
                  if (item != ledger.openItems.first) const Divider(height: 16, color: CrmColors.divider),
                  if (item.orderId != null)
                    InkWell(
                      onTap: () => _openThen(() => CrmRoutes.openOrder(context, item.orderId!)),
                      child: Text(
                        item.description ?? 'crm.receivables.order_item'.tr(args: {'code': item.orderCode}),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.link),
                      ),
                    )
                  else
                    Text(
                      item.description ?? crmEntryKindLabel(item.kind),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.text),
                    ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CrmStatusPill(
                      label: [
                        crmAgingBucketLabel(item.bucket),
                        if ((item.daysOverdue ?? 0) > 0)
                          'crm.receivables.overdue_days'.tr(args: {'n': item.daysOverdue}),
                      ].join(' · '),
                      tone: crmAgingBucketTone(item.bucket),
                    ),
                  ),
                  CrmInfoRow(label: 'crm.receivables.col.date'.tr(), value: formatCrmDay(item.entryDate)),
                  CrmInfoRow(label: 'crm.receivables.col.due'.tr(), value: formatCrmDay(item.dueDate)),
                  CrmInfoRow(label: 'crm.receivables.col.incurred'.tr(), value: formatCrmMoney(item.amount)),
                  CrmInfoRow(
                    label: 'crm.receivables.col.open'.tr(),
                    child: Text(
                      formatCrmMoney(item.openAmount),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CrmColors.text),
                    ),
                  ),
                  if (item.pendingAmount != 0)
                    CrmInfoRow(label: 'crm.receivables.col.pending'.tr(), value: formatCrmMoney(item.pendingAmount)),
                ],
              ],
            ),
    );
  }

  Widget _entries(CrmCustomerLedger ledger) {
    final entries = ledger.entries;
    final visible = entries.skip((_entryPage - 1) * kCrmListPageSize).take(kCrmListPageSize).toList();
    return CrmCard(
      title: 'crm.receivables.entries_title'.tr(),
      child: entries.isEmpty
          ? Text('crm.receivables.entries_empty'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in visible) ...[
                  if (e != visible.first) const Divider(height: 16, color: CrmColors.divider),
                  Row(
                    children: [
                      CrmStatusPill(label: crmEntryKindLabel(e.kind), tone: crmEntryKindTone(e.kind), dense: true),
                      const SizedBox(width: 8),
                      Text(formatCrmDay(e.entryDate), style: const TextStyle(fontSize: 12, color: CrmColors.muted)),
                      const Spacer(),
                      Text(
                        e.amount > 0
                            ? '+${formatCrmMoney(e.amount)}'
                            : e.amount < 0
                            ? '-${formatCrmMoney(-e.amount)}'
                            : '',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: e.amount > 0 ? CrmColors.text : CrmColors.success,
                        ),
                      ),
                    ],
                  ),
                  if ((e.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(e.description!, style: const TextStyle(fontSize: 13, color: CrmColors.body)),
                  ],
                  if (e.reference.isNotEmpty || e.dueDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (e.reference.isNotEmpty) e.reference,
                        if (e.dueDate != null) 'crm.receivables.due_on'.tr(args: {'date': formatCrmDay(e.dueDate)}),
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                    ),
                  ],
                ],
                CrmPagerBar(
                  page: _entryPage,
                  total: entries.length,
                  pageSize: kCrmListPageSize,
                  noun: 'crm.receivables.noun_entry'.tr(),
                  alwaysShowSummary: false,
                  onChanged: (p) => setState(() => _entryPage = p),
                ),
              ],
            ),
    );
  }
}
