import '../core/i18n/app_i18n.dart';
enum HrmRequestType {
  leave,
  overtime,
  advance,
  attendanceCorrection,
  shiftChange,
  businessTrip,
}

enum HrmRequestStatus {
  pending,
  approved,
  rejected,
  draft,
  cancelled,
  processing,
}

class HrmRequestItem {
  final String id;
  final HrmRequestType type;
  final String title;
  final String employeeId;
  final String employeeName;
  final String employeeCode;
  final String department;
  final DateTime requestDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? durationHours;
  final double? durationDays;
  final double? amount;
  final String reason;
  final HrmRequestStatus status;
  final String? approverName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? note;
  final String? rawStatus;

  const HrmRequestItem({
    required this.id,
    required this.type,
    required this.title,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.department,
    required this.requestDate,
    this.startDate,
    this.endDate,
    this.durationHours,
    this.durationDays,
    this.amount,
    required this.reason,
    required this.status,
    this.approverName,
    this.approvedAt,
    this.rejectionReason,
    this.note,
    this.rawStatus,
  });

  String get typeLabel {
    switch (type) {
      case HrmRequestType.leave:
        return 'models.request.leave'.tr();
      case HrmRequestType.overtime:
        return 'models.request.overtime_ot'.tr();
      case HrmRequestType.advance:
        return 'models.request.salary_advance'.tr();
      case HrmRequestType.attendanceCorrection:
        return 'models.request.attendance_explanation'.tr();
      case HrmRequestType.shiftChange:
        return 'models.request.change_shift'.tr();
      case HrmRequestType.businessTrip:
        return 'models.request.business_trip'.tr();
    }
  }

  String get apiKind {
    switch (type) {
      case HrmRequestType.leave:
        return 'leave';
      case HrmRequestType.overtime:
        return 'ot';
      case HrmRequestType.advance:
        return 'advance';
      case HrmRequestType.attendanceCorrection:
        return 'correction';
      case HrmRequestType.shiftChange:
        return 'shift_change';
      case HrmRequestType.businessTrip:
        return 'business_trip';
    }
  }

  String get statusLabel {
    switch (status) {
      case HrmRequestStatus.pending:
        return 'models.status.pending'.tr();
      case HrmRequestStatus.approved:
        return 'models.status.approved_full'.tr();
      case HrmRequestStatus.rejected:
        return 'common.reject'.tr();
      case HrmRequestStatus.draft:
        return 'models.status.draft'.tr();
      case HrmRequestStatus.cancelled:
        return 'models.status.withdrawn'.tr();
      case HrmRequestStatus.processing:
        return 'models.status.processing'.tr();
    }
  }


