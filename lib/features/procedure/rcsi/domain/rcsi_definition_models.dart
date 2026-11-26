/// Model định nghĩa quy trình (quy trình, bước, phân vai RCSI) và payload ghi —
/// khớp `procedure-engine.contracts.ts` + `procedure-finance-step.ts` của web.
library;

import 'rcsi_flow_models.dart';
import 'rcsi_json.dart';

// ------------------------------------------------------------------ Hằng số contract

/// `PROCEDURE_KINDS`.
const List<String> procedureKinds = ['process', 'maintenance_linked', 'maintenance_direct'];

/// `PROCEDURE_DEFINITION_STATUSES`.
const List<String> procedureDefinitionStatuses = ['draft', 'published', 'archived'];

/// `PROCEDURE_RACI_ROLES`.
const List<String> procedureRaciRoles = ['R', 'A', 'C', 'S', 'I', 'E'];

/// `PROCEDURE_STAGE_ORDER`.
const List<String> procedureStageOrder = ['S', 'R', 'E', 'C', 'A'];

/// `ProcedureSubjectType`.
abstract final class ProcedureSubjectType {
  static const organizationUnit = 'organization_unit';
  static const position = 'position';
  static const user = 'user';
  static const initiatorManager = 'initiator_manager';
  static const everyone = 'everyone';
}

/// `PROCEDURE_EVERYONE_SUBJECT_ID`.
const String procedureEveryoneSubjectId = 'everyone';

/// `E_TASK_SOURCES`.
const List<String> eTaskSources = ['task_list', 'equipment_template', 'manual', 'inventory_asset', 'inventory_material'];

// ------------------------------------------------------------------ Phân vai

class ProcedureETaskConfig {
  final String? assetCode;
  final String? materialCode;

  /// Chụp lúc công bố; vắng khi còn nháp. Giữ nguyên dạng thô để gửi lại không mất gì.
  final List<Map<String, dynamic>>? taskTemplate;
  final String? resolvedAt;

  const ProcedureETaskConfig({this.assetCode, this.materialCode, this.taskTemplate, this.resolvedAt});

  factory ProcedureETaskConfig.fromJson(Map<String, dynamic> json) => ProcedureETaskConfig(
        assetCode: jsonStrOrNull(json['assetCode']),
        materialCode: jsonStrOrNull(json['materialCode']),
        taskTemplate: json['taskTemplate'] is List
            ? (json['taskTemplate'] as List).whereType<Map>().map(jsonMap).toList()
            : null,
        resolvedAt: jsonStrOrNull(json['resolvedAt']),
      );

  Map<String, dynamic> toJson() => compactJson({
        'assetCode': assetCode,
        'materialCode': materialCode,
        'taskTemplate': taskTemplate,
        'resolvedAt': resolvedAt,
      });
}

/// Chủ thể dự phòng của `initiator_manager`.
class ProcedureManagerFallback {
  /// `organization_unit` | `position` | `user`.
  final String subjectType;
  final String subjectId;
  final String? subjectLabel;

  const ProcedureManagerFallback({required this.subjectType, required this.subjectId, this.subjectLabel});

  factory ProcedureManagerFallback.fromJson(Map<String, dynamic> json) => ProcedureManagerFallback(
        subjectType: jsonStr(json['subjectType'], ProcedureSubjectType.position),
        subjectId: jsonStr(json['subjectId']),
        subjectLabel: jsonStrOrNull(json['subjectLabel']),
      );

  Map<String, dynamic> toJson() =>
      compactJson({'subjectType': subjectType, 'subjectId': subjectId, 'subjectLabel': subjectLabel});
}

/// Phần chung của phân vai đã lưu và payload ghi — `sameSubject`/`isAssignedToColumn` dùng.
abstract interface class RaciSubjectRef {
  String get role;
  String get subjectType;
  String get subjectId;
}

class ProcedureRaciAssignment implements RaciSubjectRef {
  final String id;
  @override
  final String role;
  @override
  final String subjectType;
  @override
  final String subjectId;
  final String? subjectLabel;
  final String? fixedRollbackStepId;
  final String? eTaskSource;
  final ProcedureETaskConfig? eTaskConfig;
  final ProcedureManagerFallback? managerFallback;
  final String? fallbackOfAssignmentId;

