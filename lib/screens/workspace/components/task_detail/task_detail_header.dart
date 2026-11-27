import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';
import 'task_detail_format.dart';

/// Một mắt của đường dẫn: dự án hoặc một cấp cha "CODE · tiêu đề".
class TaskDetailCrumb {
  final String label;
  final VoidCallback? onTap;
  const TaskDetailCrumb(this.label, this.onTap);
}

/// Khối đầu của công việc (web `node-header.tsx`): đường dẫn bấm được, loại, mã + tiêu đề,
/// huy hiệu trạng thái (chỉ xem) và ưu tiên, rồi thanh thao tác: bên trái việc cần làm
/// (thao tác nhanh, thêm việc con), bên phải thao tác phụ (trao đổi, sửa, ⋯).
class TaskDetailHeader extends StatelessWidget {
  final StandaloneTaskItem item;
  final List<TaskDetailCrumb> crumbs;
  /// Nhãn loại ("Công việc", "Nhóm công việc"...); null thì không hiện.
  final String? kindLabel;
  /// Dòng phụ dưới tiêu đề (Công việc khác: "Vai của bạn: ...").
  final String? subtitle;
  final List<Widget> primaryActions;
  final List<Widget> secondaryActions;

  const TaskDetailHeader({
    super.key,
    required this.item,
    required this.crumbs,
    this.kindLabel,
    this.subtitle,
    this.primaryActions = const [],
    this.secondaryActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (crumbs.isNotEmpty) ...[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              for (final c in crumbs) ...[
                InkWell(
                  onTap: c.onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      c.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kTaskMuted),
                    ),
                  ),
                ),
                const Text('›', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ],
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            if (kindLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  kindLabel!.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155), letterSpacing: 0.5),
                ),
              ),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${item.code}  ',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTaskMuted),
                ),
                TextSpan(text: item.title),
              ]),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTaskInk),
            ),
            TaskPill(label: item.statusLabel, tone: taskStatusTone(item)),
            TaskPill(label: item.priorityLabel, tone: taskPriorityTone(item.priority)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(fontSize: 12, color: kTaskMuted)),
        ],
        if (primaryActions.isNotEmpty || secondaryActions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              if (primaryActions.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: primaryActions),
              if (secondaryActions.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: secondaryActions),
            ],
          ),
        ],
      ],
    );
  }
}

/// Nút của thanh thao tác: `filled` là nút chính (vàng như web), còn lại viền.
/// Chiều cao chung của các nút thao tác ở đầu chi tiết công việc (kể cả nút "⋯"), để cùng thẳng hàng.
const double kTaskActionHeight = 36;

class TaskActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;
  final int badge;

  const TaskActionButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.filled = false,
    this.danger = false,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? (filled ? Colors.white : kTaskDanger) : (filled ? kTaskInk : const Color(0xFF334155));
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 5)],
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
        if (badge > 0) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: kTaskDanger, borderRadius: BorderRadius.circular(999)),
            child: Text('$badge', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: danger ? kTaskDanger : const Color(0xFFEAB308),
          elevation: 0,
          padding: padding,
          minimumSize: const Size(0, kTaskActionHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: shape,
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: danger ? const Color(0xFFFECACA) : const Color(0xFFCBD5E1)),
        padding: padding,
        minimumSize: const Size(0, kTaskActionHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: shape,
      ),
      child: child,
    );
  }
}

/// Dải đầu xanh của hộp: nút "← CODE" quay lại việc trước (nếu có), tiêu đề, nút đóng.
class TaskDetailTopBar extends StatelessWidget {
  final String heading;
  final String? backLabel;
  final VoidCallback? onBack;
  const TaskDetailTopBar({super.key, required this.heading, this.backLabel, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF1D4ED8),
      child: Row(
        children: [
          if (backLabel != null && onBack != null) ...[
            Tooltip(
              message: 'workspace.task_detail.back_to'.tr(args: {'code': backLabel!}),
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 15, color: Colors.white),
                label: Text(backLabel!,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              heading,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: 'workspace.task_detail.close'.tr(),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
