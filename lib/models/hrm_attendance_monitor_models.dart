import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';

class HrmMonitorDayRequest {
  final String id;
  final String kind;
  final String status;
  final String? label;
  final String? reasonName;
  final String? description;
  final int? minutes;
  final String? fromAt;
  final String? toAt;

  const HrmMonitorDayRequest({
    required this.id,
    required this.kind,
    required this.status,
    this.label,
    this.reasonName,
    this.description,
    this.minutes,
    this.fromAt,
    this.toAt,
  });

  factory HrmMonitorDayRequest.fromJson(Map<String, dynamic> json) {
    return HrmMonitorDayRequest(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'CUSTOM',
      status: json['status']?.toString() ?? 'PENDING',
      label: json['label']?.toString(),
      reasonName: json['reasonName']?.toString(),
      description: json['description']?.toString(),
      minutes: json['minutes'] != null ? int.tryParse(json['minutes'].toString()) : null,
      fromAt: json['fromAt']?.toString(),
      toAt: json['toAt']?.toString(),
    );
  }

  String get kindLabel {
    switch (kind.toUpperCase()) {
      case 'LEAVE':
        return 'models.request.leave'.tr();
      case 'OT':
        return 'models.request.overtime'.tr();
      case 'TRIP':
        return 'models.request.business_trip'.tr();
      case 'CORRECTION':
        return 'models.request.attendance_explanation'.tr();
      case 'SHIFT_CHANGE':
        return 'models.request.shift_change'.tr();
      default:
        return 'models.request.other'.tr();
    }
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'models.status.approved'.tr();
      case 'REJECTED':
        return 'common.reject'.tr();
      case 'PENDING':
      default:
        return 'models.status.pending'.tr();
    }
  }

  Color get statusTextColor {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFF059669);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      case 'PENDING':
      default:
        return const Color(0xFFD97706);
    }
  }

  Color get statusBgColor {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFFECFDF5);
      case 'REJECTED':
        return const Color(0xFFFEF2F2);
      case 'PENDING':
      default:
        return const Color(0xFFFFFBEB);
    }
  }
}

class HrmMonitorRow {
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final String? positionName;
  final String status;
  final String? shiftCode;
  final String? shiftName;
  final String? shiftStart;
  final String? shiftEnd;
  final String? checkIn;
  final String? checkOut;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final String? leaveName;
  final double leaveDays;
  final List<HrmMonitorDayRequest> requests;

  const HrmMonitorRow({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    this.positionName,
    required this.status,
    this.shiftCode,
    this.shiftName,
    this.shiftStart,
    this.shiftEnd,
    this.checkIn,
    this.checkOut,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.leaveName,
    this.leaveDays = 0,
    this.requests = const [],
  });

