import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hrm_models.dart';
import '../models/hrm_attendance_models.dart';
import '../models/hrm_attendance_monitor_models.dart';
import '../models/hrm_work_schedule_models.dart';
import '../models/hrm_personnel_decision_model.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';
import '../core/i18n/app_i18n.dart';

part 'hrm_service_time_settings.dart';
part 'hrm_service_leaves.dart';
part 'hrm_service_work_schedule.dart';

class PolicyActionResult {
  final bool isSuccess;
  final String message;
  final int? statusCode;

  const PolicyActionResult({
    required this.isSuccess,
    required this.message,
    this.statusCode,
  });
}

/// Helper function to format GPS coordinates cleanly (stripping trailing zeros)
String formatCoordinate(dynamic val) => HrmService.formatCoordinate(val);

class HrmService {
  static final HrmService _instance = HrmService._internal();
  factory HrmService() => _instance;

  static String formatCoordinate(dynamic val) {
    if (val == null) return '0';
    final n = (val is num) ? val.toDouble() : double.tryParse(val.toString());
    if (n == null) return val.toString();
    if (n % 1 == 0) {
      return n.toInt().toString();
    }
    return n.toString().replaceAll(RegExp(r'\.?0+$'), '');
  }

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
  Map<String, dynamic>? _cachedTimeSettings;
  DateTime? _lastTimeSettingsFetch;
  Future<Map<String, dynamic>?>? _pendingTimeSettingsFuture;

