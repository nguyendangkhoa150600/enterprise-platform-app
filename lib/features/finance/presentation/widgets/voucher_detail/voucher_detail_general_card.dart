import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_labels.dart';
import '../common/finance_ui.dart';
import 'voucher_detail_parts.dart';

const _k = 'finance.voucher_detail';

/// Khối "Thông tin chung" (web section `Thông tin chung`).
class VoucherGeneralCard extends StatelessWidget {
  final FinanceVoucher voucher;

  /// Hồ sơ nguồn (chỉ khi approvalMode INHERITED) để hiện khoá trên trường lấy từ hồ sơ.
  final FinanceVoucherSource? source;

  const VoucherGeneralCard({super.key, required this.voucher, this.source});

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final kind = v.kind;
    bool locked(String f) => voucherFieldLocked(source, f);
    final isTransfer = kind == FinanceVoucherKind.transfer;
    return FinanceCard(
      title: '$_k.general'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VoucherDetailFieldPair(
            left: VoucherDetailField(label: kind.label('date_label'), value: formatFinanceDate(v.voucherDate)),
            right: VoucherDetailField(label: '$_k.posting_date'.tr(), value: formatFinanceDate(v.postingDate)),
          ),
          VoucherDetailField(
            label: '$_k.amount'.tr(),
            locked: locked('amount'),
            child: Text(formatFinanceMoney(v.totalAmount),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: FinanceColors.text,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
          VoucherDetailField(label: kind.label('content_label'), value: v.content, locked: locked('content')),
          if (isTransfer)
            VoucherDetailFieldPair(
              left: VoucherDetailField(label: kind.label('account_label'), value: v.accountName),
              right: VoucherDetailField(label: '$_k.dest_account'.tr(), value: v.destAccountName),
            )
          else ...[
            VoucherDetailFieldPair(
              left: VoucherDetailField(label: kind.label('reason_label'), value: v.reasonName),
              right: VoucherDetailField(label: kind.label('account_label'), value: v.accountName),
            ),
            VoucherDetailFieldPair(
              left: VoucherDetailField(label: kind.label('counterparty_label'), value: v.counterpartyGroupName),
              right: VoucherDetailField(
                  label: kind.label('person_label'), value: v.counterpartyName, locked: locked('counterpartyName')),
            ),
            VoucherDetailFieldPair(
              left: VoucherDetailField(
                  label: kind.label('person_account_label'),
                  value: v.counterpartyAccountNo,
                  locked: locked('counterpartyAccountNo')),
              right: VoucherDetailField(
                  label: kind.label('person_bank_label'), value: v.counterpartyBank, locked: locked('counterpartyBank')),
            ),
            VoucherDetailField(
              label: '$_k.allocation'.tr(),
              locked: locked('allocation'),
              value: v.allocation == null ? null : '${'$_k.allocation_project'.tr()}: ${v.allocation!.label}',
            ),
          ],
          VoucherDetailFieldPair(
            left: VoucherDetailField(label: '$_k.created_by'.tr(), value: v.createdByName),
            right: VoucherDetailField(label: '$_k.created_at'.tr(), value: formatFinanceDateTime(v.createdAt)),
          ),
          if (v.decisionNote != null && v.decisionNote!.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: FinanceColors.bg, borderRadius: BorderRadius.circular(8)),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: v.status == FinanceVoucherStatus.rejected
                        ? '$_k.reject_reason_prefix'.tr()
                        : '$_k.decision_note_prefix'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: v.decisionNote),
                ]),
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

/// Khối chi tiết dòng + hoá đơn (web bảng `detailTitle`), mỗi dòng là một thẻ nhỏ.
class VoucherLinesCard extends StatelessWidget {
  final FinanceVoucher voucher;
  const VoucherLinesCard({super.key, required this.voucher});

  static const _num = TextStyle(fontSize: 13, color: FinanceColors.text, fontFeatures: [FontFeature.tabularFigures()]);
  static const _muted = TextStyle(fontSize: 12, color: FinanceColors.muted);

  String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : formatFinanceMoney(q);

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    return FinanceCard(
      title: v.kind.label('detail_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (v.lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('$_k.lines.empty'.tr(), textAlign: TextAlign.center, style: _muted),
            )
          else ...[
            for (final line in v.lines) _lineRow(line),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('$_k.lines.grand_total'.tr(),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                ),
                Text(formatFinanceMoney(v.totalAmount), style: _num.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
            if (v.taxIncluded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text('$_k.lines.tax_included'.tr(args: {'rate': formatFinanceMoney(v.taxRate)}),
                          style: _muted),
                    ),
                    const SizedBox(width: 8),
                    Text(formatFinanceMoney(v.taxAmount), style: _muted),
                  ],
                ),
              ),
          ],
          if (v.invoices.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('$_k.invoices'.tr(),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            const SizedBox(height: 4),
            for (final inv in v.invoices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        [
                          inv.invoiceNo,
                          if (inv.invoiceDate != null && inv.invoiceDate!.isNotEmpty) formatFinanceDate(inv.invoiceDate),
                          if (inv.taxCode != null && inv.taxCode!.isNotEmpty)
                            '$_k.invoice_tax_code'.tr(args: {'code': inv.taxCode}),
                        ].join(' · '),
                        style: const TextStyle(fontSize: 13, color: FinanceColors.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formatFinanceMoney(inv.amount), style: _num),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _lineRow(FinanceVoucherLine line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FinanceColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(line.description.isEmpty ? '-' : line.description,
                    style: const TextStyle(fontSize: 13.5, color: FinanceColors.text, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              Text(formatFinanceMoney(line.total), style: _num.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${'$_k.lines.quantity'.tr()}: ${_qty(line.quantity)} · ${'$_k.lines.unit_amount'.tr()}: ${formatFinanceMoney(line.unitAmount)}',
            style: _muted,
          ),
        ],
      ),
    );
  }
}
