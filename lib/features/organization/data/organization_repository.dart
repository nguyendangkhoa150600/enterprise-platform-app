import 'package:flutter/foundation.dart';
import '../../../models/platform_models.dart';
import '../../../services/platform_service.dart';

/// Clean Architecture Repository for Organization Chart, Users, and Roles
abstract class OrganizationRepository {
  Future<List<TenantUser>> getTenantUsers();
  Future<({bool success, String? error, TenantUser? user})> createUser({
    required String fullName,
    required String email,
    required String password,
  });
  Future<bool> updateUserStatus(String userId, String status);
  Future<List<TenantRole>> getRoles();
  Future<bool> assignRoleToUser(String userId, String roleId);
}

class OrganizationRepositoryImpl implements OrganizationRepository {
  final PlatformService _service;

  OrganizationRepositoryImpl({PlatformService? service})
      : _service = service ?? PlatformService();

  @override
  Future<List<TenantUser>> getTenantUsers() async {
    try {
      return await _service.getTenantUsers();
    } catch (e) {
      debugPrint('[OrganizationRepositoryImpl] getTenantUsers error: $e');
      return [];
    }
  }

  @override
  Future<({bool success, String? error, TenantUser? user})> createUser({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return await _service.createUser(
      fullName: fullName,
      email: email,
      password: password,
    );
  }

  @override
  Future<bool> updateUserStatus(String userId, String status) async {
    final result = await _service.updateUser(userId, status: status);
    return result.success;
  }

  @override
  Future<List<TenantRole>> getRoles() async {
    return await _service.getTenantRoles();
  }

  @override
  /// Thêm một vai trò cho người dùng, giữ các vai trò đang có (API gán thay cả danh sách).
  Future<bool> assignRoleToUser(String userId, String roleId) async {
    final current = await _service.getUserRoleIds(userId);
    if (current.contains(roleId)) return true;
    final result = await _service.assignUserRoles(userId, [...current, roleId]);
    return result.success;
  }
}
