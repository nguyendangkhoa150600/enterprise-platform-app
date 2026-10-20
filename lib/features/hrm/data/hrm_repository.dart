import 'package:flutter/foundation.dart';
import '../../../models/hrm_models.dart';
import '../../../services/hrm_service.dart';

/// Clean Architecture Repository for HRM Workforce & Position Hub
abstract class HrmRepository {
  Future<List<HrmEmployeeItem>> getEmployees({String? status, String? department, bool forceRefresh = false});
  Future<List<HrmPositionItem>> getPositions({bool forceRefresh = false});
  Future<List<HrmRequestItem>> getRequests({String? status, HrmRequestType? type});
  Future<HrmRequestItem> createRequest({
    required HrmRequestType type,
    required String title,
    required String reason,
    double? durationHours,
    double? amount,
    DateTime? startDate,
    DateTime? endDate,
    String? note,
  });
  Future<bool> approveRequest(String requestId, {String? note});
  Future<bool> rejectRequest(String requestId, {required String reason});
  Future<bool> updateRequestStatus(String requestId, HrmRequestStatus newStatus, {String? note, String? reason});
  Future<HrmDashboardStats> getDashboardStats();
}

class HrmRepositoryImpl implements HrmRepository {
  final HrmService _service;

  HrmRepositoryImpl({HrmService? service}) : _service = service ?? HrmService();

  @override
  Future<List<HrmEmployeeItem>> getEmployees({String? status, String? department, bool forceRefresh = false}) async {
    try {
      return await _service.getEmployees(department: department, forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('[HrmRepositoryImpl] getEmployees error: $e');
      return [];
    }
  }

  @override
  Future<List<HrmPositionItem>> getPositions({bool forceRefresh = false}) async {
    try {
      return await _service.getPositions(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('[HrmRepositoryImpl] getPositions error: $e');
      return [];
    }
  }

  @override
  Future<List<HrmRequestItem>> getRequests({String? status, HrmRequestType? type}) async {
    try {
      return await _service.getRequests(status: status, type: type);
    } catch (e) {
      debugPrint('[HrmRepositoryImpl] getRequests error: $e');
      return [];
    }
  }

  @override
  Future<HrmRequestItem> createRequest({
    required HrmRequestType type,
    required String title,
    required String reason,
    double? durationHours,
    double? amount,
    DateTime? startDate,
    DateTime? endDate,
    String? note,
  }) async {
    return await _service.createRequest(
      type: type,
      title: title,
      reason: reason,
      durationHours: durationHours,
      amount: amount,
      startDate: startDate,
      endDate: endDate,
      note: note,
    );
  }

  @override
  Future<bool> approveRequest(String requestId, {String? note}) async {
    return await _service.approveRequest(requestId, note: note);
  }

  @override
  Future<bool> rejectRequest(String requestId, {required String reason}) async {
    return await _service.rejectRequest(requestId, reason: reason);
  }

  @override
  Future<bool> updateRequestStatus(String requestId, HrmRequestStatus newStatus, {String? note, String? reason}) async {
    if (newStatus == HrmRequestStatus.approved) {
      return await _service.approveRequest(requestId, note: note);
    } else if (newStatus == HrmRequestStatus.rejected) {
      return await _service.rejectRequest(requestId, reason: reason ?? 'Từ chối bởi quản trị viên');
    }
    return false;
  }

  @override
  Future<HrmDashboardStats> getDashboardStats() async {
    return await _service.getDashboardStats();
  }
}
