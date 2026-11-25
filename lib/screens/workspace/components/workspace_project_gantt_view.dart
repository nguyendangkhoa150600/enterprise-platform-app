import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/domain/models/project_access.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import 'project_detail/project_work_model.dart';
import 'workspace_standalone_task_detail_sheet.dart';

/// Biểu đồ Gantt của tab Công việc (web gantt-chart.tsx + gantt.model.ts): dòng theo cây WBS
/// (thụt theo cấp, nhóm công việc giữ tổ tiên của việc khớp lọc), thanh chỉ vẽ khi có đủ hai mốc kế hoạch,
/// cột mốc là hình thoi, quá hạn tô đỏ, phần đã làm tô đậm; thu phóng Ngày / Tuần / Tháng và nút "Hôm nay".
class WorkspaceProjectGanttView extends StatefulWidget {
  /// Việc khớp bộ lọc.
  final List<StandaloneTaskItem> tasks;
  final WorkspaceService service;
  final VoidCallback onRefresh;

  /// Toàn bộ việc của dự án, để giữ nhóm cha của việc khớp lọc (mặc định = [tasks]).
  final List<StandaloneTaskItem>? allTasks;
  final ProjectAccess? access;

  /// Mở chi tiết; vắng thì mở sheet chi tiết công việc mặc định.
  final ValueChanged<StandaloneTaskItem>? onOpenTask;
  final String sort;
  final bool ascending;

  const WorkspaceProjectGanttView({
    super.key,
    required this.tasks,
    required this.service,
    required this.onRefresh,
    this.allTasks,
    this.access,
    this.onOpenTask,
    this.sort = 'wbs',
    this.ascending = true,
  });

  @override
  State<WorkspaceProjectGanttView> createState() => _WorkspaceProjectGanttViewState();
}

class _WorkspaceProjectGanttViewState extends State<WorkspaceProjectGanttView> {
  static const double _rowHeight = 30;
  static const double _barHeight = 14;
  static const double _axisHeight = 28;
  static const double _labelWidth = 170;
  static const int _paddingDays = 2;
  static const int _todayReachDays = 180;
  static const int _todayPaddingDays = 7;
  static const Map<String, double> _dayWidth = {'day': 30, 'week': 10, 'month': 3.4};

  final ScrollController _hScroll = ScrollController();
  String _zoom = 'day';
  bool _scrolledInitially = false;

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static int _between(DateTime a, DateTime b) => _day(b).difference(_day(a)).inHours ~/ 24;

  void _open(StandaloneTaskItem item) {
    if (widget.onOpenTask != null) {
      widget.onOpenTask!(item);
      return;
    }
    showWorkspaceStandaloneTaskDetailSheet(context, task: item, service: widget.service, onRefresh: widget.onRefresh);
  }

  ({DateTime start, DateTime end}) _bounds(List<WorkTreeRow> rows, double minWidth) {
    final today = _day(DateTime.now());
    final dates = <DateTime>[
      for (final r in rows) ...[
        if (r.item.plannedStart != null) _day(r.item.plannedStart!.toLocal()),
        if (r.item.dueDate != null) _day(r.item.dueDate!.toLocal()),
      ],
    ];
    DateTime start;
    DateTime end;
    if (dates.isEmpty) {
      start = today.subtract(const Duration(days: 3));
      end = today.add(const Duration(days: 3));
    } else {
      dates.sort();
      start = DateTime(dates.first.year, dates.first.month, dates.first.day - _paddingDays);
      end = DateTime(dates.last.year, dates.last.month, dates.last.day + _paddingDays);
    }
    final before = _between(today, start);
    final after = _between(end, today);
    if (before > 0 && before <= _todayReachDays) start = DateTime(today.year, today.month, today.day - _todayPaddingDays);
    if (after > 0 && after <= _todayReachDays) end = DateTime(today.year, today.month, today.day + _todayPaddingDays);
    final dw = _dayWidth[_zoom]!;
    final missing = (minWidth / dw).ceil() - (_between(start, end) + 1);
    if (missing > 0) {
      final head = missing ~/ 2;
      start = DateTime(start.year, start.month, start.day - head);
      end = DateTime(end.year, end.month, end.day + (missing - head));
    }
    return (start: start, end: end);
  }

