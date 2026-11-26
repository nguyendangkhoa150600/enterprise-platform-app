import '../../domain/common/crm_json.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/common/crm_sales_organization_models.dart';
import '../../domain/quotes/crm_quote_layout_models.dart';
import '../../domain/quotes/crm_quote_models.dart';
import '../../domain/quotes/crm_quote_support_models.dart';
import '../crm_api_client.dart';

/// Endpoint báo giá, bảng giá (phần báo giá dùng), PAKD, khuyến mãi, tài liệu tham chiếu, mẫu in (web `crm-api.ts`).
class CrmQuotesRepository {
  CrmQuotesRepository._();
  static final CrmQuotesRepository instance = CrmQuotesRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  static String _quote(String id, [int? versionNo]) =>
      '/quotes/${CrmApiClient.seg(id)}${versionNo == null ? '' : '/versions/$versionNo'}';

  CrmQuoteDetail _detail(Object? raw) => CrmQuoteDetail.fromJson(CrmJson.map(raw));

  // --- Báo giá ------------------------------------------------------------------------------------------------------

  Future<CrmPage<CrmQuoteSummary>> listQuotes(CrmQuoteListQuery query) async =>
      CrmPage.fromJson(await _api.get('/quotes', query: query.toQuery()), CrmQuoteSummary.fromJson);

  Future<CrmQuoteDetail> getQuote(String id, [int? versionNo]) async =>
      _detail(await _api.get(_quote(id), query: {'version': versionNo}));

  Future<CrmQuoteDetail> createQuote(Map<String, dynamic> body) async => _detail(await _api.post('/quotes', body));

  Future<CrmQuoteDetail> updateVersion(String id, int versionNo, Map<String, dynamic> body) async =>
      _detail(await _api.patch(_quote(id, versionNo), body));

  Future<CrmQuoteDetail> addLines(String id, int versionNo, Map<String, dynamic> body) async =>
      _detail(await _api.post('${_quote(id, versionNo)}/lines/batch', body));

  Future<CrmQuoteDetail> updateLine(String id, int versionNo, String lineId, Map<String, dynamic> body) async =>
      _detail(await _api.patch('${_quote(id, versionNo)}/lines/${CrmApiClient.seg(lineId)}', body));

  Future<CrmQuoteDetail> removeLine(String id, int versionNo, String lineId, int revision) async => _detail(
      await _api.delete('${_quote(id, versionNo)}/lines/${CrmApiClient.seg(lineId)}?revision=$revision'));

  Future<void> deleteQuote(String id) => _api.delete(_quote(id));

  /// `action`: recalculate | revise | submit | approve | reject | send | accept | decline.
  Future<CrmQuoteDetail> action(String id, int versionNo, String action, {required int revision, String? reason}) async =>
      _detail(await _api.post('${_quote(id, versionNo)}/$action', {'revision': revision, 'reason': ?reason}));

  Future<CrmQuoteComparison> compare(String id, int from, int to) async =>
      CrmQuoteComparison.fromJson(CrmJson.map(await _api.get('${_quote(id)}/compare', query: {'from': from, 'to': to})));

  Future<CrmConvertQuoteResult> convert(String id) async =>
      CrmConvertQuoteResult.fromJson(CrmJson.map(await _api.post('${_quote(id)}/convert')));

  Future<String> generateCode() async => CrmJson.str(CrmJson.map(await _api.post('/quotes/code/generate'))['code']);

  /// Cột hiện ở hộp thêm dòng (`GET /quote-line-picker-settings`).
  Future<List<String>> loadLinePickerColumns() async =>
      CrmJson.strings(CrmJson.map(await _api.get('/quote-line-picker-settings'))['columns']);

  Future<List<CrmQuoteTask>> loadAwaitingMe() async =>
      CrmJson.list(CrmJson.map(await _api.get('/my-tasks'))['awaitingMe'], CrmQuoteTask.fromJson);

  // --- Mẫu, loại, trường tuỳ biến, bố cục in -------------------------------------------------------------------------

  Future<List<CrmQuoteTemplate>> listTemplates() async =>
      CrmJson.list(await _api.get('/quote-templates'), CrmQuoteTemplate.fromJson);

  Future<List<CrmQuoteType>> listTypes() async => CrmJson.list(await _api.get('/quote-types'), CrmQuoteType.fromJson);

