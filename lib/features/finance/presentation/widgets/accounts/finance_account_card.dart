import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_labels.dart';
import '../common/finance_ui.dart';

/// Một dòng của bảng "Danh sách tài khoản" (web `AccountsScreen` columns) dạng thẻ.
class FinanceAccountCard extends StatelessWidget {
  final FinanceAccount account;

  /// Mở "Sổ tài khoản".
  final VoidCallback onLedger;

  /// Sửa tài khoản; null khi không có quyền quản lý.
  final VoidCallback? onEdit;

  /// Bấm số phiếu thu/chi/chuyển: mở danh sách phiếu loại đó của tài khoản (null = không bấm được).
  final ValueChanged<FinanceVoucherKind>? onOpenKind;

  const FinanceAccountCard({super.key, required this.account, required this.onLedger, this.onEdit, this.onOpenKind});

  VoidCallback? _tap(FinanceVoucherKind kind) {
    final open = onOpenKind;
    return open == null ? null : () => open(kind);
  }

  @override
  Widget build(BuildContext context) {
    final a = account;
    final subtitle = a.accountType == FinanceAccountType.cash ? FinanceAccountType.cash.shortLabel : (a.accountNumber ?? '');
    final balance = a.balance;
    return FinanceCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                child: Icon(a.accountType.icon, size: 19, color: FinanceColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
                    if (a.accountType == FinanceAccountType.bank && (a.bankName ?? '').isNotEmpty)
                      Text(a.bankName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
                    const SizedBox(height: 4),
                    _ActiveBadge(active: a.isActive),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'finance.accounts.ledger'.tr(),
                icon: const Icon(Icons.menu_book_outlined, size: 20, color: Color(0xFF475569)),
                onPressed: onLedger,
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'common.edit'.tr(),
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF475569)),
                  onPressed: onEdit,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    _Count(label: 'finance.accounts.col_receipts'.tr(), value: a.receiptCount, onTap: _tap(FinanceVoucherKind.receipt)),
                    _Count(label: 'finance.accounts.col_payments'.tr(), value: a.paymentCount, onTap: _tap(FinanceVoucherKind.payment)),
                    _Count(label: 'finance.accounts.col_transfers'.tr(), value: a.transferCount, onTap: _tap(FinanceVoucherKind.transfer)),
                  ],
                ),
                const Divider(height: 18, color: FinanceColors.border),
                _MoneyRow(
                  label: 'finance.accounts.col_opening'.tr(),
                  value: a.openingBalance != 0 ? formatFinanceMoney(a.openingBalance) : '--',
                ),
                _MoneyRow(label: 'finance.accounts.col_total_receipts'.tr(), value: _money(a.totalReceipts)),
                _MoneyRow(label: 'finance.accounts.col_total_payments'.tr(), value: _money(a.totalPayments)),
                _MoneyRow(
                  label: 'finance.accounts.col_balance'.tr(),
                  value: _money(balance),
                  bold: true,
                  color: (balance ?? 0) < 0 ? const Color(0xFFDC2626) : FinanceColors.text,
                ),
                if ((a.pendingOut ?? 0) != 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('finance.accounts.pending_out'.tr(args: {'amount': formatFinanceMoney(a.pendingOut!)}),
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Web `money(null)` hiện '-' khi người xem không có quyền xem số dư.
  static String _money(double? v) => v == null ? '-' : formatFinanceMoney(v);
}

class _ActiveBadge extends StatelessWidget {
  final bool active;
  const _ActiveBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(active ? 'finance.accounts.status_active'.tr() : 'finance.accounts.status_inactive'.tr(),
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF047857) : FinanceColors.muted)),
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int? value;
  final VoidCallback? onTap;
  const _Count({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Web: chỉ số > 0 mới là liên kết (chữ xanh link) mở danh sách phiếu.
    final link = (value ?? 0) > 0 && onTap != null;
    return Expanded(
      child: InkWell(
        onTap: link ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Text(value?.toString() ?? '-',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: link ? FontWeight.w700 : FontWeight.w500,
                    color: link ? const Color(0xFF1D4ED8) : FinanceColors.muted,
                    decoration: link ? TextDecoration.underline : null,
                    decorationColor: const Color(0xFF1D4ED8))),
            Text(label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: FinanceColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color color;
  const _MoneyRow({required this.label, required this.value, this.bold = false, this.color = FinanceColors.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: FinanceColors.muted))),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(value,
                  style: TextStyle(
                      fontSize: bold ? 14.5 : 13,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                      color: color)),
            ),
          ),
        ],
      ),
    );
  }
}
