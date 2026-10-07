import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/hrm_models.dart';
import '../models/hrm_attendance_models.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

class HrmService {
  static final HrmService _instance = HrmService._internal();
  factory HrmService() => _instance;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  HrmService._internal() {
    ApiClientHelper.configureDio(_dio);
  }

  // In-memory persistent caches for realistic state transitions
  List<HrmRequestItem>? _cachedRequests;
  List<HrmEmployeeItem>? _cachedEmployees;
  List<HrmPayslipItem>? _cachedPayslips;
  List<HrmShift>? _cachedShifts;

  // 1. Dashboard Stats
  Future<HrmDashboardStats> getDashboardStats() async {
    try {
      final response = await _dio.get('/hrm/v1/dashboard/overview');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        return HrmDashboardStats.fromJson(data);
      }
    } catch (_) {}

    return const HrmDashboardStats(
      totalEmployees: 52,
      activeEmployees: 49,
      workingToday: 45,
      onLeaveToday: 4,
      pendingRequests: 6,
      lateArrivals: 2,
    );
  }

  // 2. Get Requests (Đơn từ & Yêu cầu)
  Future<List<HrmRequestItem>> getRequests({String? status, HrmRequestType? type}) async {
    try {
      final response = await _dio.get('/hrm/v1/requests');
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data['data'] ?? response.data['items'] ?? response.data;
        if (raw is List) {
          _cachedRequests = raw.map((item) => HrmRequestItem.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    _cachedRequests ??= _getMockRequests();

    var result = List<HrmRequestItem>.from(_cachedRequests!);
    if (status != null && status != 'ALL') {
      result = result.where((r) => r.status.name.toUpperCase() == status.toUpperCase()).toList();
    }
    if (type != null) {
      result = result.where((r) => r.type == type).toList();
    }
    return result;
  }

  // 3. Create Request
  Future<HrmRequestItem> createRequest({
    required HrmRequestType type,
    required String title,
    required String reason,
    DateTime? startDate,
    DateTime? endDate,
    double? durationHours,
    double? amount,
    String? note,
  }) async {
    final payload = {
      'type': type.name.toUpperCase(),
      'title': title,
      'reason': reason,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'duration_hours': durationHours,
      'amount': amount,
      'note': note,
    };

    try {
      final response = await _dio.post(
        '/hrm/v1/requests',
        data: payload,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final newReq = HrmRequestItem.fromJson(response.data['data'] ?? response.data);
        _cachedRequests?.insert(0, newReq);
        return newReq;
      }
    } catch (_) {}

    final newReq = HrmRequestItem(
      id: 'req-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title.isNotEmpty ? title : 'Đơn ${type.name}',
      employeeId: 'emp-current',
      employeeName: 'Nguyễn Đăng Khoa (Bạn)',
      employeeCode: 'SVN-001',
      department: 'Khối Kỹ thuật & R&D',
      requestDate: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
      durationHours: durationHours,
      amount: amount,
      reason: reason,
      status: HrmRequestStatus.pending,
      note: note,
    );

    _cachedRequests ??= _getMockRequests();
    _cachedRequests!.insert(0, newReq);
    return newReq;
  }

  // 4. Approve Request
  Future<bool> approveRequest(String id, {String? note}) async {
    try {
      await _dio.post('/hrm/v1/requests/$id/approve', data: {'note': note});
    } catch (_) {}

    if (_cachedRequests != null) {
      final idx = _cachedRequests!.indexWhere((r) => r.id == id);
      if (idx != -1) {
        final cur = _cachedRequests![idx];
        _cachedRequests![idx] = HrmRequestItem(
          id: cur.id,
          type: cur.type,
          title: cur.title,
          employeeId: cur.employeeId,
          employeeName: cur.employeeName,
          employeeCode: cur.employeeCode,
          department: cur.department,
          requestDate: cur.requestDate,
          startDate: cur.startDate,
          endDate: cur.endDate,
          durationHours: cur.durationHours,
          amount: cur.amount,
          reason: cur.reason,
          status: HrmRequestStatus.approved,
          approverName: 'Ban Giám Đốc SAVINA',
          approvedAt: DateTime.now(),
          note: note ?? cur.note,
        );
      }
    }
    return true;
  }

  // 5. Reject Request
  Future<bool> rejectRequest(String id, {required String reason}) async {
    try {
      await _dio.post('/hrm/v1/requests/$id/reject', data: {'reason': reason});
    } catch (_) {}

    if (_cachedRequests != null) {
      final idx = _cachedRequests!.indexWhere((r) => r.id == id);
      if (idx != -1) {
        final cur = _cachedRequests![idx];
        _cachedRequests![idx] = HrmRequestItem(
          id: cur.id,
          type: cur.type,
          title: cur.title,
          employeeId: cur.employeeId,
          employeeName: cur.employeeName,
          employeeCode: cur.employeeCode,
          department: cur.department,
          requestDate: cur.requestDate,
          startDate: cur.startDate,
          endDate: cur.endDate,
          durationHours: cur.durationHours,
          amount: cur.amount,
          reason: cur.reason,
          status: HrmRequestStatus.rejected,
          approverName: 'Ban Giám Đốc SAVINA',
          rejectionReason: reason,
          note: cur.note,
        );
      }
    }
    return true;
  }

  // 6. Get Employees Directory (Nhân sự)
  Future<List<HrmEmployeeItem>> getEmployees({String? search, String? department}) async {
    if (_cachedEmployees == null) {
      try {
        final response = await _dio.get('/hrm/v1/employees');
        if (response.statusCode == 200 && response.data != null) {
          final list = (response.data['data'] ?? response.data) as List;
          _cachedEmployees = list.map((item) => HrmEmployeeItem.fromJson(item)).toList();
        }
      } catch (_) {}

      _cachedEmployees ??= _getMockEmployees();
    }

    var result = List<HrmEmployeeItem>.from(_cachedEmployees!);
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      result = result.where((e) =>
        e.fullName.toLowerCase().contains(q) ||
        e.code.toLowerCase().contains(q) ||
        e.email.toLowerCase().contains(q) ||
        e.position.toLowerCase().contains(q)
      ).toList();
    }
    if (department != null && department != 'ALL') {
      result = result.where((e) => e.department == department).toList();
    }
    return result;
  }

  // 7. Get Payslips (Phiếu lương)
  Future<List<HrmPayslipItem>> getPayslips() async {
    if (_cachedPayslips == null) {
      try {
        final response = await _dio.get('/hrm/v1/payroll/payslips');
        if (response.statusCode == 200 && response.data != null) {
          final list = (response.data['data'] ?? response.data) as List;
          _cachedPayslips = list.map((item) => HrmPayslipItem.fromJson(item)).toList();
        }
      } catch (_) {}

      _cachedPayslips ??= _getMockPayslips();
    }
    return _cachedPayslips!;
  }

  // 8. Get Shifts & Rosters (Ca làm việc)
  Future<List<HrmShift>> getShifts() async {
    if (_cachedShifts == null) {
      try {
        final response = await _dio.get('/hrm/v1/shifts');
        if (response.statusCode == 200 && response.data != null) {
          final list = (response.data['data'] ?? response.data) as List;
          _cachedShifts = list.map((item) => HrmShift.fromJson(item)).toList();
        }
      } catch (_) {}

      _cachedShifts ??= [
        HrmShift(
          id: 'shift-1',
          code: 'HC-01',
          name: 'Ca Hành chính (Chuẩn)',
          startTime: '08:00:00',
          endTime: '17:30:00',
          breakMinutes: 90,
          graceLateMinutes: 15,
          graceEarlyMinutes: 10,
        ),
        HrmShift(
          id: 'shift-2',
          code: 'S-01',
          name: 'Ca Sáng (Kỹ thuật trạm)',
          startTime: '06:00:00',
          endTime: '14:30:00',
          breakMinutes: 60,
          graceLateMinutes: 10,
          graceEarlyMinutes: 5,
        ),
        HrmShift(
          id: 'shift-3',
          code: 'C-01',
          name: 'Ca Chiều - Tối',
          startTime: '14:00:00',
          endTime: '22:30:00',
          breakMinutes: 60,
          graceLateMinutes: 10,
          graceEarlyMinutes: 5,
        ),
        HrmShift(
          id: 'shift-4',
          code: 'D-01',
          name: 'Ca Đêm (Trực bảo trì MBA)',
          startTime: '22:00:00',
          endTime: '06:30:00',
          breakMinutes: 60,
          graceLateMinutes: 10,
          graceEarlyMinutes: 5,
        ),
      ];
    }
    return _cachedShifts!;
  }

  // Mock data fallback
  List<HrmRequestItem> _getMockRequests() {
    final now = DateTime.now();
    return [
      HrmRequestItem(
        id: 'req-001',
        type: HrmRequestType.leave,
        title: 'Đơn xin nghỉ phép năm (Du lịch gia đình)',
        employeeId: 'emp-01',
        employeeName: 'Nguyễn Đăng Khoa',
        employeeCode: 'SVN-001',
        department: 'Khối Kỹ thuật & R&D',
        requestDate: now.subtract(const Duration(days: 1)),
        startDate: now.add(const Duration(days: 3)),
        endDate: now.add(const Duration(days: 5)),
        durationHours: 24,
        reason: 'Nghỉ phép thường niên kết hợp thăm người thân',
        status: HrmRequestStatus.pending,
      ),
      HrmRequestItem(
        id: 'req-002',
        type: HrmRequestType.overtime,
        title: 'Đăng ký làm thêm giờ (Thí nghiệm rơle lố 901)',
        employeeId: 'emp-02',
        employeeName: 'Trần Minh Hoàng',
        employeeCode: 'SVN-004',
        department: 'Phòng Thí nghiệm Điện',
        requestDate: now.subtract(const Duration(days: 2)),
        startDate: now.subtract(const Duration(days: 1)),
        durationHours: 3.5,
        reason: 'Hỗ trợ đóng điện xung kích trạm 110kV vượt tiến độ',
        status: HrmRequestStatus.approved,
        approverName: 'Trưởng phòng Kỹ thuật',
        approvedAt: now.subtract(const Duration(days: 1)),
      ),
      HrmRequestItem(
        id: 'req-003',
        type: HrmRequestType.advance,
        title: 'Đơn xin tạm ứng lương tháng 09/2026',
        employeeId: 'emp-03',
        employeeName: 'Lê Văn Hùng',
        employeeCode: 'SVN-012',
        department: 'Đội Thi công Cơ điện',
        requestDate: now.subtract(const Duration(days: 3)),
        amount: 5000000,
        reason: 'Chi phí sửa chữa phương tiện công tác đột xuất',
        status: HrmRequestStatus.approved,
        approverName: 'Giám đốc Tài chính',
        approvedAt: now.subtract(const Duration(days: 2)),
      ),
      HrmRequestItem(
        id: 'req-004',
        type: HrmRequestType.shiftChange,
        title: 'Đổi ca trực đêm sang ca sáng',
        employeeId: 'emp-04',
        employeeName: 'Phạm Quỳnh Anh',
        employeeCode: 'SVN-019',
        department: 'Trung tâm Điều độ SCADA',
        requestDate: now.subtract(const Duration(days: 4)),
        startDate: now.add(const Duration(days: 1)),
        reason: 'Đổi ca với kỹ sư Nguyễn Hoàng Nam do trùng lịch đào tạo an toàn',
        status: HrmRequestStatus.pending,
      ),
      HrmRequestItem(
        id: 'req-005',
        type: HrmRequestType.businessTrip,
        title: 'Công tác kiểm định nhà máy điện mặt trời Ninh Thuận',
        employeeId: 'emp-01',
        employeeName: 'Nguyễn Đăng Khoa',
        employeeCode: 'SVN-001',
        department: 'Khối Kỹ thuật & R&D',
        requestDate: now.subtract(const Duration(days: 7)),
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.subtract(const Duration(days: 3)),
        durationHours: 24,
        amount: 8500000,
        reason: 'Nghiệm thu hệ thống đo đếm và bảo vệ rơle số hóa',
        status: HrmRequestStatus.approved,
        approverName: 'Tổng Giám Đốc',
        approvedAt: now.subtract(const Duration(days: 6)),
      ),
    ];
  }

  List<HrmEmployeeItem> _getMockEmployees() {
    return [
      const HrmEmployeeItem(
        id: 'emp-001',
        code: 'SVN-001',
        fullName: 'Nguyễn Đăng Khoa',
        email: 'khoa.nd@savina.vn',
        phone: '0909 123 456',
        department: 'Khối Kỹ thuật & R&D',
        position: 'Trưởng nhóm Phát triển Hệ thống',
        status: 'ACTIVE',
        baseSalary: 28000000,
      ),
      const HrmEmployeeItem(
        id: 'emp-002',
        code: 'SVN-002',
        fullName: 'Nguyễn Tấn Tài',
        email: 'tai.nt@savina.vn',
        phone: '0912 345 678',
        department: 'Khối Kỹ thuật & R&D',
        position: 'Kiến trúc sư Phần mềm Lead',
        status: 'ACTIVE',
        baseSalary: 32000000,
      ),
      const HrmEmployeeItem(
        id: 'emp-003',
        code: 'SVN-003',
        fullName: 'Lê Hoàng Hải',
        email: 'hai.lh@savina.vn',
        phone: '0988 765 432',
        department: 'Khối Kỹ thuật & R&D',
        position: 'Kỹ sư Cấp cao Full-stack',
        status: 'ACTIVE',
        baseSalary: 26000000,
      ),
      const HrmEmployeeItem(
        id: 'emp-004',
        code: 'SVN-004',
        fullName: 'Trần Minh Hoàng',
        email: 'hoang.tm@savina.vn',
        phone: '0933 555 888',
        department: 'Phòng Thí nghiệm Điện',
        position: 'Chuyên gia Đo lường & Thí nghiệm',
        status: 'ACTIVE',
        baseSalary: 22000000,
      ),
      const HrmEmployeeItem(
        id: 'emp-005',
        code: 'SVN-005',
        fullName: 'Võ Thị Mai Lan',
        email: 'lan.vtm@savina.vn',
        phone: '0903 111 222',
        department: 'Phòng Nhân sự & Hành chính',
        position: 'Trưởng phòng Nhân sự (HRM)',
        status: 'ACTIVE',
        baseSalary: 24000000,
      ),
      const HrmEmployeeItem(
        id: 'emp-006',
        code: 'SVN-006',
        fullName: 'Đỗ Quốc Bảo',
        email: 'bao.dq@savina.vn',
        phone: '0977 888 999',
        department: 'Phòng Tài chính Kế toán',
        position: 'Kế toán Trưởng',
        status: 'ACTIVE',
        baseSalary: 25000000,
      ),
    ];
  }

  List<HrmPayslipItem> _getMockPayslips() {
    return [
      HrmPayslipItem(
        id: 'ps-092026',
        period: 'Tháng 09/2026',
        baseSalary: 28000000,
        allowances: 3500000,
        overtimePay: 2100000,
        bonuses: 3000000,
        deductions: 3850000,
        netSalary: 32750000,
        status: 'PENDING',
      ),
      HrmPayslipItem(
        id: 'ps-082026',
        period: 'Tháng 08/2026',
        baseSalary: 28000000,
        allowances: 3500000,
        overtimePay: 1800000,
        bonuses: 2000000,
        deductions: 3650000,
        netSalary: 31650000,
        status: 'PAID',
        paidDate: DateTime(2026, 9, 5),
      ),
      HrmPayslipItem(
        id: 'ps-072026',
        period: 'Tháng 07/2026',
        baseSalary: 28000000,
        allowances: 3500000,
        overtimePay: 900000,
        bonuses: 2000000,
        deductions: 3450000,
        netSalary: 30950000,
        status: 'PAID',
        paidDate: DateTime(2026, 8, 5),
      ),
    ];
  }

  // 9. Get Dependents (Người phụ thuộc)
  Future<List<HrmDependentItem>> getDependents() async {
    return [
      HrmDependentItem(
        id: 'dep-001',
        employeeId: 'emp-001',
        employeeName: 'Nguyễn Đăng Khoa',
        fullName: 'Nguyễn Gia Bảo',
        relationship: 'Con ruột',
        dateOfBirth: DateTime(2020, 5, 12),
        idNumber: '079200012345',
        taxCode: '8594029101',
        status: 'VERIFIED',
        startDate: DateTime(2020, 6, 1),
      ),
      HrmDependentItem(
        id: 'dep-002',
        employeeId: 'emp-001',
        employeeName: 'Nguyễn Đăng Khoa',
        fullName: 'Trần Thị Mai',
        relationship: 'Vợ/Chồng',
        dateOfBirth: DateTime(1992, 11, 20),
        idNumber: '079192009876',
        taxCode: '8594029102',
        status: 'VERIFIED',
        startDate: DateTime(2022, 1, 1),
      ),
      HrmDependentItem(
        id: 'dep-003',
        employeeId: 'emp-002',
        employeeName: 'Trần Văn Minh',
        fullName: 'Trần Minh Khang',
        relationship: 'Con ruột',
        dateOfBirth: DateTime(2023, 8, 15),
        idNumber: '079203004321',
        taxCode: '8594029103',
        status: 'PENDING',
        startDate: DateTime(2023, 9, 1),
      ),
    ];
  }

  // 10. Get Salary Advances (Ứng và thu hồi lương)
  Future<List<HrmSalaryAdvanceItem>> getSalaryAdvances() async {
    return [
      HrmSalaryAdvanceItem(
        id: 'adv-001',
        employeeId: 'emp-002',
        employeeName: 'Trần Văn Minh',
        amount: 5000000,
        reason: 'Tạm ứng chi phí cá nhân khẩn cấp',
        requestDate: DateTime(2026, 9, 20),
        status: 'RECOVERING',
        repaymentPeriod: '10/2026 - 11/2026',
        repaidAmount: 2500000,
        monthlyDeduction: 2500000,
      ),
      HrmSalaryAdvanceItem(
        id: 'adv-002',
        employeeId: 'emp-003',
        employeeName: 'Lê Thị Thu Thảo',
        amount: 3000000,
        reason: 'Chi phí khám chữa bệnh gia đình',
        requestDate: DateTime(2026, 10, 1),
        status: 'PENDING',
        repaymentPeriod: '10/2026',
        repaidAmount: 0,
        monthlyDeduction: 3000000,
      ),
      HrmSalaryAdvanceItem(
        id: 'adv-003',
        employeeId: 'emp-004',
        employeeName: 'Phạm Đức Long',
        amount: 10000000,
        reason: 'Mua sắm thiết bị làm việc cá nhân',
        requestDate: DateTime(2026, 7, 15),
        status: 'COMPLETED',
        repaymentPeriod: '08/2026 - 09/2026',
        repaidAmount: 10000000,
        monthlyDeduction: 5000000,
      ),
    ];
  }

  // 11. Get Timesheet Summary (Bảng công tổng hợp)
  Future<List<HrmTimesheetSummaryItem>> getTimesheetSummaries() async {
    return [
      const HrmTimesheetSummaryItem(
        employeeId: 'emp-001',
        employeeName: 'Nguyễn Tấn Tài (Bạn)',
        employeeCode: 'SVN-001',
        department: 'Khối Điều hành & Kỹ thuật',
        standardWorkdays: 22,
        actualWorkdays: 22,
        paidLeaveDays: 0,
        overtimeHours: 6.5,
        lateCount: 0,
        missingPunchCount: 0,
        status: 'VALID',
      ),
      const HrmTimesheetSummaryItem(
        employeeId: 'emp-002',
        employeeName: 'Trần Văn Minh',
        employeeCode: 'SVN-002',
        department: 'Phòng Kỹ thuật & R&D',
        standardWorkdays: 22,
        actualWorkdays: 21,
        paidLeaveDays: 1,
        overtimeHours: 12.0,
        lateCount: 1,
        missingPunchCount: 0,
        status: 'VALID',
      ),
      const HrmTimesheetSummaryItem(
        employeeId: 'emp-003',
        employeeName: 'Lê Thị Thu Thảo',
        employeeCode: 'SVN-003',
        department: 'Phòng Nhân sự & Tổng hợp',
        standardWorkdays: 22,
        actualWorkdays: 22,
        paidLeaveDays: 0,
        overtimeHours: 4.0,
        lateCount: 0,
        missingPunchCount: 0,
        status: 'VALID',
      ),
      const HrmTimesheetSummaryItem(
        employeeId: 'emp-004',
        employeeName: 'Phạm Đức Long',
        employeeCode: 'SVN-004',
        department: 'Phòng Dự án & Khảo sát',
        standardWorkdays: 22,
        actualWorkdays: 20.5,
        paidLeaveDays: 1,
        overtimeHours: 8.0,
        lateCount: 2,
        missingPunchCount: 1,
        status: 'NEEDS_REVIEW',
      ),
      const HrmTimesheetSummaryItem(
        employeeId: 'emp-005',
        employeeName: 'Võ Hoàng Nam',
        employeeCode: 'SVN-005',
        department: 'Phòng Tài chính - Kế toán',
        standardWorkdays: 22,
        actualWorkdays: 22,
        paidLeaveDays: 0,
        overtimeHours: 0,
        lateCount: 0,
        missingPunchCount: 0,
        status: 'VALID',
      ),
      const HrmTimesheetSummaryItem(
        employeeId: 'emp-006',
        employeeName: 'Đặng Thanh Tùng',
        employeeCode: 'SVN-006',
        department: 'Phòng Vận hành & Bảo trì',
        standardWorkdays: 22,
        actualWorkdays: 21.5,
        paidLeaveDays: 0.5,
        overtimeHours: 15.0,
        lateCount: 0,
        missingPunchCount: 0,
        status: 'VALID',
      ),
    ];
  }

  // 12. Get Policy Config (Chính sách & Cấu hình)
  Future<HrmPolicyConfig> getPolicyConfig() async {
    return const HrmPolicyConfig();
  }

  // 13. Get Integration Devices (Hệ thống & Tích hợp)
  Future<List<HrmIntegrationDevice>> getIntegrationDevices() async {
    return [
      HrmIntegrationDevice(
        id: 'dev-01',
        name: 'Máy chấm công FaceID Cửa chính',
        type: 'FaceID Biometric Terminal',
        ipAddress: '192.168.1.201',
        location: 'Trụ sở SAVINA - Tầng 1',
        status: 'ONLINE',
        lastSync: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      HrmIntegrationDevice(
        id: 'dev-02',
        name: 'Máy chấm công Vân tay Cửa sau',
        type: 'Optical Fingerprint Scanner',
        ipAddress: '192.168.1.202',
        location: 'Trụ sở SAVINA - Tầng 2',
        status: 'ONLINE',
        lastSync: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      HrmIntegrationDevice(
        id: 'dev-03',
        name: 'Máy chấm công Xưởng cơ điện',
        type: 'Outdoor Rugged Biometric',
        ipAddress: '192.168.2.50',
        location: 'Kho trung tâm & Xưởng bảo trì',
        status: 'OFFLINE',
        lastSync: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];
  }
}

