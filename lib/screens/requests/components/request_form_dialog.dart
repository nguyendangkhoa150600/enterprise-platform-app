import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../models/workspace_models.dart';
import '../../../services/hrm_attendance_service.dart';
import '../../../utils/error_handler.dart';

/// 4 loại đơn đồng bộ 1:1 với Web ESS Request Catalog & Tạo đơn nhanh
class RequestCategoryOption {
  final String key;
  final String label;
  final IconData icon;

  const RequestCategoryOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

const List<RequestCategoryOption> kRequestCategories = [
  RequestCategoryOption(
    key: 'leave',
    label: 'Đơn xin nghỉ',
    icon: Icons.event_note_outlined,
  ),
  RequestCategoryOption(
    key: 'ot',
    label: 'Đơn tăng ca',
    icon: Icons.access_time_filled_rounded,
  ),
  RequestCategoryOption(
    key: 'business_trip',
    label: 'Đơn công tác',
    icon: Icons.business_center_outlined,
  ),
  RequestCategoryOption(
    key: 'correction',
    label: 'Đơn giải trình chấm công',
    icon: Icons.edit_calendar_outlined,
  ),
];

/// Mục lý do nghỉ phép đồng bộ 1:1 với Web ESS (Badge Có lương / Không lương & Trừ quỹ phép năm)
class LeaveReasonItem {
  final String name;
  final bool isPaid;
  final bool isAnnualLeave;

  const LeaveReasonItem({
    required this.name,
    this.isPaid = true,
    this.isAnnualLeave = false,
  });
}

const List<LeaveReasonItem> kDefaultLeaveReasons = [
  LeaveReasonItem(
    name: 'Nghỉ bù do làm thêm / tăng ca',
    isPaid: true,
  ),
  LeaveReasonItem(
    name: 'Nghỉ không lương',
    isPaid: false,
  ),
  LeaveReasonItem(
    name: 'Nghỉ phép năm',
    isPaid: true,
    isAnnualLeave: true,
  ),
  LeaveReasonItem(
    name: 'Nghỉ ốm',
    isPaid: false,
  ),
];

/// Danh mục lý do mặc định cho Làm thêm giờ (Đồng bộ 1:1 với Web ESS & DEFAULT_REQUEST_REASONS)
const List<HrmRequestReason> kDefaultOtReasons = [
  HrmRequestReason(
    id: 'ot_work',
    kind: 'OVERTIME',
    code: 'OT_WORK',
    name: 'Theo yêu cầu công việc',
    description: 'Làm thêm để hoàn thành công việc được giao',
    paid: true,
    requiresDescription: false,
    sortOrder: 10,
  ),
  HrmRequestReason(
    id: 'ot_other',
    kind: 'OVERTIME',
    code: 'OT_OTHER',
    name: 'Khác',
    description: 'Lý do khác, cần mô tả cụ thể',
    paid: true,
    requiresDescription: true,
    sortOrder: 90,
  ),
];

/// Danh mục lý do mặc định cho Công tác (Đồng bộ 1:1 với Web ESS)
const List<HrmRequestReason> kDefaultTripReasons = [
  HrmRequestReason(
    id: 'trip_plan',
    kind: 'BUSINESS_TRIP',
    code: 'TRIP_PLAN',
    name: 'Công tác theo kế hoạch',
    description: 'Công tác theo kế hoạch đã được giao',
    paid: true,
    requiresDescription: false,
    sortOrder: 10,
  ),
  HrmRequestReason(
    id: 'trip_other',
    kind: 'BUSINESS_TRIP',
    code: 'TRIP_OTHER',
    name: 'Khác',
    description: 'Lý do khác, cần mô tả cụ thể',
    paid: true,
    requiresDescription: true,
    sortOrder: 90,
  ),
];

/// Danh mục lý do mặc định cho Giải trình công (Đồng bộ 1:1 với Web ESS)
const List<HrmRequestReason> kDefaultCorrectionReasons = [
  HrmRequestReason(
    id: 'cor_forgot',
    kind: 'ATTENDANCE_CORRECTION',
    code: 'COR_FORGOT',
    name: 'Quên chấm công',
    description: 'Quên chấm vào hoặc chấm ra',
    paid: true,
    requiresDescription: false,
    sortOrder: 10,
  ),
  HrmRequestReason(
    id: 'cor_device',
    kind: 'ATTENDANCE_CORRECTION',
    code: 'COR_DEVICE',
    name: 'Lỗi thiết bị hoặc mạng',
    description: 'Không chấm được do lỗi thiết bị hoặc mạng',
    paid: true,
    requiresDescription: false,
    sortOrder: 20,
  ),
  HrmRequestReason(
    id: 'cor_other',
    kind: 'ATTENDANCE_CORRECTION',
    code: 'COR_OTHER',
    name: 'Khác',
    description: 'Lý do khác, cần mô tả cụ thể',
    paid: true,
    requiresDescription: true,
    sortOrder: 90,
  ),
];

/// Khoảng thời gian nghỉ (hỗ trợ thêm nhiều khoảng nghỉ độc lập, chuẩn ca HC 1:1 Web ESS)
class TimeInterval {
  DateTime fromDate;
  DateTime toDate;
  TimeOfDay fromTime;
  TimeOfDay toTime;
  String kind; // 'leave', 'ot', 'business_trip'
  String nextDayRest; // 'NONE' (Làm việc bình thường), 'HALF' (Nghỉ nửa ngày), 'FULL' (Nghỉ cả ngày)

  TimeInterval({
    required this.fromDate,
    required this.toDate,
    this.fromTime = const TimeOfDay(hour: 7, minute: 30),
    this.toTime = const TimeOfDay(hour: 17, minute: 0),
    this.kind = 'leave',
    this.nextDayRest = 'NONE',
  });

  int get workingMinutes {
    final startMinutes = fromTime.hour * 60 + fromTime.minute;
    final endMinutes = toTime.hour * 60 + toTime.minute;
    final dayDiff = toDate.difference(fromDate).inDays;

    if (dayDiff < 0) return 0;
    if (dayDiff == 0) {
      if (endMinutes <= startMinutes) return 0;
      return calculateDayWorkingMinutes(startMinutes, endMinutes);
    } else {
      // Ngày đầu
      int total = calculateDayWorkingMinutes(startMinutes, 17 * 60);
      // Các ngày ở giữa (mỗi ngày trọn ca 480 phút)
      if (dayDiff > 1) {
        total += (dayDiff - 1) * 480;
      }
      // Ngày cuối
      total += calculateDayWorkingMinutes(7 * 60 + 30, endMinutes);
      return total;
    }
  }

  double get hours {
    final startMinutes = fromTime.hour * 60 + fromTime.minute;
    final endMinutes = toTime.hour * 60 + toTime.minute;
    final dayDiff = toDate.difference(fromDate).inDays;

    if (kind == 'ot') {
      if (dayDiff < 0) return 0.0;
      if (dayDiff == 0) {
        if (endMinutes <= startMinutes) return 0.0;
        return (endMinutes - startMinutes) / 60.0;
      } else {
        final d1 = (24 * 60 - startMinutes) / 60.0;
        final mid = (dayDiff - 1) * 24.0;
        final dN = endMinutes / 60.0;
        return d1 + (mid > 0 ? mid : 0) + dN;
      }
    }
    return workingMinutes / 60.0;
  }

  double get days {
    if (kind == 'ot') {
      return hours / 8.0;
    }

    final dFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final dTo = DateTime(toDate.year, toDate.month, toDate.day);
    final dayDiff = dTo.difference(dFrom).inDays;
    final startMinutes = fromTime.hour * 60 + fromTime.minute;
    final endMinutes = toTime.hour * 60 + toTime.minute;

    if (dayDiff < 0 || (dayDiff == 0 && endMinutes <= startMinutes)) return 0.0;

    if (dayDiff == 0) {
      final mins = calculateDayWorkingMinutes(startMinutes, endMinutes);
      if (mins >= 480 - 1) {
        return 1.0;
      } else if ((mins - 240).abs() <= 30) {
        return 0.5;
      } else {
        // Nghỉ/công tác thời gian lẻ quy về bước 0.5 gần nhất (khớp 1:1 với Web)
        return math.max(0.5, ((mins / 480.0) * 2).round() / 2.0);
      }
    } else {
      // Đơn nhiều ngày
      double d = 0.0;
      final d1Mins = calculateDayWorkingMinutes(startMinutes, 17 * 60);
      d += d1Mins >= 479 ? 1.0 : (d1Mins <= 0 ? 0.0 : math.min(1.0, math.max(0.5, ((d1Mins / 480.0) * 2).round() / 2.0)));
      if (dayDiff > 1) {
        d += (dayDiff - 1);
      }
      final dnMins = calculateDayWorkingMinutes(7 * 60 + 30, endMinutes);
      d += dnMins >= 479 ? 1.0 : (dnMins <= 0 ? 0.0 : math.min(1.0, math.max(0.5, ((dnMins / 480.0) * 2).round() / 2.0)));
      return d;
    }
  }

