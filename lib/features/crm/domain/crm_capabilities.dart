import 'common/crm_json.dart';

/// Quyền CRM của người đang đăng nhập (contracts `CrmCapabilities`), chỉ để ẩn hiện; quyền thật kiểm ở API.
class CrmCapabilities {
  /// Quản trị viên tenant: có mọi quyền nghiệp vụ của Bán hàng.
  final bool isTenantAdmin;

  /// `crm.read.all`: thấy toàn bộ dữ liệu, không lọc theo người phụ trách.
  final bool canReadAll;

  /// `crm.opportunity.write`: lead, cơ hội, hoạt động, khách hàng của mình.
  final bool canWriteOpportunity;

  /// `crm.quote.write`: lập báo giá.
  final bool canWriteQuote;

  /// `crm.quote.approve`: duyệt báo giá.
  final bool canApproveQuote;

  /// `crm.order.write`: lập và xác nhận đơn bán.
  final bool canWriteOrder;

  /// `crm.contract.write`: quản lý hợp đồng.
  final bool canWriteContract;

  /// `crm.receivable.write`: thu tiền, điều chỉnh công nợ.
  final bool canWriteReceivable;

  /// `crm.warranty.write`: xử lý bảo hành, đổi trả.
  final bool canWriteWarranty;

  /// `crm.report.read`: xem báo cáo Bán hàng.
  final bool canReadReport;

  /// `crm.document.write`: tải lên, phiên bản mới, khoá, đổi đối tượng xem tài liệu.
  final bool canWriteDocument;

  /// `crm.document.delete`: xoá tài liệu.
  final bool canDeleteDocument;

  /// `crm.quote.cost.read`: xem giá vốn, lợi nhuận của báo giá và phương án kinh doanh.
  final bool canViewQuoteCost;

  /// `crm.manage`: bảng giá, chính sách, nhóm khách, hạn mức, cấu hình.
  final bool canManage;

  const CrmCapabilities({
    this.isTenantAdmin = false,
    this.canReadAll = false,
    this.canWriteOpportunity = false,
    this.canWriteQuote = false,
    this.canApproveQuote = false,
    this.canWriteOrder = false,
    this.canWriteContract = false,
    this.canWriteReceivable = false,
    this.canWriteWarranty = false,
    this.canReadReport = false,
    this.canWriteDocument = false,
    this.canDeleteDocument = false,
    this.canViewQuoteCost = false,
    this.canManage = false,
  });

  /// Không có quyền nào (web `CRM_NO_CAPABILITIES`): mặc định khi chưa tải xong trạng thái.
  static const CrmCapabilities none = CrmCapabilities();

  factory CrmCapabilities.fromJson(Map<String, dynamic> json) {
    bool b(String key) => CrmJson.boolean(json[key]);
    return CrmCapabilities(
      isTenantAdmin: b('isTenantAdmin'),
      canReadAll: b('canReadAll'),
      canWriteOpportunity: b('canWriteOpportunity'),
      canWriteQuote: b('canWriteQuote'),
      canApproveQuote: b('canApproveQuote'),
      canWriteOrder: b('canWriteOrder'),
      canWriteContract: b('canWriteContract'),
      canWriteReceivable: b('canWriteReceivable'),
      canWriteWarranty: b('canWriteWarranty'),
      canReadReport: b('canReadReport'),
      canWriteDocument: b('canWriteDocument'),
      canDeleteDocument: b('canDeleteDocument'),
      canViewQuoteCost: b('canViewQuoteCost'),
      canManage: b('canManage'),
    );
  }

  /// Web `useCanWrite`: được thêm, sửa khách hàng, lead, cơ hội, hoạt động.
  bool get canWrite => isTenantAdmin || canWriteOpportunity;

  /// Quản trị bán hàng (`isTenantAdmin || canManage`) — điều kiện của nhiều nút quản trị trên web.
  bool get isManager => isTenantAdmin || canManage;

  /// Phạm vi toàn bộ dữ liệu (web `crmScopeLabel`).
  bool get seesAllData => isTenantAdmin || canManage || canReadAll;
}

/// `GET /api/crm/v1/status`: mức sẵn sàng của phân hệ và quyền của người gọi.
class CrmStatus {
  final String tenantId;

  /// Người dùng hiện tại (ẩn nút tự duyệt; server vẫn chặn).
  final String userId;
  final bool schemaExists;

  /// Migration nền đã chạy xong; `false` → màn chờ "Dữ liệu CRM của tenant đang được khởi tạo".
  final bool tablesReady;
  final CrmCapabilities capabilities;

  /// Tenant có module Kho đang hoạt động.
  final bool inventoryEntitled;

  /// Người dùng có quyền vào Kho (`inventory.read`).
  final bool canAccessInventory;

  const CrmStatus({
    required this.tenantId,
    required this.userId,
    required this.schemaExists,
    required this.tablesReady,
    required this.capabilities,
    required this.inventoryEntitled,
    required this.canAccessInventory,
  });

  factory CrmStatus.fromJson(Map<String, dynamic> json) => CrmStatus(
        tenantId: CrmJson.str(json['tenantId']),
        userId: CrmJson.str(json['userId']),
        schemaExists: CrmJson.boolean(json['schemaExists']),
        tablesReady: CrmJson.boolean(json['tablesReady']),
        capabilities: CrmCapabilities.fromJson(CrmJson.map(json['capabilities'])),
        // Web `inventoryButtonState`: thiếu cờ hay sai kiểu đều coi là false.
        inventoryEntitled: json['inventoryEntitled'] == true,
        canAccessInventory: json['canAccessInventory'] == true,
      );
}
