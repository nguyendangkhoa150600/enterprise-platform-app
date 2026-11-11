import 'package:flutter/material.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/user_resolver.dart';
import 'workspace_sheets.dart';

/// Chế độ xem biểu đồ tiến độ Gantt (Timeline) cho dự án, đồng bộ 1:1 với Web React
class WorkspaceProjectGanttView extends StatelessWidget {
  final List<StandaloneTaskItem> tasks;
  final WorkspaceService service;
  final VoidCallback onRefresh;

  const WorkspaceProjectGanttView({
    super.key,
    required this.tasks,
    required this.service,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline_outlined, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Không có công việc nào để hiển thị trên biểu đồ Gantt',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Xác định timeline min và max
    DateTime? minDate;
    DateTime? maxDate;

    for (final t in tasks) {
      final s = t.plannedStart ?? t.createdAt;
      final e = t.dueDate ?? s?.add(const Duration(days: 7));
      if (s != null) {
        if (minDate == null || s.isBefore(minDate)) minDate = s;
      }
      if (e != null) {
        if (maxDate == null || e.isAfter(maxDate)) maxDate = e;
      }
    }

    final now = DateTime.now();
    minDate ??= now.subtract(const Duration(days: 7));
    maxDate ??= now.add(const Duration(days: 30));

    // Đảm bảo khoảng cách tối thiểu 14 ngày
    if (maxDate.difference(minDate).inDays < 14) {
      maxDate = minDate.add(const Duration(days: 14));
    }

    final totalDays = maxDate.difference(minDate).inDays + 1;
    const double dayWidth = 28.0;
    final double timelineWidth = totalDays * dayWidth;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chú thích trạng thái Gantt đồng bộ 1:1 với Kanban
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLegendItem('Chưa làm', const Color(0xFF94A3B8)),
                  const SizedBox(width: 12),
                  _buildLegendItem('Đang làm', const Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  _buildLegendItem('Vướng mắc', const Color(0xFFEF4444)),
                  const SizedBox(width: 12),
                  _buildLegendItem('Chờ duyệt', const Color(0xFFF59E0B)),
                  const SizedBox(width: 12),
                  _buildLegendItem('Hoàn thành', const Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  _buildLegendItem('Đã huỷ', const Color(0xFF64748B), isDashed: true),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Biểu đồ Gantt cuộn ngang
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              width: 220 + timelineWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline Header (Trục ngày)
                  Row(
                    children: [
                      Container(
                        width: 220,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Text(
                          'Công việc (WBS)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                      ),
                      SizedBox(
                        width: timelineWidth,
                        height: 36,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: totalDays,
                          itemBuilder: (ctx, i) {
                            final d = minDate!.add(Duration(days: i));
                            final isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
                            final isToday = d.year == now.year && d.month == now.month && d.day == now.day;

                            return Container(
                              width: dayWidth,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? const Color(0xFFFEF3C7)
                                    : (isWeekend ? const Color(0xFFF1F5F9) : Colors.white),
                                border: const Border(
                                  left: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                                  bottom: BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${d.day}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                      color: isToday ? const Color(0xFFB45309) : const Color(0xFF475569),
                                    ),
                                  ),
                                  Text(
                                    'T${d.weekday == 7 ? 'CN' : (d.weekday + 1)}',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      color: isWeekend ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  // Task Rows in Gantt
                  ...tasks.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final task = entry.value;
                    return _buildGanttRow(
                      context,
                      task,
                      idx + 1,
                      minDate!,
                      totalDays,
                      dayWidth,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGanttRow(
    BuildContext context,
    StandaloneTaskItem task,
    int index,
    DateTime minDate,
    int totalDays,
    double dayWidth,
  ) {
    final isCancelled = task.status == 'cancelled' || task.status == 'canceled' || task.status == 'da_huy';
    final isDone = task.status == 'done' || task.status == 'completed';
    final isBlocked = task.status == 'blocked' || task.status == 'stuck';
    final isReview = task.status == 'review';
    final isInProgress = task.status == 'in_progress';

    // Xác định màu thanh Gantt đồng bộ 100% với Kanban
    Color barColor;
    if (isCancelled) {
      barColor = const Color(0xFF94A3B8); // Xám cho Đã huỷ (không hiển thị xanh 100%)
    } else if (isDone) {
      barColor = const Color(0xFF10B981); // Xanh lá Hoàn thành
    } else if (isBlocked) {
      barColor = const Color(0xFFEF4444); // Đỏ Vướng mắc
    } else if (isReview) {
      barColor = const Color(0xFFF59E0B); // Vàng Chờ duyệt
    } else if (isInProgress) {
      barColor = const Color(0xFF3B82F6); // Xanh dương Đang làm
    } else {
      barColor = const Color(0xFFCBD5E1); // Chưa làm
    }

    final s = task.plannedStart ?? task.createdAt ?? minDate;
    final e = task.dueDate ?? s.add(const Duration(days: 3));

    final startOffsetDays = s.difference(minDate).inDays.clamp(0, totalDays - 1);
    final durationDays = (e.difference(s).inDays + 1).clamp(1, totalDays - startOffsetDays);

    final leftPosition = startOffsetDays * dayWidth;
    final barWidth = durationDays * dayWidth;

    final assignee = task.assigneeName != null && task.assigneeName!.isNotEmpty
        ? task.assigneeName!
        : (task.assigneeUserId.isNotEmpty ? UserResolver.resolveName(task.assigneeUserId) : '');

    return InkWell(
      onTap: () {
        showWorkspaceTaskStatusSheet(
          context,
          task: task,
          service: service,
          onStatusChanged: onRefresh,
        );
      },
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            // Cột bên trái: Tên Task + Người phụ trách + Trạng thái
            Container(
              width: 220,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$index',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isCancelled ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (assignee.isNotEmpty)
                          Text(
                            assignee,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  _buildStatusDot(task.status),
                ],
              ),
            ),

            // Cột timeline: Thanh Gantt bar
            SizedBox(
              width: totalDays * dayWidth,
              height: 48,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Lưới sọc ngày mờ
                  Positioned.fill(
                    child: Row(
                      children: List.generate(totalDays, (_) {
                        return Container(
                          width: dayWidth,
                          decoration: const BoxDecoration(
                            border: Border(left: BorderSide(color: Color(0xFFF8FAFC))),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Thanh Gantt đại diện công việc
                  Positioned(
                    left: leftPosition.toDouble(),
                    width: barWidth.toDouble().clamp(30.0, double.infinity),
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: isCancelled ? 0.2 : 0.85),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: barColor,
                          width: 1,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isCancelled
                                  ? 'Đã huỷ'
                                  : (isDone ? '100%' : '${task.progressPercent.toInt()}%'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isCancelled ? const Color(0xFF475569) : Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot(String status) {
    Color c;
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        c = const Color(0xFF10B981);
        break;
      case 'cancelled':
      case 'canceled':
      case 'da_huy':
        c = const Color(0xFF64748B);
        break;
      case 'blocked':
      case 'stuck':
        c = const Color(0xFFEF4444);
        break;
      case 'review':
        c = const Color(0xFFF59E0B);
        break;
      case 'in_progress':
        c = const Color(0xFF3B82F6);
        break;
      default:
        c = const Color(0xFFCBD5E1);
        break;
    }

    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool isDashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDashed ? 0.3 : 1.0),
            borderRadius: BorderRadius.circular(3),
            border: isDashed ? Border.all(color: color, width: 1) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
