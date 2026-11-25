import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_labels.dart';

/// Bộ khối giao diện dùng chung của module Tài chính, để mọi màn cùng một kiểu (đồng bộ công văn/workspace):
/// nền slate-50, thẻ trắng bo 12 viền slate-200, chữ slate-900/500, nút chính xanh #2563EB.
class FinanceColors {
  static const Color bg = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color faint = Color(0xFF94A3B8);
  static const Color primary = Color(0xFF2563EB);
  static const Color income = Color(0xFF059669);
  static const Color expense = Color(0xFFE11D48);
  static const Color warning = Color(0xFFD97706);
}

/// AppBar trắng chuẩn của các màn Tài chính.
PreferredSizeWidget financeAppBar(BuildContext context, String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) {
  return AppBar(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: FinanceColors.text)),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    iconTheme: const IconThemeData(color: FinanceColors.text),
    actions: actions,
    bottom: bottom ??
        const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: FinanceColors.border),
        ),
  );
}

/// Thẻ khối nội dung có tiêu đề (tuỳ chọn) và nút bên phải.
class FinanceCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const FinanceCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: FinanceColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FinanceColors.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(title!,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                  )
                else
                  const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

/// Nhãn trạng thái phiếu (màu theo web `FINANCE_STATUS_STYLE`).
class FinanceStatusBadge extends StatelessWidget {
  final FinanceVoucherStatus status;
  final bool dense;
  const FinanceStatusBadge({super.key, required this.status, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final t = status.tone;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: dense ? 10.5 : 11.5,
          fontWeight: FontWeight.w600,
          color: t.fg,
          decoration: status == FinanceVoucherStatus.cancelled ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

/// Ô biểu tượng loại phiếu (thu/chi/chuyển).
class FinanceKindIcon extends StatelessWidget {
  final FinanceVoucherKind kind;
  final double size;
  const FinanceKindIcon({super.key, required this.kind, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: kind.softColor, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(kind.icon, size: size * 0.5, color: kind.color),
    );
  }
}

/// Số tiền có màu: thu (+) xanh, chi (−) đỏ; [signed] = hiện dấu.
class FinanceAmountText extends StatelessWidget {
  final double amount;
  final FinanceVoucherKind? kind;
  final bool signed;
  final double fontSize;
  final FontWeight fontWeight;

  const FinanceAmountText({
    super.key,
    required this.amount,
    this.kind,
    this.signed = false,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      FinanceVoucherKind.receipt => FinanceColors.income,
      FinanceVoucherKind.payment => FinanceColors.expense,
      FinanceVoucherKind.transfer => const Color(0xFF0284C7),
      null => amount < 0 ? FinanceColors.expense : FinanceColors.text,
    };
    final sign = !signed
        ? ''
        : kind == FinanceVoucherKind.receipt
            ? '+'
            : kind == FinanceVoucherKind.payment
                ? '−'
                : '';
    return Text(
      '$sign${formatFinanceMoney(amount)}',
      style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// Thẻ số liệu nhỏ (KPI): nhãn, giá trị, ghi chú phụ.
class FinanceStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const FinanceStatTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FinanceColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: iconColor ?? FinanceColors.muted),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: FinanceColors.muted, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: valueColor ?? FinanceColors.text)),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(hint!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: FinanceColors.faint)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Trạng thái tải / lỗi (kèm "Thử lại") / rỗng, đặt giữa màn hình.
class FinanceStateView extends StatelessWidget {
  final bool loading;
  final String? error;
  final String? emptyText;
  final IconData emptyIcon;
  final VoidCallback? onRetry;

  const FinanceStateView({
    super.key,
    this.loading = false,
    this.error,
    this.emptyText,
    this.emptyIcon = Icons.inbox_outlined,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(strokeWidth: 2.5, color: FinanceColors.primary),
        ),
      );
    }
    final isError = error != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isError ? Icons.error_outline_rounded : emptyIcon,
                size: 44, color: isError ? const Color(0xFFF87171) : FinanceColors.faint),
            const SizedBox(height: 10),
            Text(
              error ?? emptyText ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: FinanceColors.muted, height: 1.4),
            ),
            if (isError && onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('common.retry'.tr()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thanh chọn tháng "‹ Tháng 11/2026 ›" (bấm giữa để chọn tháng bất kỳ).
class FinanceMonthBar extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  const FinanceMonthBar({super.key, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FinanceColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'finance.common.prev_month'.tr(),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded, color: FinanceColors.muted),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: month,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDatePickerMode: DatePickerMode.year,
                  helpText: 'finance.common.pick_month'.tr(),
                );
                if (picked != null) onChanged(DateTime(picked.year, picked.month));
              },
              child: Center(
                child: Text(formatFinanceMonth(month),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: FinanceColors.text)),
              ),
            ),
          ),
          IconButton(
            tooltip: 'finance.common.next_month'.tr(),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded, color: FinanceColors.muted),
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}

