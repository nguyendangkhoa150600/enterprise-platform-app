import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';

/// Nút "Tạo phiếu thu / Tạo phiếu chi / Tạo phiếu chuyển tiền" (chỉ các loại được phép lập).
class FinanceQuickCreateBar extends StatelessWidget {
  final List<FinanceVoucherKind> kinds;
  final ValueChanged<FinanceVoucherKind> onCreate;
  const FinanceQuickCreateBar({super.key, required this.kinds, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in kinds)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: Colors.white,
              foregroundColor: FinanceColors.text,
              side: const BorderSide(color: FinanceColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => onCreate(kind),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('finance.dashboard.create_${kind.api.toLowerCase()}'.tr()),
          ),
      ],
    );
  }
}

/// Lưới 2 cột cho các ô số liệu.
class FinanceKpiGrid extends StatelessWidget {
  final List<Widget> tiles;
  const FinanceKpiGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 10),
              Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
      ));
    }
    return Column(children: rows);
  }
}

/// Thẻ "Số dư tài khoản" (web dashboard): tên · số dư (âm tô đỏ) · "Chờ chi …".
class FinanceDashboardBalances extends StatelessWidget {
  final List<FinanceDashboardAccount> accounts;
  final VoidCallback onViewAll;
  const FinanceDashboardBalances({super.key, required this.accounts, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: 'finance.dashboard.balances_title'.tr(),
      trailing: TextButton(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        onPressed: onViewAll,
        child: Text('finance.dashboard.view_all'.tr(), style: const TextStyle(fontSize: 12.5)),
      ),
      child: accounts.isEmpty
          ? _Empty(text: 'finance.dashboard.no_accounts'.tr())
          : Column(
              children: [
                for (var i = 0; i < accounts.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _BalanceRow(account: accounts[i]),
                ],
              ],
            ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final FinanceDashboardAccount account;
  const _BalanceRow({required this.account});

  @override
  Widget build(BuildContext context) {
    final balance = account.balance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(account.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: FinanceColors.text)),
          ),
          const SizedBox(width: 8),
          // Số dư bám mép phải; tên tài khoản (Expanded) lấy phần còn lại.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(balance == null ? '-' : formatFinanceMoney(balance),
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: (balance ?? 0) < 0 ? const Color(0xFFDC2626) : FinanceColors.text)),
                ),
                if ((account.pendingOut ?? 0) != 0)
                  Text('finance.dashboard.pending_out'.tr(args: {'amount': formatFinanceMoney(account.pendingOut!)}),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ "Phiếu gần đây": mã · nội dung · số tiền · trạng thái; chạm để mở phiếu.
class FinanceDashboardRecent extends StatelessWidget {
  final List<FinanceVoucherSummary> vouchers;
  final ValueChanged<FinanceVoucherSummary> onOpen;
  const FinanceDashboardRecent({super.key, required this.vouchers, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: 'finance.dashboard.recent_title'.tr(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: vouchers.isEmpty
          ? _Empty(text: 'finance.dashboard.no_vouchers'.tr())
          : Column(
              children: [
                for (var i = 0; i < vouchers.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _RecentRow(voucher: vouchers[i], onTap: () => onOpen(vouchers[i])),
                ],
              ],
            ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final FinanceVoucherSummary voucher;
  final VoidCallback onTap;
  const _RecentRow({required this.voucher, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            FinanceKindIcon(kind: v.kind, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: FinanceColors.primary)),
                  if (v.content.isNotEmpty)
                    Text(v.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(formatFinanceMoney(v.totalAmount),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: FinanceColors.text)),
                  ),
                ),
                const SizedBox(height: 3),
                FinanceStatusBadge(status: v.status, dense: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: FinanceColors.muted)),
      );
}
