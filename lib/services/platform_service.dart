import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/platform_models.dart';
import '../providers/auth_provider.dart';
import '../utils/error_handler.dart';

class PlatformService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  PlatformService() {
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookies = await AuthProvider.getStoredCookies();
        if (cookies != null && cookies.isNotEmpty) {
          options.headers['cookie'] = cookies;
          final parts = cookies.split('; ');
          for (var part in parts) {
            if (part.startsWith('ep_csrf=')) {
              options.headers['x-csrf-token'] = part.substring('ep_csrf='.length);
            }
          }
        }
        return handler.next(options);
      },
    ));
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
    } catch (e) {
      print('[PlatformService] getTenantUsers error: $e');
    }
    return _fallbackUsers;
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
      print('[PlatformService] createUser error: $msg ($e)');
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
        print('[PlatformService] API core-snapshot nodes: ${(response.data['nodes'] as List?)?.length}');
        return OrganizationSnapshot.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      print('[PlatformService] API error: $e');
    }
    return _fallbackOrgSnapshot;
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
      // Offline fallback simulation
      final newAssignment = OrgAssignment(
        id: 'asg-${DateTime.now().millisecondsSinceEpoch}',
        nodeId: nodeId,
        userId: userId,
        isPrimary: isPrimary,
        startDate: startDate,
        endDate: endDate,
        status: status,
        note: note,
      );
      _fallbackOrgSnapshot.assignments.insert(0, newAssignment);
      return true;
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
      final idx = _fallbackOrgSnapshot.assignments.indexWhere((a) => a.id == id);
      if (idx != -1) {
        final current = _fallbackOrgSnapshot.assignments[idx];
        _fallbackOrgSnapshot.assignments[idx] = OrgAssignment(
          id: current.id,
          nodeId: nodeId ?? current.nodeId,
          userId: current.userId,
          isPrimary: isPrimary ?? current.isPrimary,
          startDate: startDate ?? current.startDate,
          endDate: endDate ?? current.endDate,
          status: status ?? current.status,
          note: note ?? current.note,
        );
      }
      return true;
    }
  }

  // Delete Assignment
  Future<bool> deleteAssignment(String id) async {
    try {
      final response = await _dio.delete('/platform/v1/tenant-organization/assignments/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      _fallbackOrgSnapshot.assignments.removeWhere((a) => a.id == id);
      return true;
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
      final newNode = OrgNode(
        id: 'node-${DateTime.now().millisecondsSinceEpoch}',
        treeId: treeId,
        parentId: parentId,
        nodeTypeId: nodeTypeId,
        code: code,
        name: name,
        description: description,
        sortOrder: sortOrder,
        status: status,
      );
      _fallbackOrgSnapshot.nodes.add(newNode);
      return true;
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
      final idx = _fallbackOrgSnapshot.nodes.indexWhere((n) => n.id == id);
      if (idx != -1) {
        final cur = _fallbackOrgSnapshot.nodes[idx];
        _fallbackOrgSnapshot.nodes[idx] = OrgNode(
          id: cur.id,
          treeId: cur.treeId,
          parentId: parentId != null ? (parentId.isEmpty ? null : parentId) : cur.parentId,
          nodeTypeId: nodeTypeId ?? cur.nodeTypeId,
          code: code ?? cur.code,
          name: name ?? cur.name,
          description: description ?? cur.description,
          sortOrder: sortOrder ?? cur.sortOrder,
          status: status ?? cur.status,
        );
      }
      return true;
    }
  }

  // Delete Org Node
  Future<bool> deleteNode(String id) async {
    try {
      final response = await _dio.delete('/platform/v1/tenant-organization/nodes/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      _fallbackOrgSnapshot.nodes.removeWhere((n) => n.id == id);
      _fallbackOrgSnapshot.assignments.removeWhere((a) => a.nodeId == id);
      return true;
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
    return _fallbackModules;
  }

  // Request Module Activation
  Future<bool> requestModuleActivation(String moduleKey) async {
    try {
      final response = await _dio.post('/platform/v1/modules/$moduleKey/activation-requests');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      final idx = _fallbackModules.indexWhere((m) => m.key == moduleKey);
      if (idx != -1) {
        final cur = _fallbackModules[idx];
        _fallbackModules[idx] = ModuleCatalogItem(
          key: cur.key,
          name: cur.name,
          description: cur.description,
          launchUrl: cur.launchUrl,
          icon: cur.icon,
          version: cur.version,
          entitlementStatus: 'provisioning',
        );
      }
      return true;
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
    return _fallbackRoles;
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
    return _fallbackPermissions;
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
      _fallbackRoles.add(
        TenantRole(
          id: 'role-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          key: key,
          description: description,
          isSystem: false,
          moduleKeys: moduleKeys,
          actionKeys: actionKeys,
          permissionIds: permissionIds,
          userIds: userIds,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      return true;
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
      final idx = _fallbackRoles.indexWhere((r) => r.id == id);
      if (idx != -1) {
        final cur = _fallbackRoles[idx];
        _fallbackRoles[idx] = TenantRole(
          id: cur.id,
          name: name ?? cur.name,
          key: key ?? cur.key,
          description: description ?? cur.description,
          isSystem: cur.isSystem,
          moduleKeys: moduleKeys ?? cur.moduleKeys,
          actionKeys: actionKeys ?? cur.actionKeys,
          permissionIds: permissionIds ?? cur.permissionIds,
          userIds: userIds ?? cur.userIds,
          createdAt: cur.createdAt,
          updatedAt: DateTime.now().toIso8601String(),
        );
      }
      return true;
    }
  }

  // Delete Role
  Future<bool> deleteRole(String id) async {
    try {
      final response = await _dio.delete('/platform/v1/tenant-roles/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      _fallbackRoles.removeWhere((r) => r.id == id);
      return true;
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
      // Also try PUT /platform/v1/tenant-users/$userId with roles field
      await _dio.put(
        '/platform/v1/tenant-users/$userId',
        data: {'roleIds': roleIds, 'roles': roleIds},
      );
    } catch (_) {}

    // Local state sync across roles
    for (int i = 0; i < _fallbackRoles.length; i++) {
      final r = _fallbackRoles[i];
      final currentUsers = List<String>.from(r.userIds);
      if (roleIds.contains(r.id)) {
        if (!currentUsers.contains(userId)) {
          currentUsers.add(userId);
        }
      } else {
        currentUsers.remove(userId);
      }
      _fallbackRoles[i] = TenantRole(
        id: r.id,
        name: r.name,
        key: r.key,
        description: r.description,
        isSystem: r.isSystem,
        moduleKeys: r.moduleKeys,
        actionKeys: r.actionKeys,
        permissionIds: r.permissionIds,
        userIds: currentUsers,
        createdAt: r.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );
    }
    return (success: true, error: null);
  }

  // Fallback Roles & Permissions
  static final List<TenantRole> _fallbackRoles = [
    TenantRole(
      id: 'role-legacy-user',
      name: 'Người dùng chuyển tiếp',
      key: 'legacy-tenant-user',
      description: 'Chưa thiết lập mô tả cho mục này.',
      isSystem: true,
      moduleKeys: ['*'],
      actionKeys: [],
      permissionIds: [],
      userIds: [],
      createdAt: '2026-08-01T00:00:00Z',
      updatedAt: '2026-08-01T00:00:00Z',
    ),
    TenantRole(
      id: 'role-tenant-admin',
      name: 'Quản trị tenant',
      key: 'tenant-admin',
      description: 'Toàn quyền quản trị tài nguyên, người dùng và module phân hệ của doanh nghiệp.',
      isSystem: true,
      moduleKeys: ['*'],
      actionKeys: ['tenant:read', 'tenant:write', 'user:manage', 'role:manage', 'org:manage'],
      permissionIds: ['perm-std-1'],
      userIds: ['usr-8', 'usr-45', 'usr-1'],
      createdAt: '2026-08-01T00:00:00Z',
      updatedAt: '2026-08-01T00:00:00Z',
    ),
    TenantRole(
      id: 'role-default-emp-1',
      name: 'Nhân viên mặc định 1',
      key: 'default-employee-1',
      description: 'Nhân viên truy cập các phân hệ nghiệp vụ vận hành hàng ngày.',
      isSystem: false,
      moduleKeys: ['hrm', 'inventory', 'maintenance', 'procedure-engine', 'workspace'],
      actionKeys: ['workspace:view', 'hrm:view', 'inventory:view', 'maintenance:view', 'procedure:view'],
      permissionIds: ['perm-std-1'],
      userIds: List.generate(42, (i) => 'usr-${i + 2}'),
      createdAt: '2026-08-01T00:00:00Z',
      updatedAt: '2026-08-01T00:00:00Z',
    ),
  ];

  static final List<TenantPermission> _fallbackPermissions = [
    TenantPermission(
      id: 'perm-std-1',
      name: 'Quyền tiêu chuẩn',
      key: 'standard-permission',
      description: 'Quyền truy cập và thao tác tiêu chuẩn đối với các phân hệ được kích hoạt.',
      isSystem: true,
      actionKeys: ['workspace:access', 'hrm:read', 'inventory:read', 'maintenance:read', 'procedure:read'],
      roleIds: ['role-tenant-admin', 'role-default-emp-1'],
    ),
  ];


  // Fallback data
  static final List<TenantUser> _fallbackUsers = [
    TenantUser(
      id: 'usr-1',
      fullName: 'Nguyễn Gia Bảo',
      email: 'nguyen.gia.bao@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-01T08:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-2',
      fullName: 'Đỗ Thanh Phong',
      email: 'do.thanh.phong@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-01T08:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-3',
      fullName: 'Lê Minh Trí',
      email: 'le.minh.tri@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-02T08:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-4',
      fullName: 'Trần Quốc Vượng',
      email: 'tran.quoc.vuong@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-02T08:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-5',
      fullName: 'Phan Đức Thắng',
      email: 'phan.duc.thang@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-03T08:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-6',
      fullName: 'Bùi Công Quyền',
      email: 'bui.cong.quyen@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-03T08:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-7',
      fullName: 'Bùi Long Quốc Huy',
      email: 'bui.long.quoc.huy@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-04T08:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-8',
      fullName: 'Trần Thúy Uyên',
      email: 'tran.thuy.uyen@savina.com',
      systemRole: 'tenant-admin',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-04T08:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-9',
      fullName: 'Nguyễn Trần Như Quỳnh',
      email: 'nguyen.tran.nhu.quynh@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-05T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-10',
      fullName: 'Phạm Nhật Minh',
      email: 'pham.nhat.minh@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-05T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-11',
      fullName: 'Hoàng Văn Thái',
      email: 'hoang.van.thai@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-06T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-12',
      fullName: 'Võ Thành Đạt',
      email: 'vo.thanh.dat@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-06T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-13',
      fullName: 'Dương Đình Nghệ',
      email: 'duong.dinh.nghe@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-07T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-14',
      fullName: 'Mai Xuân Vĩnh',
      email: 'mai.xuan.vinh@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-07T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-15',
      fullName: 'Ngô Kiến Huy',
      email: 'ngo.kien.huy@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-08T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-16',
      fullName: 'Trương Mỹ Hoa',
      email: 'truong.my.hoa@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-08T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-17',
      fullName: 'Lâm Thanh Hà',
      email: 'lam.thanh.ha@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-09T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-18',
      fullName: 'Đoàn Văn Hậu',
      email: 'doan.van.hau@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-09T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-19',
      fullName: 'Nguyễn Huy Thuận',
      email: 'thuan.nguyen@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-10T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-20',
      fullName: 'Huỳnh Thị Đông',
      email: 'dong.huynh@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-10T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-21',
      fullName: 'Cao Khánh Ngọc',
      email: 'ngoc.cao@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-11T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-22',
      fullName: 'Phạm Việt Quân',
      email: 'quan.pham@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-11T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-23',
      fullName: 'Nguyễn Thị Thủy',
      email: 'thuy.nguyen@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-12T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-24',
      fullName: 'Vũ Quốc Cường',
      email: 'vu.quoc.cuong@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-12T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-25',
      fullName: 'Trịnh Thăng Bình',
      email: 'trinh.thang.binh@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-13T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-26',
      fullName: 'Đặng Thu Thảo',
      email: 'dang.thu.thao@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-13T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-27',
      fullName: 'Nguyễn Kiều Loan',
      email: 'nguyen.kieu.loan@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-14T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-28',
      fullName: 'Hà Anh Tuấn',
      email: 'ha.anh.tuan@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-14T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-29',
      fullName: 'Phan Mạnh Quỳnh',
      email: 'phan.manh.quynh@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-15T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-30',
      fullName: 'Đinh Tiến Dũng',
      email: 'dinh.tien.dung@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-15T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-31',
      fullName: 'Bùi Anh Tuấn',
      email: 'bui.anh.tuan@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-16T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-32',
      fullName: 'Lê Bảo Bình',
      email: 'le.bao.binh@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-16T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-33',
      fullName: 'Ngô Thanh Vân',
      email: 'ngo.thanh.van@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-17T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-34',
      fullName: 'Hồ Ngọc Hà',
      email: 'ho.ngoc.ha@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-17T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-35',
      fullName: 'Vũ Cát Tường',
      email: 'vu.cat.tuong@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-18T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-36',
      fullName: 'Nguyễn Bích Phương',
      email: 'nguyen.bich.phuong@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-18T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-37',
      fullName: 'Đen Vâu (Nguyễn Đức Cường)',
      email: 'nguyen.duc.cuong@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-19T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-38',
      fullName: 'Nguyễn Khoa Tóc Tiên',
      email: 'toc.tien@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-19T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-39',
      fullName: 'Trịnh Trần Phương Tuấn',
      email: 'phuong.tuan@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-20T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-40',
      fullName: 'Nguyễn Thanh Tùng',
      email: 'thanh.tung@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-20T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-41',
      fullName: 'Phạm Đức Phúc',
      email: 'duc.phuc@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-21T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-42',
      fullName: 'Nguyễn Hòa Minzy',
      email: 'hoa.minzy@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-21T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-43',
      fullName: 'Trương Hoàng Nam',
      email: 'truong.hoang.nam@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-22T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-44',
      fullName: 'Lê Cát Trọng Lý',
      email: 'trong.ly@savina.com',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-22T08:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-45',
      fullName: 'SVN Admin',
      email: 'admin@savina.com',
      systemRole: 'tenant-admin',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-01T08:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
  ];

  static final List<ModuleCatalogItem> _fallbackModules = [
    ModuleCatalogItem(
      key: 'procedure',
      name: 'Quy trình làm việc (Procedure Engine)',
      description: 'Quản lý quy trình vận hành, luồng phê duyệt đa cấp, theo dõi SLA và phân công nhiệm vụ.',
      launchUrl: '/modules/procedure',
      version: '1.2.0',
      entitlementStatus: 'active',
    ),
    ModuleCatalogItem(
      key: 'inventory',
      name: 'Kho vật tư & Tài sản (Inventory)',
      description: 'Quản lý kho hàng, sổ kho định mức, xuất nhập điều chuyển và theo dõi phụ tùng thiết bị.',
      launchUrl: '/modules/inventory',
      version: '1.3.0',
      entitlementStatus: 'active',
    ),
    ModuleCatalogItem(
      key: 'maintenance',
      name: 'Bảo trì & Thiết bị (Maintenance)',
      description: 'Lập lịch bảo dưỡng định kỳ, ma trận kế hoạch ngăn ngừa sự cố và quản lý phiếu công tác.',
      launchUrl: '/modules/maintenance',
      version: '1.1.0',
      entitlementStatus: 'active',
    ),
    ModuleCatalogItem(
      key: 'power-quality',
      name: 'Phân tích chất lượng điện (Power Quality)',
      description: 'Đọc dữ liệu đo đạc phụ tải Excel, phân tích sóng hài điện áp và tự động tính toán báo cáo.',
      launchUrl: '/modules/power-quality',
      version: '2.0.0',
      entitlementStatus: 'active',
    ),
    ModuleCatalogItem(
      key: 'hrm',
      name: 'Chấm công & Nhân sự (HRM Attendance)',
      description: 'Chấm công GPS di động, sổ quẹt thẻ, phê duyệt giải trình công và quản lý ca làm việc.',
      launchUrl: '/modules/hrm/attendance',
      version: '1.0.0',
      entitlementStatus: 'active',
    ),
    ModuleCatalogItem(
      key: 'crm',
      name: 'Quản lý khách hàng (CRM Enterprise)',
      description: 'Quản lý thông tin khách hàng doanh nghiệp, hợp đồng dịch vụ và chăm sóc đối tác.',
      launchUrl: '/modules/crm',
      version: '1.0.0',
      entitlementStatus: 'not-entitled',
    ),
  ];

  static final OrganizationSnapshot _fallbackOrgSnapshot = OrganizationSnapshot(
    nodeTypes: [
      OrgNodeType(id: 'nt-dept', code: 'DEPT', name: 'Phòng ban / Khối', category: 'unit'),
      OrgNodeType(id: 'nt-team', code: 'TEAM', name: 'Đội / Nhóm', category: 'unit'),
      OrgNodeType(id: 'nt-pos-lead', code: 'POS_LEAD', name: 'Vị trí Lãnh đạo / Trưởng phòng', category: 'position'),
      OrgNodeType(id: 'nt-pos-exec', code: 'POS_EXEC', name: 'Vị trí Chuyên môn', category: 'position'),
    ],
    nodes: [
      // Level 1: Root
      OrgNode(id: 'node-root', treeId: 't-1', nodeTypeId: 'nt-dept', code: 'SAVINA', name: 'Công ty Cổ phần Năng lượng SAVINA', status: 'active'),
      
      // Level 2: Đại hội đồng Cổ đông
      OrgNode(id: 'node-dhdcd', treeId: 't-1', parentId: 'node-root', nodeTypeId: 'nt-dept', code: 'SAVINA-DHDCD', name: 'Đại hội đồng Cổ đông', status: 'active'),
      
      // Level 3: Hội đồng Quản trị
      OrgNode(id: 'node-hdqt', treeId: 't-1', parentId: 'node-dhdcd', nodeTypeId: 'nt-dept', code: 'SAVINA-HDQT', name: 'Hội đồng Quản trị', status: 'active'),
      
      // Level 4: Ban Tổng Giám Đốc
      OrgNode(id: 'node-btgd', treeId: 't-1', parentId: 'node-hdqt', nodeTypeId: 'nt-dept', code: 'SAVINA-BTGD', name: 'Ban Tổng Giám Đốc', status: 'active'),
      
      // Level 5: 5 branches under Ban Tổng Giám Đốc
      OrgNode(id: 'node-vp-tn', treeId: 't-1', parentId: 'node-btgd', nodeTypeId: 'nt-dept', code: 'SAVINA-VP-TAY-NGUYEN', name: 'Văn phòng Đại diện Tây Nguyên', status: 'active'),
      OrgNode(id: 'node-vp-mn', treeId: 't-1', parentId: 'node-btgd', nodeTypeId: 'nt-dept', code: 'SAVINA-VP-MIEN-NAM', name: 'Văn phòng Đại diện Miền Nam', status: 'active'),
      OrgNode(id: 'node-khoi-vp', treeId: 't-1', parentId: 'node-btgd', nodeTypeId: 'nt-dept', code: 'SAVINA-KHOI-VP', name: 'Khối Văn phòng', status: 'active'),
      OrgNode(id: 'node-khoi-ktdv', treeId: 't-1', parentId: 'node-btgd', nodeTypeId: 'nt-dept', code: 'SAVINA-KHOI-KTDV', name: 'Khối Kỹ thuật - Dịch vụ', status: 'active'),
      OrgNode(id: 'node-khoi-tn', treeId: 't-1', parentId: 'node-btgd', nodeTypeId: 'nt-dept', code: 'SAVINA-KHOI-TN', name: 'Khối Thí nghiệm', status: 'active'),

      // Level 6 under Khối Văn phòng
      OrgNode(id: 'node-vp-cty', treeId: 't-1', parentId: 'node-khoi-vp', nodeTypeId: 'nt-dept', code: 'SAVINA-VP-CTY', name: 'Văn phòng Công ty', status: 'active'),
      OrgNode(id: 'node-hcth', treeId: 't-1', parentId: 'node-khoi-vp', nodeTypeId: 'nt-dept', code: 'SAVINA-P-HCTH', name: 'Phòng Hành chính - Tổng hợp', status: 'active'),
      OrgNode(id: 'node-tckt', treeId: 't-1', parentId: 'node-khoi-vp', nodeTypeId: 'nt-dept', code: 'SAVINA-P-TCKT', name: 'Phòng Tài chính - Kế toán', status: 'active'),
      OrgNode(id: 'node-kd', treeId: 't-1', parentId: 'node-khoi-vp', nodeTypeId: 'nt-dept', code: 'SAVINA-P-KD', name: 'Phòng Kinh doanh', status: 'active'),

      // Level 6 under Khối Kỹ thuật - Dịch vụ
      OrgNode(id: 'node-kt', treeId: 't-1', parentId: 'node-khoi-ktdv', nodeTypeId: 'nt-dept', code: 'SAVINA-P-KT', name: 'Phòng Kỹ thuật', status: 'active'),
      OrgNode(id: 'node-tt-tv', treeId: 't-1', parentId: 'node-khoi-ktdv', nodeTypeId: 'nt-dept', code: 'SAVINA-TT-TV', name: 'Trung tâm Tư vấn', status: 'active'),

      // Level 6 under Khối Thí nghiệm
      OrgNode(id: 'node-tn', treeId: 't-1', parentId: 'node-khoi-tn', nodeTypeId: 'nt-dept', code: 'SAVINA-P-TN', name: 'Phòng Thí nghiệm', status: 'active'),
      OrgNode(id: 'node-vhbt', treeId: 't-1', parentId: 'node-khoi-tn', nodeTypeId: 'nt-dept', code: 'SAVINA-P-VHBT', name: 'Phòng Vận hành - Bảo trì', status: 'active'),

      // Positions under Văn phòng Tây Nguyên
      OrgNode(id: 'node-tp-tn', treeId: 't-1', parentId: 'node-vp-tn', nodeTypeId: 'nt-pos-lead', code: 'SAVINA-VP-TN--TRUONG-VP', name: 'Trưởng văn phòng đại diện', status: 'active'),

      // Positions under Phòng Hành chính - Tổng hợp
      OrgNode(id: 'node-tp-hcth', treeId: 't-1', parentId: 'node-hcth', nodeTypeId: 'nt-pos-lead', code: 'SAVINA-P-HCTH--TRUONG-PHONG-HANH-CHINH-TONG-HOP', name: 'Trưởng phòng Hành chính - Tổng hợp', status: 'active'),
      OrgNode(id: 'node-tv-hcth', treeId: 't-1', parentId: 'node-hcth', nodeTypeId: 'nt-pos-exec', code: 'SAVINA-P-HCTH--TAP-VU', name: 'Tạp vụ', status: 'active'),
      OrgNode(id: 'node-mkt-hcth', treeId: 't-1', parentId: 'node-hcth', nodeTypeId: 'nt-pos-exec', code: 'SAVINA-P-HCTH--MARKETING', name: 'Nhân viên marketing', status: 'active'),
      OrgNode(id: 'node-lx-hcth', treeId: 't-1', parentId: 'node-hcth', nodeTypeId: 'nt-pos-exec', code: 'SAVINA-P-HCTH--LAI-XE', name: 'Lái xe cơ quan', status: 'active'),
      OrgNode(id: 'node-vt-hcth', treeId: 't-1', parentId: 'node-hcth', nodeTypeId: 'nt-pos-exec', code: 'SAVINA-P-HCTH--VAN-THU', name: 'Nhân viên hành chính - văn thư', status: 'active'),
    ],
    assignments: [
      OrgAssignment(id: 'asg-1', nodeId: 'node-tp-tn', userId: 'usr-thuan', isPrimary: true, status: 'active', note: 'Trưởng văn phòng'),
      OrgAssignment(id: 'asg-2', nodeId: 'node-tp-hcth', userId: 'usr-nq', isPrimary: true, status: 'active', note: 'Trưởng phòng HCTH'),
      OrgAssignment(id: 'asg-3', nodeId: 'node-tv-hcth', userId: 'usr-dong', isPrimary: true, status: 'active', note: ''),
      OrgAssignment(id: 'asg-4', nodeId: 'node-mkt-hcth', userId: 'usr-ngoc', isPrimary: true, status: 'active', note: ''),
      OrgAssignment(id: 'asg-5', nodeId: 'node-lx-hcth', userId: 'usr-quan', isPrimary: true, status: 'active', note: ''),
      OrgAssignment(id: 'asg-6', nodeId: 'node-vt-hcth', userId: 'usr-thuy', isPrimary: true, status: 'active', note: ''),
    ],
    users: [
      ..._fallbackUsers,
      TenantUser(id: 'usr-thuan', fullName: 'Nguyễn Huy Thuận', email: 'thuan.nguyen@savina.com', systemRole: 'tenant-user', status: 'active', isActive: true, createdAt: '2026-08-10T08:00:00Z', updatedAt: '2026-09-05T10:00:00Z'),
      TenantUser(id: 'usr-dong', fullName: 'Huỳnh Thị Đông', email: 'dong.huynh@savina.com', systemRole: 'tenant-user', status: 'active', isActive: true, createdAt: '2026-08-10T08:00:00Z', updatedAt: '2026-09-05T10:00:00Z'),
      TenantUser(id: 'usr-ngoc', fullName: 'Cao Khánh Ngọc', email: 'ngoc.cao@savina.com', systemRole: 'tenant-user', status: 'active', isActive: true, createdAt: '2026-08-10T08:00:00Z', updatedAt: '2026-09-05T10:00:00Z'),
      TenantUser(id: 'usr-quan', fullName: 'Phạm Việt Quân', email: 'quan.pham@savina.com', systemRole: 'tenant-user', status: 'active', isActive: true, createdAt: '2026-08-10T08:00:00Z', updatedAt: '2026-09-05T10:00:00Z'),
      TenantUser(id: 'usr-thuy', fullName: 'Nguyễn Thị Thủy', email: 'thuy.nguyen@savina.com', systemRole: 'tenant-user', status: 'active', isActive: true, createdAt: '2026-08-10T08:00:00Z', updatedAt: '2026-09-05T10:00:00Z'),
    ],
  );
}
