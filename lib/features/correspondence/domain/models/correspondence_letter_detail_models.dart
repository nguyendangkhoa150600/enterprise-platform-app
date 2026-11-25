import '../../../../core/i18n/app_i18n.dart';
import 'correspondence_models.dart';

// Chi tiết công văn: phân công, bước, tệp, trao đổi, lịch sử, quyền thao tác.

class LetterAssignment {
  final String id;
  final String unitId;
  final String unitName;
  final String? handlerUserId;
  final String? handlerName;
  final String role; // 'lead' | 'support' | 'info'
  final int round;
  final String stage;
  final String status;
  final String? responseNote;
  final String? submittedBy;
  final String? submittedByName;
  final String? submittedAt;
  final String? revisionReason;
  final List<String> headNames;
  final bool canAssignHandler;
  final bool canRespond;
  final List<String> waitingFor;
  final String? dueOn;
  final String? comment;

  const LetterAssignment({
    required this.id,
    required this.unitId,
    required this.unitName,
    this.handlerUserId,
    this.handlerName,
    this.role = 'lead',
    this.round = 1,
    this.stage = '',
    this.status = 'pending',
    this.responseNote,
    this.submittedBy,
    this.submittedByName,
    this.submittedAt,
    this.revisionReason,
    this.headNames = const [],
    this.canAssignHandler = false,
    this.canRespond = false,
    this.waitingFor = const [],
    this.dueOn,
    this.comment,
  });

  factory LetterAssignment.fromJson(Map<String, dynamic> json) {
    final rawHeads = json['headNames'] as List? ?? [];
    final rawWaiting = json['waitingFor'] as List? ?? [];
    return LetterAssignment(
      id: json['id']?.toString() ?? '',
      unitId: json['unitId']?.toString() ?? '',
      unitName: json['unitName']?.toString() ?? '',
      handlerUserId: json['handlerUserId']?.toString(),
      handlerName: json['handlerName']?.toString(),
      role: json['role']?.toString() ?? 'lead',
      round: (json['round'] as num?)?.toInt() ?? 1,
      stage: json['stage']?.toString() ?? '',
      status: json['status']?.toString() ?? json['stage']?.toString() ?? 'pending',
      responseNote: json['responseNote']?.toString(),
      submittedBy: json['submittedBy']?.toString(),
      submittedByName: json['submittedByName']?.toString(),
      submittedAt: json['submittedAt']?.toString(),
      revisionReason: json['revisionReason']?.toString(),
      headNames: rawHeads.map((e) => e.toString()).toList(),
      canAssignHandler: json['canAssignHandler'] == true,
      canRespond: json['canRespond'] == true,
      waitingFor: rawWaiting.map((e) => e.toString()).toList(),
      dueOn: json['dueOn']?.toString(),
      comment: json['comment']?.toString(),
    );
  }
}

/// Đơn vị trong chỉ đạo / bút phê
class LetterDirectiveUnit {
  final String unitId;
  final String unitName;
  final String? handlerUserId;
  final String role;

  const LetterDirectiveUnit({
    required this.unitId,
    required this.unitName,
    this.handlerUserId,
    this.role = 'lead',
  });

  factory LetterDirectiveUnit.fromJson(Map<String, dynamic> json) {
    return LetterDirectiveUnit(
      unitId: json['unitId']?.toString() ?? '',
      unitName: json['unitName']?.toString() ?? '',
      handlerUserId: json['handlerUserId']?.toString(),
      role: json['role']?.toString() ?? 'lead',
    );
  }
}

/// Bút phê chỉ đạo của lãnh đạo
class LetterDirective {
  final String byUserId;
  final String byName;
  final String createdOn;
  final String? note;
  final String? dueOn;
  final List<LetterDirectiveUnit> units;

  const LetterDirective({
    required this.byUserId,
    required this.byName,
    required this.createdOn,
    this.note,
    this.dueOn,
    this.units = const [],
  });