  factory HrmRequestItem.fromJson(
    Map<String, dynamic> json, {
    HrmRequestType? forcedType,
    String? employeeNameFallback,
    String? employeeCodeFallback,
    String? departmentFallback,
  }) {
    HrmRequestType resolveType(dynamic t) {
      if (forcedType != null) return forcedType;
      final typeStr = (t ?? '').toString().toUpperCase();
      switch (typeStr) {
        case 'LEAVE':
          return HrmRequestType.leave;
        case 'OVERTIME':
        case 'OT':
          return HrmRequestType.overtime;
        case 'ADVANCE':
        case 'SALARY_ADVANCE':
          return HrmRequestType.advance;
        case 'ATTENDANCE_CORRECTION':
        case 'CORRECTION':
          return HrmRequestType.attendanceCorrection;
        case 'SHIFT_CHANGE':
        case 'SHIFT_EXCHANGE':
          return HrmRequestType.shiftChange;
        case 'BUSINESS_TRIP':
        case 'TRIP':
          return HrmRequestType.businessTrip;
        default:
          if (json['otType'] != null || json['plannedMinutes'] != null) {
            return HrmRequestType.overtime;
          }
          if (json['businessTripType'] != null || json['destination'] != null) {
            return HrmRequestType.businessTrip;
          }
          if (json['correctedSessions'] != null || json['reasonName'] == 'Quên chấm công') {
            return HrmRequestType.attendanceCorrection;
          }
          if (json['leaveType'] != null || json['leave_type_id'] != null || json['leave_type'] != null || json['leaveTypeCode'] != null) {
            return HrmRequestType.leave;
          }
          return HrmRequestType.leave;
      }
    }

    final rawStat = (json['status'] ?? json['state'] ?? 'PENDING').toString().toUpperCase();

    HrmRequestStatus resolveStatus(String s) {
      switch (s) {
        case 'APPROVED':
          return HrmRequestStatus.approved;
        case 'REJECTED':
          return HrmRequestStatus.rejected;
        case 'DRAFT':
          return HrmRequestStatus.draft;
        case 'CANCELLED':
        case 'WITHDRAWN':
        case 'CANCEL':
          return HrmRequestStatus.cancelled;
        case 'PROCESSING':
        case 'IN_PROGRESS':
          return HrmRequestStatus.processing;
        case 'PENDING':
        case 'PENDING_APPROVAL':
        case 'SUBMITTED':
        default:
          return HrmRequestStatus.pending;
      }
    }

    String empName = json['employee_name'] ?? json['full_name'] ?? json['employeeName'] ?? '';
    String empCode = json['employee_code'] ?? json['employeeCode'] ?? '';
    String dept = json['department'] ?? json['departmentName'] ?? '';

    if (json['employee'] is Map) {
      final empMap = json['employee'] as Map<String, dynamic>;
      if (empName.isEmpty) empName = empMap['fullName']?.toString() ?? empMap['full_name']?.toString() ?? empMap['name']?.toString() ?? '';
      if (empCode.isEmpty) empCode = empMap['code']?.toString() ?? empMap['employeeCode']?.toString() ?? '';
      if (dept.isEmpty) {
        if (empMap['department'] is Map) {
          dept = empMap['department']['name']?.toString() ?? '';
        } else if (empMap['department'] is String) {
          dept = empMap['department'].toString();
        }
      }
    }

    if (empName.isEmpty && employeeNameFallback != null && employeeNameFallback.isNotEmpty) {
      empName = employeeNameFallback;
    }
    if (empCode.isEmpty && employeeCodeFallback != null && employeeCodeFallback.isNotEmpty) {
      empCode = employeeCodeFallback;
    }
    if (dept.isEmpty && departmentFallback != null && departmentFallback.isNotEmpty) {
      dept = departmentFallback;
    }

    if (empName.isEmpty) empName = 'models.employee.default_name'.tr();
    if (empCode.isEmpty) empCode = 'NV001';
    if (dept.isEmpty) dept = 'models.employee.default_dept'.tr();

    final leaveTypeMap = json['leaveType'] is Map ? json['leaveType'] as Map<String, dynamic> : (json['leave_type'] is Map ? json['leave_type'] as Map<String, dynamic> : null);
    final leaveTypeName = leaveTypeMap?['name']?.toString() ?? json['leave_type_name']?.toString() ?? json['leaveTypeName']?.toString() ?? '';

    String reasonStr = '';
    if (json['reason'] != null && json['reason'].toString().trim().isNotEmpty) {
      reasonStr = json['reason'].toString().trim();
    } else if (json['reasonName'] != null && json['reasonName'].toString().trim().isNotEmpty) {
      reasonStr = json['reasonName'].toString().trim();
    } else if (json['description'] != null && json['description'].toString().trim().isNotEmpty) {
      reasonStr = json['description'].toString().trim();
    } else if (json['note'] != null && json['note'].toString().trim().isNotEmpty) {
      reasonStr = json['note'].toString().trim();
    } else if (leaveTypeName.isNotEmpty) {
      reasonStr = leaveTypeName;
    } else {
      reasonStr = 'models.request.default_reason'.tr();
    }

    final titleStr = json['title']?.toString() ?? json['projectName']?.toString() ?? (leaveTypeName.isNotEmpty ? 'models.request.form_named'.tr(args: {'name': leaveTypeName}) : 'models.request.default_form'.tr());

    final startDateRaw = json['fromAt'] ?? json['start_date'] ?? json['startDate'] ?? json['fromDate'] ?? json['from_date'] ??
        (json['workDate'] != null ? '${json['workDate']}T${json['startTime'] ?? '00:00:00'}' : null);
    final endDateRaw = json['toAt'] ?? json['end_date'] ?? json['endDate'] ?? json['toDate'] ?? json['to_date'] ??
        (json['workDate'] != null ? '${json['workDate']}T${json['endTime'] ?? '00:00:00'}' : null);

    final durDays = (json['duration_days'] as num?)?.toDouble() ??
        (json['daysCount'] as num?)?.toDouble() ??
        (json['days'] as num?)?.toDouble() ??
        (json['duration'] as num?)?.toDouble();

    final durHours = (json['duration_hours'] as num?)?.toDouble() ??
        (json['hours'] as num?)?.toDouble() ??
        (json['plannedMinutes'] != null ? (json['plannedMinutes'] as num).toDouble() / 60.0 : null);

    final requestDateRaw = json['request_date'] ?? json['requestDate'] ?? json['created_at'] ?? json['createdAt'];

    return HrmRequestItem(
      id: json['id']?.toString() ?? '',
      type: resolveType(json['request_type'] ?? json['type'] ?? json['kind']),
      title: titleStr,
      employeeId: json['employee_id']?.toString() ?? json['employeeId']?.toString() ?? '',
      employeeName: empName,
      employeeCode: empCode,
      department: dept,
      requestDate: requestDateRaw != null ? (DateTime.tryParse(requestDateRaw.toString()) ?? DateTime.now()) : DateTime.now(),
      startDate: startDateRaw != null ? DateTime.tryParse(startDateRaw.toString()) : null,
      endDate: endDateRaw != null ? DateTime.tryParse(endDateRaw.toString()) : null,
      durationHours: durHours,
      durationDays: durDays,
      amount: (json['amount'] as num?)?.toDouble(),
      reason: reasonStr,
      status: resolveStatus(rawStat),
      approverName: json['approver_name'] ?? json['approverName'] ?? json['approvedBy'],
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : (json['approvedAt'] != null ? DateTime.tryParse(json['approvedAt'].toString()) : null),
      rejectionReason: json['rejection_reason'] ?? json['rejectionReason'],
      note: json['note']?.toString(),
      rawStatus: rawStat,
    );
  }
}

