// Models cho phân hệ Báo cáo Workspace (Đồng bộ 1:1 với Web React @enterprise-platform/contracts-workspace)

enum ReportPeriodPreset { week, month, quarter, year, custom }

class ReportScope {
  final String level; // 'self' | 'managed' | 'tenant'
  final int projectCount;
  final bool canSeeFinance;

  const ReportScope({
    required this.level,
    required this.projectCount,
    required this.canSeeFinance,
  });

  factory ReportScope.fromJson(Map<String, dynamic> json) {
    return ReportScope(
      level: json['level']?.toString() ?? 'self',
      projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
      canSeeFinance: json['canSeeFinance'] == true,
    );
  }
}

class MyReportBlock {
  final int openItems;
  final int overdueItems;
  final int completedInPeriod;

  const MyReportBlock({
    required this.openItems,
    required this.overdueItems,
    required this.completedInPeriod,
  });

  factory MyReportBlock.fromJson(Map<String, dynamic> json) {
    return MyReportBlock(
      openItems: (json['openItems'] as num?)?.toInt() ?? 0,
      overdueItems: (json['overdueItems'] as num?)?.toInt() ?? 0,
      completedInPeriod: (json['completedInPeriod'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportKpis {
  final int createdItems;
  final int completedItems;
  final int completedOnTime;
  final int completedLate;
  final int openItems;
  final int overdueItems;
  final double completedHours;

  const ReportKpis({
    required this.createdItems,
    required this.completedItems,
    required this.completedOnTime,
    required this.completedLate,
    required this.openItems,
    required this.overdueItems,
    required this.completedHours,
  });

  factory ReportKpis.fromJson(Map<String, dynamic> json) {
    return ReportKpis(
      createdItems: (json['createdItems'] as num?)?.toInt() ?? 0,
      completedItems: (json['completedItems'] as num?)?.toInt() ?? 0,
      completedOnTime: (json['completedOnTime'] as num?)?.toInt() ?? 0,
      completedLate: (json['completedLate'] as num?)?.toInt() ?? 0,
      openItems: (json['openItems'] as num?)?.toInt() ?? 0,
      overdueItems: (json['overdueItems'] as num?)?.toInt() ?? 0,
      completedHours: (json['completedHours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReportPreviousKpis {
  final int createdItems;
  final int completedItems;
  final int completedOnTime;
  final int completedLate;
  final String from;
  final String to;

  const ReportPreviousKpis({
    required this.createdItems,
    required this.completedItems,
    required this.completedOnTime,
    required this.completedLate,
    required this.from,
    required this.to,
  });

  factory ReportPreviousKpis.fromJson(Map<String, dynamic> json) {
    return ReportPreviousKpis(
      createdItems: (json['createdItems'] as num?)?.toInt() ?? 0,
      completedItems: (json['completedItems'] as num?)?.toInt() ?? 0,
      completedOnTime: (json['completedOnTime'] as num?)?.toInt() ?? 0,
      completedLate: (json['completedLate'] as num?)?.toInt() ?? 0,
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
    );
  }
}

class ReportTrendBucket {
  final String start;
  final int created;
  final int completed;
  final int missedDeadline;

  const ReportTrendBucket({
    required this.start,
    required this.created,
    required this.completed,
    required this.missedDeadline,
  });

  factory ReportTrendBucket.fromJson(Map<String, dynamic> json) {
    return ReportTrendBucket(
      start: json['start']?.toString() ?? '',
      created: (json['created'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      missedDeadline: (json['missedDeadline'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportTrend {
  final String granularity; // 'day' | 'week' | 'month'
  final List<ReportTrendBucket> buckets;

  const ReportTrend({
    required this.granularity,
    required this.buckets,
  });

  factory ReportTrend.fromJson(Map<String, dynamic> json) {
    final list = json['buckets'] as List? ?? [];
    return ReportTrend(
      granularity: json['granularity']?.toString() ?? 'day',
      buckets: list.whereType<Map<String, dynamic>>().map(ReportTrendBucket.fromJson).toList(),
    );
  }
}

class ReportCount {
  final String key;
  final int count;

  const ReportCount({
    required this.key,
    required this.count,
  });

  factory ReportCount.fromJson(Map<String, dynamic> json) {
    return ReportCount(
      key: json['key']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PerformanceRow {
  final String userId;
  final int completedItems;
  final int completedOnTime;
  final int completedLate;
  final int averageDaysLate;
  final double completedHours;
  final int openItems;
  final int overdueItems;

  const PerformanceRow({
    required this.userId,
    required this.completedItems,
    required this.completedOnTime,
    required this.completedLate,
    required this.averageDaysLate,
    required this.completedHours,
    required this.openItems,
    required this.overdueItems,
  });

  factory PerformanceRow.fromJson(Map<String, dynamic> json) {
    return PerformanceRow(
      userId: json['userId']?.toString() ?? '',
      completedItems: (json['completedItems'] as num?)?.toInt() ?? 0,
      completedOnTime: (json['completedOnTime'] as num?)?.toInt() ?? 0,
      completedLate: (json['completedLate'] as num?)?.toInt() ?? 0,
      averageDaysLate: (json['averageDaysLate'] as num?)?.toInt() ?? 0,
      completedHours: (json['completedHours'] as num?)?.toDouble() ?? 0.0,
      openItems: (json['openItems'] as num?)?.toInt() ?? 0,
      overdueItems: (json['overdueItems'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportGroupRow {
  final String key;
  final String label;
  final String? color;
  final int projectCount;
  final int totalItems;
  final int closedItems;
  final int openItems;
  final int overdueItems;
  final int completedInPeriod;
  final int progressPercent;

  const ReportGroupRow({
    required this.key,
    required this.label,
    this.color,
    required this.projectCount,
    required this.totalItems,
    required this.closedItems,
    required this.openItems,
    required this.overdueItems,
    required this.completedInPeriod,
    required this.progressPercent,
  });

  factory ReportGroupRow.fromJson(Map<String, dynamic> json) {
    return ReportGroupRow(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString(),
      projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      closedItems: (json['closedItems'] as num?)?.toInt() ?? 0,
      openItems: (json['openItems'] as num?)?.toInt() ?? 0,
      overdueItems: (json['overdueItems'] as num?)?.toInt() ?? 0,
      completedInPeriod: (json['completedInPeriod'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProjectProgressRow {
  final String projectId;
  final String projectCode;
  final String projectName;
  final String status;
  final int progressPercent;
  final int totalItems;
  final int closedItems;
  final int overdueItems;
  final String? startDate;
  final String? endDate;

  const ProjectProgressRow({
    required this.projectId,
    required this.projectCode,
    required this.projectName,
    required this.status,
    required this.progressPercent,
    required this.totalItems,
    required this.closedItems,
    required this.overdueItems,
    this.startDate,
    this.endDate,
  });

  factory ProjectProgressRow.fromJson(Map<String, dynamic> json) {
    return ProjectProgressRow(
      projectId: json['projectId']?.toString() ?? '',
      projectCode: json['projectCode']?.toString() ?? '',
      projectName: json['projectName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      closedItems: (json['closedItems'] as num?)?.toInt() ?? 0,
      overdueItems: (json['overdueItems'] as num?)?.toInt() ?? 0,
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
    );
  }
}

class WorkloadRow {
  final String userId;
  final int openItems;
  final int overdueItems;
  final int dueThisWeek;
  final double estimatedHours;

  const WorkloadRow({
    required this.userId,
    required this.openItems,
    required this.overdueItems,
    required this.dueThisWeek,
    required this.estimatedHours,
  });

  factory WorkloadRow.fromJson(Map<String, dynamic> json) {
    return WorkloadRow(
      userId: json['userId']?.toString() ?? '',
      openItems: (json['openItems'] as num?)?.toInt() ?? 0,
      overdueItems: (json['overdueItems'] as num?)?.toInt() ?? 0,
      dueThisWeek: (json['dueThisWeek'] as num?)?.toInt() ?? 0,
      estimatedHours: (json['estimatedHours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OverdueRow {
  final String workItemId;
  final String code;
  final String title;
  final String projectCode;
  final String projectName;
  final String? assigneeUserId;
  final String plannedEnd;
  final int daysLate;
  final String status;

  const OverdueRow({
    required this.workItemId,
    required this.code,
    required this.title,
    required this.projectCode,
    required this.projectName,
    this.assigneeUserId,
    required this.plannedEnd,
    required this.daysLate,
    required this.status,
  });

  factory OverdueRow.fromJson(Map<String, dynamic> json) {
    return OverdueRow(
      workItemId: json['workItemId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      projectCode: json['projectCode']?.toString() ?? '',
      projectName: json['projectName']?.toString() ?? '',
      assigneeUserId: json['assigneeUserId']?.toString(),
      plannedEnd: json['plannedEnd']?.toString() ?? '',
      daysLate: (json['daysLate'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'todo',
    );
  }
}

class FinanceSummaryBlock {
  final int projectCount;
  final double contractValue;
  final double budget;
  final double actualCost;
  final double forecastCost;
  final double profit;
  final double? profitMargin;

  const FinanceSummaryBlock({
    required this.projectCount,
    required this.contractValue,
    required this.budget,
    required this.actualCost,
    required this.forecastCost,
    required this.profit,
    this.profitMargin,
  });

  factory FinanceSummaryBlock.fromJson(Map<String, dynamic> json) {
    return FinanceSummaryBlock(
      projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
      contractValue: (json['contractValue'] as num?)?.toDouble() ?? 0.0,
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      actualCost: (json['actualCost'] as num?)?.toDouble() ?? 0.0,
      forecastCost: (json['forecastCost'] as num?)?.toDouble() ?? 0.0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0.0,
      profitMargin: (json['profitMargin'] as num?)?.toDouble(),
    );
  }
}

class ReportBundle {
  final ReportScope scope;
  final MyReportBlock mine;
  final ReportKpis kpis;
  final ReportPreviousKpis previous;
  final ReportTrend trend;
  final List<ReportCount> statusBreakdown;
  final List<ReportCount> priorityBreakdown;
  final List<PerformanceRow> performance;
  final List<ReportGroupRow> byGroup;
  final List<ReportGroupRow> byTag;
  final String? userId;
  final List<ProjectProgressRow> projectProgress;
  final List<WorkloadRow> workload;
  final List<OverdueRow> overdue;
  final FinanceSummaryBlock? finance;
  final String from;
  final String to;
  final String timezone;
  final String generatedAt;

  const ReportBundle({
    required this.scope,
    required this.mine,
    required this.kpis,
    required this.previous,
    required this.trend,
    required this.statusBreakdown,
    required this.priorityBreakdown,
    required this.performance,
    required this.byGroup,
    required this.byTag,
    this.userId,
    required this.projectProgress,
    required this.workload,
    required this.overdue,
    this.finance,
    required this.from,
    required this.to,
    required this.timezone,
    required this.generatedAt,
  });

  factory ReportBundle.fromJson(Map<String, dynamic> json) {
    return ReportBundle(
      scope: ReportScope.fromJson(json['scope'] as Map<String, dynamic>? ?? {}),
      mine: MyReportBlock.fromJson(json['mine'] as Map<String, dynamic>? ?? {}),
      kpis: ReportKpis.fromJson(json['kpis'] as Map<String, dynamic>? ?? {}),
      previous: ReportPreviousKpis.fromJson(json['previous'] as Map<String, dynamic>? ?? {}),
      trend: ReportTrend.fromJson(json['trend'] as Map<String, dynamic>? ?? {}),
      statusBreakdown: (json['statusBreakdown'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReportCount.fromJson)
          .toList(),
      priorityBreakdown: (json['priorityBreakdown'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReportCount.fromJson)
          .toList(),
      performance: (json['performance'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PerformanceRow.fromJson)
          .toList(),
      byGroup: (json['byGroup'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReportGroupRow.fromJson)
          .toList(),
      byTag: (json['byTag'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReportGroupRow.fromJson)
          .toList(),
      userId: json['userId']?.toString(),
      projectProgress: (json['projectProgress'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ProjectProgressRow.fromJson)
          .toList(),
      workload: (json['workload'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WorkloadRow.fromJson)
          .toList(),
      overdue: (json['overdue'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OverdueRow.fromJson)
          .toList(),
      finance: json['finance'] is Map<String, dynamic> ? FinanceSummaryBlock.fromJson(json['finance']) : null,
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      timezone: json['timezone']?.toString() ?? '',
      generatedAt: json['generatedAt']?.toString() ?? '',
    );
  }
}

class ReportItemRow {
  final String workItemId;
  final String projectId;
  final String projectCode;
  final String code;
  final String title;
  final String? assigneeUserId;
  final String status;
  final String priority;
  final String? plannedEnd;
  final String? actualEnd;

  const ReportItemRow({
    required this.workItemId,
    required this.projectId,
    required this.projectCode,
    required this.code,
    required this.title,
    this.assigneeUserId,
    required this.status,
    required this.priority,
    this.plannedEnd,
    this.actualEnd,
  });

  factory ReportItemRow.fromJson(Map<String, dynamic> json) {
    return ReportItemRow(
      workItemId: json['workItemId']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      projectCode: json['projectCode']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      assigneeUserId: json['assigneeUserId']?.toString(),
      status: json['status']?.toString() ?? 'todo',
      priority: json['priority']?.toString() ?? 'normal',
      plannedEnd: json['plannedEnd']?.toString(),
      actualEnd: json['actualEnd']?.toString(),
    );
  }
}

class ReportItemList {
  final List<ReportItemRow> items;
  final bool truncated;

  const ReportItemList({
    required this.items,
    required this.truncated,
  });

  factory ReportItemList.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? [];
    return ReportItemList(
      items: list.whereType<Map<String, dynamic>>().map(ReportItemRow.fromJson).toList(),
      truncated: json['truncated'] == true,
    );
  }
}

class TagItem {
  final String id;
  final String name;
  final String? color;

  const TagItem({
    required this.id,
    required this.name,
    this.color,
  });

  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
    );
  }
}

class WorkspaceReportDateHelper {
  static String _pad(int val) => val.toString().padLeft(2, '0');
  static String formatKey(DateTime date) => '${date.year}-${_pad(date.month)}-${_pad(date.day)}';

  static ({String from, String to}) getPresetRange(ReportPeriodPreset preset, [DateTime? refDate]) {
    final today = refDate ?? DateTime.now();
    final year = today.year;
    final month = today.month;

    if (preset == ReportPeriodPreset.week) {
      // Thứ Hai làm ngày đầu tuần (weekday: Monday = 1, Sunday = 7)
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      return (from: formatKey(monday), to: formatKey(sunday));
    }
    if (preset == ReportPeriodPreset.month) {
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);
      return (from: formatKey(firstDay), to: formatKey(lastDay));
    }
    if (preset == ReportPeriodPreset.quarter) {
      final firstMonth = month - ((month - 1) % 3);
      final firstDay = DateTime(year, firstMonth, 1);
      final lastDay = DateTime(year, firstMonth + 3, 0);
      return (from: formatKey(firstDay), to: formatKey(lastDay));
    }
    // Năm nay
    return (from: '$year-01-01', to: '$year-12-31');
  }
}
