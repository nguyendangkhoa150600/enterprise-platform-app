import '../utils/user_resolver.dart';
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
  final List<String> myPermissions;
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
    this.myPermissions = const [],
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

    final rawPerms = json['myPermissions'];
    List<String> perms = [];
    if (rawPerms is List) {
      perms = rawPerms.map((e) => e.toString()).toList();
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
      myPermissions: perms,
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'].toString()) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString()) : null,
      tasks: taskList,
    );
  }

  bool get canSubmit {
    if (myRole == null || myRole!.isEmpty) return false;
    const submitterRoles = {'owner', 'manager', 'member'};
    if (myPermissions.isEmpty) {
      return submitterRoles.contains(myRole);
    }
    return myPermissions.contains('project.update_all') ||
        myPermissions.contains('project.update_related');
  }

  String get statusLabel {
    switch (status) {
      case 'active':
      case 'deploying':
      case 'in_progress':
        return 'Đang triển khai';
      case 'planning':
        return 'Đang lập kế hoạch';
      case 'paused':
      case 'blocked':
      case 'on_hold':
        return 'Tạm dừng';
      case 'completed':
      case 'done':
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
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Chủ nhiệm';
      case 'manager':
      case 'pm':
        return 'Quản lý';
      case 'member':
      case 'technician':
        return 'Thành viên';
      case 'viewer':
      default:
        return 'Người xem';
    }
  }
}

class StandaloneTaskItem {
  final String id;
  final String code;
  final String title;
  final String? description;
  final String status; // 'todo' | 'in_progress' | 'review' | 'done' | 'cancelled' | 'blocked'
  final String priority; // 'urgent' | 'high' | 'normal' | 'low'
  final String assigneeUserId;
  final String? assigneeName;
  final String createdBy;
  final String? creatorName;
  final double progressPercent;
  final DateTime? plannedStart;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final List<String> participantUserIds;
  final List<String> followerUserIds;
  final String myRole; // 'assigner' | 'assignee' | 'participant' | 'follower'
  final int childCount;
  final int openChildCount;
  final bool isReversed;
  final String? reversalReason;
  final String? blockedReason;

