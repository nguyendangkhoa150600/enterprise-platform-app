import '../../../../core/i18n/app_i18n.dart';
import 'correspondence_models.dart';

// Cấu hình Văn thư: danh mục, quy trình, sổ đăng ký.

class CatalogItem {
  final String id;
  final String kind;
  final String code;
  final String name;
  final int sortOrder;
  final bool isActive;
  final String? workflowId;
  final String? outgoingWorkflowId;
  final int? defaultDueDays;
  final bool restricted;

  const CatalogItem({
    required this.id,
    required this.kind,
    required this.code,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
    this.workflowId,
    this.outgoingWorkflowId,
    this.defaultDueDays,
    this.restricted = false,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] != false,
      workflowId: json['workflowId']?.toString(),
      outgoingWorkflowId: json['outgoingWorkflowId']?.toString(),
      defaultDueDays: (json['defaultDueDays'] as num?)?.toInt(),
      restricted: json['restricted'] == true,
    );
  }
}

/// Bước trong quy trình
class WorkflowStepModel {
  final String key;
  final String name;
  final String? type;
  final Map<String, dynamic>? approver;
  final bool directs;
  final List<dynamic>? units;
  final bool lockUnits;
  final Map<String, dynamic>? condition;

  const WorkflowStepModel({
    required this.key,
    required this.name,
    this.type,
    this.approver,
    this.directs = false,
    this.units,
    this.lockUnits = false,
    this.condition,
  });

  factory WorkflowStepModel.fromJson(Map<String, dynamic> json) {
    return WorkflowStepModel(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString(),
      approver: json['approver'] is Map<String, dynamic> ? json['approver'] as Map<String, dynamic> : null,
      directs: json['directs'] == true,
      units: json['units'] is List ? json['units'] as List : null,
      lockUnits: json['lockUnits'] == true,
      condition: json['condition'] is Map<String, dynamic> ? json['condition'] as Map<String, dynamic> : null,
    );
  }

  String formatSubtitle(CorrespondenceDirectory directory) {
    if (type == 'process') {
      if (units == null || units!.isEmpty) {
        return 'correspondence.model.step_subtitle.process_chosen_by_previous'.tr();
      }
      final names = units!.map((u) {
        if (u is Map) {
          final uid = u['unitId']?.toString();
          final found = directory.units.where((unit) => unit.id == uid).firstOrNull;
          return found?.name ?? 'correspondence.model.step_subtitle.unit_fallback'.tr();
        }
        return 'correspondence.model.step_subtitle.unit_fallback'.tr();
      }).join(', ');
      return (lockUnits ? 'correspondence.model.step_subtitle.process_always' : 'correspondence.model.step_subtitle.process_preset').tr(args: {'units': names});
    }

    if (approver != null) {
      final ruleType = approver!['type']?.toString();
      String who = '';
      if (ruleType == 'users') {
        final userIds = approver!['userIds'] as List? ?? [];
        who = userIds.map((uid) {
          final p = directory.people.where((person) => person.userId == uid).firstOrNull;
          return p?.name ?? 'correspondence.model.step_subtitle.user_fallback'.tr();
        }).join(', ');
      } else if (ruleType == 'positions') {
        final posIds = approver!['positionIds'] as List? ?? [];
        who = posIds.map((pid) {
          final pos = directory.positions.where((p) => p.id == pid).firstOrNull;
          if (pos == null) return 'correspondence.model.step_subtitle.position_fallback'.tr();
          return '${pos.name}${pos.holderNames.isNotEmpty ? " (${pos.holderNames.join(', ')})" : ""}';
        }).join(', ');
      } else if (ruleType == 'unit_heads') {
        final unitIds = approver!['unitIds'] as List? ?? [];
        final uNames = unitIds.map((uid) {
          final u = directory.units.where((unit) => unit.id == uid).firstOrNull;
          return u?.name ?? 'correspondence.model.step_subtitle.org_unit_fallback'.tr();
        }).join(', ');
        who = 'correspondence.model.step_subtitle.unit_heads'.tr(args: {'units': uNames});
      } else if (ruleType == 'choose') {
        final pool = approver!['pool']?.toString();
        who = (pool == "leaders" ? 'correspondence.model.step_subtitle.choose_leaders' : pool == "positions" ? 'correspondence.model.step_subtitle.choose_positions' : 'correspondence.model.step_subtitle.choose_units').tr();
      } else {
        who = 'correspondence.model.step_subtitle.leader_approve'.tr();
      }

      return (directs ? 'correspondence.model.step_subtitle.approver_directs' : 'correspondence.model.step_subtitle.approver').tr(args: {'who': who});
    }

    return 'correspondence.model.step_subtitle.clerk'.tr();
  }
}

/// Quy trình duyệt công văn
class WorkflowModel {
  final String id;
  final String name;
  final String? description;
  final String direction;
  final bool isActive;
  final bool isDefault;
  final String? startName;
  final String? endName;
  final List<WorkflowStepModel> steps;

  const WorkflowModel({
    required this.id,
    required this.name,
    this.description,
    required this.direction,
    this.isActive = true,
    this.isDefault = false,
    this.startName,
    this.endName,
    this.steps = const [],
  });

  factory WorkflowModel.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] as List? ?? [];
    return WorkflowModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      direction: json['direction']?.toString() ?? 'outgoing',
      isActive: json['isActive'] != false,
      isDefault: json['isDefault'] == true,
      startName: json['startName']?.toString(),
      endName: json['endName']?.toString(),
      steps: rawSteps
          .whereType<Map<String, dynamic>>()
          .map((e) => WorkflowStepModel.fromJson(e))
          .toList(),
    );
  }
}

/// Sổ đăng ký văn thư
class RegisterBookModel {
  final String id;
  final String name;
  final String direction;
  final bool confidential;
  final bool isActive;

  const RegisterBookModel({
    required this.id,
    required this.name,
    this.direction = 'incoming',
    this.confidential = false,
    this.isActive = true,
  });

  factory RegisterBookModel.fromJson(Map<String, dynamic> json) {
    return RegisterBookModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'incoming',
      confidential: json['confidential'] == true,
      isActive: json['isActive'] != false,
    );
  }
}

/// Cấu hình văn thư
class CorrespondenceConfig {
  final List<CatalogItem> catalog;
  final List<WorkflowModel> workflows;
  final List<RegisterBookModel> books;

  const CorrespondenceConfig({
    this.catalog = const [],
    this.workflows = const [],
    this.books = const [],
  });

  factory CorrespondenceConfig.fromJson(Map<String, dynamic> json) {
    final rawCatalog = json['catalog'] as List? ?? [];
    final rawWorkflows = json['workflows'] as List? ?? [];
    final rawBooks = json['books'] as List? ?? json['registers'] as List? ?? [];

    return CorrespondenceConfig(
      catalog: rawCatalog
          .whereType<Map<String, dynamic>>()
          .map((e) => CatalogItem.fromJson(e))
          .toList(),
      workflows: rawWorkflows
          .whereType<Map<String, dynamic>>()
          .map((e) => WorkflowModel.fromJson(e))
          .toList(),
      books: rawBooks
          .whereType<Map<String, dynamic>>()
          .map((e) => RegisterBookModel.fromJson(e))
          .toList(),
    );
  }
}

/// Nhân sự thành viên trong phòng ban của sơ đồ tổ chức
