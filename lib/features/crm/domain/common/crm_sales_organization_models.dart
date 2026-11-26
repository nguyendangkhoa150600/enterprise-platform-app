import 'crm_json.dart';

/// Thông tin chữ của tổ chức in lên báo giá (contracts `QuoteSeller`); trên phiên bản báo giá là bản sửa riêng.
class CrmQuoteSeller {
  final String name;
  final String? shortName;
  final String address;
  final String taxCode;
  final String phone;
  final String email;
  final String? website;
  final String? bankAccount;
  final String? bankName;
  final String? representative;
  final String? representativeTitle;

  const CrmQuoteSeller({
    required this.name,
    this.shortName,
    this.address = '',
    this.taxCode = '',
    this.phone = '',
    this.email = '',
    this.website,
    this.bankAccount,
    this.bankName,
    this.representative,
    this.representativeTitle,
  });

  factory CrmQuoteSeller.fromJson(Map<String, dynamic> json) => CrmQuoteSeller(
        name: CrmJson.str(json['name']),
        shortName: CrmJson.strOrNull(json['shortName']),
        address: CrmJson.str(json['address']),
        taxCode: CrmJson.str(json['taxCode']),
        phone: CrmJson.str(json['phone']),
        email: CrmJson.str(json['email']),
        website: CrmJson.strOrNull(json['website']),
        bankAccount: CrmJson.strOrNull(json['bankAccount']),
        bankName: CrmJson.strOrNull(json['bankName']),
        representative: CrmJson.strOrNull(json['representative']),
        representativeTitle: CrmJson.strOrNull(json['representativeTitle']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'shortName': shortName,
        'address': address,
        'taxCode': taxCode,
        'phone': phone,
        'email': email,
        'website': website,
        'bankAccount': bankAccount,
        'bankName': bankName,
        'representative': representative,
        'representativeTitle': representativeTitle,
      };
}

/// Tổ chức báo giá (công ty con, pháp nhân bán hàng) — dòng danh sách `GET /sales-organizations` (không có logo).
class CrmSalesOrganizationSummary {
  final String id;
  final String? code;
  final CrmQuoteSeller seller;
  final bool hasLogo;
  final bool isDefault;
  final bool active;
  final int sortOrder;

  /// Đã có phiên bản báo giá dùng: không xoá được, chỉ tắt.
  final bool inUse;
  final String updatedAt;

  const CrmSalesOrganizationSummary({
    required this.id,
    this.code,
    required this.seller,
    this.hasLogo = false,
    this.isDefault = false,
    this.active = true,
    this.sortOrder = 0,
    this.inUse = false,
    this.updatedAt = '',
  });

  String get name => seller.name;

  factory CrmSalesOrganizationSummary.fromJson(Map<String, dynamic> json) => CrmSalesOrganizationSummary(
        id: CrmJson.str(json['id']),
        code: CrmJson.strOrNull(json['code']),
        seller: CrmQuoteSeller.fromJson(json),
        hasLogo: CrmJson.boolean(json['hasLogo']),
        isDefault: CrmJson.boolean(json['isDefault']),
        active: CrmJson.boolean(json['active'], true),
        sortOrder: CrmJson.integer(json['sortOrder']),
        inUse: CrmJson.boolean(json['inUse']),
        updatedAt: CrmJson.str(json['updatedAt']),
      );
}

/// Chi tiết một tổ chức (`GET /sales-organizations/:id`), có logo (data URL PNG/JPEG, tối đa 300 KB).
class CrmSalesOrganization {
  final CrmSalesOrganizationSummary summary;
  final String? logo;

  const CrmSalesOrganization({required this.summary, this.logo});

  String get id => summary.id;

  factory CrmSalesOrganization.fromJson(Map<String, dynamic> json) => CrmSalesOrganization(
        summary: CrmSalesOrganizationSummary.fromJson(json),
        logo: CrmJson.strOrNull(json['logo']),
      );
}
