import '../common/crm_json.dart';
import '../crm_capabilities.dart';

/// Hồ sơ thầu của dự án luồng Chào thầu (contracts `tender.ts`, web `tender/tender.model.ts`): hồ sơ 1-1 với dự án,
/// đối tác liên danh, duyệt phương án chào thầu (nhiều vòng) và kết quả Trúng/Trượt. Tiền VND.

/// Hình thức nộp (contracts `TENDER_SUBMISSION_METHODS`).
const List<String> kCrmTenderSubmissionMethods = ['ONLINE', 'IN_PERSON', 'POST'];

/// Kết quả thầu (contracts `TENDER_RESULTS`).
const List<String> kCrmTenderResults = ['WON', 'LOST'];

class CrmTenderPartner {
  final String id;
  final String name;

  /// Phạm vi đảm nhận của đối tác trong liên danh.
  final String? scope;

  const CrmTenderPartner({required this.id, required this.name, this.scope});

  factory CrmTenderPartner.fromJson(Map<String, dynamic> json) => CrmTenderPartner(
        id: CrmJson.str(json['id']),
        name: CrmJson.str(json['name']),
        scope: CrmJson.strOrNull(json['scope']),
      );
}

/// Một vòng duyệt phương án chào thầu.
class CrmTenderPlanRound {
  final String id;
  final int roundNo;

  /// `DIRECT` hoặc `PROCEDURE`.
  final String via;
  final String submittedAt;
  final String submittedBy;
  final String? decidedAt;
  final String? decidedBy;

  /// `APPROVED`, `REJECTED` hoặc null (chờ duyệt).
  final String? decision;
  final String? reason;
  final String? procedureInstanceCode;

  const CrmTenderPlanRound({
    required this.id,
    required this.roundNo,
    required this.via,
    required this.submittedAt,
    required this.submittedBy,
    this.decidedAt,
    this.decidedBy,
    this.decision,
    this.reason,
    this.procedureInstanceCode,
  });

  factory CrmTenderPlanRound.fromJson(Map<String, dynamic> json) => CrmTenderPlanRound(
        id: CrmJson.str(json['id']),
        roundNo: CrmJson.integer(json['roundNo']),
        via: CrmJson.str(json['via'], 'DIRECT'),
        submittedAt: CrmJson.str(json['submittedAt']),
        submittedBy: CrmJson.str(json['submittedBy']),
        decidedAt: CrmJson.strOrNull(json['decidedAt']),
        decidedBy: CrmJson.strOrNull(json['decidedBy']),
        decision: CrmJson.strOrNull(json['decision']),
        reason: CrmJson.strOrNull(json['reason']),
        procedureInstanceCode: CrmJson.strOrNull(json['procedureInstanceCode']),
      );
}

/// Trạng thái duyệt phương án hiện tại của hồ sơ.
class CrmTenderPlan {
  /// `DRAFT`, `PENDING`, `APPROVED`, `REJECTED`.
  final String status;
  final int roundNo;
  final String? submittedAt;
  final String? submittedBy;
  final String? decidedAt;
  final String? decidedBy;
  final String? decisionReason;
  final String? via;
  final String? procedureInstanceCode;

  const CrmTenderPlan({
    required this.status,
    required this.roundNo,
    this.submittedAt,
    this.submittedBy,
    this.decidedAt,
    this.decidedBy,
    this.decisionReason,
    this.via,
    this.procedureInstanceCode,
  });

  factory CrmTenderPlan.fromJson(Map<String, dynamic> json) => CrmTenderPlan(
        status: CrmJson.str(json['status'], 'DRAFT'),
        roundNo: CrmJson.integer(json['roundNo']),
        submittedAt: CrmJson.strOrNull(json['submittedAt']),
        submittedBy: CrmJson.strOrNull(json['submittedBy']),
        decidedAt: CrmJson.strOrNull(json['decidedAt']),
        decidedBy: CrmJson.strOrNull(json['decidedBy']),
        decisionReason: CrmJson.strOrNull(json['decisionReason']),
        via: CrmJson.strOrNull(json['via']),
        procedureInstanceCode: CrmJson.strOrNull(json['procedureInstanceCode']),
      );
}