  factory LetterDirective.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['units'] as List? ?? [];
    return LetterDirective(
      byUserId: json['byUserId']?.toString() ?? '',
      byName: json['byName']?.toString() ?? '',
      createdOn: json['createdOn']?.toString() ?? '',
      note: json['note']?.toString(),
      dueOn: json['dueOn']?.toString(),
      units: rawUnits
          .whereType<Map>()
          .map((u) => LetterDirectiveUnit.fromJson(Map<String, dynamic>.from(u)))
          .toList(),
    );
  }
}

/// Nhân sự trong danh bạ văn thư (dùng để @ nhắc tên, giao việc)
class FlowNode {
  final String key;
  final String label;
  final String kind;
  final String state; // 'done' | 'current' | 'todo'
  final bool approval;
  final String? people;
  final String? at;

  const FlowNode({
    required this.key,
    required this.label,
    this.kind = 'step',
    this.state = 'todo',
    this.approval = false,
    this.people,
    this.at,
  });

  factory FlowNode.fromJson(Map<String, dynamic> json) {
    return FlowNode(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'step',
      state: json['state']?.toString() ?? 'todo',
      approval: json['approval'] == true,
      people: json['people']?.toString(),
      at: json['at']?.toString(),
    );
  }
}

/// Bước duyệt công văn
class LetterStep {
  final String id;
  final int seq;
  final String name;
  final String? type;
  final bool directs;
  final String status; // 'waiting' | 'active' | 'done' | 'skipped'
  final String? decision;
  final String? actedAt;
  final String? actedBy;
  final String? actedByName;
  final String? note;
  final List<String> assignees;

  const LetterStep({
    required this.id,
    required this.seq,
    required this.name,
    this.type,
    this.directs = false,
    this.status = 'waiting',
    this.decision,
    this.actedAt,
    this.actedBy,
    this.actedByName,
    this.note,
    this.assignees = const [],
  });

  factory LetterStep.fromJson(Map<String, dynamic> json) {
    final rawAssignees = json['assignees'] as List? ?? [];
    final names = rawAssignees.map((e) {
      if (e is Map<String, dynamic>) {
        return e['name']?.toString() ?? '';
      }
      return e.toString();
    }).where((s) => s.isNotEmpty).toList();

    return LetterStep(
      id: json['id']?.toString() ?? '',
      seq: (json['seq'] as num?)?.toInt() ?? 1,
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString(),
      directs: json['directs'] == true,
      status: json['status']?.toString() ?? 'waiting',
      decision: json['decision']?.toString(),
      actedAt: json['actedAt']?.toString(),
      actedBy: json['actedBy']?.toString(),
      actedByName: json['actedByName']?.toString(),
      note: json['note']?.toString(),
      assignees: names,
    );
  }
}

/// Tệp đính kèm của công văn
class LetterAttachment {
  final String id;
  final String kind;
  final String? assignmentId;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final int versionNo;
  final String uploadedByName;
  final String createdAt;
  final bool canDelete;
  final bool canVersion;

  const LetterAttachment({
    required this.id,
    this.kind = 'incoming',
    this.assignmentId,
    required this.fileName,
    this.contentType = '',
    this.sizeBytes = 0,
    this.versionNo = 1,
    this.uploadedByName = '',
    this.createdAt = '',
    this.canDelete = false,
    this.canVersion = false,
  });

  factory LetterAttachment.fromJson(Map<String, dynamic> json) {
    return LetterAttachment(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'incoming',
      assignmentId: json['assignmentId']?.toString() ?? json['assignment_id']?.toString(),
      fileName: json['fileName']?.toString() ?? 'correspondence.model.file_fallback'.tr(),
      contentType: json['contentType']?.toString() ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      versionNo: (json['versionNo'] as num?)?.toInt() ?? 1,
      uploadedByName: json['uploadedByName']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      canDelete: json['canDelete'] == true,
      canVersion: json['canVersion'] == true,
    );
  }

