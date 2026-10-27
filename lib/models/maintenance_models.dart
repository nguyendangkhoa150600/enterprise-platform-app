import '../core/i18n/app_i18n.dart';
class MaintenanceSchedule {
  final String id;
  final String assetCode;
  final String assetName;
  final String frequency; // 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'QUARTERLY' | 'YEARLY'
  final String nextDueDate;
  final String status; // 'SCHEDULED' | 'DUE' | 'OVERDUE' | 'COMPLETED'
  final String priority; // 'LOW' | 'MEDIUM' | 'HIGH'

  MaintenanceSchedule({
    required this.id,
    required this.assetCode,
    required this.assetName,
    required this.frequency,
    required this.nextDueDate,
    required this.status,
    required this.priority,
  });

  factory MaintenanceSchedule.fromJson(Map<String, dynamic> json) {
    return MaintenanceSchedule(
      id: json['id']?.toString() ?? '',
      assetCode: json['assetCode']?.toString() ?? 'AST-01',
      assetName: json['assetName']?.toString() ?? 'models.maintenance.default_asset'.tr(),
      frequency: json['frequency']?.toString() ?? 'MONTHLY',
      nextDueDate: json['nextDueDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SCHEDULED',
      priority: json['priority']?.toString() ?? 'MEDIUM',
    );
  }
}

class MaintenanceIncident {
  final String id;
  final String assetCode;
  final String assetName;
  final String title;
  final String severity; // 'LOW' | 'MEDIUM' | 'CRITICAL'
  final String reportedAt;
  final String status; // 'OPEN' | 'IN_PROGRESS' | 'RESOLVED'
  final String? reportedBy;

  MaintenanceIncident({
    required this.id,
    required this.assetCode,
    required this.assetName,
    required this.title,
    required this.severity,
    required this.reportedAt,
    required this.status,
    this.reportedBy,
  });

  factory MaintenanceIncident.fromJson(Map<String, dynamic> json) {
    return MaintenanceIncident(
      id: json['id']?.toString() ?? '',
      assetCode: json['assetCode']?.toString() ?? '',
      assetName: json['assetName']?.toString() ?? 'models.maintenance.default_system'.tr(),
      title: json['title']?.toString() ?? 'models.maintenance.default_incident'.tr(),
      severity: json['severity']?.toString() ?? 'MEDIUM',
      reportedAt: json['reportedAt']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      reportedBy: json['reportedBy']?.toString() ?? 'models.maintenance.technician'.tr(),
    );
  }
}
