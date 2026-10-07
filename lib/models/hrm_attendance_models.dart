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
      name: json['name']?.toString() ?? json['title']?.toString() ?? json['code']?.toString() ?? 'Nghỉ phép',
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

  factory HrmShift.fromJson(Map<String, dynamic> json) {
    return HrmShift(
      id: json['id']?.toString() ?? 's-01',
      code: json['code']?.toString() ?? 'CA_HC',
      name: json['name']?.toString() ?? 'Ca Hành chính',
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
      name: json['name']?.toString() ?? 'Trụ sở chính SAVINA',
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
  final HrmShift shift;
  final List<String> allowedMethods;
  final List<HrmSite> sites;

  AttendanceContext({
    required this.serverTime,
    required this.workDate,
    required this.employeeId,
    required this.employeeCode,
    required this.fullName,
    required this.shift,
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
      employeeCode: emp['employee_code']?.toString() ?? emp['code']?.toString() ?? json['employee_code']?.toString() ?? 'MS_385',
      fullName: emp['full_name']?.toString() ?? emp['fullName']?.toString() ?? emp['name']?.toString() ?? json['full_name']?.toString() ?? 'Nguyễn Tấn Tài',
      shift: json['shift'] != null ? HrmShift.fromJson(json['shift']) : HrmShift(id: 's-01', code: 'CA_HC', name: 'Ca Hành chính', startTime: '08:00:00', endTime: '17:30:00'),
      allowedMethods: (json['allowed_methods'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['GPS', 'WIFI_WAN_IP'],
      sites: rawSites.map((e) => HrmSite.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class PrecheckResult {
  final bool eligible;
  final String? matchedSiteId;
  final String matchedSiteName;
  final double distanceM;
  final String verificationMethod;
  final bool canCheckIn;
  final bool canCheckOut;

  PrecheckResult({
    required this.eligible,
    this.matchedSiteId,
    required this.matchedSiteName,
    this.distanceM = 15.0,
    this.verificationMethod = 'GPS',
    required this.canCheckIn,
    required this.canCheckOut,
  });

  factory PrecheckResult.fromJson(Map<String, dynamic> json) {
    final matched = json['matched_site'] as Map<String, dynamic>? ?? {};
    return PrecheckResult(
      eligible: json['eligible'] == true,
      matchedSiteId: matched['id']?.toString(),
      matchedSiteName: matched['name']?.toString() ?? 'Trụ sở chính SAVINA',
      distanceM: (matched['distance_m'] as num?)?.toDouble() ?? 15.0,
      verificationMethod: json['verification_method']?.toString() ?? 'GPS',
      canCheckIn: json['can_check_in'] == true,
      canCheckOut: json['can_check_out'] == true,
    );
  }
}

class AttendancePunch {
  final String punchType; // 'IN' | 'OUT'
  final String occurredAt;
  final String? verificationMethod;
  final String? siteName;

  AttendancePunch({
    required this.punchType,
    required this.occurredAt,
    this.verificationMethod = 'GPS',
    this.siteName,
  });

  factory AttendancePunch.fromJson(Map<String, dynamic> json) {
    return AttendancePunch(
      punchType: json['punch_type']?.toString() ?? json['punchType']?.toString() ?? 'IN',
      occurredAt: json['occurred_at']?.toString() ?? json['occurredAt']?.toString() ?? '',
      verificationMethod: json['verification_method']?.toString() ?? json['verificationMethod']?.toString() ?? 'GPS',
      siteName: json['site_name']?.toString() ?? json['siteName']?.toString(),
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
      matchedSiteName: json['matched_site_name']?.toString() ?? json['matchedSiteName']?.toString() ?? 'Trụ sở chính',
      note: json['note']?.toString(),
      punches: rawPunches.map((p) => AttendancePunch.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}

class AttendanceCorrection {
  final String id;
  final String employeeId;
  final String? attendanceId;
  final String requestDate;
  final String? newCheckInAt;
  final String? newCheckOutAt;
  final String reason;
  final String status; // 'PENDING' | 'APPROVED' | 'REJECTED'
  final String createdAt;
  final String? rejectionReason;

  AttendanceCorrection({
    required this.id,
    required this.employeeId,
    this.attendanceId,
    required this.requestDate,
    this.newCheckInAt,
    this.newCheckOutAt,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  factory AttendanceCorrection.fromJson(Map<String, dynamic> json) {
    final rawDate = json['request_date']?.toString() ??
        json['requestDate']?.toString() ??
        json['start_date']?.toString() ??
        json['created_at']?.toString() ??
        DateTime.now().toIso8601String();
    final cleanDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    final title = json['title']?.toString() ?? '';
    final rawReason = json['reason']?.toString() ?? json['notes']?.toString() ?? json['description']?.toString() ?? '';
    final combinedReason = title.isNotEmpty && rawReason.isNotEmpty && !rawReason.contains(title)
        ? '[$title] $rawReason'
        : (rawReason.isNotEmpty ? rawReason : (title.isNotEmpty ? title : 'Đơn đề xuất'));

    return AttendanceCorrection(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? json['employeeId']?.toString() ?? '',
      attendanceId: json['attendance_id']?.toString() ?? json['attendanceId']?.toString(),
      requestDate: cleanDate,
      newCheckInAt: json['new_check_in_at']?.toString() ?? json['newCheckInAt']?.toString() ?? json['start_date']?.toString(),
      newCheckOutAt: json['new_check_out_at']?.toString() ?? json['newCheckOutAt']?.toString() ?? json['end_date']?.toString(),
      reason: combinedReason,
      status: (json['status']?.toString() ?? 'PENDING').toUpperCase(),
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      rejectionReason: json['rejection_reason']?.toString() ?? json['rejectionReason']?.toString(),
    );
  }
}
