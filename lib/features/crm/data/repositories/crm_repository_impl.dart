import 'package:flutter/foundation.dart';
import '../../domain/models/crm_models.dart';
import '../../domain/repositories/i_crm_repository.dart';
import '../datasources/crm_remote_datasource.dart';

class CrmRepositoryImpl implements ICrmRepository {
  final CrmRemoteDataSource _remoteDataSource;

  CrmRepositoryImpl({CrmRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? CrmRemoteDataSource();

  @override
  Future<CrmStatus?> getCrmStatus() async {
    try {
      final raw = await _remoteDataSource.getStatusRaw();
      if (raw != null && raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw;
        if (data is Map<String, dynamic>) {
          return CrmStatus.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[CrmRepositoryImpl] getCrmStatus error: $e');
    }
    return null;
  }

  @override
  Future<CrmDashboard> getCrmDashboard({String period = 'month'}) async {
    try {
      final raw = await _remoteDataSource.getDashboardRaw(period: period);
      if (raw != null && raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw;
        if (data is Map<String, dynamic>) {
          return CrmDashboard.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[CrmRepositoryImpl] getCrmDashboard error: $e');
    }
    return const CrmDashboard();
  }

  @override
  Future<List<CrmCustomerSummary>> getCustomers({String? search}) async {
    try {
      final raw = await _remoteDataSource.getCustomersRaw(search: search);
      if (raw != null) {
        dynamic items = raw is Map ? (raw['items'] ?? raw['data'] ?? raw) : raw;
        if (items is Map && items['items'] != null) items = items['items'];
        if (items is List) {
          return items
              .whereType<Map<String, dynamic>>()
              .map((e) => CrmCustomerSummary.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[CrmRepositoryImpl] getCustomers error: $e');
    }
    return [];
  }

  @override
  Future<List<CrmOpportunitySummary>> getOpportunities({String? stage, String? search}) async {
    try {
      final raw = await _remoteDataSource.getOpportunitiesRaw(stage: stage, search: search);
      if (raw != null) {
        dynamic items = raw is Map ? (raw['items'] ?? raw['data'] ?? raw) : raw;
        if (items is Map && items['items'] != null) items = items['items'];
        if (items is List) {
          return items
              .whereType<Map<String, dynamic>>()
              .map((e) => CrmOpportunitySummary.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[CrmRepositoryImpl] getOpportunities error: $e');
    }
    return [];
  }

  @override
  Future<List<CrmQuoteSummary>> getQuotes({String? status, String? search}) async {
    try {
      final raw = await _remoteDataSource.getQuotesRaw(status: status, search: search);
      if (raw != null) {
        dynamic items = raw is Map ? (raw['items'] ?? raw['data'] ?? raw) : raw;
        if (items is Map && items['items'] != null) items = items['items'];
        if (items is List) {
          return items
              .whereType<Map<String, dynamic>>()
              .map((e) => CrmQuoteSummary.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[CrmRepositoryImpl] getQuotes error: $e');
    }
    return [];
  }

  @override
  Future<List<CrmLeadSummary>> getLeads({String? status, String? search}) async {
    try {
      final raw = await _remoteDataSource.getLeadsRaw(status: status, search: search);
      if (raw != null) {
        dynamic items = raw is Map ? (raw['items'] ?? raw['data'] ?? raw) : raw;
        if (items is Map && items['items'] != null) items = items['items'];
        if (items is List) {
          return items
              .whereType<Map<String, dynamic>>()
              .map((e) => CrmLeadSummary.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[CrmRepositoryImpl] getLeads error: $e');
    }
    return [];
  }
}