  factory HrmMonitorRow.fromJson(Map<String, dynamic> json) {
    return HrmMonitorRow(
      employeeId: json['employeeId']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      departmentName: json['departmentName']?.toString(),
      positionName: json['positionName']?.toString(),
      status: json['status']?.toString() ?? 'NO_SCHEDULE',
      shiftCode: json['shiftCode']?.toString(),
      shiftName: json['shiftName']?.toString(),
      shiftStart: json['shiftStart']?.toString(),
      shiftEnd: json['shiftEnd']?.toString(),
      checkIn: json['checkIn']?.toString(),
      checkOut: json['checkOut']?.toString(),
      lateMinutes: int.tryParse(json['lateMinutes']?.toString() ?? '0') ?? 0,
      earlyLeaveMinutes: int.tryParse(json['earlyLeaveMinutes']?.toString() ?? '0') ?? 0,
      leaveName: json['leaveName']?.toString(),
      leaveDays: double.tryParse(json['leaveDays']?.toString() ?? '0') ?? 0.0,
      requests: (json['requests'] as List?)
              ?.map((e) => HrmMonitorDayRequest.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  String get initials {
    final parts = employeeName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[parts.length - 2][0] + parts.last[0]).toUpperCase();
  }

  String get shiftTimeText {
    if (shiftStart == null || shiftStart!.isEmpty) return '----';
    return (shiftEnd != null && shiftEnd!.isNotEmpty) ? '$shiftStart – $shiftEnd' : shiftStart!;
  }

  String get actualText {
    if ((checkIn == null || checkIn!.isEmpty) && (checkOut == null || checkOut!.isEmpty)) {
      return 'models.attendance.not_punched'.tr();
    }
    if (checkIn != null && checkIn!.isNotEmpty && checkOut != null && checkOut!.isNotEmpty) {
      return '$checkIn – $checkOut';
    }
    if (checkIn != null && checkIn!.isNotEmpty) {
      return status == 'MISSING_PUNCH' ? 'models.attendance.punch_missing_out'.tr(args: {'time': checkIn}) : checkIn!;
    }
    return 'models.attendance.out_at'.tr(args: {'time': checkOut});
  }

  String get statusDisplayLabel {
    switch (status) {
      case 'NOT_CHECKED_IN':
        return 'models.attendance.not_started'.tr();
      case 'ABSENT':
        return 'models.attendance.absent'.tr();
      case 'LATE':
        return lateMinutes > 0 ? 'models.attendance.late_minutes'.tr(args: {'minutes': lateMinutes}) : 'models.attendance.late'.tr();
      case 'EARLY_LEAVE':
        return earlyLeaveMinutes > 0 ? 'models.attendance.early_minutes'.tr(args: {'minutes': earlyLeaveMinutes}) : 'models.attendance.early_leave'.tr();
      case 'LATE_EARLY':
        return 'models.attendance.late_and_early'.tr(args: {'late': lateMinutes, 'early': earlyLeaveMinutes});
      case 'MISSING_PUNCH':
        return 'models.attendance.missing_punch'.tr();
      case 'CHECKED_IN':
        return 'models.attendance.checked_in'.tr();
      case 'COMPLETED':
        return 'models.attendance.shift_completed'.tr();
      case 'UPCOMING':
        return 'models.attendance.before_shift'.tr();
      case 'ON_LEAVE':
        return leaveName != null && leaveName!.isNotEmpty ? 'models.attendance.leave_named'.tr(args: {'name': leaveName}) : 'models.attendance.on_leave'.tr();
      case 'ON_TRIP':
        return 'models.request.business_trip'.tr();
      case 'DAY_OFF':
        return 'models.attendance.day_off'.tr();
      case 'NO_SCHEDULE':
        return 'models.attendance.no_schedule'.tr();
      default:
        return status;
    }
  }

  Color get statusTextColor {
    switch (status) {
      case 'NOT_CHECKED_IN':
      case 'ABSENT':
      case 'MISSING_PUNCH':
        return const Color(0xFFDC2626); // Rose/Red
      case 'LATE':
      case 'LATE_EARLY':
        return const Color(0xFFD97706); // Amber
      case 'EARLY_LEAVE':
        return const Color(0xFFEA580C); // Orange
      case 'CHECKED_IN':
      case 'COMPLETED':
        return const Color(0xFF059669); // Emerald
      case 'ON_LEAVE':
        return const Color(0xFF7C3AED); // Violet/Purple
      case 'ON_TRIP':
        return const Color(0xFF2563EB); // Blue
      case 'UPCOMING':
      case 'DAY_OFF':
      case 'NO_SCHEDULE':
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  Color get statusBgColor {
    switch (status) {
      case 'NOT_CHECKED_IN':
      case 'ABSENT':
      case 'MISSING_PUNCH':
        return const Color(0xFFFEF2F2);
      case 'LATE':
      case 'LATE_EARLY':
        return const Color(0xFFFFFBEB);
      case 'EARLY_LEAVE':
        return const Color(0xFFFFF7ED);
      case 'CHECKED_IN':
      case 'COMPLETED':
        return const Color(0xFFECFDF5);
      case 'ON_LEAVE':
        return const Color(0xFFFAF5FF);
      case 'ON_TRIP':
        return const Color(0xFFEFF6FF);
      case 'UPCOMING':
      case 'DAY_OFF':
      case 'NO_SCHEDULE':
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get statusBorderColor {
    switch (status) {
      case 'NOT_CHECKED_IN':
      case 'ABSENT':
      case 'MISSING_PUNCH':
        return const Color(0xFFFECDD3);
      case 'LATE':
      case 'LATE_EARLY':
        return const Color(0xFFFDE68A);
      case 'EARLY_LEAVE':
        return const Color(0xFFFED7AA);
      case 'CHECKED_IN':
      case 'COMPLETED':
        return const Color(0xFFA7F3D0);
      case 'ON_LEAVE':
        return const Color(0xFFDDD6FE);
      case 'ON_TRIP':
        return const Color(0xFFBFDBFE);
      case 'UPCOMING':
      case 'DAY_OFF':
      case 'NO_SCHEDULE':
      default:
        return const Color(0xFFE2E8F0);
    }
  }
}

class HrmMonitorSummary {
  final int totalPeople;
  final int scheduled;
  final int checkedIn;
  final int notCheckedIn;
  final int late;
  final int earlyLeave;
  final int onLeave;
  final int onTrip;
  final int missingPunch;

  const HrmMonitorSummary({
    this.totalPeople = 0,
    this.scheduled = 0,
    this.checkedIn = 0,
    this.notCheckedIn = 0,
    this.late = 0,
    this.earlyLeave = 0,
    this.onLeave = 0,
    this.onTrip = 0,
    this.missingPunch = 0,
  });

  factory HrmMonitorSummary.fromJson(Map<String, dynamic> json) {
    return HrmMonitorSummary(
      totalPeople: int.tryParse(json['totalPeople']?.toString() ?? '0') ?? 0,
      scheduled: int.tryParse(json['scheduled']?.toString() ?? '0') ?? 0,
      checkedIn: int.tryParse(json['checkedIn']?.toString() ?? '0') ?? 0,
      notCheckedIn: int.tryParse(json['notCheckedIn']?.toString() ?? '0') ?? 0,
      late: int.tryParse(json['late']?.toString() ?? '0') ?? 0,
      earlyLeave: int.tryParse(json['earlyLeave']?.toString() ?? '0') ?? 0,
      onLeave: int.tryParse(json['onLeave']?.toString() ?? '0') ?? 0,
      onTrip: int.tryParse(json['onTrip']?.toString() ?? '0') ?? 0,
      missingPunch: int.tryParse(json['missingPunch']?.toString() ?? '0') ?? 0,
    );
  }

  String percentText(int count) {
    if (scheduled <= 0) return '0,0%';
    final pct = (count / scheduled) * 100;
    return '${pct.toStringAsFixed(1).replaceAll('.', ',')}%';
  }
}

class HrmAttendanceMonitor {
  final String date;
  final String today;
  final String generatedAt;
  final String scope; // 'ALL' | 'TEAM'
  final HrmMonitorSummary summary;
  final List<HrmMonitorRow> rows;

  const HrmAttendanceMonitor({
    required this.date,
    required this.today,
    required this.generatedAt,
    this.scope = 'ALL',
    this.summary = const HrmMonitorSummary(),
    this.rows = const [],
  });

  factory HrmAttendanceMonitor.fromJson(Map<String, dynamic> json) {
    return HrmAttendanceMonitor(
      date: json['date']?.toString() ?? '',
      today: json['today']?.toString() ?? '',
      generatedAt: json['generatedAt']?.toString() ?? '',
      scope: json['scope']?.toString() ?? 'ALL',
      summary: json['summary'] != null
          ? HrmMonitorSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : const HrmMonitorSummary(),
      rows: (json['rows'] as List?)
              ?.map((e) => HrmMonitorRow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
