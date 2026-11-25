import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';

/// Thẻ "Tổng kết kỳ" (web: 4 ô số liệu + dòng tổng tiền đã duyệt trong bộ lọc).
class VoucherListSummary extends StatelessWidget {
  final FinanceVoucherList data;
  const VoucherListSummary({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    int c(FinanceVoucherStatus s) => data.statusCounts[s] ?? 0;
    double a(FinanceVoucherStatus s) => data.statusAmounts[s] ?? 0;
    final total = data.statusCounts.values.fold<int>(0, (sum, n) => sum + n);
    String count(int n) => 'finance.voucher_list.count_vouchers'.tr(args: {'count': n});

    final tiles = [
      FinanceStatTile(label: 'finance.voucher_list.summary_total'.tr(), value: count(total)),
      FinanceStatTile(
        label: 'finance.voucher_list.summary_approved'.tr(),
        value: count(c(FinanceVoucherStatus.approved)),
        hint: formatFinanceMoney(a(FinanceVoucherStatus.approved)),
      ),
      FinanceStatTile(
        label: 'finance.voucher_list.summary_pending'.tr(),
        value: count(c(FinanceVoucherStatus.pending)),
        hint: formatFinanceMoney(a(FinanceVoucherStatus.pending)),
      ),
      FinanceStatTile(
        label: 'finance.voucher_list.summary_open'.tr(),
        value: count(c(FinanceVoucherStatus.draft) + c(FinanceVoucherStatus.rejected)),
        hint: formatFinanceMoney(a(FinanceVoucherStatus.draft) + a(FinanceVoucherStatus.rejected)),
      ),
    ];

    return FinanceCard(
      title: 'finance.voucher_list.summary_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 8), Expanded(child: tiles[1])]),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 8), Expanded(child: tiles[3])]),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('finance.voucher_list.approved_total'.tr(),
                    style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(formatFinanceMoney(data.approvedTotal),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
