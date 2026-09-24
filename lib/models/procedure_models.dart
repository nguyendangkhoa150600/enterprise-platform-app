class ProcedureInstance {
  final String id;
  final String code;
  final String title;
  final String category;
  final String stage; // 'DRAFT' | 'IN_REVIEW' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED'
  final String priority; // 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT'
  final String? assigneeName;
  final String? slaStatus; // 'ON_TIME' | 'AT_RISK' | 'BREACHED'
  final String createdAt;
  final int subtasksCount;
  final int completedSubtasksCount;

  ProcedureInstance({
    required this.id,
    required this.code,
    required this.title,
    required this.category,
    required this.stage,
    required this.priority,
    this.assigneeName,
    this.slaStatus,
    required this.createdAt,
    this.subtasksCount = 0,
    this.completedSubtasksCount = 0,
  });

  factory ProcedureInstance.fromJson(Map<String, dynamic> json) {
    return ProcedureInstance(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['id']?.toString() ?? 'PRC-001',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Quy trình vận hành',
      category: json['category']?.toString() ?? 'Vận hành',
      stage: json['stage']?.toString() ?? json['status']?.toString() ?? 'IN_PROGRESS',
      priority: json['priority']?.toString() ?? 'MEDIUM',
      assigneeName: json['assigneeName']?.toString() ?? json['actorName']?.toString(),
      slaStatus: json['slaStatus']?.toString() ?? 'ON_TIME',
      createdAt: json['createdAt']?.toString() ?? '',
      subtasksCount: (json['subtasksCount'] as num?)?.toInt() ?? 0,
      completedSubtasksCount: (json['completedSubtasksCount'] as num?)?.toInt() ?? 0,
    );
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
