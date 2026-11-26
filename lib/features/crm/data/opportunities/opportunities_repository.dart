import '../../domain/common/crm_json.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/opportunities/crm_opportunity_models.dart';
import '../crm_api_client.dart';

/// Endpoint Dự án bán hàng (web `crm-api.ts` mục "Cơ hội", khuyến mãi của dự án, báo giá theo dự án, hoạt động
/// chăm sóc lại).
class OpportunitiesRepository {
  OpportunitiesRepository._();
  static final OpportunitiesRepository instance = OpportunitiesRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  String _path(String id) => '/opportunities/${CrmApiClient.seg(id)}';

  /// `GET /opportunities?q&ownerUserId&stage&pipelineId&page&limit`.
  Future<CrmPage<CrmOpportunitySummary>> list({
    String? q,
    String? ownerUserId,
    String? stage,
    String? pipelineId,
    required int page,
    int limit = kCrmListPageSize,
  }) async =>
      CrmPage.fromJson(
        await _api.get('/opportunities', query: {
          'q': q,
          'ownerUserId': ownerUserId,
          'stage': stage,
          'pipelineId': pipelineId,
          'page': page,
          'limit': limit,
        }),
        CrmOpportunitySummary.fromJson,
      );

  /// `GET /opportunities/by-customer`.
  Future<CrmOpportunityByCustomerPage> listByCustomer({
    String? q,
    String? ownerUserId,
    String? stage,
    String? pipelineId,
    required int page,
    int limit = kCrmListPageSize,
  }) async =>
      CrmOpportunityByCustomerPage.fromJson(CrmJson.map(await _api.get('/opportunities/by-customer', query: {
        'q': q,
        'ownerUserId': ownerUserId,
        'stage': stage,
        'pipelineId': pipelineId,
        'page': page,
        'limit': limit,
      })));

  /// `GET /opportunities/board`.
  Future<CrmOpportunityBoard> loadBoard({String? q, String? ownerUserId, required String pipelineId}) async =>
      CrmOpportunityBoard.fromJson(CrmJson.map(await _api.get('/opportunities/board', query: {
        'q': q,
        'ownerUserId': ownerUserId,
        'pipelineId': pipelineId,
      })));

  /// `GET /opportunities/pipelines`.
  Future<List<CrmPipeline>> listPipelines() async =>
      CrmJson.list(await _api.get('/opportunities/pipelines'), CrmPipeline.fromJson);

  /// `GET /opportunities/:id/stage-requirements?stage=`.
  Future<List<CrmStageRequirementCheck>> stageRequirements(String id, String stage) async => CrmJson.list(
      await _api.get('${_path(id)}/stage-requirements', query: {'stage': stage}), CrmStageRequirementCheck.fromJson);

  Future<CrmOpportunityDetail> get(String id) async =>
      CrmOpportunityDetail.fromJson(CrmJson.map(await _api.get(_path(id))));

  /// `POST /opportunities`.
  Future<CrmOpportunityDetail> create(Map<String, dynamic> body) async =>
      CrmOpportunityDetail.fromJson(CrmJson.map(await _api.post('/opportunities', body)));

  /// `PATCH /opportunities/:id` (kèm `version`).
  Future<CrmOpportunityDetail> update(String id, Map<String, dynamic> body) async =>
      CrmOpportunityDetail.fromJson(CrmJson.map(await _api.patch(_path(id), body)));

  /// `PATCH /opportunities/:id/stage` `{ stage, reason?, version }`.
  Future<CrmOpportunityDetail> changeStage(String id, {required String stage, String? reason, int? version}) async =>
      CrmOpportunityDetail.fromJson(CrmJson.map(await _api.patch('${_path(id)}/stage', {
        'stage': stage,
        'reason': ?reason,
        'version': ?version,
      })));

  Future<CrmStagePlan> stagePlan(String id) async =>
      CrmStagePlan.fromJson(CrmJson.map(await _api.get('${_path(id)}/stage-plan')));

  /// `PUT /opportunities/:id/stage-plan/:stageId/assignee`.
  Future<CrmStagePlan> updateStageAssignee(String id, String stageId,
          {required String? assigneeUserId, required String? dueDate}) async =>
      CrmStagePlan.fromJson(CrmJson.map(await _api.put(
        '${_path(id)}/stage-plan/${CrmApiClient.seg(stageId)}/assignee',
        {'assigneeUserId': assigneeUserId, 'dueDate': dueDate},
      )));

  /// `POST /opportunities/:id/stage-plan/:stageId/skip`.
  Future<CrmStagePlan> skipStage(String id, String stageId, String reason) async => CrmStagePlan.fromJson(
      CrmJson.map(await _api.post('${_path(id)}/stage-plan/${CrmApiClient.seg(stageId)}/skip', {'reason': reason})));

  Future<List<CrmMyStageTask>> myStageTasks() async =>
      CrmJson.list(await _api.get('/opportunities/my-stage-tasks'), CrmMyStageTask.fromJson);

  // --- Khuyến mãi của dự án -------------------------------------------------------------------------------------

  Future<List<CrmPromotionCatalogItem>> listPromotionCatalog() async =>
      CrmJson.list(await _api.get('/promotions/catalog'), CrmPromotionCatalogItem.fromJson);

  Future<List<CrmOpportunityPromotion>> listPromotions(String id) async =>
      CrmJson.list(await _api.get('${_path(id)}/promotions'), CrmOpportunityPromotion.fromJson);

  Future<List<CrmOpportunityPromotion>> addPromotion(String id, {required String catalogId, String? note}) async =>
      CrmJson.list(await _api.post('${_path(id)}/promotions', {'catalogId': catalogId, 'note': note}),
          CrmOpportunityPromotion.fromJson);

  Future<List<CrmOpportunityPromotion>> removePromotion(String id, String linkId) async => CrmJson.list(
      await _api.delete('${_path(id)}/promotions/${CrmApiClient.seg(linkId)}'), CrmOpportunityPromotion.fromJson);

  // --- Liên quan ----------------------------------------------------------------------------------------------

  /// Báo giá của dự án (web `listQuotes({ opportunityId, limit: 20 })`).
  Future<List<CrmOpportunityQuote>> listQuotes(String opportunityId) async => CrmPage.fromJson(
        await _api.get('/quotes', query: {'opportunityId': opportunityId, 'limit': 20}),
        CrmOpportunityQuote.fromJson,
      ).items;

  /// Tạo hoạt động chăm sóc lại (web `createActivity`).
  Future<void> createActivity(Map<String, dynamic> body) async {
    await _api.post('/activities', body);
  }
}