/// Chip lọc (bo tròn, chọn thì nền xanh nhạt), kèm số đếm tuỳ chọn.
class FinanceFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int? count;
  final VoidCallback onTap;

  const FinanceFilterChip({super.key, required this.label, required this.selected, required this.onTap, this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? const Color(0xFFBFDBFE) : FinanceColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? FinanceColors.primary : const Color(0xFF475569),
                  )),
              if (count != null) ...[
                const SizedBox(width: 5),
                Text('$count',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? FinanceColors.primary : FinanceColors.faint)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dòng "Nhãn ............ Giá trị" trong thẻ thông tin.
class FinanceInfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;
  const FinanceInfoRow({super.key, required this.label, this.value, this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: FinanceColors.muted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: child ??
                Text((value == null || value!.isEmpty) ? '—' : value!,
                    style: const TextStyle(fontSize: 13, color: FinanceColors.text, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Hộp xác nhận chuẩn. Trả true khi người dùng đồng ý.
Future<bool> showFinanceConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmLabel,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
      content: message == null ? null : Text(message, style: const TextStyle(fontSize: 13.5, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? const Color(0xFFDC2626) : FinanceColors.primary),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? 'common.confirm'.tr()),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Hộp nhập lý do (huỷ, từ chối, trả hồ sơ...). Trả chuỗi đã trim, null khi bấm Huỷ.
/// [required] = bắt buộc nhập mới bấm được nút xác nhận.
Future<String?> showFinanceReasonPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String? label,
  String? hint,
  String? confirmLabel,
  bool required = true,
  bool danger = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _ReasonDialog(
      title: title,
      message: message,
      label: label,
      hint: hint,
      confirmLabel: confirmLabel,
      required: required,
      danger: danger,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String? label;
  final String? hint;
  final String? confirmLabel;
  final bool required;
  final bool danger;

  const _ReasonDialog({
    required this.title,
    this.message,
    this.label,
    this.hint,
    this.confirmLabel,
    required this.required,
    required this.danger,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !widget.required || _ctrl.text.trim().isNotEmpty;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(widget.title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(widget.message!, style: const TextStyle(fontSize: 13.5, height: 1.4)),
              const SizedBox(height: 12),
            ],
            if (widget.label != null) ...[
              Text(widget.label!,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
            ],
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.hint,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('common.cancel'.tr())),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: widget.danger ? const Color(0xFFDC2626) : FinanceColors.primary),
          onPressed: canSubmit ? () => Navigator.pop(context, _ctrl.text.trim()) : null,
          child: Text(widget.confirmLabel ?? 'common.confirm'.tr()),
        ),
      ],
    );
  }
}

/// Màn chặn khi người dùng không có quyền mở trang (web `canOpenPage` = false; khung vàng của finance-shell).
class FinanceNoAccessView extends StatelessWidget {
  const FinanceNoAccessView({super.key});

  @override
  Widget build(BuildContext context) => FinanceNoticeView(
        title: 'finance.common.no_access_title'.tr(),
        message: 'finance.common.no_access'.tr(),
      );
}

/// Khung thông báo có tiêu đề như web finance-shell: vàng (chặn quyền) hoặc đỏ ([danger], lỗi tải quyền).
class FinanceNoticeView extends StatelessWidget {
  final String title;
  final String message;
  final bool danger;
  final VoidCallback? onRetry;

  const FinanceNoticeView({super.key, required this.title, required this.message, this.danger = false, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final bg = danger ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final border = danger ? const Color(0xFFFECACA) : const Color(0xFFFDE68A);
    final fg = danger ? const Color(0xFFB91C1C) : const Color(0xFF92400E);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(message, style: TextStyle(fontSize: 13.5, color: fg, height: 1.45)),
              ],
            ],
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('common.retry'.tr()),
            ),
          ),
        ],
      ],
    );
  }
}