class HrmEmployeeItem {
  final String id;
  final String code;
  final String fullName;
  final String email;
  final String phone;
  final String department;
  final String position;
  final String status;
  final DateTime? joinDate;
  final String? avatarUrl;
  final double? baseSalary;
  final String? contractType;
  final int completionRate;
  final String? maritalStatus;
  final String? gender;
  final String? dateOfBirth;
  final String? identityCardNumber;
  final String? nationality;
  final String? ethnicity;
  final String? placeOfBirth;
  final String? hometown;
  final String? permanentAddress;
  final String? currentAddress;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelationship;
  final String? taxCode;
  final String? bankAccountNumber;
  final String? bankName;

  const HrmEmployeeItem({
    required this.id,
    required this.code,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.department,
    required this.position,
    required this.status,
    this.joinDate,
    this.avatarUrl,
    this.baseSalary,
    this.contractType,
    this.completionRate = 20,
    this.maritalStatus,
    this.gender,
    this.dateOfBirth,
    this.identityCardNumber,
    this.nationality,
    this.ethnicity,
    this.placeOfBirth,
    this.hometown,
    this.permanentAddress,
    this.currentAddress,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelationship,
    this.taxCode,
    this.bankAccountNumber,
    this.bankName,
  });

  static String _extractName(dynamic val, [String fallback = '']) {
    if (val == null) return fallback;
    if (val is String) return val.trim().isNotEmpty ? val.trim() : fallback;
    if (val is Map) {
      final name = val['name'] ?? val['title'] ?? val['unitName'] ?? val['departmentName'] ?? val['positionName'] ?? val['label'];
      if (name != null && name.toString().trim().isNotEmpty) return name.toString().trim();
    }
    return val.toString().trim().isNotEmpty ? val.toString().trim() : fallback;
  }

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  static double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  factory HrmEmployeeItem.fromJson(Map<String, dynamic> json) {
    final rawName = json['fullName'] ?? json['full_name'] ?? json['name'] ?? json['employeeName'];
    final rawCode = json['employeeCode'] ?? json['employee_code'] ?? json['code'];
    final rawEmail = json['email'] ?? json['workEmail'] ?? json['work_email'] ?? json['personalEmail'] ?? json['personal_email'];
    final rawDept = json['department'] ?? json['unit'] ?? json['organizationUnit'] ?? json['departmentName'] ?? json['department_name'] ?? json['division'];
    final rawPos = json['position'] ?? json['positionName'] ?? json['position_name'] ?? json['jobTitle'] ?? json['job_title'] ?? json['positionTitle'];
    final rawStatus = json['employmentStatus'] ?? json['employment_status'] ?? json['status'] ?? 'OFFICIAL';
    final rawJoin = json['hireDate'] ?? json['startDate'] ?? json['joinDate'] ?? json['join_date'] ?? json['created_at'];

    final rawBaseSalary = json['baseSalary'] ?? json['base_salary'];
    final rawCompletionRate = json['completionRate'] ?? json['completion_rate'] ?? json['profileCompletion'];

    return HrmEmployeeItem(
      id: json['id']?.toString() ?? json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      code: rawCode?.toString() ?? 'EMP-000',
      fullName: _extractName(rawName, 'models.employee.unnamed'.tr()),
      email: rawEmail?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['mobilePhone']?.toString() ?? json['mobile_phone']?.toString() ?? '',
      department: _extractName(rawDept, 'models.employee.default_block'.tr()),
      position: _extractName(rawPos, 'models.employee.default_position'.tr()),
      status: rawStatus?.toString() ?? 'OFFICIAL',
      joinDate: rawJoin != null ? DateTime.tryParse(rawJoin.toString()) : null,
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
      baseSalary: rawBaseSalary != null ? _parseDouble(rawBaseSalary) : null,
      contractType: json['contractType']?.toString() ?? json['contract_type']?.toString() ?? 'models.employee.contract_official'.tr(),
      completionRate: _parseInt(rawCompletionRate, 20),
      maritalStatus: json['maritalStatus']?.toString() ?? json['marital_status']?.toString(),
      gender: json['gender']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString() ?? json['date_of_birth']?.toString() ?? json['birthDate']?.toString(),
      identityCardNumber: json['identityCardNumber']?.toString() ?? json['identity_card_number']?.toString() ?? json['idCard']?.toString(),
      nationality: json['nationality']?.toString(),
      ethnicity: json['ethnicity']?.toString(),
      placeOfBirth: json['placeOfBirth']?.toString() ?? json['place_of_birth']?.toString(),
      hometown: json['hometown']?.toString(),
      permanentAddress: json['permanentAddress']?.toString() ?? json['permanent_address']?.toString(),
      currentAddress: json['currentAddress']?.toString() ?? json['current_address']?.toString(),
      emergencyContactName: json['emergencyContactName']?.toString() ?? json['emergency_contact_name']?.toString(),
      emergencyContactPhone: json['emergencyContactPhone']?.toString() ?? json['emergency_contact_phone']?.toString(),
      emergencyContactRelationship: json['emergencyContactRelationship']?.toString() ?? json['emergency_contact_relationship']?.toString(),
      taxCode: json['taxCode']?.toString() ?? json['tax_code']?.toString(),
      bankAccountNumber: json['bankAccountNumber']?.toString() ?? json['bank_account_number']?.toString(),
      bankName: json['bankName']?.toString() ?? json['bank_name']?.toString(),
    );
  }

