import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/hrm_models.dart';
import '../../../shared/widgets/app_card.dart';

/// Card for Position / Job Description Catalog
class PositionJdCard extends StatelessWidget {
  final HrmPositionItem position;
  final VoidCallback onTap;

  const PositionJdCard({
    super.key,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasJd = position.hasJd;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title, Code, and JD Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        position.title,
                        style: AppTextStyles.h3.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        position.code,
                        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: hasJd ? AppColors.successBg : AppColors.warningBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: hasJd ? AppColors.emerald200 : AppColors.warningBorder),
                ),
                child: Text(
                  hasJd ? 'hrm_widgets.position.has_jd'.tr() : 'hrm_widgets.position.no_jd'.tr(),
                  style: AppTextStyles.badge.copyWith(
                    color: hasJd ? AppColors.successFg : AppColors.warningFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Department / Unit & Salary Grade
          Row(
            children: [
              const Icon(Icons.business_outlined, size: 13, color: AppColors.slate400),
              const SizedBox(width: 4),
              Text(
                position.department,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate600),
              ),
              if (position.salaryGrade != null && position.salaryGrade!.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.purpleBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'hrm_widgets.position.grade'.tr(args: {'grade': position.salaryGrade}),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.purpleFg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 8),

          // Row 3: Active Employees Count & View Detail Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined, size: 14, color: AppColors.slate500),
                  const SizedBox(width: 5),
                  Text(
                    'hrm_widgets.position.active_holders'.tr(args: {'count': position.activeEmployeeCount}),
                    style: AppTextStyles.caption.copyWith(color: AppColors.slate600),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('hrm_widgets.position.jd_detail'.tr(), style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  const Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
