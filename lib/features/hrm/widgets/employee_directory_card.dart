import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/hrm_models.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_status_badge.dart';

/// Rich Employee Card used in HRM Directory
class EmployeeDirectoryCard extends StatelessWidget {
  final HrmEmployeeItem employee;
  final VoidCallback onTap;
  final VoidCallback onActionTap;

  const EmployeeDirectoryCard({
    super.key,
    required this.employee,
    required this.onTap,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = employee.status;
    final isProbation = status.toUpperCase().contains('PROBATION') || status.toUpperCase().contains('THỬ VIỆC');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Name, Code, Status & Menu Dot Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isProbation ? AppColors.warningBg : AppColors.primaryLight,
                child: Text(
                  employee.avatarInitials,
                  style: AppTextStyles.h3.copyWith(
                    color: isProbation ? AppColors.warningFg : AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            employee.fullName,
                            style: AppTextStyles.h3.copyWith(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            employee.code,
                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${employee.position} • ${employee.department}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppStatusBadge(
                    status: status,
                    customLabel: isProbation ? 'hrm_widgets.employee_card.probation'.tr() : 'hrm_widgets.employee_card.official'.tr(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppColors.slate400),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onActionTap,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 8),

          // Row 2: Join Date & Progress/Completion Rate
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.slate400),
                  const SizedBox(width: 5),
                  Text(
                    'hrm_widgets.employee_card.hire_date'.tr(args: {'date': Formatters.formatDate(employee.hireDate)}),
                    style: AppTextStyles.caption.copyWith(color: AppColors.slate500),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'hrm_widgets.employee_card.profile_rate'.tr(args: {'rate': employee.completionRate}),
                    style: AppTextStyles.caption.copyWith(
                      color: employee.completionRate >= 80 ? AppColors.emerald600 : AppColors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 48,
                    height: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: employee.completionRate / 100.0,
                        backgroundColor: AppColors.slate200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          employee.completionRate >= 80 ? AppColors.emerald600 : AppColors.amber,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
