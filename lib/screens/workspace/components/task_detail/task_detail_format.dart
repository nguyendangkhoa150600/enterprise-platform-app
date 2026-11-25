import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';

/// Nhãn, màu và định dạng dùng chung cho hộp chi tiết công việc (web `workspace-labels.ts`).
class TaskTone {
  final Color bg;
  final Color fg;
  const TaskTone(this.bg, this.fg);
}

const _reversedTone = TaskTone(Color(0xFFFFF7ED), Color(0xFF9A3412));

const Map<String, TaskTone> _statusTones = {
  'todo': TaskTone(Color(0x2E9CA3AF), Color(0xFF4B5563)),
  'in_progress': TaskTone(Color(0x263B82F6), Color(0xFF1D4ED8)),
  'blocked': TaskTone(Color(0x26EF4444), Color(0xFFB91C1C)),
  'review': TaskTone(Color(0x2EF59E0B), Color(0xFF92400E)),
  'done': TaskTone(Color(0x2610B981), Color(0xFF047857)),
  'cancelled': TaskTone(Color(0xFFF3F4F6), Color(0xFF6B7280)),
};

const Map<String, TaskTone> _priorityTones = {
  'urgent': TaskTone(Color(0xFFFEE2E2), Color(0xFF991B1B)),
  'high': TaskTone(Color(0xFFFFEDD5), Color(0xFF9A3412)),
  'normal': TaskTone(Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
  'low': TaskTone(Color(0xFFF1F5F9), Color(0xFF475569)),
};

TaskTone taskStatusTone(StandaloneTaskItem item) =>
    item.isReversed ? _reversedTone : (_statusTones[item.status] ?? _statusTones['todo']!);

TaskTone taskPriorityTone(String priority) => _priorityTones[priority] ?? _priorityTones['low']!;

/// Nhãn trạng thái thô (dòng nhật ký): "Chưa làm", "Đang làm"...
String taskStatusLabelOf(String status) => 'workspace.task_detail.status_label.$status'.tr();

String taskItemTypeLabel(String itemType) => 'workspace.task_detail.item_type.$itemType'.tr();

/// web `WORK_ITEM_PROGRESS_METHOD_INFO[...].label`.
String taskProgressMethodLabel(String? method) =>
    'workspace.task_detail.progress_method.${method ?? 'manual'}'.tr();

String _two(int v) => v.toString().padLeft(2, '0');

DateTime _local(DateTime d) => d.isUtc ? d.toLocal() : d;

/// `21/09/2026`; chuỗi rỗng khi không có ngày.
String taskFormatDate(DateTime? d) {
  if (d == null) return '';
  final v = _local(d);
  return '${_two(v.day)}/${_two(v.month)}/${v.year}';
}

/// `21/09` cho dòng chật; '—' khi không có ngày.
String taskFormatShortDate(DateTime? d) {
  if (d == null) return '—';
  final v = _local(d);
  return '${_two(v.day)}/${_two(v.month)}';
}

/// `14:05 21/09/2026` theo giờ máy.
String taskFormatDateTime(DateTime? d) {
  if (d == null) return '—';
  final v = _local(d);
  return '${_two(v.hour)}:${_two(v.minute)} ${taskFormatDate(v)}';
}

/// web `dateRange`: '—' khi thiếu cả hai, '…' cho đầu còn thiếu.
String taskDateRange(DateTime? start, DateTime? end) {
  final from = taskFormatDate(start);
  final to = taskFormatDate(end);
  if (from.isEmpty && to.isEmpty) return '—';
  return '${from.isEmpty ? '…' : from} → ${to.isEmpty ? '…' : to}';
}

/// Số gọn: 8.0 → "8", 2.5 → "2.5".
String taskNum(num? v) {
  if (v == null) return '0';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// web `isOverdue`: chưa xong/chưa huỷ và hạn kế hoạch đã qua (so theo ngày).
bool taskIsOverdue(StandaloneTaskItem item) {
  if (item.status == 'done' || item.status == 'cancelled') return false;
  final due = item.dueDate;
  if (due == null) return false;
  final d = _local(due);
  final now = DateTime.now();
  return DateTime(d.year, d.month, d.day).isBefore(DateTime(now.year, now.month, now.day));
}

/// Chính việc và mọi việc con cháu của nó (web `branchOf`).
Set<String> taskBranchOf(List<StandaloneTaskItem> items, String id) {
  final branch = {id};
  var grew = true;
  while (grew) {
    grew = false;
    for (final item in items) {
      final p = item.parentId;
      if (p != null && branch.contains(p) && branch.add(item.id)) grew = true;
    }
  }
  return branch;
}

/// Nhãn nút chuyển trạng thái của Công việc khác (web `transitionLabel`).
String standaloneTransitionLabel(String from, String to, bool isAssigner) {
  String k(String s) => 'workspace.task_detail.transition.$s'.tr();
  if (to == 'done') return isAssigner && from == 'review' ? k('approve') : k('complete');
  if (to == 'review') return k('submit');
  if (to == 'blocked') return k('block');
  if (to == 'cancelled') return k('cancel');
  if (to == 'in_progress') {
    if (from == 'todo') return k('start');
    if (from == 'review') return isAssigner ? k('return') : k('withdraw');
    if (from == 'done') return k('reopen');
    return k('resume');
  }
  return from == 'cancelled' ? k('reopen') : k('to_todo');
}

/// Huy hiệu bo tròn (trạng thái, ưu tiên).
class TaskPill extends StatelessWidget {
  final String label;
  final TaskTone tone;
  const TaskPill({super.key, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tone.fg)),
    );
  }
}

/// Khung panel trắng có tiêu đề (web `styles.panel` + `h3`).
class TaskPanel extends StatelessWidget {
  final Widget? title;
  final Widget child;
  const TaskPanel({super.key, this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              child: title!,
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

const kTaskMuted = Color(0xFF64748B);
const kTaskInk = Color(0xFF0F172A);
const kTaskDanger = Color(0xFFDC2626);
