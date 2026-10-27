import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';
import '../../theme/colors.dart';

/// Shown instead of a screen the signed-in user has no permission for.
class NoAccessView extends StatelessWidget {
  final String? message;
  const NoAccessView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 44, color: AppColors.slate400),
            const SizedBox(height: 12),
            Text(
              'perm.no_access_title'.tr(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
            const SizedBox(height: 6),
            Text(
              message ?? 'perm.no_access_hrm'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}
