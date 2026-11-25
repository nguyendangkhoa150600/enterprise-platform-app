import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';
import '../../../../utils/user_resolver.dart';
import 'task_detail_format.dart';
import 'task_detail_notices.dart';

/// Người tạo dòng nhật ký khi hồ sơ quy trình tự đổi trạng thái (contract `STANDALONE_TASK_SYSTEM_ACTOR_ID`).
const kStandaloneSystemActorId = '00000000-0000-4000-8000-000000000004';

List<Map<String, dynamic>> _maps(dynamic raw) =>
    raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

/// Dòng nhật ký của `StandaloneTaskDetail.history` (mới trước).
List<Map<String, dynamic>> standaloneHistoryOf(Map<String, dynamic>? detail) => _maps(detail?['history']);

/// Các thông báo dưới thanh trạng thái của Công việc khác (web `standalone-tasks-view.tsx` › `TaskDetail`):
/// huỷ hiệu lực (+ việc điều chỉnh), là việc điều chỉnh, chờ duyệt, việc con còn mở, lần trả lại gần nhất.
class StandaloneTaskNotices extends StatelessWidget {
  final StandaloneTaskItem task;
  final Map<String, dynamic>? detail;
  final bool isAssigner;
  final bool isExecutor;
  final bool canCreateAdjustment;
  final void Function(Map<String, dynamic> ref) onOpenRef;
  final VoidCallback onCreateAdjustment;

  const StandaloneTaskNotices({
    super.key,
    required this.task,
    required this.detail,
    required this.isAssigner,
    required this.isExecutor,
    required this.canCreateAdjustment,
    required this.onOpenRef,
    required this.onCreateAdjustment,
  });

  String _k(String s, [Map<String, Object>? args]) => 'workspace.task_detail.standalone_notice.$s'.tr(args: args);

  @override
  Widget build(BuildContext context) {
    final rawTask = detail?['task'] is Map ? Map<String, dynamic>.from(detail!['task'] as Map) : const <String, dynamic>{};
    final reversal = rawTask['reversal'] is Map ? Map<String, dynamic>.from(rawTask['reversal'] as Map) : null;
    final adjustments = _maps(detail?['adjustments']);
    final adjustmentOf = detail?['adjustmentOf'] is Map ? Map<String, dynamic>.from(detail!['adjustmentOf'] as Map) : null;
    final statusHistory = standaloneHistoryOf(detail).where((e) => e['toStatus'] != null).toList();
    final open = task.status != 'done' && task.status != 'cancelled';
    final byProcedure = task.status == 'review' &&
        statusHistory.isNotEmpty &&
        statusHistory.first['toStatus'] == 'review' &&
        statusHistory.first['createdBy']?.toString() == kStandaloneSystemActorId;
    Map<String, dynamic>? lastReturn;
    if (task.status == 'in_progress') {
      lastReturn = statusHistory
          .where((e) => e['fromStatus'] == 'review' && e['toStatus'] == 'in_progress')
          .firstOrNull;
    }
    final lastReturnIsLatest = lastReturn != null && statusHistory.first['id'] == lastReturn['id'];
    final returnNote = lastReturn?['note']?.toString() ?? '';
    final procedureCode = rawTask['procedure'] is Map ? (rawTask['procedure']['instanceCode']?.toString() ?? '') : '';

    final notices = <Widget>[
      if (reversal != null)
        TaskNotice(
          alert: true,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Text(
                _k('reversed', {
                  'time': taskFormatDateTime(DateTime.tryParse(reversal['reversedAt']?.toString() ?? '')),
                  'name': reversal['reversedByName']?.toString() ??
                      UserResolver.resolveName(reversal['reversedBy']?.toString()),
                  'reason': reversal['reason']?.toString() ?? '',
                }),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B)),
              ),
              if (adjustments.isNotEmpty) ...[
                Text(' · ${_k('adjustments')} ', style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
                for (var i = 0; i < adjustments.length; i++) ...[
                  if (i > 0) const Text(', ', style: TextStyle(fontSize: 12.5)),
                  TaskInlineLink(adjustments[i]['code']?.toString() ?? '', onTap: () => onOpenRef(adjustments[i])),
                  if (adjustments[i]['status'] == 'cancelled')
                    Text(' ${_k('adjustment_cancelled')}', style: const TextStyle(fontSize: 12.5)),
                ],
              ] else if (reversal['adjustmentRequested'] == true)
                Text(' · ${_k('adjustment_needed')}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
              if (canCreateAdjustment) ...[
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: onCreateAdjustment,
                  icon: const Icon(Icons.add, size: 13),
                  label: Text('workspace.task_detail.menu.adjust'.tr(), style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ],
          ),
        ),
      if (adjustmentOf != null)
        TaskAdjustmentOfNotice(
          code: '${adjustmentOf['code'] ?? ''} · ${adjustmentOf['title'] ?? ''}',
          standalone: true,
          onOpen: () => onOpenRef(adjustmentOf),
        ),
      if (task.status == 'review' && isExecutor)
        TaskNotice.text(
          '${byProcedure ? _k('procedure_done') : ''}${_k('waiting_review', {'name': UserResolver.resolveName(task.createdBy)})}',
        ),
      if (task.status == 'review' && isAssigner && (byProcedure || task.assigneeUserId != task.createdBy))
        TaskNotice.text(
          '${byProcedure ? _k('procedure_auto_review', {'code': procedureCode}) : _k('submitted', {'name': UserResolver.resolveName(task.assigneeUserId)})} ${_k('please_review')}',
        ),
      if (task.openChildCount > 0 && open)
        TaskNotice.text(
          (task.parentId != null ? 'open_children_complete' : 'open_children_submit')
              .let((key) => _k(key, {'count': task.openChildCount})),
        ),
      if (lastReturnIsLatest && returnNote.isNotEmpty)
        TaskNotice.text(
          _k('returned', {
            'time': taskFormatDateTime(DateTime.tryParse(lastReturn['createdAt']?.toString() ?? '')),
            'note': returnNote,
          }),
          alert: true,
        ),
    ];

    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final n in notices) Padding(padding: const EdgeInsets.only(bottom: 8), child: n),
      ],
    );
  }
}

extension _Let on String {
  R let<R>(R Function(String) f) => f(this);
}

/// "Nhật ký" của Công việc khác (web `HistoryDrawer`): đổi trạng thái hoặc sửa thông tin, người làm, lúc nào.
class StandaloneHistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const StandaloneHistoryList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    String k(String s) => 'workspace.task_detail.history.$s'.tr();
    return TaskPanel(
      title: Text(k('title')),
      child: entries.isEmpty
          ? Text(k('empty'), style: const TextStyle(fontSize: 12.5, color: kTaskMuted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e['toStatus'] != null
                              ? '${e['fromStatus'] != null ? '${taskStatusLabelOf(e['fromStatus'].toString())} → ${taskStatusLabelOf(e['toStatus'].toString())}' : k('assigned')}'
                                  '${(e['note']?.toString() ?? '').isNotEmpty ? ' · ${e['note']}' : ''}'
                              : k('edited'),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTaskInk),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e['createdBy']?.toString() == kStandaloneSystemActorId ? k('system') : UserResolver.resolveName(e['createdBy']?.toString())}'
                          ' · ${taskFormatDateTime(DateTime.tryParse(e['createdAt']?.toString() ?? ''))}',
                          style: const TextStyle(fontSize: 11.5, color: kTaskMuted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
