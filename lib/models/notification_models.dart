import 'package:flutter/material.dart';

enum NotificationPriority {
  required,
  actionable,
  informational;

  static NotificationPriority fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'required':
        return NotificationPriority.required;
      case 'actionable':
        return NotificationPriority.actionable;
      case 'informational':
      default:
        return NotificationPriority.informational;
    }
  }

  String get label {
    switch (this) {
      case NotificationPriority.required:
        return 'Bắt buộc';
      case NotificationPriority.actionable:
        return 'Cần xử lý';
      case NotificationPriority.informational:
        return 'Thông tin';
    }
  }

  Color get badgeColor {
    switch (this) {
      case NotificationPriority.required:
        return const Color(0xFFEF4444);
      case NotificationPriority.actionable:
        return const Color(0xFFF59E0B);
      case NotificationPriority.informational:
        return const Color(0xFF3B82F6);
    }
  }

  Color get badgeBg {
    switch (this) {
      case NotificationPriority.required:
        return const Color(0xFFFEE2E2);
      case NotificationPriority.actionable:
        return const Color(0xFFFEF3C7);
      case NotificationPriority.informational:
        return const Color(0xFFEFF6FF);
    }
  }
}

enum NotificationModule {
  identity,
  procedure,
  workspace,
  hrm,
  inventory,
  maintenance;

  static NotificationModule fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'identity':
        return NotificationModule.identity;
      case 'procedure':
        return NotificationModule.procedure;
      case 'workspace':
        return NotificationModule.workspace;
      case 'inventory':
        return NotificationModule.inventory;
      case 'maintenance':
        return NotificationModule.maintenance;
      case 'hrm':
      default:
        return NotificationModule.hrm;
    }
  }

  String get displayName {
    switch (this) {
      case NotificationModule.hrm:
        return 'Nhân sự (HRM)';
      case NotificationModule.procedure:
        return 'Quy trình';
      case NotificationModule.workspace:
        return 'Không gian làm việc';
      case NotificationModule.maintenance:
        return 'Bảo trì & Sự cố';
      case NotificationModule.inventory:
        return 'Kho & Vật tư';
      case NotificationModule.identity:
        return 'Bảo mật & Tài khoản';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationModule.hrm:
        return Icons.people_alt_outlined;
      case NotificationModule.procedure:
        return Icons.account_tree_outlined;
      case NotificationModule.workspace:
        return Icons.dashboard_outlined;
      case NotificationModule.maintenance:
        return Icons.build_circle_outlined;
      case NotificationModule.inventory:
        return Icons.inventory_2_outlined;
      case NotificationModule.identity:
        return Icons.security_outlined;
    }
  }

  Color get color {
    switch (this) {
      case NotificationModule.hrm:
        return const Color(0xFF0284C7);
      case NotificationModule.procedure:
        return const Color(0xFF8B5CF6);
      case NotificationModule.workspace:
        return const Color(0xFF0D9488);
      case NotificationModule.maintenance:
        return const Color(0xFFD97706);
      case NotificationModule.inventory:
        return const Color(0xFF059669);
      case NotificationModule.identity:
        return const Color(0xFFDC2626);
    }
  }
}

class NotificationRecord {
  final String id;
  final NotificationModule module;
  final String category;
  final NotificationPriority priority;
  final String title;
  final String body;
  final String? deepLink;
  final String sourceType;
  final String sourceId;
  final int aggregateCount;
  final String? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sequence;

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  NotificationRecord({
    required this.id,
    required this.module,
    required this.category,
    required this.priority,
    required this.title,
    required this.body,
    this.deepLink,
    required this.sourceType,
    required this.sourceId,
    this.aggregateCount = 1,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
    this.sequence = 0,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: json['id']?.toString() ?? '',
      module: NotificationModule.fromString(json['module']?.toString()),
      category: json['category']?.toString() ?? 'general',
      priority: NotificationPriority.fromString(json['priority']?.toString()),
      title: json['title']?.toString() ?? 'Thông báo mới',
      body: json['body']?.toString() ?? '',
      deepLink: json['deep_link']?.toString() ?? json['deepLink']?.toString(),
      sourceType: json['source_type']?.toString() ?? json['sourceType']?.toString() ?? 'system',
      sourceId: json['source_id']?.toString() ?? json['sourceId']?.toString() ?? '',
      aggregateCount: (json['aggregate_count'] ?? json['aggregateCount'] as num?)?.toInt() ?? 1,
      readAt: json['read_at']?.toString() ?? json['readAt']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
    );
  }

  String get categoryVietnamese {
    switch (category) {
      case 'hrm_approval_required':
      case 'leave_request_submitted':
        return 'Cần duyệt đơn nghỉ phép';
      case 'leave_request_approved':
        return 'Đơn nghỉ phép đã được duyệt';
      case 'leave_request_rejected':
        return 'Đơn nghỉ phép bị từ chối';
      case 'attendance_abnormal':
        return 'Bất thường chấm công';
      case 'payroll_payslip_issued':
        return 'Phiếu lương phát hành';
      case 'procedure_instance_assigned':
        return 'Quy trình được giao';
      case 'procedure_task_deadline':
        return 'Hạn chót công việc';
      case 'maintenance_incident_reported':
        return 'Sự cố thiết bị mới';
      case 'inventory_stock_alert':
        return 'Cảnh báo mức tồn kho';
      case 'session_expiring':
      case 'session_revoked':
        return 'Bảo mật phiên đăng nhập';
      default:
        return 'Thông báo hệ thống';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
  }
}

class NotificationSummary {
  final int unreadCount;
  final int lastSequence;

  NotificationSummary({
    this.unreadCount = 0,
    this.lastSequence = 0,
  });

  factory NotificationSummary.fromJson(Map<String, dynamic> json) {
    return NotificationSummary(
      unreadCount: (json['unread_count'] ?? json['unreadCount'] as num?)?.toInt() ?? 0,
      lastSequence: (json['last_sequence'] ?? json['lastSequence'] as num?)?.toInt() ?? 0,
    );
  }
}

class NotificationPreference {
  final NotificationModule module;
  final String category;
  final NotificationPriority priority;
  final bool feedEnabled;
  final bool toastEnabled;

  NotificationPreference({
    required this.module,
    required this.category,
    required this.priority,
    this.feedEnabled = true,
    this.toastEnabled = true,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      module: NotificationModule.fromString(json['module']?.toString()),
      category: json['category']?.toString() ?? '',
      priority: NotificationPriority.fromString(json['priority']?.toString()),
      feedEnabled: json['feed_enabled'] ?? json['feedEnabled'] ?? true,
      toastEnabled: json['toast_enabled'] ?? json['toastEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'module': module.name,
      'category': category,
      'priority': priority.name,
      'feed_enabled': feedEnabled,
      'toast_enabled': toastEnabled,
    };
  }
}
