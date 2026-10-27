import 'package:dio/dio.dart';
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
  Future<ProcedureWorkspaceData> getProcedureWorkspace() async {
    final endpoints = [
      '/api/procedure/v1/workspace',
      '/procedure/v1/workspace',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data : null;
          if (data != null) {
            return ProcedureWorkspaceData.fromJson(data as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return ProcedureWorkspaceData(instances: [], definitions: []);
  }

  Future<List<ProcedureInstance>> getProcedureInstances() async {
    final ws = await getProcedureWorkspace();
    return ws.instances;
  }

  // Procedure Organization Context (for RACI subjects, unit names, member names)
  Future<Map<String, dynamic>?> getProcedureOrganizationContext() async {
    final endpoints = [
      '/api/procedure/v1/organization-context',
      '/procedure/v1/organization-context',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          if (response.data is Map<String, dynamic>) {
            return response.data as Map<String, dynamic>;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // Get single instance
  Future<ProcedureInstance?> getProcedureInstance(String id) async {
    final endpoints = [
      '/api/procedure/v1/instances/$id',
      '/procedure/v1/instances/$id',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data : null;
          if (data != null) {
            return ProcedureInstance.fromJson(data as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // Create new instance
  Future<ProcedureInstance?> createProcedureInstance({
    required String definitionId,
    required String title,
    Map<String, dynamic>? processAttributeValues,
  }) async {
    final endpoints = [
      '/api/procedure/v1/instances',
      '/procedure/v1/instances',
    ];
    final payload = {
      'definitionId': definitionId,
      'title': title,
      'idempotencyKey': generateProcedureUuidV4(),
      ...?processAttributeValues != null ? {'processAttributeValues': processAttributeValues} : null,
    };
    for (final ep in endpoints) {
      try {
        final response = await _dio.post(ep, data: payload);
        if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data : null;
          if (data != null) {
            return ProcedureInstance.fromJson(data as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // Action on step: approve, complete, reject, return, cancel
  Future<ProcedureInstance?> applyProcedureAction({
    required String instanceId,
    required String action,
    String? comment,
    String? returnToStepId,
    Map<String, dynamic>? attributeValues,
  }) async {
    final endpoints = [
      '/api/procedure/v1/instances/$instanceId/actions',
      '/procedure/v1/instances/$instanceId/actions',
    ];
    final payload = {
      'action': action,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'idempotencyKey': generateProcedureUuidV4(),
      ...?returnToStepId != null ? {'returnToStepId': returnToStepId} : null,
      ...?attributeValues != null ? {'attributeValues': attributeValues} : null,
    };
    for (final ep in endpoints) {
      try {
        final response = await _dio.post(ep, data: payload);
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data : null;
          if (data != null) {
            return ProcedureInstance.fromJson(data as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return null;
  }



  // Post comment
  Future<ProcedureInstance?> postProcedureComment({
    required String instanceId,
    required String body,
  }) async {
    final endpoints = [
      '/api/procedure/v1/instances/$instanceId/comments',
      '/procedure/v1/instances/$instanceId/comments',
    ];
    final payload = {
      'body': body,
      'idempotencyKey': generateProcedureUuidV4(),
    };
    for (final ep in endpoints) {
      try {
        final response = await _dio.post(ep, data: payload);
        if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data : null;
          if (data != null) {
            return ProcedureInstance.fromJson(data as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // Get attachments
  Future<List<ProcedureAttachment>> getProcedureAttachments(String instanceId) async {
    final endpoints = [
      '/api/procedure/v1/instances/$instanceId/attachments',
      '/procedure/v1/instances/$instanceId/attachments',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep);
        if (response.statusCode == 200 && response.data != null) {
          final list = response.data as List<dynamic>? ?? [];
          return list.map((e) => ProcedureAttachment.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // Delete instance
  Future<bool> deleteProcedureInstance({
    required String instanceId,
    required String reason,
  }) async {
    final endpoints = [
      '/api/procedure/v1/instances/$instanceId/delete',
      '/procedure/v1/instances/$instanceId/delete',
    ];
    for (final ep in endpoints) {
      try {
        final response = await _dio.post(
          ep,
          data: {'reason': reason},
        );
        if (response.statusCode == 200 || response.statusCode == 204) {
          return true;
        }
      } catch (_) {}
    }
    return false;
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