  String? get error {
    final dFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final dTo = DateTime(toDate.year, toDate.month, toDate.day);
    final dayDiff = dTo.difference(dFrom).inDays;
    final startMinutes = fromTime.hour * 60 + fromTime.minute;
    final endMinutes = toTime.hour * 60 + toTime.minute;

    if (dayDiff < 0 || (dayDiff == 0 && endMinutes <= startMinutes)) {
      return 'Thời điểm kết thúc phải sau thời điểm bắt đầu.';
    }

    if (kind == 'leave') {
      if (dayDiff == 0) {
        final mins = calculateDayWorkingMinutes(startMinutes, endMinutes);
        if (mins == 0) {
          return '${_isoDate(fromDate)}: khoảng đã chọn không nằm trong ca làm việc hoặc chỉ rơi vào giờ nghỉ giữa ca (11:30 - 13:00).';
        }
      }
    } else if (kind == 'business_trip') {
      if (dayDiff == 0) {
        final mins = calculateDayWorkingMinutes(startMinutes, endMinutes);
        // Nếu chọn trong khoảng giờ hành chính nhưng chỉ rơi vào giờ nghỉ trưa giữa ca
        if (mins == 0 && startMinutes >= 7 * 60 + 30 && endMinutes <= 17 * 60) {
          return '${_isoDate(fromDate)}: khoảng đã chọn chỉ rơi vào giờ nghỉ trưa giữa ca (11:30 - 13:00).';
        }
      }
    }
    return null;
  }
}

/// Tính số phút làm việc thực tế trong ngày theo ca Hành chính (HC) chuẩn 1:1 với Web ESS
int calculateDayWorkingMinutes(int startMinutes, int endMinutes) {
  const shiftStart = 7 * 60 + 30; // 450 (07:30)
  const breakStart = 11 * 60 + 30; // 690 (11:30)
  const breakEnd = 13 * 60; // 780 (13:00)
  const shiftEnd = 17 * 60; // 1020 (17:00)

  final effStart = math.max<int>(startMinutes, shiftStart);
  final effEnd = math.min<int>(endMinutes, shiftEnd);
  if (effEnd <= effStart) return 0;

  // Ca sáng: 07:30 - 11:30 (240 phút)
  final morning = math.max<int>(0, math.min<int>(effEnd, breakStart) - math.max<int>(effStart, shiftStart));
  // Ca chiều: 13:00 - 17:00 (240 phút)
  final afternoon = math.max<int>(0, math.min<int>(effEnd, shiftEnd) - math.max<int>(effStart, breakEnd));
  return morning + afternoon;
}

String _isoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Chuyển mốc ngày & giờ Việt Nam (UTC+7) sang chuỗi chuẩn ISO 8601 UTC (.000Z) cho Backend ERP
String _toUtcIso(DateTime date, TimeOfDay time) {
  final vnLocal = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  final utc = vnLocal.subtract(const Duration(hours: 7));
  final y = utc.year.toString().padLeft(4, '0');
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  final h = utc.hour.toString().padLeft(2, '0');
  final min = utc.minute.toString().padLeft(2, '0');
  final s = utc.second.toString().padLeft(2, '0');
  return '$y-$m-${d}T$h:$min:$s.000Z';
}

double calculateWorkingHours(DateTime fromDate, TimeOfDay fromTime, DateTime toDate, TimeOfDay toTime) {
  return TimeInterval(fromDate: fromDate, toDate: toDate, fromTime: fromTime, toTime: toTime).hours;
}

double calculateWorkingDays(double hours) {
  return hours / 8.0;
}

String _normalizeRequestKey(String? raw) {
  if (raw == null || raw.isEmpty) return 'leave';
  final l = raw.toLowerCase();
  if (l.contains('tăng ca') || l.contains('làm thêm') || l.contains('overtime') || l == 'ot') {
    return 'ot';
  }
  if (l.contains('công tác') || l.contains('business_trip') || l.contains('trip')) {
    return 'business_trip';
  }
  if (l.contains('giải trình') || l.contains('bổ sung công') || l.contains('correction')) {
    return 'correction';
  }
  return 'leave';
}

/// Giá trị điền sẵn lúc mở form (bản nháp của Trợ lý Savina, web `RequestFormInitial`); ô null giữ mặc định của form.
/// Ngày giờ áp vào khoảng thời gian đầu của loại đơn đang mở; lý do, dự án chỉ chọn khi có trong danh mục tải về.
class RequestFormPrefill {
  final DateTime? fromDate;
  final DateTime? toDate;
  final TimeOfDay? fromTime;
  final TimeOfDay? toTime;
  final String? leaveTypeId;
  final String? reasonId;
  final String? description;
  final String? destination;

  /// DOMESTIC | OVERSEAS | INTERSITE.
  final String? businessTripType;
  final String? projectId;

