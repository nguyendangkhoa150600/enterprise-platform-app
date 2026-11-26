import '../common/crm_directory_models.dart';
import '../common/crm_json.dart';

/// Người liên hệ của khách (contracts `CustomerContact`).
class CrmCustomerContact {
  final String id;
  final String customerId;
  final String fullName;
  final String? title;
  final String? phone;
  final String? email;
  final String? note;
  final bool isPrimary;

  const CrmCustomerContact({
    required this.id,
    required this.customerId,
    required this.fullName,
    this.title,
    this.phone,
    this.email,
    this.note,
    this.isPrimary = false,
  });

  factory CrmCustomerContact.fromJson(Map<String, dynamic> json) => CrmCustomerContact(
        id: CrmJson.str(json['id']),
        customerId: CrmJson.str(json['customerId']),
        fullName: CrmJson.str(json['fullName']),
        title: CrmJson.strOrNull(json['title']),
        phone: CrmJson.strOrNull(json['phone']),
        email: CrmJson.strOrNull(json['email']),
        note: CrmJson.strOrNull(json['note']),
        isPrimary: CrmJson.boolean(json['isPrimary']),
      );
}

/// Hồ sơ khách hàng (contracts `CustomerDetail`).
class CrmCustomerDetail {
  final CrmCustomerSummary summary;
  final String? address;
  final String? industry;
  final String? phone;
  final String? email;
  final double? creditLimit;
  final int? paymentTermDays;
  final String? note;

  /// Chân dung khách hàng (P2F-03); null là chưa ghi.
  final String? profileNote;
  final int version;
  final String createdAt;
  final List<CrmCustomerContact> contacts;

  const CrmCustomerDetail({
    required this.summary,
    this.address,
    this.industry,
    this.phone,
    this.email,
    this.creditLimit,
    this.paymentTermDays,
    this.note,
    this.profileNote,
    this.version = 0,
    this.createdAt = '',
    this.contacts = const [],
  });

  String get id => summary.id;
  String get code => summary.code;
  String get name => summary.name;
  String? get taxCode => summary.taxCode;
  String get kind => summary.kind;
  String get kindName => summary.kindName;
  String? get groupId => summary.groupId;
  String? get groupName => summary.groupName;
  String get ownerUserId => summary.ownerUserId;
  String? get province => summary.province;
  String? get region => summary.region;

  factory CrmCustomerDetail.fromJson(Map<String, dynamic> json) => CrmCustomerDetail(
        summary: CrmCustomerSummary.fromJson(json),
        address: CrmJson.strOrNull(json['address']),
        industry: CrmJson.strOrNull(json['industry']),
        phone: CrmJson.strOrNull(json['phone']),
        email: CrmJson.strOrNull(json['email']),
        creditLimit: CrmJson.numOrNull(json['creditLimit']),
        paymentTermDays: CrmJson.intOrNull(json['paymentTermDays']),
        note: CrmJson.strOrNull(json['note']),
        profileNote: CrmJson.strOrNull(json['profileNote']),
        version: CrmJson.integer(json['version']),
        createdAt: CrmJson.str(json['createdAt']),
        contacts: CrmJson.list(json['contacts'], CrmCustomerContact.fromJson),
      );
}

/// Khách đã có cùng MST (contracts `TaxCodeMatch`).
class CrmTaxCodeMatch {
  final String id;
  final String code;
  final String name;
  const CrmTaxCodeMatch({required this.id, required this.code, required this.name});

  factory CrmTaxCodeMatch.fromJson(Map<String, dynamic> json) => CrmTaxCodeMatch(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
      );
}

/// Dự án bán hàng của khách (phần dùng ở tab "Dự án bán hàng", contracts `OpportunitySummary`).
class CrmCustomerOpportunity {
  final String id;
  final String name;
  final String stageName;

  /// Nghĩa giai đoạn: OPEN | WON | LOST.
  final String stageSemantic;
  final double? expectedValue;
  final String ownerUserId;

  const CrmCustomerOpportunity({
    required this.id,
    required this.name,
    required this.stageName,
    required this.stageSemantic,
    this.expectedValue,
    this.ownerUserId = '',
  });

  factory CrmCustomerOpportunity.fromJson(Map<String, dynamic> json) {
    final stage = CrmJson.map(json['stageInfo']);
    return CrmCustomerOpportunity(
      id: CrmJson.str(json['id']),
      name: CrmJson.str(json['name']),
      stageName: CrmJson.str(stage['name'], CrmJson.str(json['stage'])),
      stageSemantic: CrmJson.str(stage['semantic']),
      expectedValue: CrmJson.numOrNull(json['expectedValue']),
      ownerUserId: CrmJson.str(json['ownerUserId']),
    );
  }
}

/// Mục dòng thời gian khách hàng (contracts `CustomerTimelineEntry`, union theo [kind]). Giữ JSON thô [raw] để
/// đọc trường riêng của từng loại; loại lạ hiện nhãn chung.
class CrmTimelineEntry {
  final String kind;
  final String id;
  final String at;
  final String? actorId;
  final Map<String, dynamic> raw;

  const CrmTimelineEntry({required this.kind, required this.id, required this.at, this.actorId, this.raw = const {}});

  String str(String key) => CrmJson.str(raw[key]);
  String? strOrNull(String key) {
    final value = CrmJson.strOrNull(raw[key]);
    return value == null || value.isEmpty ? null : value;
  }

  factory CrmTimelineEntry.fromJson(Map<String, dynamic> json) => CrmTimelineEntry(
        kind: CrmJson.str(json['kind']),
        id: CrmJson.str(json['id']),
        at: CrmJson.str(json['at']),
        actorId: CrmJson.strOrNull(json['actorId']),
        raw: json,
      );
}

/// Độ dài tối đa của chân dung khách hàng (contracts `CUSTOMER_PROFILE_NOTE_MAX`).
const int kCrmCustomerProfileNoteMax = 4000;

/// Mã lỗi khi MST trùng và chưa xác nhận (contracts `CRM_DUPLICATE_TAX_CODE`); thân lỗi có `matches`.
const String kCrmDuplicateTaxCode = 'DUPLICATE_TAX_CODE';

/// Web `taxCodeLooksValid`: rỗng hoặc 10 số hoặc 10 số-3 số.
bool crmTaxCodeLooksValid(String value) {
  final text = value.trim();
  return text.isEmpty || RegExp(r'^\d{10}(-\d{3})?$').hasMatch(text);
}

String _stripTones(String value) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final ch = String.fromCharCode(rune);
    final lower = ch.toLowerCase();
    var mapped = ch;
    for (final entry in groups.entries) {
      if (entry.value.contains(lower)) {
        mapped = ch == lower ? entry.key : entry.key.toUpperCase();
        break;
      }
    }
    buffer.write(mapped);
  }
  return buffer.toString();
}

/// Web `normalizeGroupName`: bỏ dấu, bỏ khác biệt hoa thường và khoảng trắng thừa.
String crmNormalizeGroupName(String name) =>
    _stripTones(name).trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Web `groupCodeFromName`: "Đại lý cấp 1" → "DAI-LY-CAP-1" (A-Z 0-9 và `-`, tối đa 50 ký tự).
String crmGroupCodeFromName(String name) {
  var code = _stripTones(name)
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (code.length > 50) code = code.substring(0, 50);
  return code.replaceAll(RegExp(r'-+$'), '');
}
