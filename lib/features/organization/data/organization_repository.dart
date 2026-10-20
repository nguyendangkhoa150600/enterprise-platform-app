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
  Future<List<Map<String, dynamic>>> getRoles();
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
    return await _service.updateUserStatus(userId, status);
  }

  @override
  Future<List<Map<String, dynamic>>> getRoles() async {
    return await _service.getRoles();
  }

  @override
  Future<bool> assignRoleToUser(String userId, String roleId) async {
    return await _service.assignRoleToUser(userId, roleId);
  }
}
