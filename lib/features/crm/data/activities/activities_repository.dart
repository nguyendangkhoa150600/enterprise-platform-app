import '../../domain/activities/crm_activity_models.dart';
import '../../domain/common/crm_json.dart';
import '../../domain/common/crm_page.dart';
import '../crm_api_client.dart';

/// Hoạt động chăm sóc (web `crm-api.ts`: `listActivities`, `getActivity`, `createActivity`, `updateActivity`).
class CrmActivitiesRepository {
  CrmActivitiesRepository._();
  static final CrmActivitiesRepository instance = CrmActivitiesRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  /// `GET /activities`.
  Future<CrmPage<CrmActivity>> list(CrmActivityListQuery query) async =>
      CrmPage.fromJson(await _api.get('/activities', query: query.toQuery()), CrmActivity.fromJson);

  /// `GET /activities/:id`.
  Future<CrmActivity> get(String id) async =>
      CrmActivity.fromJson(CrmJson.map(await _api.get('/activities/${CrmApiClient.seg(id)}')));

  /// `POST /activities` (contracts `CreateActivityRequest`).
  Future<CrmActivity> create(Map<String, dynamic> body) async =>
      CrmActivity.fromJson(CrmJson.map(await _api.post('/activities', body)));

  /// `PATCH /activities/:id` (contracts `UpdateActivityRequest`, kèm `version`).
  Future<CrmActivity> update(String id, Map<String, dynamic> body) async =>
      CrmActivity.fromJson(CrmJson.map(await _api.patch('/activities/${CrmApiClient.seg(id)}', body)));
}
