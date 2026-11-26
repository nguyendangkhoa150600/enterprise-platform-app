import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';

/// Bộ khối giao diện dùng chung của CRM (cùng kiểu Tài chính/Kho): nền slate-50, thẻ trắng bo 12 viền slate-200,
/// chữ slate-900/500, nút chính xanh #2563EB (web `colorPrimary`).
class CrmColors {
  CrmColors._();
  static const Color bg = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color text = Color(0xFF0F172A);
  static const Color body = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color faint = Color(0xFF94A3B8);
  static const Color primary = Color(0xFF2563EB);
  static const Color primarySoft = Color(0xFFEFF6FF);
  static const Color link = Color(0xFF1D4ED8);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
}

/// AppBar trắng chuẩn của các màn CRM.
PreferredSizeWidget crmAppBar(
  BuildContext context,
  String title, {
  String? subtitle,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    title: subtitle == null
        ? Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: CrmColors.text),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: CrmColors.text),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: CrmColors.muted),
              ),
            ],
          ),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    iconTheme: const IconThemeData(color: CrmColors.text),
    actions: actions,
    bottom:
        bottom ??
        const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: CrmColors.border),
        ),
  );
}

/// Thẻ khối nội dung có tiêu đề (tuỳ chọn), nút bên phải; [onTap] → thẻ bấm được (thay hàng bảng của web).
class CrmCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const CrmCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
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
                    child: Text(
                      title!,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: CrmColors.text),
                    ),
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
    return Padding(
      padding: margin,
      child: Material(
        color: CrmColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: CrmColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Tông màu nhãn trạng thái (web `StatusPill` tone).
enum CrmTone {
  neutral(Color(0xFFF1F5F9), Color(0xFFE2E8F0), Color(0xFF475569)),
  info(Color(0xFFEFF6FF), Color(0xFFBFDBFE), Color(0xFF1D4ED8)),
  success(Color(0xFFECFDF5), Color(0xFFA7F3D0), Color(0xFF047857)),
  warning(Color(0xFFFFFBEB), Color(0xFFFDE68A), Color(0xFFB45309)),
  danger(Color(0xFFFEF2F2), Color(0xFFFECACA), Color(0xFFB91C1C));

  const CrmTone(this.bg, this.border, this.fg);
  final Color bg;
  final Color border;
  final Color fg;
}

/// Nhãn trạng thái dạng chấm màu (web `StatusPill`, không dùng emoji).
class CrmStatusPill extends StatelessWidget {
  final String label;
  final CrmTone tone;
  final bool dense;
  const CrmStatusPill({super.key, required this.label, this.tone = CrmTone.neutral, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dense ? 5 : 6,
            height: dense ? 5 : 6,
            decoration: BoxDecoration(color: tone.fg, shape: BoxShape.circle),
          ),
          SizedBox(width: dense ? 4 : 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: dense ? 10.5 : 11.5, fontWeight: FontWeight.w600, color: tone.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Huy hiệu nhỏ dạng mã (web `badge` của ô chọn: mã nhóm, mã kho…).
class CrmCodeBadge extends StatelessWidget {
  final String text;
  const CrmCodeBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: CrmColors.divider, borderRadius: BorderRadius.circular(6)),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: CrmColors.muted,
        fontFamily: 'monospace',
      ),
    ),
  );
}

/// Dòng "Nhãn ......... Giá trị" trong thẻ thông tin (thay cột bảng/ô mô tả của web).
class CrmInfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;
  final double labelWidth;
  const CrmInfoRow({super.key, required this.label, this.value, this.child, this.labelWidth = 120});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                child ??
                Text(
                  (value == null || value!.isEmpty) ? '—' : value!,
                  style: const TextStyle(fontSize: 13, color: CrmColors.text, fontWeight: FontWeight.w500),
                ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ số liệu nhỏ (KPI): nhãn, giá trị, ghi chú phụ; [onTap] mở trang liên quan.
class CrmStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final Color? hintColor;
  final Color? valueColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const CrmStatTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.hintColor,
    this.valueColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CrmColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[Icon(icon, size: 16, color: CrmColors.muted), const SizedBox(width: 6)],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: CrmColors.muted, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: valueColor ?? CrmColors.text),
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: hintColor ?? CrmColors.faint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề nhóm nhỏ trong danh sách/biểu mẫu.
class CrmSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const CrmSectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: CrmColors.muted,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Nút chính/phụ chuẩn (nút "Lưu" đổi thành vòng quay khi [busy]).
class CrmButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool outlined;
  final bool danger;

  const CrmButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    this.outlined = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? CrmColors.danger : CrmColors.primary;
    final child = busy
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? color : Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final action = busy ? null : onPressed;
    if (outlined) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: danger ? const Color(0xFFFECACA) : CrmColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: action,
        child: child,
      );
    }
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: action,
      child: child,
    );
  }
}

/// Hiện thông báo ngắn (thành công/lỗi) dưới màn hình.
void showCrmSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB91C1C) : CrmColors.text,
    ),
  );
}

/// Nhãn "Chưa có" / "—" cho ô trống.
String crmDash(String? value) => (value == null || value.trim().isEmpty) ? '—' : value;

/// Chuỗi "Đang lưu…" chuẩn.
String crmSavingLabel() => 'crm.common.saving'.tr();
