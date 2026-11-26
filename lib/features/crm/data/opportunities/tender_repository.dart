import '../../domain/common/crm_json.dart';
import '../../domain/opportunities/crm_tender_models.dart';
import '../crm_api_client.dart';

/// Endpoint hồ sơ thầu của dự án (web `crm-api.ts` mục tender; backend `TenderController`). Mọi thao tác ghi trả
/// hồ sơ mới nhất.
class TenderRepository {
  TenderRepository._();
  static final TenderRepository instance = TenderRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  String _path(String opportunityId) => '/opportunities/${CrmApiClient.seg(opportunityId)}/tender';

  CrmTenderProfile _profile(Object? raw) => CrmTenderProfile.fromJson(CrmJson.map(raw));

  /// `GET /opportunities/:id/tender`; null khi dự án chưa có hồ sơ thầu (thân rỗng).
  Future<CrmTenderProfile?> get(String opportunityId) async => CrmTenderProfile.tryParse(await _api.get(_path(opportunityId)));

  /// `POST /opportunities/:id/tender`.
  Future<CrmTenderProfile> create(String opportunityId, Map<String, dynamic> body) async =>
      _profile(await _api.post(_path(opportunityId), body));

  /// `PUT /opportunities/:id/tender` (kèm `version`).
  Future<CrmTenderProfile> update(String opportunityId, Map<String, dynamic> body) async =>
      _profile(await _api.put(_path(opportunityId), body));

  /// `POST /opportunities/:id/tender/partners` `{ name, scope }`.
  Future<CrmTenderProfile> addPartner(String opportunityId, {required String name, String? scope}) async =>
      _profile(await _api.post('${_path(opportunityId)}/partners', {'name': name, 'scope': scope}));

  /// `PUT /opportunities/:id/tender/partners/:partnerId`.
  Future<CrmTenderProfile> updatePartner(String opportunityId, String partnerId,
          {required String name, String? scope}) async =>
      _profile(await _api.put(
          '${_path(opportunityId)}/partners/${CrmApiClient.seg(partnerId)}', {'name': name, 'scope': scope}));

  /// `DELETE /opportunities/:id/tender/partners/:partnerId`.
  Future<CrmTenderProfile> deletePartner(String opportunityId, String partnerId) async =>
      _profile(await _api.delete('${_path(opportunityId)}/partners/${CrmApiClient.seg(partnerId)}'));

  /// `POST /opportunities/:id/tender/plan/{submit|approve|reject}` `{ version, reason? }`.
  Future<CrmTenderProfile> planAction(String opportunityId, String action, {required int version, String? reason}) async =>
      _profile(await _api.post('${_path(opportunityId)}/plan/$action', {
        'version': version,
        'reason': ?reason,
      }));

  /// `POST /opportunities/:id/tender/result`.
  Future<CrmTenderProfile> recordResult(String opportunityId, Map<String, dynamic> body) async =>
      _profile(await _api.post('${_path(opportunityId)}/result', body));
}
