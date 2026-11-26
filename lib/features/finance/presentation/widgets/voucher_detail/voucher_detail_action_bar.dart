import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../common/finance_ui.dart';

enum VoucherActionStyle { primary, danger, outline }

/// Một thao tác trên phiếu (hiện khi quyền server cho phép).
class VoucherDetailAction {
  final String label;
  final IconData icon;
  final VoucherActionStyle style;
  final VoidCallback onPressed;
  const VoucherDetailAction({required this.label, required this.icon, required this.onPressed, this.style = VoucherActionStyle.outline});
}

/// Thanh thao tác dính đáy: tối đa 2 nút hiện, còn lại nằm trong bảng ⋯.
class VoucherDetailActionBar extends StatelessWidget {
  final List<VoucherDetailAction> actions;
  final bool busy;
  const VoucherDetailActionBar({super.key, required this.actions, required this.busy});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final List<VoucherDetailAction> visible;
    final List<VoucherDetailAction> overflow;
    if (actions.length <= 2) {
      visible = actions;
      overflow = const [];
    } else {
      // Ưu tiên nút chính (Ghi sổ / Gửi duyệt / Duyệt), giữ thứ tự của web.
      final ranked = [
        ...actions.where((a) => a.style == VoucherActionStyle.primary),
        ...actions.where((a) => a.style != VoucherActionStyle.primary),
      ];
      final shown = ranked.take(2).toSet();
      visible = actions.where(shown.contains).toList();
      overflow = actions.where((a) => !shown.contains(a)).toList();
    }
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: FinanceColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (overflow.isNotEmpty) ...[
              SizedBox(
                width: 44,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: FinanceColors.border),
                  ),
                  onPressed: busy ? null : () => _showMore(context, overflow),
                  child: const Icon(Icons.more_horiz_rounded, color: FinanceColors.text),
                ),
              ),
              const SizedBox(width: 8),
            ],
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _button(visible[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _button(VoucherDetailAction a) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(a.icon, size: 18),
        const SizedBox(width: 6),
        Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
    final onPressed = busy ? null : a.onPressed;
    return SizedBox(
      height: 44,
      child: switch (a.style) {
        VoucherActionStyle.primary => FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FinanceColors.primary, shape: shape),
            onPressed: onPressed,
            child: child),
        VoucherActionStyle.danger => FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: shape),
            onPressed: onPressed,
            child: child),
        VoucherActionStyle.outline => OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: FinanceColors.text, shape: shape, side: const BorderSide(color: FinanceColors.border)),
            onPressed: onPressed,
            child: child),
      },
    );
  }

  Future<void> _showMore(BuildContext context, List<VoucherDetailAction> items) async {
    final picked = await showModalBottomSheet<VoucherDetailAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('finance.voucher_detail.more_actions'.tr(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: FinanceColors.text)),
            ),
            for (final a in items)
              ListTile(
                leading: Icon(a.icon,
                    color: a.style == VoucherActionStyle.danger ? const Color(0xFFDC2626) : FinanceColors.text),
                title: Text(a.label,
                    style: TextStyle(
                        fontSize: 14,
                        color: a.style == VoucherActionStyle.danger ? const Color(0xFFDC2626) : FinanceColors.text)),
                onTap: () => Navigator.pop(ctx, a),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    picked?.onPressed();
  }
}