  String get maritalStatusLabel {
    switch (maritalStatus?.toUpperCase()) {
      case 'SINGLE':
        return 'models.marital.single'.tr();
      case 'MARRIED':
        return 'models.marital.married'.tr();
      case 'DIVORCED':
        return 'models.marital.divorced'.tr();
      default:
        return maritalStatus?.isNotEmpty == true ? maritalStatus! : 'models.marital.single'.tr();
    }
  }

  String get genderLabel {
    switch (gender?.toUpperCase()) {
      case 'MALE':
        return 'models.gender.male'.tr();
      case 'FEMALE':
        return 'models.gender.female'.tr();
      default:
        return gender?.isNotEmpty == true ? gender! : 'models.gender.male'.tr();
    }
  }

  DateTime? get hireDate => joinDate;

  String get avatarInitials {
    final parts = fullName.trim().split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join().toUpperCase();
    return parts.isNotEmpty ? parts : 'NV';
  }
}

class HrmPositionItem {
  final String id;
  final String code;
  final String title;
  final String department;
  final String? salaryGrade;
  final bool isConfigured;
  final int activeEmployeeCount;
  final String? jobPurpose;

  const HrmPositionItem({
    required this.id,
    required this.code,
    required this.title,
    required this.department,
    this.salaryGrade,
    this.isConfigured = false,
    this.activeEmployeeCount = 0,
    this.jobPurpose,
  });