/// Gợi ý điền sẵn khi lập hợp đồng từ dự án thầu đã trúng (contracts `TenderContractDraft`).
class CrmTenderContractDraft {
  final String type;
  final String customerId;
  final String title;
  final double value;
  final String validFrom;
  final String ownerUserId;

  const CrmTenderContractDraft({
    required this.type,
    required this.customerId,
    required this.title,
    required this.value,
    required this.validFrom,
    required this.ownerUserId,
  });

  factory CrmTenderContractDraft.fromJson(Map<String, dynamic> json) => CrmTenderContractDraft(
        type: CrmJson.str(json['type'], 'SALE'),
        customerId: CrmJson.str(json['customerId']),
        title: CrmJson.str(json['title']),
        value: CrmJson.number(json['value']),
        validFrom: CrmJson.str(json['validFrom']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
      );
}

class CrmTenderProfile {
  final String id;
  final String opportunityId;
  final String packageName;

  /// Bên mời thầu.
  final String inviterName;
  final String? packageCode;
  final String? submissionDeadline;
  final String? submissionMethod;
  final String? submitterUserId;
  final String? submittedAt;
  final bool hasJointVenture;

  /// Kịch bản chọn: nội dung phương án chào thầu đưa đi duyệt.
  final String? scenario;
  final CrmTenderPlan plan;

  /// `WON`, `LOST` hoặc null.
  final String? result;
  final double? winningPrice;
  final String? winnerName;
  final String? lostReason;
  final String? resultRecordedAt;
  final String? resultRecordedBy;
  final List<CrmTenderPartner> partners;
  final List<CrmTenderPlanRound> rounds;
  final CrmTenderContractDraft? contractDraft;

  /// `false` khi dự án đã đóng (Trúng hoặc Trượt).
  final bool editable;

  /// `true` khi phương án đang chờ duyệt: khoá sửa kịch bản, liên danh, đối tác.
  final bool planLocked;
  final int version;

  const CrmTenderProfile({
    required this.id,
    required this.opportunityId,
    required this.packageName,
    required this.inviterName,
    this.packageCode,
    this.submissionDeadline,
    this.submissionMethod,
    this.submitterUserId,
    this.submittedAt,
    required this.hasJointVenture,
    this.scenario,
    required this.plan,
    this.result,
    this.winningPrice,
    this.winnerName,
    this.lostReason,
    this.resultRecordedAt,
    this.resultRecordedBy,
    required this.partners,
    required this.rounds,
    this.contractDraft,
    required this.editable,
    required this.planLocked,
    required this.version,
  });

  /// Web `asTenderProfile`: server trả 200 thân rỗng khi chưa có hồ sơ; chỉ coi là hồ sơ khi có `id` và `plan`.
  static CrmTenderProfile? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final id = json['id'];
    if (id == null || id.toString().isEmpty || json['plan'] is! Map) return null;
    return CrmTenderProfile.fromJson(json);
  }

  factory CrmTenderProfile.fromJson(Map<String, dynamic> json) {
    final draft = json['contractDraft'];
    return CrmTenderProfile(
      id: CrmJson.str(json['id']),
      opportunityId: CrmJson.str(json['opportunityId']),
      packageName: CrmJson.str(json['packageName']),
      inviterName: CrmJson.str(json['inviterName']),
      packageCode: CrmJson.strOrNull(json['packageCode']),
      submissionDeadline: CrmJson.strOrNull(json['submissionDeadline']),
      submissionMethod: CrmJson.strOrNull(json['submissionMethod']),
      submitterUserId: CrmJson.strOrNull(json['submitterUserId']),
      submittedAt: CrmJson.strOrNull(json['submittedAt']),
      hasJointVenture: CrmJson.boolean(json['hasJointVenture']),
      scenario: CrmJson.strOrNull(json['scenario']),
      plan: CrmTenderPlan.fromJson(CrmJson.map(json['plan'])),
      result: CrmJson.strOrNull(json['result']),
      winningPrice: CrmJson.numOrNull(json['winningPrice']),
      winnerName: CrmJson.strOrNull(json['winnerName']),
      lostReason: CrmJson.strOrNull(json['lostReason']),
      resultRecordedAt: CrmJson.strOrNull(json['resultRecordedAt']),
      resultRecordedBy: CrmJson.strOrNull(json['resultRecordedBy']),
      partners: CrmJson.list(json['partners'], CrmTenderPartner.fromJson),
      rounds: CrmJson.list(json['rounds'], CrmTenderPlanRound.fromJson),
      contractDraft: draft is Map ? CrmTenderContractDraft.fromJson(Map<String, dynamic>.from(draft)) : null,
      editable: CrmJson.boolean(json['editable']),
      planLocked: CrmJson.boolean(json['planLocked']),
      version: CrmJson.integer(json['version']),
    );
  }
}

