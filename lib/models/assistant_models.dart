import 'package:flutter/widgets.dart';
import 'package:power_quality_analysis/core/i18n/app_i18n.dart';
/// Vai trò người gửi trong khung chat
enum MessageSender {
  user,
  assistant,
  system,
}

/// Trạng thái của thẻ Form nhúng trong tin nhắn chat
enum ActionDraftStatus {
  draft,       // Đang xem / chỉnh sửa bản nháp
  submitting,  // Đang gửi lên API
  submitted,   // Đã gửi thành công
  cancelled,   // Đã huỷ thao tác
  error,       // Lỗi khi gửi
}

/// Định nghĩa bản nháp thao tác Trợ lý (Action Draft)
/// Đồng bộ 1:1 với packages/contracts/assistant (HRM, Workspace, Maintenance, Procedure)
class AssistantActionDraft {
  final String requestId;
  final String key; // vd: hrm.leave-request.create, workspace.standalone-task.create
  final String title;
  final String module;
  Map<String, dynamic> fields;
  ActionDraftStatus status;
  String? resultId;
  String? resultLabel;
  String? errorMessage;

  AssistantActionDraft({
    required this.requestId,
    required this.key,
    required this.title,
    required this.module,
    required this.fields,
    this.status = ActionDraftStatus.draft,
    this.resultId,
    this.resultLabel,
    this.errorMessage,
  });

  factory AssistantActionDraft.fromJson(Map<String, dynamic> json) {
    return AssistantActionDraft(
      requestId: json['requestId']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      module: json['module']?.toString() ?? '',
      fields: json['fields'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['fields'])
          : {},
      status: _parseStatus(json['status']),
      resultId: json['resultId']?.toString(),
      resultLabel: json['resultLabel']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
    );
  }

  static ActionDraftStatus _parseStatus(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'submitting':
        return ActionDraftStatus.submitting;
      case 'submitted':
        return ActionDraftStatus.submitted;
      case 'cancelled':
        return ActionDraftStatus.cancelled;
      case 'error':
        return ActionDraftStatus.error;
      default:
        return ActionDraftStatus.draft;
    }
  }

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'key': key,
    'title': title,
    'module': module,
    'fields': fields,
    'status': status.name,
    if (resultId != null) 'resultId': resultId,
    if (resultLabel != null) 'resultLabel': resultLabel,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };
}

/// Một tin nhắn trong luồng trò chuyện với Trợ lý Savina AI
class AssistantMessage {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final AssistantActionDraft? actionDraft;
  final List<String> mentions; // Danh sách userId được @mention

  AssistantMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.actionDraft,
    this.mentions = const [],
  });

  AssistantMessage copyWith({
    String? id,
    MessageSender? sender,
    String? text,
    DateTime? timestamp,
    AssistantActionDraft? actionDraft,
    List<String>? mentions,
  }) {
    return AssistantMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      actionDraft: actionDraft ?? this.actionDraft,
      mentions: mentions ?? this.mentions,
    );
  }
}

/// Nhân sự dùng để gợi ý khi gõ @mention
class MentionUser {
  final String userId;
  final String displayName;
  final String? email;
  final String? roleName;
  final String? departmentName;
  final String? avatarUrl;

  const MentionUser({
    required this.userId,
    required this.displayName,
    this.email,
    this.roleName,
    this.departmentName,
    this.avatarUrl,
  });

  factory MentionUser.fromJson(Map<String, dynamic> json) {
    return MentionUser(
      userId: json['userId']?.toString() ?? json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['fullName']?.toString() ?? json['name']?.toString() ?? 'assistant.model.default_employee'.tr(),
      email: json['email']?.toString(),
      roleName: json['role']?.toString() ?? json['roleName']?.toString(),
      departmentName: json['unitNames'] != null && json['unitNames'] is List && (json['unitNames'] as List).isNotEmpty
          ? (json['unitNames'] as List).first.toString()
          : json['department']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

/// Thao tác Trợ lý lấy từ danh mục `GET /api/<phân hệ>/v1/assistant/actions`
/// Chuẩn contracts-assistant của Savina ERP
class AssistantCatalogItem {
  final String key;
  final String module;
  final String title;
  final List<String> hints;
  final String page;
  final String form;
  final Map<String, dynamic> draft;

  const AssistantCatalogItem({
    required this.key,
    required this.module,
    required this.title,
    required this.hints,
    required this.page,
    required this.form,
    required this.draft,
  });

  factory AssistantCatalogItem.fromJson(Map<String, dynamic> json) {
    return AssistantCatalogItem(
      key: json['key']?.toString() ?? '',
      module: json['module']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      hints: (json['hints'] is List)
          ? (json['hints'] as List).map((e) => e.toString()).toList()
          : [],
      page: json['page']?.toString() ?? '',
      form: json['form']?.toString() ?? '',
      draft: (json['draft'] is Map) ? Map<String, dynamic>.from(json['draft']) : {},
    );
  }
}

/// Phím tắt "Xem nhanh" và "Tạo nhanh" theo chuẩn Savina ERP
class QuickShortcutItem {
  final String key;
  final String label;
  final IconData icon;
  final String group; // 'view' hoặc 'create'
  final String prompt;
  final int? count;

  const QuickShortcutItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.group,
    required this.prompt,
    this.count,
  });

  QuickShortcutItem copyWith({int? count}) {
    return QuickShortcutItem(
      key: key,
      label: label,
      icon: icon,
      group: group,
      prompt: prompt,
      count: count ?? this.count,
    );
  }
}


