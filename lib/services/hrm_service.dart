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

    _cachedRequests ??= [];

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

    final response = await _dio.post(
      '/hrm/v1/requests',
      data: payload,
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final newReq = HrmRequestItem.fromJson(response.data['data'] ?? response.data);
      _cachedRequests ??= [];
      _cachedRequests!.insert(0, newReq);
      return newReq;
    }
    throw Exception('Không thể tạo đơn yêu cầu (Mã: ${response.statusCode})');
  }

  // 4. Approve Request
  Future<bool> approveRequest(String id, {String? note}) async {
    try {
      final res = await _dio.post('/hrm/v1/requests/$id/approve', data: {'note': note});
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // 5. Reject Request
  Future<bool> rejectRequest(String id, {required String reason}) async {
    try {
      final res = await _dio.post('/hrm/v1/requests/$id/reject', data: {'reason': reason});
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
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

      _cachedEmployees ??= [];
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

      _cachedPayslips ??= [];
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

      _cachedShifts ??= [];
    }
    return _cachedShifts!;
  }

  // 9. Get Dependents (Người phụ thuộc)
  Future<List<HrmDependentItem>> getDependents() async {
    return [];
  }

  // 10. Get Salary Advances (Ứng và thu hồi lương)
  Future<List<HrmSalaryAdvanceItem>> getSalaryAdvances() async {
    return [];
  }

  // 11. Get Timesheet Summary (Bảng công tổng hợp)
  Future<List<HrmTimesheetSummaryItem>> getTimesheetSummaries() async {
    return [];
  }

  // 12. Get Policy Config (Chính sách & Cấu hình)
  Future<HrmPolicyConfig> getPolicyConfig() async {
    return const HrmPolicyConfig();
  }

  // 13. Get Integration Devices (Hệ thống & Tích hợp)
  Future<List<HrmIntegrationDevice>> getIntegrationDevices() async {
    return [];
  }
}

