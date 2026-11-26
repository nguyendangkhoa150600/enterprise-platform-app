import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';

/// Hộp xác nhận (thay Popconfirm của web). Trả true khi người dùng xác nhận.
Future<bool> showRcsiConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(fontSize: 13.5, color: AppColors.slate600)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel ?? 'procedure.rcsi.common.cancel'.tr()),
        ),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.errorFg) : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
