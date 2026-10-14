import 'package:dio/dio.dart';
import '../models/platform_models.dart';
import '../providers/auth_provider.dart';
import '../utils/error_handler.dart';
import 'api_client_helper.dart';

class PlatformService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  PlatformService() {
    ApiClientHelper.configureDio(_dio);
  }

  // Fetch Users
  Future<List<TenantUser>> getTenantUsers() async {
    try {
      final response = await _dio.get('/platform/v1/tenant-users');
      if (response.statusCode == 200 && response.data != null) {
        dynamic rawList;
        if (response.data is List) {
          rawList = response.data;
        } else if (response.data is Map) {
          rawList = response.data['users'] ?? response.data['data'] ?? response.data['items'];
        }
        if (rawList is List) {
          return rawList.map((e) => TenantUser.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Create User
  Future<({bool success, String? error, TenantUser? user})> createUser({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/platform/v1/tenant-users',
        data: {
          'fullName': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        TenantUser? newUser;
        if (response.data != null && response.data is Map && response.data['user'] != null) {
          newUser = TenantUser.fromJson(response.data['user'] as Map<String, dynamic>);
        }
        return (success: true, error: null, user: newUser);
      }
      return (success: false, error: 'Không thể tạo người dùng (Mã lỗi ${response.statusCode}).', user: null);
    } catch (e) {
      final msg = ApiErrorHandler.parse(e, defaultMessage: 'Không thể tạo người dùng. Vui lòng thử lại.');
      return (success: false, error: msg, user: null);
    }
  }

  // Update User Status, Name, Email, Password, Role
  Future<({bool success, String? error})> updateUser(
    String id, {
    String? fullName,
    String? email,
    String? password,
    String? status,
    String? systemRole,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['fullName'] = fullName.trim();
      if (email != null) data['email'] = email.trim().toLowerCase();
      if (password != null && password.isNotEmpty) data['password'] = password;
      if (status != null) data['status'] = status;
      if (systemRole != null) {
        data['systemRole'] = systemRole;
        data['role'] = systemRole;
      }

      final response = await _dio.patch('/platform/v1/tenant-users/$id', data: data);
      if (response.statusCode == 200) {
        return (success: true, error: null);
      }
      return (success: false, error: 'Cập nhật thất bại (Mã lỗi ${response.statusCode}).');
    } catch (e) {
      final msg = ApiErrorHandler.parse(e, defaultMessage: 'Không thể cập nhật thông tin người dùng.');
      return (success: false, error: msg);
    }
  }

  // Delete User
  Future<({bool success, String? error})> deleteUser(String id) async {
    try {
      final response = await _dio.delete('/platform/v1/tenant-users/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        return (success: true, error: null);
      }
      return (success: false, error: 'Không thể xóa người dùng (Mã lỗi ${response.statusCode}).');
    } catch (e) {
      final msg = ApiErrorHandler.parse(e, defaultMessage: 'Không thể xóa người dùng.');
      return (success: false, error: msg);
    }
  }

  // Fetch Organization Snapshot
  Future<OrganizationSnapshot> getOrganizationSnapshot() async {
    try {
      final response = await _dio.get('/platform/v1/tenant-organization/core-snapshot');
      if (response.statusCode == 200 && response.data != null) {
        return OrganizationSnapshot.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return OrganizationSnapshot(nodes: const [], nodeTypes: const [], assignments: const [], users: const []);
  }

  // Create Assignment (Bổ nhiệm nhân sự)
  Future<bool> createAssignment({
    required String userId,
    required String nodeId,
    required bool isPrimary,
    String? startDate,
    String? endDate,
    String? note,
    String status = 'active',
  }) async {
    try {
      final response = await _dio.post(
        '/platform/v1/tenant-organization/assignments',
        data: {
          'userId': userId,
          'nodeId': nodeId,
          'isPrimary': isPrimary,
          'startDate': startDate,
          'endDate': endDate,
          'note': note,
          'status': status,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // Update Assignment
  Future<bool> updateAssignment(
    String id, {
    String? nodeId,
    bool? isPrimary,
    String? startDate,
    String? endDate,
    String? note,
    String? status,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (nodeId != null) data['nodeId'] = nodeId;
      if (isPrimary != null) data['isPrimary'] = isPrimary;
      if (startDate != null) data['startDate'] = startDate;
      if (endDate != null) data['endDate'] = endDate;
      if (note != null) data['note'] = note;
      if (status != null) data['status'] = status;

      final response = await _dio.patch(
        '/platform/v1/tenant-organization/assignments/$id',
        data: data,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Delete Assignment
  Future<bool> deleteAssignment(String id) async {
    try {
      final response = await _dio.delete('/platform/v1/tenant-organization/assignments/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // Create Org Node
  Future<bool> createNode({
    required String treeId,
    String? parentId,
    required String nodeTypeId,
    required String code,
    required String name,
    String? description,
    int sortOrder = 0,
    String status = 'active',
  }) async {
    try {
      final response = await _dio.post(
        '/platform/v1/tenant-organization/nodes',
        data: {
          'treeId': treeId,
          if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
          'nodeTypeId': nodeTypeId,
          'code': code,
          'name': name,
          if (description != null) 'description': description,
          'sortOrder': sortOrder,
          'status': status,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // Update Org Node
  Future<bool> updateNode(
    String id, {
    String? parentId,
    String? nodeTypeId,
    String? code,
    String? name,
    String? description,
    int? sortOrder,
    String? status,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (parentId != null) data['parentId'] = parentId.isEmpty ? null : parentId;
      if (nodeTypeId != null) data['nodeTypeId'] = nodeTypeId;
      if (code != null) data['code'] = code;
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (sortOrder != null) data['sortOrder'] = sortOrder;
      if (status != null) data['status'] = status;

      final response = await _dio.patch(
        '/platform/v1/tenant-organization/nodes/$id',
        data: data,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Delete Org Node
  Future<bool> deleteNode(String id) async {
    try {
      final response = await _dio.delete('/platform/v1/tenant-organization/nodes/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // Fetch Module Catalog
  Future<List<ModuleCatalogItem>> getModuleCatalog() async {
    try {
      final response = await _dio.get('/platform/v1/modules/catalog');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['modules'] as List<dynamic>? ?? [];
        if (rawList.isNotEmpty) {
          return rawList.map((e) => ModuleCatalogItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Request Module Activation
  Future<bool> requestModuleActivation(String moduleKey) async {
    try {
      final response = await _dio.post('/platform/v1/modules/$moduleKey/activation-requests');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // Fetch Roles
  Future<List<TenantRole>> getTenantRoles() async {
    try {
      final response = await _dio.get('/platform/v1/tenant-roles');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['roles'] as List<dynamic>? ?? (response.data is List ? response.data as List<dynamic> : []);
        if (rawList.isNotEmpty) {
          return rawList.map((e) => TenantRole.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Fetch Permissions
  Future<List<TenantPermission>> getTenantPermissions() async {
    try {
      final response = await _dio.get('/platform/v1/tenant-permissions');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['permissions'] as List<dynamic>? ?? (response.data is List ? response.data as List<dynamic> : []);
        if (rawList.isNotEmpty) {
          return rawList.map((e) => TenantPermission.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Create Role
  Future<bool> createRole({
    required String name,
    required String key,
    String? description,
    List<String> moduleKeys = const [],
    List<String> actionKeys = const [],
    List<String> permissionIds = const [],
    List<String> userIds = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/platform/v1/tenant-roles',
        data: {
          'name': name,
          'key': key,
          if (description != null) 'description': description,
          'moduleKeys': moduleKeys,
          'actionKeys': actionKeys,
          'permissionIds': permissionIds,
          'userIds': userIds,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // Update Role
  Future<bool> updateRole(
    String id, {
    String? name,
    String? key,
    String? description,
    List<String>? moduleKeys,
    List<String>? actionKeys,
    List<String>? permissionIds,
    List<String>? userIds,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (key != null) data['key'] = key;
      if (description != null) data['description'] = description;
      if (moduleKeys != null) data['moduleKeys'] = moduleKeys;
      if (actionKeys != null) data['actionKeys'] = actionKeys;
      if (permissionIds != null) data['permissionIds'] = permissionIds;
      if (userIds != null) data['userIds'] = userIds;

      final response = await _dio.patch('/platform/v1/tenant-roles/$id', data: data);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Delete Role
  Future<bool> deleteRole(String id) async {
    try {
      final response = await _dio.delete('/platform/v1/tenant-roles/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // Assign Roles to User
  Future<({bool success, String? error})> assignUserRoles(String userId, List<String> roleIds) async {
    try {
      final response = await _dio.post(
        '/platform/v1/tenant-users/$userId/roles',
        data: {'roleIds': roleIds},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return (success: true, error: null);
      }
    } catch (_) {}

    try {
      final response = await _dio.put(
        '/platform/v1/tenant-users/$userId',
        data: {'roleIds': roleIds, 'roles': roleIds},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return (success: true, error: null);
      }
    } catch (_) {}

    return (success: false, error: 'Không thể phân quyền người dùng.');
  }
}
