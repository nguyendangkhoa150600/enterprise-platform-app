import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/procedure_models.dart';
import '../models/inventory_models.dart';
import '../models/maintenance_models.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

class ModuleBusinessService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  ModuleBusinessService() {
    ApiClientHelper.configureDio(_dio);
  }

  // Procedure Workspace
  Future<List<ProcedureInstance>> getProcedureInstances() async {
    try {
      final response = await _dio.get('/procedure/v1/workspace');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['instances'] as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => ProcedureInstance.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Inventory Materials & Transactions
  Future<List<MaterialItem>> getInventoryMaterials() async {
    try {
      final response = await _dio.get('/inventory/v1/materials');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['materials'] as List<dynamic>? ?? response.data as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => MaterialItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<StockTransaction>> getInventoryTransactions() async {
    try {
      final response = await _dio.get('/inventory/v1/transactions');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['transactions'] as List<dynamic>? ?? response.data as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => StockTransaction.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Maintenance Schedules & Incidents
  Future<List<MaintenanceSchedule>> getMaintenanceSchedules() async {
    try {
      final response = await _dio.get('/maintenance/v1/schedules');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['schedules'] as List<dynamic>? ?? response.data as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => MaintenanceSchedule.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<MaintenanceIncident>> getMaintenanceIncidents() async {
    try {
      final response = await _dio.get('/maintenance/v1/occurrences/incidents');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['incidents'] as List<dynamic>? ?? response.data as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => MaintenanceIncident.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
