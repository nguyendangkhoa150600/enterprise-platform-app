import '../../domain/common/crm_directory_models.dart';
import '../../domain/common/crm_json.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/customers/crm_customer_models.dart';
import '../crm_api_client.dart';

/// Endpoint khách hàng, người liên hệ, dòng thời gian, tạo nhanh nhóm/phân loại (web `crm-api.ts` phần Khách hàng).
/// Danh sách khách dùng chung ở `CrmCommonRepository.listCustomers`.
class CrmCustomersRepository {
  CrmCustomersRepository._();
  static final CrmCustomersRepository instance = CrmCustomersRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  String _path(String id) => '/customers/${CrmApiClient.seg(id)}';

  CrmCustomerDetail _detail(Object? raw) => CrmCustomerDetail.fromJson(CrmJson.map(raw));

  /// `GET /customers/:id`.
  Future<CrmCustomerDetail> getCustomer(String id) async => _detail(await _api.get(_path(id)));

  /// `GET /customers/tax-code-matches?taxCode&excludeId`.
  Future<List<CrmTaxCodeMatch>> findTaxCodeMatches(String taxCode, {String? excludeId}) async => CrmJson.list(
      await _api.get('/customers/tax-code-matches', query: {'taxCode': taxCode, 'excludeId': excludeId}),
      CrmTaxCodeMatch.fromJson);

  /// `POST /customers` (contracts `CreateCustomerRequest`).
  Future<CrmCustomerDetail> createCustomer(Map<String, dynamic> body) async =>
      _detail(await _api.post('/customers', body));

  /// `PATCH /customers/:id` (contracts `UpdateCustomerRequest`, có `code` và `version`).
  Future<CrmCustomerDetail> updateCustomer(String id, Map<String, dynamic> body) async =>
      _detail(await _api.patch(_path(id), body));

  /// `PUT /customers/:id/profile`: lưu chân dung khách hàng.
  Future<CrmCustomerDetail> saveProfile(String id, {required String? profileNote, required int version}) async =>
      _detail(await _api.put('${_path(id)}/profile', {'profileNote': profileNote, 'version': version}));

  /// `POST /customers/:id/contacts`.
  Future<CrmCustomerDetail> addContact(String customerId, Map<String, dynamic> body) async =>
      _detail(await _api.post('${_path(customerId)}/contacts', body));

  /// `PATCH /customers/:id/contacts/:contactId`.
  Future<CrmCustomerDetail> updateContact(String customerId, String contactId, Map<String, dynamic> body) async =>
      _detail(await _api.patch('${_path(customerId)}/contacts/${CrmApiClient.seg(contactId)}', body));

  /// `POST /customers/:id/contacts/:contactId/primary`.
  Future<CrmCustomerDetail> setPrimaryContact(String customerId, String contactId) async =>
      _detail(await _api.post('${_path(customerId)}/contacts/${CrmApiClient.seg(contactId)}/primary'));

  /// `DELETE /customers/:id/contacts/:contactId`.
  Future<CrmCustomerDetail> deleteContact(String customerId, String contactId) async =>
      _detail(await _api.delete('${_path(customerId)}/contacts/${CrmApiClient.seg(contactId)}'));

  /// `GET /customers/:id/timeline?cursor&limit=15`.
  Future<CrmPage<CrmTimelineEntry>> loadTimeline(String customerId, {String? cursor}) async => CrmPage.fromJson(
      await _api.get('${_path(customerId)}/timeline', query: {'cursor': cursor, 'limit': kCrmListPageSize}),
      CrmTimelineEntry.fromJson);

  /// `GET /opportunities?customerId&page&limit` (tab "Dự án bán hàng").
  Future<CrmPage<CrmCustomerOpportunity>> listOpportunities(String customerId, int page) async => CrmPage.fromJson(
      await _api.get('/opportunities', query: {'customerId': customerId, 'page': page, 'limit': kCrmListPageSize}),
      CrmCustomerOpportunity.fromJson);

  /// `POST /customer-groups` (tạo nhanh trong form khách).
  Future<CrmCustomerGroup> createGroup({required String code, required String name}) async => CrmCustomerGroup.fromJson(
      CrmJson.map(await _api.post('/customer-groups', {'code': code, 'name': name, 'description': null})));

  /// `POST /customer-kinds` (tạo nhanh trong form khách).
  Future<CrmCustomerKind> createKind({required String code, required String name}) async => CrmCustomerKind.fromJson(
      CrmJson.map(await _api.post('/customer-kinds', {'code': code, 'name': name, 'description': null})));
}
