import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_calendar_api.dart';
import 'calendar_grid_model.dart';
import 'calendar_people_picker.dart';

/// Mở form tạo / xem / sửa sự kiện (web `event-form.tsx`). [onChanged] chạy sau mỗi lần ghi thành công để tab tải lại
/// lịch (web tăng `calendarToken`).
Future<void> showCalendarEventFormSheet(
  BuildContext context, {
  required WorkspaceCalendarApi api,
  required String projectId,
  required String currentUserId,
  required bool isTenantAdmin,
  required List<CalendarPerson> invitable,
  required String Function(String userId) nameOf,
  required VoidCallback onChanged,
  CalendarOccurrence? occurrence,
  DateTime? defaultDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => CalendarEventFormSheet(
      api: api,
      projectId: projectId,
      currentUserId: currentUserId,
      isTenantAdmin: isTenantAdmin,
      invitable: invitable,
      nameOf: nameOf,
      onChanged: onChanged,
      occurrence: occurrence,
      defaultDate: defaultDate,
    ),
  );
}

const _eventTypes = ['meeting', 'activity', 'other'];
const _frequencies = ['DAILY', 'WEEKLY', 'MONTHLY'];
const _weekdayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

class CalendarEventFormSheet extends StatefulWidget {
  final WorkspaceCalendarApi api;
  final String projectId;
  final String currentUserId;
  final bool isTenantAdmin;
  final List<CalendarPerson> invitable;
  final String Function(String userId) nameOf;
  final VoidCallback onChanged;
  final CalendarOccurrence? occurrence;
  final DateTime? defaultDate;

  const CalendarEventFormSheet({
    super.key,
    required this.api,
    required this.projectId,
    required this.currentUserId,
    required this.isTenantAdmin,
    required this.invitable,
    required this.nameOf,
    required this.onChanged,
    this.occurrence,
    this.defaultDate,
  });

  @override
  State<CalendarEventFormSheet> createState() => _CalendarEventFormSheetState();
}

