import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/rcsi_flow_models.dart';

/// Báo cáo kiểm tra trước khi công bố (popup `report` của web): liệt kê hết lỗi
/// và cảnh báo. Chỉ có cảnh báo và người dùng được công bố thì có nút "Vẫn công bố".
/// Trả true khi người dùng chọn "Vẫn công bố".
Future<bool> showRcsiValidationReportDialog(
  BuildContext context, {
  required ProcedureValidationReport report,
  required bool canPublish,
}) async {
  final hasErrors = report.errors.isNotEmpty;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasErrors ? 'procedure.rcsi.report.title_blocked'.tr() : 'procedure.rcsi.report.title_check'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            hasErrors
                ? 'procedure.rcsi.report.subtitle_errors'.tr(args: {'count': report.errors.length})
                : 'procedure.rcsi.report.subtitle_warnings'.tr(),
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate500, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final issue in report.errors) _IssueTile(issue: issue, isError: true),
            for (final issue in report.warnings) _IssueTile(issue: issue, isError: false),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('procedure.rcsi.common.close'.tr()),
        ),
        if (!hasErrors && canPublish)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('procedure.rcsi.report.publish_anyway'.tr()),
          ),
      ],
    ),
  );
  return result ?? false;
}

class _IssueTile extends StatelessWidget {
  final ProcedureValidationIssue issue;
  final bool isError;

  const _IssueTile({required this.issue, required this.isError});

  @override
  Widget build(BuildContext context) {
    final fg = isError ? AppColors.errorFg : AppColors.warningFg;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorBg : AppColors.warningBg,
        border: Border.all(color: isError ? AppColors.errorBorder : AppColors.warningBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(issue.message, style: TextStyle(fontSize: 13, color: fg))),
        ],
      ),
    );
  }
}
