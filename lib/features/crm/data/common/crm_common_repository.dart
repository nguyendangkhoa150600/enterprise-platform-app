import '../../domain/common/crm_catalog_models.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/common/crm_json.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/common/crm_sales_organization_models.dart';
import '../../domain/crm_capabilities.dart';
import '../crm_api_client.dart';

/// Endpoint CRM dùng chung cho nhiều màn (web `crm-api.ts`: status, danh bạ, nhóm/phân loại khách, danh sách khách,
/// danh mục Kho, kho, tổn kho, tổ chức báo giá). Endpoint riêng của từng khu vực đặt ở `data/<khu_vực>/`.
class CrmCommonRepository {
  CrmCommonRepository._();
  static final CrmCommonRepository instance = CrmCommonRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  /// Số mặt hàng mỗi trang của hộp chọn mặt hàng (web `CATALOG_PAGE_SIZE`).
  static const int catalogPageSize = 20;

  // --- Trạng thái, danh bạ -------------------------------------------------

  /// `GET /status`: 403 khi người dùng chưa có quyền `crm.*` nào.
  Future<CrmStatus> loadStatus() async => CrmStatus.fromJson(CrmJson.map(await _api.get('/status')));

  Future<List<CrmPerson>> listPeople() async => CrmJson.list(await _api.get('/people'), CrmPerson.fromJson);

  Future<List<CrmCustomerGroup>> listGroups() async =>
      CrmJson.list(await _api.get('/customer-groups'), CrmCustomerGroup.fromJson);

  Future<List<CrmCustomerKind>> listKinds() async =>
      CrmJson.list(await _api.get('/customer-kinds'), CrmCustomerKind.fromJson);

  // --- Khách hàng ----------------------------------------------------------

  /// `GET /customers` (danh sách và ô chọn khách: web gọi `{ limit: 100 }` hoặc `{ q, limit: 20 }`).
  Future<CrmPage<CrmCustomerSummary>> listCustomers(CrmCustomerListQuery query) async =>
      CrmPage.fromJson(await _api.get('/customers', query: query.toQuery()), CrmCustomerSummary.fromJson);

  // --- Danh mục Kho --------------------------------------------------------

  /// `GET /catalog/materials`: tìm mặt hàng theo trang (xếp theo mã). [kind] STOCK | SERVICE; [pricedFor] chỉ mặt
  /// hàng có giá bán cho phiên bản báo giá đó.
  Future<CrmCatalogPage> searchCatalog({
    required String search,
    String? cursor,
    String? kind,
    String? tradeCategory,
    ({String quoteId, int versionNo})? pricedFor,
  }) async =>
      CrmCatalogPage.fromJson(await _api.get('/catalog/materials', query: {
        'search': search,
        'limit': catalogPageSize,
        'cursor': cursor,
        'kind': kind,
        'tradeCategory': tradeCategory,
        if (pricedFor != null) 'quoteId': pricedFor.quoteId,
        if (pricedFor != null) 'versionNo': pricedFor.versionNo,
      }));

  /// `GET /catalog/trade-categories`: phân loại đang dùng ở Kho; [kind] thu hẹp theo nhóm.
  Future<List<String>> listCatalogTradeCategories([String? kind]) async =>
      CrmJson.strings(await _api.get('/catalog/trade-categories', query: {'kind': kind}));

  /// `GET /catalog/stock`: tồn khả dụng theo kho của các mặt hàng.
  Future<List<CrmMaterialStock>> loadMaterialStock(List<String> materialIds) async => CrmJson.list(
      await _api.get('/catalog/stock', query: {'materialIds': materialIds.join(',')}), CrmMaterialStock.fromJson);

  Future<List<CrmWarehouseOption>>? _warehouses;

  /// Kho của phân hệ Kho (web `loadWarehouseOptions`), tải một lần trong phiên; lỗi thì bỏ cache để lần sau tải lại.
  /// [codes] (web `loadWarehouses(codes)`): lấy thêm kho đang chọn (kể cả đã ngừng) — gọi thẳng API, không cache.
  Future<List<CrmWarehouseOption>> loadWarehouseOptions({List<String>? codes}) {
    final wanted = codes?.where((c) => c.isNotEmpty).toList() ?? const <String>[];
    if (wanted.isNotEmpty) {
      return _api
          .get('/catalog/warehouses', query: {'codes': wanted.join(',')})
          .then((raw) => CrmJson.list(raw, CrmWarehouseOption.fromJson));
    }
    final cached = _warehouses;
    if (cached != null) return cached;
    final next = _api.get('/catalog/warehouses').then((raw) => CrmJson.list(raw, CrmWarehouseOption.fromJson));
    _warehouses = next;
    next.catchError((Object _) {
      if (identical(_warehouses, next)) _warehouses = null;
      return const <CrmWarehouseOption>[];
    });
    return next;
  }

  // --- Tổ chức báo giá -----------------------------------------------------

  Future<List<CrmSalesOrganizationSummary>>? _activeOrgs;
  final Map<String, Future<CrmSalesOrganization>> _orgDetails = {};

  /// `GET /sales-organizations` (không có logo); [includeInactive] chỉ có hiệu lực với `crm.manage`.
  Future<List<CrmSalesOrganizationSummary>> listSalesOrganizations({bool includeInactive = false}) async =>
      CrmJson.list(
        await _api.get('/sales-organizations', query: {'includeInactive': includeInactive ? 'true' : null}),
        CrmSalesOrganizationSummary.fromJson,
      );

  /// Tổ chức đang bật, giữ trong phiên (web `loadActiveSalesOrganizations`).
  Future<List<CrmSalesOrganizationSummary>> loadActiveSalesOrganizations() {
    final cached = _activeOrgs;
    if (cached != null) return cached;
    final next = listSalesOrganizations().then((rows) => rows.where((row) => row.active).toList());
    _activeOrgs = next;
    next.catchError((Object _) {
      if (identical(_activeOrgs, next)) _activeOrgs = null;
      return const <CrmSalesOrganizationSummary>[];
    });
    return next;
  }

  /// Chi tiết một tổ chức (có logo), mỗi id gọi API một lần trong phiên (web `loadSalesOrganization`).
  Future<CrmSalesOrganization> loadSalesOrganization(String id) {
    final cached = _orgDetails[id];
    if (cached != null) return cached;
    final next = _api
        .get('/sales-organizations/${CrmApiClient.seg(id)}')
        .then((raw) => CrmSalesOrganization.fromJson(CrmJson.map(raw)));
    _orgDetails[id] = next;
    next.catchError((Object _) {
      if (identical(_orgDetails[id], next)) _orgDetails.remove(id);
      return CrmSalesOrganization(summary: CrmSalesOrganizationSummary(id: id, seller: const CrmQuoteSeller(name: '')));
    });
    return next;
  }

  /// Xoá mọi cache (đăng xuất / đổi tổ chức).
  void clearCaches() {
    _warehouses = null;
    _activeOrgs = null;
    _orgDetails.clear();
  }
}
