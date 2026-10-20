import 'package:flutter/foundation.dart';
import '../../../services/hrm_attendance_service.dart';

/// Data Repository for Payroll, Payslips, and Personal Income
abstract class PayrollRepository {
  Future<List<Map<String, dynamic>>> getMyPayslips({bool forceRefresh = false});
  Future<Map<String, dynamic>> getIncomeSummary({int? year});
  Future<Map<String, dynamic>?> getPersonalProfile({bool forceRefresh = false});
  Future<bool> createDependent(Map<String, dynamic> payload);
  Future<bool> deleteDependent(String dependentId);
  Future<String?> uploadAttachment({
    required String filePath,
    required String fileName,
    required String documentType,
    String? employeeId,
  });
  Future<bool> submitDocumentChanges({
    required List<Map<String, dynamic>> documentChanges,
    String? employeeId,
    String? reason,
  });
}

class PayrollRepositoryImpl implements PayrollRepository {
  final HrmAttendanceService _service;

  PayrollRepositoryImpl({HrmAttendanceService? service})
      : _service = service ?? HrmAttendanceService();

  @override
  Future<List<Map<String, dynamic>>> getMyPayslips({bool forceRefresh = false}) async {
    try {
      return await _service.getMyPayslips(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('[PayrollRepositoryImpl] getMyPayslips error: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getIncomeSummary({int? year}) async {
    try {
      return await _service.getIncomeSummary(year: year);
    } catch (e) {
      debugPrint('[PayrollRepositoryImpl] getIncomeSummary error: $e');
      return {
        'totalGross': 0,
        'totalNet': 0,
        'totalTax': 0,
        'totalInsurance': 0,
      };
    }
  }

  @override
  Future<Map<String, dynamic>?> getPersonalProfile({bool forceRefresh = false}) async {
    try {
      return await _service.getPersonalProfile(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('[PayrollRepositoryImpl] getPersonalProfile error: $e');
      return null;
    }
  }

  @override
  Future<bool> createDependent(Map<String, dynamic> payload) async {
    return await _service.createDependent(payload);
  }

  @override
  Future<bool> deleteDependent(String dependentId) async {
    return await _service.deleteDependent(dependentId);
  }

  @override
  Future<String?> uploadAttachment({
    required String filePath,
    required String fileName,
    required String documentType,
    String? employeeId,
  }) async {
    return await _service.uploadHrmAttachment(
      filePath: filePath,
      fileName: fileName,
      documentType: documentType,
      employeeId: employeeId,
    );
  }

  @override
  Future<bool> submitDocumentChanges({
    required List<Map<String, dynamic>> documentChanges,
    String? employeeId,
    String? reason,
  }) async {
    return await _service.submitProfileDocumentChanges(
      documentChanges: documentChanges,
      employeeId: employeeId,
      reason: reason,
    );
  }
}
