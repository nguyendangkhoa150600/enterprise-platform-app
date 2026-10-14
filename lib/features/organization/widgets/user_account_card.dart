import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/platform_models.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_status_badge.dart';

/// Clean User Account Card for Admin & User Management
class UserAccountCard extends StatelessWidget {
  final TenantUser user;
  final VoidCallback? onAssignRole;
  final VoidCallback? onToggleStatus;

  const UserAccountCard({
    super.key,
    required this.user,
    this.onAssignRole,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user.status.toUpperCase() == 'ACTIVE';
    final initials = user.fullName.trim().split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join().toUpperCase();

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Full Name, Email, Status Badge
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isActive ? AppColors.primaryLight : AppColors.slate200,
                child: Text(
                  initials.isNotEmpty ? initials : 'U',
                  style: AppTextStyles.h3.copyWith(
                    color: isActive ? AppColors.primary : AppColors.slate600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: AppTextStyles.h3.copyWith(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppStatusBadge(
                status: user.status,
                customLabel: isActive ? 'Hoạt động' : 'Tạm khóa',
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 8),

          // Row 2: Role Badges & Assign Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.security_outlined, size: 14, color: AppColors.slate500),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        user.roles.isNotEmpty ? user.roles.join(', ') : 'Chưa phân vai trò',
                        style: AppTextStyles.caption.copyWith(
                          color: user.roles.isNotEmpty ? AppColors.primaryDark : AppColors.slate400,
                          fontWeight: user.roles.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (onAssignRole != null)
                TextButton.icon(
                  onPressed: onAssignRole,
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 14),
                  label: const Text('Gán vai trò', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
