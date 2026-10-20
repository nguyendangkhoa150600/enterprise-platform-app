import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_status_badge.dart';

/// Card for displaying individual Shift Assignment in the Roster / Timesheet
class ShiftAssignmentCard extends StatelessWidget {
  final ShiftAssignment assignment;
  final VoidCallback? onTap;

  const ShiftAssignmentCard({
    super.key,
    required this.assignment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = assignment.status;
    final isAssigned = status.toUpperCase() == 'ASSIGNED' || status.toUpperCase() == 'OFFICIAL';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          // Shift Icon indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isAssigned ? AppColors.primaryLight : AppColors.slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: isAssigned ? AppColors.primary : AppColors.slate500,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Date, Shift Title, Time Range
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.formatDate(assignment.workDate),
                      style: AppTextStyles.h3.copyWith(fontSize: 13.5),
                    ),
                    AppStatusBadge(
                      status: status,
                      customLabel: isAssigned ? 'ĐÃ GÁN CA' : status,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  assignment.shiftName ?? 'Ca hành chính chuẩn (08:00 - 17:30)',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
