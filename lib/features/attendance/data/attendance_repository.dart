import 'package:flutter/foundation.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../services/hrm_attendance_service.dart';

/// Clean Architecture Repository for Attendance, Shifts, GPS Check-in, and Timesheets
abstract class AttendanceRepository {
  Future<AttendanceRecord?> getTodayRecord({bool forceRefresh = false});
  Future<AttendanceRecord> checkIn({
    String? employeeId,
    String verificationMethod = 'GPS',
    double latitude = 10.776889,
    double longitude = 106.700806,
    String deviceId = 'mobile-device-savina',
  });
  Future<AttendanceRecord> checkOut({
    String? employeeId,
    String verificationMethod = 'GPS',
    double latitude = 10.776889,
    double longitude = 106.700806,
    String deviceId = 'mobile-device-savina',
  });
  Future<MonthlyAttendanceSummary> getMonthlySummary({String? monthYear, bool forceRefresh = false});
  Future<List<AttendanceRecord>> getAttendanceLogs({String? from, String? to, String? status});
  Future<List<LeaveType>> getLeaveTypes();
  Future<AttendanceCorrection> createCorrection({
    required String requestDate,
    required String newCheckInAt,
    required String newCheckOutAt,
    required String reason,
    String? employeeId,
  });
}

class AttendanceRepositoryImpl implements AttendanceRepository {
  final HrmAttendanceService _service;

  AttendanceRepositoryImpl({HrmAttendanceService? service})
      : _service = service ?? HrmAttendanceService();

  @override
  Future<AttendanceRecord?> getTodayRecord({bool forceRefresh = false}) async {
    try {
      return await _service.getTodayAttendance();
    } catch (e) {
      debugPrint('[AttendanceRepositoryImpl] getTodayRecord error: $e');
      return null;
    }
  }

  @override
  Future<AttendanceRecord> checkIn({
    String? employeeId,
    String verificationMethod = 'GPS',
    double latitude = 10.776889,
    double longitude = 106.700806,
    String deviceId = 'mobile-device-savina',
  }) async {
    return await _service.checkIn(
      employeeId: employeeId,
      verificationMethod: verificationMethod,
      latitude: latitude,
      longitude: longitude,
      deviceId: deviceId,
    );
  }

  @override
  Future<AttendanceRecord> checkOut({
    String? employeeId,
    String verificationMethod = 'GPS',
    double latitude = 10.776889,
    double longitude = 106.700806,
    String deviceId = 'mobile-device-savina',
  }) async {
    return await _service.checkOut(
      employeeId: employeeId,
      verificationMethod: verificationMethod,
      latitude: latitude,
      longitude: longitude,
      deviceId: deviceId,
    );
  }

  @override
  Future<MonthlyAttendanceSummary> getMonthlySummary({String? monthYear, bool forceRefresh = false}) async {
    try {
      final records = await _service.getAttendanceHistory();
      int actualDays = records.where((r) => r.firstCheckInAt != null).length;
      int lateDays = records.where((r) => r.lateMinutes > 0).length;
      int earlyDays = records.where((r) => r.earlyLeaveMinutes > 0).length;
      double totalHours = records.fold(0.0, (sum, r) => sum + (r.workedMinutes / 60.0));

      return MonthlyAttendanceSummary(
        monthYear: monthYear ?? 'T10/2026',
        totalWorkDays: 22,
        actualWorkDays: actualDays,
        lateDays: lateDays,
        earlyLeaveDays: earlyDays,
        leaveDays: 0,
        unauthorizedAbsenceDays: 0,
        totalWorkHours: double.parse(totalHours.toStringAsFixed(1)),
        totalOvertimeHours: 0.0,
      );
    } catch (e) {
      debugPrint('[AttendanceRepositoryImpl] getMonthlySummary error: $e');
      return MonthlyAttendanceSummary(
        monthYear: monthYear ?? 'T10/2026',
        totalWorkDays: 22,
        actualWorkDays: 0,
        lateDays: 0,
        earlyLeaveDays: 0,
        leaveDays: 0,
        unauthorizedAbsenceDays: 0,
        totalWorkHours: 0.0,
        totalOvertimeHours: 0.0,
      );
    }
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceLogs({String? from, String? to, String? status}) async {
    try {
      return await _service.getAttendanceHistory(from: from, to: to, status: status);
    } catch (e) {
      debugPrint('[AttendanceRepositoryImpl] getAttendanceLogs error: $e');
      return [];
    }
  }

  @override
  Future<List<LeaveType>> getLeaveTypes() async {
    try {
      return await _service.getLeaveTypes();
    } catch (e) {
      debugPrint('[AttendanceRepositoryImpl] getLeaveTypes error: $e');
      return [];
    }
  }

  @override
  Future<AttendanceCorrection> createCorrection({
    required String requestDate,
    required String newCheckInAt,
    required String newCheckOutAt,
    required String reason,
    String? employeeId,
  }) async {
    return await _service.createCorrection(
      requestDate: requestDate,
      newCheckInAt: newCheckInAt,
      newCheckOutAt: newCheckOutAt,
      reason: reason,
      employeeId: employeeId,
    );
  }
}
