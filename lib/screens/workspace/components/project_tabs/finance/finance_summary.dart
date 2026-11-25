import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_finance_api.dart';
import 'finance_format.dart';

const Color financePositive = Color(0xFF047857);
const Color financeNegative = Color(0xFFB91C1C);

/// Khối "Tổng quan tài chính dự án" của web `tab-finance.tsx`: 4 thẻ KPI, tiến độ thu tiền, phiếu chờ, chi phí ghi tay cũ.
class FinanceSummary extends StatelessWidget {
  final double? contract;
  final double actualCost;

  /// Null khi chưa có số thu chi (đang tải hoặc lỗi) — web chỉ hiện thẻ "Giá trị hợp đồng".
  final ProjectVoucherList? data;
  final VoidCallback onEdit;

  const FinanceSummary({
    super.key,
    required this.contract,
    required this.actualCost,
    required this.data,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final data = this.data;
    final contract = this.contract;
    final contractPositive = contract != null && contract > 0;
    String? percentOfContract(double amount) => contractPositive ? formatPercent(amount / contract * 100) : null;

    final kpis = <Widget>[
      Tooltip(
        message: formatVnd(contract),
        child: _Kpi(
          label: 'workspace.finance.contract_value'.tr(),
          value: formatVndCompact(contract),
          sub: contract == null ? 'workspace.finance.no_contract'.tr() : formatVnd(contract),
          action: TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 13),
            label: Text('workspace.finance.edit'.tr(), style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
    ];

    if (data != null) {
      final t = data.totals;
      final profit = ((t.received - t.paid) * 100).round() / 100;
      final margin = t.received > 0 ? (profit / t.received * 1000).round() / 10 : null;
      final receivedPct = percentOfContract(t.received);
      final paidPct = percentOfContract(t.paid);
      kpis.addAll([
        Tooltip(
          message: 'workspace.finance.received_hint'.tr(args: {'count': t.receiptCount}),
          child: _Kpi(
            label: 'workspace.finance.received'.tr(),
            value: formatVndCompact(t.received),
            sub: receivedPct != null
                ? 'workspace.finance.of_contract'.tr(args: {'percent': receivedPct})
                : 'workspace.finance.receipt_count'.tr(args: {'count': t.receiptCount}),
          ),
        ),
        Tooltip(
          message: 'workspace.finance.paid_hint'.tr(args: {'count': t.paymentCount}),
          child: _Kpi(
            label: 'workspace.finance.paid'.tr(),
            value: formatVndCompact(t.paid),
            sub: paidPct != null
                ? 'workspace.finance.of_contract'.tr(args: {'percent': paidPct})
                : 'workspace.finance.payment_count'.tr(args: {'count': t.paymentCount}),
          ),
        ),
        Tooltip(
          message: 'workspace.finance.profit_hint'.tr(),
          child: _Kpi(
            label: 'workspace.finance.profit'.tr(),
            value: formatVndCompact(profit),
            valueColor: profit < 0 ? financeNegative : (profit != 0 ? financePositive : null),
            sub: margin == null
                ? 'workspace.finance.no_revenue'.tr()
                : 'workspace.finance.margin'.tr(args: {'percent': formatPercent(margin)}),
          ),
        ),
      ]);
    }

    final collected = contractPositive && data != null ? (data.totals.received / contract * 100).clamp(0, 100).toDouble() : 0.0;
    final muted = Theme.of(context).hintColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: financeCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, box) {
            final width = (box.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final kpi in kpis) SizedBox(width: width, child: kpi)],
            );
          }),
          if (data != null) ...[
            const SizedBox(height: 12),
            if (contractPositive)
              Tooltip(
                message: 'workspace.finance.collect_hint'.tr(args: {
                  'received': formatVnd(data.totals.received),
                  'contract': formatVnd(contract),
                }),
                child: Row(
                  children: [
                    Text('workspace.finance.collect_progress'.tr(), style: TextStyle(fontSize: 12, color: muted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: collected / 100, minHeight: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formatPercent(collected), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              Text('workspace.finance.enter_contract_hint'.tr(), style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 8),
            Tooltip(
              message: 'workspace.finance.pending_hint'.tr(),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 12, color: muted),
                  children: [
                    TextSpan(text: '${'workspace.finance.pending_received'.tr()} '),
                    TextSpan(text: formatVnd(data.totals.pendingReceived), style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: ' · ${'workspace.finance.pending_paid'.tr()} '),
                    TextSpan(text: formatVnd(data.totals.pendingPaid), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
          if (actualCost > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                'workspace.finance.legacy_cost'.tr(args: {'amount': formatVnd(actualCost)}),
                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Viền thẻ dùng chung trong tab Tài chính.
BoxDecoration financeCardDecoration(BuildContext context) => BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
    );

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color? valueColor;
  final Widget? action;

  const _Kpi({required this.label, required this.value, required this.sub, this.valueColor, this.action});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: valueColor),
          ),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: muted)),
          if (action != null) Align(alignment: Alignment.centerLeft, child: action),
        ],
      ),
    );
  }
}