  Future<List<CrmCustomFieldDefinition>> listCustomFields() async =>
      CrmJson.list(await _api.get('/custom-fields', query: {'entityType': 'quote'}), CrmCustomFieldDefinition.fromJson);

  /// Bố cục của mẫu; null là mẫu dùng bố cục mặc định.
  Future<CrmQuoteLayout?> getTemplateLayout(String templateId) async {
    final layout = CrmJson.map(await _api.get('/quote-templates/${CrmApiClient.seg(templateId)}/layout'))['layout'];
    return layout is Map ? CrmQuoteLayout.fromJson(CrmJson.map(layout)) : null;
  }

  // --- Người theo dõi, đối tượng liên quan -------------------------------------------------------------------------

  Future<List<CrmQuoteFollower>> listFollowers(String id) async =>
      CrmJson.list(await _api.get('${_quote(id)}/followers'), CrmQuoteFollower.fromJson);
  Future<void> addFollower(String id, String userId) => _api.post('${_quote(id)}/followers', {'userId': userId});
  Future<void> removeFollower(String id, String userId) =>
      _api.delete('${_quote(id)}/followers/${CrmApiClient.seg(userId)}');

  Future<List<CrmQuoteLink>> listLinks(String id) async =>
      CrmJson.list(await _api.get('${_quote(id)}/links'), CrmQuoteLink.fromJson);
  Future<void> addLink(String id, String targetType, String targetId) =>
      _api.post('${_quote(id)}/links', {'targetType': targetType, 'targetId': targetId});
  Future<void> removeLink(String id, String linkId) => _api.delete('${_quote(id)}/links/${CrmApiClient.seg(linkId)}');

  /// Lựa chọn đối tượng liên quan theo loại (web `loadTargets`, mỗi loại 100 dòng đầu).
  Future<List<CrmQuoteLinkTarget>> loadLinkTargets(String type) async {
    List<Map<String, dynamic>> items(Object? raw) => CrmJson.maps(CrmJson.map(raw)['items']);
    switch (type) {
      case 'CUSTOMER':
        return items(await _api.get('/customers', query: {'limit': 100}))
            .map((e) => CrmQuoteLinkTarget(id: CrmJson.str(e['id']), label: CrmJson.str(e['name']), badge: CrmJson.strOrNull(e['code'])))
            .toList();
      case 'OPPORTUNITY':
        return items(await _api.get('/opportunities', query: {'limit': 100}))
            .map((e) => CrmQuoteLinkTarget(
                id: CrmJson.str(e['id']), label: CrmJson.str(e['name']), description: CrmJson.strOrNull(e['customerName'])))
            .toList();
      case 'CONTRACT':
        return items(await _api.get('/contracts', query: {'limit': 100}))
            .map((e) => CrmQuoteLinkTarget(
                id: CrmJson.str(e['id']),
                label: CrmJson.str(e['title']),
                badge: CrmJson.strOrNull(e['code']),
                description: CrmJson.strOrNull(e['customerName'])))
            .toList();
      case 'SALES_ORDER':
        return items(await _api.get('/orders', query: {'limit': 100}))
            .map((e) => CrmQuoteLinkTarget(
                id: CrmJson.str(e['id']), label: CrmJson.str(e['code']), description: CrmJson.strOrNull(e['customerName'])))
            .toList();
      case 'QUOTE':
        return items(await _api.get('/quotes', query: {'limit': 100})).map((e) {
          final name = CrmJson.strOrNull(e['quoteName']);
          return CrmQuoteLinkTarget(
              id: CrmJson.str(e['id']),
              label: (name == null || name.isEmpty) ? CrmJson.str(e['code']) : name,
              badge: CrmJson.strOrNull(e['code']),
              description: CrmJson.strOrNull(e['customerName']));
        }).toList();
    }
    return const [];
  }

  // --- Khách, dự án (màn lập mới, dữ liệu in) -----------------------------------------------------------------------

  Future<CrmQuoteCustomerInfo> getCustomer(String id) async =>
      CrmQuoteCustomerInfo.fromJson(CrmJson.map(await _api.get('/customers/${CrmApiClient.seg(id)}')));

  Future<List<CrmQuoteCustomerInfo>> listCustomers() async =>
      CrmJson.list(CrmJson.map(await _api.get('/customers', query: {'limit': 100}))['items'], CrmQuoteCustomerInfo.fromJson);