  bool get hasJd => isConfigured;
  String get positionName => title;
  String get positionCode => code;
  String get departmentName => department;

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  static String _extractUnit(dynamic json) {
    if (json == null) return 'models.org.unassigned'.tr();
    final unitObj = (json['unit'] is Map ? json['unit'] as Map<String, dynamic> : null) ??
        (json['organizationUnit'] is Map ? json['organizationUnit'] as Map<String, dynamic> : null) ??
        (json['orgUnit'] is Map ? json['orgUnit'] as Map<String, dynamic> : null) ??
        (json['department'] is Map ? json['department'] as Map<String, dynamic> : null);

    if (unitObj != null) {
      final name = unitObj['name'] ?? unitObj['unitName'] ?? unitObj['title'];
      if (name != null && name.toString().trim().isNotEmpty) return name.toString().trim();
    }

    final raw = json['unitName'] ??
        json['organizationUnitName'] ??
        json['orgUnitName'] ??
        (json['department'] is String ? json['department'] : null) ??
        json['departmentName'] ??
        json['department_name'] ??
        json['unit'];

    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return 'models.org.unassigned'.tr();
  }

  factory HrmPositionItem.fromJson(Map<String, dynamic> json) {
    final unitName = _extractUnit(json);

    String? sg;
    if (json['salaryGrade'] is Map) {
      final sgMap = json['salaryGrade'] as Map<String, dynamic>;
      final code = sgMap['code']?.toString() ?? '';
      final name = sgMap['name']?.toString() ?? '';
      sg = code.isNotEmpty && name.isNotEmpty ? '$code - $name' : (name.isNotEmpty ? name : code);
    } else if (json['salaryGrade'] != null && json['salaryGrade'].toString().isNotEmpty && json['salaryGrade'].toString() != 'null') {
      sg = json['salaryGrade']?.toString();
    } else if (json['salaryGradeName'] != null && json['salaryGradeName'].toString().isNotEmpty) {
      sg = json['salaryGradeName']?.toString();
    }

    final status = json['jdStatus']?.toString() ?? json['jd_status']?.toString() ?? json['jobDescriptionStatus']?.toString();
    final isConfigured = json['hasJd'] == true ||
        json['has_jd'] == true ||
        status == 'CONFIGURED' ||
        status == 'ACTIVE' ||
        status == 'ESTABLISHED';

    final count = _parseInt(
      json['activeEmployeeCount'] ??
      json['employeeCount'] ??
      json['employee_count'] ??
      json['employeesCount'] ??
      json['totalEmployees'],
      0,
    );

    return HrmPositionItem(
      id: json['positionId']?.toString() ?? json['id']?.toString() ?? '',
      code: json['positionCode']?.toString() ?? json['code']?.toString() ?? '',
      title: json['positionName']?.toString() ?? json['title']?.toString() ?? json['name']?.toString() ?? 'models.position.default_title'.tr(),
      department: unitName,
      salaryGrade: (sg == null || sg.isEmpty || sg == 'null') ? 'models.position.no_grade'.tr() : sg,
      isConfigured: isConfigured,
      activeEmployeeCount: count,
      jobPurpose: json['jobPurpose']?.toString(),
    );
  }
}


