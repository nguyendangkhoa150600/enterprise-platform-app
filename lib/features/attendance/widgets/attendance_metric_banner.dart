import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/hrm_attendance_models.dart';

/// Top Overview Metric Banner for Monthly Attendance Summary
class AttendanceMetricBanner extends StatelessWidget {
  final MonthlyAttendanceSummary summary;
  final VoidCallback? onLateTap;
  final VoidCallback? onLeaveTap;

  const AttendanceMetricBanner({
    super.key,
    required this.summary,
    this.onLateTap,
    this.onLeaveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkNavy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title & Month Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'att_widgets.banner.monthly_summary'.tr(args: {'month': summary.monthYear.toUpperCase()}),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.slate400,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${summary.actualWorkDays}',
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.emerald,
                          fontSize: 24,
                        ),
                      ),
                      Text(
                        'att_widgets.banner.standard_days'.tr(args: {'days': summary.totalWorkDays}),
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate300),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.slate800,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slate700),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: AppColors.emerald),
                    const SizedBox(width: 5),
                    Text(
                      'att_widgets.banner.work_hours'.tr(args: {'hours': summary.totalWorkHours}),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.slate800),
          const SizedBox(height: 12),

          // Row 2: Sub Metrics (Đi muộn / Về sớm, Nghỉ phép, Làm thêm OT)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSubMetric(
                label: 'att_widgets.banner.late_early'.tr(),
                value: 'att_widgets.banner.times'.tr(args: {'count': summary.lateDays + summary.earlyLeaveDays}),
                isWarning: (summary.lateDays + summary.earlyLeaveDays) > 0,
                onTap: onLateTap,
              ),
              _buildSubMetric(
                label: 'att_widgets.banner.leave'.tr(),
                value: 'att_widgets.banner.days'.tr(args: {'count': summary.leaveDays}),
                onTap: onLeaveTap,
              ),
              _buildSubMetric(
                label: 'att_widgets.banner.overtime'.tr(),
                value: '${summary.totalOvertimeHours}h',
                isSuccess: summary.totalOvertimeHours > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubMetric({
    required String label,
    required String value,
    bool isWarning = false,
    bool isSuccess = false,
    VoidCallback? onTap,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.slate400)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isWarning
                ? AppColors.amber
                : isSuccess
                    ? AppColors.emerald
                    : Colors.white,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: content,
        ),
      );
    }

    return content;
  }
}
