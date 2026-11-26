import '../../domain/common/crm_json.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/contracts/crm_contract_models.dart';
import '../crm_api_client.dart';

/// Endpoint hợp đồng (web `crm-api.ts`: listContracts, getContract, createContract, updateContract,
/// savePaymentTerms, contractAction, triggerPaymentTerm).
class ContractsRepository {
  ContractsRepository._();
  static final ContractsRepository instance = ContractsRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  static String _path(String id) => '/contracts/${CrmApiClient.seg(id)}';

  /// `GET /contracts`.
  Future<CrmPage<CrmContractSummary>> listContracts(CrmContractListQuery query) async =>
      CrmPage.fromJson(await _api.get('/contracts', query: query.toQuery()), CrmContractSummary.fromJson);

  /// `GET /contracts/:id`.
  Future<CrmContractDetail> getContract(String id) async =>
      CrmContractDetail.fromJson(CrmJson.map(await _api.get(_path(id))));

  /// `POST /contracts` (contracts `SaveContractRequest`).
  Future<CrmContractDetail> createContract(Map<String, dynamic> body) async =>
      CrmContractDetail.fromJson(CrmJson.map(await _api.post('/contracts', body)));

  /// `PATCH /contracts/:id` (phần đầu và/hoặc `lines` thay toàn bộ dòng; kèm `revision`).
  Future<CrmContractDetail> updateContract(String id, Map<String, dynamic> body) async =>
      CrmContractDetail.fromJson(CrmJson.map(await _api.patch(_path(id), body)));

  /// `PUT /contracts/:id/payment-terms` `{ revision, terms }`.
  Future<CrmContractDetail> savePaymentTerms(String id, int revision, List<Map<String, dynamic>> terms) async =>
      CrmContractDetail.fromJson(
          CrmJson.map(await _api.put('${_path(id)}/payment-terms', {'revision': revision, 'terms': terms})));

  /// `POST /contracts/:id/{confirm|cancel|complete|liquidate}` `{ revision, reason }`.
  Future<CrmContractDetail> contractAction(String id, String action, int revision, {String? reason}) async =>
      CrmContractDetail.fromJson(
          CrmJson.map(await _api.post('${_path(id)}/$action', {'revision': revision, 'reason': reason})));

  /// `POST /contracts/:id/payment-terms/:termId/trigger` `{ date }` (rỗng là hôm nay).
  Future<void> triggerPaymentTerm(String id, String termId, String? date) async {
    await _api.post('${_path(id)}/payment-terms/${CrmApiClient.seg(termId)}/trigger',
        {'date': (date == null || date.isEmpty) ? null : date});
  }
}
