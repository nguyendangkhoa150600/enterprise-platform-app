import 'crm_json.dart';

/// Người trong tổ chức (`GET /people`), để chọn người phụ trách, người được giao.
class CrmPerson {
  final String userId;
  final String displayName;

  const CrmPerson({required this.userId, required this.displayName});

  factory CrmPerson.fromJson(Map<String, dynamic> json) =>
      CrmPerson(userId: CrmJson.str(json['userId']), displayName: CrmJson.str(json['displayName']));
}

/// Nhóm khách (`GET /customer-groups`).
class CrmCustomerGroup {
  final String id;
  final String code;
  final String name;
  final String? description;

  /// Số khách đang thuộc nhóm.
  final int customerCount;

  const CrmCustomerGroup({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.customerCount = 0,
  });

  factory CrmCustomerGroup.fromJson(Map<String, dynamic> json) => CrmCustomerGroup(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        description: CrmJson.strOrNull(json['description']),
        customerCount: CrmJson.integer(json['customerCount']),
      );
}

/// Phân loại khách (`GET /customer-kinds`); giá trị là mã phân loại.
class CrmCustomerKind {
  final String code;
  final String name;
  final String? description;

  /// Phân loại hệ thống (LEAD_CUSTOMER, CUSTOMER, INACTIVE): không xoá, không đổi mã.
  final bool isSystem;
  final int sortOrder;
  final int customerCount;

  const CrmCustomerKind({
    required this.code,
    required this.name,
    this.description,
    this.isSystem = false,
    this.sortOrder = 0,
    this.customerCount = 0,
  });

  /// Ba mã phân loại hệ thống (contracts `SYSTEM_CUSTOMER_KINDS`).
  static const List<String> systemKinds = ['LEAD_CUSTOMER', 'CUSTOMER', 'INACTIVE'];

  /// Phân loại của khách mới khi không chọn, và của khách tạo từ lead.
  static const String defaultKind = 'LEAD_CUSTOMER';

  factory CrmCustomerKind.fromJson(Map<String, dynamic> json) => CrmCustomerKind(
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        description: CrmJson.strOrNull(json['description']),
        isSystem: CrmJson.boolean(json['isSystem']),
        sortOrder: CrmJson.integer(json['sortOrder']),
        customerCount: CrmJson.integer(json['customerCount']),
      );
}

/// Dòng danh sách khách hàng (contracts `CustomerSummary`) — dùng cho danh sách và ô chọn khách ở nhiều màn.
class CrmCustomerSummary {
  final String id;
  final String code;
  final String name;
  final String? taxCode;
  final String? province;
  final String? region;
  final String kind;

  /// Tên phân loại để hiển thị.
  final String kindName;
  final String? groupId;
  final String? groupName;
  final String ownerUserId;
  final String? primaryContactName;
  final String updatedAt;

  const CrmCustomerSummary({
    required this.id,
    required this.code,
    required this.name,
    this.taxCode,
    this.province,
    this.region,
    this.kind = '',
    this.kindName = '',
    this.groupId,
    this.groupName,
    this.ownerUserId = '',
    this.primaryContactName,
    this.updatedAt = '',
  });

  factory CrmCustomerSummary.fromJson(Map<String, dynamic> json) => CrmCustomerSummary(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        taxCode: CrmJson.strOrNull(json['taxCode']),
        province: CrmJson.strOrNull(json['province']),
        region: CrmJson.strOrNull(json['region']),
        kind: CrmJson.str(json['kind']),
        kindName: CrmJson.str(json['kindName']),
        groupId: CrmJson.strOrNull(json['groupId']),
        groupName: CrmJson.strOrNull(json['groupName']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        primaryContactName: CrmJson.strOrNull(json['primaryContactName']),
        updatedAt: CrmJson.str(json['updatedAt']),
      );
}

/// Bộ lọc `GET /customers` (contracts `CustomerListQuery`). [toQuery] bỏ giá trị rỗng như web `toQuery`.
class CrmCustomerListQuery {
  final String? q;
  final String? groupId;
  final String? kind;
  final String? ownerUserId;
  final String? cursor;

  /// Trang (từ 1) thay cho `cursor`: server trả kèm `page` và `total`.
  final int? page;
  final int? limit;

  const CrmCustomerListQuery({this.q, this.groupId, this.kind, this.ownerUserId, this.cursor, this.page, this.limit});

  Map<String, dynamic> toQuery() => {
        'q': q,
        'groupId': groupId,
        'kind': kind,
        'ownerUserId': ownerUserId,
        'cursor': cursor,
        'page': page,
        'limit': limit,
      };
}
