/// Model phiếu thu/chi/chuyển tiền (web `contracts-finance.ts` + `finance-procedure-step.ts`).
library;

import 'finance_json.dart';
import 'finance_models.dart';

class FinanceVoucherLine {
  final String? id;
  final int? lineNo;
  final String description;
  final double quantity;
  final double unitAmount;

  /// = quantity * unitAmount (server luôn tính lại).
  final double total;

  const FinanceVoucherLine({
    this.id,
    this.lineNo,
    required this.description,
    required this.quantity,
    required this.unitAmount,
    required this.total,
  });

  factory FinanceVoucherLine.fromJson(Map<String, dynamic> j) => FinanceVoucherLine(
        id: fStrOrNull(j['id']),
        lineNo: j['lineNo'] == null ? null : fInt(j['lineNo']),
        description: fStr(j['description']),
        quantity: fDouble(j['quantity'], 1),
        unitAmount: fDouble(j['unitAmount']),
        total: fDouble(j['total']),
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'unitAmount': unitAmount,
        'total': financeLineTotal(quantity, unitAmount),
      };
}

class FinanceVoucherInvoice {
  final String? id;
  final String invoiceNo;
  final String? invoiceDate;
  final String? taxCode;
  final double amount;

  const FinanceVoucherInvoice({this.id, required this.invoiceNo, this.invoiceDate, this.taxCode, required this.amount});

  factory FinanceVoucherInvoice.fromJson(Map<String, dynamic> j) => FinanceVoucherInvoice(
        id: fStrOrNull(j['id']),
        invoiceNo: fStr(j['invoiceNo']),
        invoiceDate: fStrOrNull(j['invoiceDate']),
        taxCode: fStrOrNull(j['taxCode']),
        amount: fDouble(j['amount']),
      );

  Map<String, dynamic> toJson() => {
        'invoiceNo': invoiceNo,
        'invoiceDate': invoiceDate,
        'taxCode': taxCode,
        'amount': amount,
      };
}

/// Hạch toán nội bộ cho dự án (chỉ cấp dự án).
class FinanceAllocation {
  final String projectId;
  final String projectCode;
  final String projectName;

  const FinanceAllocation({required this.projectId, required this.projectCode, required this.projectName});

  static FinanceAllocation? fromJson(dynamic json) {
    if (json is! Map) return null;
    final j = Map<String, dynamic>.from(json);
    return FinanceAllocation(
      projectId: fStr(j['projectId']),
      projectCode: fStr(j['projectCode']),
      projectName: fStr(j['projectName']),
    );
  }

  /// "DA001 - Tên dự án" (web `financeAllocationLabel`).
  String get label => '$projectCode - $projectName';
}

/// Dự án liên quan: chỉ tham chiếu, không cộng vào tổng thu chi dự án.
class FinanceRelatedProject {
  final String projectId;
  final String projectCode;
  final String projectName;
  const FinanceRelatedProject({required this.projectId, required this.projectCode, required this.projectName});

  factory FinanceRelatedProject.fromJson(Map<String, dynamic> j) => FinanceRelatedProject(
        projectId: fStr(j['projectId']),
        projectCode: fStr(j['projectCode']),
        projectName: fStr(j['projectName']),
      );

  String get label => '$projectCode - $projectName';
}

class FinanceVoucherAttachment {
  final String id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String? uploadedBy;
  final String? uploadedByName;
  final String uploadedAt;

  /// ATTACHMENT (đính kèm thủ công) hoặc NOTE_IMAGE (ảnh dán trong ghi chú).
  final String purpose;

  const FinanceVoucherAttachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.uploadedBy,
    this.uploadedByName,
    this.uploadedAt = '',
    this.purpose = 'ATTACHMENT',
  });

  factory FinanceVoucherAttachment.fromJson(Map<String, dynamic> j) => FinanceVoucherAttachment(
        id: fStr(j['id']),
        fileName: fStr(j['fileName']),
        contentType: fStr(j['contentType']),
        sizeBytes: fInt(j['sizeBytes']),
        uploadedBy: fStrOrNull(j['uploadedBy']),
        uploadedByName: fStrOrNull(j['uploadedByName']),
        uploadedAt: fStr(j['uploadedAt']),
        purpose: fStr(j['purpose'], 'ATTACHMENT'),
      );

  bool get isNoteImage => purpose == 'NOTE_IMAGE';
}