  const ProcedureRaciAssignment({
    required this.id,
    required this.role,
    required this.subjectType,
    required this.subjectId,
    this.subjectLabel,
    this.fixedRollbackStepId,
    this.eTaskSource,
    this.eTaskConfig,
    this.managerFallback,
    this.fallbackOfAssignmentId,
  });

  factory ProcedureRaciAssignment.fromJson(Map<String, dynamic> json) => ProcedureRaciAssignment(
        id: jsonStr(json['id']),
        role: jsonStr(json['role']),
        subjectType: jsonStr(json['subjectType']),
        subjectId: jsonStr(json['subjectId']),
        subjectLabel: jsonStrOrNull(json['subjectLabel']),
        fixedRollbackStepId: jsonStrOrNull(json['fixedRollbackStepId']),
        eTaskSource: jsonStrOrNull(json['eTaskSource']),
        eTaskConfig: json['eTaskConfig'] is Map ? ProcedureETaskConfig.fromJson(jsonMap(json['eTaskConfig'])) : null,
        managerFallback:
            json['managerFallback'] is Map ? ProcedureManagerFallback.fromJson(jsonMap(json['managerFallback'])) : null,
        fallbackOfAssignmentId: jsonStrOrNull(json['fallbackOfAssignmentId']),
      );

  Map<String, dynamic> toJson() => compactJson({
        'id': id,
        'role': role,
        'subjectType': subjectType,
        'subjectId': subjectId,
        'subjectLabel': subjectLabel,
        'fixedRollbackStepId': fixedRollbackStepId,
        'eTaskSource': eTaskSource,
        'eTaskConfig': eTaskConfig?.toJson(),
        'managerFallback': managerFallback?.toJson(),
        'fallbackOfAssignmentId': fallbackOfAssignmentId,
      });
}

/// `CreateProcedureRaciAssignmentInput` — một phân vai trong payload ghi.
class CreateProcedureRaciAssignmentInput implements RaciSubjectRef {
  @override
  final String role;
  @override
  final String subjectType;
  @override
  final String subjectId;
  final String? subjectLabel;
  final String? fixedRollbackStepId;
  final String? eTaskSource;
  final ProcedureETaskConfig? eTaskConfig;
  final ProcedureManagerFallback? managerFallback;

  const CreateProcedureRaciAssignmentInput({
    required this.role,
    required this.subjectType,
    required this.subjectId,
    this.subjectLabel,
    this.fixedRollbackStepId,
    this.eTaskSource,
    this.eTaskConfig,
    this.managerFallback,
  });

  Map<String, dynamic> toJson() => compactJson({
        'role': role,
        'subjectType': subjectType,
        'subjectId': subjectId,
        'subjectLabel': subjectLabel,
        'fixedRollbackStepId': fixedRollbackStepId,
        'eTaskSource': eTaskSource,
        'eTaskConfig': eTaskConfig?.toJson(),
        'managerFallback': managerFallback?.toJson(),
      });

  CreateProcedureRaciAssignmentInput copyWith({
    String? role,
    String? subjectType,
    String? subjectId,
    Object? subjectLabel = keepValue,
    Object? fixedRollbackStepId = keepValue,
    Object? eTaskSource = keepValue,
    Object? eTaskConfig = keepValue,
    Object? managerFallback = keepValue,
  }) =>
      CreateProcedureRaciAssignmentInput(
        role: role ?? this.role,
        subjectType: subjectType ?? this.subjectType,
        subjectId: subjectId ?? this.subjectId,
        subjectLabel: pick<String>(subjectLabel, this.subjectLabel),
        fixedRollbackStepId: pick<String>(fixedRollbackStepId, this.fixedRollbackStepId),
        eTaskSource: pick<String>(eTaskSource, this.eTaskSource),
        eTaskConfig: pick<ProcedureETaskConfig>(eTaskConfig, this.eTaskConfig),
        managerFallback: pick<ProcedureManagerFallback>(managerFallback, this.managerFallback),
      );
}