/// Thao tác hiện được trên hồ sơ thầu (web `TenderUiAction`).
enum CrmTenderAction { edit, submit, approve, reject, result, partners }

/// Bản nháp form hồ sơ thầu. [submissionDeadline] là ISO (UTC) hoặc rỗng.
class CrmTenderDraft {
  final String packageName;
  final String inviterName;
  final String packageCode;
  final String submissionDeadline;
  final String submissionMethod;
  final String submitterUserId;
  final bool hasJointVenture;
  final String scenario;

  const CrmTenderDraft({
    this.packageName = '',
    this.inviterName = '',
    this.packageCode = '',
    this.submissionDeadline = '',
    this.submissionMethod = '',
    this.submitterUserId = '',
    this.hasJointVenture = false,
    this.scenario = '',
  });
}

/// Kết quả dựng yêu cầu: [body] khi hợp lệ, [errorKey] (khoá dịch) khi sai.
class CrmTenderBuild {
  final Map<String, dynamic>? body;
  final String? errorKey;
  const CrmTenderBuild.ok(Map<String, dynamic> this.body) : errorKey = null;
  const CrmTenderBuild.fail(String this.errorKey) : body = null;
  bool get ok => body != null;
}

/// Logic thuần của hồ sơ thầu (web `tender.model.ts`).
class CrmTenderRules {
  CrmTenderRules._();

  /// Luồng có profile `TENDER` mới hiện khối hồ sơ thầu.
  static bool isTenderPipeline(String? profile) => profile == 'TENDER';

  /// Web `tenderActions`.
  static List<CrmTenderAction> actions(CrmTenderProfile profile, CrmCapabilities caps, String? currentUserId) {
    final write = caps.isTenantAdmin || caps.canWriteOpportunity;
    final approve = caps.isTenantAdmin || caps.canApproveQuote;
    final out = <CrmTenderAction>[];
    final status = profile.plan.status;
    if (write && profile.editable) {
      out.add(CrmTenderAction.edit);
      if (!profile.planLocked && profile.hasJointVenture) out.add(CrmTenderAction.partners);
      if (status == 'DRAFT' || status == 'REJECTED') out.add(CrmTenderAction.submit);
      if (profile.result == null) out.add(CrmTenderAction.result);
    }
    final self = currentUserId != null && currentUserId.isNotEmpty && profile.plan.submittedBy == currentUserId;
    if (approve && profile.editable && status == 'PENDING' && !self) {
      out.addAll([CrmTenderAction.approve, CrmTenderAction.reject]);
    }
    return out;
  }

  static CrmTenderDraft draftFromProfile(CrmTenderProfile p) => CrmTenderDraft(
        packageName: p.packageName,
        inviterName: p.inviterName,
        packageCode: p.packageCode ?? '',
        submissionDeadline: p.submissionDeadline ?? '',
        submissionMethod: p.submissionMethod ?? '',
        submitterUserId: p.submitterUserId ?? '',
        hasJointVenture: p.hasJointVenture,
        scenario: p.scenario ?? '',
      );

