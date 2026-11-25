// Payload tạo công văn đến / đi.

class CreateOutgoingRequest {
  final String subject;
  final String recipient;
  final String? dueOn;
  final String? kind;
  final String? urgency;
  final String? confidentiality;
  final String? authorUnitId;
  final String sentAs; // 'person' | 'unit'
  final String? workflowId;
  final String? relatedLetterId;

  const CreateOutgoingRequest({
    required this.subject,
    required this.recipient,
    this.dueOn,
    this.kind,
    this.urgency,
    this.confidentiality,
    this.authorUnitId,
    this.sentAs = 'person',
    this.workflowId,
    this.relatedLetterId,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'subject': subject,
      'recipient': recipient,
      'sentAs': sentAs,
    };
    if (dueOn != null && dueOn!.isNotEmpty) data['dueOn'] = dueOn;
    if (kind != null && kind!.isNotEmpty) data['kind'] = kind;
    if (urgency != null && urgency!.isNotEmpty) data['urgency'] = urgency;
    if (confidentiality != null && confidentiality!.isNotEmpty) {
      data['confidentiality'] = confidentiality;
    }
    if (authorUnitId != null && authorUnitId!.isNotEmpty) {
      data['authorUnitId'] = authorUnitId;
    }
    if (workflowId != null && workflowId!.isNotEmpty) {
      data['workflowId'] = workflowId;
    }
    if (relatedLetterId != null && relatedLetterId!.isNotEmpty) {
      data['relatedLetterId'] = relatedLetterId;
    }
    return data;
  }
}

/// Yêu cầu tiếp nhận công văn đến (Vào sổ công văn)
class CreateLetterRequest {
  final String senderOrg;
  final String? senderRef;
  final String? senderDate;
  final String subject;
  final String? receivedOn;
  final String? dueOn;
  final String? kind;
  final String? urgency;
  final String? confidentiality;
  final String? registerId;
  final String? workflowId;
  final bool? personal;

  // Phân loại sơ bộ (IntakeCheck)
  final String envelopeStatus; // 'intact' | 'damaged' | 'electronic'
  final bool sealed;
  final int? pageCount;
  final int? copyCount;
  final String? addressedTo;
  final String? addressedUserId;

  const CreateLetterRequest({
    required this.senderOrg,
    this.senderRef,
    this.senderDate,
    required this.subject,
    this.receivedOn,
    this.dueOn,
    this.kind,
    this.urgency,
    this.confidentiality,
    this.registerId,
    this.workflowId,
    this.personal,
    this.envelopeStatus = 'intact',
    this.sealed = false,
    this.pageCount,
    this.copyCount,
    this.addressedTo,
    this.addressedUserId,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'senderOrg': senderOrg,
      'subject': subject,
      'envelopeStatus': envelopeStatus,
      'sealed': sealed,
    };
    if (senderRef != null && senderRef!.isNotEmpty) data['senderRef'] = senderRef;
    if (senderDate != null && senderDate!.isNotEmpty) data['senderDate'] = senderDate;
    if (receivedOn != null && receivedOn!.isNotEmpty) data['receivedOn'] = receivedOn;
    if (dueOn != null && dueOn!.isNotEmpty) data['dueOn'] = dueOn;
    if (kind != null && kind!.isNotEmpty) data['kind'] = kind;
    if (urgency != null && urgency!.isNotEmpty) data['urgency'] = urgency;
    if (confidentiality != null && confidentiality!.isNotEmpty) {
      data['confidentiality'] = confidentiality;
    }
    if (registerId != null && registerId!.isNotEmpty) data['registerId'] = registerId;
    if (workflowId != null && workflowId!.isNotEmpty) data['workflowId'] = workflowId;
    if (personal == true) data['personal'] = true;
    if (pageCount != null) data['pageCount'] = pageCount;
    if (copyCount != null) data['copyCount'] = copyCount;
    if (addressedTo != null && addressedTo!.trim().isNotEmpty) {
      data['addressedTo'] = addressedTo!.trim();
    }
    if (addressedUserId != null && addressedUserId!.isNotEmpty) {
      data['addressedUserId'] = addressedUserId;
    }
    return data;
  }
}

/// Nút tiến trình xử lý (FlowStepper node)
