import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';
import '../../../../utils/user_resolver.dart';
import '../workspace_tag_picker.dart' show getTagColor;
import 'task_detail_format.dart';

/// Dòng thông tin dưới khối đầu (web `node-header.tsx` › `nodeMeta`): phụ trách, cùng thực hiện,
/// kế hoạch, nhãn, số việc lá đã xong trên nhánh, số quá hạn và ô tiến độ.
class TaskDetailMeta extends StatelessWidget {
  final StandaloneTaskItem item;
  final List<StandaloneTaskItem> projectItems;
  /// Danh mục nhãn `{id, name, color}`; nhãn của việc tra theo `tagIds`.
  final List<Map<String, dynamic>> tagCatalog;
  /// Bấm ô tiến độ (báo tiến độ / khối lượng); null là chỉ xem.
  final VoidCallback? onProgressTap;
  /// Lời giải thích khi ô tiến độ bị khoá (web `progressCellMode().reason`).
  final String? progressLockedReason;

  const TaskDetailMeta({
    super.key,
    required this.item,
    required this.projectItems,
    this.tagCatalog = const [],
    this.onProgressTap,
    this.progressLockedReason,
  });

  String _name(String id) => UserResolver.resolveName(id);

  @override
  Widget build(BuildContext context) {
    final branch = taskBranchOf(projectItems, item.id);
    final scope = projectItems.where((i) => branch.contains(i.id) && i.id != item.id).toList();
    final parentIds = scope.map((i) => i.parentId).whereType<String>().toSet();
    final leaves = scope.where((i) => !parentIds.contains(i.id) && i.status != 'cancelled').toList();
    final done = leaves.where((i) => i.status == 'done').length;
    final overdue = scope.where(taskIsOverdue).length;
    final tags = item.tagIds
        .map((id) => tagCatalog.where((t) => t['id']?.toString() == id).firstOrNull)
        .whereType<Map<String, dynamic>>()
        .toList();

    const label = TextStyle(fontSize: 12, color: kTaskMuted);
    const bold = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTaskInk);

    Widget pair(String l, String v) => Text.rich(TextSpan(children: [
          TextSpan(text: '$l ', style: label),
          TextSpan(text: v, style: bold),
        ]));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          pair(
            'workspace.task_detail.meta.assignee'.tr(),
            item.assigneeUserId.isEmpty
                ? 'workspace.task_detail.unassigned'.tr()
                : (item.assigneeName ?? _name(item.assigneeUserId)),
          ),
          if (item.participantUserIds.isNotEmpty)
            pair('workspace.task_detail.meta.participants'.tr(), item.participantUserIds.map(_name).join(', ')),
          pair('workspace.task_detail.meta.plan'.tr(), taskDateRange(item.plannedStart, item.dueDate)),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [
                for (final t in tags)
                  Text(
                    t['name']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: getTagColor(t['name']?.toString() ?? '', t['color']?.toString()),
                    ),
                  ),
              ],
            ),
          Text.rich(TextSpan(children: [
            if (leaves.isNotEmpty) ...[
              TextSpan(text: '$done/${leaves.length}', style: bold),
              TextSpan(text: ' ${'workspace.task_detail.meta.leaves_done'.tr()}', style: label),
            ] else
              TextSpan(text: 'workspace.task_detail.meta.no_children'.tr(), style: label),
            if (overdue > 0)
              TextSpan(
                text: ' · ${'workspace.task_detail.meta.overdue'.tr(args: {'count': overdue})}',
                style: const TextStyle(fontSize: 12, color: kTaskDanger),
              ),
          ])),
          if (item.isReversed)
            Text('workspace.task_detail.meta.not_counted'.tr(), style: label)
          else
            TaskProgressCell(
              item: item,
              onTap: onProgressTap,
              lockedReason: progressLockedReason,
            ),
        ],
      ),
    );
  }
}

/// Ô tiến độ: thanh + số phần trăm; bấm được khi có [onTap], khoá thì giải thích bằng tooltip.
class TaskProgressCell extends StatelessWidget {
  final StandaloneTaskItem item;
  final VoidCallback? onTap;
  final String? lockedReason;
  const TaskProgressCell({super.key, required this.item, this.onTap, this.lockedReason});

  @override
  Widget build(BuildContext context) {
    final pct = item.progressPercent.clamp(0.0, 100.0);
    Widget cell = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              color: const Color(0xFF1D4ED8),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${taskNum(pct.round())}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTaskInk)),
        if (onTap != null) ...[
          const SizedBox(width: 2),
          const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF1D4ED8)),
        ],
      ],
    );
    final semanticsLabel = 'workspace.task_detail.meta.progress_of'.tr(args: {'code': item.code});
    if (onTap != null) {
      cell = InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(2), child: cell));
    } else if (lockedReason != null && lockedReason!.isNotEmpty) {
      cell = Tooltip(message: lockedReason!, triggerMode: TooltipTriggerMode.tap, child: cell);
    }
    return Semantics(label: semanticsLabel, child: cell);
  }
}