  void _scrollToToday(double todayX, double viewport, {bool animate = true}) {
    if (!_hScroll.hasClients) return;
    final target = (todayX - viewport / 2).clamp(0.0, _hScroll.position.maxScrollExtent);
    if (animate) {
      _hScroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _hScroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.allTasks ?? widget.tasks;
    final rows = buildWorkTree(all, widget.tasks.map((t) => t.id).toSet(),
        compare: workComparator(widget.sort, widget.ascending));

    return LayoutBuilder(builder: (context, constraints) {
      final viewport = (constraints.maxWidth - _labelWidth).clamp(100.0, double.infinity);
      final b = _bounds(rows, viewport);
      final dw = _dayWidth[_zoom]!;
      final days = _between(b.start, b.end) + 1;
      final width = days * dw;
      final today = _day(DateTime.now());
      final todayOffset = _between(b.start, today);
      final double? todayX = todayOffset >= 0 && todayOffset < days ? todayOffset * dw + dw / 2 : null;
      if (!_scrolledInitially && todayX != null) {
        _scrolledInitially = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToToday(todayX, viewport, animate: false);
        });
      }

      return Column(
        children: [
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('${formatFullDate(b.start)} – ${formatFullDate(b.end)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                ),
                TextButton(
                  onPressed: todayX == null ? null : () => _scrollToToday(todayX, viewport),
                  child: Text('workspace.work_tab.gantt_today'.tr(), style: const TextStyle(fontSize: 12)),
                ),
                _zoomSwitch(),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text('workspace.work_tab.gantt_empty'.tr(),
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  )
                : SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _labels(rows),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _hScroll,
                            scrollDirection: Axis.horizontal,
                            child: GestureDetector(
                              onTapUp: (d) {
                                final i = ((d.localPosition.dy - _axisHeight) / _rowHeight).floor();
                                if (i >= 0 && i < rows.length) _open(rows[i].item);
                              },
                              child: CustomPaint(
                                size: Size(width, _axisHeight + rows.length * _rowHeight),
                                painter: _GanttPainter(
                                  rows: rows,
                                  start: b.start,
                                  days: days,
                                  dayWidth: dw,
                                  zoom: _zoom,
                                  todayX: todayX,
                                  rowHeight: _rowHeight,
                                  barHeight: _barHeight,
                                  axisHeight: _axisHeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    });
  }

  Widget _zoomSwitch() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final z in const ['day', 'week', 'month'])
            InkWell(
              onTap: () => setState(() {
                _zoom = z;
                _scrolledInitially = false;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _zoom == z ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('workspace.work_tab.gantt_zoom_$z'.tr(),
                    style: TextStyle(fontSize: 11, fontWeight: _zoom == z ? FontWeight.bold : FontWeight.w500)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _labels(List<WorkTreeRow> rows) {
    return Container(
      width: _labelWidth,
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Column(
        children: [
          const SizedBox(height: _axisHeight),
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: () => _open(rows[i].item),
              child: Container(
                height: _rowHeight,
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(left: rows[i].depth * 12.0 + 8, right: 4),
                decoration: BoxDecoration(
                  border: Border(
                    top: rows[i].depth == 0 && i > 0
                        ? const BorderSide(color: Color(0xFFCBD5E1))
                        : BorderSide.none,
                  ),
                ),
                child: Text(
                  '${rows[i].item.code} · ${rows[i].item.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: rows[i].hasChildren ? FontWeight.w700 : FontWeight.w500,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GanttPainter extends CustomPainter {
  final List<WorkTreeRow> rows;
  final DateTime start;
  final int days;
  final double dayWidth;
  final String zoom;
  final double? todayX;
  final double rowHeight;
  final double barHeight;
  final double axisHeight;

  _GanttPainter({
    required this.rows,
    required this.start,
    required this.days,
    required this.dayWidth,
    required this.zoom,
    required this.todayX,
    required this.rowHeight,
    required this.barHeight,
    required this.axisHeight,
  });

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  double _xOf(DateTime d) => (_day(d).difference(start).inHours ~/ 24) * dayWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()..color = const Color(0xFFF1F5F9);
    final major = Paint()..color = const Color(0xFFCBD5E1);
    final todayKey = _day(DateTime.now());

    // Trục thời gian.
    for (var i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      String? label;
      bool isMajor = false;
      if (zoom == 'day') {
        label = '${d.day}';
        isMajor = d.day == 1 || d.weekday == DateTime.monday;
      } else if (zoom == 'week') {
        if (d.weekday == DateTime.monday) {
          label = formatShortDate(d);
          isMajor = true;
        }
      } else if (d.day == 1) {
        label = '${d.month.toString().padLeft(2, '0')}/${d.year}';
        isMajor = true;
      }
      if (label == null) continue;
      final x = i * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), isMajor ? major : minor);
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 3, 8));
    }
    canvas.drawLine(Offset(0, axisHeight), Offset(size.width, axisHeight), major);

    for (var i = 0; i < rows.length; i++) {
      final item = rows[i].item;
      final top = axisHeight + i * rowHeight;
      if (rows[i].depth == 0 && i > 0) canvas.drawLine(Offset(0, top), Offset(size.width, top), major);
      final centerY = top + rowHeight / 2;
      final end = item.dueDate?.toLocal();
      final begin = item.plannedStart?.toLocal();
      final overdue = item.status != 'done' && item.status != 'cancelled' && end != null && _day(end).isBefore(todayKey);
      final stroke = overdue ? const Color(0xFFB91C1C) : const Color(0xFF2563EB);

      if (item.meta.isMilestone) {
        final at = end ?? begin;
        if (at == null) continue;
        final x = _xOf(at);
        const s = 6.0;
        final path = Path()
          ..moveTo(x, centerY - s)
          ..lineTo(x + s, centerY)
          ..lineTo(x, centerY + s)
          ..lineTo(x - s, centerY)
          ..close();
        canvas.drawPath(path, Paint()..color = overdue ? const Color(0xFFB91C1C) : const Color(0xFF6D28D9));
        continue;
      }
      if (begin == null || end == null) continue;
      final x = _xOf(begin);
      final w = ((_day(end).difference(_day(begin)).inHours ~/ 24) + 1) * dayWidth;
      final width = w < dayWidth ? dayWidth : w;
      final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - barHeight / 2, width, barHeight), const Radius.circular(3));
      canvas.drawRRect(rect, Paint()..color = overdue ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE));
      final progress = width * (item.progressPercent.clamp(0, 100) / 100);
      if (progress > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, centerY - barHeight / 2, progress, barHeight), const Radius.circular(3)),
          Paint()..color = stroke,
        );
      }
      canvas.drawRRect(rect, Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke);
    }

    if (todayX != null) {
      canvas.drawLine(
        Offset(todayX!, 0),
        Offset(todayX!, size.height),
        Paint()
          ..color = const Color(0xFFD9AB00)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GanttPainter old) =>
      old.rows != rows || old.zoom != zoom || old.start != start || old.days != days || old.todayX != todayX;
}
