import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_calendar_api.dart';
import '../../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../../models/workspace_models.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/workspace_service.dart';
import 'calendar/calendar_business_trip_sheet.dart';
import 'calendar/calendar_event_form_sheet.dart';
import 'calendar/calendar_grid_model.dart';
import 'calendar/calendar_people_picker.dart';
import 'calendar/calendar_views.dart';

/// Tab "Lịch" của dự án như web `tab-calendar.tsx`: sự kiện của dự án (`GET /calendar?projectId`) cộng hạn công việc
/// ghép ở client. Chế độ tháng là lưới ô ngày + danh sách của ngày đang chọn; chế độ tuần là danh sách theo từng ngày.
class WorkspaceProjectCalendarTab extends StatefulWidget {
  final ProjectItem project;
  final WorkspaceService service;
  final ProjectAccess access;
  final List<StandaloneTaskItem> projectItems;
  final void Function(String itemId)? onOpenItem;

  const WorkspaceProjectCalendarTab({
    super.key,
    required this.project,
    required this.service,
    required this.access,
    this.projectItems = const [],
    this.onOpenItem,
  });

  @override
  State<WorkspaceProjectCalendarTab> createState() => _WorkspaceProjectCalendarTabState();
}

class _WorkspaceProjectCalendarTabState extends State<WorkspaceProjectCalendarTab> {
  final WorkspaceCalendarApi _api = WorkspaceCalendarApi();

  CalendarMode _mode = CalendarMode.month;
  DateTime _anchor = DateTime.now();
  String? _selectedKey;
  List<CalendarOccurrence> _occurrences = const [];
  bool _loading = false;
  String? _error;
  int _loadSeq = 0;

  List<ProjectMemberItem> _members = const [];
  Map<String, WorkspaceDirectoryPerson> _directory = const {};

  @override
  void initState() {
    super.initState();
    _selectedKey = calendarDateKey(_anchor);
    _load();
    _loadPeople();
  }