/// Sự kiện lịch sử xử lý. [action]: CREATED, UPDATED, SUBMITTED, APPROVED, REJECTED, RETURNED, CANCELLED, REVERSED, TAKEN_OVER.
class FinanceVoucherEvent {
  final String id;
  final String action;
  final String? actorId;
  final String? actorName;
  final String? note;
  final String createdAt;

  const FinanceVoucherEvent({
    required this.id,
    required this.action,
    this.actorId,
    this.actorName,
    this.note,
    this.createdAt = '',
  });

  factory FinanceVoucherEvent.fromJson(Map<String, dynamic> j) => FinanceVoucherEvent(
        id: fStr(j['id']),
        action: fStr(j['action']),
        actorId: fStrOrNull(j['actorId']),
        actorName: fStrOrNull(j['actorName']),
        note: fStrOrNull(j['note']),
        createdAt: fStr(j['createdAt']),
      );
}

class FinanceSourcedPermissions {
  final bool canEditSourced;
  final bool canPost;
  final bool canReturnSource;
  final bool canTakeOver;
  final bool canRetryReversal;

  const FinanceSourcedPermissions({
    this.canEditSourced = false,
    this.canPost = false,
    this.canReturnSource = false,
    this.canTakeOver = false,
    this.canRetryReversal = false,
  });

  factory FinanceSourcedPermissions.fromJson(dynamic json) {
    final j = fMap(json);
    return FinanceSourcedPermissions(
      canEditSourced: fBool(j['canEditSourced']),
      canPost: fBool(j['canPost']),
      canReturnSource: fBool(j['canReturnSource']),
      canTakeOver: fBool(j['canTakeOver']),
      canRetryReversal: fBool(j['canRetryReversal']),
    );
  }
}

/// Thao tác người xem được làm ngay bây giờ (server tính).
class FinanceVoucherPermissions {
  final bool canEdit;
  final bool canSubmit;
  final bool canApprove;
  final bool canReject;
  final bool canCancel;
  final bool canReverse;
  final bool canDelete;
  final bool canRetryProcedure;
  final FinanceSourcedPermissions sourced;

  const FinanceVoucherPermissions({
    this.canEdit = false,
    this.canSubmit = false,
    this.canApprove = false,
    this.canReject = false,
    this.canCancel = false,
    this.canReverse = false,
    this.canDelete = false,
    this.canRetryProcedure = false,
    this.sourced = const FinanceSourcedPermissions(),
  });

  factory FinanceVoucherPermissions.fromJson(dynamic json) {
    final j = fMap(json);
    return FinanceVoucherPermissions(
      canEdit: fBool(j['canEdit']),
      canSubmit: fBool(j['canSubmit']),
      canApprove: fBool(j['canApprove']),
      canReject: fBool(j['canReject']),
      canCancel: fBool(j['canCancel']),
      canReverse: fBool(j['canReverse']),
      canDelete: fBool(j['canDelete']),
      canRetryProcedure: fBool(j['canRetryProcedure']),
      sourced: FinanceSourcedPermissions.fromJson(j['sourced']),
    );
  }
}

/// Tiến độ quy trình duyệt (chế độ PROCEDURE).
/// [syncStatus]: START_PENDING/FAILED (chưa tạo được hồ sơ), RUNNING, APPLIED, CONFLICT (đã duyệt nhưng chưa ghi sổ), CLOSED.
class FinanceProcedureProgress {
  final String? instanceId;
  final String? instanceCode;
  final String status;
  final String? currentStepName;
  final String? currentAssigneeName;
  final bool? canAct;
  final String syncStatus;
  final String? lastError;

  const FinanceProcedureProgress({
    this.instanceId,
    this.instanceCode,
    this.status = '',
    this.currentStepName,
    this.currentAssigneeName,
    this.canAct,
    this.syncStatus = '',
    this.lastError,
  });

