import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Standardized Status Badge used across HRM, Attendance, Payroll, and Admin
class AppStatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const AppStatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase().trim();
    String label = customLabel ?? 'CHÍNH THỨC';
    Color bg = AppColors.successBg;
    Color fg = AppColors.successFg;
    Color? border;

    if (s == 'PROBATION' || s.contains('THỬ VIỆC')) {
      label = customLabel ?? 'THỬ VIỆC';
      bg = AppColors.warningBg;
      fg = AppColors.warningFg;
      border = AppColors.warningBorder;
    } else if (s == 'PENDING' || s == 'WAITING' || s.contains('CHỜ DUYỆT') || s.contains('CHỜ XỬ LÝ')) {
      label = customLabel ?? 'CHỜ DUYỆT';
      bg = AppColors.warningBg;
      fg = AppColors.warningFg;
      border = AppColors.warningBorder;
    } else if (s == 'APPROVED' || s == 'OFFICIAL' || s == 'ACTIVE' || s == 'PAID' || s.contains('ĐÃ DUYỆT') || s.contains('ĐÃ CHI TRẢ')) {
      label = customLabel ?? (s == 'PAID' ? 'ĐÃ CHI TRẢ' : 'CHÍNH THỨC');
      bg = AppColors.successBg;
      fg = AppColors.successFg;
      border = const Color(0xFFA7F3D0);
    } else if (s == 'REJECTED' || s == 'TERMINATED' || s == 'CANCELLED' || s.contains('TỪ CHỐI') || s.contains('CHẤM DỨT')) {
      label = customLabel ?? 'TỪ CHỐI';
      bg = AppColors.errorBg;
      fg = AppColors.errorFg;
      border = AppColors.errorBorder;
    } else if (s == 'SUSPENDED' || s == 'ON_LEAVE' || s == 'LEAVE' || s.contains('TẠM NGHỈ') || s.contains('NGHỈ PHÉP')) {
      label = customLabel ?? 'TẠM NGHỈ';
      bg = AppColors.purpleBg;
      fg = AppColors.purpleFg;
      border = AppColors.purpleBorder;
    } else if (s == 'INACTIVE' || s == 'RESIGNED' || s.contains('ĐÃ NGHỈ')) {
      label = customLabel ?? 'ĐÃ NGHỈ VIỆC';
      bg = AppColors.slate100;
      fg = AppColors.slate500;
      border = AppColors.slate300;
    } else if (customLabel != null) {
      label = customLabel!;
      bg = AppColors.slate100;
      fg = AppColors.slate700;
    }

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: border != null ? Border.all(color: border, width: 0.8) : null,
      ),
      child: Text(
        label,
        style: AppTextStyles.badge.copyWith(
          color: fg,
          fontSize: fontSize ?? 9.5,
        ),
      ),
    );
  }
}
