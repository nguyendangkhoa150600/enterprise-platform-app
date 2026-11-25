import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_labels.dart';
import '../common/finance_ui.dart';

/// Đầu trang chi tiết phiếu: loại phiếu, mã (kèm mã nháp nếu khác), trạng thái, tổng tiền.
class VoucherDetailHeader extends StatelessWidget {
  final FinanceVoucher voucher;
  const VoucherDetailHeader({super.key, required this.voucher});

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final showDraft = v.draftCode != null && v.draftCode!.isNotEmpty && v.draftCode != v.code;
    return FinanceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinanceKindIcon(kind: v.kind, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.kind.name, style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
                const SizedBox(height: 2),
                Text(
                  v.code,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: FinanceColors.text),
                ),
                if (showDraft)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('finance.voucher_detail.draft_code'.tr(args: {'code': v.draftCode}),
                        style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FinanceStatusBadge(status: v.status),
                    if (v.posted && v.status == FinanceVoucherStatus.approved)
                      Text('finance.voucher_detail.posted_to_account'.tr(),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF047857))),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: FinanceAmountText(amount: v.totalAmount, kind: v.kind, fontSize: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
