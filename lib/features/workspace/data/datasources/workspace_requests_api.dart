import 'workspace_api_base.dart';

/// Thứ tự trạng thái đơn từ (như `PROJECT_REQUEST_STATUSES`), dùng cho lọc và sắp xếp.
const List<String> projectRequestStatuses = ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'REVERSED'];

class ProjectRequestDetail {
  final String label;
  final String value;
  const ProjectRequestDetail(this.label, this.value);
}

class ProjectRequestReversal {
  final String requestedAt;
  final String? requestedByName;
  final String reason;

  /// Module nguồn từ chối huỷ (vd vừa chốt kỳ lương).
  final String? error;

  const ProjectRequestReversal({
    required this.requestedAt,
    required this.requestedByName,
    required this.reason,
    required this.error,
  });
}

/// Đơn từ gắn dự án (khớp `ProjectRequest` ở contracts-workspace).
class ProjectRequestItem {
  final String id;
  final String code;
  final String sourceModule;
  final String sourceKind;
  final String requestTypeLabel;
  final String requesterUserId;
  final String? requesterName;
  final String? fromDate;
  final String? toDate;
  final String status;
  final String? procedureInstanceId;
  final String? procedureInstanceCode;
  final String? launchUrl;
  final String submittedAt;
  final String? statusChangedAt;
  final String? linkedViaKind;
  final String? linkedViaCode;
  final String? statusNote;
  final ProjectRequestReversal? reversalRequest;
  final List<ProjectRequestDetail> details;

  const ProjectRequestItem({
    required this.id,
    required this.code,
    required this.sourceModule,
    required this.sourceKind,
    required this.requestTypeLabel,
    required this.requesterUserId,
    required this.requesterName,
    required this.fromDate,
    required this.toDate,
    required this.status,
    required this.procedureInstanceId,
    required this.procedureInstanceCode,
    required this.launchUrl,
    required this.submittedAt,
    required this.statusChangedAt,
    required this.linkedViaKind,
    required this.linkedViaCode,
    required this.statusNote,
    required this.reversalRequest,
    required this.details,
  });

  factory ProjectRequestItem.fromJson(Map<String, dynamic> json) {
    final reversal = json['reversalRequest'];
    final details = json['details'] is List
        ? (json['details'] as List)
            .whereType<Map>()
            .map((e) => ProjectRequestDetail(e['label']?.toString() ?? '', e['value']?.toString() ?? ''))
            .toList()
        : const <ProjectRequestDetail>[];
    return ProjectRequestItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      sourceModule: json['sourceModule']?.toString() ?? '',
      sourceKind: json['sourceKind']?.toString() ?? '',
      requestTypeLabel: json['requestTypeLabel']?.toString() ?? '',
      requesterUserId: json['requesterUserId']?.toString() ?? '',
      requesterName: _text(json['requesterName']),
      fromDate: _text(json['fromDate']),
      toDate: _text(json['toDate']),
      status: json['status']?.toString() ?? 'PENDING',
      procedureInstanceId: _text(json['procedureInstanceId']),
      procedureInstanceCode: _text(json['procedureInstanceCode']),
      launchUrl: _text(json['launchUrl']),
      submittedAt: json['submittedAt']?.toString() ?? '',
      statusChangedAt: _text(json['statusChangedAt']),
      linkedViaKind: _text(json['linkedViaKind']),
      linkedViaCode: _text(json['linkedViaCode']),
      statusNote: _text(json['statusNote']),
      reversalRequest: reversal is Map
          ? ProjectRequestReversal(
              requestedAt: reversal['requestedAt']?.toString() ?? '',
              requestedByName: _text(reversal['requestedByName']),
              reason: reversal['reason']?.toString() ?? '',
              error: _text(reversal['error']),
            )
          : null,
      details: details,
    );
  }
}

/// Một loại ngày trong bảng ưu tiên tính công (`WorkdayRule`).
class WorkdayRule {
  final String kind;
  final String label;
  final int rank;
  final double units;
  const WorkdayRule({required this.kind, required this.label, required this.rank, required this.units});
}

/// Bảng ưu tiên tính công (`WorkdayRuleSet`), cao nhất trước.
class WorkdayRuleSet {
  final List<WorkdayRule> rules;
  final double normalUnits;
  final bool canEdit;
  const WorkdayRuleSet({required this.rules, required this.normalUnits, required this.canEdit});

  /// Cấu hình mặc định khi chưa đọc được từ server (`DEFAULT_WORKDAY_RULES`, nhãn do màn hình dịch).
  static const defaults = WorkdayRuleSet(
    rules: [
      WorkdayRule(kind: 'leave', label: '', rank: 1, units: 0),
      WorkdayRule(kind: 'business_trip', label: '', rank: 2, units: 1.5),
    ],
    normalUnits: 1,
    canEdit: false,
  );

  factory WorkdayRuleSet.fromJson(dynamic raw) {
    final map = raw is Map ? raw : const {};
    final rules = map['rules'] is List
        ? (map['rules'] as List).whereType<Map>().map((e) => WorkdayRule(
              kind: e['kind']?.toString() ?? '',
              label: e['label']?.toString() ?? '',
              rank: (e['rank'] as num?)?.toInt() ?? 0,
              units: (e['units'] as num?)?.toDouble() ?? 0,
            )).toList()
        : <WorkdayRule>[];
    return WorkdayRuleSet(
      rules: rules,
      normalUnits: (map['normalUnits'] as num?)?.toDouble() ?? 1,
      canEdit: map['canEdit'] == true,
    );
  }
}

/// Đơn từ của dự án: danh sách, huỷ hiệu lực, bảng ưu tiên tính công.
class WorkspaceRequestsApi extends WorkspaceApiBase {
  /// `GET /projects/{id}/requests`.
  Future<WorkspaceApiResult<List<ProjectRequestItem>>> listProjectRequests(String projectId) {
    return send(
      'GET',
      '${WorkspaceApiBase.root}/projects/$projectId/requests',
      parse: (data) => WorkspaceApiBase.itemsOf(data).map(ProjectRequestItem.fromJson).toList(),
    );
  }

  /// `POST /project-requests/{id}/reverse` — gửi yêu cầu huỷ hiệu lực sang module nguồn.
  Future<WorkspaceApiResult<void>> reverseProjectRequest(
    String requestId, {
    required String reason,
    required bool createAdjustment,
  }) {
    return send<void>(
      'POST',
      '${WorkspaceApiBase.root}/project-requests/$requestId/reverse',
      body: {'reason': reason, 'createAdjustment': createAdjustment},
      parse: (_) {},
    );
  }

  /// `GET /workday-rules`.
  Future<WorkspaceApiResult<WorkdayRuleSet>> workdayRules() =>
      send('GET', '${WorkspaceApiBase.root}/workday-rules', parse: WorkdayRuleSet.fromJson);

  /// `PUT /workday-rules` — chỉ quản trị.
  Future<WorkspaceApiResult<WorkdayRuleSet>> updateWorkdayRules({
    required List<String> order,
    required Map<String, double> units,
    required double normalUnits,
  }) =>
      send(
        'PUT',
        '${WorkspaceApiBase.root}/workday-rules',
        body: {'order': order, 'units': units, 'normalUnits': normalUnits},
        parse: WorkdayRuleSet.fromJson,
      );
}

String? _text(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}
