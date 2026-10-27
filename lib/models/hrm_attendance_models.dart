import '../core/i18n/app_i18n.dart';
class LeaveType {
  final String id;
  final String code;
  final String name;
  final double? daysAllowed;
  final bool isPaid;
  final String? description;

  LeaveType({
    required this.id,
    required this.code,
    required this.name,
    this.daysAllowed,
    this.isPaid = true,
    this.description,
  });

  factory LeaveType.fromJson(Map<String, dynamic> json) {
    return LeaveType(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? json['code']?.toString() ?? 'models.request.leave'.tr(),
      daysAllowed: (json['days_allowed'] ?? json['daysAllowed'] ?? json['quota']) != null
          ? double.tryParse(json['days_allowed']?.toString() ?? json['daysAllowed']?.toString() ?? json['quota']?.toString() ?? '')
          : null,
      isPaid: json['is_paid'] ?? json['isPaid'] ?? true,
      description: json['description']?.toString(),
    );
  }
}

class HrmShift {
  final String id;
  final String code;
  final String name;
  final String startTime;
  final String endTime;
  final int breakMinutes;
  final int graceLateMinutes;
  final int graceEarlyMinutes;

  HrmShift({
    required this.id,
    required this.code,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.breakMinutes = 90,
    this.graceLateMinutes = 10,
    this.graceEarlyMinutes = 5,
  });

  /// Server returns the shift as `{ window: { start, end, breakMinutes, ... } }` with ISO instants.
  static String? _clock(dynamic iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso.toString());
    if (dt == null) return null;
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}:00';
  }

  factory HrmShift.fromJson(Map<String, dynamic> json) {
    final window = json['window'];
    if (window is Map<String, dynamic>) {
      return HrmShift(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        startTime: _clock(window['start']) ?? '',
        endTime: _clock(window['end']) ?? '',
        breakMinutes: (window['breakMinutes'] as num?)?.toInt() ?? 0,
        graceLateMinutes: (window['graceLateMinutes'] as num?)?.toInt() ?? 0,
        graceEarlyMinutes: (window['graceEarlyMinutes'] as num?)?.toInt() ?? 0,
      );
    }
    return HrmShift(
      id: json['id']?.toString() ?? 's-01',
      code: json['code']?.toString() ?? 'CA_HC',
      name: json['name']?.toString() ?? 'models.shift.office_hours'.tr(),
      startTime: json['start_time']?.toString() ?? json['startTime']?.toString() ?? '08:00:00',
      endTime: json['end_time']?.toString() ?? json['endTime']?.toString() ?? '17:30:00',
      breakMinutes: (json['break_minutes'] ?? json['breakMinutes'] as num?)?.toInt() ?? 90,
      graceLateMinutes: (json['grace_late_minutes'] ?? json['graceLateMinutes'] as num?)?.toInt() ?? 10,
      graceEarlyMinutes: (json['grace_early_minutes'] ?? json['graceEarlyMinutes'] as num?)?.toInt() ?? 5,
    );
  }
}

class HrmSite {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusM;

  HrmSite({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
  });

