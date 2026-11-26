import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_calendar_api.dart';
import 'calendar_grid_model.dart';

/// Chi tiết một đơn công tác hiện trên lịch dự án (web `business-trip-dialog.tsx`). Chỉ xem, dữ liệu có sẵn trong lần
/// đọc lịch nên không gọi thêm API.
Future<void> showCalendarBusinessTripSheet(
  BuildContext context,
  CalendarBusinessTrip trip, {
  String Function(String userId)? nameOf,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => _BusinessTripSheet(trip: trip, nameOf: nameOf),
  );
}

String _fmtDate(String? iso) {
  final value = iso == null ? null : DateTime.tryParse(iso);
  if (value == null) return iso ?? '—';
  // Ngày trần (YYYY-MM-DD) giữ nguyên ngày; mốc có giờ đổi về giờ máy.
  return calendarDate(iso!.length <= 10 ? value : value.toLocal());
}

String _fmtDateTime(String? iso) {
  final value = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (value == null) return iso ?? '—';
  return '${calendarClock(value)} ${calendarDate(value)}';
}

class _BusinessTripSheet extends StatelessWidget {
  final CalendarBusinessTrip trip;
  final String Function(String userId)? nameOf;

  const _BusinessTripSheet({required this.trip, this.nameOf});

  String get _range {
    if (trip.fromDate == null) return '—';
    return trip.toDate == null || trip.toDate == trip.fromDate
        ? _fmtDate(trip.fromDate)
        : '${_fmtDate(trip.fromDate)} – ${_fmtDate(trip.toDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final who = trip.requesterName ?? nameOf?.call(trip.requesterUserId) ?? trip.requesterUserId;
    final pending = trip.status == 'PENDING';
    final statusBg = pending ? const Color(0x2EF59E0B) : const Color(0x2610B981);
    final statusFg = pending ? const Color(0xFF92400E) : const Color(0xFF047857);
    final statusLabel = pending ? 'workspace.calendar.trip_status_pending'.tr() : 'workspace.calendar.trip_status_approved'.tr();

    final rows = <MapEntry<String, Widget>>[
      MapEntry('workspace.calendar.trip_code'.tr(), Text(trip.code)),
      MapEntry('workspace.calendar.trip_type'.tr(), Text(trip.requestTypeLabel)),
      MapEntry('workspace.calendar.trip_traveler'.tr(), Text(who)),
      MapEntry('workspace.calendar.trip_time'.tr(), Text(_range)),
      MapEntry(
        'workspace.calendar.trip_status'.tr(),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
            child: Text(statusLabel, style: TextStyle(color: statusFg, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
      MapEntry('workspace.calendar.trip_submitted_at'.tr(), Text(_fmtDateTime(trip.submittedAt))),
      if (trip.statusChangedAt != null)
        MapEntry('workspace.calendar.trip_status_changed_at'.tr(), Text(_fmtDateTime(trip.statusChangedAt))),
      MapEntry(
        'workspace.calendar.trip_procedure'.tr(),
        Text(trip.procedureInstanceCode ?? 'workspace.calendar.trip_no_procedure'.tr()),
      ),
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trip.requestTypeLabel} ${trip.code}'.trim(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        if (who.isNotEmpty)
                          Text(
                            'workspace.calendar.trip_subtitle'.tr(args: {'name': who}),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  _sectionTitle('workspace.calendar.trip_info'.tr()),
                  for (final row in rows) _row(row.key, row.value),
                  const SizedBox(height: 12),
                  _sectionTitle('workspace.calendar.trip_details'.tr()),
                  if (trip.details.isEmpty)
                    Text('workspace.calendar.trip_no_details'.tr(),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))
                  else
                    for (final d in trip.details) _row(d.key, Text(d.value)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton(onPressed: () => Navigator.pop(context), child: Text('common.close'.tr())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
      );

  Widget _row(String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ),
            Expanded(child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 13), child: value)),
          ],
        ),
      );
}
