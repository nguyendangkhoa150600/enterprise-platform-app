import '../core/i18n/app_i18n.dart';
// Workspace Models: Customers, Contracts, Projects, Roles, and Standalone Tasks (1:1 Web Parity)

class CustomerItem {
  final String id;
  final String code;
  final String name;
  final String? note;
  final int contractCount;
  final int projectCount;
  final DateTime createdAt;

  const CustomerItem({
    required this.id,
    required this.code,
    required this.name,
    this.note,
    this.contractCount = 0,
    this.projectCount = 0,
    required this.createdAt,
  });

  factory CustomerItem.fromJson(Map<String, dynamic> json) {
    return CustomerItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'models.workspace.customer_unnamed'.tr(),
      note: json['note']?.toString(),
      contractCount: parseInt(json['contractCount']),
      projectCount: parseInt(json['projectCount']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static int parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ContractItem {
  final String id;
  final String customerId;
  final String code;
  final String name;
  final String status; // 'draft' | 'active' | 'completed' | 'cancelled'
  final double? value;
  final DateTime? signedDate;
  final String? note;
  final String? projectId;
  final String? projectName;
  final DateTime createdAt;

  const ContractItem({
    required this.id,
    required this.customerId,
    required this.code,
    required this.name,
    required this.status,
    this.value,
    this.signedDate,
    this.note,
    this.projectId,
    this.projectName,
    required this.createdAt,
  });

  factory ContractItem.fromJson(Map<String, dynamic> json, [Map<String, String>? projectMap]) {
    final pid = json['projectId']?.toString();
    return ContractItem(
      id: json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'models.workspace.contract_unnamed'.tr(),
      status: json['status']?.toString() ?? 'draft',
      value: json['value'] != null ? double.tryParse(json['value'].toString()) : null,
      signedDate: json['signedDate'] != null ? DateTime.tryParse(json['signedDate'].toString()) : null,
      note: json['note']?.toString(),
      projectId: pid,
      projectName: pid != null && projectMap != null ? projectMap[pid] : json['projectName']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'models.workspace.in_progress'.tr();
      case 'completed':
        return 'models.workspace.completed'.tr();
      case 'cancelled':
        return 'models.workspace.cancelled'.tr();
      case 'draft':
      default:
        return 'models.status.draft'.tr();
    }
  }
}

class ProjectItem {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String status; // 'draft' | 'active' | 'completed' | 'cancelled'
  final String? projectType;
  final String? customerId;
  final String? customerName;
  final double progressPercent;
  final int totalItems;
  final int closedItems;
  final int overdueItems;
  final String? myRole;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<StandaloneTaskItem> tasks;

  const ProjectItem({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.status,
    this.projectType,
    this.customerId,
    this.customerName,
    this.progressPercent = 0.0,
    this.totalItems = 0,
    this.closedItems = 0,
    this.overdueItems = 0,
    this.myRole,
    this.startDate,
    this.endDate,
    this.tasks = const [],
  });

  factory ProjectItem.fromJson(Map<String, dynamic> json, [Map<String, String>? customerMap]) {
    final cid = json['customerId']?.toString();
    final rawTasks = json['tasks'] ?? json['items'] ?? json['children'];
    List<StandaloneTaskItem> taskList = [];
    if (rawTasks is List) {
      taskList = rawTasks.map((t) => StandaloneTaskItem.fromJson(Map<String, dynamic>.from(t as Map))).toList();
    }

    return ProjectItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'models.workspace.project_unnamed'.tr(),
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'active',
      projectType: json['projectType']?.toString(),
      customerId: cid,
      customerName: cid != null && customerMap != null ? customerMap[cid] : json['customerName']?.toString(),
      progressPercent: json['progressPercent'] != null ? (double.tryParse(json['progressPercent'].toString()) ?? 0.0) : 0.0,
      totalItems: CustomerItem.parseInt(json['totalItems']),
      closedItems: CustomerItem.parseInt(json['closedItems']),
      overdueItems: CustomerItem.parseInt(json['overdueItems']),
      myRole: json['myRole']?.toString(),
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'].toString()) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString()) : null,
      tasks: taskList,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'models.workspace.deploying'.tr();
      case 'completed':
        return 'models.workspace.completed'.tr();
      case 'cancelled':
        return 'models.workspace.cancelled'.tr();
      case 'draft':
      default:
        return 'models.workspace.initiated'.tr();
    }
  }

  String get typeLabel => projectType != null && projectType!.isNotEmpty ? projectType! : 'models.workspace.uncategorized'.tr();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ProjectMemberItem {
  final String userId;
  final String? fullName;
  final String? email;
  final String role; // 'manager' | 'technician' | 'viewer'

  const ProjectMemberItem({
    required this.userId,
    this.fullName,
    this.email,
    required this.role,
  });

  factory ProjectMemberItem.fromJson(Map<String, dynamic> json) {
    return ProjectMemberItem(
      userId: json['userId']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['name']?.toString() ?? 'models.workspace.member'.tr(),
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'technician',
    );
  }

  String get roleLabel {
    switch (role) {
      case 'manager':
        return 'models.workspace.project_manager'.tr();
      case 'technician':
        return 'models.maintenance.technician'.tr();
      case 'viewer':
      default:
        return 'models.workspace.viewer'.tr();
    }
  }
}

class StandaloneTaskItem {
  final String id;
  final String code;
  final String title;
  final String? description;
  final String status; // 'todo' | 'in_progress' | 'review' | 'done' | 'cancelled'
  final String priority; // 'urgent' | 'high' | 'normal' | 'low'
  final String assigneeUserId;
  final String? assigneeName;
  final double progressPercent;
  final DateTime? dueDate;
  final String myRole; // 'assigner' | 'assignee' | 'participant' | 'follower'
  final int childCount;
  final int openChildCount;
  final bool isReversed;

  const StandaloneTaskItem({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.assigneeUserId,
    this.assigneeName,
    this.progressPercent = 0.0,
    this.dueDate,
    this.myRole = 'assignee',
    this.childCount = 0,
    this.openChildCount = 0,
    this.isReversed = false,
  });

  factory StandaloneTaskItem.fromJson(Map<String, dynamic> json) {
    final task = json['task'] is Map ? json['task'] as Map<String, dynamic> : (json['item'] is Map ? json['item'] as Map<String, dynamic> : json);
    final role = json['myRole']?.toString() ?? task['myRole']?.toString() ?? 'assignee';

    DateTime? parsedDue;
    for (final key in ['dueDate', 'plannedEnd', 'endDate', 'due_date', 'deadline']) {
      if (task[key] != null) {
        parsedDue = DateTime.tryParse(task[key].toString());
        if (parsedDue != null) break;
      }
    }

    return StandaloneTaskItem(
      id: task['id']?.toString() ?? '',
      code: task['code']?.toString() ?? '',
      title: task['title']?.toString() ?? 'models.workspace.task_unnamed'.tr(),
      description: task['description']?.toString(),
      status: task['status']?.toString() ?? 'todo',
      priority: task['priority']?.toString() ?? 'normal',
      assigneeUserId: task['assigneeUserId']?.toString() ?? '',
      assigneeName: task['assigneeName']?.toString() ?? task['assignee']?['name']?.toString(),
      progressPercent: task['progressPercent'] != null ? (double.tryParse(task['progressPercent'].toString()) ?? 0.0) : 0.0,
      dueDate: parsedDue,
      myRole: role,
      childCount: CustomerItem.parseInt(task['childCount']),
      openChildCount: CustomerItem.parseInt(task['openChildCount']),
      isReversed: task['reversal'] != null,
    );
  }

  String get statusLabel {
    if (isReversed) return 'Đã huỷ hiệu lực';
    switch (status) {
      case 'in_progress':
        return 'Đang làm';
      case 'blocked':
        return 'Vướng mắc';
      case 'review':
        return 'Chờ duyệt';
      case 'done':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã huỷ';
      case 'todo':
      default:
        return 'Chưa làm';
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'urgent':
        return 'Khẩn cấp';
      case 'high':
        return 'Cao';
      case 'low':
        return 'Thấp';
      case 'normal':
      default:
        return 'Bình thường';
    }
  }
}

class DepartmentItem {
  final String id;
  final String name;
  final String? parentPath;
  final String? parentId;

  const DepartmentItem({
    required this.id,
    required this.name,
    this.parentPath,
    this.parentId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepartmentItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A document of the workspace (GET /workspace/v1/documents), flattened with its current version.
class WorkspaceDocumentItem {
  final String id;
  final String name;
  final String? description;
  final String? projectId;
  final String status;
  final String fileName;
  final String contentType;
  final int? sizeBytes;
  final int versionCount;
  final DateTime? updatedAt;

  const WorkspaceDocumentItem({
    required this.id,
    required this.name,
    this.description,
    this.projectId,
    this.status = 'active',
    this.fileName = '',
    this.contentType = '',
    this.sizeBytes,
    this.versionCount = 0,
    this.updatedAt,
  });

  factory WorkspaceDocumentItem.fromJson(Map<String, dynamic> json) {
    final v = json['currentVersion'];
    final ver = v is Map<String, dynamic> ? v : const <String, dynamic>{};
    return WorkspaceDocumentItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      projectId: json['projectId']?.toString(),
      status: json['status']?.toString() ?? 'active',
      fileName: ver['fileName']?.toString() ?? '',
      contentType: ver['contentType']?.toString() ?? '',
      sizeBytes: (ver['sizeBytes'] as num?)?.toInt(),
      versionCount: (json['versionCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal(),
    );
  }

  /// 'PDF' | 'WORD' | 'EXCEL' | 'OTHER'
  String get kind {
    final n = (fileName.isNotEmpty ? fileName : name).toLowerCase();
    final t = contentType.toLowerCase();
    if (t.contains('pdf') || n.endsWith('.pdf')) return 'PDF';
    if (t.contains('word') || n.endsWith('.doc') || n.endsWith('.docx')) return 'WORD';
    if (t.contains('sheet') || t.contains('excel') || n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv')) return 'EXCEL';
    return 'OTHER';
  }

  String get sizeLabel {
    final b = sizeBytes;
    if (b == null) return '';
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).round()} KB';
    return '$b B';
  }
}
