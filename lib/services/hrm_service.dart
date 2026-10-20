import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/hrm_models.dart';
import '../models/hrm_attendance_models.dart';
import '../models/hrm_attendance_monitor_models.dart';
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
      totalEmployees: 0,
      activeEmployees: 0,
      workingToday: 0,
      onLeaveToday: 0,
      pendingRequests: 0,
      lateArrivals: 0,
    );
  }

  // 2. Get Requests (Đơn từ cần xử lý & Yêu cầu)
  Future<List<HrmRequestItem>> getRequests({String? status, HrmRequestType? type, bool forceRefresh = false}) async {
    final List<HrmRequestItem> all = [];

    // Ensure employees are cached so we can map employeeId -> Name / Code / Dept
    final Map<String, HrmEmployeeItem> empMap = {};
    try {
      final emps = await getEmployees();
      for (final e in emps) {
        empMap[e.id] = e;
      }
    } catch (_) {}

    // Fallback for special users if not in employee directory
    empMap['e1e0cc28-0c3c-416d-a1f9-557031cc564a'] ??= const HrmEmployeeItem(
      id: 'e1e0cc28-0c3c-416d-a1f9-557031cc564a',
      code: 'NV051',
      fullName: 'admin',
      email: 'admin@savinajsc.com',
      phone: '',
      department: 'Khối Văn phòng',
      position: 'Quản trị viên',
      status: 'OFFICIAL',
    );

    final endpoints = [
      {'path': '/hrm/v1/leave-requests', 'type': HrmRequestType.leave},
      {'path': '/hrm/v1/ot-requests', 'type': HrmRequestType.overtime},
      {'path': '/hrm/v1/attendance-corrections', 'type': HrmRequestType.attendanceCorrection},
      {'path': '/hrm/v1/business-trip-requests', 'type': HrmRequestType.businessTrip},
      {'path': '/hrm/v1/shift-change-requests', 'type': HrmRequestType.shiftChange},
      {'path': '/hrm/v1/salary-advance-requests', 'type': HrmRequestType.advance},
      {'path': '/hrm/v1/requests', 'type': null},
    ];

    for (final ep in endpoints) {
      try {
        final path = ep['path'] as String;
        final res = await _dio.get(path);
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data['items'] ?? res.data;
          if (raw is List) {
            for (final item in raw) {
              if (item is Map<String, dynamic>) {
                final id = item['id']?.toString() ?? '';
                if (id.isNotEmpty && !all.any((r) => r.id == id)) {
                  final empId = item['employeeId']?.toString() ?? item['employee_id']?.toString() ?? '';
                  final emp = empMap[empId];
                  all.add(HrmRequestItem.fromJson(
                    item,
                    forcedType: ep['type'] as HrmRequestType?,
                    employeeNameFallback: emp?.fullName,
                    employeeCodeFallback: emp?.code,
                    departmentFallback: emp?.department,
                  ));
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    if (all.isNotEmpty) {
      _cachedRequests = all;
    } else {
      _cachedRequests ??= [];
    }

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
    final endpoints = [
      '/hrm/v1/leave-requests/$id/approve',
      '/hrm/v1/ot-requests/$id/approve',
      '/hrm/v1/attendance-corrections/$id/approve',
      '/hrm/v1/business-trip-requests/$id/approve',
      '/hrm/v1/shift-change-requests/$id/approve',
      '/hrm/v1/salary-advance-requests/$id/approve',
      '/hrm/v1/requests/$id/approve',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.post(ep, data: {'note': note ?? ''});
        if (res.statusCode == 200 || res.statusCode == 201) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  // 5. Reject Request
  Future<bool> rejectRequest(String id, {required String reason}) async {
    final endpoints = [
      '/hrm/v1/leave-requests/$id/reject',
      '/hrm/v1/ot-requests/$id/reject',
      '/hrm/v1/attendance-corrections/$id/reject',
      '/hrm/v1/business-trip-requests/$id/reject',
      '/hrm/v1/shift-change-requests/$id/reject',
      '/hrm/v1/salary-advance-requests/$id/reject',
      '/hrm/v1/requests/$id/reject',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.post(ep, data: {'reason': reason});
        if (res.statusCode == 200 || res.statusCode == 201) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  List<HrmPositionItem>? _cachedPositions;

  // 6. Get Employees Directory (Nhân sự)
  Future<List<HrmEmployeeItem>> getEmployees({String? search, String? department, bool forceRefresh = false}) async {
    if (_cachedEmployees == null || forceRefresh) {
      try {
        final response = await _dio.get(
          '/hrm/v1/employees',
          queryParameters: {'page_size': 100},
        );
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

  // 6.5 Get Positions & JD (Chức danh & Tiêu chuẩn chức danh)
  Future<List<HrmPositionItem>> getPositions({bool forceRefresh = false}) async {
    if (_cachedPositions == null || forceRefresh) {
      try {
        final response = await _dio.get('/hrm/v1/positions');
        if (response.statusCode == 200 && response.data != null) {
          final list = (response.data['data'] ?? response.data) as List;
          _cachedPositions = list.map((item) => HrmPositionItem.fromJson(item)).toList();
        }
      } catch (_) {}

      _cachedPositions ??= [];
    }
    return _cachedPositions!;
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

  // 14. Get Request Comments (Trao đổi và ý kiến)
  Future<List<HrmRequestComment>> getRequestComments({
    required String kind,
    required String requestId,
  }) async {
    try {
      debugPrint('[HrmService] getRequestComments -> kind=$kind requestId=$requestId');
      final response = await _dio.get(
        '/hrm/v1/request-comments',
        queryParameters: {'kind': kind, 'requestId': requestId},
      );
      debugPrint('[HrmService] getRequestComments status=${response.statusCode} data=${response.data}');
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data['data'] ?? response.data;
        if (raw is List) {
          final list = raw.map((item) => HrmRequestComment.fromJson(item as Map<String, dynamic>)).toList();
          debugPrint('[HrmService] getRequestComments parsed ${list.length} comments');
          return list;
        }
      }
    } catch (e, stack) {
      debugPrint('[HrmService] getRequestComments ERROR: $e\n$stack');
    }
    return [];
  }

  // 15. Post Request Comment (Gửi trao đổi hoặc ghi nhận ý kiến quyết định)
  Future<bool> postRequestComment({
    required String kind,
    required String requestId,
    required String body,
    List<String>? mentionUserIds,
    String? commentKind,
    String? decision,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'kind': kind,
        'requestId': requestId,
        'body': body,
      };
      if (mentionUserIds != null) payload['mentionUserIds'] = mentionUserIds;
      if (commentKind != null) payload['commentKind'] = commentKind;
      if (decision != null) payload['decision'] = decision;
      debugPrint('[HrmService] postRequestComment payload=$payload');
      final response = await _dio.post(
        '/hrm/v1/request-comments',
        data: payload,
      );
      debugPrint('[HrmService] postRequestComment status=${response.statusCode} data=${response.data}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e, stack) {
      debugPrint('[HrmService] postRequestComment ERROR: $e\n$stack');
      return false;
    }
  }

  // 16. Search Mention Candidates (Tìm danh sách @ nhắc tên)
  Future<List<HrmMentionCandidate>> searchMentionCandidates({String query = ''}) async {
    try {
      debugPrint('[HrmService] searchMentionCandidates q=$query');
      final response = await _dio.get(
        '/hrm/v1/request-comments/mention-candidates',
        queryParameters: {'q': query},
      );
      debugPrint('[HrmService] searchMentionCandidates status=${response.statusCode} data=${response.data}');
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data['data'] ?? response.data;
        if (raw is List) {
          return raw.map((item) => HrmMentionCandidate.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e, stack) {
      debugPrint('[HrmService] searchMentionCandidates ERROR: $e\n$stack');
    }
    return [];
  }

  // 17. Attendance Monitor (Giám sát chấm công theo ngày)
  Future<HrmAttendanceMonitor?> getAttendanceMonitor({String? date}) async {
    try {
      final Map<String, dynamic> params = {};
      if (date != null && date.isNotEmpty) {
        params['date'] = date;
      }
      final response = await _dio.get(
        '/hrm/v1/attendance-monitor',
        queryParameters: params,
      );
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data['data'] ?? response.data;
        if (raw is Map<String, dynamic>) {
          return HrmAttendanceMonitor.fromJson(raw);
        }
      }
    } catch (e, stack) {
      debugPrint('[HrmService] getAttendanceMonitor ERROR: $e\n$stack');
    }
    return null;
  }
}

