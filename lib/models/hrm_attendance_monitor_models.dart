import 'package:flutter/material.dart';

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
        return 'Nghỉ phép';
      case 'OT':
        return 'Làm thêm giờ';
      case 'TRIP':
        return 'Công tác';
      case 'CORRECTION':
        return 'Giải trình công';
      case 'SHIFT_CHANGE':
        return 'Đổi ca';
      default:
        return 'Đơn khác';
    }
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'Đã duyệt';
      case 'REJECTED':
        return 'Từ chối';
      case 'PENDING':
      default:
        return 'Chờ duyệt';
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
      return 'Chưa chấm';
    }
    if (checkIn != null && checkIn!.isNotEmpty && checkOut != null && checkOut!.isNotEmpty) {
      return '$checkIn – $checkOut';
    }
    if (checkIn != null && checkIn!.isNotEmpty) {
      return status == 'MISSING_PUNCH' ? '$checkIn (chưa có lượt ra)' : checkIn!;
    }
    return 'Ra lúc $checkOut';
  }

  String get statusDisplayLabel {
    switch (status) {
      case 'NOT_CHECKED_IN':
        return 'Chưa vào ca';
      case 'ABSENT':
        return 'Vắng mặt';
      case 'LATE':
        return lateMinutes > 0 ? 'Đi trễ $lateMinutes phút' : 'Đi trễ';
      case 'EARLY_LEAVE':
        return earlyLeaveMinutes > 0 ? 'Về sớm $earlyLeaveMinutes phút' : 'Về sớm';
      case 'LATE_EARLY':
        return 'Đi trễ, về sớm ($lateMinutes p / $earlyLeaveMinutes p)';
      case 'MISSING_PUNCH':
        return 'Thiếu lượt chấm';
      case 'CHECKED_IN':
        return 'Đã vào ca';
      case 'COMPLETED':
        return 'Đã hoàn thành ca';
      case 'UPCOMING':
        return 'Chưa tới giờ ca';
      case 'ON_LEAVE':
        return leaveName != null && leaveName!.isNotEmpty ? 'Nghỉ phép ($leaveName)' : 'Đang nghỉ phép';
      case 'ON_TRIP':
        return 'Công tác';
      case 'DAY_OFF':
        return 'Ngày nghỉ';
      case 'NO_SCHEDULE':
        return 'Chưa có lịch';
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
