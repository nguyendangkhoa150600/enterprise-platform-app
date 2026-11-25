import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import 'task_detail_format.dart';

/// Khung "Vướng mắc" (web `BlockedReasonNotice`): lý do hoặc "Chưa ghi lý do";
/// nút "Ghi lý do"/"Sửa lý do" chỉ khi có [onEdit].
class TaskBlockedNotice extends StatelessWidget {
  final String? reason;
  final VoidCallback? onEdit;
  const TaskBlockedNotice({super.key, this.reason, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final text = reason?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: kTaskDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('workspace.task_detail.blocked_notice.label'.tr(),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                const SizedBox(height: 3),
                Text(
                  text.isNotEmpty ? text : 'workspace.task_detail.blocked_notice.empty'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: text.isNotEmpty ? const Color(0xFFB91C1C) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                (text.isNotEmpty ? 'workspace.task_detail.blocked_notice.edit' : 'workspace.task_detail.blocked_notice.write')
                    .tr(),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: kTaskDanger),
              ),
            ),
        ],
      ),
    );
  }
}

/// Liên kết chữ nhỏ trong thông báo (mã công việc bấm được).
class TaskInlineLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  const TaskInlineLink(this.label, {super.key, this.onTap, this.color = const Color(0xFF1D4ED8)});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: onTap == null ? kTaskMuted : color,
          decoration: onTap == null ? null : TextDecoration.underline,
        ),
      ),
    );
  }
}

/// Khối "Đã huỷ hiệu lực" của việc dự án (web `node-header.tsx`).
class TaskReversalNotice extends StatelessWidget {
  final String? reversedByName;
  final DateTime? reversedAt;
  final String? reason;
  /// Công việc điều chỉnh còn hiệu lực (mã + mở), nếu có.
  final String? adjustmentCode;
  final VoidCallback? onOpenAdjustment;
  final bool adjustmentRequested;

  const TaskReversalNotice({
    super.key,
    this.reversedByName,
    this.reversedAt,
    this.reason,
    this.adjustmentCode,
    this.onOpenAdjustment,
    this.adjustmentRequested = false,
  });

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF7C2D12);
    const strong = Color(0xFF9A3412);
    const body = TextStyle(fontSize: 13, color: ink, height: 1.5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('workspace.task_detail.reversal.title'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: strong)),
          const SizedBox(height: 3),
          Text(
            '${reversedByName ?? 'workspace.task_detail.reversal.admin'.tr()} · ${taskFormatDateTime(reversedAt)}',
            style: TextStyle(fontSize: 12, color: strong.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 3),
          Text.rich(TextSpan(children: [
            TextSpan(text: '${'workspace.task_detail.reversal.reason'.tr()} ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: reason ?? ''),
          ]), style: body),
          if (adjustmentCode != null) ...[
            const SizedBox(height: 3),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${'workspace.task_detail.reversal.adjustment'.tr()} ',
                  style: body.copyWith(fontWeight: FontWeight.bold)),
              TaskInlineLink(adjustmentCode!, onTap: onOpenAdjustment),
            ]),
          ] else if (adjustmentRequested) ...[
            const SizedBox(height: 3),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${'workspace.task_detail.reversal.adjustment_label'.tr()} ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: 'workspace.task_detail.reversal.adjustment_pending'.tr()),
            ]), style: body),
          ],
        ],
      ),
    );
  }
}

/// "Công việc điều chỉnh cho CODE đã huỷ hiệu lực." — [code] null thì "một công việc".
class TaskAdjustmentOfNotice extends StatelessWidget {
  final String? code;
  final VoidCallback? onOpen;
  /// Công việc khác: "(đã huỷ hiệu lực)." thay vì "đã huỷ hiệu lực.".
  final bool standalone;
  const TaskAdjustmentOfNotice({super.key, this.code, this.onOpen, this.standalone = false});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13, color: kTaskMuted);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${'workspace.task_detail.adjustment_of.prefix'.tr()} ', style: style),
        if (code != null)
          TaskInlineLink(code!, onTap: onOpen)
        else
          Text('workspace.task_detail.adjustment_of.unknown'.tr(), style: style),
        Text(
          ' ${(standalone ? 'workspace.task_detail.adjustment_of.suffix_standalone' : 'workspace.task_detail.adjustment_of.suffix').tr()}',
          style: style,
        ),
      ],
    );
  }
}

/// Dòng thông báo của Công việc khác (web `styles.notice` / `styles.alert`).
class TaskNotice extends StatelessWidget {
  final Widget child;
  final bool alert;
  const TaskNotice({super.key, required this.child, this.alert = false});

  factory TaskNotice.text(String text, {bool alert = false}) => TaskNotice(
        alert: alert,
        child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.4, color: alert ? const Color(0xFF991B1B) : const Color(0xFF1E3A8A))),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: alert ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alert ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE)),
      ),
      child: child,
    );
  }
}
