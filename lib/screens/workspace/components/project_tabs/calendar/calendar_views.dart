import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import 'calendar_grid_model.dart';

/// Nhãn thứ T2…CN như web.
List<String> calendarWeekdayLabels() =>
    ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].map((d) => 'workspace.calendar.weekday_$d'.tr()).toList();

/// Số mục tối đa trong một ô ngày của lưới tháng; phần còn lại gộp thành "+n mục khác" (bấm để xem tuần đó).
const int kCalendarMonthCellLimit = 3;

/// Lưới tháng 6×7 (thứ Hai đầu tuần). Chạm ô để xem danh sách của ngày bên dưới; nhấn giữ để tạo sự kiện (thay cho
/// nhấp đúp ở web) khi có quyền.
class CalendarMonthGrid extends StatelessWidget {
  final List<CalendarDay> days;
  final String? selectedKey;
  final ValueChanged<CalendarDay> onSelectDay;
  final ValueChanged<CalendarDay>? onCreateOnDay;
  final ValueChanged<CalendarEntry> onOpenEntry;
  final ValueChanged<DateTime> onShowWeek;

  const CalendarMonthGrid({
    super.key,
    required this.days,
    required this.selectedKey,
    required this.onSelectDay,
    required this.onOpenEntry,
    required this.onShowWeek,
    this.onCreateOnDay,
  });

  @override
  Widget build(BuildContext context) {
    final labels = calendarWeekdayLabels();
    final rows = (days.length / 7).ceil();
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: i >= 5 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < rows; r++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < 7; c++) Expanded(child: _cell(days[r * 7 + c], c >= 5)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(CalendarDay day, bool weekend) {
    final shown = day.entries.take(kCalendarMonthCellLimit).toList();
    final hidden = day.entries.length - shown.length;
    final selected = day.key == selectedKey;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelectDay(day),
      onLongPress: onCreateOnDay == null ? null : () => onCreateOnDay!(day),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFDBEAFE)
              : day.isToday
                  ? const Color(0xFFEFF6FF)
                  : weekend
                      ? const Color(0xFFF8FAFC)
                      : Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: day.isToday
                    ? BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(8))
                    : null,
                child: Text(
                  '${day.date.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
                    color: day.isToday
                        ? Colors.white
                        : day.inCurrentMonth
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ),
            for (final entry in shown)
              GestureDetector(
                onTap: () => onOpenEntry(entry),
                child: Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: entry.tone.withValues(alpha: 0.12),
                    border: Border(left: BorderSide(color: entry.tone, width: 2)),
                  ),
                  child: Text(
                    entry.time != null ? '${entry.time} ${entry.title}' : entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: entry.tone, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (hidden > 0)
              GestureDetector(
                onTap: () => onShowWeek(day.date),
                child: Tooltip(
                  message: 'workspace.calendar.show_week'.tr(),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'workspace.calendar.more_entries'.tr(args: {'count': hidden}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Một mục trong danh sách theo ngày.
class CalendarEntryTile extends StatelessWidget {
  final CalendarEntry entry;
  final VoidCallback onTap;

  const CalendarEntryTile({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final location = entry.occurrence?.location;
    final sub = [entry.time, location].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: entry.tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: entry.tone, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: entry.tone),
                  ),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

/// Khối một ngày: tiêu đề thứ/ngày + các mục (dùng cho chế độ tuần và ngày đang chọn của chế độ tháng).
class CalendarDayAgenda extends StatelessWidget {
  final CalendarDay day;
  final String weekdayLabel;
  final ValueChanged<CalendarEntry> onOpenEntry;
  final VoidCallback? onCreate;

  const CalendarDayAgenda({
    super.key,
    required this.day,
    required this.weekdayLabel,
    required this.onOpenEntry,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final accent = day.isToday ? const Color(0xFF2563EB) : const Color(0xFF0F172A);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onCreate,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: day.isToday ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$weekdayLabel  ${calendarDate(day.date)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
            ),
            const SizedBox(height: 6),
            if (day.entries.isEmpty)
              Text('workspace.calendar.day_empty'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
            else
              for (final entry in day.entries) CalendarEntryTile(entry: entry, onTap: () => onOpenEntry(entry)),
          ],
        ),
      ),
    );
  }
}
