import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_calendar_api.dart';
import '../../../../../models/workspace_models.dart';

/// Lưới lịch của web `calendar-grid.model.ts`: tuần bắt đầu thứ Hai, tháng luôn 42 ô.
enum CalendarMode { week, month }

/// Một mục trên lưới: sự kiện thật hoặc hạn công việc (ghép ở client, không phải dòng `calendar_events`).
class CalendarEntry {
  final String key;
  final bool isDeadline;
  final String title;

  /// `HH:mm` (tháng) hoặc `HH:mm–HH:mm` (tuần); null với mục cả ngày và hạn công việc.
  final String? time;
  final Color tone;
  final CalendarOccurrence? occurrence;
  final String? workItemId;

  const CalendarEntry({
    required this.key,
    required this.isDeadline,
    required this.title,
    this.time,
    required this.tone,
    this.occurrence,
    this.workItemId,
  });
}

class CalendarDay {
  final DateTime date;
  final String key;
  final bool inCurrentMonth;
  final bool isToday;
  final List<CalendarEntry> entries;

  const CalendarDay({
    required this.date,
    required this.key,
    required this.inCurrentMonth,
    required this.isToday,
    required this.entries,
  });
}

String calendarDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime _startOfDay(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime calendarGridStart(DateTime anchor, CalendarMode mode) {
  final base = mode == CalendarMode.week ? _startOfDay(anchor) : DateTime(anchor.year, anchor.month, 1);
  return DateTime(base.year, base.month, base.day - (base.weekday - 1));
}

int calendarGridLength(CalendarMode mode) => mode == CalendarMode.week ? 7 : 42;

({DateTime from, DateTime to}) calendarGridRange(DateTime anchor, CalendarMode mode) {
  final from = calendarGridStart(anchor, mode);
  final last = DateTime(from.year, from.month, from.day + calendarGridLength(mode) - 1);
  return (from: from, to: DateTime(last.year, last.month, last.day, 23, 59, 59, 999));
}

DateTime calendarShiftAnchor(DateTime anchor, CalendarMode mode, int direction) => mode == CalendarMode.week
    ? DateTime(anchor.year, anchor.month, anchor.day + direction * 7)
    : DateTime(anchor.year, anchor.month + direction, 1);

String _two(int v) => v.toString().padLeft(2, '0');
String calendarClock(DateTime v) => '${_two(v.hour)}:${_two(v.minute)}';
String calendarDate(DateTime v) => '${_two(v.day)}/${_two(v.month)}/${v.year}';

/// `Tuần 21/09/2026 – 27/09/2026` hoặc `Tháng 09/2026`.
String calendarGridLabel(DateTime anchor, CalendarMode mode) {
  if (mode == CalendarMode.month) {
    return 'workspace.calendar.month_label'.tr(args: {'month': '${_two(anchor.month)}/${anchor.year}'});
  }
  final start = calendarGridStart(anchor, CalendarMode.week);
  final end = DateTime(start.year, start.month, start.day + 6);
  return 'workspace.calendar.week_label'.tr(args: {'from': calendarDate(start), 'to': calendarDate(end)});
}

const Map<String, Color> _eventTones = {
  'meeting': Color(0xFF2563EB),
  'activity': Color(0xFF15803D),
  'other': Color(0xFF6D28D9),
};

/// Lịch công tác có màu riêng; đơn chờ duyệt nhạt hơn đơn đã duyệt.
Color calendarToneOf(CalendarOccurrence occurrence) {
  final trip = occurrence.businessTrip;
  if (trip != null) return trip.status == 'PENDING' ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
  return _eventTones[occurrence.eventType] ?? _eventTones['other']!;
}

/// Dựng các ngày của lưới. Mục nhiều ngày rải vào từng ngày nó chạm tới; hạn công việc (chưa xong/huỷ) theo `plannedEnd`.
/// [timeRange] = true thì giờ hiện dạng `HH:mm–HH:mm` (danh sách theo ngày của chế độ tuần).
List<CalendarDay> buildCalendarDays(
  DateTime anchor,
  CalendarMode mode,
  List<CalendarOccurrence> occurrences,
  List<StandaloneTaskItem> workItems, {
  bool timeRange = false,
}) {
  final start = calendarGridStart(anchor, mode);
  final today = calendarDateKey(DateTime.now());
  final byDate = <String, List<CalendarEntry>>{};
  void push(String date, CalendarEntry entry) => byDate.putIfAbsent(date, () => []).add(entry);

  for (final occurrence in occurrences) {
    final from = _startOfDay(occurrence.startAt);
    final until = _startOfDay(occurrence.endAt);
    for (var cursor = from; !cursor.isAfter(until); cursor = DateTime(cursor.year, cursor.month, cursor.day + 1)) {
      final key = calendarDateKey(cursor);
      final isFirstDay = cursor == from;
      final sameDay = calendarDateKey(occurrence.startAt) ==
          calendarDateKey(occurrence.endAt.subtract(const Duration(milliseconds: 1)));
      String? time;
      if (!occurrence.allDay && isFirstDay) {
        time = timeRange && sameDay
            ? '${calendarClock(occurrence.startAt)}–${calendarClock(occurrence.endAt)}'
            : calendarClock(occurrence.startAt);
      }
      push(
        key,
        CalendarEntry(
          key: '${occurrence.eventId}:${occurrence.occurrenceDate}:$key',
          isDeadline: false,
          title: occurrence.title,
          time: time,
          tone: calendarToneOf(occurrence),
          occurrence: occurrence,
        ),
      );
    }
  }

  for (final item in workItems) {
    final due = item.dueDate;
    if (due == null) continue;
    if (item.status == 'done' || item.status == 'cancelled') continue;
    push(
      calendarDateKey(due),
      CalendarEntry(
        key: 'deadline:${item.id}',
        isDeadline: true,
        title: 'workspace.calendar.deadline_title'.tr(args: {'title': item.title}),
        tone: const Color(0xFFB45309),
        workItemId: item.id,
      ),
    );
  }

  final length = calendarGridLength(mode);
  return List.generate(length, (index) {
    final day = DateTime(start.year, start.month, start.day + index);
    final key = calendarDateKey(day);
    final raw = byDate[key] ?? const <CalendarEntry>[];
    // Mục cả ngày và hạn công việc không có giờ, xếp lên đầu ô (sắp ổn định như web).
    final order = List.generate(raw.length, (i) => i)
      ..sort((a, b) {
        final byTime = (raw[a].time ?? '').compareTo(raw[b].time ?? '');
        return byTime != 0 ? byTime : a - b;
      });
    final entries = [for (final i in order) raw[i]];
    return CalendarDay(
      date: day,
      key: key,
      inCurrentMonth: mode == CalendarMode.week || day.month == anchor.month,
      isToday: key == today,
      entries: entries,
    );
  });
}