  static FinanceProcedureProgress? fromJson(dynamic json) {
    if (json is! Map) return null;
    final j = Map<String, dynamic>.from(json);
    return FinanceProcedureProgress(
      instanceId: fStrOrNull(j['instanceId']),
      instanceCode: fStrOrNull(j['instanceCode']),
      status: fStr(j['status']),
      currentStepName: fStrOrNull(j['currentStepName']),
      currentAssigneeName: fStrOrNull(j['currentAssigneeName']),
      canAct: j['canAct'] == null ? null : fBool(j['canAct']),
      syncStatus: fStr(j['syncStatus']),
      lastError: fStrOrNull(j['lastError']),
    );
  }
}

/// Giá trị bước Tài chính của hồ sơ quy trình gửi sang.
class FinanceSourceValues {
  final double? amount;
  final String? content;
  final String? counterpartyName;
  final String? counterpartyAccountNo;
  final String? counterpartyBank;
  final String? voucherDate;

  const FinanceSourceValues({
    this.amount,
    this.content,
    this.counterpartyName,
    this.counterpartyAccountNo,
    this.counterpartyBank,
    this.voucherDate,
  });

  factory FinanceSourceValues.fromJson(dynamic json) {
    final j = fMap(json);
    return FinanceSourceValues(
      amount: fDoubleOrNull(j['amount']),
      content: fStrOrNull(j['content']),
      counterpartyName: fStrOrNull(j['counterpartyName']),
      counterpartyAccountNo: fStrOrNull(j['counterpartyAccountNo']),
      counterpartyBank: fStrOrNull(j['counterpartyBank']),
      voucherDate: fStrOrNull(j['voucherDate']),
    );
  }
}

/// Hồ sơ nguồn đã tạo ra phiếu (chế độ INHERITED).
/// [status]: OPEN, RETURNED, POSTED, CLOSED, REVERSAL_PENDING, REVERSED.
/// [lockedFields]: amount, content, counterpartyName, counterpartyAccountNo, counterpartyBank, voucherDate, allocation.
class FinanceVoucherSource {
  final String sourceModule;
  final String? sourceRef;
  final String? instanceId;
  final String instanceCode;
  final String? instanceTitle;
  final String? definitionName;
  final String? stepName;
  final int activation;
  final String status;
  final FinanceSourceValues values;
  final String? requestedProjectId;
  final String? requestedWorkItemId;
  final List<String> lockedFields;
  final String? assigneeLabel;
  final String? handlingBy;
  final String? handlingByName;
  final String? handlingSince;
  final bool? canAct;
  final String? canActReason;
  final String? reversalReason;
  final String? reversalError;

  const FinanceVoucherSource({
    required this.sourceModule,
    this.sourceRef,
    this.instanceId,
    required this.instanceCode,
    this.instanceTitle,
    this.definitionName,
    this.stepName,
    this.activation = 0,
    this.status = '',
    this.values = const FinanceSourceValues(),
    this.requestedProjectId,
    this.requestedWorkItemId,
    this.lockedFields = const [],
    this.assigneeLabel,
    this.handlingBy,
    this.handlingByName,
    this.handlingSince,
    this.canAct,
    this.canActReason,
    this.reversalReason,
    this.reversalError,
  });

  static FinanceVoucherSource? fromJson(dynamic json) {
    if (json is! Map) return null;
    final j = Map<String, dynamic>.from(json);
    return FinanceVoucherSource(
      sourceModule: fStr(j['sourceModule']),
      sourceRef: fStrOrNull(j['sourceRef']),
      instanceId: fStrOrNull(j['instanceId']),
      instanceCode: fStr(j['instanceCode']),
      instanceTitle: fStrOrNull(j['instanceTitle']),
      definitionName: fStrOrNull(j['definitionName']),
      stepName: fStrOrNull(j['stepName']),
      activation: fInt(j['activation']),
      status: fStr(j['status']),
      values: FinanceSourceValues.fromJson(j['values']),
      requestedProjectId: fStrOrNull(j['requestedProjectId']),
      requestedWorkItemId: fStrOrNull(j['requestedWorkItemId']),
      lockedFields: fStrings(j['lockedFields']),
      assigneeLabel: fStrOrNull(j['assigneeLabel']),
      handlingBy: fStrOrNull(j['handlingBy']),
      handlingByName: fStrOrNull(j['handlingByName']),
      handlingSince: fStrOrNull(j['handlingSince']),
      canAct: j['canAct'] == null ? null : fBool(j['canAct']),
      canActReason: fStrOrNull(j['canActReason']),
      reversalReason: fStrOrNull(j['reversalReason']),
      reversalError: fStrOrNull(j['reversalError']),
    );
  }