// ------------------------------------------------------------------ Vật tư & tích hợp

class ProcedureStepMaterial {
  final String materialCode;
  final num quantity;
  final String? note;

  /// Chụp lúc công bố; vắng khi còn nháp.
  final String? materialName;
  final String? unit;

  const ProcedureStepMaterial({
    required this.materialCode,
    required this.quantity,
    this.note,
    this.materialName,
    this.unit,
  });

  factory ProcedureStepMaterial.fromJson(Map<String, dynamic> json) => ProcedureStepMaterial(
        materialCode: jsonStr(json['materialCode']),
        quantity: jsonNumOrNull(json['quantity']) ?? 0,
        note: jsonStrOrNull(json['note']),
        materialName: jsonStrOrNull(json['materialName']),
        unit: jsonStrOrNull(json['unit']),
      );

  Map<String, dynamic> toJson() => compactJson({
        'materialCode': materialCode,
        'quantity': quantity,
        'note': note,
        'materialName': materialName,
        'unit': unit,
      });
}

/// Cấu hình bước Tài chính (`ProcedureStepIntegration`). Vắng = bước thường.
class ProcedureStepIntegration {
  /// Luôn `finance`.
  final String module;

  /// Luôn `voucher`.
  final String action;

  /// `PAYMENT` | `RECEIPT`.
  final String voucherKind;

  /// Trường phiếu (FinanceVoucherSourceField) ← khoá thuộc tính hồ sơ.
  final Map<String, String>? mapping;
  final String? returnToStepId;

  const ProcedureStepIntegration({
    this.module = 'finance',
    this.action = 'voucher',
    required this.voucherKind,
    this.mapping,
    this.returnToStepId,
  });

  factory ProcedureStepIntegration.fromJson(Map<String, dynamic> json) {
    final rawMapping = json['mapping'];
    return ProcedureStepIntegration(
      module: jsonStr(json['module'], 'finance'),
      action: jsonStr(json['action'], 'voucher'),
      voucherKind: jsonStr(json['voucherKind'], 'PAYMENT'),
      mapping: rawMapping is Map
          ? Map<String, String>.fromEntries(
              rawMapping.entries.where((entry) => entry.value != null).map(
                    (entry) => MapEntry(entry.key.toString(), entry.value.toString()),
                  ),
            )
          : null,
      returnToStepId: jsonStrOrNull(json['returnToStepId']),
    );
  }

  Map<String, dynamic> toJson() => compactJson({
        'module': module,
        'action': action,
        'voucherKind': voucherKind,
        'mapping': mapping == null ? null : Map<String, String>.of(mapping!),
        'returnToStepId': returnToStepId,
      });

  ProcedureStepIntegration copy() => ProcedureStepIntegration(
        module: module,
        action: action,
        voucherKind: voucherKind,
        mapping: mapping == null ? null : Map<String, String>.of(mapping!),
        returnToStepId: returnToStepId,
      );

  @override
  bool operator ==(Object other) =>
      other is ProcedureStepIntegration &&
      other.module == module &&
      other.action == action &&
      other.voucherKind == voucherKind &&
      other.returnToStepId == returnToStepId &&
      _sameMapping(other.mapping, mapping);

  @override
  int get hashCode => Object.hash(module, action, voucherKind, returnToStepId, mapping?.length);

  static bool _sameMapping(Map<String, String>? left, Map<String, String>? right) {
    if (left == null || right == null) return left == right;
    if (left.length != right.length) return false;
    return left.entries.every((entry) => right[entry.key] == entry.value);
  }
}

// ------------------------------------------------------------------ Bước & quy trình

class ProcedureStepDefinition {
  final String id;
  final String key;
  final int order;
  final String name;
  final String? description;
  final String? linkedDefinitionId;
  final List<ProcedureStepMaterial>? materials;

  /// SLA tính bằng giờ. Null = không SLA.
  final num? slaHours;
  final List<ProcedureAttributeDefinition>? attributes;
  final ProcedureStepIntegration? integration;
  final List<ProcedureRaciAssignment> assignments;

