import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import 'crm_ui.dart';

/// Trạng thái tải / lỗi (kèm "Thử lại") / rỗng, đặt giữa vùng nội dung.
class CrmStateView extends StatelessWidget {
  final bool loading;
  final String? error;
  final String? emptyText;
  final IconData emptyIcon;
  final VoidCallback? onRetry;

  const CrmStateView({
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
          child: CircularProgressIndicator(strokeWidth: 2.5, color: CrmColors.primary),
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
            Icon(
              isError ? Icons.error_outline_rounded : emptyIcon,
              size: 44,
              color: isError ? const Color(0xFFF87171) : CrmColors.faint,
            ),
            const SizedBox(height: 10),
            Text(
              error ?? emptyText ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: CrmColors.muted, height: 1.4),
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

/// Kiểu hộp thông báo trong trang.
enum CrmBannerKind { error, warning, info, success }

/// Hộp báo lỗi / lưu ý trong trang (web `<p role="alert" className={styles.alert}>` / `notice`).
class CrmBanner extends StatelessWidget {
  final String message;
  final CrmBannerKind kind;
  final Widget? action;
  final EdgeInsetsGeometry margin;

  const CrmBanner({
    super.key,
    required this.message,
    this.kind = CrmBannerKind.error,
    this.action,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (kind) {
      CrmBannerKind.error => (const Color(0xFFFEF2F2), const Color(0xFFFECACA), const Color(0xFFB91C1C)),
      CrmBannerKind.warning => (const Color(0xFFFFFBEB), const Color(0xFFFDE68A), const Color(0xFF92400E)),
      CrmBannerKind.info => (const Color(0xFFEFF6FF), const Color(0xFFBFDBFE), const Color(0xFF1E40AF)),
      CrmBannerKind.success => (const Color(0xFFECFDF5), const Color(0xFFA7F3D0), const Color(0xFF065F46)),
    };
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13, color: fg, height: 1.4)),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

/// Khung thông báo toàn trang có tiêu đề: vàng (chặn quyền / đang khởi tạo) hoặc đỏ ([danger], lỗi tải).
class CrmNoticeView extends StatelessWidget {
  final String title;
  final String message;
  final bool danger;
  final VoidCallback? onRetry;

  const CrmNoticeView({super.key, required this.title, required this.message, this.danger = false, this.onRetry});

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
              Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
              ),
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
