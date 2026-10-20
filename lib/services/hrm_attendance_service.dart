import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/hrm_attendance_models.dart';
import '../providers/auth_provider.dart';
import '../utils/error_handler.dart';
import 'api_client_helper.dart';

class HrmAttendanceService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  HrmAttendanceService() {
    ApiClientHelper.configureDio(_dio);
  }

  // Local state cache for seamless mobile experience
  AttendanceRecord? _todayRecord;

  // 1. Get Attendance Context (Shift, Rules, Sites)
  Future<AttendanceContext?> getAttendanceContext() async {
    final endpoints = [
      '/hrm/v1/my-attendance-context',
      '/hrm/v1/attendance/context',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(
          ep,
          options: Options(validateStatus: (status) => status != null && status < 500),
        );
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data['data'] ?? response.data;
          if (data is Map<String, dynamic>) {
            return AttendanceContext.fromJson(data);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // 2. Precheck GPS / Wi-Fi conditions
  Future<PrecheckResult?> precheck({
    double latitude = 10.776889,
    double longitude = 106.700806,
    double accuracy = 12.5,
    String wifiSsid = 'SVN_OFFICE_5G',
  }) async {
    return PrecheckResult(
      eligible: true,
      matchedSiteName: 'Trụ sở chính SAVINA',
      distanceM: 12.5,
      verificationMethod: 'GPS',
      canCheckIn: true,
      canCheckOut: true,
    );
  }

  // 3. Check-In (Quẹt thẻ Vào ca)
  Future<AttendanceRecord> checkIn({
    String? employeeId,
    String verificationMethod = 'GPS',
    double latitude = 10.776889,
    double longitude = 106.700806,
    double accuracy = 14.0,
    String deviceId = 'mobile-device-savina',
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final idempotencyKey = 'checkin-${now.millisecondsSinceEpoch}';

    try {
      final response = await _dio.post(
        '/hrm/v1/attendance/check-in',
        options: Options(headers: {
          'Idempotency-Key': idempotencyKey,
          'X-Device-Id': deviceId,
        }),
        data: {
          if (employeeId != null) 'employee_id': employeeId,
          'source': 'MOBILE_APP',
          'verification_method': verificationMethod,
          'device_id': deviceId,
          'occurred_at': nowIso,
          'gps_coordinates': {
            'latitude': latitude,
            'longitude': longitude,
            'accuracy': accuracy,
            'is_mocked': false,
          },
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        _todayRecord = AttendanceRecord.fromJson(data as Map<String, dynamic>);
        return _todayRecord!;
      }
      throw Exception('Không thể quẹt thẻ vào ca (Mã: ${response.statusCode})');
    } catch (e) {
      debugPrint('[HrmAttendanceService] checkIn error: $e');
      rethrow;
    }
  }

  // 4. Check-Out (Quẹt thẻ Ra ca)
  Future<AttendanceRecord> checkOut({
    String? employeeId,
    String verificationMethod = 'GPS',
    double latitude = 10.776889,
    double longitude = 106.700806,
    String deviceId = 'mobile-device-savina',
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final idempotencyKey = 'checkout-${now.millisecondsSinceEpoch}';

    try {
      final response = await _dio.post(
        '/hrm/v1/attendance/check-out',
        options: Options(headers: {
          'Idempotency-Key': idempotencyKey,
          'X-Device-Id': deviceId,
        }),
        data: {
          if (employeeId != null) 'employee_id': employeeId,
          'source': 'MOBILE_APP',
          'verification_method': verificationMethod,
          'device_id': deviceId,
          'occurred_at': nowIso,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        _todayRecord = AttendanceRecord.fromJson(data as Map<String, dynamic>);
        return _todayRecord!;
      }
      throw Exception('Không thể quẹt thẻ ra ca (Mã: ${response.statusCode})');
    } catch (e) {
      debugPrint('[HrmAttendanceService] checkOut error: $e');
      rethrow;
    }
  }

  // 5. Get Today Status
  Future<AttendanceRecord?> getTodayAttendance() async {
    final endpoints = [
      '/hrm/v1/my-attendance',
      '/hrm/v1/attendance',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(
          ep,
          options: Options(validateStatus: (status) => true),
        );
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data['data'] ?? response.data['items'] ?? response.data;
          if (data is List && data.isNotEmpty) {
            final now = DateTime.now();
            final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            for (final item in data) {
              if (item is Map<String, dynamic>) {
                final rec = AttendanceRecord.fromJson(item);
                if (rec.workDate == todayStr || rec.firstCheckInAt != null) {
                  _todayRecord = rec;
                  return _todayRecord;
                }
              }
            }
          } else if (data is Map<String, dynamic>) {
            _todayRecord = AttendanceRecord.fromJson(data);
            return _todayRecord;
          }
        }
      } catch (e) {
        debugPrint('[HrmAttendanceService] getTodayAttendance info: $e');
      }
    }
    return _todayRecord;
  }

  // 6. Get Attendance History (Sổ chấm công)
  Future<List<AttendanceRecord>> getAttendanceHistory({String? from, String? to, String? status}) async {
    try {
      final response = await _dio.get(
        '/hrm/v1/attendance',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          if (status != null && status != 'ALL') 'status': status,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data['data'] ?? response.data['items'] ?? response.data;
        if (raw is List) {
          return raw.map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] getAttendanceHistory error: $e');
    }
    return [];
  }

  List<LeaveType> _cachedLeaveTypes = [];

  // 6.5. Get Leave Types (Loại nghỉ phép)
  Future<List<LeaveType>> getLeaveTypes() async {
    if (_cachedLeaveTypes.isNotEmpty) return _cachedLeaveTypes;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

    // 1. Try multiple possible leave types endpoints
    final candidateEndpoints = [
      '/hrm/v1/leave-types',
      '/hrm/v1/leaves/types',
      '/hrm/v1/leave-policies',
      '/hrm/v1/leaves',
    ];

    for (final ep in candidateEndpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          final dynamic raw = response.data['data'] ?? response.data['items'] ?? response.data;
          if (raw is List && raw.isNotEmpty) {
            for (final item in raw) {
              if (item is Map<String, dynamic>) {
                final lt = LeaveType.fromJson(item);
                if (lt.id.isNotEmpty && !_cachedLeaveTypes.any((t) => t.id == lt.id)) {
                  _cachedLeaveTypes.add(lt);
                }
              }
            }
            if (_cachedLeaveTypes.isNotEmpty) {
              debugPrint('[HrmAttendanceService] Loaded ${_cachedLeaveTypes.length} leave types from $ep');
              return _cachedLeaveTypes;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Extract real leave type UUIDs from existing /hrm/v1/leave-requests
    try {
      final lrRes = await _dio.get('/hrm/v1/leave-requests');
      if (lrRes.statusCode == 200 && lrRes.data != null) {
        final dynamic raw = lrRes.data['data'] ?? lrRes.data['items'] ?? lrRes.data;
        if (raw is List) {
          for (final item in raw) {
            final lt = item['leave_type'] ?? item['leaveType'];
            if (lt is Map<String, dynamic> && lt['id'] != null && uuidRegex.hasMatch(lt['id'].toString())) {
              final parsed = LeaveType.fromJson(lt);
              if (!_cachedLeaveTypes.any((t) => t.id == parsed.id)) {
                _cachedLeaveTypes.add(parsed);
              }
            } else {
              final tid = item['leave_type_id']?.toString() ?? item['leaveTypeId']?.toString() ?? '';
              if (tid.isNotEmpty && uuidRegex.hasMatch(tid) && !_cachedLeaveTypes.any((t) => t.id == tid)) {
                _cachedLeaveTypes.add(LeaveType(
                  id: tid,
                  code: item['leave_type_code']?.toString() ?? 'ANNUAL',
                  name: item['leave_type_name']?.toString() ?? 'Nghỉ phép năm (Hưởng nguyên lương)',
                ));
              }
            }
          }
          if (_cachedLeaveTypes.isNotEmpty) {
            debugPrint('[HrmAttendanceService] Extracted ${_cachedLeaveTypes.length} real leave types from /hrm/v1/leave-requests');
            return _cachedLeaveTypes;
          }
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] Extract from leave-requests error: $e');
    }

    // 3. Auto-create standard leave types if tenant has none yet
    final defaultTypes = [
      {'code': 'ANNUAL', 'name': 'Nghỉ phép năm (Hưởng nguyên lương)', 'unit': 'DAYS', 'paid': true, 'active': true, 'deductBalance': true, 'negativeLimit': 2},
      {'code': 'SICK', 'name': 'Nghỉ ốm (Hưởng BHXH)', 'unit': 'DAYS', 'paid': true, 'active': true, 'deductBalance': false, 'negativeLimit': 0},
      {'code': 'SPECIAL', 'name': 'Nghỉ việc riêng (Có lương)', 'unit': 'DAYS', 'paid': true, 'active': true, 'deductBalance': false, 'negativeLimit': 0},
      {'code': 'UNPAID', 'name': 'Nghỉ không hưởng lương', 'unit': 'DAYS', 'paid': false, 'active': true, 'deductBalance': false, 'negativeLimit': 0},
    ];
    for (final dt in defaultTypes) {
      try {
        final seedRes = await _dio.post('/hrm/v1/leave-types', data: dt);
        if (seedRes.statusCode == 200 || seedRes.statusCode == 201) {
          final data = seedRes.data['data'] ?? seedRes.data;
          if (data is Map<String, dynamic> && data['id'] != null) {
            final parsed = LeaveType.fromJson(data);
            if (!_cachedLeaveTypes.any((t) => t.id == parsed.id)) {
              _cachedLeaveTypes.add(parsed);
            }
          }
        }
      } catch (_) {}
    }

    return _cachedLeaveTypes;
  }

  String _mapLeaveType(String raw) {
    final upper = raw.toUpperCase();
    if (upper.contains('PHÉP NĂM') || upper.contains('ANNUAL')) return 'ANNUAL_LEAVE';
    if (upper.contains('ỐM') || upper.contains('SICK')) return 'SICK_LEAVE';
    if (upper.contains('VIỆC RIÊNG') || upper.contains('SPECIAL')) return 'PAID_LEAVE';
    if (upper.contains('KHÔNG LƯƠNG') || upper.contains('UNPAID')) return 'UNPAID_LEAVE';
    if (upper.contains('THÊM GIỜ') || upper.contains('OVERTIME') || upper.contains('OT')) return 'OVERTIME';
    if (upper.contains('CÔNG TÁC') || upper.contains('BUSINESS')) return 'BUSINESS_TRIP';
    if (upper.contains('ĐỔI CA') || upper.contains('SHIFT')) return 'SHIFT_SWAP';
    if (upper.contains('TẠM ỨNG') || upper.contains('ADVANCE')) return 'SALARY_ADVANCE';
    return 'ANNUAL_LEAVE';
  }

  // 7. Create Attendance Correction / ESS Request (Làm đơn & đồng bộ lên hệ thống)
  Future<AttendanceCorrection> createCorrection({
    String? employeeId,
    String? attendanceId,
    String? leaveTypeId,
    String? draftId,
    String? expectedUpdatedAt,
    required String requestDate,
    String? fromDate,
    String? toDate,
    required String newCheckInAt,
    required String newCheckOutAt,
    required String reason,
    double duration = 1.0,
    bool isNegativeLeave = false,
  }) async {
    debugPrint('[HrmAttendanceService] createCorrection START: $reason, date: $requestDate, leaveTypeId: $leaveTypeId, duration: $duration, draftId: $draftId');

    final cleanReason = reason.contains('] ') ? reason.substring(reason.indexOf('] ') + 2) : reason;
    final lowerReason = reason.toLowerCase();
    final fromDateClean = fromDate ?? (newCheckInAt.length >= 10 ? newCheckInAt.substring(0, 10) : requestDate);
    final toDateClean = toDate ?? (newCheckOutAt.length >= 10 ? newCheckOutAt.substring(0, 10) : requestDate);
    final inTimeClean = newCheckInAt.contains('T')
        ? newCheckInAt
        : (newCheckInAt.length >= 10 ? '${newCheckInAt.substring(0, 10)}T08:00:00' : '${requestDate}T08:00:00');
    final outTimeClean = newCheckOutAt.contains('T')
        ? newCheckOutAt
        : (newCheckOutAt.length >= 10 ? '${newCheckOutAt.substring(0, 10)}T17:30:00' : '${requestDate}T17:30:00');

    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    String? validUuidLeaveTypeId = (leaveTypeId != null && uuidRegex.hasMatch(leaveTypeId)) ? leaveTypeId : null;

    if (validUuidLeaveTypeId == null) {
      final types = await getLeaveTypes();
      for (final t in types) {
        if (uuidRegex.hasMatch(t.id)) {
          if (lowerReason.contains(t.name.toLowerCase()) || (t.code.isNotEmpty && reason.toUpperCase().contains(t.code.toUpperCase()))) {
            validUuidLeaveTypeId = t.id;
            break;
          }
        }
      }
      validUuidLeaveTypeId ??= types.where((t) => uuidRegex.hasMatch(t.id)).firstOrNull?.id;
    }

    // Determine ESS Request Category
    String requestType = 'LEAVE';
    String requestTitle = 'Đơn xin nghỉ phép';
    if ((attendanceId != null && attendanceId.isNotEmpty) ||
        lowerReason.contains('giải trình') ||
        lowerReason.contains('điều chỉnh công') ||
        lowerReason.contains('quên') ||
        lowerReason.contains('bổ sung công')) {
      requestType = 'ATTENDANCE_CORRECTION';
      requestTitle = 'Đơn giải trình chấm công';
    } else if (lowerReason.contains('thêm giờ') || lowerReason.contains('overtime') || lowerReason.contains('ot')) {
      requestType = 'OVERTIME';
      requestTitle = 'Đơn đăng ký làm thêm giờ (OT)';
    } else if (lowerReason.contains('công tác') || lowerReason.contains('business')) {
      requestType = 'BUSINESS_TRIP';
      requestTitle = 'Đơn đề xuất đi công tác';
    } else if (lowerReason.contains('tạm ứng') || lowerReason.contains('advance')) {
      requestType = 'SALARY_ADVANCE';
      requestTitle = 'Đơn xin tạm ứng lương';
    } else if (lowerReason.contains('đổi ca') || lowerReason.contains('shift')) {
      requestType = 'SHIFT_CHANGE';
      requestTitle = 'Đơn xin đổi ca làm việc';
    }

    final isEmpUuid = employeeId != null && uuidRegex.hasMatch(employeeId);

    // 1. LEAVE REQUEST (Đơn xin nghỉ phép)
    if (requestType == 'LEAVE') {
      try {
        final Map<String, dynamic> leavePayload = {
          if (validUuidLeaveTypeId != null) 'leaveTypeId': validUuidLeaveTypeId,
          if (validUuidLeaveTypeId != null) 'leave_type_id': validUuidLeaveTypeId,
          'duration': duration > 0 ? duration : 1.0,
          'isNegativeLeave': isNegativeLeave,
          'is_negative_leave': isNegativeLeave,
          'reason': cleanReason.isNotEmpty ? cleanReason : reason,
          'fromDate': fromDateClean,
          'toDate': toDateClean,
          'from_date': fromDateClean,
          'to_date': toDateClean,
          'requestDate': requestDate,
          'request_date': requestDate,
        };

        // Step 1: Sync draft to backend first (matching Web persistRequest behavior)
        String? actualDraftId = draftId;
        String? actualExpectedUpdatedAt = expectedUpdatedAt;

        try {
          final savedDraft = await saveDraft(
            kind: 'leave',
            draftId: (draftId != null && !draftId.startsWith('DFT-')) ? draftId : null,
            employeeId: isEmpUuid ? employeeId : null,
            payload: leavePayload,
            expectedUpdatedAt: expectedUpdatedAt,
          );
          if (savedDraft != null) {
            actualDraftId = savedDraft.id;
            actualExpectedUpdatedAt = savedDraft.createdAt;
          }
        } catch (draftErr) {
          debugPrint('[HrmAttendanceService] sync draft before leave-requests error: $draftErr');
        }

        // Step 2: Submit leave request
        final Map<String, dynamic> payload = {
          if (isEmpUuid) 'employeeId': employeeId,
          if (isEmpUuid) 'employee_id': employeeId,
          if (validUuidLeaveTypeId != null) 'leaveTypeId': validUuidLeaveTypeId,
          if (validUuidLeaveTypeId != null) 'leave_type_id': validUuidLeaveTypeId,
          if (actualDraftId != null && !actualDraftId.startsWith('DFT-')) 'draftId': actualDraftId,
          if (actualExpectedUpdatedAt != null) 'expectedUpdatedAt': actualExpectedUpdatedAt,
          ...leavePayload,
        };
        debugPrint('[HrmAttendanceService] /hrm/v1/leave-requests payload: $payload');
        final leaveResponse = await _dio.post(
          '/hrm/v1/leave-requests',
          data: payload,
        );
        if (leaveResponse.statusCode == 200 || leaveResponse.statusCode == 201) {
          final data = leaveResponse.data['data'] ?? leaveResponse.data;
          return AttendanceCorrection.fromJson(data as Map<String, dynamic>);
        }
      } catch (e) {
        if (e is DioException) {
          debugPrint('[HrmAttendanceService] /hrm/v1/leave-requests ERROR status: ${e.response?.statusCode}, body: ${e.response?.data}');
        }
        final err = ApiErrorHandler.parse(e);
        throw Exception(err);
      }

      throw Exception('Không thể tạo đơn nghỉ phép. Vui lòng kiểm tra lại cấu hình loại phép.');
    }

    // 2. ATTENDANCE CORRECTION (Giải trình công)
    if (requestType == 'ATTENDANCE_CORRECTION') {
      try {
        final response = await _dio.post(
          '/hrm/v1/attendance-corrections',
          data: {
            if (isEmpUuid) 'employeeId': employeeId,
            if (attendanceId != null && attendanceId.isNotEmpty) 'attendanceId': attendanceId,
            'request_date': requestDate,
            'requestDate': requestDate,
            'new_check_in_at': inTimeClean,
            'newCheckInAt': inTimeClean,
            'new_check_out_at': outTimeClean,
            'newCheckOutAt': outTimeClean,
            'reason': cleanReason.isNotEmpty ? cleanReason : reason,
          },
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data['data'] ?? response.data;
          return AttendanceCorrection.fromJson(data as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('[HrmAttendanceService] /hrm/v1/attendance-corrections ERROR: $e');
        final err = ApiErrorHandler.parse(e);
        throw Exception(err);
      }
    }

    // 3. OVERTIME (Làm thêm giờ)
    if (requestType == 'OVERTIME') {
      try {
        final otRes = await _dio.post(
          '/hrm/v1/ot-requests',
          data: {
            if (isEmpUuid) 'employeeId': employeeId,
            'workDate': fromDateClean,
            'startTime': '18:00',
            'endTime': '21:00',
            'plannedMinutes': (duration * 60).toInt() > 0 ? (duration * 60).toInt() : 180,
            'otType': 'REGULAR',
            'isNightOt': false,
            'reason': cleanReason.isNotEmpty ? cleanReason : reason,
          },
        );
        if (otRes.statusCode == 200 || otRes.statusCode == 201) {
          final data = otRes.data['data'] ?? otRes.data;
          return AttendanceCorrection.fromJson(data as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('[HrmAttendanceService] /hrm/v1/ot-requests ERROR: $e');
        final err = ApiErrorHandler.parse(e);
        throw Exception(err);
      }
    }

    // 4. BUSINESS TRIP (Công tác)
    if (requestType == 'BUSINESS_TRIP') {
      try {
        final tripRes = await _dio.post(
          '/hrm/v1/business-trip-requests',
          data: {
            if (isEmpUuid) 'employeeId': employeeId,
            'businessTripType': 'DOMESTIC',
            'destination': 'Công tác theo kế hoạch dự án',
            'fromDate': fromDateClean,
            'toDate': toDateClean,
            'daysCount': duration.ceil() > 0 ? duration.ceil() : 1,
            'allowOt': false,
            'reason': cleanReason.isNotEmpty ? cleanReason : reason,
          },
        );
        if (tripRes.statusCode == 200 || tripRes.statusCode == 201) {
          final data = tripRes.data['data'] ?? tripRes.data;
          return AttendanceCorrection.fromJson(data as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('[HrmAttendanceService] /hrm/v1/business-trip-requests ERROR: $e');
        final err = ApiErrorHandler.parse(e);
        throw Exception(err);
      }
    }

    // 5. SALARY ADVANCE (Tạm ứng lương)
    if (requestType == 'SALARY_ADVANCE') {
      try {
        final advRes = await _dio.post(
          '/hrm/v1/salary-advance-requests',
          data: {
            if (isEmpUuid) 'employeeId': employeeId,
            'requestDate': fromDateClean,
            'requestedAmount': 5000000,
            'numberOfInstallments': 1,
            'reason': cleanReason.isNotEmpty ? cleanReason : reason,
          },
        );
        if (advRes.statusCode == 200 || advRes.statusCode == 201) {
          final data = advRes.data['data'] ?? advRes.data;
          return AttendanceCorrection.fromJson(data as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('[HrmAttendanceService] /hrm/v1/salary-advance-requests ERROR: $e');
        final err = ApiErrorHandler.parse(e);
        throw Exception(err);
      }
    }

    // 6. SHIFT CHANGE (Đổi ca)
    if (requestType == 'SHIFT_CHANGE') {
      try {
        final shiftRes = await _dio.post(
          '/hrm/v1/shift-change-requests',
          data: {
            if (isEmpUuid) 'employeeId': employeeId,
            'changeType': 'CHANGE',
            'fromDate': fromDateClean,
            'toDate': toDateClean,
            'reason': cleanReason.isNotEmpty ? cleanReason : reason,
          },
        );
        if (shiftRes.statusCode == 200 || shiftRes.statusCode == 201) {
          final data = shiftRes.data['data'] ?? shiftRes.data;
          return AttendanceCorrection.fromJson(data as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('[HrmAttendanceService] /hrm/v1/shift-change-requests ERROR: $e');
        final err = ApiErrorHandler.parse(e);
        throw Exception(err);
      }
    }

    throw Exception('Không thể tạo đơn đề xuất. Vui lòng kiểm tra lại kết nối mạng.');
  }

  // 8. Get Corrections & Requests (Synced from Web and Mobile for all 7 types)
  Future<List<AttendanceCorrection>> getCorrections({String? status}) async {
    final List<AttendanceCorrection> remoteCorrections = [];
    debugPrint('[HrmAttendanceService] getCorrections START with status: $status');

    final endpoints = [
      '/hrm/v1/shift-change-requests',
      '/hrm/v1/leave-requests',
      '/hrm/v1/ot-requests',
      '/hrm/v1/business-trip-requests',
      '/hrm/v1/attendance-corrections',
      '/hrm/v1/salary-advance-requests',
      '/hrm/v1/profile-corrections',
      '/hrm/v1/requests',
    ];

    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          queryParameters: {
            if (status != null && status != 'ALL') 'status': status,
          },
        );
        if (res.statusCode == 200 && res.data != null) {
          final dynamic raw = res.data['data'] ?? res.data['items'] ?? res.data;
          if (raw is List) {
            for (final item in raw) {
              if (item is Map<String, dynamic>) {
                final id = item['id']?.toString() ?? item['code']?.toString() ?? '';
                if (id.isNotEmpty && !remoteCorrections.any((c) => c.id == id)) {
                  // If it's a shift change request without a title
                  if (ep.contains('shift-change') && (item['title'] == null && item['leaveTypeName'] == null)) {
                    item['title'] = 'Đổi ca với đồng nghiệp';
                    item['leave_type_name'] = 'Đổi ca với đồng nghiệp';
                  } else if (ep.contains('ot-requests') && (item['title'] == null && item['leaveTypeName'] == null)) {
                    item['title'] = 'Làm thêm giờ (OT)';
                    item['leave_type_name'] = 'Làm thêm giờ (OT)';
                  } else if (ep.contains('business-trip') && (item['title'] == null && item['leaveTypeName'] == null)) {
                    item['title'] = 'Đề xuất công tác';
                    item['leave_type_name'] = 'Đề xuất công tác';
                  } else if (ep.contains('salary-advance') && (item['title'] == null && item['leaveTypeName'] == null)) {
                    item['title'] = 'Tạm ứng lương';
                    item['leave_type_name'] = 'Tạm ứng lương';
                  }

                  final parsed = AttendanceCorrection.fromJson(item);
                  remoteCorrections.add(parsed);
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[HrmAttendanceService] get $ep error: $e');
      }
    }

    if (status != null && status != 'ALL') {
      return remoteCorrections.where((c) => c.status == status).toList();
    }
    return remoteCorrections;
  }

  // 7.5. Get Drafts (Bản nháp từ /hrm/v1/request-drafts)
  Future<List<AttendanceCorrection>> getDrafts({String? employeeId}) async {
    final List<AttendanceCorrection> drafts = [];
    final endpoints = [
      '/hrm/v1/request-drafts',
      if (employeeId != null && employeeId.isNotEmpty) '/hrm/v1/request-drafts?employee_id=$employeeId',
      '/hrm/v1/leave-requests?status=DRAFT',
      '/hrm/v1/requests?status=DRAFT',
      '/hrm/v1/attendance-corrections?status=DRAFT',
    ];

    const kindNames = <String, String>{
      'leave': 'Nghỉ phép',
      'ot': 'Làm thêm giờ',
      'business_trip': 'Công tác',
      'shift_change': 'Đổi ca',
      'correction': 'Bổ sung công',
      'advance': 'Tạm ứng lương',
      'profile_correction': 'Điều chỉnh hồ sơ',
    };

    for (final ep in endpoints) {
      try {
        final res = await _dio.get(ep);
        if (res.statusCode == 200 && res.data != null) {
          final dynamic raw = res.data['data'] ?? res.data['items'] ?? res.data;
          if (raw is List) {
            for (final item in raw) {
              if (item is Map<String, dynamic>) {
                // If it's a request-draft format: { id, employeeId, kind, status, payload, updatedAt }
                if (item.containsKey('payload') && item['payload'] is Map) {
                  final payload = item['payload'] as Map<String, dynamic>;
                  final kind = item['kind']?.toString() ?? 'leave';
                  final typeName = kindNames[kind] ?? 'Nghỉ phép';
                  final reason = payload['reason']?.toString() ?? payload['notes']?.toString() ?? payload['description']?.toString() ?? '123321';
                  final rawDate = payload['fromDate']?.toString() ?? payload['workDate']?.toString() ?? payload['requestDate']?.toString() ?? item['updatedAt']?.toString() ?? DateTime.now().toIso8601String();
                  final cleanDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
                  final rawFrom = payload['fromDate']?.toString() ?? cleanDate;
                  final rawTo = payload['toDate']?.toString() ?? cleanDate;
                  double? dur;
                  if (payload['duration'] != null) {
                    dur = double.tryParse(payload['duration'].toString());
                  }

                  final draftObj = AttendanceCorrection(
                    id: item['id']?.toString() ?? '',
                    employeeId: item['employeeId']?.toString() ?? item['employee_id']?.toString() ?? '',
                    attendanceId: payload['attendanceId']?.toString(),
                    requestDate: cleanDate,
                    fromDate: rawFrom.length >= 10 ? rawFrom.substring(0, 10) : rawFrom,
                    toDate: rawTo.length >= 10 ? rawTo.substring(0, 10) : rawTo,
                    reason: '[$typeName] $reason',
                    duration: dur,
                    leaveTypeName: typeName,
                    status: 'DRAFT',
                    createdAt: item['updatedAt']?.toString() ?? item['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
                  );
                  if (draftObj.id.isNotEmpty && !drafts.any((d) => d.id == draftObj.id)) {
                    drafts.add(draftObj);
                  }
                } else {
                  final parsed = AttendanceCorrection.fromJson(item);
                  if (parsed.id.isNotEmpty && !drafts.any((d) => d.id == parsed.id)) {
                    drafts.add(parsed);
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[HrmAttendanceService] getDrafts from $ep error: $e');
      }
    }
    return drafts;
  }

  // 7.6. Save Draft to Backend (/hrm/v1/request-drafts/:kind)
  Future<AttendanceCorrection?> saveDraft({
    required String kind,
    String? draftId,
    String? employeeId,
    required Map<String, dynamic> payload,
    String? expectedUpdatedAt,
  }) async {
    try {
      final isEdit = draftId != null && draftId.isNotEmpty && !draftId.startsWith('DFT-');
      final url = isEdit ? '/hrm/v1/request-drafts/$kind/$draftId' : '/hrm/v1/request-drafts/$kind';
      final cleanEmployeeId = (employeeId != null && employeeId.contains('-')) ? employeeId : null;

      String? versionToUse = expectedUpdatedAt;
      if (isEdit && (versionToUse == null || !versionToUse.contains('T'))) {
        try {
          final resList = await _dio.get('/hrm/v1/request-drafts');
          final raw = resList.data['data'] ?? resList.data['items'] ?? resList.data;
          if (raw is List) {
            for (final item in raw) {
              if (item is Map<String, dynamic> && item['id']?.toString() == draftId) {
                versionToUse = item['updatedAt']?.toString() ?? item['updated_at']?.toString();
                break;
              }
            }
          }
        } catch (_) {}
      }

      final body = {
        if (cleanEmployeeId != null) 'employeeId': cleanEmployeeId,
        'payload': payload,
        if (versionToUse != null) 'expectedUpdatedAt': versionToUse,
      };

      debugPrint('[HrmAttendanceService] saveDraft isEdit: $isEdit, url: $url, body: $body');
      Response<dynamic> response;
      if (isEdit) {
        response = await _dio.patch(
          url,
          data: body,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );

        if (response.statusCode == 400 || response.statusCode == 409) {
          debugPrint('[HrmAttendanceService] saveDraft got ${response.statusCode}, re-fetching fresh expectedUpdatedAt...');
          try {
            final resList = await _dio.get('/hrm/v1/request-drafts');
            final raw = resList.data['data'] ?? resList.data['items'] ?? resList.data;
            if (raw is List) {
              for (final item in raw) {
                if (item is Map<String, dynamic> && item['id']?.toString() == draftId) {
                  final fresh = item['updatedAt']?.toString() ?? item['updated_at']?.toString();
                  if (fresh != null) {
                    response = await _dio.patch(url, data: {
                      'payload': payload,
                      'expectedUpdatedAt': fresh,
                    });
                    break;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[HrmAttendanceService] retry saveDraft error: $e');
          }
        }
      } else {
        response = await _dio.post(url, data: body);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        if (data is Map<String, dynamic>) {
          const kindNames = <String, String>{
            'leave': 'Nghỉ phép',
            'ot': 'Làm thêm giờ',
            'business_trip': 'Công tác',
            'shift_change': 'Đổi ca',
            'correction': 'Bổ sung công',
            'advance': 'Tạm ứng lương',
            'profile_correction': 'Điều chỉnh hồ sơ',
          };
          final typeName = kindNames[kind] ?? 'Nghỉ phép';
          final innerPayload = (data['payload'] is Map) ? (data['payload'] as Map<String, dynamic>) : payload;
          final reason = innerPayload['reason']?.toString() ?? 'Bản nháp';
          final rawDate = innerPayload['fromDate']?.toString() ?? innerPayload['workDate']?.toString() ?? data['updatedAt']?.toString() ?? DateTime.now().toIso8601String();
          final cleanDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

          return AttendanceCorrection(
            id: data['id']?.toString() ?? draftId ?? 'DFT-${DateTime.now().millisecondsSinceEpoch}',
            employeeId: data['employeeId']?.toString() ?? employeeId ?? '',
            requestDate: cleanDate,
            fromDate: innerPayload['fromDate']?.toString() ?? cleanDate,
            toDate: innerPayload['toDate']?.toString() ?? cleanDate,
            reason: '[$typeName] $reason',
            duration: double.tryParse(innerPayload['duration']?.toString() ?? '1.0'),
            leaveTypeName: typeName,
            status: 'DRAFT',
            createdAt: data['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
          );
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] saveDraft error: $e');
    }
    return null;
  }

  Future<bool> deleteDraft(String id, {String kind = 'leave', String? expectedUpdatedAt}) async {
    final kindsToTry = [kind, 'leave', 'ot', 'business_trip', 'correction', 'shift_change', 'advance', 'profile_correction'];
    for (final k in kindsToTry) {
      try {
        final res = await _dio.delete(
          '/hrm/v1/request-drafts/$k/$id',
          data: {
            if (expectedUpdatedAt != null) 'expectedUpdatedAt': expectedUpdatedAt,
          },
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
      } catch (e) {
        debugPrint('[HrmAttendanceService] deleteDraft for kind $k error: $e');
      }
    }
    return false;
  }

  Future<bool> cancelCorrection(String id) async {
    debugPrint('[HrmAttendanceService] cancelCorrection START for id: $id');
    final attempts = <Future<Response<dynamic>> Function()>[
      () => _dio.post('/hrm/v1/leave-requests/$id/cancel'),
      () => _dio.patch('/hrm/v1/leave-requests/$id/cancel'),
      () => _dio.delete('/hrm/v1/leave-requests/$id'),
      () => _dio.post('/hrm/v1/attendance-corrections/$id/cancel'),
      () => _dio.patch('/hrm/v1/attendance-corrections/$id/cancel'),
      () => _dio.delete('/hrm/v1/attendance-corrections/$id'),
      () => _dio.post('/hrm/v1/requests/$id/cancel'),
      () => _dio.patch('/hrm/v1/requests/$id/cancel'),
      () => _dio.delete('/hrm/v1/requests/$id'),
      () => _dio.post('/hrm/v1/leave-requests/$id/withdraw'),
      () => _dio.patch('/hrm/v1/leave-requests/$id', data: {'status': 'CANCELLED'}),
    ];

    for (int i = 0; i < attempts.length; i++) {
      try {
        final res = await attempts[i]();
        if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
          debugPrint('[HrmAttendanceService] cancelCorrection SUCCESS on attempt $i, status: ${res.statusCode}');
          return true;
        }
      } catch (e) {
        if (e is DioException) {
          debugPrint('[HrmAttendanceService] cancelCorrection attempt $i failed: ${e.response?.statusCode} ${e.response?.data}');
        }
      }
    }
    return false;
  }

  // ==========================================
  // 8. MY PROFILE & INCOME (HỒ SƠ & PHIẾU LƯƠNG CỦA TÔI)
  // ==========================================
  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final res = await _dio.get(
        '/hrm/v1/my-profile',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'] ?? res.data;
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] getMyProfile error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getCareerHistory() async {
    try {
      final res = await _dio.get(
        '/hrm/v1/my-profile/career-history',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['data'] ?? res.data;
        if (raw is List) {
          return raw.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] getCareerHistory error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMyPayslips() async {
    try {
      final res = await _dio.get(
        '/hrm/v1/my-payslips',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['data'] ?? res.data;
        if (raw is List) {
          return raw.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] getMyPayslips error: $e');
    }
    return [];
  }

  Future<bool> updateMyProfile(Map<String, dynamic> updateData) async {
    final endpoints = [
      '/hrm/v1/my-profile',
      '/hrm/v1/profile',
    ];

    for (int attempt = 0; attempt < 2; attempt++) {
      for (final ep in endpoints) {
        try {
          final res = await _dio.patch(
            ep,
            data: updateData,
            options: Options(
              headers: {'Content-Type': 'application/json'},
              validateStatus: (status) => status != null && status < 500,
            ),
          );
          debugPrint('[HrmAttendanceService] updateMyProfile ($ep) status: ${res.statusCode}, response: ${res.data}');
          if (res.statusCode == 200 || res.statusCode == 204) {
            return true;
          }
          if (res.statusCode == 401 && attempt == 0) {
            debugPrint('[HrmAttendanceService] 401 received on updateMyProfile. Triggering silent relogin...');
            final renewed = await AuthProvider.silentRelogin();
            if (renewed) {
              break; // Break inner loop to retry outer loop with renewed token
            }
          }
        } catch (e) {
          debugPrint('[HrmAttendanceService] updateMyProfile ($ep) error: $e');
        }
      }
    }
    return false;
  }

  Future<Map<String, dynamic>?> getProfileDocuments(String employeeId) async {
    try {
      final res = await _dio.get(
        '/hrm/v1/employees/$employeeId/profile-documents',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'] ?? res.data;
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] getProfileDocuments error: $e');
    }
    return null;
  }

  Future<String?> uploadHrmAttachment({
    required String filePath,
    required String fileName,
    String? documentType,
    String? employeeId,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final ext = fileName.split('.').last.toLowerCase();
      String contentType = 'application/octet-stream';
      if (ext == 'jpg' || ext == 'jpeg') contentType = 'image/jpeg';
      else if (ext == 'png') contentType = 'image/png';
      else if (ext == 'webp') contentType = 'image/webp';
      else if (ext == 'pdf') contentType = 'application/pdf';

      // Step 1: Create attachment record
      final createRes = await _dio.post(
        '/hrm/v1/attachments',
        data: {
          if (employeeId != null && employeeId.isNotEmpty && employeeId.length > 30) 'employeeId': employeeId,
          'fileName': fileName,
          'contentType': contentType,
          'sizeBytes': bytes.length,
          if (documentType != null) 'documentType': documentType,
        },
        options: Options(validateStatus: (s) => s != null && s < 500),
      );

      if (createRes.statusCode != 200 && createRes.statusCode != 201) {
        debugPrint('[HrmAttendanceService] Attachment create failed: ${createRes.data}');
        return null;
      }

      final attachData = createRes.data['data'] ?? createRes.data;
      final attachmentId = attachData['id']?.toString();
      final uploadUrl = attachData['uploadUrl']?.toString();

      if (attachmentId != null && uploadUrl != null) {
        // Step 2: PUT binary bytes to presigned URL
        final putRes = await Dio().put(
          uploadUrl,
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {
              'Content-Type': contentType,
              'Content-Length': bytes.length,
            },
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (putRes.statusCode == 200 || putRes.statusCode == 204) {
          // Step 3: Complete attachment
          await _dio.post(
            '/hrm/v1/attachments/$attachmentId/complete',
            options: Options(validateStatus: (s) => s != null && s < 500),
          );
          return attachmentId;
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] uploadHrmAttachment error: $e');
    }
    return null;
  }

  Future<bool> submitProfileDocumentChanges({
    required List<Map<String, dynamic>> documentChanges,
    String? reason,
    String? identityCardExpiryDate,
    String? employeeId,
  }) async {
    try {
      // 1. First try direct profile-documents if employeeId is provided
      if (employeeId != null && employeeId.isNotEmpty && employeeId.length > 30) {
        final docRes = await _dio.post(
          '/hrm/v1/employees/$employeeId/profile-documents',
          data: {
            'documentChanges': documentChanges,
            if (identityCardExpiryDate != null) 'identityCardExpiryDate': identityCardExpiryDate,
          },
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (docRes.statusCode == 200 || docRes.statusCode == 201) {
          return true;
        }
      }

      // 2. Self-service profile correction request
      final corrRes = await _dio.post(
        '/hrm/v1/profile-corrections',
        data: {
          'documentChanges': documentChanges,
          'changes': identityCardExpiryDate != null ? {'identityCardExpiryDate': identityCardExpiryDate} : {},
          'reason': (reason != null && reason.trim().length >= 3) ? reason.trim() : 'Cập nhật hồ sơ từ Mobile App',
        },
        options: Options(validateStatus: (s) => s != null && s < 500),
      );

      return corrRes.statusCode == 200 || corrRes.statusCode == 201;
    } catch (e) {
      debugPrint('[HrmAttendanceService] submitProfileDocumentChanges error: $e');
    }
    return false;
  }

  // ==========================================
  // SELF-SERVICE DEPENDENTS (NGƯỜI THÂN CÁ NHÂN)
  // ==========================================
  Future<List<Map<String, dynamic>>> getDependents() async {
    try {
      final res = await _dio.get(
        '/api/hrm/v1/my-dependents',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['data'] ?? res.data;
        if (raw is List) {
          return raw.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] getDependents error: $e');
    }
    return [];
  }

  Future<bool> createDependent(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(
        '/api/hrm/v1/my-dependents',
        data: data,
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[HrmAttendanceService] createDependent error: $e');
      return false;
    }
  }

  Future<bool> deleteDependent(String id) async {
    try {
      final res = await _dio.delete(
        '/api/hrm/v1/my-dependents/$id',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[HrmAttendanceService] deleteDependent error: $e');
      return false;
    }
  }

  // ==========================================
  // EMPLOYEE DEPENDENTS (QUẢN LÝ NGƯỜI THÂN THEO NHÂN VIÊN)
  // ==========================================
  Future<List<Map<String, dynamic>>> getEmployeeDependents(String employeeId) async {
    try {
      final res = await _dio.get(
        '/api/hrm/v1/employees/$employeeId/dependents',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['data'] ?? res.data;
        if (raw is List) {
          return raw.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] getEmployeeDependents error: $e');
    }
    return [];
  }

  Future<bool> createEmployeeDependent(String employeeId, Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(
        '/api/hrm/v1/employees/$employeeId/dependents',
        data: data,
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[HrmAttendanceService] createEmployeeDependent error: $e');
      return false;
    }
  }

  Future<bool> deleteEmployeeDependent(String employeeId, String id) async {
    try {
      final res = await _dio.delete(
        '/api/hrm/v1/employees/$employeeId/dependents/$id',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[HrmAttendanceService] deleteEmployeeDependent error: $e');
      return false;
    }
  }

  // ==========================================
  // EMPLOYEE CONTRACTS (HỢP ĐỒNG LAO ĐỘNG)
  // ==========================================
  Future<List<Map<String, dynamic>>> getEmployeeContracts(String employeeId) async {
    try {
      final res = await _dio.get(
        '/api/hrm/v1/employees/$employeeId/contracts',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['data'] ?? res.data;
        if (raw is List) {
          return raw.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] getEmployeeContracts error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> createEmployeeDraftContract(String employeeId, Map<String, dynamic> data) async {
    try {
      debugPrint('[HrmAttendanceService] createEmployeeDraftContract employeeId: $employeeId, data: $data');
      final res = await _dio.post(
        '/api/hrm/v1/employees/$employeeId/contracts',
        data: data,
        options: Options(validateStatus: (status) => true),
      );
      debugPrint('[HrmAttendanceService] createEmployeeDraftContract response: ${res.statusCode} ${res.data}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        final resData = res.data is Map ? (res.data['data'] ?? res.data) : null;
        return {
          'success': true,
          'data': resData is Map<String, dynamic> ? resData : data,
        };
      } else {
        String msg = 'Tạo hợp đồng thất bại (Mã: ${res.statusCode})';
        if (res.data is Map) {
          final m = res.data['message'] ?? res.data['error'] ?? res.data['detail'];
          if (m != null) msg = m is List ? m.join(', ') : m.toString();
        } else if (res.data is String && (res.data as String).isNotEmpty) {
          msg = res.data.toString();
        }
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] createEmployeeDraftContract exception: $e');
      String msg = e.toString();
      if (e is DioException && e.response?.data != null) {
        final d = e.response!.data;
        if (d is Map) {
          final m = d['message'] ?? d['error'] ?? d['detail'];
          if (m != null) msg = m is List ? m.join(', ') : m.toString();
        } else if (d is String && d.isNotEmpty) {
          msg = d;
        }
      }
      return {'success': false, 'message': msg};
    }
  }

  Future<bool> deleteEmployeeContract(String contractId, {String? expectedUpdatedAt}) async {
    try {
      final res = await _dio.delete(
        '/api/hrm/v1/contracts/$contractId',
        data: expectedUpdatedAt != null ? {'expectedUpdatedAt': expectedUpdatedAt} : null,
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[HrmAttendanceService] deleteEmployeeContract error: $e');
      return false;
    }
  }

  /// Ban hành hợp đồng theo chứng từ đã ký (DRAFT -> ACTIVE)
  Future<Map<String, dynamic>> activateEmployeeContract(String contractId, {required String expectedUpdatedAt}) async {
    try {
      final res = await _dio.post(
        '/api/hrm/v1/contracts/$contractId/activate',
        data: {'expectedUpdatedAt': expectedUpdatedAt},
        options: Options(validateStatus: (status) => true),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'data': res.data};
      }
      String msg = 'Ban hành hợp đồng thất bại (${res.statusCode})';
      if (res.data is Map) {
        final m = res.data['message'] ?? res.data['error'];
        if (m != null) msg = m is List ? m.join(', ') : m.toString();
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      debugPrint('[HrmAttendanceService] activateEmployeeContract error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Lập phụ lục / gia hạn từ hợp đồng gốc đang ACTIVE
  Future<Map<String, dynamic>> amendEmployeeContract(String contractId, Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(
        '/api/hrm/v1/contracts/$contractId/amendments',
        data: data,
        options: Options(validateStatus: (status) => true),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'data': res.data};
      }
      String msg = 'Tạo phụ lục thất bại (${res.statusCode})';
      if (res.data is Map) {
        final m = res.data['message'] ?? res.data['error'];
        if (m != null) msg = m is List ? m.join(', ') : m.toString();
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      debugPrint('[HrmAttendanceService] amendEmployeeContract error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Ghi nhận chấm dứt hợp đồng ACTIVE
  Future<Map<String, dynamic>> terminateEmployeeContract(String contractId, Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(
        '/api/hrm/v1/contracts/$contractId/terminate',
        data: data,
        options: Options(validateStatus: (status) => true),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'data': res.data};
      }
      String msg = 'Ghi nhận chấm dứt thất bại (${res.statusCode})';
      if (res.data is Map) {
        final m = res.data['message'] ?? res.data['error'];
        if (m != null) msg = m is List ? m.join(', ') : m.toString();
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      debugPrint('[HrmAttendanceService] terminateEmployeeContract error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Sửa thông tin hợp đồng nháp
  Future<Map<String, dynamic>> updateEmployeeDraftContract(String contractId, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch(
        '/api/hrm/v1/contracts/$contractId',
        data: data,
        options: Options(validateStatus: (status) => true),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'data': res.data};
      }
      String msg = 'Cập nhật hợp đồng thất bại (${res.statusCode})';
      if (res.data is Map) {
        final m = res.data['message'] ?? res.data['error'];
        if (m != null) msg = m is List ? m.join(', ') : m.toString();
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      debugPrint('[HrmAttendanceService] updateEmployeeDraftContract error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Lấy tuyến quản lý trực tiếp & lịch sử báo cáo chuẩn Core
  Future<Map<String, dynamic>?> getEmployeeReportingLines(String employeeId) async {
    try {
      final res = await _dio.get(
        '/api/hrm/v1/employees/$employeeId/reporting-lines',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'] ?? res.data;
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] getEmployeeReportingLines error: $e');
    }
    return null;
  }

  /// Lấy quỹ phép & thâm niên theo chính sách HĐLĐ mới
  Future<List<Map<String, dynamic>>> getEmployeeLeaveBalances(String employeeId, {int? year}) async {
    try {
      final y = year ?? DateTime.now().year;
      final res = await _dio.get(
        '/api/hrm/v1/employees/$employeeId/leave-balances?year=$y',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['data'] ?? res.data;
        if (raw is List) {
          return raw.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      debugPrint('[HrmAttendanceService] getEmployeeLeaveBalances error: $e');
    }
    return [];
  }
}

