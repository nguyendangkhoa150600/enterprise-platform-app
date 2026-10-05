class AuthenticatedPrincipal {
  final String kind; // 'tenant-user' | 'platform-admin'
  final String userId;
  final String sessionId;
  final String email;
  final String displayName;
  final String? tenantId;
  final String? tenantSlug;
  final String? membershipId;
  final List<String> roles;
  final List<String> permissions;

  AuthenticatedPrincipal({
    required this.kind,
    required this.userId,
    required this.sessionId,
    required this.email,
    required this.displayName,
    this.tenantId,
    this.tenantSlug,
    this.membershipId,
    required this.roles,
    required this.permissions,
  });

  bool get isPlatformAdmin => kind == 'platform-admin' || roles.contains('platform-admin');
  bool get isTenantAdmin => roles.contains('tenant-admin');

  factory AuthenticatedPrincipal.fromJson(Map<String, dynamic> json) {
    return AuthenticatedPrincipal(
      kind: json['kind']?.toString() ?? 'tenant-user',
      userId: json['userId']?.toString() ?? '',
      sessionId: json['sessionId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['fullName']?.toString() ?? 'Người dùng',
      tenantId: json['tenantId']?.toString(),
      tenantSlug: json['tenantSlug']?.toString(),
      membershipId: json['membershipId']?.toString(),
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      permissions: (json['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'userId': userId,
    'sessionId': sessionId,
    'email': email,
    'displayName': displayName,
    'tenantId': tenantId,
    'tenantSlug': tenantSlug,
    'membershipId': membershipId,
    'roles': roles,
    'permissions': permissions,
  };
}

class TenantUser {
  final String id;
  final String? username;
  final String fullName;
  final String email;
  final String systemRole; // 'tenant-admin' | 'tenant-user'
  final String status; // 'active' | 'disabled'
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  TenantUser({
    required this.id,
    this.username,
    required this.fullName,
    required this.email,
    required this.systemRole,
    required this.status,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TenantUser.fromJson(Map<String, dynamic> json) {
    return TenantUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString(),
      fullName: json['fullName']?.toString() ?? json['name']?.toString() ?? 'Người dùng',
      email: json['email']?.toString() ?? '',
      systemRole: json['systemRole']?.toString() ?? 'tenant-user',
      status: json['status']?.toString() ?? (json['isActive'] == true ? 'active' : 'disabled'),
      isActive: json['isActive'] == true || json['status'] == 'active',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'email': email,
    'systemRole': systemRole,
    'status': status,
    'isActive': isActive,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

class ModuleCatalogItem {
  final String key;
  final String name;
  final String description;
  final String launchUrl;
  final String? icon;
  final String version;
  final String entitlementStatus; // 'active' | 'provisioning' | 'not-entitled'

  ModuleCatalogItem({
    required this.key,
    required this.name,
    required this.description,
    required this.launchUrl,
    this.icon,
    required this.version,
    required this.entitlementStatus,
  });

  bool get isActive => entitlementStatus == 'active';

  factory ModuleCatalogItem.fromJson(Map<String, dynamic> json) {
    return ModuleCatalogItem(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      launchUrl: json['launchUrl']?.toString() ?? '',
      icon: json['icon']?.toString(),
      version: json['version']?.toString() ?? '1.0.0',
      entitlementStatus: json['entitlementStatus']?.toString() ?? 'not-entitled',
    );
  }
}

class OrgNode {
  final String id;
  final String treeId;
  final String? parentId;
  final String nodeTypeId;
  final String code;
  final String name;
  final String? description;
  final int sortOrder;
  final String status;

  OrgNode({
    required this.id,
    required this.treeId,
    this.parentId,
    required this.nodeTypeId,
    required this.code,
    required this.name,
    this.description,
    this.sortOrder = 0,
    required this.status,
  });

  factory OrgNode.fromJson(Map<String, dynamic> json) {
    return OrgNode(
      id: json['id']?.toString() ?? '',
      treeId: json['treeId']?.toString() ?? '',
      parentId: json['parentId']?.toString(),
      nodeTypeId: json['nodeTypeId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'active',
    );
  }
}

class OrgNodeType {
  final String id;
  final String code;
  final String name;
  final String category; // 'unit' | 'position'
  final String? description;

  OrgNodeType({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    this.description,
  });

  factory OrgNodeType.fromJson(Map<String, dynamic> json) {
    return OrgNodeType(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'unit',
      description: json['description']?.toString(),
    );
  }
}

class OrgAssignment {
  final String id;
  final String nodeId;
  final String userId;
  final bool isPrimary;
  final String? startDate;
  final String? endDate;
  final String? note;
  final String status;

  OrgAssignment({
    required this.id,
    required this.nodeId,
    required this.userId,
    required this.isPrimary,
    this.startDate,
    this.endDate,
    this.note,
    required this.status,
  });

  factory OrgAssignment.fromJson(Map<String, dynamic> json) {
    return OrgAssignment(
      id: json['id']?.toString() ?? '',
      nodeId: json['nodeId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      isPrimary: json['isPrimary'] == true,
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      note: json['note']?.toString(),
      status: json['status']?.toString() ?? 'active',
    );
  }
}

class OrganizationSnapshot {
  final List<OrgNode> nodes;
  final List<OrgNodeType> nodeTypes;
  final List<OrgAssignment> assignments;
  final List<TenantUser> users;

  OrganizationSnapshot({
    required this.nodes,
    required this.nodeTypes,
    required this.assignments,
    required this.users,
  });

  factory OrganizationSnapshot.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as List<dynamic>? ?? [];
    final rawTypes = json['nodeTypes'] as List<dynamic>? ?? [];
    final rawAssignments = json['assignments'] as List<dynamic>? ?? [];
    final rawUsers = json['users'] as List<dynamic>? ?? [];

    return OrganizationSnapshot(
      nodes: rawNodes.map((e) => OrgNode.fromJson(e as Map<String, dynamic>)).toList(),
      nodeTypes: rawTypes.map((e) => OrgNodeType.fromJson(e as Map<String, dynamic>)).toList(),
      assignments: rawAssignments.map((e) => OrgAssignment.fromJson(e as Map<String, dynamic>)).toList(),
      users: rawUsers.map((e) => TenantUser.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class TenantRole {
  final String id;
  final String name;
  final String key;
  final String? description;
  final bool isSystem;
  final List<String> actionKeys;
  final List<String> permissionIds;
  final List<String> moduleKeys;
  final List<String> userIds;
  final String? createdAt;
  final String? updatedAt;

  TenantRole({
    required this.id,
    required this.name,
    required this.key,
    this.description,
    this.isSystem = false,
    this.actionKeys = const [],
    this.permissionIds = const [],
    this.moduleKeys = const [],
    this.userIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory TenantRole.fromJson(Map<String, dynamic> json) {
    return TenantRole(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      description: json['description']?.toString(),
      isSystem: json['isSystem'] == true,
      actionKeys: (json['actionKeys'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      permissionIds: (json['permissionIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      moduleKeys: (json['moduleKeys'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      userIds: (json['userIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'key': key,
    'description': description,
    'isSystem': isSystem,
    'actionKeys': actionKeys,
    'permissionIds': permissionIds,
    'moduleKeys': moduleKeys,
    'userIds': userIds,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

class TenantPermission {
  final String id;
  final String name;
  final String? key;
  final String? description;
  final bool isSystem;
  final List<String> actionKeys;
  final List<String> roleIds;

  TenantPermission({
    required this.id,
    required this.name,
    this.key,
    this.description,
    this.isSystem = false,
    this.actionKeys = const [],
    this.roleIds = const [],
  });

  factory TenantPermission.fromJson(Map<String, dynamic> json) {
    return TenantPermission(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      key: json['key']?.toString(),
      description: json['description']?.toString(),
      isSystem: json['isSystem'] == true,
      actionKeys: (json['actionKeys'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      roleIds: (json['roleIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'key': key,
    'description': description,
    'isSystem': isSystem,
    'actionKeys': actionKeys,
    'roleIds': roleIds,
  };
}

