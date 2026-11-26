import '../common/crm_json.dart';

/// Trạng thái lead (contracts `LEAD_STATUSES`).
class CrmLeadStatus {
  CrmLeadStatus._();
  static const String newLead = 'NEW';
  static const String working = 'WORKING';
  static const String disqualified = 'DISQUALIFIED';
  static const String converted = 'CONVERTED';

  static const List<String> all = [newLead, working, disqualified, converted];

  /// Trạng thái được đặt khi sửa (CONVERTED chỉ qua thao tác chuyển đổi).
  static const List<String> editable = [newLead, working, disqualified];
}

/// Lead (contracts `Lead`).
class CrmLead {
  final String id;
  final String name;
  final String? contactName;
  final String? taxCode;
  final String? phone;
  final String? email;
  final String? source;
  final String? need;
  final String? note;
  final String ownerUserId;
  final String status;
  final String? convertedCustomerId;
  final String? convertedOpportunityId;
  final String? convertedAt;
  final int version;
  final String createdAt;
  final String updatedAt;

  const CrmLead({
    required this.id,
    required this.name,
    this.contactName,
    this.taxCode,
    this.phone,
    this.email,
    this.source,
    this.need,
    this.note,
    this.ownerUserId = '',
    this.status = CrmLeadStatus.newLead,
    this.convertedCustomerId,
    this.convertedOpportunityId,
    this.convertedAt,
    this.version = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory CrmLead.fromJson(Map<String, dynamic> json) => CrmLead(
        id: CrmJson.str(json['id']),
        name: CrmJson.str(json['name']),
        contactName: CrmJson.strOrNull(json['contactName']),
        taxCode: CrmJson.strOrNull(json['taxCode']),
        phone: CrmJson.strOrNull(json['phone']),
        email: CrmJson.strOrNull(json['email']),
        source: CrmJson.strOrNull(json['source']),
        need: CrmJson.strOrNull(json['need']),
        note: CrmJson.strOrNull(json['note']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        status: CrmJson.str(json['status'], CrmLeadStatus.newLead),
        convertedCustomerId: CrmJson.strOrNull(json['convertedCustomerId']),
        convertedOpportunityId: CrmJson.strOrNull(json['convertedOpportunityId']),
        convertedAt: CrmJson.strOrNull(json['convertedAt']),
        version: CrmJson.integer(json['version']),
        createdAt: CrmJson.str(json['createdAt']),
        updatedAt: CrmJson.str(json['updatedAt']),
      );
}

/// Kết quả "Chuyển thành khách hàng và dự án bán hàng" (contracts `ConvertLeadResult`).
class CrmConvertLeadResult {
  final String leadId;
  final String customerId;
  final String opportunityId;

  /// Lead khớp MST khách đã có nên gắn vào khách cũ.
  final bool attachedToExistingCustomer;

  const CrmConvertLeadResult({
    required this.leadId,
    required this.customerId,
    required this.opportunityId,
    this.attachedToExistingCustomer = false,
  });

  factory CrmConvertLeadResult.fromJson(Map<String, dynamic> json) => CrmConvertLeadResult(
        leadId: CrmJson.str(json['leadId']),
        customerId: CrmJson.str(json['customerId']),
        opportunityId: CrmJson.str(json['opportunityId']),
        attachedToExistingCustomer: CrmJson.boolean(json['attachedToExistingCustomer']),
      );
}
