/// Ảnh chụp cơ cấu tổ chức tenant (`TenantOrganizationSnapshot` của
/// `contracts-organization`), nạp từ `GET /api/procedure/v1/organization-context`.
library;

import 'rcsi_json.dart';

class OrganizationUnitType {
  final String id;
  final String key;
  final String name;

  /// `unit` | `position`.
  final String category;
  final int usageCount;
  final String createdAt;

  const OrganizationUnitType({
    required this.id,
    required this.key,
    required this.name,
    required this.category,
    this.usageCount = 0,
    this.createdAt = '',
  });

  factory OrganizationUnitType.fromJson(Map<String, dynamic> json) => OrganizationUnitType(
        id: jsonStr(json['id']),
        key: jsonStr(json['key']),
        name: jsonStr(json['name']),
        category: jsonStr(json['category'], 'unit'),
        usageCount: jsonInt(json['usageCount']),
        createdAt: jsonStr(json['createdAt']),
      );
}

class OrganizationPosition {
  final String id;
  final String key;
  final String name;
  final String unitId;
  final String? treeId;
  final int? sortOrder;
  final String? reportsToPositionId;
  final String createdAt;

  const OrganizationPosition({
    required this.id,
    required this.key,
    required this.name,
    required this.unitId,
    this.treeId,
    this.sortOrder,
    this.reportsToPositionId,
    this.createdAt = '',
  });

  factory OrganizationPosition.fromJson(Map<String, dynamic> json) => OrganizationPosition(
        id: jsonStr(json['id']),
        key: jsonStr(json['key']),
        name: jsonStr(json['name']),
        unitId: jsonStr(json['unitId']),
        treeId: jsonStrOrNull(json['treeId']),
        sortOrder: json['sortOrder'] == null ? null : jsonInt(json['sortOrder']),
        reportsToPositionId: jsonStrOrNull(json['reportsToPositionId']),
        createdAt: jsonStr(json['createdAt']),
      );
}

class OrganizationMember {
  final String membershipId;
  final String userId;
  final String displayName;
  final String email;
  final String? unitId;
  final String? positionId;
  final String? positionName;
  final bool isHead;
  final String? assignmentId;
  final String? reportsToPositionOverrideId;

  const OrganizationMember({
    required this.membershipId,
    required this.userId,
    required this.displayName,
    this.email = '',
    this.unitId,
    this.positionId,
    this.positionName,
    this.isHead = false,
    this.assignmentId,
    this.reportsToPositionOverrideId,
  });

  factory OrganizationMember.fromJson(Map<String, dynamic> json) => OrganizationMember(
        membershipId: jsonStr(json['membershipId']),
        userId: jsonStr(json['userId']),
        displayName: jsonStr(json['displayName']),
        email: jsonStr(json['email']),
        unitId: jsonStrOrNull(json['unitId']),
        positionId: jsonStrOrNull(json['positionId']),
        positionName: jsonStrOrNull(json['positionName']),
        isHead: jsonBool(json['isHead']),
        assignmentId: jsonStrOrNull(json['assignmentId']),
        reportsToPositionOverrideId: jsonStrOrNull(json['reportsToPositionOverrideId']),
      );
}

class OrganizationUnit {
  final String id;
  final String? treeId;
  final String code;
  final String name;
  final String typeId;
  final String typeName;

  /// `unit` (đơn vị) | `position` (node chức danh).
  final String typeCategory;
  final String? parentId;
  final String? headPositionId;
  final String? reportsToPositionId;
  final String? headMembershipId;
  final String? headName;
  final int memberCount;
  final int? sortOrder;
  final String createdAt;
  final String updatedAt;

  const OrganizationUnit({
    required this.id,
    this.treeId,
    required this.code,
    required this.name,
    this.typeId = '',
    this.typeName = '',
    this.typeCategory = 'unit',
    this.parentId,
    this.headPositionId,
    this.reportsToPositionId,
    this.headMembershipId,
    this.headName,
    this.memberCount = 0,
    this.sortOrder,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory OrganizationUnit.fromJson(Map<String, dynamic> json) => OrganizationUnit(
        id: jsonStr(json['id']),
        treeId: jsonStrOrNull(json['treeId']),
        code: jsonStr(json['code']),
        name: jsonStr(json['name']),
        typeId: jsonStr(json['typeId']),
        typeName: jsonStr(json['typeName']),
        typeCategory: jsonStr(json['typeCategory'], 'unit'),
        parentId: jsonStrOrNull(json['parentId']),
        headPositionId: jsonStrOrNull(json['headPositionId']),
        reportsToPositionId: jsonStrOrNull(json['reportsToPositionId']),
        headMembershipId: jsonStrOrNull(json['headMembershipId']),
        headName: jsonStrOrNull(json['headName']),
        memberCount: jsonInt(json['memberCount']),
        sortOrder: json['sortOrder'] == null ? null : jsonInt(json['sortOrder']),
        createdAt: jsonStr(json['createdAt']),
        updatedAt: jsonStr(json['updatedAt']),
      );

  bool get isPositionNode => typeCategory == 'position';
}

class OrganizationTreeInfo {
  final String id;
  final String code;
  final String name;
  final String? description;
  final bool? isPrimary;

  const OrganizationTreeInfo({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.isPrimary,
  });

  factory OrganizationTreeInfo.fromJson(Map<String, dynamic> json) => OrganizationTreeInfo(
        id: jsonStr(json['id']),
        code: jsonStr(json['code']),
        name: jsonStr(json['name']),
        description: jsonStrOrNull(json['description']),
        isPrimary: json['isPrimary'] == null ? null : jsonBool(json['isPrimary']),
      );
}

class TenantOrganizationSnapshot {
  final String tenantId;
  final String generatedAt;
  final List<OrganizationUnitType> unitTypes;
  final List<OrganizationUnit> units;
  final List<OrganizationPosition> positions;
  final List<OrganizationMember> members;

  /// Null khi server cũ không trả danh sách sơ đồ.
  final List<OrganizationTreeInfo>? trees;

  /// membershipId → { organizationUnitIds, positionIds }.
  final Map<String, ({List<String> organizationUnitIds, List<String> positionIds})> membershipSubjects;

  const TenantOrganizationSnapshot({
    this.tenantId = '',
    this.generatedAt = '',
    this.unitTypes = const [],
    this.units = const [],
    this.positions = const [],
    this.members = const [],
    this.trees,
    this.membershipSubjects = const {},
  });

  factory TenantOrganizationSnapshot.fromJson(Map<String, dynamic> json) {
    final subjects = jsonMap(json['membershipSubjects']).map((key, value) {
      final entry = jsonMap(value);
      return MapEntry(key, (
        organizationUnitIds: jsonStringList(entry['organizationUnitIds']),
        positionIds: jsonStringList(entry['positionIds']),
      ));
    });
    return TenantOrganizationSnapshot(
      tenantId: jsonStr(json['tenantId']),
      generatedAt: jsonStr(json['generatedAt']),
      unitTypes: jsonList(json['unitTypes'], OrganizationUnitType.fromJson),
      units: jsonList(json['units'], OrganizationUnit.fromJson),
      positions: jsonList(json['positions'], OrganizationPosition.fromJson),
      members: jsonList(json['members'], OrganizationMember.fromJson),
      trees: json['trees'] is List ? jsonList(json['trees'], OrganizationTreeInfo.fromJson) : null,
      membershipSubjects: subjects,
    );
  }
}
