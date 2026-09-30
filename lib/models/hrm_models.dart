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
  final double? amount;
  final String reason;
  final HrmRequestStatus status;
  final String? approverName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? note;

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
    this.amount,
    required this.reason,
    required this.status,
    this.approverName,
    this.approvedAt,
    this.rejectionReason,
    this.note,
  });

  String get typeLabel {
    switch (type) {
      case HrmRequestType.leave:
        return 'Nghỉ phép';
      case HrmRequestType.overtime:
        return 'Làm thêm (OT)';
      case HrmRequestType.advance:
        return 'Tạm ứng lương';
      case HrmRequestType.attendanceCorrection:
        return 'Giải trình công';
      case HrmRequestType.shiftChange:
        return 'Đổi ca làm';
      case HrmRequestType.businessTrip:
        return 'Công tác';
    }
  }

  String get statusLabel {
    switch (status) {
      case HrmRequestStatus.pending:
        return 'Chờ duyệt';
      case HrmRequestStatus.approved:
        return 'Đã phê duyệt';
      case HrmRequestStatus.rejected:
        return 'Từ chối';
      case HrmRequestStatus.draft:
        return 'Bản nháp';
      case HrmRequestStatus.cancelled:
        return 'Đã hủy';
    }
  }

  factory HrmRequestItem.fromJson(Map<String, dynamic> json) {
    HrmRequestType resolveType(String? t) {
      switch ((t ?? '').toUpperCase()) {
        case 'LEAVE':
          return HrmRequestType.leave;
        case 'OVERTIME':
        case 'OT':
          return HrmRequestType.overtime;
        case 'ADVANCE':
          return HrmRequestType.advance;
        case 'ATTENDANCE_CORRECTION':
        case 'CORRECTION':
          return HrmRequestType.attendanceCorrection;
        case 'SHIFT_CHANGE':
        case 'SHIFT_EXCHANGE':
          return HrmRequestType.shiftChange;
        case 'BUSINESS_TRIP':
          return HrmRequestType.businessTrip;
        default:
          return HrmRequestType.leave;
      }
    }

    HrmRequestStatus resolveStatus(String? s) {
      switch ((s ?? '').toUpperCase()) {
        case 'APPROVED':
          return HrmRequestStatus.approved;
        case 'REJECTED':
          return HrmRequestStatus.rejected;
        case 'DRAFT':
          return HrmRequestStatus.draft;
        case 'CANCELLED':
          return HrmRequestStatus.cancelled;
        case 'PENDING':
        case 'PENDING_APPROVAL':
        default:
          return HrmRequestStatus.pending;
      }
    }

    return HrmRequestItem(
      id: json['id']?.toString() ?? '',
      type: resolveType(json['request_type'] ?? json['type'] ?? json['kind']),
      title: json['title'] ?? 'Yêu cầu nhân sự',
      employeeId: json['employee_id']?.toString() ?? '',
      employeeName: json['employee_name'] ?? json['full_name'] ?? 'Nhân viên SAVINA',
      employeeCode: json['employee_code'] ?? 'SVN-EMP',
      department: json['department'] ?? 'Khối Kỹ thuật \u0026 Vận hành',
      requestDate: DateTime.tryParse(json['request_date'] ?? json['created_at'] ?? '') ?? DateTime.now(),
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      durationHours: (json['duration_hours'] as num?)?.toDouble() ?? (json['hours'] as num?)?.toDouble(),
      amount: (json['amount'] as num?)?.toDouble(),
      reason: json['reason'] ?? '',
      status: resolveStatus(json['status']),
      approverName: json['approver_name'],
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at']) : null,
      rejectionReason: json['rejection_reason'],
      note: json['note'],
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
  });

  factory HrmEmployeeItem.fromJson(Map<String, dynamic> json) {
    return HrmEmployeeItem(
      id: json['id']?.toString() ?? '',
      code: json['code'] ?? json['employee_code'] ?? 'EMP-000',
      fullName: json['full_name'] ?? json['name'] ?? 'Chưa đặt tên',
      email: json['email'] ?? '',
      phone: json['phone'] ?? json['mobile_phone'] ?? '',
      department: json['department'] ?? json['department_name'] ?? 'Phòng Kỹ thuật',
      position: json['position'] ?? json['job_title'] ?? 'Chuyên viên',
      status: json['status'] ?? 'ACTIVE',
      joinDate: json['join_date'] != null ? DateTime.tryParse(json['join_date']) : null,
      avatarUrl: json['avatar_url'],
      baseSalary: (json['base_salary'] as num?)?.toDouble(),
      contractType: json['contract_type'] ?? 'Hợp đồng lao động không xác định thời hạn',
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