  const ProcedureStepDefinition({
    required this.id,
    required this.key,
    required this.order,
    required this.name,
    this.description,
    this.linkedDefinitionId,
    this.materials,
    this.slaHours,
    this.attributes,
    this.integration,
    this.assignments = const [],
  });

  factory ProcedureStepDefinition.fromJson(Map<String, dynamic> json) => ProcedureStepDefinition(
        id: jsonStr(json['id']),
        key: jsonStr(json['key']),
        order: jsonInt(json['order']),
        name: jsonStr(json['name']),
        description: jsonStrOrNull(json['description']),
        linkedDefinitionId: jsonStrOrNull(json['linkedDefinitionId']),
        materials: json['materials'] is List ? jsonList(json['materials'], ProcedureStepMaterial.fromJson) : null,
        slaHours: jsonNumOrNull(json['slaHours']),
        attributes:
            json['attributes'] is List ? jsonList(json['attributes'], ProcedureAttributeDefinition.fromJson) : null,
        integration:
            json['integration'] is Map ? ProcedureStepIntegration.fromJson(jsonMap(json['integration'])) : null,
        assignments: jsonList(json['assignments'], ProcedureRaciAssignment.fromJson),
      );

  Map<String, dynamic> toJson() => compactJson({
        'id': id,
        'key': key,
        'order': order,
        'name': name,
        'description': description,
        'linkedDefinitionId': linkedDefinitionId,
        'materials': materials?.map((item) => item.toJson()).toList(),
        'slaHours': slaHours,
        'attributes': attributes?.map((item) => item.toJson()).toList(),
        'integration': integration?.toJson(),
        'assignments': assignments.map((item) => item.toJson()).toList(),
      });

  /// Phân vai "Quản lý trực tiếp của người khởi tạo", nếu có.
  ProcedureRaciAssignment? get dynamicApprover {
    for (final item in assignments) {
      if (item.subjectType == ProcedureSubjectType.initiatorManager) return item;
    }
    return null;
  }
}

/// `CreateProcedureStepInput` — một bước trong payload tạo/sửa bản nháp.
class CreateProcedureStepInput {
  final String key;

  /// `num` vì thao tác luồng tạm dùng số lẻ (x.5) trước khi đánh lại 1..n.
  final num order;
  final String name;
  final String? description;
  final String? linkedDefinitionId;
  final num? slaHours;
  final List<ProcedureStepMaterial>? materials;
  final List<ProcedureAttributeDefinition>? attributes;
  final ProcedureStepIntegration? integration;
  final List<CreateProcedureRaciAssignmentInput> assignments;

  const CreateProcedureStepInput({
    required this.key,
    required this.order,
    required this.name,
    this.description,
    this.linkedDefinitionId,
    this.slaHours,
    this.materials,
    this.attributes,
    this.integration,
    this.assignments = const [],
  });

  Map<String, dynamic> toJson() => compactJson({
        'key': key,
        'order': order,
        'name': name,
        'description': description,
        'linkedDefinitionId': linkedDefinitionId,
        'slaHours': slaHours,
        'materials': materials?.map((item) => item.toJson()).toList(),
        'attributes': attributes?.map((item) => item.toJson()).toList(),
        'integration': integration?.toJson(),
        'assignments': assignments.map((item) => item.toJson()).toList(),
      });

  CreateProcedureStepInput copyWith({
    String? key,
    num? order,
    String? name,
    Object? description = keepValue,
    Object? linkedDefinitionId = keepValue,
    Object? slaHours = keepValue,
    Object? materials = keepValue,
    Object? attributes = keepValue,
    Object? integration = keepValue,
    List<CreateProcedureRaciAssignmentInput>? assignments,
  }) =>
      CreateProcedureStepInput(
        key: key ?? this.key,
        order: order ?? this.order,
        name: name ?? this.name,
        description: pick<String>(description, this.description),
        linkedDefinitionId: pick<String>(linkedDefinitionId, this.linkedDefinitionId),
        slaHours: pick<num>(slaHours, this.slaHours),
        materials: pick<List<ProcedureStepMaterial>>(materials, this.materials),
        attributes: pick<List<ProcedureAttributeDefinition>>(attributes, this.attributes),
        integration: pick<ProcedureStepIntegration>(integration, this.integration),
        assignments: assignments ?? this.assignments,
      );
}