  String get formattedSize {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Người được nhắc tên trong trao đổi
class LetterCommentMention {
  final String userId;
  final String name;

  const LetterCommentMention({
    required this.userId,
    this.name = '',
  });

  factory LetterCommentMention.fromJson(Map<String, dynamic> json) {
    return LetterCommentMention(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

/// Bình luận / Trao đổi trong công văn
class LetterComment {
  final String id;
  final String stepLabel;
  final String body;
  final String authorName;
  final String at;
  final List<LetterCommentMention> mentions;

  const LetterComment({
    required this.id,
    this.stepLabel = '',
    required this.body,
    this.authorName = '',
    this.at = '',
    this.mentions = const [],
  });

  factory LetterComment.fromJson(Map<String, dynamic> json) {
    final rawMentions = json['mentions'] as List? ?? [];
    return LetterComment(
      id: json['id']?.toString() ?? '',
      stepLabel: json['stepLabel']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'correspondence.model.user_fallback'.tr(),
      at: json['at']?.toString() ?? '',
      mentions: rawMentions
          .whereType<Map<String, dynamic>>()
          .map((e) => LetterCommentMention.fromJson(e))
          .toList(),
    );
  }
}

/// Lịch sử xử lý công văn
class LetterHistoryEntry {
  final String id;
  final String action;
  final String summary;
  final String? note;
  final String? actorName;
  final String at;

  const LetterHistoryEntry({
    required this.id,
    this.action = '',
    required this.summary,
    this.note,
    this.actorName,
    this.at = '',
  });

  factory LetterHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LetterHistoryEntry(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      note: json['note']?.toString(),
      actorName: json['actorName']?.toString() ?? (json['actorUserId'] != null ? 'correspondence.model.user_fallback'.tr() : 'correspondence.model.system_actor'.tr()),
      at: json['at']?.toString() ?? '',
    );
  }
}

/// Quyền thao tác với công văn ở bước hiện tại
class LetterActions {
  final bool edit;
  final bool dispatch;
  final bool sendToClerk;
  final bool submit;
  final bool approve;
  final bool complete;
  final bool publish;
  final bool cancel;
  final bool reply;
  final bool remind;
  final bool updateDelivery;
  final bool requestRevoke;
  final bool decideRevoke;
  final bool withdrawRevoke;
  final bool remove;
  final bool comment;
  /// 'previous-step' | 'handlers' | 'clerk'
  final List<String> returnTargets;
  /// Các bước đã xong trước bước hiện tại, trả về đúng bước đó (target 'step').
  final List<ReturnStepOption> returnSteps;
  /// Nơi trả về mặc định của bước theo cấu hình quy trình.
  final String? defaultReturnTarget;
  /// Loại tệp được đính kèm ở bước này: 'incoming' | 'draft' | 'outgoing' | 'reference'.
  final List<String> attachKinds;

  const LetterActions({
    this.edit = false,
    this.dispatch = false,
    this.sendToClerk = false,
    this.submit = false,
    this.approve = false,
    this.complete = false,
    this.publish = false,
    this.cancel = false,
    this.reply = false,
    this.remind = false,
    this.updateDelivery = false,
    this.requestRevoke = false,
    this.decideRevoke = false,
    this.withdrawRevoke = false,
    this.remove = false,
    this.comment = false,
    this.returnTargets = const [],
    this.returnSteps = const [],
    this.defaultReturnTarget,
    this.attachKinds = const [],
  });

  factory LetterActions.fromJson(Map<String, dynamic> json) {
    final rawTargets = json['returnTargets'] as List? ?? [];
    return LetterActions(
      edit: json['edit'] == true,
      dispatch: json['dispatch'] == true,
      sendToClerk: json['sendToClerk'] == true,
      submit: json['submit'] == true,
      approve: json['approve'] == true,
      complete: json['complete'] == true,
      publish: json['publish'] == true,
      cancel: json['cancel'] == true,
      reply: json['reply'] == true,
      remind: json['remind'] == true,
      updateDelivery: json['updateDelivery'] == true,
      requestRevoke: json['requestRevoke'] == true,
      decideRevoke: json['decideRevoke'] == true,
      withdrawRevoke: json['withdrawRevoke'] == true,
      remove: json['remove'] == true,
      comment: json['comment'] == true,
      returnTargets: rawTargets.map((e) => e.toString()).toList(),
      returnSteps: (json['returnSteps'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ReturnStepOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      defaultReturnTarget: json['defaultReturnTarget']?.toString(),
      attachKinds: (json['attachKinds'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

/// Một bước đã xong có thể trả công văn về (`target: 'step'`, `stepSeq`).
class ReturnStepOption {
  final int seq;
  final String name;

  const ReturnStepOption({required this.seq, required this.name});

  factory ReturnStepOption.fromJson(Map<String, dynamic> json) => ReturnStepOption(
        seq: (json['seq'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
      );
}

/// Thông tin đề nghị huỷ / thu hồi công văn
class LetterRevoke {
  final String kind;
  final String kindLabel;
  final String reason;
  final String? requestedBy;
  final String? requestedByName;
  final String? requestedAt;
  final List<String> approverNames;

  const LetterRevoke({
    required this.kind,
    required this.kindLabel,
    required this.reason,
    this.requestedBy,
    this.requestedByName,
    this.requestedAt,
    this.approverNames = const [],
  });

  factory LetterRevoke.fromJson(Map<String, dynamic> json) {
    final rawApprovers = json['approverNames'] as List? ?? [];
    return LetterRevoke(
      kind: json['kind']?.toString() ?? '',
      kindLabel: json['kindLabel']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      requestedBy: json['requestedBy']?.toString(),
      requestedByName: json['requestedByName']?.toString(),
      requestedAt: json['requestedAt']?.toString(),
      approverNames: rawApprovers.map((e) => e.toString()).toList(),
    );
  }
}

/// Chi tiết đầy đủ của một công văn (Đến hoặc Đi)
class LetterDetail extends LetterSummary {
  final String? instruction;
  final String? workflowName;
  final String? chosenWorkflowId;
  final String? envelopeStatus;
  final bool sealed;
  final int? pageCount;
  final String? receivedByName;
  final String? registerName;
  final List<FlowNode> flow;
  final List<LetterStep> steps;
  final List<LetterAssignment> assignments;
  final LetterDirective? directive;
  final LetterRevoke? revoke;
  final String? cancelReason;
  final List<LetterAttachment> attachments;
  final List<LetterComment> comments;
  final List<LetterHistoryEntry> history;
  final bool personal;
  final LetterActions actions;

  const LetterDetail({
    required super.id,
    required super.direction,
    required super.displayNo,
    super.incomingNo = '',
    required super.receivedOn,
    required super.senderOrg,
    super.senderRef,
    super.senderDate,
    required super.subject,
    super.kind = '',
    super.kindName = '',
    super.urgency = 'normal',
    super.urgencyName = 'Thường',
    super.urgencyHighlight = false,
    super.confidentiality = 'normal',
    super.confidentialityName = 'Thường',
    super.restricted = false,
    super.dueOn,
    required super.stage,
    required super.stageLabel,
    super.currentStepName,
    super.currentAssigneeNames = const [],
    super.assignmentsDone = 0,
    super.assignmentsTotal = 0,
    super.authorUserId,
    super.authorName,
    super.authorUnitName,
    super.outgoingNo,
    super.publishedOn,
    super.recipient,
    super.deliveryStatus,
    super.deliveredOn,
    super.completionNote,
    super.archiveCode,
    super.archivedOn,
    super.awaitingMe = false,
    super.unitNames = const [],
    super.signerName,
    super.signerTitle,
    super.copyCount,
    super.sentAs = 'person',
    this.instruction,
    this.workflowName,
    this.chosenWorkflowId,
    this.envelopeStatus,
    this.sealed = false,
    this.pageCount,
    this.receivedByName,
    this.registerName,
    this.flow = const [],
    this.steps = const [],
    this.assignments = const [],
    this.directive,
    this.revoke,
    this.cancelReason,
    this.attachments = const [],
    this.comments = const [],
    this.history = const [],
    this.personal = false,
    this.actions = const LetterActions(),
  });

  factory LetterDetail.fromJson(Map<String, dynamic> json) {
    final base = LetterSummary.fromJson(json);

    final rawFlow = json['flow'] as List? ?? [];
    final rawSteps = json['steps'] as List? ?? [];
    final rawAssignments = json['assignments'] as List? ?? [];
    final rawDirective = json['directive'] is Map ? json['directive'] as Map : null;
    final rawRevoke = json['revoke'] is Map ? json['revoke'] as Map : null;
    final rawAttachments = json['attachments'] as List? ?? [];
    final rawComments = json['comments'] as List? ?? [];
    final rawHistory = json['history'] as List? ?? [];
    final rawActions = json['actions'] is Map<String, dynamic>
        ? json['actions'] as Map<String, dynamic>
        : <String, dynamic>{};

    return LetterDetail(
      id: base.id,
      direction: base.direction,
      displayNo: base.displayNo,
      incomingNo: base.incomingNo,
      receivedOn: base.receivedOn,
      senderOrg: base.senderOrg,
      senderRef: base.senderRef,
      senderDate: base.senderDate,
      subject: base.subject,
      kind: base.kind,
      kindName: base.kindName,
      urgency: base.urgency,
      urgencyName: base.urgencyName,
      urgencyHighlight: base.urgencyHighlight,
      confidentiality: base.confidentiality,
      confidentialityName: base.confidentialityName,
      restricted: base.restricted,
      dueOn: base.dueOn,
      stage: base.stage,
      stageLabel: base.stageLabel,
      currentStepName: base.currentStepName,
      currentAssigneeNames: base.currentAssigneeNames,
      assignmentsDone: base.assignmentsDone,
      assignmentsTotal: base.assignmentsTotal,
      authorUserId: base.authorUserId,
      authorName: base.authorName,
      authorUnitName: base.authorUnitName,
      outgoingNo: base.outgoingNo,
      publishedOn: base.publishedOn,
      recipient: base.recipient,
      deliveryStatus: base.deliveryStatus,
      deliveredOn: base.deliveredOn,
      completionNote: base.completionNote,
      archiveCode: base.archiveCode,
      archivedOn: base.archivedOn,
      awaitingMe: base.awaitingMe,
      unitNames: base.unitNames,
      signerName: base.signerName,
      signerTitle: base.signerTitle,
      sentAs: base.sentAs,
      instruction: json['instruction']?.toString(),
      workflowName: json['workflowName']?.toString(),
      chosenWorkflowId: json['chosenWorkflowId']?.toString() ?? json['workflowId']?.toString(),
      envelopeStatus: json['envelopeStatus']?.toString(),
      sealed: json['sealed'] == true,
      pageCount: (json['pageCount'] as num?)?.toInt(),
      copyCount: (json['copyCount'] as num?)?.toInt(),
      receivedByName: json['receivedByName']?.toString(),
      registerName: json['registerName']?.toString(),
      personal: json['personal'] == true,
      flow: rawFlow
          .whereType<Map<String, dynamic>>()
          .map((e) => FlowNode.fromJson(e))
          .toList(),
      steps: rawSteps
          .whereType<Map<String, dynamic>>()
          .map((e) => LetterStep.fromJson(e))
          .toList(),
      assignments: rawAssignments
          .whereType<Map>()
          .map((a) => LetterAssignment.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
      directive: rawDirective != null
          ? LetterDirective.fromJson(Map<String, dynamic>.from(rawDirective))
          : null,
      revoke: rawRevoke != null
          ? LetterRevoke.fromJson(Map<String, dynamic>.from(rawRevoke))
          : null,
      cancelReason: json['cancelReason']?.toString(),
      attachments: rawAttachments
          .whereType<Map<String, dynamic>>()
          .map((e) => LetterAttachment.fromJson(e))
          .toList(),
      comments: rawComments
          .whereType<Map<String, dynamic>>()
          .map((e) => LetterComment.fromJson(e))
          .toList(),
      history: rawHistory
          .whereType<Map<String, dynamic>>()
          .map((e) => LetterHistoryEntry.fromJson(e))
          .toList(),
      actions: LetterActions.fromJson(rawActions),
    );
  }
}
