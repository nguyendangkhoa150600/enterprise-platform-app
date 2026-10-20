import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/workspace_models.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

class WorkspaceService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  WorkspaceService() {
    ApiClientHelper.configureDio(_dio);
  }

  // ==========================================
  // 1. CUSTOMERS (Khách hàng)
  // ==========================================
  Future<List<CustomerItem>> getCustomers({String? query}) async {
    final endpoints = [
      '/api/workspace/v1/customers',
      '/workspace/v1/customers',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          queryParameters: query != null && query.isNotEmpty ? {'query': query} : null,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data;
          if (raw is List) {
            return raw.map((e) => CustomerItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        }
      } catch (e) {
        debugPrint('[WorkspaceService] getCustomers error on $ep: $e');
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> getCustomerDetail(String id) async {
    final endpoints = [
      '/api/workspace/v1/customers/$id',
      '/workspace/v1/customers/$id',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data;
          if (raw is Map) return Map<String, dynamic>.from(raw);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool> createCustomer({
    required String code,
    required String name,
    String? note,
  }) async {
    final endpoints = [
      '/api/workspace/v1/customers',
      '/workspace/v1/customers',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.post(
          ep,
          data: {
            'code': code.trim(),
            'name': name.trim(),
            if (note != null && note.isNotEmpty) 'note': note.trim(),
          },
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 201) return true;
      } catch (e) {
        debugPrint('[WorkspaceService] createCustomer error on $ep: $e');
      }
    }
    return false;
  }

  Future<bool> updateCustomer(
    String id, {
    String? name,
    String? note,
  }) async {
    final endpoints = [
      '/api/workspace/v1/customers/$id',
      '/workspace/v1/customers/$id',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.patch(
          ep,
          data: {
            if (name != null) 'name': name.trim(),
            'note': note?.trim(),
          },
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
      } catch (_) {}
    }
    return false;
  }

  Future<bool> deleteCustomer(String id) async {
    final endpoints = [
      '/api/workspace/v1/customers/$id',
      '/workspace/v1/customers/$id',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.delete(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
      } catch (_) {}
    }
    return false;
  }

  // ==========================================
  // 2. CONTRACTS (Hợp đồng)
  // ==========================================
  Future<List<ContractItem>> getCustomerContracts(String customerId, [Map<String, String>? projectMap]) async {
    final endpoints = [
      '/api/workspace/v1/customers/$customerId/contracts',
      '/workspace/v1/customers/$customerId/contracts',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data;
          if (raw is List) {
            return raw.map((e) => ContractItem.fromJson(Map<String, dynamic>.from(e as Map), projectMap)).toList();
          }
        }
      } catch (e) {
        debugPrint('[WorkspaceService] getCustomerContracts error: $e');
      }
    }
    return [];
  }

  Future<bool> createContract({
    required String customerId,
    required String code,
    required String name,
    String status = 'draft',
    double? value,
    DateTime? signedDate,
    String? note,
    String? projectId,
  }) async {
    final endpoints = [
      '/api/workspace/v1/contracts',
      '/workspace/v1/contracts',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.post(
          ep,
          data: {
            'customerId': customerId,
            'code': code.trim(),
            'name': name.trim(),
            'status': status,
            if (value != null) 'value': value,
            if (signedDate != null) 'signedDate': signedDate.toIso8601String().substring(0, 10),
            if (note != null && note.isNotEmpty) 'note': note.trim(),
            if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
          },
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 201) return true;
      } catch (e) {
        debugPrint('[WorkspaceService] createContract error: $e');
      }
    }
    return false;
  }

  Future<bool> updateContract(
    String id, {
    String? name,
    String? status,
    double? value,
    DateTime? signedDate,
    String? note,
    String? projectId,
  }) async {
    final endpoints = [
      '/api/workspace/v1/contracts/$id',
      '/workspace/v1/contracts/$id',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.patch(
          ep,
          data: {
            if (name != null) 'name': name.trim(),
            if (status != null) 'status': status,
            'value': value,
            'signedDate': signedDate?.toIso8601String().substring(0, 10),
            'note': note?.trim(),
            'projectId': projectId,
          },
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
      } catch (_) {}
    }
    return false;
  }

  Future<bool> deleteContract(String id) async {
    final endpoints = [
      '/api/workspace/v1/contracts/$id',
      '/workspace/v1/contracts/$id',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.delete(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
      } catch (_) {}
    }
    return false;
  }

  // ==========================================
  // 3. PROJECTS (Dự án & Phân quyền)
  // ==========================================
  Future<List<ProjectItem>> getProjects({
    String? status,
    String? projectType,
    String? customerId,
    Map<String, String>? customerMap,
  }) async {
    final endpoints = [
      '/api/workspace/v1/projects',
      '/workspace/v1/projects',
    ];
    for (final ep in endpoints) {
      try {
        final query = <String, dynamic>{};
        if (status != null && status != 'all') query['status'] = status;
        if (projectType != null && projectType.isNotEmpty) query['projectType'] = projectType;
        if (customerId != null && customerId.isNotEmpty) query['customerId'] = customerId;

        final res = await _dio.get(
          ep,
          queryParameters: query.isNotEmpty ? query : null,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data;
          if (raw is List) {
            return raw.map((e) => ProjectItem.fromJson(Map<String, dynamic>.from(e as Map), customerMap)).toList();
          }
        }
      } catch (e) {
        debugPrint('[WorkspaceService] getProjects error on $ep: $e');
      }
    }
    return [];
  }

  Future<List<ProjectMemberItem>> getProjectMembers(String projectId) async {
    final endpoints = [
      '/api/workspace/v1/projects/$projectId/members',
      '/workspace/v1/projects/$projectId/members',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['data'] ?? res.data['members'] ?? res.data;
          if (raw is List) {
            return raw.map((e) => ProjectMemberItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  Future<bool> setProjectMembers(String projectId, List<Map<String, String>> members) async {
    final endpoints = [
      '/api/workspace/v1/projects/$projectId/members',
      '/workspace/v1/projects/$projectId/members',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.put(
          ep,
          data: {'members': members},
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
      } catch (_) {}
    }
    return false;
  }

  // ==========================================
  // 4. STANDALONE TASKS (Việc ngoài dự án)
  // ==========================================
  Future<List<StandaloneTaskItem>> getStandaloneTasks({String scope = 'assigned_to_me'}) async {
    final endpoints = [
      '/api/workspace/v1/standalone-tasks',
      '/workspace/v1/standalone-tasks',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.get(
          ep,
          queryParameters: {'scope': scope},
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data['items'] ?? res.data['data'] ?? res.data;
          if (raw is List) {
            return raw.map((e) => StandaloneTaskItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        }
      } catch (e) {
        debugPrint('[WorkspaceService] getStandaloneTasks error on $ep: $e');
      }
    }
    return [];
  }

  Future<bool> createStandaloneTask({
    required String title,
    String? description,
    String priority = 'normal',
    required String assigneeUserId,
    DateTime? dueDate,
  }) async {
    final endpoints = [
      '/api/workspace/v1/standalone-tasks',
      '/workspace/v1/standalone-tasks',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.post(
          ep,
          data: {
            'title': title.trim(),
            if (description != null && description.isNotEmpty) 'description': description.trim(),
            'priority': priority,
            'assigneeUserId': assigneeUserId,
            if (dueDate != null) 'dueDate': dueDate.toIso8601String().substring(0, 10),
          },
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 201) return true;
      } catch (e) {
        debugPrint('[WorkspaceService] createStandaloneTask error: $e');
      }
    }
    return false;
  }

  Future<bool> changeStandaloneTaskStatus(String id, String status, {String? note}) async {
    final endpoints = [
      '/api/workspace/v1/standalone-tasks/$id/status',
      '/workspace/v1/standalone-tasks/$id/status',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _dio.patch(
          ep,
          data: {
            'status': status,
            if (note != null && note.isNotEmpty) 'note': note.trim(),
          },
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
      } catch (_) {}
    }
    return false;
  }
}
