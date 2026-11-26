import 'package:flutter/material.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../services/hrm_attendance_service.dart';
import '../../requests/components/request_form_dialog.dart';
import 'assistant_form_registry.dart';

/// Thao tác Trợ lý của HRM (web `HRM_ASSISTANT_ACTIONS`): mở chính form tạo đơn của trang Đơn từ, điền sẵn bản nháp
/// theo `assistant-request-draft.ts` của web. Giá trị sai định dạng bị bỏ qua: form vẫn mở để người dùng tự nhập.

Future<AssistantFormResult> openAssistantLeaveForm(
  BuildContext context,
  Map<String, dynamic> draft,
  String? variant,
) =>
    _openRequestForm(context, 'leave', draft);

Future<AssistantFormResult> openAssistantOtForm(
  BuildContext context,
  Map<String, dynamic> draft,
  String? variant,
) =>
    _openRequestForm(context, 'ot', draft);

Future<AssistantFormResult> openAssistantBusinessTripForm(
  BuildContext context,
  Map<String, dynamic> draft,
  String? variant,
) =>
    _openRequestForm(context, 'business_trip', draft);

/// Loại đơn do công ty tự tạo (engine GENERIC): form tạo đơn của mobile chưa có loại đơn tuỳ chỉnh.
Future<AssistantFormResult> openAssistantCustomRequestForm(
  BuildContext context,
  Map<String, dynamic> draft,
  String? variant,
) async =>
    AssistantFormResult('unavailable', message: 'assistant.form.hrm_custom_unsupported'.tr());

Future<AssistantFormResult> _openRequestForm(
  BuildContext context,
  String kind,
  Map<String, dynamic> draft,
) async {
  final service = HrmAttendanceService();
  // Cùng dữ liệu trang Đơn từ của tôi nạp trước khi mở form (MyRequestsScreen).
  final loaded = await Future.wait<Object?>([
    service.getAttendanceContext(),
    service.getLeaveTypes(),
  ]);
  if (!context.mounted) return AssistantFormResult.cancelled;

  final created = await showCorrectionFormDialog(
    context: context,
    service: service,
    initialType: kind,
    attendanceContext: loaded[0] as AttendanceContext?,
    availableLeaveTypes: loaded[1] as List<LeaveType>,
    prefill: _prefillOf(kind, draft),
    onSaveDraft: (_) async {},
    onSubmitSuccess: (_) async {},
  );
  if (created == null) return AssistantFormResult.cancelled;

  final id = created.id.trim();
  return AssistantFormResult(
    'saved',
    id: id.isEmpty ? null : id,
    label: _labelOf(created, kind),
    href: id.isEmpty ? null : '/modules/hrm/requests?request=${Uri.encodeQueryComponent(id)}',
  );
}

// ---------------------------------------------------------------------------
// Bản nháp → giá trị form (web assistantRequestPatch)
// ---------------------------------------------------------------------------

const int _maxDescription = 2000;
const int _maxText = 500;
const List<String> _tripTypes = ['DOMESTIC', 'OVERSEAS', 'INTERSITE'];

