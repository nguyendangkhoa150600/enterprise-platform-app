import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';
import '../../../../utils/user_resolver.dart';
import 'task_detail_format.dart';
import 'task_detail_meta.dart';

class _Definition extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? valueWidget;
  const _Definition(this.label, this.value, {this.valueColor, this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: kTaskMuted)),
          ),
          Expanded(
            child: valueWidget ??
                Text(value,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: valueColor ?? kTaskInk)),
          ),
        ],
      ),
    );
  }
}

/// Tab "Chi tiết" của việc dự án (web `tab-overview.tsx` › `detailBody` + `quantityBlock`).
class TaskDetailInfoTab extends StatelessWidget {
  final StandaloneTaskItem item;
  /// Mở hộp báo khối lượng; null thì không có khối "Đã hoàn thành ... / Báo khối lượng".
  final VoidCallback? onReportQuantity;

  const TaskDetailInfoTab({super.key, required this.item, this.onReportQuantity});

  @override
  Widget build(BuildContext context) {
    final m = item.meta;
    final isQuantity = item.progressMethod == 'quantity';
    final showQuantityBlock =
        isQuantity && onReportQuantity != null && item.status != 'done' && item.status != 'cancelled';
    final description = item.description?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showQuantityBlock)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'workspace.task_detail.info.quantity_done'.tr(args: {
                      'done': taskNum(m.quantityDone ?? 0),
                      'target': taskNum(m.quantityTarget ?? 0),
                      'unit': m.quantityUnit ?? '',
                    }),
                    style: const TextStyle(fontSize: 12.5, color: kTaskInk),
                  ),
                ),
                OutlinedButton(
                  onPressed: onReportQuantity,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text('workspace.task_detail.info.report_quantity'.tr(), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        _Definition('workspace.task_detail.info.type'.tr(), taskItemTypeLabel(m.itemType)),
        _Definition(
          'workspace.task_detail.info.execution'.tr(),
          (m.executionType == 'procedure'
                  ? 'workspace.task_detail.info.execution_procedure'
                  : 'workspace.task_detail.info.execution_manual')
              .tr(),
        ),
        _Definition(
          'workspace.task_detail.info.estimate'.tr(),
          item.estimatedHours == null
              ? '—'
              : 'workspace.task_detail.info.hours'.tr(args: {'value': taskNum(item.estimatedHours)}),
        ),
        _Definition('workspace.task_detail.info.progress_method'.tr(), taskProgressMethodLabel(item.progressMethod)),
        if (isQuantity)
          _Definition(
            'workspace.task_detail.info.quantity'.tr(),
            '${taskNum(m.quantityDone ?? 0)} / ${taskNum(m.quantityTarget ?? 0)} ${m.quantityUnit ?? ''}'.trim(),
          ),
        if (item.weight != null) _Definition('workspace.task_detail.info.weight'.tr(), taskNum(item.weight)),
        _Definition('workspace.task_detail.info.actual'.tr(), taskDateRange(m.actualStart, m.actualEnd)),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF334155))),
        ],
      ],
    );
  }
}

/// Panel "Thông tin" + "Mô tả" của Công việc khác (web `standalone-tasks-view.tsx` › `TaskDetail`).
class StandaloneInfoSection extends StatelessWidget {
  final StandaloneTaskItem task;
  /// Bấm ô tiến độ (người giao / người thực hiện, việc đang mở); null là chỉ xem.
  final VoidCallback? onProgressTap;
  final String? progressLockedReason;

  const StandaloneInfoSection({super.key, required this.task, this.onProgressTap, this.progressLockedReason});

  String _names(List<String> ids) => ids.isEmpty ? '—' : ids.map((id) => UserResolver.resolveName(id)).join(', ');

  @override
  Widget build(BuildContext context) {
    final actual = task.meta.actualStart == null
        ? '—'
        : '${taskFormatDate(task.meta.actualStart)}${task.meta.actualEnd != null ? ' → ${taskFormatDate(task.meta.actualEnd)}' : ''}';
    final description = task.description?.trim() ?? '';
    String k(String s) => 'workspace.task_detail.standalone.$s'.tr();

    return Column(
      children: [
        TaskPanel(
          title: Text(k('info_title')),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Definition(k('assigner'), UserResolver.resolveName(task.createdBy)),
              _Definition(k('assignee'), UserResolver.resolveName(task.assigneeUserId)),
              _Definition(k('participants'), _names(task.participantUserIds)),
              _Definition(k('followers'), _names(task.followerUserIds)),
              _Definition(k('priority'), task.priorityLabel),
              _Definition(k('start'), taskFormatDate(task.plannedStart).isEmpty ? '—' : taskFormatDate(task.plannedStart)),
              _Definition(
                k('due'),
                taskFormatDate(task.dueDate).isEmpty ? '—' : taskFormatDate(task.dueDate),
                valueColor: taskIsOverdue(task) ? kTaskDanger : null,
              ),
              _Definition(k('actual'), actual),
              _Definition(
                k('progress'),
                '',
                valueWidget: Align(
                  alignment: Alignment.centerLeft,
                  child: TaskProgressCell(item: task, onTap: onProgressTap, lockedReason: progressLockedReason),
                ),
              ),
              _Definition(k('assigned_at'), taskFormatDateTime(task.createdAt)),
              if (task.childCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  task.meta.progressManual
                      ? 'workspace.task_detail.standalone.child_progress_manual'
                          .tr(args: {'auto': taskNum(task.meta.autoProgressPercent ?? 0)})
                      : k('child_progress_auto'),
                  style: const TextStyle(fontSize: 12, color: kTaskMuted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        TaskPanel(
          title: Text(k('description_title')),
          child: Text(
            description.isEmpty ? k('no_description') : description,
            style: TextStyle(fontSize: 13, height: 1.45, color: description.isEmpty ? kTaskMuted : const Color(0xFF334155)),
          ),
        ),
      ],
    );
  }
}