  bool isLocked(String field) => lockedFields.contains(field);
}

/// Công việc Workspace liên quan tới phiếu (qua hồ sơ quy trình), chỉ để tham chiếu.
class FinanceLinkedWorkItem {
  final String id;
  final String code;
  final String title;
  final String status;
  final String projectId;
  const FinanceLinkedWorkItem({
    required this.id,
    required this.code,
    required this.title,
    required this.status,
    required this.projectId,
  });

  static FinanceLinkedWorkItem? fromJson(dynamic json) {
    if (json is! Map) return null;
    final j = Map<String, dynamic>.from(json);
    return FinanceLinkedWorkItem(
      id: fStr(j['id']),
      code: fStr(j['code']),
      title: fStr(j['title']),
      status: fStr(j['status']),
      projectId: fStr(j['projectId']),
    );
  }
}

/// Dòng phiếu ở danh sách (`FinanceVoucherSummary`).
class FinanceVoucherSummary {
  final String id;
  final FinanceVoucherKind kind;

  /// Mã đang hiển thị (chính thức nếu đã ghi sổ, không thì mã nháp).
  final String code;
  final String voucherDate;
  final String postingDate;
  final String content;
  final String? reasonId;
  final String? reasonName;
  final String? accountId;
  final String? accountName;
  final String? destAccountId;
  final String? destAccountName;
  final String? counterpartyGroupName;
  final String? counterpartyName;
  final double totalAmount;
  final FinanceVoucherStatus status;
  final String createdBy;
  final String? createdByName;
  final String createdAt;
  final String updatedAt;
  final String? submittedAt;
  final String? decidedAt;
  final FinanceApprovalMode approvalMode;
  final FinanceAllocation? allocation;
  final String? draftCode;
  final String? officialCode;

  /// Mã hồ sơ quy trình đã tạo ra phiếu (INHERITED).
  final String? sourceCode;

  const FinanceVoucherSummary({
    required this.id,
    required this.kind,
    required this.code,
    required this.voucherDate,
    required this.postingDate,
    required this.content,
    this.reasonId,
    this.reasonName,
    this.accountId,
    this.accountName,
    this.destAccountId,
    this.destAccountName,
    this.counterpartyGroupName,
    this.counterpartyName,
    required this.totalAmount,
    required this.status,
    this.createdBy = '',
    this.createdByName,
    this.createdAt = '',
    this.updatedAt = '',
    this.submittedAt,
    this.decidedAt,
    this.approvalMode = FinanceApprovalMode.direct,
    this.allocation,
    this.draftCode,
    this.officialCode,
    this.sourceCode,
  });

  factory FinanceVoucherSummary.fromJson(Map<String, dynamic> j) => FinanceVoucherSummary(
        id: fStr(j['id']),
        kind: FinanceVoucherKind.fromApi(j['kind']),
        code: fStr(j['code']),
        voucherDate: fStr(j['voucherDate']),
        postingDate: fStr(j['postingDate']),
        content: fStr(j['content']),
        reasonId: fStrOrNull(j['reasonId']),
        reasonName: fStrOrNull(j['reasonName']),
        accountId: fStrOrNull(j['accountId']),
        accountName: fStrOrNull(j['accountName']),
        destAccountId: fStrOrNull(j['destAccountId']),
        destAccountName: fStrOrNull(j['destAccountName']),
        counterpartyGroupName: fStrOrNull(j['counterpartyGroupName']),
        counterpartyName: fStrOrNull(j['counterpartyName']),
        totalAmount: fDouble(j['totalAmount']),
        status: FinanceVoucherStatus.fromApi(j['status']),
        createdBy: fStr(j['createdBy']),
        createdByName: fStrOrNull(j['createdByName']),
        createdAt: fStr(j['createdAt']),
        updatedAt: fStr(j['updatedAt']),
        submittedAt: fStrOrNull(j['submittedAt']),
        decidedAt: fStrOrNull(j['decidedAt']),
        approvalMode: FinanceApprovalMode.fromApi(j['approvalMode']),
        allocation: FinanceAllocation.fromJson(j['allocation']),
        draftCode: fStrOrNull(j['draftCode']),
        officialCode: fStrOrNull(j['officialCode']),
        sourceCode: fStrOrNull(j['sourceCode']),
      );
}