  const StandaloneTaskItem({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.assigneeUserId,
    this.assigneeName,
    this.createdBy = '',
    this.creatorName,
    this.progressPercent = 0.0,
    this.plannedStart,
    this.dueDate,
    this.createdAt,
    this.participantUserIds = const [],
    this.followerUserIds = const [],
    this.myRole = 'assignee',
    this.childCount = 0,
    this.openChildCount = 0,
    this.isReversed = false,
    this.reversalReason,
    this.blockedReason,
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

    DateTime? parsedStart;
    for (final key in ['plannedStart', 'startDate', 'start_date']) {
      if (task[key] != null) {
        parsedStart = DateTime.tryParse(task[key].toString());
        if (parsedStart != null) break;
      }
    }

    DateTime? parsedCreated;
    if (task['createdAt'] != null) {
      parsedCreated = DateTime.tryParse(task['createdAt'].toString());
    }

    final assigneeId = task['assigneeUserId']?.toString() ?? '';
    final creatorId = task['createdBy']?.toString() ?? '';

    final pUsers = (task['participantUserIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final fUsers = (task['followerUserIds'] as List?)?.map((e) => e.toString()).toList() ?? [];

    String? resolvedAssignee = task['assigneeName']?.toString() ??
        task['assignee']?['name']?.toString() ??
        task['assignee']?['fullName']?.toString() ??
        task['assigneeUserName']?.toString();
    if (resolvedAssignee != null && (UserResolver.isUuid(resolvedAssignee) || resolvedAssignee == assigneeId)) {
      resolvedAssignee = null;
    }
    if (resolvedAssignee == null && assigneeId.isNotEmpty) {
      final name = UserResolver.resolveName(assigneeId);
      if (name != '—' && !UserResolver.isUuid(name)) {
        resolvedAssignee = name;
      }
    }

    String? resolvedCreator = task['creatorName']?.toString() ??
        task['creator']?['name']?.toString() ??
        task['creator']?['fullName']?.toString() ??
        task['creatorUserName']?.toString();
    if (resolvedCreator != null && (UserResolver.isUuid(resolvedCreator) || resolvedCreator == creatorId)) {
      resolvedCreator = null;
    }
    if (resolvedCreator == null && creatorId.isNotEmpty) {
      final name = UserResolver.resolveName(creatorId);
      if (name != '—' && !UserResolver.isUuid(name)) {
        resolvedCreator = name;
      }
    }

    return StandaloneTaskItem(
      id: task['id']?.toString() ?? '',
      code: task['code']?.toString() ?? '',
      title: task['title']?.toString() ?? 'models.workspace.task_unnamed'.tr(),
      description: task['description']?.toString(),
      status: task['status']?.toString() ?? 'todo',
      priority: task['priority']?.toString() ?? 'normal',
      assigneeUserId: assigneeId,
      assigneeName: resolvedAssignee,
      createdBy: creatorId,
      creatorName: resolvedCreator,
      progressPercent: task['progressPercent'] != null ? (double.tryParse(task['progressPercent'].toString()) ?? 0.0) : 0.0,
      plannedStart: parsedStart,
      dueDate: parsedDue,
      createdAt: parsedCreated,
      participantUserIds: pUsers,
      followerUserIds: fUsers,
      myRole: role,
      childCount: CustomerItem.parseInt(task['childCount']),
      openChildCount: CustomerItem.parseInt(task['openChildCount']),
      isReversed: task['reversal'] != null,
      reversalReason: task['reversal'] is Map ? task['reversal']['reason']?.toString() : null,
      blockedReason: task['blockedReason']?.toString() ?? task['blocked_reason']?.toString(),
    );
  }

  String get myRoleLabel {
    switch (myRole) {
      case 'assigner':
        return 'Người giao';
      case 'assignee':
        return 'Người phụ trách';
      case 'participant':
        return 'Người cùng thực hiện';
      case 'follower':
        return 'Người theo dõi';
      default:
        return 'Người giao';
    }
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

  StandaloneTaskItem copyWith({
    String? id,
    String? code,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assigneeUserId,
    String? assigneeName,
    String? createdBy,
    String? creatorName,
    double? progressPercent,
    DateTime? plannedStart,
    DateTime? dueDate,
    DateTime? createdAt,
    List<String>? participantUserIds,
    List<String>? followerUserIds,
    String? myRole,
    int? childCount,
    int? openChildCount,
    bool? isReversed,
    String? reversalReason,
  }) {
    return StandaloneTaskItem(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assigneeUserId: assigneeUserId ?? this.assigneeUserId,
      assigneeName: assigneeName ?? this.assigneeName,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      progressPercent: progressPercent ?? this.progressPercent,
      plannedStart: plannedStart ?? this.plannedStart,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      participantUserIds: participantUserIds ?? this.participantUserIds,
      followerUserIds: followerUserIds ?? this.followerUserIds,
      myRole: myRole ?? this.myRole,
      childCount: childCount ?? this.childCount,
      openChildCount: openChildCount ?? this.openChildCount,
      isReversed: isReversed ?? this.isReversed,
      reversalReason: reversalReason ?? this.reversalReason,
    );
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
/// Thư mục tài liệu Workspace: GET /api/workspace/v1/folders
class WorkspaceFolderItem {
  final String id;
  final String name;
  final String? parentId;
  final String? projectId;
  final String? color;
  final String? icon;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkspaceFolderItem({
    required this.id,
    required this.name,
    this.parentId,
    this.projectId,
    this.color,
    this.icon,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkspaceFolderItem.fromJson(Map<String, dynamic> json) {
    return WorkspaceFolderItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      parentId: json['parentId']?.toString(),
      projectId: json['projectId']?.toString(),
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
      isActive: json['isActive'] != false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal(),
    );
  }

  bool get isProjectFolder => projectId != null && projectId!.isNotEmpty;
}

/// A document of the workspace (GET /workspace/v1/documents), flattened with its current version.
class WorkspaceDocumentItem {
  final String id;
  final String name;
  final String? description;
  final String? projectId;
  final String? folderId;
  final List<String> refFolderIds;
  final String status;
  final String fileName;
  final String contentType;
  final int? sizeBytes;
  final int versionCount;
  final String? uploadedBy;
  final DateTime? updatedAt;

  const WorkspaceDocumentItem({
    required this.id,
    required this.name,
    this.description,
    this.projectId,
    this.folderId,
    this.refFolderIds = const [],
    this.status = 'active',
    this.fileName = '',
    this.contentType = '',
    this.sizeBytes,
    this.versionCount = 0,
    this.uploadedBy,
    this.updatedAt,
  });

  factory WorkspaceDocumentItem.fromJson(Map<String, dynamic> json) {
    final v = json['currentVersion'];
    final ver = v is Map<String, dynamic> ? v : const <String, dynamic>{};
    final refs = <String>[];
    if (json['refFolderIds'] is List) {
      for (final r in json['refFolderIds']) {
        if (r != null && r.toString().isNotEmpty) refs.add(r.toString());
      }
    }
    return WorkspaceDocumentItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      projectId: json['projectId']?.toString(),
      folderId: json['folderId']?.toString(),
      refFolderIds: refs,
      status: json['status']?.toString() ?? 'active',
      fileName: ver['fileName']?.toString() ?? '',
      contentType: ver['contentType']?.toString() ?? '',
      sizeBytes: (ver['sizeBytes'] as num?)?.toInt(),
      versionCount: (json['versionCount'] as num?)?.toInt() ?? 1,
      uploadedBy: ver['uploadedBy']?.toString() ?? json['createdBy']?.toString(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal(),
    );
  }

  String get versionName => 'v${versionCount > 0 ? versionCount : 1}';

  /// 'PDF' | 'WORD' | 'EXCEL' | 'IMAGE' | 'ARCHIVE' | 'OTHER'
  String get kind {
    final n = (fileName.isNotEmpty ? fileName : name).toLowerCase();
    final t = contentType.toLowerCase();
    if (t.contains('pdf') || n.endsWith('.pdf')) return 'PDF';
    if (t.contains('word') || n.endsWith('.doc') || n.endsWith('.docx')) return 'WORD';
    if (t.contains('sheet') || t.contains('excel') || n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv')) return 'EXCEL';
    if (t.startsWith('image/') || n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.webp')) return 'IMAGE';
    if (t.contains('zip') || t.contains('rar') || t.contains('tar') || t.contains('7z') || n.endsWith('.zip') || n.endsWith('.rar')) return 'ARCHIVE';
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

/// Người trong danh bạ Workspace: GET /api/workspace/v1/directory
class WorkspaceDirectoryPerson {
  final String userId;
  final String displayName;
  final String? email;
  final List<String> unitNames;
  final String? positionName;

  const WorkspaceDirectoryPerson({
    required this.userId,
    required this.displayName,
    this.email,
    this.unitNames = const [],
    this.positionName,
  });

  factory WorkspaceDirectoryPerson.fromJson(Map<String, dynamic> json) {
    final units = <String>[];
    if (json['unitNames'] is List) {
      for (final u in json['unitNames']) {
        if (u != null && u.toString().isNotEmpty) {
          units.add(u.toString());
        }
      }
    }
    return WorkspaceDirectoryPerson(
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      email: json['email']?.toString(),
      unitNames: units,
      positionName: json['positionName']?.toString(),
    );
  }

  String get subtitle {
    final parts = <String>[displayName];
    if (positionName != null && positionName!.trim().isNotEmpty) {
      parts.add(positionName!.trim());
    }
    if (unitNames.isNotEmpty) {
      parts.add(unitNames.join(', '));
    } else if (email != null && email!.trim().isNotEmpty) {
      parts.add(email!.trim());
    }
    return parts.join(' · ');
  }
}

class WorkspaceDirectoryResponse {
  final List<WorkspaceDirectoryPerson> people;
  final bool degraded;

  const WorkspaceDirectoryResponse({
    this.people = const [],
    this.degraded = false,
  });

  factory WorkspaceDirectoryResponse.fromJson(Map<String, dynamic> json) {
    final rawPeople = json['people'];
    final list = <WorkspaceDirectoryPerson>[];
    if (rawPeople is List) {
      for (final p in rawPeople) {
        if (p is Map<String, dynamic>) {
          list.add(WorkspaceDirectoryPerson.fromJson(p));
        }
      }
    }
    return WorkspaceDirectoryResponse(
      people: list,
      degraded: json['degraded'] == true,
    );
  }
}

/// Một công việc trong danh sách của màn "Trao đổi công việc" (Chat Feed)
class ProjectChatFeedItem {
  final String workItemId;
  final String? latestAt;
  final String? latestBy;
  final String? latestBody;
  final int messageCount;

  const ProjectChatFeedItem({
    required this.workItemId,
    this.latestAt,
    this.latestBy,
    this.latestBody,
    this.messageCount = 0,
  });

  factory ProjectChatFeedItem.fromJson(Map<String, dynamic> json) {
    return ProjectChatFeedItem(
      workItemId: json['workItemId']?.toString() ?? '',
      latestAt: json['latestAt']?.toString(),
      latestBy: json['latestBy']?.toString(),
      latestBody: json['latestBody']?.toString(),
      messageCount: CustomerItem.parseInt(json['messageCount']),
    );
  }
}

/// Một trang danh sách công việc của dự án cho màn Trao đổi công việc
class ProjectChatFeedPage {
  final List<ProjectChatFeedItem> items;
  final int total;
  final int page;
  final int pageSize;

  const ProjectChatFeedPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
  });

  factory ProjectChatFeedPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final list = <ProjectChatFeedItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          list.add(ProjectChatFeedItem.fromJson(item));
        }
      }
    }
    return ProjectChatFeedPage(
      items: list,
      total: CustomerItem.parseInt(json['total']),
      page: CustomerItem.parseInt(json['page']) == 0 ? 1 : CustomerItem.parseInt(json['page']),
      pageSize: CustomerItem.parseInt(json['pageSize']) == 0 ? 20 : CustomerItem.parseInt(json['pageSize']),
    );
  }
}

/// Tin nhắn trao đổi công việc
class ProjectChatMessage {
  final String id;
  final String body;
  final String createdBy;
  final String createdAt;
  final bool isDeleted;
  final bool isEdited;
  final String? parentId;
  final String? attachmentDocumentId;
  final List<String> attachmentDocumentIds;

  const ProjectChatMessage({
    required this.id,
    required this.body,
    required this.createdBy,
    required this.createdAt,
    this.isDeleted = false,
    this.isEdited = false,
    this.parentId,
    this.attachmentDocumentId,
    this.attachmentDocumentIds = const [],
  });

  factory ProjectChatMessage.fromJson(Map<String, dynamic> json) {
    final list = (json['attachmentDocumentIds'] as List?)?.map((e) => e.toString()).toList() ??
        (json['attachment_document_ids'] as List?)?.map((e) => e.toString()).toList() ??
        [];
    final singleId = json['attachmentDocumentId']?.toString() ?? json['attachment_document_id']?.toString();
    if (list.isEmpty && singleId != null && singleId.isNotEmpty) {
      list.add(singleId);
    }

    return ProjectChatMessage(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      isDeleted: json['isDeleted'] == true,
      isEdited: json['isEdited'] == true,
      parentId: json['parentId']?.toString(),
      attachmentDocumentId: singleId,
      attachmentDocumentIds: list,
    );
  }
}

/// Luồng trao đổi của một công việc
class ProjectChatThread {
  final List<ProjectChatMessage> messages;
  final bool hasMore;

  const ProjectChatThread({
    this.messages = const [],
    this.hasMore = false,
  });

  factory ProjectChatThread.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final list = <ProjectChatMessage>[];
    if (rawMessages is List) {
      for (final m in rawMessages) {
        if (m is Map<String, dynamic>) {
          list.add(ProjectChatMessage.fromJson(m));
        }
      }
    }
    return ProjectChatThread(
      messages: list,
      hasMore: json['hasMore'] == true,
    );
  }
}

/// Điều kiện hoàn thành công việc
class WorkItemCompletionCondition {
  final String id;
  final String label;

  const WorkItemCompletionCondition({
    required this.id,
    required this.label,
  });

  factory WorkItemCompletionCondition.fromJson(Map<String, dynamic> json) {
    return WorkItemCompletionCondition(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
  };
}

/// Cấu hình điều kiện hoàn thành công việc
class WorkItemCompletionPolicy {
  final String rule; // 'all' | 'at_least' | 'none'
  final int? minRequired;
  final List<WorkItemCompletionCondition> conditions;

  const WorkItemCompletionPolicy({
    this.rule = 'all',
    this.minRequired,
    this.conditions = const [],
  });

  factory WorkItemCompletionPolicy.fromJson(Map<String, dynamic> json) {
    final rawConds = json['conditions'];
    final condList = <WorkItemCompletionCondition>[];
    if (rawConds is List) {
      for (final c in rawConds) {
        if (c is Map<String, dynamic>) {
          condList.add(WorkItemCompletionCondition.fromJson(c));
        }
      }
    }
    return WorkItemCompletionPolicy(
      rule: json['rule']?.toString() ?? 'all',
      minRequired: json['minRequired'] != null ? CustomerItem.parseInt(json['minRequired']) : null,
      conditions: condList,
    );
  }

  int get requiredCount {
    if (conditions.isEmpty) return 0;
    if (rule == 'all') return conditions.length;
    if (rule == 'at_least') return (minRequired ?? 1).clamp(1, conditions.length);
    return 0; // 'none'
  }

  bool isSatisfied(Set<String> confirmedIds) {
    if (conditions.isEmpty) return true;
    final confirmedCount = conditions.where((c) => confirmedIds.contains(c.id)).length;
    if (rule == 'all') return confirmedCount >= conditions.length;
    if (rule == 'at_least') return confirmedCount >= (minRequired ?? 1);
    return true; // 'none'
  }
}

