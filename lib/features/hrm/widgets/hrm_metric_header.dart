import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Top Overview Metric Cards for HRM Directory
class HrmMetricHeader extends StatelessWidget {
  final int totalEmployees;
  final int probationCount;
  final int totalPositions;
  final String? thirdTitle;
  final String? thirdSubtitle;
  final int? thirdCount;
  final IconData? thirdIcon;
  final VoidCallback? onTotalTap;
  final VoidCallback? onProbationTap;
  final VoidCallback? onPositionsTap;

  const HrmMetricHeader({
    super.key,
    required this.totalEmployees,
    required this.probationCount,
    required this.totalPositions,
    this.thirdTitle,
    this.thirdSubtitle,
    this.thirdCount,
    this.thirdIcon,
    this.onTotalTap,
    this.onProbationTap,
    this.onPositionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              title: 'hrm_widgets.metric.total_staff'.tr(),
              count: '$totalEmployees',
              subtitle: 'common.active'.tr(),
              icon: Icons.people_alt_rounded,
              iconColor: AppColors.primary,
              iconBgColor: AppColors.primaryLight,
              onTap: onTotalTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              title: 'hrm_widgets.metric.probation'.tr(),
              count: '$probationCount',
              subtitle: 'hrm_widgets.metric.needs_review'.tr(),
              icon: Icons.hourglass_top_rounded,
              iconColor: AppColors.warningFg,
              iconBgColor: AppColors.warningBg,
              onTap: onProbationTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              title: thirdTitle ?? 'hrm_widgets.metric.decisions'.tr(),
              count: '${thirdCount ?? totalPositions}',
              subtitle: thirdSubtitle ?? 'hrm_widgets.metric.appointments_transfers'.tr(),
              icon: thirdIcon ?? Icons.description_outlined,
              iconColor: AppColors.emerald600,
              iconBgColor: AppColors.emerald50,
              onTap: onPositionsTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 14, color: iconColor),
                ),
                Text(
                  count,
                  style: AppTextStyles.h2.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.caption.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: AppColors.slate700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.slate400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