class _CalendarEventFormSheetState extends State<CalendarEventFormSheet> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _interval = TextEditingController(text: '1');
  final _count = TextEditingController(text: '10');

  String _eventType = 'meeting';
  late DateTime? _date;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  bool _allDay = false;
  bool _repeats = false;
  String _freq = 'WEEKLY';
  List<int> _byDay = [];
  List<String> _participants = [];
  String _scope = 'single';
  String? _organizerId;
  String? _myResponse;
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  List<CalendarSchedulingWarning> _warnings = const [];

  CalendarOccurrence? get _occ => widget.occurrence;
  bool get _canEdit => _occ == null || _organizerId == widget.currentUserId || widget.isTenantAdmin;
  bool get _isInvitee => _occ != null && !_canEdit && _myResponse != null;

  @override
  void initState() {
    super.initState();
    final occ = _occ;
    if (occ == null) {
      _organizerId = widget.currentUserId;
      final d = widget.defaultDate ?? DateTime.now();
      _date = DateTime(d.year, d.month, d.day);
      return;
    }
    _organizerId = occ.organizerUserId;
    _title.text = occ.title;
    _location.text = occ.location ?? '';
    _eventType = occ.eventType;
    _date = DateTime(occ.startAt.year, occ.startAt.month, occ.startAt.day);
    _start = TimeOfDay.fromDateTime(occ.startAt);
    _end = TimeOfDay.fromDateTime(occ.endAt);
    _allDay = occ.allDay;
    _scope = occ.isRecurring ? 'single' : 'all';
    _loadDetail(occ.eventId);
  }

  /// Người tham dự và mô tả không có trong dữ liệu lưới; bỏ bước này mà lưu sẽ xoá sạch người được mời.
  Future<void> _loadDetail(String eventId) async {
    setState(() => _loading = true);
    final res = await widget.api.getEvent(eventId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      final detail = res.data;
      if (!res.ok || detail == null) {
        _error = res.error ?? 'workspace.calendar.error_load_detail'.tr();
        return;
      }
      _description.text = detail.description ?? '';
      // Người tổ chức luôn có mặt; không đưa vào danh sách chọn.
      _participants = detail.participants.where((p) => !p.isOrganizer).map((p) => p.userId).toList();
      _myResponse = detail.participants.where((p) => p.userId == widget.currentUserId).firstOrNull?.responseStatus;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  int? get _ownWeekday => _date == null ? null : _date!.weekday - 1;

  List<int> get _effectiveByDay => _byDay.isNotEmpty ? _byDay : [?_ownWeekday];

  String? _buildRecurrence() {
    if (!_repeats) return null;
    final interval = [int.tryParse(_interval.text.trim()) ?? 1, 1].reduce((a, b) => a > b ? a : b);
    final count = [int.tryParse(_count.text.trim()) ?? 1, 1].reduce((a, b) => a > b ? a : b);
    // Luôn kèm COUNT: chuỗi vô hạn bị server từ chối.
    final days = _freq == 'WEEKLY' ? ([..._effectiveByDay]..sort()) : <int>[];
    final byDay = days.isEmpty ? '' : ';BYDAY=${days.map((d) => _weekdayCodes[d]).join(',')}';
    return 'FREQ=$_freq;INTERVAL=$interval$byDay;COUNT=$count';
  }

  String _instant(TimeOfDay t) =>
      DateTime(_date!.year, _date!.month, _date!.day, t.hour, t.minute).toUtc().toIso8601String();

  Future<void> _submit() async {
    if (!_canEdit) {
      Navigator.pop(context);
      return;
    }
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'workspace.calendar.error_title_required'.tr());
      return;
    }
    if (_date == null) {
      setState(() => _error = 'workspace.calendar.error_date_required'.tr());
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final common = <String, dynamic>{
      'title': _title.text,
      if (_description.text.isNotEmpty) 'description': _description.text,
      if (_location.text.isNotEmpty) 'location': _location.text,
      'eventType': _eventType,
      'startAt': _instant(_allDay ? const TimeOfDay(hour: 0, minute: 0) : _start),
      'endAt': _instant(_allDay ? const TimeOfDay(hour: 23, minute: 59) : _end),
      'allDay': _allDay,
      'participantUserIds': _participants,
    };
    final occ = _occ;
    final res = occ != null
        ? await widget.api.updateEvent(occ.eventId, {...common, 'scope': _scope, 'occurrenceDate': occ.occurrenceDate})
        : await widget.api.createEvent({
            ...common,
            'projectId': widget.projectId,
            'recurrenceRule': ?_buildRecurrence(),
          });
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _submitting = false;
        _error = res.error ?? 'workspace.calendar.error_save'.tr();
      });
      return;
    }
    widget.onChanged();
    final warnings = res.data?.warnings ?? const [];
    // Trùng lịch người chỉ là cảnh báo: giữ form mở để người tổ chức đọc rồi tự quyết.
    if (warnings.isNotEmpty) {
      setState(() {
        _warnings = warnings;
        _submitting = false;
      });
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _respond(String response) async {
    final occ = _occ;
    if (occ == null) return;
    setState(() {
      _error = null;
      _submitting = true;
    });
    final res = await widget.api.respondToEvent(occ.eventId, response);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (res.ok) {
        _myResponse = response;
      } else {
        _error = res.error ?? 'workspace.calendar.error_respond'.tr();
      }
    });
    if (res.ok) widget.onChanged();
  }

  Future<void> _remove() async {
    final occ = _occ;
    if (occ == null) return;
    setState(() {
      _error = null;
      _submitting = true;
    });
    final res = await widget.api.cancelEvent(occ.eventId, scope: _scope, occurrenceDate: occ.occurrenceDate);
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _submitting = false;
        _error = res.error ?? 'workspace.calendar.error_cancel'.tr();
      });
      return;
    }
    widget.onChanged();
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      builder: (ctx, child) =>
          MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (!mounted || picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get _titleText => _occ == null
      ? 'workspace.calendar.form_title_create'.tr()
      : _canEdit
          ? 'workspace.calendar.form_title_edit'.tr()
          : 'workspace.calendar.form_title_view'.tr();

  String get _subtitle {
    if (!_canEdit) return 'workspace.calendar.form_sub_organizer'.tr(args: {'name': widget.nameOf(_organizerId ?? '')});
    if (_occ?.isRecurring == true) return 'workspace.calendar.form_sub_recurring'.tr();
    return 'workspace.calendar.form_sub_project'.tr();
  }

  String get _removeLabel => switch (_scope) {
        'single' => 'workspace.calendar.cancel_single'.tr(),
        'following' => 'workspace.calendar.cancel_following'.tr(),
        _ => 'workspace.calendar.cancel_all'.tr(),
      };

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _loading;
    final edit = _canEdit;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_titleText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(_subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: busy ? null : () => Navigator.pop(context)),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (_isInvitee) ..._responseRow(),
                _label('workspace.calendar.field_title'.tr()),
                TextField(
                  controller: _title,
                  enabled: edit,
                  maxLength: 200,
                  decoration: _input('workspace.calendar.field_title_placeholder'.tr()),
                ),
                _label('workspace.calendar.field_type'.tr()),
                DropdownButtonFormField<String>(
                  initialValue: _eventTypes.contains(_eventType) ? _eventType : 'other',
                  isExpanded: true,
                  decoration: _input(null),
                  items: [
                    for (final t in _eventTypes)
                      DropdownMenuItem(value: t, child: Text('workspace.calendar.type_$t'.tr())),
                  ],
                  onChanged: edit ? (v) => setState(() => _eventType = v ?? _eventType) : null,
                ),
                _label('workspace.calendar.field_location'.tr()),
                TextField(
                  controller: _location,
                  enabled: edit,
                  maxLength: 255,
                  decoration: _input('workspace.calendar.field_location_placeholder'.tr()),
                ),
                _label('workspace.calendar.field_date'.tr()),
                _pickerBox(_date == null ? '' : calendarDate(_date!), edit ? _pickDate : null, Icons.event),
                if (!_allDay) ...[
                  _label('workspace.calendar.field_time_range'.tr()),
                  Row(
                    children: [
                      Expanded(child: _pickerBox(_hhmm(_start), edit ? () => _pickTime(true) : null, Icons.schedule)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-')),
                      Expanded(child: _pickerBox(_hhmm(_end), edit ? () => _pickTime(false) : null, Icons.schedule)),
                    ],
                  ),
                ],
                CheckboxListTile(
                  value: _allDay,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('workspace.calendar.field_all_day'.tr()),
                  onChanged: edit ? (v) => setState(() => _allDay = v ?? false) : null,
                ),
                _label('workspace.calendar.field_participants'.tr()),
                CalendarPeoplePicker(
                  people: widget.invitable,
                  selected: _participants,
                  exclude: [?_organizerId],
                  nameOf: widget.nameOf,
                  enabled: edit,
                  onChanged: (ids) => setState(() => _participants = ids),
                ),
                if (edit) _hint('workspace.calendar.field_participants_hint'.tr()),
                _label('workspace.calendar.field_description'.tr()),
                TextField(
                  controller: _description,
                  enabled: edit,
                  minLines: 2,
                  maxLines: 5,
                  decoration: _input('workspace.calendar.field_description_placeholder'.tr()),
                ),
                if (_occ == null && edit) ..._recurrenceFields(),
                if (_occ?.isRecurring == true && edit) ...[
                  _label('workspace.calendar.field_scope'.tr()),
                  DropdownButtonFormField<String>(
                    initialValue: _scope,
                    isExpanded: true,
                    decoration: _input(null),
                    items: [
                      for (final s in ['single', 'following', 'all'])
                        DropdownMenuItem(value: s, child: Text('workspace.calendar.scope_$s'.tr())),
                    ],
                    onChanged: (v) => setState(() => _scope = v ?? _scope),
                  ),
                ],
                if (_warnings.isNotEmpty) _warningBox(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                  ),
                if (_occ != null && edit)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                      ),
                      onPressed: busy ? null : _remove,
                      child: Text(_removeLabel),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  if (edit) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => Navigator.pop(context),
                        child: Text(_occ != null ? 'common.close'.tr() : 'workspace.calendar.action_cancel'.tr()),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(!edit
                              ? 'common.close'.tr()
                              : _occ != null
                                  ? 'workspace.calendar.action_save'.tr()
                                  : 'workspace.calendar.action_create'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _responseRow() => [
        _label('workspace.calendar.your_response'.tr()),
        Wrap(
          spacing: 8,
          children: [
            for (final r in ['accepted', 'tentative', 'declined'])
              ChoiceChip(
                label: Text('workspace.calendar.respond_$r'.tr()),
                selected: _myResponse == r,
                onSelected: _submitting ? null : (_) => _respond(r),
              ),
          ],
        ),
      ];

  List<Widget> _recurrenceFields() => [
        CheckboxListTile(
          value: _repeats,
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('workspace.calendar.field_repeats'.tr()),
          onChanged: (v) => setState(() => _repeats = v ?? false),
        ),
        if (_repeats) ...[
          _label('workspace.calendar.field_freq'.tr()),
          DropdownButtonFormField<String>(
            initialValue: _freq,
            isExpanded: true,
            decoration: _input(null),
            items: [
              for (final f in _frequencies)
                DropdownMenuItem(value: f, child: Text('workspace.calendar.freq_${f.toLowerCase()}'.tr())),
            ],
            onChanged: (v) => setState(() => _freq = v ?? _freq),
          ),
          _label('workspace.calendar.field_interval'.tr()),
          TextField(controller: _interval, keyboardType: TextInputType.number, decoration: _input(null)),
          _hint('workspace.calendar.field_interval_hint'.tr()),
          _label('workspace.calendar.field_count'.tr()),
          TextField(controller: _count, keyboardType: TextInputType.number, decoration: _input(null)),
          _hint('workspace.calendar.field_count_hint'.tr()),
          if (_freq == 'WEEKLY') ...[
            _label('workspace.calendar.field_by_day'.tr()),
            Wrap(
              spacing: 6,
              children: [
                for (var d = 0; d < 7; d++)
                  FilterChip(
                    label: Text('workspace.calendar.weekday_${['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][d]}'.tr()),
                    selected: _effectiveByDay.contains(d),
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      final base = [..._effectiveByDay];
                      _byDay = base.contains(d) ? (base..remove(d)) : [...base, d];
                    }),
                  ),
              ],
            ),
            _hint('workspace.calendar.field_by_day_hint'.tr()),
          ],
        ],
      ];

  Widget _warningBox() => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('workspace.calendar.warnings_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final w in _warnings)
              Text('• ${widget.nameOf(w.userId)} — ${w.message}', style: const TextStyle(fontSize: 12)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('workspace.calendar.warnings_ack'.tr()),
              ),
            ),
          ],
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      );

  InputDecoration _input(String? hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        counterText: '',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      );

  Widget _pickerBox(String text, VoidCallback? onTap, IconData icon) => InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: _input(null).copyWith(enabled: onTap != null, suffixIcon: Icon(icon, size: 18)),
          child: Text(text),
        ),
      );
}