  factory HrmSite.fromJson(Map<String, dynamic> json) {
    return HrmSite(
      id: json['id']?.toString() ?? 'site-01',
      name: json['name']?.toString() ?? 'models.site.hq_savina'.tr(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 10.776889,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 106.700806,
      radiusM: (json['radius_m'] ?? json['radiusM'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

class AttendanceContext {
  final String serverTime;
  final String workDate;
  final String employeeId;
  final String employeeCode;
  final String fullName;
  final HrmShift? shift;
  final bool requireGps;
  final List<String> allowedMethods;
  final List<HrmSite> sites;

  AttendanceContext({
    required this.serverTime,
    required this.workDate,
    required this.employeeId,
    required this.employeeCode,
    required this.fullName,
    this.shift,
    this.requireGps = false,
    required this.allowedMethods,
    required this.sites,
  });

  factory AttendanceContext.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'] as Map<String, dynamic>? ?? json['user'] as Map<String, dynamic>? ?? json['profile'] as Map<String, dynamic>? ?? {};
    final rawSites = json['sites'] as List<dynamic>? ?? [];

    return AttendanceContext(
      serverTime: json['server_time']?.toString() ?? DateTime.now().toIso8601String(),
      workDate: json['work_date']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10),
      employeeId: emp['id']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeCode: emp['employee_code']?.toString() ?? emp['code']?.toString() ?? json['employee_code']?.toString() ?? '',
      fullName: emp['full_name']?.toString() ?? emp['fullName']?.toString() ?? emp['name']?.toString() ?? json['full_name']?.toString() ?? '',
      shift: json['shift'] is Map<String, dynamic> ? HrmShift.fromJson(json['shift'] as Map<String, dynamic>) : null,
      requireGps: (json['requireGps'] ?? json['require_gps']) == true,
      allowedMethods: (json['allowed_methods'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      sites: rawSites.map((e) => HrmSite.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class AttendancePunch {
  final String punchType; // 'IN' | 'OUT'
  final String occurredAt;
  final String? verificationMethod;
  final String? siteName;
  final String? deviceName;

  AttendancePunch({
    required this.punchType,
    required this.occurredAt,
    this.verificationMethod = 'GPS',
    this.siteName,
    this.deviceName,
  });

  factory AttendancePunch.fromJson(Map<String, dynamic> json) {
    return AttendancePunch(
      punchType: json['punch_type']?.toString() ?? json['punchType']?.toString() ?? 'IN',
      occurredAt: json['occurred_at']?.toString() ?? json['occurredAt']?.toString() ?? '',
      verificationMethod: json['verification_method']?.toString() ?? json['verificationMethod']?.toString() ?? 'GPS',
      siteName: json['site_name']?.toString() ?? json['siteName']?.toString(),
      deviceName: json['device_name']?.toString() ?? json['deviceName']?.toString(),
    );
  }
}

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String workDate;
  final String? firstCheckInAt;
  final String? lastCheckOutAt;
  final int workedMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final String status; // 'VALID' | 'LATE' | 'EARLY_LEAVE' | 'ABNORMAL' | 'APPROVED_CORRECTION'
  final String attendanceSource;
  final String? matchedSiteName;
  final String? note;
  final List<AttendancePunch>? punches;

  List<AttendancePunch> get punchList => punches ?? const [];

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.workDate,
    this.firstCheckInAt,
    this.lastCheckOutAt,
    this.workedMinutes = 0,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    required this.status,
    this.attendanceSource = 'MOBILE_APP',
    this.matchedSiteName,
    this.note,
    this.punches = const [],
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final rawPunches = json['punches'] as List<dynamic>? ?? [];
    return AttendanceRecord(
      id: json['id']?.toString() ?? 'att-0',
      employeeId: json['employee_id']?.toString() ?? json['employeeId']?.toString() ?? '',
      workDate: json['work_date']?.toString() ?? json['workDate']?.toString() ?? '',
      firstCheckInAt: json['first_check_in_at']?.toString() ?? json['firstCheckInAt']?.toString() ?? json['check_in_at']?.toString(),
      lastCheckOutAt: json['last_check_out_at']?.toString() ?? json['lastCheckOutAt']?.toString() ?? json['check_out_at']?.toString(),
      workedMinutes: (json['worked_minutes'] ?? json['workedMinutes'] as num?)?.toInt() ?? 0,
      lateMinutes: (json['late_minutes'] ?? json['lateMinutes'] as num?)?.toInt() ?? 0,
      earlyLeaveMinutes: (json['early_leave_minutes'] ?? json['earlyLeaveMinutes'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'VALID',
      attendanceSource: json['attendance_source']?.toString() ?? json['attendanceSource']?.toString() ?? 'MOBILE_APP',
      matchedSiteName: json['matched_site_name']?.toString() ?? json['matchedSiteName']?.toString() ?? 'models.site.hq'.tr(),
      note: json['note']?.toString(),
      punches: rawPunches.map((p) => AttendancePunch.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}

class AttendanceCorrection {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? attendanceId;
  final String requestDate;
  final String? fromDate;
  final String? toDate;
  final String? newCheckInAt;
  final String? newCheckOutAt;
  final String reason;
  final double? duration;
  final String? leaveTypeName;
  final String status; // 'PENDING' | 'APPROVED' | 'REJECTED'
  final String createdAt;
  final String? rejectionReason;

  AttendanceCorrection({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.attendanceId,
    required this.requestDate,
    this.fromDate,
    this.toDate,
    this.newCheckInAt,
    this.newCheckOutAt,
    required this.reason,
    this.duration,
    this.leaveTypeName,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  factory AttendanceCorrection.fromJson(Map<String, dynamic> json) {
    final rawDate = json['request_date']?.toString() ??
        json['requestDate']?.toString() ??
        json['start_date']?.toString() ??
        json['fromDate']?.toString() ??
        json['from_date']?.toString() ??
        json['created_at']?.toString() ??
        DateTime.now().toIso8601String();
    final cleanDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    final title = json['title']?.toString() ??
        json['leave_type_name']?.toString() ??
        json['leaveTypeName']?.toString() ??
        (json['leave_type'] is Map ? json['leave_type']['name']?.toString() : null) ??
        '';
    final rawReason = json['reason']?.toString() ?? json['notes']?.toString() ?? json['description']?.toString() ?? '';
    final combinedReason = title.isNotEmpty && rawReason.isNotEmpty && !rawReason.contains(title)
        ? '[$title] $rawReason'
        : (rawReason.isNotEmpty ? rawReason : (title.isNotEmpty ? title : 'models.request.default_title'.tr()));

    double? parsedDuration;
    if (json['duration'] != null) {
      parsedDuration = double.tryParse(json['duration'].toString());
    }

    final rawFrom = json['from_date']?.toString() ?? json['fromDate']?.toString() ?? json['start_date']?.toString() ?? cleanDate;
    final rawTo = json['to_date']?.toString() ?? json['toDate']?.toString() ?? json['end_date']?.toString() ?? cleanDate;

    return AttendanceCorrection(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? json['employeeId']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ??
          json['employeeName']?.toString() ??
          (json['employee'] is Map ? json['employee']['name']?.toString() : null),
      attendanceId: json['attendance_id']?.toString() ?? json['attendanceId']?.toString(),
      requestDate: cleanDate,
      fromDate: rawFrom.length >= 10 ? rawFrom.substring(0, 10) : rawFrom,
      toDate: rawTo.length >= 10 ? rawTo.substring(0, 10) : rawTo,
      newCheckInAt: json['new_check_in_at']?.toString() ?? json['newCheckInAt']?.toString() ?? json['start_date']?.toString(),
      newCheckOutAt: json['new_check_out_at']?.toString() ?? json['newCheckOutAt']?.toString() ?? json['end_date']?.toString(),
      reason: combinedReason,
      duration: parsedDuration,
      leaveTypeName: title.isNotEmpty ? title : null,
      status: (json['status']?.toString() ?? 'PENDING').toUpperCase(),
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      rejectionReason: json['rejection_reason']?.toString() ?? json['rejectionReason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'attendance_id': attendanceId,
      'request_date': requestDate,
      'from_date': fromDate,
      'to_date': toDate,
      'new_check_in_at': newCheckInAt,
      'new_check_out_at': newCheckOutAt,
      'reason': reason,
      'duration': duration,
      'leave_type_name': leaveTypeName,
      'status': status,
      'created_at': createdAt,
      'rejection_reason': rejectionReason,
    };
  }
}

class MonthlyAttendanceSummary {
  final String monthYear;
  final int totalWorkDays;
  final int actualWorkDays;
  final int lateDays;
  final int earlyLeaveDays;
  final int leaveDays;
  final int unauthorizedAbsenceDays;
  final double totalWorkHours;
  final double totalOvertimeHours;

  const MonthlyAttendanceSummary({
    required this.monthYear,
    this.totalWorkDays = 22,
    this.actualWorkDays = 0,
    this.lateDays = 0,
    this.earlyLeaveDays = 0,
    this.leaveDays = 0,
    this.unauthorizedAbsenceDays = 0,
    this.totalWorkHours = 0.0,
    this.totalOvertimeHours = 0.0,
  });

  factory MonthlyAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return MonthlyAttendanceSummary(
      monthYear: json['month_year']?.toString() ?? json['monthYear']?.toString() ?? 'T10/2026',
      totalWorkDays: (json['total_work_days'] ?? json['totalWorkDays'] as num?)?.toInt() ?? 22,
      actualWorkDays: (json['actual_work_days'] ?? json['actualWorkDays'] as num?)?.toInt() ?? 0,
      lateDays: (json['late_days'] ?? json['lateDays'] as num?)?.toInt() ?? 0,
      earlyLeaveDays: (json['early_leave_days'] ?? json['earlyLeaveDays'] as num?)?.toInt() ?? 0,
      leaveDays: (json['leave_days'] ?? json['leaveDays'] as num?)?.toInt() ?? 0,
      unauthorizedAbsenceDays: (json['unauthorized_absence_days'] ?? json['unauthorizedAbsenceDays'] as num?)?.toInt() ?? 0,
      totalWorkHours: (json['total_work_hours'] ?? json['totalWorkHours'] as num?)?.toDouble() ?? 0.0,
      totalOvertimeHours: (json['total_overtime_hours'] ?? json['totalOvertimeHours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ShiftAssignment {
  final String id;
  final String employeeId;
  final DateTime workDate;
  final String shiftId;
  final String? shiftName;
  final String status;

  const ShiftAssignment({
    required this.id,
    required this.employeeId,
    required this.workDate,
    required this.shiftId,
    this.shiftName,
    this.status = 'ASSIGNED',
  });

  factory ShiftAssignment.fromJson(Map<String, dynamic> json) {
    final rawDate = json['work_date'] ?? json['workDate'] ?? json['date'] ?? DateTime.now().toIso8601String();
    return ShiftAssignment(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? json['employeeId']?.toString() ?? '',
      workDate: DateTime.tryParse(rawDate.toString()) ?? DateTime.now(),
      shiftId: json['shift_id']?.toString() ?? json['shiftId']?.toString() ?? '',
      shiftName: json['shift_name']?.toString() ?? json['shiftName']?.toString(),
      status: json['status']?.toString() ?? 'ASSIGNED',
    );
  }
}

class HrmBoardMonthInfo {
  final String month; // e.g. "2026-10"
  final String from; // e.g. "2026-10-01"
  final String to; // e.g. "2026-10-31"
  final String state; // "OPEN" | "LOCKED" | "REVIEWING"
  final String? periodId;
  final String? requestsClosedAt;
  final String? lockedAt;
  final String? calculatedAt;

  HrmBoardMonthInfo({
    required this.month,
    required this.from,
    required this.to,
    required this.state,
    this.periodId,
    this.requestsClosedAt,
    this.lockedAt,
    this.calculatedAt,
  });

  String get stateLabel {
    switch (state) {
      case 'OPEN':
        return 'models.period.open'.tr();
      case 'LOCKED':
        return 'models.period.locked'.tr();
      case 'REQUESTS_CLOSED':
        return 'models.period.closed'.tr();
      default:
        return state;
    }
  }

  factory HrmBoardMonthInfo.fromJson(Map<String, dynamic> json) {
    return HrmBoardMonthInfo(
      month: json['month']?.toString() ?? '',
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      state: (json['state']?.toString() ?? 'OPEN').toUpperCase(),
      periodId: json['periodId']?.toString() ?? json['period_id']?.toString(),
      requestsClosedAt: json['requestsClosedAt']?.toString() ?? json['requests_closed_at']?.toString(),
      lockedAt: json['lockedAt']?.toString() ?? json['locked_at']?.toString(),
      calculatedAt: json['calculatedAt']?.toString() ?? json['calculated_at']?.toString(),
    );
  }
}

class HrmBoardCalendarDay {
  final String date;
  final int weekday; // 0 = Sun, 1 = Mon ... 6 = Sat
  final String kind; // 'WORK' | 'OFF' | 'HOLIDAY'
  final String? holidayName;

  HrmBoardCalendarDay({
    required this.date,
    required this.weekday,
    required this.kind,
    this.holidayName,
  });

  factory HrmBoardCalendarDay.fromJson(Map<String, dynamic> json) {
    return HrmBoardCalendarDay(
      date: json['date']?.toString() ?? '',
      weekday: (json['weekday'] as num?)?.toInt() ?? 0,
      kind: (json['kind']?.toString() ?? 'WORK').toUpperCase(),
      holidayName: json['holidayName']?.toString() ?? json['holiday_name']?.toString(),
    );
  }
}

class HrmDayRequest {
  final String id;
  final String kind; // 'LEAVE' | 'OT' | 'TRIP' | 'CORRECTION' | 'SHIFT_CHANGE' | 'CUSTOM'
  final String status; // 'APPROVED' | 'PENDING' | 'REJECTED'
  final String? code;
  final String? label;
  final String? reasonName;
  final String? description;
  final String? fromAt;
  final String? toAt;
  final int? minutes;
  final double? otRate;
  final String? punchIn;
  final String? punchOut;
  final String? createdAt;

  HrmDayRequest({
    required this.id,
    required this.kind,
    required this.status,
    this.code,
    this.label,
    this.reasonName,
    this.description,
    this.fromAt,
    this.toAt,
    this.minutes,
    this.otRate,
    this.punchIn,
    this.punchOut,
    this.createdAt,
  });

  factory HrmDayRequest.fromJson(Map<String, dynamic> json) {
    return HrmDayRequest(
      id: json['id']?.toString() ?? '',
      kind: (json['kind']?.toString() ?? 'LEAVE').toUpperCase(),
      status: (json['status']?.toString() ?? 'PENDING').toUpperCase(),
      code: json['code']?.toString(),
      label: json['label']?.toString(),
      reasonName: json['reasonName']?.toString() ?? json['reason_name']?.toString(),
      description: json['description']?.toString(),
      fromAt: json['fromAt']?.toString() ?? json['from_at']?.toString(),
      toAt: json['toAt']?.toString() ?? json['to_at']?.toString(),
      minutes: (json['minutes'] as num?)?.toInt(),
      otRate: (json['otRate'] ?? json['ot_rate'] as num?)?.toDouble(),
      punchIn: json['punchIn']?.toString() ?? json['punch_in']?.toString(),
      punchOut: json['punchOut']?.toString() ?? json['punch_out']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
    );
  }
}

class HrmDayLeaveInfo {
  final String? reasonName;
  final bool paid;
  final bool annual;
  final double days;

  HrmDayLeaveInfo({
    this.reasonName,
    this.paid = true,
    this.annual = false,
    this.days = 1.0,
  });

  factory HrmDayLeaveInfo.fromJson(Map<String, dynamic> json) {
    return HrmDayLeaveInfo(
      reasonName: json['reasonName']?.toString() ?? json['reason_name']?.toString() ?? json['name']?.toString(),
      paid: json['paid'] == true || json['isPaid'] == true || json['is_paid'] == true,
      annual: json['annual'] == true || json['isAnnual'] == true || json['is_annual'] == true,
      days: (json['days'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class HrmBoardDay {
  final String date;
  final String kind; // 'WORK' | 'OFF' | 'HOLIDAY'
  final String status; // 'PRESENT' | 'LATE' | 'EARLY_LEAVE' | 'LATE_EARLY' | 'ABNORMAL' | 'ABSENT' | 'ANNUAL_LEAVE' | 'PAID_LEAVE' | 'UNPAID_LEAVE' | 'TRIP' | 'OFF' | 'HOLIDAY' | 'NO_SCHEDULE' | 'FUTURE'
  final String? shiftCode;
  final String? shiftName;
  final String? shiftStart;
  final String? shiftEnd;
  final String? shiftBreakStart;
  final String? shiftBreakEnd;
  final int shiftBreakMinutes;
  final String? checkIn;
  final String? checkOut;
  final int scheduledMinutes;
  final int workedMinutes;
  final int paidMinutes;
  final double workdayUnits;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int otMinutes;
  final List<String> anomalies;
  final String? tripId;
  final String? holidayName;
  final bool adjusted;
  final List<HrmDayRequest> requests;
  final HrmDayLeaveInfo? leave;

  HrmBoardDay({
    required this.date,
    required this.kind,
    required this.status,
    this.shiftCode,
    this.shiftName,
    this.shiftStart,
    this.shiftEnd,
    this.shiftBreakStart,
    this.shiftBreakEnd,
    this.shiftBreakMinutes = 0,
    this.checkIn,
    this.checkOut,
    this.scheduledMinutes = 0,
    this.workedMinutes = 0,
    this.paidMinutes = 0,
    this.workdayUnits = 0.0,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.otMinutes = 0,
    this.anomalies = const [],
    this.tripId,
    this.holidayName,
    this.adjusted = false,
    this.requests = const [],
    this.leave,
  });

  bool get isLateOrEarly => lateMinutes > 0 || earlyLeaveMinutes > 0;
  int get earlyMinutes => earlyLeaveMinutes;
  bool get isAbsent => status == 'ABSENT';
  bool get isOff => kind == 'OFF' || status == 'OFF';
  bool get isHoliday => kind == 'HOLIDAY' || status == 'HOLIDAY';
  bool get isFuture => status == 'FUTURE';

  factory HrmBoardDay.fromJson(Map<String, dynamic> json) {
    final anomaliesRaw = json['anomalies'];
    final List<String> anomaliesList = [];
    if (anomaliesRaw is List) {
      for (final a in anomaliesRaw) {
        if (a != null) anomaliesList.add(a.toString());
      }
    }

    final requestsRaw = json['requests'];
    final List<HrmDayRequest> requestsList = [];
    if (requestsRaw is List) {
      for (final r in requestsRaw) {
        if (r is Map<String, dynamic>) {
          requestsList.add(HrmDayRequest.fromJson(r));
        }
      }
    }

    return HrmBoardDay(
      date: json['date']?.toString() ?? '',
      kind: (json['kind']?.toString() ?? 'WORK').toUpperCase(),
      status: (json['status']?.toString() ?? 'NO_SCHEDULE').toUpperCase(),
      shiftCode: json['shiftCode']?.toString() ?? json['shift_code']?.toString(),
      shiftName: json['shiftName']?.toString() ?? json['shift_name']?.toString(),
      shiftStart: json['shiftStart']?.toString() ?? json['shift_start']?.toString(),
      shiftEnd: json['shiftEnd']?.toString() ?? json['shift_end']?.toString(),
      shiftBreakStart: json['shiftBreakStart']?.toString() ?? json['shift_break_start']?.toString(),
      shiftBreakEnd: json['shiftBreakEnd']?.toString() ?? json['shift_break_end']?.toString(),
      shiftBreakMinutes: (json['shiftBreakMinutes'] ?? json['shift_break_minutes'] as num?)?.toInt() ?? 0,
      checkIn: json['checkIn']?.toString() ?? json['check_in']?.toString(),
      checkOut: json['checkOut']?.toString() ?? json['check_out']?.toString(),
      scheduledMinutes: (json['scheduledMinutes'] ?? json['scheduled_minutes'] as num?)?.toInt() ?? 0,
      workedMinutes: (json['workedMinutes'] ?? json['worked_minutes'] as num?)?.toInt() ?? 0,
      paidMinutes: (json['paidMinutes'] ?? json['paid_minutes'] as num?)?.toInt() ?? 0,
      workdayUnits: (json['workdayUnits'] ?? json['workday_units'] as num?)?.toDouble() ?? 0.0,
      lateMinutes: (json['lateMinutes'] ?? json['late_minutes'] as num?)?.toInt() ?? 0,
      earlyLeaveMinutes: (json['earlyLeaveMinutes'] ?? json['early_leave_minutes'] as num?)?.toInt() ?? 0,
      otMinutes: (json['otMinutes'] ?? json['ot_minutes'] as num?)?.toInt() ?? 0,
      anomalies: anomaliesList,
      tripId: json['tripId']?.toString() ?? json['trip_id']?.toString(),
      holidayName: json['holidayName']?.toString() ?? json['holiday_name']?.toString(),
      adjusted: json['adjusted'] == true,
      requests: requestsList,
      leave: json['leave'] is Map<String, dynamic> ? HrmDayLeaveInfo.fromJson(json['leave'] as Map<String, dynamic>) : null,
    );
  }
}

class HrmBoardTotals {
  final double workdayUnits;
  final int workedMinutes;
  final int paidMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int otMinutes;
  final int lateDays;
  final int earlyLeaveDays;
  final int abnormalDays;
  final int unscheduledDays;
  final int absentDays;
  final int annualLeaveDays;
  final int paidLeaveDays;
  final int unpaidLeaveDays;
  final int tripDays;
  final int offDays;
  final int holidayDays;

  HrmBoardTotals({
    this.workdayUnits = 0.0,
    this.workedMinutes = 0,
    this.paidMinutes = 0,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.otMinutes = 0,
    this.lateDays = 0,
    this.earlyLeaveDays = 0,
    this.abnormalDays = 0,
    this.unscheduledDays = 0,
    this.absentDays = 0,
    this.annualLeaveDays = 0,
    this.paidLeaveDays = 0,
    this.unpaidLeaveDays = 0,
    this.tripDays = 0,
    this.offDays = 0,
    this.holidayDays = 0,
  });

  factory HrmBoardTotals.fromJson(Map<String, dynamic> json) {
    return HrmBoardTotals(
      workdayUnits: (json['workdayUnits'] ?? json['workday_units'] as num?)?.toDouble() ?? 0.0,
      workedMinutes: (json['workedMinutes'] ?? json['worked_minutes'] as num?)?.toInt() ?? 0,
      paidMinutes: (json['paidMinutes'] ?? json['paid_minutes'] as num?)?.toInt() ?? 0,
      lateMinutes: (json['lateMinutes'] ?? json['late_minutes'] as num?)?.toInt() ?? 0,
      earlyLeaveMinutes: (json['earlyLeaveMinutes'] ?? json['early_leave_minutes'] as num?)?.toInt() ?? 0,
      otMinutes: (json['otMinutes'] ?? json['ot_minutes'] as num?)?.toInt() ?? 0,
      lateDays: (json['lateDays'] ?? json['late_days'] as num?)?.toInt() ?? 0,
      earlyLeaveDays: (json['earlyLeaveDays'] ?? json['early_leave_days'] as num?)?.toInt() ?? 0,
      abnormalDays: (json['abnormalDays'] ?? json['abnormal_days'] as num?)?.toInt() ?? 0,
      unscheduledDays: (json['unscheduledDays'] ?? json['unscheduled_days'] as num?)?.toInt() ?? 0,
      absentDays: (json['absentDays'] ?? json['absent_days'] as num?)?.toInt() ?? 0,
      annualLeaveDays: (json['annualLeaveDays'] ?? json['annual_leave_days'] as num?)?.toInt() ?? 0,
      paidLeaveDays: (json['paidLeaveDays'] ?? json['paid_leave_days'] as num?)?.toInt() ?? 0,
      unpaidLeaveDays: (json['unpaidLeaveDays'] ?? json['unpaid_leave_days'] as num?)?.toInt() ?? 0,
      tripDays: (json['tripDays'] ?? json['trip_days'] as num?)?.toInt() ?? 0,
      offDays: (json['offDays'] ?? json['off_days'] as num?)?.toInt() ?? 0,
      holidayDays: (json['holidayDays'] ?? json['holiday_days'] as num?)?.toInt() ?? 0,
    );
  }
}

class HrmBoardStandard {
  final String mode; // 'DYNAMIC' | 'FIXED' | 'MINUTES'
  final double workdays;

  HrmBoardStandard({
    this.mode = 'DYNAMIC',
    this.workdays = 0.0,
  });

  factory HrmBoardStandard.fromJson(Map<String, dynamic> json) {
    return HrmBoardStandard(
      mode: json['mode']?.toString() ?? 'DYNAMIC',
      workdays: (json['workdays'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HrmBoardEmployee {
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final String? positionName;
  final Map<String, HrmBoardDay> days;
  final HrmBoardTotals totals;
  final HrmBoardStandard? standard;

  HrmBoardEmployee({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    this.positionName,
    this.days = const {},
    required this.totals,
    this.standard,
  });

  factory HrmBoardEmployee.fromJson(Map<String, dynamic> json) {
    final Map<String, HrmBoardDay> daysMap = {};
    final rawDays = json['days'];
    if (rawDays is Map<String, dynamic>) {
      rawDays.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          daysMap[k] = HrmBoardDay.fromJson(v);
        }
      });
    }

    return HrmBoardEmployee(
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString() ?? '',
      departmentName: json['departmentName']?.toString() ?? json['department_name']?.toString(),
      positionName: json['positionName']?.toString() ?? json['position_name']?.toString(),
      days: daysMap,
      totals: json['totals'] is Map<String, dynamic>
          ? HrmBoardTotals.fromJson(json['totals'] as Map<String, dynamic>)
          : HrmBoardTotals(),
      standard: json['standard'] is Map<String, dynamic>
          ? HrmBoardStandard.fromJson(json['standard'] as Map<String, dynamic>)
          : null,
    );
  }
}

class HrmTimesheetBoard {
  final HrmBoardMonthInfo month;
  final bool canViewAll;
  final List<HrmBoardCalendarDay> calendar;
  final List<HrmBoardEmployee> employees;
  final Map<String, dynamic> meta;

  HrmTimesheetBoard({
    required this.month,
    required this.canViewAll,
    this.calendar = const [],
    this.employees = const [],
    this.meta = const {},
  });

  HrmBoardEmployee? get myEmployee => employees.isNotEmpty ? employees.first : null;

  factory HrmTimesheetBoard.fromJson(Map<String, dynamic> json) {
    final calRaw = json['calendar'];
    final List<HrmBoardCalendarDay> calList = [];
    if (calRaw is List) {
      for (final c in calRaw) {
        if (c is Map<String, dynamic>) {
          calList.add(HrmBoardCalendarDay.fromJson(c));
        }
      }
    }

    final empRaw = json['employees'];
    final List<HrmBoardEmployee> empList = [];
    if (empRaw is List) {
      for (final e in empRaw) {
        if (e is Map<String, dynamic>) {
          empList.add(HrmBoardEmployee.fromJson(e));
        }
      }
    }

    return HrmTimesheetBoard(
      month: json['month'] is Map<String, dynamic>
          ? HrmBoardMonthInfo.fromJson(json['month'] as Map<String, dynamic>)
          : HrmBoardMonthInfo(month: '', from: '', to: '', state: 'OPEN'),
      canViewAll: json['canViewAll'] == true || json['can_view_all'] == true,
      calendar: calList,
      employees: empList,
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] as Map<String, dynamic> : {},
    );
  }
}

class TimesheetCell {
  final int day;
  final String date;
  final String status;
  final String shiftCode;
  final String shiftName;
  final String? firstIn;
  final String? lastOut;
  final int lateMinutes;
  final int earlyMinutes;
  final double workUnits;
  final bool isLate;
  final bool isAbnormal;
  final bool isAbsent;
  final bool isLeave;
  final String? leaveType;
  final List<AttendancePunch> punches;
  final HrmBoardDay? rawBoardDay;

  TimesheetCell({
    required this.day,
    required this.date,
    this.status = 'PRESENT',
    this.shiftCode = 'CA_HC',
    String? shiftName,
    this.firstIn,
    this.lastOut,
    this.lateMinutes = 0,
    this.earlyMinutes = 0,
    this.workUnits = 1.0,
    this.isLate = false,
    this.isAbnormal = false,
    this.isAbsent = false,
    this.isLeave = false,
    this.leaveType,
    this.punches = const [],
    this.rawBoardDay,
  }) : shiftName = shiftName ?? 'models.shift.office_hours'.tr();

  factory TimesheetCell.fromBoardDay(int day, HrmBoardDay d) {
    final punches = <AttendancePunch>[];
    if (d.checkIn != null && d.checkIn!.isNotEmpty) {
      punches.add(AttendancePunch(punchType: 'IN', occurredAt: d.checkIn!));
    }
    if (d.checkOut != null && d.checkOut!.isNotEmpty) {
      punches.add(AttendancePunch(punchType: 'OUT', occurredAt: d.checkOut!));
    }
    final isLv = d.status.contains('LEAVE') || d.requests.any((r) => r.kind == 'LEAVE');
    final String? lvType = d.requests.where((r) => r.kind == 'LEAVE').firstOrNull?.label ?? (isLv ? 'models.request.leave'.tr() : null);
    final isAbs = d.status == 'ABSENT';
    final isAbn = d.status == 'ABNORMAL' || isAbs;
    final isLt = d.lateMinutes > 0 || d.earlyLeaveMinutes > 0 || d.status == 'LATE' || d.status == 'LATE_EARLY' || d.status == 'EARLY_LEAVE';

    return TimesheetCell(
      day: day,
      date: d.date,
      status: d.status,
      shiftCode: d.shiftCode ?? 'CA_HC',
      shiftName: d.shiftName ?? 'models.shift.office_hours'.tr(),
      firstIn: d.checkIn,
      lastOut: d.checkOut,
      lateMinutes: d.lateMinutes,
      earlyMinutes: d.earlyMinutes,
      workUnits: d.workdayUnits,
      isLate: isLt,
      isAbnormal: isAbn,
      isAbsent: isAbs,
      isLeave: isLv,
      leaveType: lvType,
      punches: punches,
      rawBoardDay: d,
    );
  }
}

class MonthlyTimesheetSummary {
  final double standardWorkDays;
  final String standardHint;
  final double actualWorkDays;
  final int lateDays;
  final int lateMinutes;
  final int earlyDays;
  final int earlyMinutes;
  final double leaveDays;
  final int absentDays;
  final double otHours;
  final int abnormalDays;
  final int tripDays;
  final int unscheduledDays;
  final int missingPunchDays;
  final double paidLeaveDays;
  final double unpaidLeaveDays;
  final double holidayDays;
  final double totalWorkHours;
  final double completionRate;

  MonthlyTimesheetSummary({
    this.standardWorkDays = 22.0,
    String? standardHint,
    this.actualWorkDays = 0.0,
    this.lateDays = 0,
    this.lateMinutes = 0,
    this.earlyDays = 0,
    this.earlyMinutes = 0,
    this.leaveDays = 0.0,
    this.absentDays = 0,
    this.otHours = 0.0,
    this.abnormalDays = 0,
    this.tripDays = 0,
    this.unscheduledDays = 0,
    this.missingPunchDays = 0,
    this.paidLeaveDays = 0.0,
    this.unpaidLeaveDays = 0.0,
    this.holidayDays = 0.0,
    this.totalWorkHours = 0.0,
    this.completionRate = 0.0,
  }) : standardHint = standardHint ?? 'models.standard.dynamic'.tr();
}

class MonthlyTimesheetRow {
  final String employeeCode;
  final String employeeName;
  final String departmentName;
  final String positionName;
  final bool isCurrentUser;
  final Map<int, TimesheetCell> cells;
  final MonthlyTimesheetSummary summary;

  MonthlyTimesheetRow({
    required this.employeeCode,
    required this.employeeName,
    this.departmentName = '',
    this.positionName = '',
    this.isCurrentUser = true,
    this.cells = const {},
    required this.summary,
  });

  factory MonthlyTimesheetRow.fromBoardEmployee(HrmBoardEmployee emp, [HrmBoardStandard? standard]) {
    final cellMap = <int, TimesheetCell>{};
    emp.days.forEach((dateStr, boardDay) {
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        final d = int.tryParse(parts[2]);
        if (d != null) {
          cellMap[d] = TimesheetCell.fromBoardDay(d, boardDay);
        }
      }
    });

    final totalAbsent = emp.totals.absentDays;
    final totalAbnormal = emp.totals.abnormalDays;
    final combinedMissing = totalAbsent > 0 ? (totalAbsent + totalAbnormal) : totalAbnormal;
    final standardDays = standard?.workdays ?? 22.0;
    final isFixed = standard?.mode == 'FIXED' || standard?.mode == 'MINUTES';
    final stdHint = isFixed ? 'models.standard.fixed'.tr() : 'models.standard.dynamic'.tr();
    final totalLeaves = (emp.totals.annualLeaveDays + emp.totals.paidLeaveDays + emp.totals.unpaidLeaveDays).toDouble();
    final otHours = emp.totals.otMinutes / 60.0;
    final rate = standardDays > 0 ? ((emp.totals.workdayUnits / standardDays) * 100.0).clamp(0.0, 100.0) : 0.0;

    return MonthlyTimesheetRow(
      employeeCode: emp.employeeCode,
      employeeName: emp.employeeName,
      departmentName: emp.departmentName ?? '',
      positionName: emp.positionName ?? '',
      isCurrentUser: true,
      cells: cellMap,
      summary: MonthlyTimesheetSummary(
        standardWorkDays: standardDays,
        standardHint: stdHint,
        actualWorkDays: emp.totals.workdayUnits,
        lateDays: emp.totals.lateDays,
        lateMinutes: emp.totals.lateMinutes,
        earlyDays: emp.totals.earlyLeaveDays,
        earlyMinutes: emp.totals.earlyLeaveMinutes,
        leaveDays: totalLeaves,
        absentDays: totalAbsent,
        otHours: otHours,
        abnormalDays: totalAbnormal,
        tripDays: emp.totals.tripDays,
        unscheduledDays: emp.totals.unscheduledDays,
        missingPunchDays: combinedMissing,
        paidLeaveDays: emp.totals.paidLeaveDays.toDouble(),
        unpaidLeaveDays: emp.totals.unpaidLeaveDays.toDouble(),
        holidayDays: emp.totals.holidayDays.toDouble(),
        totalWorkHours: emp.totals.workedMinutes / 60.0,
        completionRate: rate,
      ),
    );
  }
}

// ==========================================
// THÁNG CÔNG & ĐIỀU KIỆN CHỐT CÔNG (WEB SYNCHRONIZED)
// ==========================================
class HrmMonthCloseItem {
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final String date;
  final String reason;

  HrmMonthCloseItem({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.date,
    required this.reason,
  });

  factory HrmMonthCloseItem.fromJson(Map<String, dynamic> json) {
    return HrmMonthCloseItem(
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      reason: json['reason']?.toString() ?? json['message']?.toString() ?? '',
    );
  }
}

class HrmMonthCloseBlocker {
  final String code;
  final String message;
  final int count;
  final List<HrmMonthCloseItem> items;

  HrmMonthCloseBlocker({
    required this.code,
    required this.message,
    required this.count,
    this.items = const [],
  });

  factory HrmMonthCloseBlocker.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<HrmMonthCloseItem> itemsList = [];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          itemsList.add(HrmMonthCloseItem.fromJson(it));
        }
      }
    }
    return HrmMonthCloseBlocker(
      code: json['code']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      items: itemsList,
    );
  }
}

class HrmMonthCloseState {
  final HrmBoardMonthInfo month;
  final List<HrmMonthCloseBlocker> blockersForRequests;
  final List<HrmMonthCloseBlocker> blockersForLock;

  HrmMonthCloseState({
    required this.month,
    this.blockersForRequests = const [],
    this.blockersForLock = const [],
  });

  factory HrmMonthCloseState.fromJson(Map<String, dynamic> json) {
    final rawReq = json['blockersForRequests'] ?? json['blockers_for_requests'];
    final List<HrmMonthCloseBlocker> reqList = [];
    if (rawReq is List) {
      for (final b in rawReq) {
        if (b is Map<String, dynamic>) {
          reqList.add(HrmMonthCloseBlocker.fromJson(b));
        }
      }
    }

    final rawLock = json['blockersForLock'] ?? json['blockers_for_lock'];
    final List<HrmMonthCloseBlocker> lockList = [];
    if (rawLock is List) {
      for (final b in rawLock) {
        if (b is Map<String, dynamic>) {
          lockList.add(HrmMonthCloseBlocker.fromJson(b));
        }
      }
    }

    return HrmMonthCloseState(
      month: json['month'] is Map<String, dynamic>
          ? HrmBoardMonthInfo.fromJson(json['month'] as Map<String, dynamic>)
          : HrmBoardMonthInfo(month: '', from: '', to: '', state: 'OPEN'),
      blockersForRequests: reqList,
      blockersForLock: lockList,
    );
  }
}

class HrmTimesheetCalculateResult {
  final int count;
  final int abnormal;

  HrmTimesheetCalculateResult({required this.count, required this.abnormal});

  factory HrmTimesheetCalculateResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] is Map<String, dynamic> ? json['result'] as Map<String, dynamic> : json;
    return HrmTimesheetCalculateResult(
      count: (result['count'] as num?)?.toInt() ?? 0,
      abnormal: (result['abnormal'] as num?)?.toInt() ?? 0,
    );
  }
}

class HrmAttendanceDataRow {
  final String id;
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final String? departmentName;
  final String workDate;
  final String? checkInAt;
  final String? checkOutAt;
  final int workedMinutes;
  final int scheduledMinutes;
  final int lateMinutes;
  final int earlyMinutes;
  final String status;
  final String? source;

  HrmAttendanceDataRow({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.departmentName,
    required this.workDate,
    this.checkInAt,
    this.checkOutAt,
    this.workedMinutes = 0,
    this.scheduledMinutes = 0,
    this.lateMinutes = 0,
    this.earlyMinutes = 0,
    this.status = 'VALID',
    this.source,
  });

  factory HrmAttendanceDataRow.fromJson(Map<String, dynamic> json) {
    return HrmAttendanceDataRow(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString() ?? json['fullName']?.toString() ?? json['full_name']?.toString() ?? '',
      departmentName: json['departmentName']?.toString() ?? json['department_name']?.toString(),
      workDate: json['workDate']?.toString() ?? json['work_date']?.toString() ?? '',
      checkInAt: json['checkInAt']?.toString() ?? json['check_in_at']?.toString() ?? json['firstCheckInAt']?.toString() ?? json['first_check_in_at']?.toString(),
      checkOutAt: json['checkOutAt']?.toString() ?? json['check_out_at']?.toString() ?? json['lastCheckOutAt']?.toString() ?? json['last_check_out_at']?.toString(),
      workedMinutes: (json['workedMinutes'] ?? json['worked_minutes'] as num?)?.toInt() ?? 0,
      scheduledMinutes: (json['scheduledMinutes'] ?? json['scheduled_minutes'] as num?)?.toInt() ?? 0,
      lateMinutes: (json['lateMinutes'] ?? json['late_minutes'] as num?)?.toInt() ?? 0,
      earlyMinutes: (json['earlyMinutes'] ?? json['early_minutes'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'VALID',
      source: json['source']?.toString() ?? json['attendance_source']?.toString() ?? json['attendanceSource']?.toString(),
    );
  }
}

class HrmAttendanceRawEvent {
  final String id;
  final String eventKind; // 'IN' | 'OUT'
  final String occurredAt;
  final String? source;
  final String? deviceId;
  final Map<String, dynamic>? gpsCoordinates;
  final String? voidedByCorrectionId;

  HrmAttendanceRawEvent({
    required this.id,
    required this.eventKind,
    required this.occurredAt,
    this.source,
    this.deviceId,
    this.gpsCoordinates,
    this.voidedByCorrectionId,
  });

  factory HrmAttendanceRawEvent.fromJson(Map<String, dynamic> json) {
    return HrmAttendanceRawEvent(
      id: json['id']?.toString() ?? '',
      eventKind: json['event_kind']?.toString() ?? json['eventKind']?.toString() ?? json['kind']?.toString() ?? 'IN',
      occurredAt: json['occurred_at']?.toString() ?? json['occurredAt']?.toString() ?? '',
      source: json['source']?.toString(),
      deviceId: json['device_id']?.toString() ?? json['deviceId']?.toString(),
      gpsCoordinates: json['gps_coordinates'] is Map ? (json['gps_coordinates'] as Map<String, dynamic>) : null,
      voidedByCorrectionId: json['voided_by_correction_id']?.toString() ?? json['voidedByCorrectionId']?.toString(),
    );
  }
}