final RegExp _dateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _dateTimeRe =
    RegExp(r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?$');
final RegExp _idRe = RegExp(r'^\S{1,200}$');

/// 'YYYY-MM-DD' có thật trên lịch, hoặc null.
DateTime? _draftDate(Object? value) {
  if (value is! String) return null;
  final m = _dateRe.firstMatch(value.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final date = DateTime(y, mo, d);
  return date.month == mo && date.day == d ? date : null;
}

/// 'YYYY-MM-DDTHH:mm' (có thể kèm giây) là giờ địa phương; chuỗi có múi giờ thì đổi sang giờ của máy.
({DateTime date, TimeOfDay time})? _draftDateTime(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  final m = _dateTimeRe.firstMatch(text);
  if (m == null) return null;
  final day = _draftDate(m.group(1));
  final hour = int.parse(m.group(2)!);
  final minute = int.parse(m.group(3)!);
  if (day == null || hour > 23 || minute > 59) return null;
  if (m.group(4) == null) return (date: day, time: TimeOfDay(hour: hour, minute: minute));
  final normalized =
      text.replaceFirst(' ', 'T').replaceFirstMapped(RegExp(r'([+-]\d{2})(\d{2})$'), (x) => '${x[1]}:${x[2]}');
  final at = DateTime.tryParse(normalized)?.toLocal();
  if (at == null) return null;
  return (date: DateTime(at.year, at.month, at.day), time: TimeOfDay(hour: at.hour, minute: at.minute));
}

String? _draftText(Object? value, int max) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  return text.length > max ? text.substring(0, max) : text;
}

String? _draftId(Object? value) => value is String && _idRe.hasMatch(value) ? value : null;

/// Khoảng thời gian chính: có `fromAt`/`toAt` thì lấy cả giờ (nghỉ theo giờ); không thì `fromDate`/`toDate` với giờ
/// mặc định của form (làm thêm giờ chỉ nhận `fromAt`/`toAt`). Thiếu ngày kết thúc thì kết thúc cùng ngày bắt đầu.
RequestFormPrefill _prefillOf(String kind, Map<String, dynamic> draft) {
  final allowDates = kind != 'ot';
  DateTime? fromDate;
  DateTime? toDate;
  TimeOfDay? fromTime;
  TimeOfDay? toTime;

  final from = _draftDateTime(draft['fromAt']);
  final to = _draftDateTime(draft['toAt']);
  if (from != null) {
    fromDate = from.date;
    fromTime = from.time;
  } else if (allowDates) {
    fromDate = _draftDate(draft['fromDate']);
  }
  if (to != null) {
    toDate = to.date;
    toTime = to.time;
  } else if (allowDates) {
    toDate = _draftDate(draft['toDate']);
  }
  if (fromDate != null && toDate != null && toDate.isBefore(fromDate)) {
    toDate = null;
    toTime = null;
  }
  // Form mới mở (chưa có ngày kết thúc khác): kết thúc cùng ngày bắt đầu.
  if (fromDate != null && toDate == null) toDate = fromDate;

  final isTrip = kind == 'business_trip';
  final tripType = draft['businessTripType'];
  return RequestFormPrefill(
    fromDate: fromDate,
    toDate: toDate,
    fromTime: fromTime,
    toTime: toTime,
    leaveTypeId: kind == 'leave' ? _draftId(draft['leaveTypeId']) : null,
    reasonId: kind == 'leave' ? null : _draftId(draft['reasonId']),
    description: _draftText(draft['description'], _maxDescription),
    destination: isTrip ? _draftText(draft['destination'], _maxText) : null,
    businessTripType: isTrip && tripType is String && _tripTypes.contains(tripType) ? tripType : null,
    projectId: isTrip ? _draftId(draft['projectId']) : null,
  );
}

// ---------------------------------------------------------------------------
// Nhãn của đơn vừa gửi: loại đơn và thời gian (web RequestFormResult.label)
// ---------------------------------------------------------------------------

String _labelOf(AttendanceCorrection created, String kind) {
  final typeKey = switch ((created.kind ?? '').toUpperCase()) {
    'OVERTIME' => 'hrm_requests.type_overtime',
    'BUSINESS_TRIP' => 'hrm_requests.type_business_trip',
    'ATTENDANCE_CORRECTION' => 'hrm_requests.type_attendance_correction',
    'LEAVE' => 'hrm_requests.type_leave',
    _ => switch (kind) {
        'ot' => 'hrm_requests.type_overtime',
        'business_trip' => 'hrm_requests.type_business_trip',
        _ => 'hrm_requests.type_leave',
      },
  };
  final from = _dayOf(created.fromDate) ?? _dayOf(created.requestDate);
  final to = _dayOf(created.toDate);
  final period = from == null ? '' : (to == null || to == from ? from : '$from - $to');
  return [typeKey.tr(), period].where((part) => part.isNotEmpty).join(' ');
}

/// 'dd/MM/yyyy' của chuỗi ngày (hoặc ngày giờ) máy chủ trả về.
String? _dayOf(String? value) {
  if (value == null || value.length < 10) return null;
  final day = _draftDate(value.substring(0, 10));
  if (day == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(day.day)}/${two(day.month)}/${day.year}';
}
