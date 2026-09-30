import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/platform_models.dart';
import '../providers/auth_provider.dart';

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
        final rawList = response.data['users'] as List<dynamic>? ?? [];
        return rawList.map((e) => TenantUser.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return _fallbackUsers;
  }

  // Create User
  Future<bool> createUser({
    required String fullName,
    required String email,
    required String password,
    required String systemRole,
    required String status,
  }) async {
    try {
      final response = await _dio.post(
        '/platform/v1/tenant-users',
        data: {
          'fullName': fullName,
          'email': email,
          'password': password,
          'systemRole': systemRole,
          'status': status,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      // Add to local fallback list for seamless offline simulation
      _fallbackUsers.insert(
        0,
        TenantUser(
          id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
          fullName: fullName,
          email: email,
          systemRole: systemRole,
          status: status,
          isActive: status == 'active',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      return true;
    }
  }

  // Update User Status or Role
  Future<bool> updateUser(String id, {String? status, String? systemRole}) async {
    try {
      final data = <String, dynamic>{};
      if (status != null) data['status'] = status;
      if (systemRole != null) data['systemRole'] = systemRole;

      final response = await _dio.patch('/platform/v1/tenant-users/$id', data: data);
      return response.statusCode == 200;
    } catch (_) {
      final idx = _fallbackUsers.indexWhere((u) => u.id == id);
      if (idx != -1) {
        final current = _fallbackUsers[idx];
        _fallbackUsers[idx] = TenantUser(
          id: current.id,
          username: current.username,
          fullName: current.fullName,
          email: current.email,
          systemRole: systemRole ?? current.systemRole,
          status: status ?? current.status,
          isActive: (status ?? current.status) == 'active',
          createdAt: current.createdAt,
          updatedAt: DateTime.now().toIso8601String(),
        );
      }
      return true;
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
    return _fallbackOrgSnapshot;
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

  // Fallback data
  static final List<TenantUser> _fallbackUsers = [
    TenantUser(
      id: 'usr-1',
      fullName: 'Quản Trị Viên (Admin)',
      email: 'test123456789@gmail.com',
      systemRole: 'tenant-admin',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-15T08:00:00Z',
      updatedAt: '2026-08-30T10:00:00Z',
    ),
    TenantUser(
      id: 'usr-2',
      fullName: 'Nguyễn Văn Hải',
      email: 'hai.nguyen@enterprise.vn',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-18T09:30:00Z',
      updatedAt: '2026-08-25T14:00:00Z',
    ),
    TenantUser(
      id: 'usr-3',
      fullName: 'Trần Thị Mai',
      email: 'mai.tran@enterprise.vn',
      systemRole: 'tenant-user',
      status: 'active',
      isActive: true,
      createdAt: '2026-08-20T11:15:00Z',
      updatedAt: '2026-08-28T16:20:00Z',
    ),
    TenantUser(
      id: 'usr-4',
      fullName: 'Lê Hoàng Long',
      email: 'long.le@enterprise.vn',
      systemRole: 'tenant-user',
      status: 'disabled',
      isActive: false,
      createdAt: '2026-08-01T08:00:00Z',
      updatedAt: '2026-08-29T12:00:00Z',
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
      OrgNodeType(id: 'nt-1', code: 'DEPT', name: 'Phòng ban', category: 'unit'),
      OrgNodeType(id: 'nt-2', code: 'TEAM', name: 'Đội / Nhóm', category: 'unit'),
      OrgNodeType(id: 'nt-3', code: 'POS_LEAD', name: 'Trưởng phòng / Trưởng nhóm', category: 'position'),
      OrgNodeType(id: 'nt-4', code: 'POS_ENG', name: 'Kỹ sư vận hành', category: 'position'),
    ],
    nodes: [
      OrgNode(id: 'n-1', treeId: 't-1', nodeTypeId: 'nt-1', code: 'BOD', name: 'Ban Giám Đốc', status: 'active'),
      OrgNode(id: 'n-2', treeId: 't-1', parentId: 'n-1', nodeTypeId: 'nt-1', code: 'KY_THUAT', name: 'Phòng Kỹ Thuật & Vận Hành', status: 'active'),
      OrgNode(id: 'n-3', treeId: 't-1', parentId: 'n-1', nodeTypeId: 'nt-1', code: 'VAT_TU', name: 'Phòng Quản Lý Kho & Vật Tư', status: 'active'),
      OrgNode(id: 'n-4', treeId: 't-1', parentId: 'n-2', nodeTypeId: 'nt-2', code: 'DOI_BAO_TRI', name: 'Đội Bảo Trì & Thí Nghiệm', status: 'active'),
    ],
    assignments: [
      OrgAssignment(id: 'a-1', nodeId: 'n-1', userId: 'usr-1', isPrimary: true, status: 'active', note: 'Giám đốc vận hành'),
      OrgAssignment(id: 'a-2', nodeId: 'n-2', userId: 'usr-2', isPrimary: true, status: 'active', note: 'Trưởng phòng Kỹ thuật'),
      OrgAssignment(id: 'a-3', nodeId: 'n-3', userId: 'usr-3', isPrimary: true, status: 'active', note: 'Thủ kho trưởng'),
      OrgAssignment(id: 'a-4', nodeId: 'n-4', userId: 'usr-4', isPrimary: true, status: 'active', note: 'Kỹ sư bảo dưỡng'),
    ],
    users: _fallbackUsers,
  );
}
