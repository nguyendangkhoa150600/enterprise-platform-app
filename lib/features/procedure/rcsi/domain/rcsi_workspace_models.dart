/// Dữ liệu nền của Ma trận RCSI: quyền, danh mục nhóm, danh mục vật tư.
library;

import 'rcsi_definition_models.dart';
import 'rcsi_json.dart';

/// `ProcedureWorkspacePermissions`.
class ProcedureWorkspacePermissions {
  final bool canManageDefinitions;
  final bool canPublishDefinitions;
  final bool canCreateInstances;
  final bool canOverrideActions;

  const ProcedureWorkspacePermissions({
    this.canManageDefinitions = false,
    this.canPublishDefinitions = false,
    this.canCreateInstances = false,
    this.canOverrideActions = false,
  });

  factory ProcedureWorkspacePermissions.fromJson(Map<String, dynamic> json) => ProcedureWorkspacePermissions(
        canManageDefinitions: jsonBool(json['canManageDefinitions']),
        canPublishDefinitions: jsonBool(json['canPublishDefinitions']),
        canCreateInstances: jsonBool(json['canCreateInstances']),
        canOverrideActions: jsonBool(json['canOverrideActions']),
      );
}

/// `ProcedureGroupOption` (cấu hình `catalog.group`).
class ProcedureGroupOption {
  final String code;
  final String label;
  final int sortOrder;
  final bool isActive;

  const ProcedureGroupOption({required this.code, required this.label, this.sortOrder = 0, this.isActive = true});

  factory ProcedureGroupOption.fromJson(Map<String, dynamic> json) => ProcedureGroupOption(
        code: jsonStr(json['code']),
        label: jsonStr(json['label']),
        sortOrder: jsonInt(json['sortOrder']),
        isActive: jsonBool(json['isActive'], true),
      );
}

/// `ProcedureGroupCatalog`.
class ProcedureGroupCatalog {
  final List<ProcedureGroupOption> options;
  final bool autoAssignEnabled;

  const ProcedureGroupCatalog({this.options = const [], this.autoAssignEnabled = false});

  factory ProcedureGroupCatalog.fromJson(Map<String, dynamic> json) => ProcedureGroupCatalog(
        options: jsonList(json['options'], ProcedureGroupOption.fromJson),
        autoAssignEnabled: jsonBool(json['autoAssignEnabled']),
      );

  /// Nhóm đang bật, giữ đúng thứ tự admin đã sắp (`activeGroups` của web).
  List<ProcedureGroupOption> get activeOptions => options.where((group) => group.isActive).toList();
}

/// Một dòng danh mục vật tư của Kho (`GET /material-catalog`).
class MaterialCatalogItem {
  final String code;
  final String name;
  final String unit;

  /// Tồn khả dụng gộp mọi kho, đọc tươi.
  final num? available;

  const MaterialCatalogItem({required this.code, required this.name, required this.unit, this.available});

  factory MaterialCatalogItem.fromJson(Map<String, dynamic> json) => MaterialCatalogItem(
        code: jsonStr(json['code']),
        name: jsonStr(json['name']),
        unit: jsonStr(json['unit']),
        available: jsonNumOrNull(json['available']),
      );
}

/// Phần `GET /workspace` mà Ma trận RCSI dùng (bỏ qua `instances`).
class RcsiWorkspace {
  final String tenantId;
  final String actorId;
  final String actorName;
  final ProcedureWorkspacePermissions permissions;
  final List<ProcedureDefinition> definitions;

  const RcsiWorkspace({
    this.tenantId = '',
    this.actorId = '',
    this.actorName = '',
    this.permissions = const ProcedureWorkspacePermissions(),
    this.definitions = const [],
  });

  factory RcsiWorkspace.fromJson(Map<String, dynamic> json) {
    final actor = jsonMap(json['actor']);
    return RcsiWorkspace(
      tenantId: jsonStr(json['tenantId']),
      actorId: jsonStr(actor['id']),
      actorName: jsonStr(actor['name']),
      permissions: ProcedureWorkspacePermissions.fromJson(jsonMap(json['permissions'])),
      definitions: jsonList(json['definitions'], ProcedureDefinition.fromJson),
    );
  }
}
