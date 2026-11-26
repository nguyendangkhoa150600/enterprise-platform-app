import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/platform_models.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../widgets/user_avatar.dart';

/// Clean User Account Card for Admin & User Management
class UserAccountCard extends StatelessWidget {
  final TenantUser user;

  /// Tên các vai trò của người dùng (TenantUser không kèm vai trò; nơi gọi tải qua `getUserRoleIds`).
  final List<String> roles;
  final VoidCallback? onAssignRole;
  final VoidCallback? onToggleStatus;

  const UserAccountCard({
    super.key,
    required this.user,
    this.roles = const [],
    this.onAssignRole,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user.status.toUpperCase() == 'ACTIVE';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Full Name, Email, Status Badge
          Row(
            children: [
              UserAvatar(
                userId: user.id,
                name: user.fullName,
                size: 40,
                background: isActive ? AppColors.primaryLight : AppColors.slate200,
                foreground: isActive ? AppColors.primary : AppColors.slate600,
                fontSize: 13,
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
                customLabel: isActive ? 'org_widgets.user.active'.tr() : 'org_widgets.user.locked'.tr(),
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
                        roles.isNotEmpty ? roles.join(', ') : 'org_widgets.user.no_roles'.tr(),
                        style: AppTextStyles.caption.copyWith(
                          color: roles.isNotEmpty ? AppColors.primaryDark : AppColors.slate400,
                          fontWeight: roles.isNotEmpty ? FontWeight.bold : FontWeight.normal,
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
                  label: Text('org_widgets.user.assign_role'.tr(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
