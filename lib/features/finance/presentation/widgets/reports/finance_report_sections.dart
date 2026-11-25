import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';

/// Tỷ lệ % như web: làm tròn 1 chữ số lẻ, total ≤ 0 → '-'.
String _share(double amount, double total) {
  if (total <= 0) return '-';
  final v = (amount / total * 1000).round() / 10;
  return v == v.roundToDouble() ? '${v.toInt()}%' : '$v%';
}

/// Bảng phân tích theo hạng mục (web `Breakdown`): mỗi dòng một thẻ nhỏ với thanh tỷ lệ.
class FinanceReportBreakdown extends StatelessWidget {
  final String title;
  final List<FinanceBreakdownRow> rows;
  final double total;
  final Color color;

  const FinanceReportBreakdown({
    super.key,
    required this.title,
    required this.rows,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: title,
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('finance.reports.breakdown_empty'.tr(),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: FinanceColors.muted)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('finance.reports.col_item'.tr(), style: _head)),
                    Text('finance.reports.col_count'.tr(), style: _head),
                    const SizedBox(width: 12),
                    Text('finance.reports.col_amount'.tr(), style: _head),
                  ],
                ),
                const Divider(height: 12, color: FinanceColors.border),
                for (final row in rows) _row(row),
              ],
            ),
    );
  }

  static const _head = TextStyle(fontSize: 11.5, color: FinanceColors.muted, fontWeight: FontWeight.w500);

  Widget _row(FinanceBreakdownRow row) {
    final ratio = total > 0 ? (row.amount / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: FinanceColors.text)),
              ),
              const SizedBox(width: 8),
              Text('${row.count}', style: const TextStyle(fontSize: 12.5, color: FinanceColors.muted)),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(formatFinanceMoney(row.amount),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FinanceColors.text)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(_share(row.amount, total),
                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: FinanceColors.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Biến động tài khoản": mỗi tài khoản một thẻ.
class FinanceAccountMovementCard extends StatelessWidget {
  final List<FinanceAccountMovement> accounts;
  const FinanceAccountMovementCard({super.key, required this.accounts});

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: 'finance.reports.accounts_title'.tr(),
      // Web: bảng rỗng vẫn hiện (chỉ tiêu đề), không có dòng "không có dữ liệu".
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < accounts.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: FinanceColors.border),
            _account(accounts[i]),
          ],
        ],
      ),
    );
  }

  Widget _account(FinanceAccountMovement a) {
    Widget cell(String label, double value, {Color? color, bool bold = false}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: FinanceColors.muted)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatFinanceMoney(value),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                        color: color ?? FinanceColors.text)),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(a.accountName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: FinanceColors.text)),
        const SizedBox(height: 8),
        Row(children: [
          cell('finance.reports.opening_balance'.tr(), a.openingBalance),
          cell('finance.reports.receipts'.tr(), a.receipts, color: FinanceColors.income),
          cell('finance.reports.payments'.tr(), a.payments, color: const Color(0xFFDC2626)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          cell('finance.reports.transfers_in'.tr(), a.transfersIn),
          cell('finance.reports.transfers_out'.tr(), a.transfersOut),
          cell('finance.reports.closing_balance'.tr(), a.closingBalance, bold: true),
        ]),
      ],
    );
  }
}
