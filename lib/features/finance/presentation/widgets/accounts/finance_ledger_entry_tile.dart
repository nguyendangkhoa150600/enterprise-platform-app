import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_labels.dart';
import '../common/finance_ui.dart';

/// Một bút toán trong "Sổ tài khoản" (web `LedgerDrawer`: Ngày · Phiếu · Phát sinh · Số dư sau).
class FinanceLedgerEntryTile extends StatelessWidget {
  final FinanceLedgerEntry entry;
  final VoidCallback onTap;
  const FinanceLedgerEntryTile({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final amountText = '${e.amount > 0 ? '+' : ''}${formatFinanceMoney(e.amount)}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            FinanceKindIcon(kind: e.voucherKind, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: e.voucherCode),
                      if (e.isReversal)
                        TextSpan(
                          text: ' ${'finance.accounts.ledger_reversal'.tr()}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFDC2626)),
                        ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: FinanceColors.primary),
                  ),
                  const SizedBox(height: 2),
                  Text('${formatFinanceDate(e.postedDate)} · ${e.voucherKind.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Cột số tiền bám mép phải; phần thông tin bên trái (Expanded) lấy hết chỗ còn lại.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(amountText,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: e.amount < 0 ? const Color(0xFFDC2626) : const Color(0xFF047857))),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text('finance.accounts.ledger_balance_after'.tr(args: {'amount': formatFinanceMoney(e.balanceAfter)}),
                        style: const TextStyle(fontSize: 11.5, color: FinanceColors.muted)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