class HrmPayslipItem {
  final String id;
  final String period; // e.g. "09/2026"
  final double baseSalary;
  final double allowances;
  final double overtimePay;
  final double bonuses;
  final double deductions;
  final double netSalary;
  final String status;
  final DateTime? paidDate;

  const HrmPayslipItem({
    required this.id,
    required this.period,
    required this.baseSalary,
    required this.allowances,
    required this.overtimePay,
    required this.bonuses,
    required this.deductions,
    required this.netSalary,
    required this.status,
    this.paidDate,
  });

  factory HrmPayslipItem.fromJson(Map<String, dynamic> json) {
    return HrmPayslipItem(
      id: json['id']?.toString() ?? '',
      period: json['period'] ?? '09/2026',
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 15000000,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 2500000,
      overtimePay: (json['overtime_pay'] as num?)?.toDouble() ?? 1200000,
      bonuses: (json['bonuses'] as num?)?.toDouble() ?? 1000000,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 1850000,
      netSalary: (json['net_salary'] as num?)?.toDouble() ?? 17850000,
      status: json['status'] ?? 'PAID',
      paidDate: json['paid_date'] != null ? DateTime.tryParse(json['paid_date']) : null,
    );
  }
}

class HrmDashboardStats {
  final int totalEmployees;
  final int activeEmployees;
  final int workingToday;
  final int onLeaveToday;
  final int pendingRequests;
  final int lateArrivals;

  const HrmDashboardStats({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.workingToday,
    required this.onLeaveToday,
    required this.pendingRequests,
    required this.lateArrivals,
  });

  factory HrmDashboardStats.fromJson(Map<String, dynamic> json) {
    return HrmDashboardStats(
      totalEmployees: json['total_employees'] ?? 48,
      activeEmployees: json['active_employees'] ?? 46,
      workingToday: json['working_today'] ?? 42,
      onLeaveToday: json['on_leave_today'] ?? 4,
      pendingRequests: json['pending_requests'] ?? 5,
      lateArrivals: json['late_arrivals'] ?? 2,
    );
  }
}

class HrmDependentItem {
  final String id;
  final String employeeId;
  final String employeeName;
  final String fullName;
  final String relationship; // Con ruột, Cha/Mẹ, Vợ/Chồng
  final DateTime dateOfBirth;
  final String idNumber;
  final String taxCode;
  final String status; // VERIFIED, PENDING
  final DateTime startDate;
  final DateTime? endDate;

  const HrmDependentItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.fullName,
    required this.relationship,
    required this.dateOfBirth,
    required this.idNumber,
    required this.taxCode,
    required this.status,
    required this.startDate,
    this.endDate,
  });
}

class HrmSalaryAdvanceItem {
  final String id;
  final String employeeId;
  final String employeeName;
  final double amount;
  final String reason;
  final DateTime requestDate;
  final String status; // PENDING, APPROVED, RECOVERING, COMPLETED, REJECTED
  final String repaymentPeriod; // e.g. "10/2026 - 12/2026"
  final double repaidAmount;
  final double monthlyDeduction;

  const HrmSalaryAdvanceItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    required this.reason,
    required this.requestDate,
    required this.status,
    required this.repaymentPeriod,
    required this.repaidAmount,
    required this.monthlyDeduction,
  });
}

class HrmTimesheetSummaryItem {
  final String employeeId;
  final String employeeName;
  final String employeeCode;
  final String department;
  final double standardWorkdays;
  final double actualWorkdays;
  final double paidLeaveDays;
  final double overtimeHours;
  final int lateCount;
  final int missingPunchCount;
  final String status; // VALID, NEEDS_REVIEW, LOCKED

