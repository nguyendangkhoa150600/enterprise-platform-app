import '../common/crm_json.dart';

/// Việc cần xử lý trong CRM (contracts `tasks.ts`, `GET /my-tasks`) và phần logic thuần của web `tasks.model.ts`.

/// Loại việc (contracts `CRM_TASK_KINDS`).
const List<String> kCrmTaskKinds = [
  'QUOTE_APPROVAL',
  'BUSINESS_PLAN_APPROVAL',
  'QUOTE_REJECTED',
  'QUOTE_READY_TO_SEND',
  'BUSINESS_PLAN_REJECTED',
  'QUOTE_PENDING',
  'BUSINESS_PLAN_PENDING',
];

/// Đích duyệt (contracts `CrmTaskApprovalTarget`).
class CrmTaskApprovalTarget {
  /// `QUOTE` | `BUSINESS_PLAN`.
  final String subject;

  /// `DIRECT` | `PROCEDURE`.
  final String mode;
  final String? procedureInstanceId;
  final String? procedureInstanceCode;
  const CrmTaskApprovalTarget({
    required this.subject,
    required this.mode,
    this.procedureInstanceId,
    this.procedureInstanceCode,
  });

  static CrmTaskApprovalTarget? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = CrmJson.map(raw);
    return CrmTaskApprovalTarget(
      subject: CrmJson.str(json['subject'], 'QUOTE'),
      mode: CrmJson.str(json['mode'], 'DIRECT'),
      procedureInstanceId: CrmJson.strOrNull(json['procedureInstanceId']),
      procedureInstanceCode: CrmJson.strOrNull(json['procedureInstanceCode']),
    );
  }

  /// Web `procedureHrefOf` có giá trị: duyệt qua Quy trình và hồ sơ đã tạo.
  String? get procedureId =>
      (mode == 'PROCEDURE' && procedureInstanceId != null && procedureInstanceId!.isNotEmpty)
          ? procedureInstanceId
          : null;
}

class CrmTask {
  final String kind;
  final String quoteId;
  final String quoteCode;
  final String? quoteName;
  final int versionNo;
  final String? customerId;
  final String? customerName;
  final String ownerUserId;
  final String? ownerName;
  final String? actorUserId;
  final String? actorName;
  final String? at;
  final double totalAmount;
  final double? marginPercent;
  final List<String> reasons;
  final CrmTaskApprovalTarget? approval;
  final String? waitingOn;

  const CrmTask({
    required this.kind,
    required this.quoteId,
    required this.quoteCode,
    this.quoteName,
    required this.versionNo,
    this.customerId,
    this.customerName,
    required this.ownerUserId,
    this.ownerName,
    this.actorUserId,
    this.actorName,
    this.at,
    required this.totalAmount,
    this.marginPercent,
    this.reasons = const [],
    this.approval,
    this.waitingOn,
  });

  factory CrmTask.fromJson(Map<String, dynamic> json) => CrmTask(
        kind: CrmJson.str(json['kind']),
        quoteId: CrmJson.str(json['quoteId']),
        quoteCode: CrmJson.str(json['quoteCode']),
        quoteName: CrmJson.strOrNull(json['quoteName']),
        versionNo: CrmJson.integer(json['versionNo'], 1),
        customerId: CrmJson.strOrNull(json['customerId']),
        customerName: CrmJson.strOrNull(json['customerName']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        ownerName: CrmJson.strOrNull(json['ownerName']),
        actorUserId: CrmJson.strOrNull(json['actorUserId']),
        actorName: CrmJson.strOrNull(json['actorName']),
        at: CrmJson.strOrNull(json['at']),
        totalAmount: CrmJson.number(json['totalAmount']),
        marginPercent: CrmJson.numOrNull(json['marginPercent']),
        reasons: CrmJson.strings(json['reasons']),
        approval: CrmTaskApprovalTarget.fromJson(json['approval']),
        waitingOn: CrmJson.strOrNull(json['waitingOn']),
      );

  String get rowKey => '$kind:$quoteId:$versionNo';

  /// Web `isBusinessPlanTask`.
  bool get isBusinessPlan =>
      kind == 'BUSINESS_PLAN_APPROVAL' || kind == 'BUSINESS_PLAN_REJECTED' || kind == 'BUSINESS_PLAN_PENDING';

  /// Web `isWaitingTask`: chỉ theo dõi, luôn mở báo giá trong CRM.
  bool get isWaiting => kind == 'QUOTE_PENDING' || kind == 'BUSINESS_PLAN_PENDING';

  /// Hồ sơ Quy trình cần mở (web `taskTarget` kind `procedure`); null → mở báo giá.
  String? get procedureTarget => isWaiting ? null : approval?.procedureId;

  /// Web `taskQuoteLabel`: "BG2600001 - Báo giá bơm (v2)".
  String get quoteLabel =>
      '$quoteCode${(quoteName != null && quoteName!.isNotEmpty) ? ' - $quoteName' : ''} (v$versionNo)';
}

class CrmTaskList {
  final List<CrmTask> awaitingMe;
  final List<CrmTask> mine;
  final List<CrmTask> waiting;
  const CrmTaskList({required this.awaitingMe, required this.mine, required this.waiting});

  factory CrmTaskList.fromJson(Map<String, dynamic> json) => CrmTaskList(
        awaitingMe: CrmJson.list(json['awaitingMe'], CrmTask.fromJson),
        mine: CrmJson.list(json['mine'], CrmTask.fromJson),
        waiting: CrmJson.list(json['waiting'], CrmTask.fromJson),
      );
}

/// Web `hasMargin`.
bool crmTasksHaveMargin(List<CrmTask> tasks) => tasks.any((t) => t.marginPercent != null);
