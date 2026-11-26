import '../../domain/common/crm_json.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/leads/crm_lead_models.dart';
import '../crm_api_client.dart';

/// Endpoint lead (web `crm-api.ts` phần Lead).
class CrmLeadsRepository {
  CrmLeadsRepository._();
  static final CrmLeadsRepository instance = CrmLeadsRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  /// `GET /leads?q&status&ownerUserId&page&limit`.
  Future<CrmPage<CrmLead>> listLeads({String? q, String? status, String? ownerUserId, required int page}) async =>
      CrmPage.fromJson(
          await _api.get('/leads', query: {
            'q': q,
            'status': status,
            'ownerUserId': ownerUserId,
            'page': page,
            'limit': kCrmListPageSize,
          }),
          CrmLead.fromJson);

  /// `POST /leads` (contracts `CreateLeadRequest`).
  Future<CrmLead> createLead(Map<String, dynamic> body) async =>
      CrmLead.fromJson(CrmJson.map(await _api.post('/leads', body)));

  /// `PATCH /leads/:id` (contracts `UpdateLeadRequest`, có `status` và `version`).
  Future<CrmLead> updateLead(String id, Map<String, dynamic> body) async =>
      CrmLead.fromJson(CrmJson.map(await _api.patch('/leads/${CrmApiClient.seg(id)}', body)));

  /// `POST /leads/:id/convert`.
  Future<CrmConvertLeadResult> convertLead(
    String id, {
    String? opportunityName,
    num? expectedValue,
    String? expectedCloseDate,
  }) async =>
      CrmConvertLeadResult.fromJson(CrmJson.map(await _api.post('/leads/${CrmApiClient.seg(id)}/convert', {
        'opportunityName': opportunityName,
        'expectedValue': expectedValue,
        'expectedCloseDate': expectedCloseDate,
      })));
}