/// Phiếu đầy đủ (`GET /vouchers/:id`).
class FinanceVoucher extends FinanceVoucherSummary {
  final String? counterpartyGroupId;
  final String? counterpartyAccountNo;
  final String? counterpartyBank;
  final bool taxIncluded;
  final double taxRate;
  final double taxAmount;

  /// Ghi chú dạng HTML (rich text của web).
  final String? note;
  final String? decisionNote;
  final String? decidedBy;
  final String? decidedByName;
  final int revision;
  final List<FinanceVoucherLine> lines;
  final List<FinanceVoucherInvoice> invoices;
  final List<FinanceRelatedProject> relatedProjects;
  final List<FinanceVoucherAttachment> attachments;
  final List<FinanceVoucherEvent> events;
  final bool posted;
  final FinanceProcedureProgress? procedure;
  final FinanceVoucherSource? source;
  final FinanceLinkedWorkItem? linkedWorkItem;
  final FinanceVoucherPermissions permissions;

  FinanceVoucher._(
    FinanceVoucherSummary s, {
    this.counterpartyGroupId,
    this.counterpartyAccountNo,
    this.counterpartyBank,
    this.taxIncluded = false,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.note,
    this.decisionNote,
    this.decidedBy,
    this.decidedByName,
    this.revision = 0,
    this.lines = const [],
    this.invoices = const [],
    this.relatedProjects = const [],
    this.attachments = const [],
    this.events = const [],
    this.posted = false,
    this.procedure,
    this.source,
    this.linkedWorkItem,
    this.permissions = const FinanceVoucherPermissions(),
  }) : super(
          id: s.id,
          kind: s.kind,
          code: s.code,
          voucherDate: s.voucherDate,
          postingDate: s.postingDate,
          content: s.content,
          reasonId: s.reasonId,
          reasonName: s.reasonName,
          accountId: s.accountId,
          accountName: s.accountName,
          destAccountId: s.destAccountId,
          destAccountName: s.destAccountName,
          counterpartyGroupName: s.counterpartyGroupName,
          counterpartyName: s.counterpartyName,
          totalAmount: s.totalAmount,
          status: s.status,
          createdBy: s.createdBy,
          createdByName: s.createdByName,
          createdAt: s.createdAt,
          updatedAt: s.updatedAt,
          submittedAt: s.submittedAt,
          decidedAt: s.decidedAt,
          approvalMode: s.approvalMode,
          allocation: s.allocation,
          draftCode: s.draftCode,
          officialCode: s.officialCode,
          sourceCode: s.sourceCode,
        );

  factory FinanceVoucher.fromJson(Map<String, dynamic> j) => FinanceVoucher._(
        FinanceVoucherSummary.fromJson(j),
        counterpartyGroupId: fStrOrNull(j['counterpartyGroupId']),
        counterpartyAccountNo: fStrOrNull(j['counterpartyAccountNo']),
        counterpartyBank: fStrOrNull(j['counterpartyBank']),
        taxIncluded: fBool(j['taxIncluded']),
        taxRate: fDouble(j['taxRate']),
        taxAmount: fDouble(j['taxAmount']),
        note: fStrOrNull(j['note']),
        decisionNote: fStrOrNull(j['decisionNote']),
        decidedBy: fStrOrNull(j['decidedBy']),
        decidedByName: fStrOrNull(j['decidedByName']),
        revision: fInt(j['revision']),
        lines: fList(j['lines']).map(FinanceVoucherLine.fromJson).toList(),
        invoices: fList(j['invoices']).map(FinanceVoucherInvoice.fromJson).toList(),
        relatedProjects: fList(j['relatedProjects']).map(FinanceRelatedProject.fromJson).toList(),
        attachments: fList(j['attachments']).map(FinanceVoucherAttachment.fromJson).toList(),
        events: fList(j['events']).map(FinanceVoucherEvent.fromJson).toList(),
        posted: fBool(j['posted']),
        procedure: FinanceProcedureProgress.fromJson(j['procedure']),
        source: FinanceVoucherSource.fromJson(j['source']),
        linkedWorkItem: FinanceLinkedWorkItem.fromJson(j['linkedWorkItem']),
        permissions: FinanceVoucherPermissions.fromJson(j['permissions']),
      );
}

