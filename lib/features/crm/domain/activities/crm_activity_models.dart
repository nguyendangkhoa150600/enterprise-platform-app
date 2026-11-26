import '../../../../core/i18n/app_i18n.dart';
import '../common/crm_json.dart';

/// Loại hoạt động (contracts `ACTIVITY_TYPES`).
const List<String> kCrmActivityTypes = ['CALL', 'EMAIL', 'MEETING', 'TASK'];

/// Trạng thái hoạt động (contracts `ACTIVITY_STATUSES`).
const List<String> kCrmActivityStatuses = ['OPEN', 'DONE', 'CANCELLED'];

/// Nhãn loại (web `ACTIVITY_TYPE_LABELS`).
String crmActivityTypeLabel(String type) => 'crm.activities.type.${type.toLowerCase()}'.tr();

/// Nhãn trạng thái (web `ACTIVITY_STATUS_LABELS`).
String crmActivityStatusLabel(String status) => 'crm.activities.status.${status.toLowerCase()}'.tr();

/// Bảng nhãn loại theo thứ tự (cho ô chọn).
Map<String, String> crmActivityTypeLabels() => {for (final t in kCrmActivityTypes) t: crmActivityTypeLabel(t)};

/// Bảng nhãn trạng thái theo thứ tự (cho ô chọn).
Map<String, String> crmActivityStatusLabels() =>
    {for (final s in kCrmActivityStatuses) s: crmActivityStatusLabel(s)};

/// Hoạt động gắn khách hàng hoặc dự án bán hàng (contracts `Activity`).
class CrmActivity {
  final String id;
  final String type;
  final String subject;
  final String? description;
  final String? customerId;
  final String? customerName;
  final String? opportunityId;
  final String? opportunityName;
  final String assigneeUserId;

  /// Hạn (ISO).
  final String? dueAt;
  final String status;
  final String? result;
  final String? completedAt;
  final String? completedBy;
  final int version;
  final String createdAt;
  final String? createdBy;

  const CrmActivity({
    required this.id,
    required this.type,
    required this.subject,
    this.description,
    this.customerId,
    this.customerName,
    this.opportunityId,
    this.opportunityName,
    required this.assigneeUserId,
    this.dueAt,
    required this.status,
    this.result,
    this.completedAt,
    this.completedBy,
    required this.version,
    required this.createdAt,
    this.createdBy,
  });

  factory CrmActivity.fromJson(Map<String, dynamic> json) => CrmActivity(
        id: CrmJson.str(json['id']),
        type: CrmJson.str(json['type'], 'CALL'),
        subject: CrmJson.str(json['subject']),
        description: CrmJson.strOrNull(json['description']),
        customerId: CrmJson.strOrNull(json['customerId']),
        customerName: CrmJson.strOrNull(json['customerName']),
        opportunityId: CrmJson.strOrNull(json['opportunityId']),
        opportunityName: CrmJson.strOrNull(json['opportunityName']),
        assigneeUserId: CrmJson.str(json['assigneeUserId']),
        dueAt: CrmJson.strOrNull(json['dueAt']),
        status: CrmJson.str(json['status'], 'OPEN'),
        result: CrmJson.strOrNull(json['result']),
        completedAt: CrmJson.strOrNull(json['completedAt']),
        completedBy: CrmJson.strOrNull(json['completedBy']),
        version: CrmJson.integer(json['version']),
        createdAt: CrmJson.str(json['createdAt']),
        createdBy: CrmJson.strOrNull(json['createdBy']),
      );

  /// Web `isOverdue`: đang mở và đã qua hạn.
  bool isOverdue([DateTime? now]) {
    if (status != 'OPEN' || dueAt == null || dueAt!.isEmpty) return false;
    final due = DateTime.tryParse(dueAt!);
    return due != null && due.isBefore(now ?? DateTime.now());
  }

  /// Cột "Khách hàng / dự án bán hàng" của trang Hoạt động.
  String get targetText =>
      [customerName, opportunityName].where((e) => e != null && e.isNotEmpty).join(' · ');
}

/// Phạm vi danh sách (web `ActivityScope`): theo khách, theo dự án bán hàng, hoặc việc giao cho một người.
class CrmActivityScope {
  final String? customerId;
  final String? opportunityId;
  final String? assigneeUserId;
  const CrmActivityScope({this.customerId, this.opportunityId, this.assigneeUserId});

  bool get hasTarget =>
      (customerId != null && customerId!.isNotEmpty) || (opportunityId != null && opportunityId!.isNotEmpty);

  String get key => '$customerId|$opportunityId|$assigneeUserId';
}

/// `GET /activities` (contracts `ActivityListQuery`).
class CrmActivityListQuery {
  final CrmActivityScope scope;
  final String? status;
  final int page;
  final int limit;
  const CrmActivityListQuery({required this.scope, this.status, required this.page, required this.limit});

  Map<String, dynamic> toQuery() => {
        'customerId': scope.customerId,
        'opportunityId': scope.opportunityId,
        'assigneeUserId': scope.assigneeUserId,
        'status': status,
        'page': page,
        'limit': limit,
      };
}