  // Single source of truth for all HRM Time Settings (Policy Versions, Sites, Calendar, Holidays)
  Future<Map<String, dynamic>?> getTimeSettings({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedTimeSettings != null &&
        _lastTimeSettingsFetch != null &&
        DateTime.now().difference(_lastTimeSettingsFetch!).inSeconds < 15) {
      return _cachedTimeSettings;
    }

    if (_pendingTimeSettingsFuture != null) {
      return _pendingTimeSettingsFuture!;
    }

    final future = () async {
      try {
        final res = await _dio.get(
          '/api/hrm/v1/time-settings',
          options: Options(validateStatus: (status) => status != null && status < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = (res.data is Map) ? (res.data['data'] ?? res.data) : res.data;
          if (data is Map<String, dynamic>) {
            _cachedTimeSettings = data;
            _lastTimeSettingsFetch = DateTime.now();
            return data;
          }
        }
      } catch (e) {
        debugPrint('[HrmService] getTimeSettings error: $e');
      }
      return _cachedTimeSettings;
    }();

    _pendingTimeSettingsFuture = future;
    try {
      return await future;
    } finally {
      _pendingTimeSettingsFuture = null;
    }
  }

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

  // 2. Get Requests (ÄÆ¡n tá»« cáº§n xá»­ lÃ½ & YÃªu cáº§u)
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

    // Fetch direct approvers to enrich pending requests
    try {
      final approvers = await getDirectApprovers();
      if (approvers.isNotEmpty) {
        for (var i = 0; i < all.length; i++) {
          final req = all[i];
          if (req.status == HrmRequestStatus.pending && (req.currentAssigneeName == null || req.currentAssigneeName!.isEmpty)) {
            final name = approvers[req.id];
            if (name != null && name.isNotEmpty) {
              all[i] = req.copyWith(currentAssigneeName: name);
            }
          }
        }
      }
    } catch (_) {}

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
    throw Exception('svc_hrm.request_create_failed'.tr(args: {'code': response.statusCode}));
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

  // 5. Reject Request (Äá»“ng bá»™ React: cho phÃ©p bá» trá»‘ng lÃ½ do tá»« chá»‘i)
  Future<bool> rejectRequest(String id, {String? reason}) async {
    final endpoints = [
      '/hrm/v1/leave-requests/$id/reject',
      '/hrm/v1/ot-requests/$id/reject',
      '/hrm/v1/attendance-corrections/$id/reject',
      '/hrm/v1/business-trip-requests/$id/reject',
      '/hrm/v1/shift-change-requests/$id/reject',
      '/hrm/v1/salary-advance-requests/$id/reject',
      '/hrm/v1/requests/$id/reject',
    ];
    final payload = (reason != null && reason.trim().isNotEmpty) ? {'reason': reason.trim()} : <String, dynamic>{};
    for (final ep in endpoints) {
      try {
        final res = await _dio.post(ep, data: payload);
        if (res.statusCode == 200 || res.statusCode == 201) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  List<HrmPositionItem>? _cachedPositions;

  // 6. Get Employees Directory (NhÃ¢n sá»±)
  Future<List<HrmEmployeeItem>> getEmployees({String? search, String? department, bool forceRefresh = false}) async {
    if (_cachedEmployees == null || forceRefresh) {
      final endpoints = [
        '/api/hrm/v1/employees',
        '/hrm/v1/employees',
      ];
      for (final ep in endpoints) {
        try {
          final response = await _dio.get(
            ep,
            queryParameters: {'page_size': 100},
          );
          if (response.statusCode == 200 && response.data != null) {
            final list = (response.data['data'] ?? response.data) as List;
            _cachedEmployees = list.map((item) => HrmEmployeeItem.fromJson(item)).toList();
            if (_cachedEmployees!.isNotEmpty) break;
          }
        } catch (_) {}
      }

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

  // 6.5 Get Positions & JD (Chá»©c danh & TiÃªu chuáº©n chá»©c danh)
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

  List<HrmPersonnelDecision>? _cachedPersonnelDecisions;

  // 6.6 Get Personnel Decisions (Quyáº¿t Ä‘á»‹nh nhÃ¢n sá»± - 1:1 Web)
  Future<List<HrmPersonnelDecision>> getPersonnelDecisions({
    String? status,
    String? type,
    String? employeeId,
    bool forceRefresh = false,
  }) async {
    if (_cachedPersonnelDecisions == null || forceRefresh) {
      try {
        final queryParams = <String, dynamic>{};
        if (status != null && status.isNotEmpty && status != 'ALL') queryParams['status'] = status;
        if (type != null && type.isNotEmpty && type != 'ALL') queryParams['type'] = type;
        if (employeeId != null && employeeId.isNotEmpty) queryParams['employeeId'] = employeeId;

        final response = await _dio.get('/hrm/v1/personnel-decisions', queryParameters: queryParams);
        if (response.statusCode == 200 && response.data != null) {
          final list = (response.data['data'] ?? response.data) as List;
          _cachedPersonnelDecisions = list.map((item) => HrmPersonnelDecision.fromJson(item as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('[HrmService] getPersonnelDecisions error: $e');
      }

      _cachedPersonnelDecisions ??= [];
    }
    return _cachedPersonnelDecisions!;
  }

  Future<HrmPersonnelDecision> createPersonnelDecision(Map<String, dynamic> payload) async {
    final res = await _dio.post('/hrm/v1/personnel-decisions', data: payload);
    final data = res.data['data'] ?? res.data;
    final item = HrmPersonnelDecision.fromJson(data as Map<String, dynamic>);
    _cachedPersonnelDecisions?.insert(0, item);
    return item;
  }

  Future<HrmPersonnelDecision> updatePersonnelDecision(String id, Map<String, dynamic> payload) async {
    final res = await _dio.patch('/hrm/v1/personnel-decisions/$id', data: payload);
    final data = res.data['data'] ?? res.data;
    final item = HrmPersonnelDecision.fromJson(data as Map<String, dynamic>);
    if (_cachedPersonnelDecisions != null) {
      final idx = _cachedPersonnelDecisions!.indexWhere((d) => d.id == id);
      if (idx != -1) _cachedPersonnelDecisions![idx] = item;
    }
    return item;
  }

  Future<void> approvePersonnelDecision(String id) async {
    await _dio.post('/hrm/v1/personnel-decisions/$id/approve');
    await getPersonnelDecisions(forceRefresh: true);
  }

  Future<void> rejectPersonnelDecision(String id, String reason) async {
    await _dio.post('/hrm/v1/personnel-decisions/$id/reject', data: {'reason': reason});
    await getPersonnelDecisions(forceRefresh: true);
  }

  Future<void> cancelPersonnelDecision(String id) async {
    await _dio.post('/hrm/v1/personnel-decisions/$id/cancel');
    await getPersonnelDecisions(forceRefresh: true);
  }

  Future<void> retryApplyPersonnelDecision(String id) async {
    await _dio.post('/hrm/v1/personnel-decisions/$id/retry-apply');
    await getPersonnelDecisions(forceRefresh: true);
  }

  // 6.7 Salary Grades & Steps (1:1 Web)
  Future<List<HrmSalaryGrade>> getSalaryGrades() async {
    try {
      final res = await _dio.get('/hrm/v1/salary-grades');
      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data['data'] ?? res.data) as List;
        return list.map((e) => HrmSalaryGrade.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[HrmService] getSalaryGrades error: $e');
    }
    return const [];
  }

  Future<List<HrmSalaryGradeStep>> getSalaryGradeSteps(String gradeId) async {
    try {
      final res = await _dio.get('/hrm/v1/salary-grades/$gradeId/steps');
      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data['data'] ?? res.data) as List;
        return list.map((e) => HrmSalaryGradeStep.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[HrmService] getSalaryGradeSteps error: $e');
    }
    return [
      HrmSalaryGradeStep(id: '$gradeId-step-1', salaryGradeId: gradeId, stepNo: 1, baseSalary: 10000000),
      HrmSalaryGradeStep(id: '$gradeId-step-2', salaryGradeId: gradeId, stepNo: 2, baseSalary: 12500000),
      HrmSalaryGradeStep(id: '$gradeId-step-3', salaryGradeId: gradeId, stepNo: 3, baseSalary: 15000000),
      HrmSalaryGradeStep(id: '$gradeId-step-4', salaryGradeId: gradeId, stepNo: 4, baseSalary: 18000000),
      HrmSalaryGradeStep(id: '$gradeId-step-5', salaryGradeId: gradeId, stepNo: 5, baseSalary: 22000000),
    ];
  }

  Future<Map<String, dynamic>?> getAppointmentContext(String employeeId) async {
    try {
      final res = await _dio.get('/hrm/v1/employees/$employeeId/appointment-context');
      if (res.statusCode == 200 && res.data != null) {
        return (res.data['data'] ?? res.data) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[HrmService] getAppointmentContext error: $e');
    }
    return null;
  }


  // 7. Get Payslips (Phiáº¿u lÆ°Æ¡ng)
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

  // 8. Get Shifts & Rosters (Ca lÃ m viá»‡c)
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

  /// Standard-workday policies (GET /hrm/v1/timesheet-standards). Returns null when the call fails.
  Future<({List<Map<String, dynamic>> policies, String? currentId})?> getTimesheetStandards() async {
    try {
      final response = await _dio.get('/hrm/v1/timesheet-standards');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        if (data is Map<String, dynamic>) {
          final list = (data['policies'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? <Map<String, dynamic>>[];
          return (policies: list, currentId: data['currentId']?.toString());
        }
      }
    } catch (e) {
      debugPrint('[HrmService] getTimesheetStandards error: $e');
    }
    return null;
  }

  // 9. Get Dependents (NgÆ°á»i phá»¥ thuá»™c)
  Future<List<HrmDependentItem>> getDependents() async {
    return [];
  }

  // 10. Get Salary Advances (á»¨ng vÃ  thu há»“i lÆ°Æ¡ng)
  Future<List<HrmSalaryAdvanceItem>> getSalaryAdvances() async {
    return [];
  }

  // 11. Get Timesheet Summary (Báº£ng cÃ´ng tá»•ng há»£p)
  Future<List<HrmTimesheetSummaryItem>> getTimesheetSummaries() async {
    return [];
  }

  // 12. Direct Approvers (Người duyệt trực tiếp theo luồng đơn)
  Future<Map<String, String>> getDirectApprovers() async {
    final Map<String, String> map = {};
    try {
      final endpoints = [
        '/hrm/v1/request-direct-approvers',
        '/api/hrm/v1/request-direct-approvers',
        '/request-direct-approvers',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _dio.get(ep);
          if (res.statusCode == 200 && res.data != null) {
            final list = res.data['data'] ?? (res.data is List ? res.data : null);
            if (list is List) {
              for (final item in list) {
                if (item is Map) {
                  final reqId = item['requestId']?.toString() ?? '';
                  final name = item['assigneeName']?.toString() ?? '';
                  if (reqId.isNotEmpty && name.isNotEmpty) {
                    map[reqId] = name;
                  }
                }
              }
              if (map.isNotEmpty) break;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return map;
  }

  // 13. Employee Asset Custody (Vật tư & Tài sản cấp phát)
  Future<List<Map<String, dynamic>>> getEmployeeCustody(String employeeId) async {
    try {
      final res = await _dio.get('/hrm/v1/employees/' + Uri.encodeComponent(employeeId) + '/custody');
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['data'] ?? (res.data is List ? res.data : null);
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<bool> assignEmployeeCustody(String employeeId, String materialCode) async {
    try {
      final res = await _dio.post(
        '/hrm/v1/employees/' + Uri.encodeComponent(employeeId) + '/custody',
        data: {'materialCode': materialCode},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> revokeEmployeeCustody(String employeeId, String materialCode) async {
    try {
      final res = await _dio.post(
        '/hrm/v1/employees/' + Uri.encodeComponent(employeeId) + '/custody/' + Uri.encodeComponent(materialCode) + '/revoke',
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAssignableCustodyAssets() async {
    try {
      final res = await _dio.get('/hrm/v1/custody/assignable');
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['data'] ?? (res.data is List ? res.data : null);
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