/// Bộ lọc danh sách phiếu (`GET /vouchers`).
/// [scope]: mine | to-approve | to-post | awaiting-post. [source]: 'procedure' = chỉ phiếu tạo từ quy trình.
class FinanceVoucherQuery {
  final FinanceVoucherKind kind;
  final FinanceVoucherStatus? status;
  final String? search;
  final String? accountId;
  final String? reasonId;
  final String? projectId;
  final String? from;
  final String? to;
  final String? scope;
  final String? source;
  final int page;
  final int pageSize;

  const FinanceVoucherQuery({
    required this.kind,
    this.status,
    this.search,
    this.accountId,
    this.reasonId,
    this.projectId,
    this.from,
    this.to,
    this.scope,
    this.source,
    this.page = 1,
    this.pageSize = 20,
  });

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{'kind': kind.api, 'page': page, 'pageSize': pageSize};
    void put(String k, String? v) {
      if (v != null && v.trim().isNotEmpty) q[k] = v.trim();
    }

    put('status', status?.api);
    put('search', search);
    put('accountId', accountId);
    put('reasonId', reasonId);
    put('projectId', projectId);
    put('from', from);
    put('to', to);
    put('scope', scope);
    put('source', source);
    return q;
  }
}

class FinanceVoucherList {
  final List<FinanceVoucherSummary> items;
  final int total;
  final int page;
  final int pageSize;

  /// Số phiếu theo trạng thái (theo bộ lọc nhưng không theo trạng thái), cho các tab.
  final Map<FinanceVoucherStatus, int> statusCounts;

  /// Tổng tiền theo trạng thái, cho thẻ "Tổng kết kỳ".
  final Map<FinanceVoucherStatus, double> statusAmounts;
  final double approvedTotal;

  const FinanceVoucherList({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.statusCounts = const {},
    this.statusAmounts = const {},
    this.approvedTotal = 0,
  });

  factory FinanceVoucherList.fromJson(Map<String, dynamic> j) {
    final counts = fMap(j['statusCounts']);
    final amounts = fMap(j['statusAmounts']);
    return FinanceVoucherList(
      items: fList(j['items']).map(FinanceVoucherSummary.fromJson).toList(),
      total: fInt(j['total']),
      page: fInt(j['page'], 1),
      pageSize: fInt(j['pageSize'], 20),
      statusCounts: {for (final s in FinanceVoucherStatus.values) s: fInt(counts[s.api])},
      statusAmounts: {for (final s in FinanceVoucherStatus.values) s: fDouble(amounts[s.api])},
      approvedTotal: fDouble(j['approvedTotal']),
    );
  }

  bool get hasMore => page * pageSize < total;
}

class FinanceBulkApproveResult {
  final List<({String id, String code})> approved;
  final List<({String id, String? code, String message})> failed;
  const FinanceBulkApproveResult({this.approved = const [], this.failed = const []});

  factory FinanceBulkApproveResult.fromJson(Map<String, dynamic> j) => FinanceBulkApproveResult(
        approved: fList(j['approved']).map((e) => (id: fStr(e['id']), code: fStr(e['code']))).toList(),
        failed: fList(j['failed'])
            .map((e) => (id: fStr(e['id']), code: fStrOrNull(e['code']), message: fStr(e['message'])))
            .toList(),
      );
}

/* ----------------------------- Hàm tính dùng chung ----------------------------- */

/// Làm tròn tiền 2 chữ số (half away from zero).
double roundMoney(double value) {
  if (!value.isFinite) return 0;
  final sign = value < 0 ? -1 : 1;
  return sign * (double.parse((value.abs() * 100).toStringAsFixed(6)).roundToDouble()) / 100;
}

double financeLineTotal(double quantity, double unitAmount) => roundMoney(quantity * unitAmount);

double financeLinesTotal(Iterable<FinanceVoucherLine> lines) =>
    roundMoney(lines.fold<double>(0, (sum, l) => sum + financeLineTotal(l.quantity, l.unitAmount)));

/// Phần thuế nằm trong tổng đã gồm thuế: total - total / (1 + rate%).
double financeIncludedTax(double total, double taxRate) =>
    taxRate > 0 ? roundMoney(total - total / (1 + taxRate / 100)) : 0;
