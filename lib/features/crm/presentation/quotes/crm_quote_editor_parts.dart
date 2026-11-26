import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/quotes/crm_quote_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_quote_logic.dart';

/// Màn lập mới vừa tạo báo giá bằng nút +: mở chọn mặt hàng ngay khi màn báo giá tải xong (web `openPickerAfterLoad`).
({String quoteId, String search})? crmQuotePickerAfterOpen;

/// Thanh nút dưới màn (web `QuoteActionBar`): Huỷ / Lưu / Trình duyệt / Báo giá; Huỷ khi có thay đổi chưa lưu thì hỏi.
class CrmQuoteActionBar extends StatelessWidget {
  final Widget? summary;
  final bool dirty;
  final bool busy;
  final bool canCancel;
  final bool canSave;
  final bool canSubmit;
  final bool canSend;
  final String? submitHint;
  final String? cancelMessage;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onSubmit;
  final VoidCallback onSend;

  const CrmQuoteActionBar({
    super.key,
    this.summary,
    required this.dirty,
    required this.busy,
    this.canCancel = false,
    required this.canSave,
    required this.canSubmit,
    required this.canSend,
    this.submitHint,
    this.cancelMessage,
    required this.onCancel,
    required this.onSave,
    required this.onSubmit,
    required this.onSend,
  });

  Future<void> _cancel(BuildContext context) async {
    if (!dirty) return onCancel();
    final ok = await showCrmConfirm(
      context,
      title: 'crm.quotes.bar.discard_title'.tr(),
      message: cancelMessage ?? 'crm.quotes.bar.discard_message'.tr(),
      confirmLabel: 'crm.quotes.bar.discard'.tr(),
      danger: true,
    );
    if (ok) onCancel();
  }

  @override
  Widget build(BuildContext context) {
    Widget button(String label, VoidCallback? onPressed, {bool primary = false}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: primary
            ? FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CrmColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onPressed,
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onPressed,
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
      ),
    );
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (summary != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: summary!),
              Row(
                children: [
                  button('crm.common.cancel'.tr(), busy || (!dirty && !canCancel) ? null : () => _cancel(context)),
                  button('crm.common.save'.tr(), busy || !canSave ? null : onSave),
                  Expanded(
                    child: Tooltip(
                      message: canSubmit ? '' : (submitHint ?? ''),
                      child: Row(
                        children: [
                          button('crm.quotes.bar.submit'.tr(), busy || !canSubmit ? null : onSubmit, primary: true),
                        ],
                      ),
                    ),
                  ),
                  button('crm.quotes.bar.send'.tr(), busy || !canSend ? null : onSend, primary: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng tổng tiền dưới dòng hàng (web `<dl className={local.totals}>`).
class CrmQuoteTotalsView extends StatelessWidget {
  final CrmQuoteVersion version;
  const CrmQuoteTotalsView({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    final t = version.totals;
    final form = version.form;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: CrmColors.border),
          CrmInfoRow(label: 'crm.quotes.totals.gross'.tr(), value: formatCrmMoney(t.grossAmount), labelWidth: 170),
          CrmInfoRow(
            label: 'crm.quotes.totals.discount'.tr(args: {'p': formatCrmPercent(t.discountPercent)}),
            value: formatCrmMoney(t.discountAmount),
            labelWidth: 170,
          ),
          CrmInfoRow(label: 'crm.quotes.totals.net'.tr(), value: formatCrmMoney(t.netAmount), labelWidth: 170),
          if (t.shippingAmount != 0)
            CrmInfoRow(
              label: 'crm.quotes.totals.shipping'.tr(args: {'p': formatCrmPercent(version.shipping.vatRate)}),
              value: formatCrmMoney(t.shippingAmount),
              labelWidth: 170,
            ),
          if (form.discountMode == 'ORDER' && form.orderDiscount.inputKind != null)
            CrmInfoRow(
              label: 'crm.quotes.totals.order_discount'.tr(args: {'p': formatCrmPercent(form.orderDiscount.percent)}),
              value: formatCrmMoney(form.orderDiscount.amount),
              labelWidth: 170,
            ),
          if (form.taxMode == 'ORDER' && form.orderTax.inputKind != null)
            CrmInfoRow(
              label: 'crm.quotes.totals.order_tax'.tr(args: {'p': formatCrmPercent(form.orderTax.percent)}),
              value: formatCrmMoney(form.orderTax.amount),
              labelWidth: 170,
            ),
          for (final fee in form.fees)
            CrmInfoRow(
              label: 'crm.quotes.totals.fee'.tr(
                args: {'name': fee.feeType.isEmpty ? 'crm.quotes.totals.fee_default'.tr() : fee.feeType},
              ),
              value: formatCrmMoney(fee.amount),
              labelWidth: 170,
            ),
          CrmInfoRow(label: 'crm.quotes.totals.vat'.tr(), value: formatCrmMoney(t.vatAmount), labelWidth: 170),
          CrmInfoRow(
            label: 'crm.quotes.totals.total'.tr(),
            labelWidth: 170,
            child: Text(
              formatCrmMoney(t.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CrmColors.text),
            ),
          ),
          if (!version.costHidden) ...[
            CrmInfoRow(label: 'crm.quotes.totals.est_cost'.tr(), value: formatCrmMoney(t.estCost), labelWidth: 170),
            CrmInfoRow(
              label: 'crm.quotes.totals.profit'.tr(),
              value:
                  '${formatCrmMoney(t.profit)}${t.marginPercent == null ? '' : ' (${'crm.quotes.totals.margin'.tr()} ${formatCrmPercent(t.marginPercent)})'}',
              labelWidth: 170,
            ),
          ],
        ],
      ),
    );
  }
}

/// Lịch sử duyệt và nhật ký (web khối "Lịch sử").
class CrmQuoteHistoryView extends StatelessWidget {
  final CrmQuoteDetail detail;
  const CrmQuoteHistoryView({super.key, required this.detail});

  Widget _entry(CrmQuoteHistoryEntry e, {bool withStatus = false}) {
    final scope = CrmScope.instance;
    final status = withStatus && e.toStatus != null && CrmQuoteStatus.values.contains(e.toStatus)
        ? ': ${crmQuoteStatusLabel(e.toStatus!)}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5, right: 10),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: CrmColors.primary, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${crmQuoteHistoryLabel(e.action)}${e.versionNo == null ? '' : ' v${e.versionNo}'}$status',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if ((e.reason ?? '').isNotEmpty)
                  Text(e.reason!, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
                Text(
                  '${formatCrmDateTime(e.at)} · ${e.actorId == null ? 'crm.quotes.system'.tr() : scope.personName(e.actorId)}',
                  style: const TextStyle(fontSize: 11.5, color: CrmColors.faint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final approvals = detail.history.where((e) => const ['submit', 'approve', 'reject'].contains(e.action)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmSectionTitle('crm.quotes.history.approvals'.tr()),
        if (approvals.isEmpty)
          Text('crm.quotes.history.not_submitted'.tr(), style: const TextStyle(fontSize: 12.5, color: CrmColors.muted))
        else
          for (final e in approvals) _entry(e, withStatus: true),
        const SizedBox(height: 8),
        CrmSectionTitle('crm.quotes.history.log'.tr()),
        for (final e in detail.history) _entry(e),
      ],
    );
  }
}