  Future<List<CrmQuoteOpportunityOption>> listOpenOpportunities() async => CrmJson.list(
          CrmJson.map(await _api.get('/opportunities', query: {'limit': 100}))['items'], CrmQuoteOpportunityOption.fromJson)
      .where((o) => o.stage != 'WON' && o.stage != 'LOST')
      .toList();

  Future<CrmQuoteOpportunityOption> getOpportunity(String id) async =>
      CrmQuoteOpportunityOption.fromJson(CrmJson.map(await _api.get('/opportunities/${CrmApiClient.seg(id)}')));

  // --- Bảng giá ------------------------------------------------------------------------------------------------------

  Future<List<CrmPriceListSummary>> listPriceLists() async =>
      CrmJson.list(await _api.get('/price-lists'), CrmPriceListSummary.fromJson);

  Future<CrmPriceListSyncStatus> loadCatalogSyncStatus() async =>
      CrmPriceListSyncStatus.fromJson(CrmJson.map(await _api.get('/pricing/catalog-sync')));

  Future<CrmPriceListSyncResult> syncCatalog() async =>
      CrmPriceListSyncResult.fromJson(CrmJson.map(await _api.post('/pricing/catalog-sync')));

  // --- Tổ chức báo giá ---------------------------------------------------------------------------------------------

  Future<CrmSalesOrganization> createSalesOrganization(Map<String, dynamic> body) async =>
      CrmSalesOrganization.fromJson(CrmJson.map(await _api.post('/sales-organizations', body)));

  // --- PAKD ----------------------------------------------------------------------------------------------------------

  String _plan(String id, int versionNo) => '${_quote(id, versionNo)}/business-plan';

  Future<CrmBusinessPlan?> getBusinessPlan(String id, int versionNo) async {
    final raw = await _api.get(_plan(id, versionNo));
    return raw is Map ? CrmBusinessPlan.fromJson(CrmJson.map(raw)) : null;
  }

  Future<CrmBusinessPlan> saveBusinessPlan(String id, int versionNo, Map<String, dynamic> body) async =>
      CrmBusinessPlan.fromJson(CrmJson.map(await _api.put(_plan(id, versionNo), body)));

  /// `action`: submit | approve | reject.
  Future<CrmBusinessPlan> businessPlanAction(String id, int versionNo, String action,
          {required int version, String? reason}) async =>
      CrmBusinessPlan.fromJson(CrmJson.map(
          await _api.post('${_plan(id, versionNo)}/$action', {'version': version, 'reason': ?reason})));

  // --- Khuyến mãi ----------------------------------------------------------------------------------------------------

  Future<List<CrmOpportunityPromotion>> listOpportunityPromotions(String opportunityId) async => CrmJson.list(
      await _api.get('/opportunities/${CrmApiClient.seg(opportunityId)}/promotions'), CrmOpportunityPromotion.fromJson);

  Future<void> saveQuotePromotions(String id, int versionNo, List<String> catalogIds, int revision) =>
      _api.put('${_quote(id, versionNo)}/promotions', {'catalogIds': catalogIds, 'revision': revision});

  // --- Tài liệu có sẵn ---------------------------------------------------------------------------------------------

  Future<List<CrmQuoteDocumentItem>> listDocumentCandidates(String id, {String? sourceType, String? search}) async =>
      CrmJson.list(await _api.get('${_quote(id)}/document-candidates', query: {'sourceType': sourceType, 'search': search}),
          CrmQuoteDocumentItem.fromJson);

  Future<List<CrmQuoteDocumentItem>> listDocumentReferences(String id) async =>
      CrmJson.list(await _api.get('${_quote(id)}/document-references'), CrmQuoteDocumentItem.fromJson);

  Future<List<CrmQuoteDocumentItem>> addDocumentReference(String id, String documentId) async => CrmJson.list(
      await _api.post('${_quote(id)}/document-references', {'documentId': documentId}), CrmQuoteDocumentItem.fromJson);

  Future<List<CrmQuoteDocumentItem>> removeDocumentReference(String id, String referenceId) async => CrmJson.list(
      await _api.delete('${_quote(id)}/document-references/${CrmApiClient.seg(referenceId)}'),
      CrmQuoteDocumentItem.fromJson);

  /// URL tải xuống ký sẵn.
  Future<String> documentReferenceDownloadUrl(String id, String referenceId) async => CrmJson.str(CrmJson.map(
      await _api.get('${_quote(id)}/document-references/${CrmApiClient.seg(referenceId)}/download'))['downloadUrl']);
}
