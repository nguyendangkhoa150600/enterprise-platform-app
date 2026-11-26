import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/rcsi_board_helpers.dart';

/// Bảng màu vai trò, khớp `.roleS…roleI` của `rcsi-board.module.scss`.
class RcsiRolePalette {
  final Color foreground;
  final Color background;
  final Color border;

  const RcsiRolePalette(this.foreground, this.background, this.border);

  static const Map<String, RcsiRolePalette> _byRole = {
    'S': RcsiRolePalette(Color(0xFF854D0E), Color(0xFFFEF9C3), Color(0xFFFDE68A)),
    'R': RcsiRolePalette(Color(0xFF1E40AF), Color(0xFFDBEAFE), Color(0xFFBFDBFE)),
    'E': RcsiRolePalette(Color(0xFF9A3412), Color(0xFFFFEDD5), Color(0xFFFED7AA)),
    'C': RcsiRolePalette(Color(0xFF5B21B6), Color(0xFFEDE9FE), Color(0xFFDDD6FE)),
    'A': RcsiRolePalette(Color(0xFF166534), Color(0xFFDCFCE7), Color(0xFFBBF7D0)),
    'I': RcsiRolePalette(Color(0xFF374151), Color(0xFFF3F4F6), Color(0xFFE5E7EB)),
  };

  static RcsiRolePalette of(String role) => _byRole[role] ?? _byRole['I']!;
}

/// Ô chữ vai trò (S/R/E/C/A/I) tô màu theo vai.
class RcsiRoleBadge extends StatelessWidget {
  final String role;
  final double size;

  const RcsiRoleBadge(this.role, {super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final palette = RcsiRolePalette.of(role);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role,
        style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w800, color: palette.foreground),
      ),
    );
  }
}

/// Nhãn trạng thái quy trình (Nháp / Đã công bố / Lưu trữ), màu như web.
class RcsiStatusBadge extends StatelessWidget {
  final String status;

  const RcsiStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (fg, bg, border) = switch (status) {
      'draft' => (const Color(0xFF92400E), const Color(0xFFFEF3C7), const Color(0xFFFDE68A)),
      'published' => (const Color(0xFF166534), const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)),
      _ => (const Color(0xFF475569), const Color(0xFFF1F5F9), const Color(0xFFCBD5E1)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rcsiStatusLabelKey(status).tr(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Thẻ nhỏ một dòng (SLA, số thuộc tính, vật tư…).
class RcsiTag extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;

  const RcsiTag(
    this.text, {
    super.key,
    this.color = AppColors.slate600,
    this.background = AppColors.slate100,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner lỗi / thông báo của thao tác (web: khối `error`/`notice` của ModuleShell).
class RcsiBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback onClose;
  final VoidCallback? onRetry;

  const RcsiBanner({super.key, required this.message, required this.onClose, this.isError = true, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final fg = isError ? AppColors.errorFg : AppColors.primaryDark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorBg : AppColors.primaryLight,
        border: Border.all(color: isError ? AppColors.errorBorder : AppColors.primaryBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isError)
                  Text(
                    'procedure.rcsi.error.title'.tr(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
                  ),
                Text(message, style: TextStyle(fontSize: 12.5, color: fg)),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text('procedure.rcsi.common.retry'.tr())),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: fg),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Khung bottom sheet chuẩn của RCSI: tay kéo, tiêu đề, phụ đề, nút đóng, nội dung cuộn.
class RcsiSheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final Widget? leading;

  const RcsiSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate900),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                    tooltip: 'procedure.rcsi.common.close'.tr(),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(child: child),
            if (footer != null) ...[
              const Divider(height: 1, color: AppColors.border),
              SafeArea(
                top: false,
                child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: footer!),
              ),
            ] else
              SizedBox(height: media.padding.bottom),
          ],
        ),
      ),
    );
  }
}

/// Mở một bottom sheet RCSI (nền trắng, bo góc trên, cuộn theo nội dung).
Future<T?> showRcsiSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: builder,
    );

/// Ô tìm kiếm dùng chung của các sheet RCSI.
class RcsiSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  const RcsiSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13.5),
        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.slate400),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.slate400),
                tooltip: 'procedure.rcsi.common.clear_search'.tr(),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: AppColors.slate50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