  @override
  void didUpdateWidget(covariant WorkspaceProjectCalendarTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _load();
      _loadPeople();
    }
  }

  Future<void> _load() async {
    // Lưới có thể đổi trong lúc đang chờ; bỏ kết quả cũ thay vì ghi đè lưới mới.
    final seq = ++_loadSeq;
    final range = calendarGridRange(_anchor, _mode);
    setState(() => _loading = true);
    final res = await _api.loadCalendar(from: range.from, to: range.to, projectId: widget.project.id);
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _loading = false;
      if (res.ok) {
        _occurrences = res.data ?? const [];
        _error = null;
      } else {
        _occurrences = const [];
        _error = res.error ?? 'workspace.calendar.error_load'.tr();
      }
    });
  }

  Future<void> _loadPeople() async {
    final results = await Future.wait([
      widget.service.getProjectMembers(widget.project.id),
      widget.service.getDirectory(),
    ]);
    if (!mounted) return;
    final members = results[0] as List<ProjectMemberItem>;
    final directory = results[1] as WorkspaceDirectoryResponse?;
    setState(() {
      _members = members;
      _directory = {for (final p in directory?.people ?? const <WorkspaceDirectoryPerson>[]) p.userId: p};
    });
  }

  String _nameOf(String userId) {
    final person = _directory[userId];
    if (person != null) return person.displayName;
    final member = _members.where((m) => m.userId == userId).firstOrNull;
    return member?.fullName ?? member?.email ?? userId;
  }

  /// Sự kiện dự án chỉ mời được thành viên dự án (server cũng chặn người ngoài).
  List<CalendarPerson> get _invitable => [
        for (final m in _members)
          CalendarPerson(
            userId: m.userId,
            name: _nameOf(m.userId),
            subtitle: _directory[m.userId]?.positionName ?? _directory[m.userId]?.email ?? m.email,
          ),
      ];

  /// Web: `myRole` rỗng chỉ xảy ra với quản trị viên tenant.
  bool get _isTenantAdmin => widget.project.permissionsProvided
      ? (widget.project.myRole ?? '').isEmpty
      : AuthProvider.instance?.isTenantAdmin == true;

  void _setAnchor(DateTime anchor, {CalendarMode? mode}) {
    setState(() {
      _anchor = anchor;
      if (mode != null) _mode = mode;
      _selectedKey = calendarDateKey(anchor);
    });
    _load();
  }

  void _openEntry(CalendarEntry entry) {
    if (entry.isDeadline && entry.workItemId != null) {
      widget.onOpenItem?.call(entry.workItemId!);
      return;
    }
    final occurrence = entry.occurrence;
    if (occurrence == null) return;
    // Lịch công tác dựng từ đơn ở HRM: chỉ xem, mở hộp chi tiết đơn thay vì form sửa sự kiện.
    final trip = occurrence.businessTrip;
    if (trip != null) {
      showCalendarBusinessTripSheet(context, trip, nameOf: _nameOf);
      return;
    }
    _openForm(occurrence: occurrence);
  }

  void _openForm({CalendarOccurrence? occurrence, DateTime? date}) {
    final userId = AuthProvider.instance?.userId ?? '';
    showCalendarEventFormSheet(
      context,
      api: _api,
      projectId: widget.project.id,
      currentUserId: userId,
      isTenantAdmin: _isTenantAdmin,
      invitable: _invitable,
      nameOf: _nameOf,
      onChanged: _load,
      occurrence: occurrence,
      defaultDate: date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.access.canWrite;
    final weekdays = calendarWeekdayLabels();
    final days = buildCalendarDays(
      _anchor,
      _mode,
      _occurrences,
      widget.projectItems,
      timeRange: _mode == CalendarMode.week,
    );

    final children = <Widget>[
      if (_error != null)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
        ),
    ];

    if (_mode == CalendarMode.month) {
      final selected = days.where((d) => d.key == _selectedKey).firstOrNull;
      children.add(CalendarMonthGrid(
        days: days,
        selectedKey: _selectedKey,
        onSelectDay: (day) => setState(() => _selectedKey = day.key),
        onCreateOnDay: canWrite ? (day) => _openForm(date: day.date) : null,
        onOpenEntry: _openEntry,
        onShowWeek: (date) => _setAnchor(date, mode: CalendarMode.week),
      ));
      if (selected != null) {
        children.add(const SizedBox(height: 10));
        children.add(CalendarDayAgenda(
          day: selected,
          weekdayLabel: weekdays[selected.date.weekday - 1],
          onOpenEntry: _openEntry,
          onCreate: canWrite ? () => _openForm(date: selected.date) : null,
        ));
      }
    } else {
      for (var i = 0; i < days.length; i++) {
        children.add(CalendarDayAgenda(
          day: days[i],
          weekdayLabel: weekdays[i],
          onOpenEntry: _openEntry,
          onCreate: canWrite ? () => _openForm(date: days[i].date) : null,
        ));
      }
    }

    return Column(
      children: [
        _header(canWrite),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(bool canWrite) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'workspace.calendar.prev'.tr(),
                icon: const Icon(Icons.chevron_left, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => _setAnchor(calendarShiftAnchor(_anchor, _mode, -1)),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _setAnchor(DateTime.now()),
                child: Text('workspace.calendar.today'.tr(), style: const TextStyle(fontSize: 12)),
              ),
              IconButton(
                tooltip: 'workspace.calendar.next'.tr(),
                icon: const Icon(Icons.chevron_right, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => _setAnchor(calendarShiftAnchor(_anchor, _mode, 1)),
              ),
              const Spacer(),
              SegmentedButton<CalendarMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(
                    value: CalendarMode.week,
                    label: Text('workspace.calendar.mode_week'.tr(), style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: CalendarMode.month,
                    label: Text('workspace.calendar.mode_month'.tr(), style: const TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (set) => _setAnchor(_anchor, mode: set.first),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  calendarGridLabel(_anchor, _mode),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('workspace.calendar.loading'.tr(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
              if (canWrite)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () => _openForm(date: _anchor),
                  icon: const Icon(Icons.event_available, size: 16),
                  label: Text('workspace.calendar.new_event'.tr(), style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