class ProcedureDefinition {
  final String id;
  final String code;
  final String name;
  final String? description;

  /// Một giá trị của [procedureKinds].
  final String kind;

  /// Mã nhóm (danh mục `catalog.group`); bản nháp phải có trước khi công bố.
  final String? category;

  /// `draft` | `published` | `archived`.
  final String status;
  final int versionNumber;
  final List<ProcedureStepDefinition> steps;

  /// Thuộc tính cấp quy trình.
  final List<ProcedureAttributeDefinition>? attributes;

  /// Điểm rẽ nhánh. Null/rỗng = tuyến tính.
  final List<ProcedureGatewayDefinition>? gateways;
  final String createdAt;
  final String updatedAt;
  final String? publishedAt;
  final String? deletedAt;

  const ProcedureDefinition({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.kind = 'process',
    this.category,
    required this.status,
    this.versionNumber = 1,
    this.steps = const [],
    this.attributes,
    this.gateways,
    this.createdAt = '',
    this.updatedAt = '',
    this.publishedAt,
    this.deletedAt,
  });

  factory ProcedureDefinition.fromJson(Map<String, dynamic> json) => ProcedureDefinition(
        id: jsonStr(json['id']),
        code: jsonStr(json['code']),
        name: jsonStr(json['name']),
        description: jsonStrOrNull(json['description']),
        kind: jsonStr(json['kind'], 'process'),
        category: jsonStrOrNull(json['category']),
        status: jsonStr(json['status'], 'draft'),
        versionNumber: jsonInt(json['versionNumber'], 1),
        steps: jsonList(json['steps'], ProcedureStepDefinition.fromJson),
        attributes:
            json['attributes'] is List ? jsonList(json['attributes'], ProcedureAttributeDefinition.fromJson) : null,
        gateways: json['gateways'] is List ? jsonList(json['gateways'], ProcedureGatewayDefinition.fromJson) : null,
        createdAt: jsonStr(json['createdAt']),
        updatedAt: jsonStr(json['updatedAt']),
        publishedAt: jsonStrOrNull(json['publishedAt']),
        deletedAt: jsonStrOrNull(json['deletedAt']),
      );

  Map<String, dynamic> toJson() => compactJson({
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'kind': kind,
        'category': category,
        'status': status,
        'versionNumber': versionNumber,
        'steps': steps.map((step) => step.toJson()).toList(),
        'attributes': attributes?.map((item) => item.toJson()).toList(),
        'gateways': gateways?.map((item) => item.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'publishedAt': publishedAt,
        'deletedAt': deletedAt,
      });

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isArchived => status == 'archived';

  ProcedureStepDefinition? stepById(String stepId) {
    for (final step in steps) {
      if (step.id == stepId) return step;
    }
    return null;
  }

  ProcedureGatewayDefinition? gatewayById(String gatewayId) {
    for (final gateway in gateways ?? const <ProcedureGatewayDefinition>[]) {
      if (gateway.id == gatewayId) return gateway;
    }
    return null;
  }

  /// Bước theo `order` tăng dần (bản sao, không đổi [steps]).
  List<ProcedureStepDefinition> get orderedSteps {
    final indexed = steps.asMap().entries.toList()
      ..sort((left, right) {
        final diff = left.value.order.compareTo(right.value.order);
        return diff != 0 ? diff : left.key.compareTo(right.key);
      });
    return indexed.map((entry) => entry.value).toList();
  }

  ProcedureDefinition copyWith({
    String? status,
    Object? category = keepValue,
    List<ProcedureStepDefinition>? steps,
  }) =>
      ProcedureDefinition(
        id: id,
        code: code,
        name: name,
        description: description,
        kind: kind,
        category: pick<String>(category, this.category),
        status: status ?? this.status,
        versionNumber: versionNumber,
        steps: steps ?? this.steps,
        attributes: attributes,
        gateways: gateways,
        createdAt: createdAt,
        updatedAt: updatedAt,
        publishedAt: publishedAt,
        deletedAt: deletedAt,
      );
}