  const HrmTimesheetSummaryItem({
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.department,
    required this.standardWorkdays,
    required this.actualWorkdays,
    required this.paidLeaveDays,
    required this.overtimeHours,
    required this.lateCount,
    required this.missingPunchCount,
    required this.status,
  });
}

class HrmPolicyConfig {
  final int annualLeaves;
  final int lateGraceMinutes;
  final double otWeekdayRate;
  final double otWeekendRate;
  final double otHolidayRate;
  final double geofenceRadiusMeters;
  final bool requireWifiMatching;
  final bool autoApproveOt;

  const HrmPolicyConfig({
    this.annualLeaves = 12,
    this.lateGraceMinutes = 15,
    this.otWeekdayRate = 1.5,
    this.otWeekendRate = 2.0,
    this.otHolidayRate = 3.0,
    this.geofenceRadiusMeters = 100,
    this.requireWifiMatching = true,
    this.autoApproveOt = false,
  });
}

class HrmIntegrationDevice {
  final String id;
  final String name;
  final String type; // Biometric, FaceID, Cloud Sync, Webhook
  final String ipAddress;
  final String location;
  final String status; // ONLINE, OFFLINE
  final DateTime lastSync;

  const HrmIntegrationDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.ipAddress,
    required this.location,
    required this.status,
    required this.lastSync,
  });
}

class HrmCommentMention {
  final String userId;
  final String name;

  const HrmCommentMention({
    required this.userId,
    required this.name,
  });

  factory HrmCommentMention.fromJson(Map<String, dynamic> json) {
    return HrmCommentMention(
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
  };
}

class HrmMentionCandidate {
  final String userId;
  final String name;
  final String employeeCode;
  final String department;

  const HrmMentionCandidate({
    required this.userId,
    required this.name,
    this.employeeCode = '',
    this.department = '',
  });

  factory HrmMentionCandidate.fromJson(Map<String, dynamic> json) {
    return HrmMentionCandidate(
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['code']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
    );
  }
}

class HrmRequestComment {
  final String id;
  final String requestKind;
  final String requestId;
  final String authorUserId;
  final String authorName;
  final String kind; // 'COMMENT' | 'DECISION'
  final String? decision;
  final String body;
  final List<HrmCommentMention> mentions;
  final DateTime createdAt;
  final bool mine;

  const HrmRequestComment({
    required this.id,
    required this.requestKind,
    required this.requestId,
    required this.authorUserId,
    required this.authorName,
    required this.kind,
    this.decision,
    required this.body,
    this.mentions = const [],
    required this.createdAt,
    this.mine = false,
  });

  factory HrmRequestComment.fromJson(Map<String, dynamic> json) {
    final mentionsRaw = json['mentions'];
    final List<HrmCommentMention> parsedMentions = [];
    if (mentionsRaw is List) {
      for (final m in mentionsRaw) {
        if (m is Map<String, dynamic>) {
          parsedMentions.add(HrmCommentMention.fromJson(m));
        }
      }
    }

    DateTime parsedCreated = DateTime.now();
    if (json['createdAt'] != null) {
      parsedCreated = DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now();
    } else if (json['created_at'] != null) {
      parsedCreated = DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now();
    }

    return HrmRequestComment(
      id: json['id']?.toString() ?? '',
      requestKind: json['requestKind']?.toString() ?? json['kind']?.toString() ?? '',
      requestId: json['requestId']?.toString() ?? json['request_id']?.toString() ?? '',
      authorUserId: json['authorUserId']?.toString() ?? json['author_user_id']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? json['author_name']?.toString() ?? 'Người dùng',
      kind: (json['kind'] ?? json['commentKind'] ?? 'COMMENT').toString().toUpperCase(),
      decision: json['decision']?.toString(),
      body: json['body']?.toString() ?? '',
      mentions: parsedMentions,
      createdAt: parsedCreated,
      mine: json['mine'] == true,
    );
  }
}


