import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';
import '../../../../utils/user_resolver.dart';
import 'task_detail_format.dart';

String _assigneeOf(StandaloneTaskItem item) => item.assigneeUserId.isEmpty
    ? 'workspace.task_detail.unassigned'.tr()
    : (item.assigneeName ?? UserResolver.resolveName(item.assigneeUserId));

/// "Công việc con · done/total" của việc dự án (web `ChildItems`): con trực tiếp, xếp theo
/// sortOrder rồi mã; chưa có con thì không chiếm chỗ (nút thêm đã ở khối đầu).
class TaskChildItems extends StatelessWidget {
  final StandaloneTaskItem parent;
  final List<StandaloneTaskItem> items;
  final bool canAdd;
  final ValueChanged<StandaloneTaskItem> onOpen;
  final VoidCallback onAdd;

  const TaskChildItems({
    super.key,
    required this.parent,
    required this.items,
    required this.canAdd,
    required this.onOpen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final children = items.where((i) => i.parentId == parent.id).toList()
      ..sort((a, b) {
        final c = a.meta.sortOrder.compareTo(b.meta.sortOrder);
        return c != 0 ? c : a.code.compareTo(b.code);
      });
    if (children.isEmpty) return const SizedBox.shrink();
    final done = children.where((i) => i.status == 'done').length;

    return TaskPanel(
      title: Text.rich(TextSpan(children: [
        TextSpan(text: 'workspace.task_detail.children.title'.tr()),
        TextSpan(
          text: ' · $done/${children.length}',
          style: const TextStyle(fontWeight: FontWeight.normal, color: kTaskMuted),
        ),
      ])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final child in children)
            InkWell(
              onTap: () => onOpen(child),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Text(child.code,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: kTaskMuted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(child.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTaskInk)),
                          const SizedBox(height: 2),
                          Text('${_assigneeOf(child)} · ${taskFormatShortDate(child.dueDate)}',
                              style: const TextStyle(fontSize: 11.5, color: kTaskMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    TaskPill(label: child.statusLabel, tone: taskStatusTone(child)),
                  ],
                ),
              ),
            ),
          if (canAdd)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 14),
              label: Text('workspace.task_detail.children.add'.tr(), style: const TextStyle(fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}

/// "Việc con" của Công việc khác (web `standalone-tasks-view.tsx`): luôn hiện, có số đã xong/tổng,
/// mỗi dòng: mã, tiêu đề, trạng thái, người phụ trách, %, hạn.
class StandaloneChildItems extends StatelessWidget {
  final StandaloneTaskItem parent;
  final List<StandaloneTaskItem> children;
  final bool canAdd;
  final ValueChanged<StandaloneTaskItem> onOpen;
  final VoidCallback onAdd;

  const StandaloneChildItems({
    super.key,
    required this.parent,
    required this.children,
    required this.canAdd,
    required this.onOpen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return TaskPanel(
      title: Row(
        children: [
          const Icon(Icons.account_tree_outlined, size: 15, color: kTaskMuted),
          const SizedBox(width: 6),
          Text('workspace.task_detail.children.standalone_title'.tr()),
          if (parent.childCount > 0) ...[
            const SizedBox(width: 6),
            Text('${parent.childCount - parent.openChildCount}/${parent.childCount}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTaskMuted)),
          ],
          const Spacer(),
          if (canAdd)
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 13),
              label: Text('workspace.task_detail.children.add'.tr(), style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
            ),
        ],
      ),
      child: children.isEmpty
          ? Text(
              (canAdd ? 'workspace.task_detail.children.empty_can_add' : 'workspace.task_detail.children.empty').tr(),
              style: const TextStyle(fontSize: 12.5, color: kTaskMuted),
            )
          : Column(
              children: [
                for (final child in children)
                  InkWell(
                    onTap: () => onOpen(child),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(TextSpan(children: [
                            TextSpan(
                                text: '${child.code}  ',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: kTaskMuted)),
                            TextSpan(text: child.title),
                          ]), style: const TextStyle(fontSize: 12.5, color: kTaskInk)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TaskPill(label: child.statusLabel, tone: taskStatusTone(child)),
                              Text(_assigneeOf(child), style: const TextStyle(fontSize: 11.5, color: kTaskMuted)),
                              Text('${taskNum(child.progressPercent.round())}%',
                                  style: const TextStyle(fontSize: 11.5, color: kTaskMuted)),
                              if (child.dueDate != null)
                                Text(
                                  'workspace.task_detail.children.due'.tr(args: {'date': taskFormatDate(child.dueDate)}),
                                  style: TextStyle(
                                      fontSize: 11.5, color: taskIsOverdue(child) ? kTaskDanger : kTaskMuted),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
