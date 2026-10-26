import 'dart:math';
import '../core/i18n/app_i18n.dart';

String generateProcedureUuidV4() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40; // Version 4
  values[8] = (values[8] & 0x3f) | 0x80; // Variant RFC4122
  final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

enum ProcedureSlaState { none, ok, warning, breached }

class ProcedureRuntimeAuthorization {
  final List<String> myRoles;
  final String? currentRoleStage;
  final List<String> availableActions;
  final bool canComment;
  final bool canDelete;
  final bool canSupplement;
  final bool isOverride;
  final List<String> returnTargetStepIds;
  final List<String> editableAttributeKeys;

  ProcedureRuntimeAuthorization({
    this.myRoles = const [],
    this.currentRoleStage,
    this.availableActions = const [],
    this.canComment = false,
    this.canDelete = false,
    this.canSupplement = false,
    this.isOverride = false,
    this.returnTargetStepIds = const [],
    this.editableAttributeKeys = const [],
  });

  factory ProcedureRuntimeAuthorization.fromJson(Map<String, dynamic> json) {
    return ProcedureRuntimeAuthorization(
      myRoles: (json['myRoles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      currentRoleStage: json['currentRoleStage']?.toString(),
      availableActions: (json['availableActions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      canComment: json['canComment'] == true,
      canDelete: json['canDelete'] == true,
      canSupplement: json['canSupplement'] == true,
      isOverride: json['isOverride'] == true,
      returnTargetStepIds: (json['returnTargetStepIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      editableAttributeKeys: (json['editableAttributeKeys'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  bool get canApprove => availableActions.contains('approve');
  bool get canComplete => availableActions.contains('complete');
  bool get canReject => availableActions.contains('reject');
  bool get canReturn => availableActions.contains('return');
  bool get canCancel => availableActions.contains('cancel');
  bool get isActionable => availableActions.any((a) => a != 'comment');
}

class ProcedureInstanceStep {
  final String id;
  final String definitionStepId;
  final String key;
  final int order;
  final String name;
  final String status; // 'pending' | 'active' | 'ready' | 'completed' | 'returned' | 'rejected' | 'cancelled' | 'skipped'
  final String? currentRoleStage;
  final List<ProcedureRaciAssignment> assignments;
  final int? slaHours;
  final String? slaDueAt;
  final String? completedAt;

  ProcedureInstanceStep({
    required this.id,
    required this.definitionStepId,
    required this.key,
    required this.order,
    required this.name,
    required this.status,
    this.currentRoleStage,
    this.assignments = const [],
    this.slaHours,
    this.slaDueAt,
    this.completedAt,
  });

  factory ProcedureInstanceStep.fromJson(Map<String, dynamic> json) {
    final rawAssignments = json['assignments'] as List<dynamic>? ?? [];
    return ProcedureInstanceStep(
      id: json['id']?.toString() ?? '',
      definitionStepId: json['definitionStepId']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      currentRoleStage: json['currentRoleStage']?.toString(),
      assignments: rawAssignments.map((e) => ProcedureRaciAssignment.fromJson(e)).toList(),
      slaHours: (json['slaHours'] as num?)?.toInt(),
      slaDueAt: json['slaDueAt']?.toString(),
      completedAt: json['completedAt']?.toString(),
    );
  }

  bool get isCurrent => status == 'active' || status == 'ready';
  bool get isCompleted => status == 'completed';
}

class ProcedureActivity {
  final String id;
  final String action;
  final String actorId;
  final String actorName;
  final String summary;
  final String? comment;
  final String createdAt;
  final String? stepInstanceId;

  ProcedureActivity({
    required this.id,
    required this.action,
    required this.actorId,
    required this.actorName,
    required this.summary,
    this.comment,
    required this.createdAt,
    this.stepInstanceId,
  });

  factory ProcedureActivity.fromJson(Map<String, dynamic> json) {
    return ProcedureActivity(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      actorId: json['actorId']?.toString() ?? '',
      actorName: json['actorName']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      comment: json['comment']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      stepInstanceId: json['stepInstanceId']?.toString(),
    );
  }
}

class ProcedureAttachment {
  final String id;
  final String instanceId;
  final String fileName;
  final String contentType;
  final int? sizeBytes;
  final String uploadedBy;
  final String createdAt;
  final String? downloadUrl;

  ProcedureAttachment({
    required this.id,
    required this.instanceId,
    required this.fileName,
    required this.contentType,
    this.sizeBytes,
    required this.uploadedBy,
    required this.createdAt,
    this.downloadUrl,
  });

  factory ProcedureAttachment.fromJson(Map<String, dynamic> json) {
    return ProcedureAttachment(
      id: json['id']?.toString() ?? '',
      instanceId: json['instanceId']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      uploadedBy: json['uploadedBy']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      downloadUrl: json['downloadUrl']?.toString(),
    );
  }
}

class ProcedureInstance {
  final String id;
  final String code;
  final String title;
  final String definitionId;
  final String definitionCode;
  final String definitionName;
  final int definitionVersion;
  final String status; // 'running' | 'completed' | 'rejected' | 'cancelled' | 'reversed'
  final String? currentStepId;
  final String initiatedBy;
  final String? creatorName;
  final String startedAt;
  final String? completedAt;
  final List<ProcedureInstanceStep> steps;
  final List<ProcedureActivity> activity;
  final ProcedureRuntimeAuthorization? authorization;
  final String category;
  final String stage;
  final String priority;
  final String? assigneeName;
  final String? slaStatus;
  final int subtasksCount;
  final int completedSubtasksCount;
  final String? source;

  ProcedureInstance({
    required this.id,
    required this.code,
    required this.title,
    this.definitionId = '',
    this.definitionCode = '',
    this.definitionName = '',
    this.definitionVersion = 1,
    required this.status,
    this.currentStepId,
    this.initiatedBy = '',
    this.creatorName,
    required this.startedAt,
    this.completedAt,
    this.steps = const [],
    this.activity = const [],
    this.authorization,
    String? category,
    this.stage = 'IN_PROGRESS',
    this.priority = 'MEDIUM',
    this.assigneeName,
    this.slaStatus = 'ON_TIME',
    this.subtasksCount = 0,
    this.completedSubtasksCount = 0,
    this.source,
  }) : category = category ?? 'models.procedure.default_category'.tr();

  factory ProcedureInstance.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] as List<dynamic>? ?? [];
    final stepsList = rawSteps
        .map((e) => ProcedureInstanceStep.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final rawActivity = json['activity'] as List<dynamic>? ?? [];
    final activityList = rawActivity
        .map((e) => ProcedureActivity.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final authJson = json['authorization'] as Map<String, dynamic>?;
    final authorization = authJson != null ? ProcedureRuntimeAuthorization.fromJson(authJson) : null;

    final rawStatus = (json['status'] ?? json['stage'])?.toString().toLowerCase() ?? 'running';
    String normStatus = 'running';
    if (rawStatus.contains('complete')) {
      normStatus = 'completed';
    } else if (rawStatus.contains('reject')) {
      normStatus = 'rejected';
    } else if (rawStatus.contains('cancel')) {
      normStatus = 'cancelled';
    } else if (rawStatus.contains('reverse')) {
      normStatus = 'reversed';
    }

    final createdAt = json['startedAt']?.toString() ?? json['createdAt']?.toString() ?? '';

    // Calculate SLA status
    String calculatedSla = 'ON_TIME';
    if (normStatus == 'completed') {
      calculatedSla = 'ON_TIME';
    } else {
      ProcedureInstanceStep? activeStep;
      if (json['currentStepId'] != null) {
        for (final s in stepsList) {
          if (s.id == json['currentStepId']) {
            activeStep = s;
            break;
          }
        }
      }
      activeStep ??= stepsList.where((s) => s.isCurrent).firstOrNull ?? (stepsList.isNotEmpty ? stepsList.first : null);
      if (activeStep?.slaDueAt != null && activeStep!.slaDueAt!.isNotEmpty) {
        try {
          final due = DateTime.parse(activeStep.slaDueAt!);
          final now = DateTime.now();
          if (now.isAfter(due)) {
            calculatedSla = 'BREACHED';
          } else if (due.difference(now).inHours <= 4) {
            calculatedSla = 'AT_RISK';
          }
        } catch (_) {}
      }
    }

    return ProcedureInstance(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['id']?.toString() ?? 'PRC-001',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'models.procedure.default_title'.tr(),
      definitionId: json['definitionId']?.toString() ?? '',
      definitionCode: json['definitionCode']?.toString() ?? '',
      definitionName: json['definitionName']?.toString() ?? json['category']?.toString() ?? 'models.notif.cat_procedure'.tr(),
      definitionVersion: (json['definitionVersion'] as num?)?.toInt() ?? 1,
      status: normStatus,
      currentStepId: json['currentStepId']?.toString(),
      initiatedBy: json['initiatedBy']?.toString() ?? '',
      creatorName: json['creatorName']?.toString() ??
          json['actorName']?.toString() ??
          (json['createdOnBehalfBy'] is Map ? json['createdOnBehalfBy']['name']?.toString() : null) ??
          (json['createdOnBehalfBy'] is String ? json['createdOnBehalfBy'].toString() : null),
      startedAt: createdAt,
      completedAt: json['completedAt']?.toString(),
      steps: stepsList,
      activity: activityList,
      authorization: authorization,
      category: json['category']?.toString() ?? json['definitionName']?.toString() ?? 'models.procedure.default_category'.tr(),
      stage: normStatus == 'completed' ? 'COMPLETED' : 'IN_PROGRESS',
      priority: json['priority']?.toString().toUpperCase() ?? 'MEDIUM',
      assigneeName: json['assigneeName']?.toString() ?? json['actorName']?.toString() ?? authorization?.currentRoleStage,
      slaStatus: json['slaStatus']?.toString().toUpperCase() ?? calculatedSla,
      subtasksCount: (json['subtasksCount'] as num?)?.toInt() ?? (json['subtasks'] is List ? (json['subtasks'] as List).length : 0),
      completedSubtasksCount: (json['completedSubtasksCount'] as num?)?.toInt() ?? 0,
      source: json['source']?.toString() ?? json['origin']?.toString() ?? 'MANUAL',
    );
  }

  String get createdAt => startedAt.isNotEmpty ? startedAt : (completedAt ?? '');

  bool get isRunning => status == 'running';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isActionable {
    if (!isRunning) return false;
    if (authorization != null) {
      if (authorization!.isActionable) return true;
      if (authorization!.isOverride) return true;
      if (authorization!.myRoles.isNotEmpty) return true;
    }
    return true;
  }

  String get currentStepOnlyName {
    final step = currentStep;
    if (step == null) return 'models.status.processing'.tr();
    return 'models.procedure.step_label'.tr(args: {'order': step.order, 'name': step.name});
  }

  String get currentRole {
    return authorization?.currentRoleStage ??
        (currentStep?.assignments.isNotEmpty == true ? currentStep!.assignments.first.role : 'S');
  }

  String get submitterDisplayName {
    if (creatorName != null && creatorName!.isNotEmpty) return creatorName!;
    for (final act in activity) {
      if (act.action == 'start' && act.actorName.isNotEmpty) {
        return act.actorName;
      }
    }
    for (final act in activity) {
      if (act.actorName.isNotEmpty) return act.actorName;
    }
    return initiatedBy.isNotEmpty ? initiatedBy : 'Ngô Tấn Trình';
  }

  String get sourceLabel => (source?.toUpperCase() == 'SYSTEM' || source?.toLowerCase() == 'automated')
      ? 'models.procedure.system'.tr()
      : 'models.procedure.manual'.tr();

  ProcedureInstanceStep? get currentStep {
    if (steps.isEmpty) return null;
    if (currentStepId != null) {
      for (final s in steps) {
        if (s.id == currentStepId) return s;
      }
    }
    for (final s in steps) {
      if (s.isCurrent) return s;
    }
    return steps.first;
  }

  ProcedureSlaState get slaState {
    final step = currentStep;
    final dueStr = step?.slaDueAt;
    if (dueStr == null || dueStr.isEmpty) return ProcedureSlaState.none;
    try {
      final due = DateTime.parse(dueStr).toLocal();
      final stoppedAtStr = step?.completedAt ?? completedAt;
      final ref = stoppedAtStr != null && stoppedAtStr.isNotEmpty
          ? DateTime.parse(stoppedAtStr).toLocal()
          : DateTime.now();
      final remainingMs = due.millisecondsSinceEpoch - ref.millisecondsSinceEpoch;
      if (remainingMs <= 0) return ProcedureSlaState.breached;
      // 4 hours warning threshold (PROCEDURE_SLA_WARNING_MS = 4 * 60 * 60 * 1000)
      if (remainingMs <= 4 * 3600 * 1000) return ProcedureSlaState.warning;
      return ProcedureSlaState.ok;
    } catch (_) {
      return ProcedureSlaState.none;
    }
  }

  String? get slaCountdownText {
    final step = currentStep;
    final dueStr = step?.slaDueAt;
    if (dueStr == null || dueStr.isEmpty) return null;
    try {
      final due = DateTime.parse(dueStr).toLocal();
      final stoppedAtStr = step?.completedAt ?? completedAt;
      final ref = stoppedAtStr != null && stoppedAtStr.isNotEmpty
          ? DateTime.parse(stoppedAtStr).toLocal()
          : DateTime.now();
      final diffMs = due.millisecondsSinceEpoch - ref.millisecondsSinceEpoch;
      final totalMinutes = (diffMs.abs() / 60000).round();
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      final durStr = hours == 0 ? '${minutes}p' : (minutes == 0 ? '${hours}h' : '${hours}h ${minutes}p');
      if (diffMs <= 0) {
        return 'models.procedure.overdue_by'.tr(args: {'duration': durStr});
      } else {
        return 'models.procedure.remaining'.tr(args: {'duration': durStr});
      }
    } catch (_) {
      return null;
    }
  }

  bool get isSlaBreached => slaState == ProcedureSlaState.breached;
  bool get isSlaWarning => slaState == ProcedureSlaState.warning;
  bool get isSlaOk => slaState == ProcedureSlaState.ok;
  bool get isSlaNone => slaState == ProcedureSlaState.none;

  String get currentStepLabel {
    final step = currentStep;
    if (step == null) return 'models.procedure.initializing'.tr();
    final role = authorization?.currentRoleStage ?? (step.assignments.isNotEmpty ? step.assignments.first.role : null);
    final roleText = role != null && role.isNotEmpty ? 'models.procedure.role_suffix'.tr(args: {'role': role}) : '';
    return 'models.procedure.step_label_role'.tr(args: {'order': step.order, 'name': step.name, 'role': roleText});
  }
}

class ProcedureWorkspaceStats {
  final int total;
  final int inProgress;
  final int pendingApproval;
  final int completed;
  final int slaBreached;

  ProcedureWorkspaceStats({
    required this.total,
    required this.inProgress,
    required this.pendingApproval,
    required this.completed,
    required this.slaBreached,
  });
}

class ProcedureRaciAssignment {
  final String role; // 'S', 'R', 'A', 'C', 'I', 'E'
  final String? subjectType;
  final String? subjectId;
  final String? subjectLabel;

  ProcedureRaciAssignment({
    required this.role,
    this.subjectType,
    this.subjectId,
    this.subjectLabel,
  });

  factory ProcedureRaciAssignment.fromJson(dynamic json) {
    if (json == null) return ProcedureRaciAssignment(role: 'S');
    if (json is String) return ProcedureRaciAssignment(role: json.trim().toUpperCase());
    if (json is Map<String, dynamic>) {
      final roleStr = json['role']?.toString().trim().toUpperCase() ?? 'S';
      return ProcedureRaciAssignment(
        role: roleStr.isNotEmpty ? roleStr : 'S',
        subjectType: json['subjectType']?.toString(),
        subjectId: json['subjectId']?.toString(),
        subjectLabel: json['subjectLabel']?.toString(),
      );
    }
    return ProcedureRaciAssignment(role: 'S');
  }
}

class ProcedureStepDefinition {
  final String id;
  final String key;
  final int order;
  final String name;
  final String? description;
  final List<ProcedureRaciAssignment> assignments;

  ProcedureStepDefinition({
    required this.id,
    required this.key,
    required this.order,
    required this.name,
    this.description,
    this.assignments = const [],
  });

  factory ProcedureStepDefinition.fromJson(Map<String, dynamic> json) {
    final rawAssignments = json['assignments'] as List<dynamic>? ?? [];
    return ProcedureStepDefinition(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      assignments: rawAssignments
          .map((e) => ProcedureRaciAssignment.fromJson(e))
          .toList(),
    );
  }

  List<String> get roles {
    final set = <String>{};
    for (final a in assignments) {
      if (a.role.isNotEmpty) set.add(a.role);
    }
    return set.toList();
  }
}

class ProcedureDefinition {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String? category;
  final String status; // 'published' | 'draft' | 'archived'
  final int versionNumber;
  final List<ProcedureStepDefinition> steps;

  ProcedureDefinition({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.category,
    required this.status,
    this.versionNumber = 1,
    this.steps = const [],
  });

  factory ProcedureDefinition.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] as List<dynamic>? ?? [];
    final stepsList = rawSteps
        .map((e) => ProcedureStepDefinition.fromJson(e as Map<String, dynamic>))
        .toList();
    stepsList.sort((a, b) => a.order.compareTo(b.order));

    return ProcedureDefinition(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      versionNumber: (json['versionNumber'] as num?)?.toInt() ?? 1,
      steps: stepsList,
    );
  }

  String get displayName {
    final count = steps.length;
    final statusText = status == 'published' ? 'models.procedure.published'.tr() : 'models.status.draft'.tr();
    return 'models.procedure.def_summary'.tr(args: {'name': name, 'count': count, 'status': statusText});
  }
}

class ProcedureWorkspaceData {
  final String tenantId;
  final Map<String, dynamic> actor;
  final Map<String, dynamic> permissions;
  final List<ProcedureInstance> instances;
  final List<ProcedureDefinition> definitions;

  ProcedureWorkspaceData({
    this.tenantId = '',
    this.actor = const {},
    this.permissions = const {},
    required this.instances,
    required this.definitions,
  });

  factory ProcedureWorkspaceData.fromJson(Map<String, dynamic> json) {
    final map = (json['data'] is Map<String, dynamic>) ? json['data'] as Map<String, dynamic> : json;
    final rawInstances = (map['instances'] ?? json['instances']) as List<dynamic>? ?? [];
    final rawDefs = (map['definitions'] ?? json['definitions']) as List<dynamic>? ?? [];

    final instances = rawInstances
        .map((e) => ProcedureInstance.fromJson(e as Map<String, dynamic>))
        .toList();

    final definitions = rawDefs
        .map((e) => ProcedureDefinition.fromJson(e as Map<String, dynamic>))
        .where((d) => d.steps.isNotEmpty)
        .toList();

    return ProcedureWorkspaceData(
      tenantId: (map['tenantId'] ?? json['tenantId'])?.toString() ?? '',
      actor: (map['actor'] ?? json['actor']) as Map<String, dynamic>? ?? {},
      permissions: (map['permissions'] ?? json['permissions']) as Map<String, dynamic>? ?? {},
      instances: instances,
      definitions: definitions,
    );
  }
}