  const RequestFormPrefill({
    this.fromDate,
    this.toDate,
    this.fromTime,
    this.toTime,
    this.leaveTypeId,
    this.reasonId,
    this.description,
    this.destination,
    this.businessTripType,
    this.projectId,
  });
}

/// Mở form tạo đơn; trả về đơn vừa gửi (nhiều khoảng thời gian là đơn cuối cùng), null khi đóng không gửi.
Future<AttendanceCorrection?> showCorrectionFormDialog({
  required BuildContext context,
  required HrmAttendanceService service,
  AttendanceRecord? item,
  String? initialType,
  AttendanceCorrection? draftItem,
  AttendanceContext? attendanceContext,
  List<LeaveType> availableLeaveTypes = const [],
  RequestFormPrefill? prefill,
  required Future<void> Function(AttendanceCorrection draft) onSaveDraft,
  required Future<void> Function(AttendanceCorrection? deletedDraft) onSubmitSuccess,
}) {
  String selectedCategoryKey = _normalizeRequestKey(initialType);

  // Parse draft or item
  String initialReason = '';
  if (draftItem != null) {
    initialReason = draftItem.reason;
    final match = RegExp(r'^\[(.*?)\]').firstMatch(draftItem.reason);
    if (match != null) {
      final tag = match.group(1)!;
      initialReason = draftItem.reason.substring(match.end).trim();
      selectedCategoryKey = _normalizeRequestKey(tag);
    } else if (draftItem.leaveTypeName != null && draftItem.leaveTypeName!.isNotEmpty) {
      selectedCategoryKey = _normalizeRequestKey(draftItem.leaveTypeName);
    }
  } else if (item != null) {
    selectedCategoryKey = 'correction';
  }

  final now = DateTime.now();
  final initialFromDate = DateTime(now.year, now.month, now.day);
  final initialToDate = DateTime(now.year, now.month, now.day);

  // List of leave intervals (cho phép thêm nhiều khoảng nghỉ)
  final leaveIntervals = <TimeInterval>[
    TimeInterval(
      fromDate: initialFromDate,
      toDate: initialToDate,
      fromTime: const TimeOfDay(hour: 7, minute: 30),
      toTime: const TimeOfDay(hour: 17, minute: 0),
      kind: 'leave',
    ),
  ];

  // List of OT intervals
  final otIntervals = <TimeInterval>[
    TimeInterval(
      fromDate: initialFromDate,
      toDate: initialToDate,
      fromTime: const TimeOfDay(hour: 17, minute: 30),
      toTime: const TimeOfDay(hour: 20, minute: 30),
      kind: 'ot',
    ),
  ];

  // List of Business trip intervals
  final tripIntervals = <TimeInterval>[
    TimeInterval(
      fromDate: initialFromDate,
      toDate: initialToDate,
      fromTime: const TimeOfDay(hour: 7, minute: 30),
      toTime: const TimeOfDay(hour: 17, minute: 0),
      kind: 'business_trip',
    ),
  ];

  // Form specific state
  HrmRequestReason? selectedLeaveReason;
  HrmRequestReason? selectedOtReason;
  HrmRequestReason? selectedTripReason;
  HrmRequestReason? selectedCorrectionReason;

  List<HrmRequestReason> otReasons = List.from(kDefaultOtReasons);
  List<HrmRequestReason> tripReasons = List.from(kDefaultTripReasons);
  List<HrmRequestReason> correctionReasons = List.from(kDefaultCorrectionReasons);
  bool didFetchServerReasons = false;

  final descController = TextEditingController(text: initialReason);

  // Specific fields for Business Trip
  String tripScope = 'Công tác trong nước (Nội địa)';
  final tripLocationCtrl = TextEditingController();
  final tripDeptCtrl = TextEditingController(text: 'Phòng Hành chính - Tổng hợp');
  String tripTransport = 'Không cần phương tiện';
  String tripExternalVehicle = 'Taxi hoặc xe ngoài';
  ProjectItem? selectedTripProject;

  // Specific fields for OT
  String otNextDayRest = 'NONE';
  ProjectItem? selectedOtProject;
  List<ProjectItem> linkableProjects = [];

  // Specific fields for Attendance Correction
  DateTime correctionDate = DateTime(now.year, now.month, now.day);
  String correctionTimeType = 'Giờ vào'; // 'Giờ vào' | 'Giờ ra'
  TimeOfDay correctionTime = const TimeOfDay(hour: 7, minute: 30);
  if (item != null) {
    correctionDate = DateTime.tryParse(item.workDate) ?? DateTime(now.year, now.month, now.day);
    if (item.firstCheckInAt != null && item.lastCheckOutAt == null) {
      correctionTimeType = 'Giờ ra';
      correctionTime = const TimeOfDay(hour: 17, minute: 0);
    } else if (item.firstCheckInAt == null && item.lastCheckOutAt != null) {
      correctionTimeType = 'Giờ vào';
      correctionTime = const TimeOfDay(hour: 7, minute: 30);
    }
  } else if (draftItem != null) {
    if (draftItem.newCheckOutAt != null) {
      correctionTimeType = 'Giờ ra';
      final parsed = DateTime.tryParse(draftItem.newCheckOutAt!)?.toLocal();
      if (parsed != null) {
        correctionDate = DateTime(parsed.year, parsed.month, parsed.day);
        correctionTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      }
    } else if (draftItem.newCheckInAt != null) {
      correctionTimeType = 'Giờ vào';
      final parsed = DateTime.tryParse(draftItem.newCheckInAt!)?.toLocal();
      if (parsed != null) {
        correctionDate = DateTime(parsed.year, parsed.month, parsed.day);
        correctionTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      }
    }
  }

  // Điền sẵn từ bản nháp của Trợ lý (lý do, dự án áp khi danh mục tải xong, xem bên dưới).
  if (prefill != null) {
    final target = switch (selectedCategoryKey) {
      'ot' => otIntervals.first,
      'business_trip' => tripIntervals.first,
      'leave' => leaveIntervals.first,
      _ => null,
    };
    if (target != null) {
      if (prefill.fromDate != null) target.fromDate = prefill.fromDate!;
      if (prefill.toDate != null) target.toDate = prefill.toDate!;
      if (prefill.fromTime != null) target.fromTime = prefill.fromTime!;
      if (prefill.toTime != null) target.toTime = prefill.toTime!;
    }
    if (prefill.description != null) descController.text = prefill.description!;
    if (prefill.destination != null) tripLocationCtrl.text = prefill.destination!;
    switch (prefill.businessTripType) {
      case 'OVERSEAS':
        tripScope = 'Công tác nước ngoài (Quốc tế)';
      case 'INTERSITE':
        tripScope = 'Công tác nội bộ liên chi nhánh';
      case 'DOMESTIC':
        tripScope = 'Công tác trong nước (Nội địa)';
    }
  }

  // Attachments & submission state
  String? selectedFileName;
  int? selectedFileSize;
  bool isSubmitting = false;
  bool isSavingDraft = false;
  String? modalErrorMessage;

  return showModalBottomSheet<AttendanceCorrection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          final currentCategory = kRequestCategories.firstWhere(
            (c) => c.key == selectedCategoryKey,
            orElse: () => kRequestCategories.first,
          );

          // Priority 1: Map from real availableLeaveTypes from server (Zero-Mock Policy)
          final leaveReasonsList = <HrmRequestReason>[];
          if (availableLeaveTypes.isNotEmpty) {
            for (final lt in availableLeaveTypes) {
              if (lt.code.toUpperCase().contains('SENIOR') || lt.name.toLowerCase().contains('thâm niên')) {
                continue; // Lọc bỏ loại thâm niên cũ theo chuẩn Web selectableLeaveTypesOf
              }
              final isAnnual = lt.name.toLowerCase().contains('phép năm') ||
                  lt.code.toUpperCase().contains('ANNUAL') ||
                  lt.code.toUpperCase().contains('AL');
              final isUnpaid = lt.name.toLowerCase().contains('không lương') ||
                  lt.code.toUpperCase().contains('UNPAID') ||
                  lt.name.toLowerCase().contains('unpaid');
              leaveReasonsList.add(
                HrmRequestReason(
                  id: lt.id,
                  kind: 'LEAVE',
                  code: lt.code,
                  name: lt.name,
                  description: isAnnual ? 'Trừ trực tiếp vào quỹ phép năm hiện có' : (lt.description ?? ''),
                  paid: isUnpaid ? false : lt.isPaid,
                  requiresDescription: false,
                  sortOrder: 10,
                ),
              );
            }
          }

          // Priority 2: Fallback to exact 4 items matching Web ESS
          if (leaveReasonsList.isEmpty) {
            leaveReasonsList.addAll(kDefaultLeaveReasons.map((r) => HrmRequestReason(
              id: r.name,
              kind: 'LEAVE',
              code: r.isAnnualLeave ? 'ANNUAL' : 'OTHER',
              name: r.name,
              description: r.isAnnualLeave ? 'Trừ trực tiếp vào quỹ phép năm hiện có' : null,
              paid: r.isPaid,
              requiresDescription: false,
              sortOrder: 10,
            )));
          }

          selectedLeaveReason ??=
              leaveReasonsList.where((r) => r.id == prefill?.leaveTypeId).firstOrNull ?? leaveReasonsList.first;

          // Fetch dynamic reasons and linkable projects from backend (Zero-Mock Policy)
          if (!didFetchServerReasons) {
            didFetchServerReasons = true;
            Future.wait([
              service.getRequestReasons('OVERTIME'),
              service.getRequestReasons('BUSINESS_TRIP'),
              service.getRequestReasons('ATTENDANCE_CORRECTION'),
              service.getLinkableProjects(),
            ]).then((results) {
              if (results[0].isNotEmpty) otReasons = results[0] as List<HrmRequestReason>;
              if (results[1].isNotEmpty) tripReasons = results[1] as List<HrmRequestReason>;
              if (results[2].isNotEmpty) correctionReasons = results[2] as List<HrmRequestReason>;
              if (results[3].isNotEmpty) linkableProjects = results[3] as List<ProjectItem>;
              final wantedReasonId = prefill?.reasonId;
              if (wantedReasonId != null) {
                selectedOtReason = otReasons.where((r) => r.id == wantedReasonId).firstOrNull ?? selectedOtReason;
                selectedTripReason = tripReasons.where((r) => r.id == wantedReasonId).firstOrNull ?? selectedTripReason;
              }
              final wantedProjectId = prefill?.projectId;
              if (wantedProjectId != null) {
                selectedTripProject =
                    linkableProjects.where((p) => p.id == wantedProjectId).firstOrNull ?? selectedTripProject;
              }
              selectedOtReason = otReasons.firstWhere((r) => r.id == selectedOtReason?.id, orElse: () => otReasons.first);
              selectedTripReason = tripReasons.firstWhere((r) => r.id == selectedTripReason?.id, orElse: () => tripReasons.first);
              selectedCorrectionReason = correctionReasons.firstWhere((r) => r.id == selectedCorrectionReason?.id, orElse: () => correctionReasons.first);
              setModalState(() {});
            }).catchError((e) {
              debugPrint('[request_form_dialog] fetch request reasons error: $e');
            });
          }

          selectedOtReason ??= otReasons.first;
          selectedTripReason ??= tripReasons.first;
          selectedCorrectionReason ??= correctionReasons.first;

          if (draftItem != null) {
            final otMatch = otReasons.where((r) => draftItem.reason.contains(r.name) || (r.code.isNotEmpty && draftItem.reason.contains(r.code))).firstOrNull;
            if (otMatch != null) selectedOtReason = otMatch;
            final tripMatch = tripReasons.where((r) => draftItem.reason.contains(r.name) || (r.code.isNotEmpty && draftItem.reason.contains(r.code))).firstOrNull;
            if (tripMatch != null) selectedTripReason = tripMatch;
            final corMatch = correctionReasons.where((r) => draftItem.reason.contains(r.name) || (r.code.isNotEmpty && draftItem.reason.contains(r.code))).firstOrNull;
            if (corMatch != null) selectedCorrectionReason = corMatch;
          }

          return Container(
            height: MediaQuery.of(modalContext).size.height * 0.94,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(currentCategory.icon, size: 20, color: const Color(0xFF1E293B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentCategory.label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 22),
                        onPressed: () => Navigator.pop(ctx),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Modal Body (Scrollable Form)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (modalErrorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    modalErrorMessage!,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => setModalState(() => modalErrorMessage = null),
                                  child: const Icon(Icons.close, color: Color(0xFF991B1B), size: 16),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // ==========================================
                        // 1. SELECT LOẠI ĐƠN ĐỀ NGHỊ (4 LOẠI ĐỒNG BỘ)
                        // ==========================================
                        const Text(
                          'Loại đơn đề nghị *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              menuMaxHeight: 280,
                              borderRadius: BorderRadius.circular(12),
                              value: selectedCategoryKey,
                              items: kRequestCategories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.key,
                                  child: Row(
                                    children: [
                                      Icon(c.icon, size: 17, color: const Color(0xFF2563EB)),
                                      const SizedBox(width: 8),
                                      Text(
                                        c.label,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (newKey) {
                                if (newKey != null && newKey != selectedCategoryKey) {
                                  setModalState(() {
                                    selectedCategoryKey = newKey;
                                    modalErrorMessage = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ==========================================
                        // DYNAMIC FORM CONTENT BASED ON SELECTED KEY
                        // ==========================================
                        if (selectedCategoryKey == 'leave') ...[
                          _buildLeaveForm(
                            context: modalContext,
                            setModalState: setModalState,
                            reasons: leaveReasonsList,
                            selectedReason: selectedLeaveReason!,
                            onReasonChanged: (r) => setModalState(() => selectedLeaveReason = r),
                            descController: descController,
                            intervals: leaveIntervals,
                            onClearError: () => setModalState(() => modalErrorMessage = null),
                          ),
                        ] else if (selectedCategoryKey == 'ot') ...[
                          _buildOvertimeForm(
                            context: modalContext,
                            setModalState: setModalState,
                            reasons: otReasons,
                            selectedReason: selectedOtReason!,
                            onReasonChanged: (r) => setModalState(() => selectedOtReason = r),
                            descController: descController,
                            intervals: otIntervals,
                            nextDayRest: otNextDayRest,
                            onNextDayRestChanged: (v) => setModalState(() => otNextDayRest = v),
                            projects: linkableProjects,
                            selectedProject: selectedOtProject,
                            onProjectChanged: (p) => setModalState(() => selectedOtProject = p),
                            onClearError: () => setModalState(() => modalErrorMessage = null),
                          ),
                        ] else if (selectedCategoryKey == 'business_trip') ...[
                          _buildBusinessTripForm(
                            context: modalContext,
                            setModalState: setModalState,
                            reasons: tripReasons,
                            selectedReason: selectedTripReason!,
                            onReasonChanged: (r) => setModalState(() => selectedTripReason = r),
                            descController: descController,
                            intervals: tripIntervals,
                            tripScope: tripScope,
                            onTripScopeChanged: (s) => setModalState(() => tripScope = s),
                            locationCtrl: tripLocationCtrl,
                            deptCtrl: tripDeptCtrl,
                            transport: tripTransport,
                            onTransportChanged: (tr) => setModalState(() => tripTransport = tr),
                            externalVehicle: tripExternalVehicle,
                            onExternalVehicleChanged: (v) => setModalState(() => tripExternalVehicle = v),
                            projects: linkableProjects,
                            selectedProject: selectedTripProject,
                            onProjectChanged: (p) => setModalState(() => selectedTripProject = p),
                            onClearError: () => setModalState(() => modalErrorMessage = null),
                          ),
                        ] else if (selectedCategoryKey == 'correction') ...[
                          _buildCorrectionForm(
                            context: modalContext,
                            setModalState: setModalState,
                            reasons: correctionReasons,
                            selectedReason: selectedCorrectionReason!,
                            onReasonChanged: (r) => setModalState(() => selectedCorrectionReason = r),
                            descController: descController,
                            workDate: correctionDate,
                            onPickWorkDate: (d) => setModalState(() => correctionDate = d),
                            timeType: correctionTimeType,
                            onTimeTypeChanged: (t) => setModalState(() {
                              correctionTimeType = t;
                              if (t == 'Giờ ra' && correctionTime.hour < 12) {
                                correctionTime = const TimeOfDay(hour: 17, minute: 0);
                              } else if (t == 'Giờ vào' && correctionTime.hour >= 12) {
                                correctionTime = const TimeOfDay(hour: 7, minute: 30);
                              }
                            }),
                            correctionTime: correctionTime,
                            onPickTime: (t) => setModalState(() => correctionTime = t),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // File Attachment Box (Common across forms)
                        _buildAttachmentSection(
                          selectedFileName: selectedFileName,
                          selectedFileSize: selectedFileSize,
                          onPickFile: () async {
                            final picked = await FilePicker.pickFile(type: FileType.any);
                            if (picked != null) {
                              final pickedSize = await picked.length() ?? 0;
                              setModalState(() {
                                selectedFileName = picked.name;
                                selectedFileSize = pickedSize;
                              });
                            }
                          },
                          onRemoveFile: () {
                            setModalState(() {
                              selectedFileName = null;
                              selectedFileSize = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Pinned Error Banner above footer actions (always visible when scrolled)
                if (modalErrorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      border: Border(
                        top: BorderSide(color: Color(0xFFFECDD3)),
                        bottom: BorderSide(color: Color(0xFFFECDD3)),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            modalErrorMessage!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setModalState(() => modalErrorMessage = null),
                          child: const Icon(Icons.close, color: Color(0xFF991B1B), size: 16),
                        ),
                      ],
                    ),
                  ),

                // Modal Actions (Matching Web: Hủy | Gửi duyệt đơn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Nút Hủy
                      OutlinedButton(
                        onPressed: (isSubmitting || isSavingDraft) ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Nút Gửi duyệt đơn
                      ElevatedButton.icon(
                        onPressed: (isSubmitting || isSavingDraft)
                            ? null
                            : () async {
                                // Validation thời gian không hợp lệ (thời gian lẻ không khớp nửa ca / cả ca chuẩn Web ESS)
                                if (selectedCategoryKey == 'leave') {
                                  final errInterval = leaveIntervals.cast<TimeInterval?>().firstWhere(
                                    (it) => it?.error != null,
                                    orElse: () => null,
                                  );
                                  if (errInterval != null) {
                                    setModalState(() => modalErrorMessage = errInterval.error);
                                    return;
                                  }
                                }
                                if (selectedCategoryKey == 'ot') {
                                  final errInterval = otIntervals.cast<TimeInterval?>().firstWhere(
                                    (it) => it?.error != null,
                                    orElse: () => null,
                                  );
                                  if (errInterval != null) {
                                    setModalState(() => modalErrorMessage = errInterval.error);
                                    return;
                                  }
                                }
                                if (selectedCategoryKey == 'business_trip') {
                                  final errInterval = tripIntervals.cast<TimeInterval?>().firstWhere(
                                    (it) => it?.error != null,
                                    orElse: () => null,
                                  );
                                  if (errInterval != null) {
                                    setModalState(() => modalErrorMessage = errInterval.error);
                                    return;
                                  }
                                }

                                if (selectedCategoryKey == 'ot') {
                                  final reqDesc = selectedOtReason?.requiresDescription ?? false;
                                  if (reqDesc && descController.text.trim().isEmpty) {
                                    setModalState(() => modalErrorMessage = 'Vui lòng nhập mô tả chi tiết cho lý do này.');
                                    return;
                                  }
                                }
                                if (selectedCategoryKey == 'business_trip') {
                                  final reqDesc = selectedTripReason?.requiresDescription ?? false;
                                  if (reqDesc && descController.text.trim().isEmpty) {
                                    setModalState(() => modalErrorMessage = 'Vui lòng nhập nội dung công việc công tác.');
                                    return;
                                  }
                                }
                                if (selectedCategoryKey == 'correction') {
                                  final reqDesc = selectedCorrectionReason?.requiresDescription ?? false;
                                  if (reqDesc && descController.text.trim().isEmpty) {
                                    setModalState(() => modalErrorMessage = 'Vui lòng nhập mô tả chi tiết cho lý do này.');
                                    return;
                                  }
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  modalErrorMessage = null;
                                });

                                AttendanceCorrection? created;
                                try {
                                  if (selectedCategoryKey == 'leave') {
                                    final reasonTag = selectedLeaveReason?.name ?? 'Nghỉ phép năm';
                                    final fullReason = '[$reasonTag] ${descController.text.trim()}'.trim();

                                    String? targetLeaveTypeId;
                                    if (selectedLeaveReason != null && selectedLeaveReason!.id.length > 20) {
                                      targetLeaveTypeId = selectedLeaveReason!.id;
                                    } else if (availableLeaveTypes.isNotEmpty) {
                                      for (final lt in availableLeaveTypes) {
                                        if (fullReason.toLowerCase().contains(lt.name.toLowerCase()) ||
                                            lt.name.toLowerCase().contains(fullReason.toLowerCase())) {
                                          targetLeaveTypeId = lt.id;
                                          break;
                                        }
                                      }
                                      targetLeaveTypeId ??= availableLeaveTypes.first.id;
                                    }

                                    // Gửi đơn nghỉ (Đồng bộ 1:1 với Web ESS: tạo đơn nhiều khoản trong 1 giao dịch qua extraRanges)
                                    final mainInterval = leaveIntervals.first;
                                    final mainFDate = '${mainInterval.fromDate.year}-${mainInterval.fromDate.month.toString().padLeft(2, '0')}-${mainInterval.fromDate.day.toString().padLeft(2, '0')}';
                                    final mainTDate = '${mainInterval.toDate.year}-${mainInterval.toDate.month.toString().padLeft(2, '0')}-${mainInterval.toDate.day.toString().padLeft(2, '0')}';

                                    List<Map<String, dynamic>>? extraRangesPayload;
                                    if (leaveIntervals.length > 1) {
                                      extraRangesPayload = leaveIntervals.sublist(1).map((extra) {
                                        final efDate = '${extra.fromDate.year}-${extra.fromDate.month.toString().padLeft(2, '0')}-${extra.fromDate.day.toString().padLeft(2, '0')}';
                                        final etDate = '${extra.toDate.year}-${extra.toDate.month.toString().padLeft(2, '0')}-${extra.toDate.day.toString().padLeft(2, '0')}';
                                        return {
                                          'fromDate': efDate,
                                          'toDate': etDate,
                                          'fromAt': _toUtcIso(extra.fromDate, extra.fromTime),
                                          'toAt': _toUtcIso(extra.toDate, extra.toTime),
                                          'duration': extra.days,
                                        };
                                      }).toList();
                                    }

                                    created = await service.createCorrection(
                                      employeeId: attendanceContext?.employeeId,
                                      attendanceId: item?.id,
                                      leaveTypeId: targetLeaveTypeId,
                                      draftId: draftItem?.id,
                                      expectedUpdatedAt: draftItem?.createdAt,
                                      requestDate: mainFDate,
                                      fromDate: mainFDate,
                                      toDate: mainTDate,
                                      newCheckInAt: _toUtcIso(mainInterval.fromDate, mainInterval.fromTime),
                                      newCheckOutAt: _toUtcIso(mainInterval.toDate, mainInterval.toTime),
                                      reason: fullReason,
                                      duration: mainInterval.days,
                                      requestKind: 'LEAVE',
                                      extraRanges: extraRangesPayload,
                                    );
                                  } else if (selectedCategoryKey == 'ot') {
                                    final reasonTag = selectedOtReason?.name ?? 'Làm thêm giờ (Overtime)';
                                    final fullReason = '[$reasonTag] ${descController.text.trim()}'.trim();
                                    final actualReasonId = (selectedOtReason != null && !selectedOtReason!.id.startsWith('ot_'))
                                        ? selectedOtReason!.id
                                        : null;

                                    for (int i = 0; i < otIntervals.length; i++) {
                                      final interval = otIntervals[i];
                                      final fDate = '${interval.fromDate.year}-${interval.fromDate.month.toString().padLeft(2, '0')}-${interval.fromDate.day.toString().padLeft(2, '0')}';
                                      final tDate = '${interval.toDate.year}-${interval.toDate.month.toString().padLeft(2, '0')}-${interval.toDate.day.toString().padLeft(2, '0')}';

                                      created = await service.createCorrection(
                                        employeeId: attendanceContext?.employeeId,
                                        attendanceId: item?.id,
                                        reasonId: actualReasonId,
                                        projectId: selectedOtProject?.id,
                                        projectCode: selectedOtProject?.code,
                                        projectName: selectedOtProject?.name,
                                        draftId: (i == 0) ? draftItem?.id : null,
                                        expectedUpdatedAt: (i == 0) ? draftItem?.createdAt : null,
                                        requestDate: fDate,
                                        fromDate: fDate,
                                        toDate: tDate,
                                        newCheckInAt: _toUtcIso(interval.fromDate, interval.fromTime),
                                        newCheckOutAt: _toUtcIso(interval.toDate, interval.toTime),
                                        reason: fullReason,
                                        duration: interval.hours,
                                        requestKind: 'OVERTIME',
                                        nextDayRest: interval.nextDayRest,
                                      );
                                    }
                                  } else if (selectedCategoryKey == 'business_trip') {
                                    final reasonTag = selectedTripReason?.name ?? 'Đi công tác';
                                    final loc = tripLocationCtrl.text.trim().isNotEmpty ? ' tại ${tripLocationCtrl.text.trim()}' : '';
                                    final fullReason = '[$reasonTag$loc] Địa điểm: ${tripLocationCtrl.text.trim()}. Hình thức: $tripScope. Nhiệm vụ: ${descController.text.trim()}'.trim();
                                    final actualReasonId = (selectedTripReason != null && !selectedTripReason!.id.startsWith('trip_'))
                                        ? selectedTripReason!.id
                                        : null;

                                    String actualVehicle = '';
                                    if (tripTransport == 'Xe công ty') {
                                      actualVehicle = 'Xe công ty';
                                    } else if (tripTransport == 'Phương tiện ngoài (tự sắp xếp)') {
                                      actualVehicle = tripExternalVehicle;
                                    }

                                    String actualTripType = 'DOMESTIC';
                                    if (tripScope.contains('nước ngoài') || tripScope.contains('Quốc tế')) {
                                      actualTripType = 'OVERSEAS';
                                    } else if (tripScope.contains('liên chi nhánh')) {
                                      actualTripType = 'INTERSITE';
                                    }

                                    for (int i = 0; i < tripIntervals.length; i++) {
                                      final interval = tripIntervals[i];
                                      final fDate = '${interval.fromDate.year}-${interval.fromDate.month.toString().padLeft(2, '0')}-${interval.fromDate.day.toString().padLeft(2, '0')}';
                                      final tDate = '${interval.toDate.year}-${interval.toDate.month.toString().padLeft(2, '0')}-${interval.toDate.day.toString().padLeft(2, '0')}';

                                      created = await service.createCorrection(
                                        employeeId: attendanceContext?.employeeId,
                                        attendanceId: item?.id,
                                        reasonId: actualReasonId,
                                        projectId: selectedTripProject?.id,
                                        projectCode: selectedTripProject?.code,
                                        projectName: selectedTripProject?.name,
                                        draftId: (i == 0) ? draftItem?.id : null,
                                        expectedUpdatedAt: (i == 0) ? draftItem?.createdAt : null,
                                        requestDate: fDate,
                                        fromDate: fDate,
                                        toDate: tDate,
                                        newCheckInAt: _toUtcIso(interval.fromDate, interval.fromTime),
                                        newCheckOutAt: _toUtcIso(interval.toDate, interval.toTime),
                                        reason: fullReason,
                                        duration: interval.days,
                                        requestKind: 'BUSINESS_TRIP',
                                        businessTripType: actualTripType,
                                        destination: tripLocationCtrl.text.trim().isNotEmpty
                                            ? tripLocationCtrl.text.trim()
                                            : 'Công tác theo kế hoạch',
                                        workDepartment: tripDeptCtrl.text.trim(),
                                        vehicle: actualVehicle.isNotEmpty ? actualVehicle : null,
                                      );
                                    }
                                  } else if (selectedCategoryKey == 'correction') {
                                    final reasonTag = selectedCorrectionReason?.name ?? 'Đơn giải trình / Bổ sung công';
                                    final timeStr = '${correctionTime.hour.toString().padLeft(2, '0')}:${correctionTime.minute.toString().padLeft(2, '0')}';
                                    final fullReason = '[$reasonTag - $correctionTimeType: $timeStr] ${descController.text.trim()}'.trim();
                                    final actualReasonId = (selectedCorrectionReason != null && !selectedCorrectionReason!.id.startsWith('cor_'))
                                        ? selectedCorrectionReason!.id
                                        : null;

                                    final fDate = '${correctionDate.year}-${correctionDate.month.toString().padLeft(2, '0')}-${correctionDate.day.toString().padLeft(2, '0')}';

                                    created = await service.createCorrection(
                                      employeeId: attendanceContext?.employeeId,
                                      attendanceId: item?.id,
                                      reasonId: actualReasonId,
                                      draftId: draftItem?.id,
                                      expectedUpdatedAt: draftItem?.createdAt,
                                      requestDate: fDate,
                                      fromDate: fDate,
                                      toDate: fDate,
                                      newCheckInAt: correctionTimeType == 'Giờ vào'
                                          ? _toUtcIso(correctionDate, correctionTime)
                                          : _toUtcIso(correctionDate, const TimeOfDay(hour: 7, minute: 30)),
                                      newCheckOutAt: correctionTimeType == 'Giờ ra'
                                          ? _toUtcIso(correctionDate, correctionTime)
                                          : _toUtcIso(correctionDate, const TimeOfDay(hour: 17, minute: 0)),
                                      reason: fullReason,
                                      duration: 1.0,
                                      requestKind: 'ATTENDANCE_CORRECTION',
                                    );
                                  }

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx, created);
                                  }

                                  if (draftItem != null && !draftItem.id.startsWith('DFT-')) {
                                    service.deleteDraft(draftItem.id, expectedUpdatedAt: draftItem.createdAt);
                                  }

                                  await onSubmitSuccess(draftItem);

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                            const SizedBox(width: 8),
                                            Text('Đã gửi ${currentCategory.label} thành công!'),
                                          ],
                                        ),
                                        backgroundColor: const Color(0xFF059669),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  final rawMsg = e.toString().replaceFirst('Exception: ', '').trim();
                                  final parsedMsg = rawMsg.isNotEmpty
                                      ? rawMsg
                                      : ApiErrorHandler.parse(e, defaultMessage: 'Gửi duyệt đơn thất bại.');
                                  setModalState(() {
                                    isSubmitting = false;
                                    modalErrorMessage = parsedMsg;
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                parsedMsg,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(0xFFDC2626),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 6),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                              )
                            : const Icon(Icons.send_rounded, size: 16, color: Color(0xFF0F172A)),
                        label: Text(
                          isSubmitting ? 'Đang gửi...' : 'Gửi duyệt đơn',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ============================================================================
// 1. FORM ĐƠN XIN NGHỈ (MATCHING SCREENSHOT 1, 2, 3 1:1)
// ============================================================================
Widget _buildLeaveForm({
  required BuildContext context,
  required StateSetter setModalState,
  required List<HrmRequestReason> reasons,
  required HrmRequestReason selectedReason,
  required ValueChanged<HrmRequestReason> onReasonChanged,
  required TextEditingController descController,
  required List<TimeInterval> intervals,
  VoidCallback? onClearError,
}) {
  // Compute total days across all intervals
  final totalDays = intervals.fold<double>(0.0, (acc, item) => acc + item.days);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Lý do * (Đồng bộ 1:1 với Web ESS - Có lương / Không lương / Trừ quỹ phép năm)
      _buildReasonSelectorField(
        context: context,
        label: 'Lý do *',
        reasons: reasons,
        selectedReason: selectedReason,
        onReasonChanged: onReasonChanged,
        showPaid: true,
        isLeave: true,
      ),
      const SizedBox(height: 14),

      // Mô tả (nhập thêm chi tiết nếu cần)
      const Text('Mô tả (nhập thêm chi tiết nếu cần)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildTextField(
        controller: descController,
        hint: 'Nhập thêm chi tiết nếu cần (không bắt buộc)...',
        maxLines: 3,
      ),
      const SizedBox(height: 14),

      // ==========================================
      // DANH SÁCH CÁC KHOẢNG NGHỈ (KHOẢNG 1, KHOẢNG 2...)
      // ==========================================
      for (int i = 0; i < intervals.length; i++) ...[
        if (intervals.length > 1) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Khoảng nghỉ ${i + 1}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              if (i > 0)
                InkWell(
                  onTap: () {
                    setModalState(() {
                      intervals.removeAt(i);
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        SizedBox(width: 3),
                        Text(
                          'Xoá',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ] else if (i > 0) ...[
          const SizedBox(height: 14),
        ],

        _buildDateTimeRangeRow(
          context: context,
          fromLabel: intervals.length > 1 ? 'Từ ngày giờ nghỉ *' : 'Từ ngày giờ *',
          toLabel: intervals.length > 1 ? 'Đến ngày giờ nghỉ *' : 'Đến ngày giờ *',
          fromDate: intervals[i].fromDate,
          toDate: intervals[i].toDate,
          fromTime: intervals[i].fromTime,
          toTime: intervals[i].toTime,
          errorText: intervals[i].error,
          onPickFromDate: (d) => setModalState(() {
            intervals[i].fromDate = d;
            if (intervals[i].toDate.isBefore(d)) intervals[i].toDate = d;
            onClearError?.call();
          }),
          onPickToDate: (d) => setModalState(() {
            intervals[i].toDate = d;
            onClearError?.call();
          }),
          onPickFromTime: (t) => setModalState(() {
            intervals[i].fromTime = t;
            onClearError?.call();
          }),
          onPickToTime: (t) => setModalState(() {
            intervals[i].toTime = t;
            onClearError?.call();
          }),
        ),
        if (i < intervals.length - 1) const SizedBox(height: 14),
      ],
      const SizedBox(height: 12),

      // Nút Thêm khoảng nghỉ & helper text bên dưới
      OutlinedButton.icon(
        onPressed: () {
          setModalState(() {
            final last = intervals.last;
            final nextDate = last.toDate.add(const Duration(days: 1));
            intervals.add(
              TimeInterval(
                fromDate: nextDate,
                toDate: nextDate,
                fromTime: const TimeOfDay(hour: 7, minute: 30),
                toTime: const TimeOfDay(hour: 17, minute: 0),
                kind: 'leave',
              ),
            );
          });
        },
        icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF1E293B)),
        label: const Text('Thêm khoảng nghỉ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        ),
      ),
      if (intervals.length > 1) ...[
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Đơn nghỉ nhiều khoản: tạo trong một giao dịch (${intervals.length} khoản), duyệt/hủy cùng nhau.',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),

      // ==========================================
      // THẺ TÍNH TOÁN SỐ NGÀY NGHỈ & BẢNG KHOẢN (MATCHING SCREENSHOT 3)
      // ==========================================
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Số ngày nghỉ tính toán', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                if (intervals.length > 1)
                  Text(
                    '${totalDays.toStringAsFixed(totalDays % 1 == 0 ? 0 : 1)} ngày (${intervals.length} khoảng)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (intervals.length == 1) ...[
              Text(
                '${totalDays.toStringAsFixed(totalDays % 1 == 0 ? 0 : 1)} ngày (Trọn ${totalDays.toStringAsFixed(totalDays % 1 == 0 ? 0 : 1)} ngày công)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
              ),
              if (intervals[0].error != null) ...[
                const SizedBox(height: 4),
                Text(
                  intervals[0].error!,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                ),
              ],
            ] else ...[
              const SizedBox(height: 8),
              // Bảng chi tiết từng khoảng (Matching Screenshot 3)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF9C3), // Light yellow matching Web
                        borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Khoản', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)))),
                          Expanded(flex: 5, child: Text('Thời gian', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)))),
                          Expanded(flex: 2, child: Text('Số ngày', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)))),
                        ],
                      ),
                    ),
                    // Table Rows
                    for (int i = 0; i < intervals.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: Text('Khoảng nghỉ ${i + 1}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)))),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${intervals[i].fromDate.day}/${intervals[i].fromDate.month} ${_formatTime(intervals[i].fromTime)} - ${intervals[i].toDate.day}/${intervals[i].toDate.month} ${_formatTime(intervals[i].toTime)}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                                  ),
                                  if (intervals[i].error != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      intervals[i].error!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFDC2626),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${intervals[i].days.toStringAsFixed(intervals[i].days % 1 == 0 ? 0 : 1)} ngày',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < intervals.length - 1) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ],
                    // Table Footer: Tổng cộng
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
                      ),
                      child: Row(
                        children: [
                          const Expanded(flex: 8, child: Text('Tổng cộng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${totalDays.toStringAsFixed(totalDays % 1 == 0 ? 0 : 1)} ngày',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

// ============================================================================
// 2. FORM ĐƠN TĂNG CA (HỖ TRỢ THÊM KHOẢNG LÀM THÊM)
// ============================================================================
Widget _buildOvertimeForm({
  required BuildContext context,
  required StateSetter setModalState,
  required List<HrmRequestReason> reasons,
  required HrmRequestReason selectedReason,
  required ValueChanged<HrmRequestReason> onReasonChanged,
  required TextEditingController descController,
  required List<TimeInterval> intervals,
  String nextDayRest = 'NONE',
  ValueChanged<String>? onNextDayRestChanged,
  required List<ProjectItem> projects,
  required ProjectItem? selectedProject,
  required ValueChanged<ProjectItem?> onProjectChanged,
  VoidCallback? onClearError,
}) {
  final totalHours = intervals.fold<double>(0.0, (acc, item) => acc + item.hours);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Lý do * (Chọn từ danh mục request_reasons - Đồng bộ 1:1 với Web ESS)
      _buildReasonSelectorField(
        context: context,
        label: 'Lý do *',
        reasons: reasons,
        selectedReason: selectedReason,
        onReasonChanged: onReasonChanged,
        showPaid: true,
      ),
      const SizedBox(height: 14),

      // Mô tả nội dung công việc làm thêm
      Text(
        selectedReason.requiresDescription
            ? 'Mô tả nội dung công việc làm thêm *'
            : 'Mô tả (nhập thêm chi tiết nếu cần)',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
      ),
      const SizedBox(height: 6),
      _buildTextField(
        controller: descController,
        hint: selectedReason.requiresDescription
            ? 'Nhập mô tả chi tiết công việc và lý do làm thêm (bắt buộc)...'
            : 'Nhập thêm chi tiết nếu cần (không bắt buộc)...',
        maxLines: 3,
      ),
      const SizedBox(height: 14),

      // Danh sách khoảng làm thêm
      for (int i = 0; i < intervals.length; i++) ...[
        if (i > 0) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Khoảng làm thêm ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              InkWell(
                onTap: () => setModalState(() => intervals.removeAt(i)),
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    SizedBox(width: 3),
                    Text('Xoá', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],

        // 1. Ngày làm thêm (Chỉ chọn 1 ngày duy nhất cho mỗi khoảng, đồng bộ 1:1 với Web)
        Text(
          i == 0 ? 'Ngày làm thêm *' : 'Ngày làm thêm (khoảng ${i + 1}) *',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 6),
        _buildDateCapsule(
          context: context,
          date: intervals[i].fromDate,
          onSelected: (d) => setModalState(() {
            intervals[i].fromDate = d;
            intervals[i].toDate = d;
            onClearError?.call();
          }),
        ),
        const SizedBox(height: 10),

        // 2. Từ giờ & Đến giờ (Đặt cạnh nhau trên 1 hàng như Web)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Từ giờ *',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  _buildTimeCapsule(
                    context: context,
                    time: intervals[i].fromTime,
                    label: 'giờ bắt đầu',
                    onSelected: (t) => setModalState(() {
                      intervals[i].fromTime = t;
                      onClearError?.call();
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đến giờ *',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  _buildTimeCapsule(
                    context: context,
                    time: intervals[i].toTime,
                    label: 'giờ kết thúc',
                    onSelected: (t) => setModalState(() {
                      intervals[i].toTime = t;
                      onClearError?.call();
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (intervals[i].error != null && intervals[i].error!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            intervals[i].error!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFDC2626),
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 10),

        // Sáng hôm sau (Khớp 1:1 với Web: Làm việc bình thường / Nghỉ nửa ngày / Nghỉ cả ngày)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sáng hôm sau',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            _buildDropdownContainer(
              value: intervals[i].nextDayRest == 'HALF'
                  ? 'Nghỉ nửa ngày'
                  : (intervals[i].nextDayRest == 'FULL' ? 'Nghỉ cả ngày' : 'Làm việc bình thường'),
              hint: 'Làm việc bình thường',
              items: const ['Làm việc bình thường', 'Nghỉ nửa ngày', 'Nghỉ cả ngày'],
              onChanged: (v) {
                setModalState(() {
                  if (v == 'Nghỉ nửa ngày') {
                    intervals[i].nextDayRest = 'HALF';
                  } else if (v == 'Nghỉ cả ngày') {
                    intervals[i].nextDayRest = 'FULL';
                  } else {
                    intervals[i].nextDayRest = 'NONE';
                  }
                });
              },
            ),
          ],
        ),
      ],
      const SizedBox(height: 12),

      // + Thêm khoảng làm thêm button
      OutlinedButton.icon(
        onPressed: () {
          setModalState(() {
            final last = intervals.last;
            final nextDate = last.toDate.add(const Duration(days: 1));
            intervals.add(
              TimeInterval(
                fromDate: nextDate,
                toDate: nextDate,
                fromTime: const TimeOfDay(hour: 17, minute: 30),
                toTime: const TimeOfDay(hour: 20, minute: 30),
                kind: 'ot',
                nextDayRest: 'NONE',
              ),
            );
          });
        },
        icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF1E293B)),
        label: const Text('Thêm khoảng làm thêm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        ),
      ),
      const SizedBox(height: 14),

      // Bảng chi tiết từng khoảng làm thêm (Đồng bộ 1:1 với Web ESS)
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF9C3), // Light yellow matching Web
                borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Khoản', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)))),
                  Expanded(flex: 5, child: Text('Thời gian', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)))),
                  Expanded(flex: 2, child: Text('Số giờ', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)))),
                ],
              ),
            ),
            // Table Rows
            for (int i = 0; i < intervals.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Text('Khoảng làm thêm ${i + 1}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)))),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            intervals[i].fromDate.year == intervals[i].toDate.year &&
                                    intervals[i].fromDate.month == intervals[i].toDate.month &&
                                    intervals[i].fromDate.day == intervals[i].toDate.day
                                ? '${intervals[i].fromDate.day.toString().padLeft(2, '0')}/${intervals[i].fromDate.month.toString().padLeft(2, '0')} ${_formatTime(intervals[i].fromTime)} - ${_formatTime(intervals[i].toTime)}'
                                : '${intervals[i].fromDate.day}/${intervals[i].fromDate.month} ${_formatTime(intervals[i].fromTime)} - ${intervals[i].toDate.day}/${intervals[i].toDate.month} ${_formatTime(intervals[i].toTime)}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                          ),
                          if (intervals[i].nextDayRest != 'NONE') ...[
                            const SizedBox(height: 2),
                            Text(
                              'Sáng hôm sau: ${intervals[i].nextDayRest == 'HALF' ? 'Nghỉ nửa ngày' : 'Nghỉ cả ngày'}',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            ),
                          ],
                          if (intervals[i].error != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              intervals[i].error!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${intervals[i].hours.toStringAsFixed(intervals[i].hours % 1 == 0 ? 0 : 1)} giờ',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < intervals.length - 1) const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ],
            // Table Footer: Tổng cộng
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
              ),
              child: Row(
                children: [
                  const Expanded(flex: 8, child: Text('Tổng cộng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${totalHours.toStringAsFixed(totalHours % 1 == 0 ? 0 : 1)} giờ',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Dự án liên quan (Workspace)
      _buildProjectSelectorField(
        context: context,
        projects: projects,
        selectedProject: selectedProject,
        onProjectChanged: onProjectChanged,
        label: 'Dự án liên quan (Workspace)',
      ),
    ],
  );
}

// ============================================================================
// 3. FORM ĐƠN CÔNG TÁC (HỖ TRỢ THÊM KHOẢNG CÔNG TÁC)
// ============================================================================
Widget _buildBusinessTripForm({
  required BuildContext context,
  required StateSetter setModalState,
  required List<HrmRequestReason> reasons,
  required HrmRequestReason selectedReason,
  required ValueChanged<HrmRequestReason> onReasonChanged,
  required TextEditingController descController,
  required List<TimeInterval> intervals,
  required String tripScope,
  required ValueChanged<String> onTripScopeChanged,
  required TextEditingController locationCtrl,
  required TextEditingController deptCtrl,
  required String transport,
  required ValueChanged<String> onTransportChanged,
  required String externalVehicle,
  required ValueChanged<String> onExternalVehicleChanged,
  required List<ProjectItem> projects,
  required ProjectItem? selectedProject,
  required ValueChanged<ProjectItem?> onProjectChanged,
  VoidCallback? onClearError,
}) {
  final scopeOptions = [
    'Công tác trong nước (Nội địa)',
    'Công tác nước ngoài (Quốc tế)',
    'Công tác nội bộ liên chi nhánh',
  ];

  final transportOptions = [
    'Không cần phương tiện',
    'Xe công ty',
    'Phương tiện ngoài (tự sắp xếp)',
  ];

  final externalOptions = [
    'Taxi hoặc xe ngoài',
    'Máy bay',
    'Xe cá nhân',
    'Phương tiện khác',
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Lý do * (Chọn từ danh mục request_reasons - Đồng bộ 1:1 với Web ESS)
      _buildReasonSelectorField(
        context: context,
        label: 'Lý do *',
        reasons: reasons,
        selectedReason: selectedReason,
        onReasonChanged: onReasonChanged,
        showPaid: false,
      ),
      const SizedBox(height: 14),

      // Nội dung công việc công tác *
      Text(
        selectedReason.requiresDescription
            ? 'Nội dung công việc công tác *'
            : 'Mô tả nhiệm vụ công tác (nhập thêm nếu cần)',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
      ),
      const SizedBox(height: 6),
      _buildTextField(
        controller: descController,
        hint: selectedReason.requiresDescription
            ? 'Nhập chi tiết nhiệm vụ và nội dung công việc thực hiện trong chuyến công tác (bắt buộc)...'
            : 'Nhập chi tiết nhiệm vụ và nội dung công việc (không bắt buộc)...',
        maxLines: 3,
      ),
      const SizedBox(height: 14),

      // Danh sách khoảng công tác
      for (int i = 0; i < intervals.length; i++) ...[
        if (i > 0) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Khoảng công tác ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              InkWell(
                onTap: () => setModalState(() => intervals.removeAt(i)),
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    SizedBox(width: 3),
                    Text('Xoá', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],

        _buildDateTimeRangeRow(
          context: context,
          fromLabel: i == 0 ? 'Từ ngày giờ *' : 'Từ ngày giờ công tác *',
          toLabel: i == 0 ? 'Đến ngày giờ *' : 'Đến ngày giờ công tác *',
          fromDate: intervals[i].fromDate,
          toDate: intervals[i].toDate,
          fromTime: intervals[i].fromTime,
          toTime: intervals[i].toTime,
          errorText: intervals[i].error,
          onPickFromDate: (d) => setModalState(() {
            intervals[i].fromDate = d;
            if (intervals[i].toDate.isBefore(d)) intervals[i].toDate = d;
            onClearError?.call();
          }),
          onPickToDate: (d) => setModalState(() {
            intervals[i].toDate = d;
            onClearError?.call();
          }),
          onPickFromTime: (t) => setModalState(() {
            intervals[i].fromTime = t;
            onClearError?.call();
          }),
          onPickToTime: (t) => setModalState(() {
            intervals[i].toTime = t;
            onClearError?.call();
          }),
        ),
      ],
      const SizedBox(height: 10),

      // + Thêm khoảng công tác button
      OutlinedButton.icon(
        onPressed: () {
          setModalState(() {
            final last = intervals.last;
            final nextDate = last.toDate.add(const Duration(days: 1));
            intervals.add(
              TimeInterval(
                fromDate: nextDate,
                toDate: nextDate,
                fromTime: const TimeOfDay(hour: 7, minute: 30),
                toTime: const TimeOfDay(hour: 17, minute: 0),
                kind: 'business_trip',
              ),
            );
          });
        },
        icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF1E293B)),
        label: const Text('Thêm khoảng công tác', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      const SizedBox(height: 14),

      // Row: Hình thức công tác * | Phòng ban công tác / cử đi
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hình thức công tác *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                _buildDropdownContainer(
                  value: tripScope,
                  hint: 'Chọn hình thức...',
                  items: scopeOptions,
                  onChanged: (v) {
                    if (v != null) onTripScopeChanged(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phòng ban công tác / cử đi', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: deptCtrl,
                  hint: 'Phòng ban cử đi...',
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),

      // Địa điểm công tác *
      const Text('Địa điểm công tác *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildTextField(
        controller: locationCtrl,
        hint: 'VD: Trạm biến áp 500kV Phố Nối, NM Đắc Sin 1...',
        maxLines: 1,
      ),
      const SizedBox(height: 14),

      // Phương tiện di chuyển
      const Text('Phương tiện di chuyển', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      _buildDropdownContainer(
        value: transport,
        hint: 'Không cần phương tiện',
        items: transportOptions,
        onChanged: (v) {
          if (v != null) onTransportChanged(v);
        },
      ),
      if (transport == 'Phương tiện ngoài (tự sắp xếp)') ...[
        const SizedBox(height: 10),
        const Text('Loại phương tiện *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        _buildDropdownContainer(
          value: externalVehicle,
          hint: 'Chọn loại phương tiện...',
          items: externalOptions,
          onChanged: (v) {
            if (v != null) onExternalVehicleChanged(v);
          },
        ),
      ],
      const SizedBox(height: 14),

      // Card: Dự trù kinh phí & Phụ phí công tác
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_money_rounded, size: 18, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Dự trù kinh phí & Phụ phí công tác',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 14, color: Color(0xFF1E293B)),
                  label: const Text('+ Thêm phụ phí', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Chưa có phụ phí dự trù. Bấm "Thêm phụ phí" để khai báo vé xe, khách sạn, tiền ăn...',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Dự án liên quan (Workspace)
      _buildProjectSelectorField(
        context: context,
        projects: projects,
        selectedProject: selectedProject,
        onProjectChanged: onProjectChanged,
        label: 'Dự án liên quan (Workspace)',
      ),
    ],
  );
}

// ============================================================================
// 4. FORM ĐƠN GIẢI TRÌNH CHẤM CÔNG (MATCHING SCREENSHOT 5)
// ============================================================================
Widget _buildCorrectionForm({
  required BuildContext context,
  required StateSetter setModalState,
  required List<HrmRequestReason> reasons,
  required HrmRequestReason selectedReason,
  required ValueChanged<HrmRequestReason> onReasonChanged,
  required TextEditingController descController,
  required DateTime workDate,
  required ValueChanged<DateTime> onPickWorkDate,
  required String timeType,
  required ValueChanged<String> onTimeTypeChanged,
  required TimeOfDay correctionTime,
  required ValueChanged<TimeOfDay> onPickTime,
}) {
  final timeTypes = ['Giờ vào', 'Giờ ra'];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Lý do * (Chọn từ danh mục request_reasons - Đồng bộ 1:1 với Web ESS)
      _buildReasonSelectorField(
        context: context,
        label: 'Lý do *',
        reasons: reasons,
        selectedReason: selectedReason,
        onReasonChanged: onReasonChanged,
        showPaid: false,
      ),
      const SizedBox(height: 14),

      // Mô tả (nhập thêm chi tiết nếu cần)
      Text(
        selectedReason.requiresDescription
            ? 'Mô tả (bắt buộc khi chọn lý do này) *'
            : 'Mô tả (nhập thêm chi tiết nếu cần)',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
      ),
      const SizedBox(height: 6),
      _buildTextField(
        controller: descController,
        hint: selectedReason.requiresDescription
            ? 'Nhập mô tả chi tiết giải trình (bắt buộc)...'
            : 'Nhập thêm chi tiết nếu cần (không bắt buộc)...',
        maxLines: 3,
      ),
      const SizedBox(height: 14),

      // Ngày phát sinh điều chỉnh *
      const Text('Ngày phát sinh điều chỉnh *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: workDate,
            firstDate: DateTime(2025),
            lastDate: DateTime(2027),
          );
          if (picked != null) onPickWorkDate(picked);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Text(
                '${workDate.day.toString().padLeft(2, '0')}/${workDate.month.toString().padLeft(2, '0')}/${workDate.year}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Giờ chấm công cần bổ sung
      const Text('Giờ chấm công cần bổ sung', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 4),
      const Text(
        'Chọn đây là giờ vào hay giờ ra rồi nhập giờ (gợi ý theo ca được gán). Mỗi đơn chỉ khai báo một mốc; quên chấm cả hai chiều thì tạo hai đơn. Giờ cùng loại đã chấm trong ngày sẽ được thay bằng giờ này, loại còn lại giữ nguyên.',
        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.4),
      ),
      const SizedBox(height: 10),

      // Row: Loại giờ & Giờ vào/ra *
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Loại giờ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                _buildDropdownContainer(
                  value: timeType,
                  hint: 'Chọn loại...',
                  items: timeTypes,
                  onChanged: (v) {
                    if (v != null) {
                      onTimeTypeChanged(v);
                      if (v == 'Giờ ra' && correctionTime.hour < 12) {
                        onPickTime(const TimeOfDay(hour: 17, minute: 0));
                      } else if (v == 'Giờ vào' && correctionTime.hour >= 12) {
                        onPickTime(const TimeOfDay(hour: 7, minute: 30));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$timeType *', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _showNativeTimeOnlyPicker(
                    context: context,
                    initialTime: correctionTime,
                    timeType: timeType,
                    onSelected: onPickTime,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${correctionTime.hour.toString().padLeft(2, '0')}:${correctionTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                        const Spacer(),
                        const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),

      // Mốc gợi ý nhanh đồng bộ 1:1 với Web TimeComboInput
      Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Gợi ý:',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          ...((timeType == 'Giờ ra')
                  ? const [
                      TimeOfDay(hour: 17, minute: 0),
                      TimeOfDay(hour: 17, minute: 30),
                      TimeOfDay(hour: 18, minute: 0),
                      TimeOfDay(hour: 12, minute: 0),
                    ]
                  : const [
                      TimeOfDay(hour: 7, minute: 30),
                      TimeOfDay(hour: 8, minute: 0),
                      TimeOfDay(hour: 8, minute: 30),
                      TimeOfDay(hour: 13, minute: 0),
                    ])
              .map((suggested) {
            final isSelected =
                correctionTime.hour == suggested.hour && correctionTime.minute == suggested.minute;
            final label =
                '${suggested.hour.toString().padLeft(2, '0')}:${suggested.minute.toString().padLeft(2, '0')}';
            return InkWell(
              onTap: () => onPickTime(suggested),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      const SizedBox(height: 12),

      // Mở bảng công của tôi để đối chiếu (Link)
      InkWell(
        onTap: () => Navigator.pop(context),
        child: const Text(
          'Mở bảng công của tôi để đối chiếu',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFFD97706),
          ),
        ),
      ),
    ],
  );
}

// ============================================================================
// HELPER COMPONENT BUILDERS (MATCHING SCREENSHOT LAYOUTS 1:1)
// ============================================================================
Widget _buildPaidBadge(bool isPaid) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: isPaid ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
      ),
    ),
    child: Text(
      isPaid ? 'Có lương' : 'Không lương',
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: isPaid ? const Color(0xFF059669) : const Color(0xFF64748B),
      ),
    ),
  );
}

String _formatTime(TimeOfDay t) {
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

Widget _buildReasonSelectorField({
  required BuildContext context,
  required String label,
  required List<HrmRequestReason> reasons,
  required HrmRequestReason selectedReason,
  required ValueChanged<HrmRequestReason> onReasonChanged,
  bool showPaid = true,
  bool isLeave = false,
}) {
  final isAnnual = isLeave && (selectedReason.code.toUpperCase().contains('ANNUAL') || selectedReason.name.toLowerCase().contains('phép năm'));
  final isCompOff = isLeave && (selectedReason.code.toUpperCase().contains('COMP') || selectedReason.name.toLowerCase().contains('nghỉ bù'));

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 6),
      InkWell(
        onTap: () => _openReasonSearchSheet(
          context: context,
          title: label.replaceAll(' *', ''),
          reasons: reasons,
          selectedReason: selectedReason,
          onReasonChanged: onReasonChanged,
          showPaid: showPaid,
          isLeave: isLeave,
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            selectedReason.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showPaid) ...[
                          const SizedBox(width: 6),
                          _buildPaidBadge(selectedReason.paid),
                        ],
                        if (isAnnual) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Text(
                              'Trừ quỹ phép năm',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                        if (isCompOff) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text(
                              'Trừ quỹ nghỉ bù',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (selectedReason.description != null && selectedReason.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        selectedReason.description!,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
            ],
          ),
        ),
      ),
    ],
  );
}

void _openReasonSearchSheet({
  required BuildContext context,
  required String title,
  required List<HrmRequestReason> reasons,
  required HrmRequestReason selectedReason,
  required ValueChanged<HrmRequestReason> onReasonChanged,
  bool showPaid = true,
  bool isLeave = false,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      String searchQuery = '';
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final query = searchQuery.trim().toLowerCase();
          final filtered = query.isEmpty
              ? reasons
              : reasons.where((r) =>
                  r.name.toLowerCase().contains(query) ||
                  (r.description?.toLowerCase().contains(query) ?? false) ||
                  r.code.toLowerCase().contains(query)).toList();

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(sheetCtx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    autofocus: reasons.length > 5,
                    onChanged: (val) => setSheetState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Chọn lý do...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Không tìm thấy lý do phù hợp',
                            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
                          itemCount: filtered.length,
                          separatorBuilder: (_, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (_, idx) {
                            final r = filtered[idx];
                            final isSelected = r.id == selectedReason.id;
                            final isRAnnual = isLeave && (r.code.toUpperCase().contains('ANNUAL') || r.name.toLowerCase().contains('phép năm'));
                            final isRCompOff = isLeave && (r.code.toUpperCase().contains('COMP') || r.name.toLowerCase().contains('nghỉ bù'));
                            return InkWell(
                              onTap: () {
                                onReasonChanged(r);
                                Navigator.pop(sheetCtx);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  r.name,
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                    color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                                                  ),
                                                ),
                                              ),
                                              if (showPaid) ...[
                                                const SizedBox(width: 8),
                                                _buildPaidBadge(r.paid),
                                              ],
                                              if (isRAnnual) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                                  ),
                                                  child: const Text(
                                                    'Trừ quỹ phép năm',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF92400E),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (isRCompOff) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                                  ),
                                                  child: const Text(
                                                    'Trừ quỹ nghỉ bù',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF1E40AF),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (r.description != null && r.description!.trim().isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              r.description!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildProjectSelectorField({
  required BuildContext context,
  required List<ProjectItem> projects,
  required ProjectItem? selectedProject,
  required ValueChanged<ProjectItem?> onProjectChanged,
  String label = 'Dự án liên quan (Workspace)',
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          if (selectedProject != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'Mã: ${selectedProject.code}',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      InkWell(
        onTap: () => _openProjectSearchSheet(
          context: context,
          projects: projects,
          selectedProject: selectedProject,
          onProjectChanged: onProjectChanged,
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: selectedProject == null
                    ? const Text(
                        'Không gắn dự án',
                        style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        overflow: TextOverflow.ellipsis,
                      )
                    : Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${selectedProject.code} - ${selectedProject.name}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              selectedProject.code,
                              style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
              ),
              if (selectedProject != null)
                InkWell(
                  onTap: () => onProjectChanged(null),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                  ),
                )
              else
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        selectedProject != null
            ? 'Đơn sẽ được ghi vào tab "Đơn từ" của dự án ${selectedProject.code} với mã DTxxx tự sinh.'
            : 'Chỉ hiện dự án bạn đang tham gia. Chọn dự án để đơn này được ghi nhận trong dự án đó.',
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
      ),
    ],
  );
}

void _openProjectSearchSheet({
  required BuildContext context,
  required List<ProjectItem> projects,
  required ProjectItem? selectedProject,
  required ValueChanged<ProjectItem?> onProjectChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      String searchQuery = '';
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final query = searchQuery.trim().toLowerCase();
          final filtered = query.isEmpty
              ? projects
              : projects.where((p) =>
                  p.name.toLowerCase().contains(query) ||
                  p.code.toLowerCase().contains(query) ||
                  p.statusLabel.toLowerCase().contains(query)).toList();

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dự án liên kết (Workspace)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(sheetCtx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    autofocus: projects.length > 5,
                    onChanged: (val) => setSheetState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Chọn dự án liên quan nếu có (không bắt buộc)...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                ),
                // Mục "Không gắn dự án"
                InkWell(
                  onTap: () {
                    onProjectChanged(null);
                    Navigator.pop(sheetCtx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: selectedProject == null ? const Color(0xFFEFF6FF) : Colors.transparent,
                      border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.do_not_disturb_on_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          'Không gắn dự án',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selectedProject == null ? FontWeight.w700 : FontWeight.w500,
                            color: selectedProject == null ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                          ),
                        ),
                        if (selectedProject == null) ...[
                          const Spacer(),
                          const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Bạn chưa tham gia dự án nào bên Workspace',
                            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
                          itemCount: filtered.length,
                          separatorBuilder: (_, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (_, idx) {
                            final p = filtered[idx];
                            final isSelected = p.id == selectedProject?.id;
                            return InkWell(
                              onTap: () {
                                onProjectChanged(p);
                                Navigator.pop(sheetCtx);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  '${p.code} - ${p.name}',
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                    color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  p.code,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'monospace',
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            p.statusLabel,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildDropdownContainer({
  required String value,
  required String hint,
  required List<String> items,
  required ValueChanged<String?> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFCBD5E1)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        menuMaxHeight: 280,
        borderRadius: BorderRadius.circular(12),
        value: items.contains(value) ? value : items.firstOrNull,
        hint: Text(hint, style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
        items: items.map((opt) {
          return DropdownMenuItem<String>(
            value: opt,
            child: Text(
              opt,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

Widget _buildTextField({
  required TextEditingController controller,
  required String hint,
  int maxLines = 1,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
    ),
  );
}

/// Kích hoạt chọn ngày giờ kiểu Native 1-Tap Trigger (Khớp Chuẩn Rule 5.3 Unified Date Capsule)
void _showNativeDateTimePicker({
  required BuildContext context,
  required DateTime initialDate,
  required TimeOfDay initialTime,
  required void Function(DateTime date, TimeOfDay time) onSelected,
  DateTime? minDate,
}) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  DateTime tempDateTime = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
    initialTime.hour,
    initialTime.minute,
  );

  if (isIOS) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Container(
          height: 310,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Thanh điều khiển Xong / Huỷ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Huỷ', style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
                      ),
                      const Text(
                        'Chọn ngày & giờ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          onSelected(
                            DateTime(tempDateTime.year, tempDateTime.month, tempDateTime.day),
                            TimeOfDay(hour: tempDateTime.hour, minute: tempDateTime.minute),
                          );
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF021E73), fontSize: 15)),
                      ),
                    ],
                  ),
                ),
                // Vòng xoay cuộn Native iOS (Cupertino wheel)
                Expanded(
                  child: CupertinoDatePicker(
                    initialDateTime: tempDateTime.isBefore(minDate ?? DateTime(2025)) ? (minDate ?? DateTime(2025)) : tempDateTime,
                    minimumDate: minDate,
                    maximumDate: DateTime(2028),
                    mode: CupertinoDatePickerMode.dateAndTime,
                    use24hFormat: true,
                    onDateTimeChanged: (DateTime newDt) {
                      tempDateTime = newDt;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } else {
    // Android: Chọn ngày -> chọn giờ
    showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(minDate ?? DateTime(2025)) ? (minDate ?? DateTime(2025)) : initialDate,
      firstDate: minDate ?? DateTime(2025),
      lastDate: DateTime(2028),
    ).then((pickedDate) {
      if (pickedDate != null && context.mounted) {
        showTimePicker(
          context: context,
          initialTime: initialTime,
        ).then((pickedTime) {
          if (pickedTime != null) {
            onSelected(pickedDate, pickedTime);
          } else {
            onSelected(pickedDate, initialTime);
          }
        });
      }
    });
  }
}

/// Kích hoạt chọn giờ Native (Cupertino Time Wheel trên iOS - Rule 5.3)
Future<void> _showNativeTimeOnlyPicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required String timeType,
  required ValueChanged<TimeOfDay> onSelected,
}) async {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  final now = DateTime.now();
  DateTime tempDateTime = DateTime(
    now.year,
    now.month,
    now.day,
    initialTime.hour,
    initialTime.minute,
  );

  if (isIOS) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Container(
          height: 290,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Thanh điều khiển Xong / Huỷ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Huỷ', style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
                      ),
                      Text(
                        'Chọn $timeType',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          onSelected(TimeOfDay(hour: tempDateTime.hour, minute: tempDateTime.minute));
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF021E73), fontSize: 15)),
                      ),
                    ],
                  ),
                ),
                // Vòng xoay cuộn Native iOS (Cupertino time wheel)
                Expanded(
                  child: CupertinoDatePicker(
                    initialDateTime: tempDateTime,
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    onDateTimeChanged: (DateTime newDt) {
                      tempDateTime = newDt;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } else {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'CHỌN $timeType'.toUpperCase(),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }
}

/// Kích hoạt chọn ngày Native (Cupertino Date Wheel trên iOS, DatePicker trên Android)
void _showNativeDateOnlyPicker({
  required BuildContext context,
  required DateTime initialDate,
  required ValueChanged<DateTime> onSelected,
  DateTime? minDate,
}) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  DateTime tempDate = initialDate;

  if (isIOS) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Container(
          height: 290,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Huỷ', style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
                      ),
                      const Text(
                        'Chọn ngày',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          onSelected(tempDate);
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF021E73), fontSize: 15)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    initialDateTime: initialDate.isBefore(minDate ?? DateTime(2025)) ? (minDate ?? DateTime(2025)) : initialDate,
                    minimumDate: minDate,
                    maximumDate: DateTime(2028),
                    mode: CupertinoDatePickerMode.date,
                    onDateTimeChanged: (DateTime newDt) {
                      tempDate = newDt;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } else {
    showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(minDate ?? DateTime(2025)) ? (minDate ?? DateTime(2025)) : initialDate,
      firstDate: minDate ?? DateTime(2025),
      lastDate: DateTime(2028),
    ).then((pickedDate) {
      if (pickedDate != null) {
        onSelected(pickedDate);
      }
    });
  }
}

/// Hộp chọn ngày chuẩn Web (dd/MM/yyyy kèm icon lịch)
Widget _buildDateCapsule({
  required BuildContext context,
  required DateTime date,
  required ValueChanged<DateTime> onSelected,
  DateTime? minDate,
}) {
  final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  return InkWell(
    onTap: () => _showNativeDateOnlyPicker(
      context: context,
      initialDate: date,
      onSelected: onSelected,
      minDate: minDate,
    ),
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateStr,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF64748B)),
        ],
      ),
    ),
  );
}

/// Hộp chọn giờ chuẩn Web (HH:mm kèm icon đồng hồ)
Widget _buildTimeCapsule({
  required BuildContext context,
  required TimeOfDay time,
  required String label,
  required ValueChanged<TimeOfDay> onSelected,
}) {
  final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  return InkWell(
    onTap: () => _showNativeTimeOnlyPicker(
      context: context,
      initialTime: time,
      timeType: label,
      onSelected: onSelected,
    ),
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              timeStr,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF64748B)),
        ],
      ),
    ),
  );
}

/// Hộp chọn thời gian Unified Date Capsule theo chuẩn Rule 5.3
Widget _buildDateTimeCapsule({
  required BuildContext context,
  required DateTime date,
  required TimeOfDay time,
  required void Function(DateTime date, TimeOfDay time) onSelected,
  DateTime? minDate,
}) {
  final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  return InkWell(
    onTap: () => _showNativeDateTimePicker(
      context: context,
      initialDate: date,
      initialTime: time,
      onSelected: onSelected,
      minDate: minDate,
    ),
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          // Cyan glow dot (khớp Chuẩn Rule 5.3 Unified Date Capsule)
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Text thời gian
          Expanded(
            child: Text(
              '$timeStr  ·  $dateStr',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Đường chia cách dọc mỏng
          Container(
            width: 1,
            height: 20,
            color: const Color(0xFFCBD5E1),
          ),
          const SizedBox(width: 10),
          // Icon lịch
          const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF64748B)),
        ],
      ),
    ),
  );
}

Widget _buildDateTimeRangeRow({
  required BuildContext context,
  required String fromLabel,
  required String toLabel,
  required DateTime fromDate,
  required DateTime toDate,
  required TimeOfDay fromTime,
  required TimeOfDay toTime,
  required ValueChanged<DateTime> onPickFromDate,
  required ValueChanged<DateTime> onPickToDate,
  required ValueChanged<TimeOfDay> onPickFromTime,
  required ValueChanged<TimeOfDay> onPickToTime,
  String? errorText,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        fromLabel,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
      ),
      const SizedBox(height: 6),
      _buildDateTimeCapsule(
        context: context,
        date: fromDate,
        time: fromTime,
        onSelected: (d, t) {
          onPickFromDate(d);
          onPickFromTime(t);
          if (toDate.isBefore(d)) {
            onPickToDate(d);
          }
        },
      ),
      const SizedBox(height: 10),
      Text(
        toLabel,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
      ),
      const SizedBox(height: 6),
      _buildDateTimeCapsule(
        context: context,
        date: toDate,
        time: toTime,
        minDate: fromDate,
        onSelected: (d, t) {
          onPickToDate(d);
          onPickToTime(t);
        },
      ),
      if (errorText != null && errorText.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          errorText,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFDC2626),
            height: 1.35,
          ),
        ),
      ],
    ],
  );
}

Widget _buildAttachmentSection({
  required String? selectedFileName,
  required int? selectedFileSize,
  required VoidCallback onPickFile,
  required VoidCallback onRemoveFile,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Tệp đính kèm (không bắt buộc)',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
      ),
      const SizedBox(height: 6),
      InkWell(
        onTap: onPickFile,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: selectedFileName != null
              ? Row(
                  children: [
                    const Icon(Icons.attach_file, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$selectedFileName (${((selectedFileSize ?? 0) / 1024).toStringAsFixed(1)} KB)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                      onPressed: onRemoveFile,
                    ),
                  ],
                )
              : const Column(
                  children: [
                    Icon(Icons.upload_file_outlined, color: Color(0xFF64748B), size: 24),
                    SizedBox(height: 4),
                    Text(
                      'Kéo tệp vào đây hoặc chọn tệp',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hỗ trợ: PDF, DOC, DOCX, JPG, PNG (tối đa 10MB)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
        ),
      ),
    ],
  );
}
