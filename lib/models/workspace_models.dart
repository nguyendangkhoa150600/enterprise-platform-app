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
      name: json['name']?.toString() ?? 'Khách hàng chưa đặt tên',
      note: json['note']?.toString(),
      contractCount: _parseInt(json['contractCount']),
      projectCount: _parseInt(json['projectCount']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }
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
      name: json['name']?.toString() ?? 'Hợp đồng chưa đặt tên',
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
        return 'Đang thực hiện';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã huỷ';
      case 'draft':
      default:
        return 'Bản nháp';
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
  });

  factory ProjectItem.fromJson(Map<String, dynamic> json, [Map<String, String>? customerMap]) {
    final cid = json['customerId']?.toString();
    return ProjectItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Dự án chưa đặt tên',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'active',
      projectType: json['projectType']?.toString(),
      customerId: cid,
      customerName: cid != null && customerMap != null ? customerMap[cid] : json['customerName']?.toString(),
      progressPercent: json['progressPercent'] != null ? (double.tryParse(json['progressPercent'].toString()) ?? 0.0) : 0.0,
      totalItems: CustomerItem._parseInt(json['totalItems']),
      closedItems: CustomerItem._parseInt(json['closedItems']),
      overdueItems: CustomerItem._parseInt(json['overdueItems']),
      myRole: json['myRole']?.toString(),
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'].toString()) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString()) : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Đang triển khai';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã huỷ';
      case 'draft':
      default:
        return 'Khởi tạo';
    }
  }

  String get typeLabel => projectType != null && projectType!.isNotEmpty ? projectType! : 'Chưa phân loại';
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
      fullName: json['fullName']?.toString() ?? json['name']?.toString() ?? 'Thành viên',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'technician',
    );
  }

  String get roleLabel {
    switch (role) {
      case 'manager':
        return 'Quản lý dự án';
      case 'technician':
        return 'Kỹ thuật viên';
      case 'viewer':
      default:
        return 'Xem / Theo dõi';
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
    final task = json['task'] is Map ? json['task'] as Map<String, dynamic> : json;
    final role = json['myRole']?.toString() ?? task['myRole']?.toString() ?? 'assignee';

    return StandaloneTaskItem(
      id: task['id']?.toString() ?? '',
      code: task['code']?.toString() ?? '',
      title: task['title']?.toString() ?? 'Công việc không tên',
      description: task['description']?.toString(),
      status: task['status']?.toString() ?? 'todo',
      priority: task['priority']?.toString() ?? 'normal',
      assigneeUserId: task['assigneeUserId']?.toString() ?? '',
      assigneeName: task['assigneeName']?.toString() ?? task['assignee']?['name']?.toString(),
      progressPercent: task['progressPercent'] != null ? (double.tryParse(task['progressPercent'].toString()) ?? 0.0) : 0.0,
      dueDate: task['dueDate'] != null ? DateTime.tryParse(task['dueDate'].toString()) : null,
      myRole: role,
      childCount: CustomerItem._parseInt(task['childCount']),
      openChildCount: CustomerItem._parseInt(task['openChildCount']),
      isReversed: task['reversal'] != null,
    );
  }

  String get statusLabel {
    if (isReversed) return 'Đã huỷ hiệu lực';
    switch (status) {
      case 'in_progress':
        return 'Đang làm';
      case 'review':
        return 'Chờ duyệt';
      case 'done':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã huỷ';
      case 'todo':
      default:
        return 'Cần làm';
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