  /// Cắt đến phút theo giờ máy (web so giá trị ô `datetime-local`).
  static String _minuteKey(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.year}-${d.month}-${d.day}T${d.hour}:${d.minute}';
  }

  static CrmTenderBuild _fields(CrmTenderDraft draft, DateTime now) {
    final packageName = draft.packageName.trim();
    final inviterName = draft.inviterName.trim();
    if (packageName.isEmpty) return const CrmTenderBuild.fail('crm.opportunities.tender.error.package_required');
    if (inviterName.isEmpty) return const CrmTenderBuild.fail('crm.opportunities.tender.error.inviter_required');
    String? deadline;
    if (draft.submissionDeadline.isNotEmpty) {
      final date = DateTime.tryParse(draft.submissionDeadline);
      if (date == null) return const CrmTenderBuild.fail('crm.opportunities.tender.error.deadline_invalid');
      if (date.isBefore(now)) return const CrmTenderBuild.fail('crm.opportunities.tender.error.deadline_past');
      deadline = date.toUtc().toIso8601String();
    }
    final method = kCrmTenderSubmissionMethods.contains(draft.submissionMethod) ? draft.submissionMethod : null;
    final code = draft.packageCode.trim();
    final scenario = draft.scenario.trim();
    return CrmTenderBuild.ok({
      'packageName': packageName,
      'inviterName': inviterName,
      'packageCode': code.isEmpty ? null : code,
      'submissionDeadline': deadline,
      'submissionMethod': method,
      'submitterUserId': draft.submitterUserId.isEmpty ? null : draft.submitterUserId,
      'hasJointVenture': draft.hasJointVenture,
      'scenario': scenario.isEmpty ? null : scenario,
    });
  }

  /// Yêu cầu tạo (`POST .../tender`).
  static CrmTenderBuild buildCreate(CrmTenderDraft draft, [DateTime? now]) => _fields(draft, now ?? DateTime.now());

  /// Yêu cầu sửa (`PUT .../tender`): hạn nộp không đổi thì không kiểm "quá khứ" và không gửi lại.
  static CrmTenderBuild buildUpdate(CrmTenderDraft draft, CrmTenderProfile profile, [DateTime? now]) {
    final unchanged = _minuteKey(draft.submissionDeadline) == _minuteKey(profile.submissionDeadline);
    final built = _fields(
      unchanged
          ? CrmTenderDraft(
              packageName: draft.packageName,
              inviterName: draft.inviterName,
              packageCode: draft.packageCode,
              submissionMethod: draft.submissionMethod,
              submitterUserId: draft.submitterUserId,
              hasJointVenture: draft.hasJointVenture,
              scenario: draft.scenario,
            )
          : draft,
      now ?? DateTime.now(),
    );
    if (!built.ok) return built;
    final body = Map<String, dynamic>.from(built.body!);
    if (unchanged) body.remove('submissionDeadline');
    body['version'] = profile.version;
    return CrmTenderBuild.ok(body);
  }

  /// Giá trúng: chữ số (có thể có dấu phân cách nghìn), > 0, tối đa 15 chữ số.
  static int? parseWinningPrice(String text) {
    final digits = text.replaceAll(RegExp(r'[.,\s]'), '');
    if (!RegExp(r'^\d{1,15}$').hasMatch(digits)) return null;
    final value = int.parse(digits);
    return value > 0 ? value : null;
  }

  /// Ghi kết quả: Trúng cần giá > 0; Trượt cần lý do.
  static CrmTenderBuild buildResult({
    required String result,
    required String winningPrice,
    required String winnerName,
    required String reason,
    required int version,
  }) {
    final winner = winnerName.trim();
    if (result == 'WON') {
      final price = parseWinningPrice(winningPrice);
      if (price == null) return const CrmTenderBuild.fail('crm.opportunities.tender.error.price_invalid');
      return CrmTenderBuild.ok({
        'version': version,
        'result': 'WON',
        'winningPrice': price,
        'winnerName': winner.isEmpty ? null : winner,
        'reason': null,
      });
    }
    final r = reason.trim();
    if (r.isEmpty) return const CrmTenderBuild.fail('crm.opportunities.tender.error.lost_reason_required');
    return CrmTenderBuild.ok({'version': version, 'result': 'LOST', 'winnerName': winner.isEmpty ? null : winner, 'reason': r});
  }
}
