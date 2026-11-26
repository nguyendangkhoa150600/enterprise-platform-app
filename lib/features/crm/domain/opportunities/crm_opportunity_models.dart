import '../common/crm_json.dart';

/// Model dự án bán hàng (contracts `opportunities.ts`, `promotions.ts`): luồng, giai đoạn, cơ hội, kế hoạch giai
/// đoạn, kanban, việc của tôi, khuyến mãi của dự án.

/// Nghĩa của giai đoạn: `OPEN` đang chạy, `WON` thắng, `LOST` thua.
class CrmStageSemantic {
  CrmStageSemantic._();
  static const String open = 'OPEN';
  static const String won = 'WON';
  static const String lost = 'LOST';
}

/// Điều kiện chuyển vào một giai đoạn (`StageRequirement`).
class CrmStageRequirement {
  final String kind;
  final String ref;
  final bool required;
  final String message;

  const CrmStageRequirement({required this.kind, required this.ref, required this.required, required this.message});

  factory CrmStageRequirement.fromJson(Map<String, dynamic> json) => CrmStageRequirement(
        kind: CrmJson.str(json['kind']),
        ref: CrmJson.str(json['ref']),
        required: CrmJson.boolean(json['required']),
        message: CrmJson.str(json['message']),
      );
}

/// Giai đoạn trong luồng (`PipelineStage`).
class CrmPipelineStage {
  final String id;
  final String code;
  final String name;
  final String semantic;
  final int sortOrder;
  final bool active;
  final bool skippable;
  final List<String> nextStageIds;
  final List<CrmStageRequirement> requirements;

  const CrmPipelineStage({
    required this.id,
    required this.code,
    required this.name,
    required this.semantic,
    required this.sortOrder,
    required this.active,
    required this.skippable,
    required this.nextStageIds,
    required this.requirements,
  });

  factory CrmPipelineStage.fromJson(Map<String, dynamic> json) => CrmPipelineStage(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        semantic: CrmJson.str(json['semantic'], CrmStageSemantic.open),
        sortOrder: CrmJson.integer(json['sortOrder']),
        active: CrmJson.boolean(json['active'], true),
        skippable: CrmJson.boolean(json['skippable']),
        nextStageIds: CrmJson.strings(json['nextStageIds']),
        requirements: CrmJson.list(json['requirements'], CrmStageRequirement.fromJson),
      );
}

/// Luồng bán hàng (`Pipeline`, `GET /opportunities/pipelines`).
class CrmPipeline {
  final String id;
  final String code;
  final String name;
  final String profile;
  final bool isDefault;
  final bool active;
  final List<CrmPipelineStage> stages;

  const CrmPipeline({
    required this.id,
    required this.code,
    required this.name,
    required this.profile,
    required this.isDefault,
    required this.active,
    required this.stages,
  });

  factory CrmPipeline.fromJson(Map<String, dynamic> json) => CrmPipeline(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        profile: CrmJson.str(json['profile'], 'STANDARD'),
        isDefault: CrmJson.boolean(json['isDefault']),
        active: CrmJson.boolean(json['active'], true),
        stages: CrmJson.list(json['stages'], CrmPipelineStage.fromJson),
      );
}

/// Tham chiếu gọn tới luồng (`PipelineRef`).
class CrmPipelineRef {
  final String id;
  final String code;
  final String name;

  const CrmPipelineRef({required this.id, required this.code, required this.name});

  factory CrmPipelineRef.fromJson(Map<String, dynamic> json) => CrmPipelineRef(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
      );
}

/// Tham chiếu gọn tới giai đoạn (`StageRef`).
class CrmStageRef {
  final String id;
  final String code;
  final String name;
  final String semantic;

  const CrmStageRef({required this.id, required this.code, required this.name, required this.semantic});

  bool get isOpen => semantic == CrmStageSemantic.open;

  factory CrmStageRef.fromJson(Map<String, dynamic> json) => CrmStageRef(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        semantic: CrmJson.str(json['semantic'], CrmStageSemantic.open),
      );
}

/// Kết quả kiểm một điều kiện chuyển giai đoạn (`StageRequirementCheck`); [met] null = chưa kiểm được.
class CrmStageRequirementCheck {
  final String kind;
  final String ref;
  final bool required;
  final String message;
  final bool? met;

  const CrmStageRequirementCheck({
    required this.kind,
    required this.ref,
    required this.required,
    required this.message,
    this.met,
  });

  factory CrmStageRequirementCheck.fromJson(Map<String, dynamic> json) => CrmStageRequirementCheck(
        kind: CrmJson.str(json['kind']),
        ref: CrmJson.str(json['ref']),
        required: CrmJson.boolean(json['required']),
        message: CrmJson.str(json['message']),
        met: json['met'] == null ? null : CrmJson.boolean(json['met']),
      );
}

/// Dòng dự án bán hàng (`OpportunitySummary`).
class CrmOpportunitySummary {
  final String id;
  final String name;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String stage;
  final CrmPipelineRef pipeline;
  final CrmStageRef stageInfo;
  final int probability;
  final double? expectedValue;
  final String? expectedCloseDate;
  final String ownerUserId;
  final int version;
  final String updatedAt;

  const CrmOpportunitySummary({
    required this.id,
    required this.name,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.stage,
    required this.pipeline,
    required this.stageInfo,
    required this.probability,
    required this.expectedValue,
    required this.expectedCloseDate,
    required this.ownerUserId,
    required this.version,
    required this.updatedAt,
  });

  factory CrmOpportunitySummary.fromJson(Map<String, dynamic> json) => CrmOpportunitySummary(
        id: CrmJson.str(json['id']),
        name: CrmJson.str(json['name']),
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        stage: CrmJson.str(json['stage']),
        pipeline: CrmPipelineRef.fromJson(CrmJson.map(json['pipeline'])),
        stageInfo: CrmStageRef.fromJson(CrmJson.map(json['stageInfo'])),
        probability: CrmJson.integer(json['probability']),
        expectedValue: CrmJson.numOrNull(json['expectedValue']),
        expectedCloseDate: CrmJson.strOrNull(json['expectedCloseDate']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        version: CrmJson.integer(json['version']),
        updatedAt: CrmJson.str(json['updatedAt']),
      );

  /// Thẻ chuyển sang cột khác ngay trên giao diện (web `moveCard`).
  CrmOpportunitySummary movedTo(String stageCode, CrmStageRef info) => CrmOpportunitySummary(
        id: id,
        name: name,
        customerId: customerId,
        customerCode: customerCode,
        customerName: customerName,
        stage: stageCode,
        pipeline: pipeline,
        stageInfo: info,
        probability: probability,
        expectedValue: expectedValue,
        expectedCloseDate: expectedCloseDate,
        ownerUserId: ownerUserId,
        version: version,
        updatedAt: updatedAt,
      );
}

/// Một dòng lịch sử giai đoạn (`OpportunityStageHistoryEntry`); [kind] `CHANGE` hoặc `SKIP`.
class CrmStageHistoryEntry {
  final String id;
  final String? fromStage;
  final String toStage;
  final String? fromStageName;
  final String? toStageName;
  final String? actorId;
  final String? reason;
  final String at;
  final String kind;

  const CrmStageHistoryEntry({
    required this.id,
    required this.fromStage,
    required this.toStage,
    required this.fromStageName,
    required this.toStageName,
    required this.actorId,
    required this.reason,
    required this.at,
    required this.kind,
  });

  factory CrmStageHistoryEntry.fromJson(Map<String, dynamic> json) => CrmStageHistoryEntry(
        id: CrmJson.str(json['id']),
        fromStage: CrmJson.strOrNull(json['fromStage']),
        toStage: CrmJson.str(json['toStage']),
        fromStageName: CrmJson.strOrNull(json['fromStageName']),
        toStageName: CrmJson.strOrNull(json['toStageName']),
        actorId: CrmJson.strOrNull(json['actorId']),
        reason: CrmJson.strOrNull(json['reason']),
        at: CrmJson.str(json['at']),
        kind: CrmJson.str(json['kind'], 'CHANGE'),
      );
}

/// PAKD mới nhất của dự án (`OpportunityBusinessPlanSummary`).
class CrmOpportunityBusinessPlan {
  final String quoteId;
  final String quoteCode;
  final int versionNo;
  final String status;
  final double revenue;
  final bool costVisible;
  final double? totalCost;

  const CrmOpportunityBusinessPlan({
    required this.quoteId,
    required this.quoteCode,
    required this.versionNo,
    required this.status,
    required this.revenue,
    required this.costVisible,
    required this.totalCost,
  });

  factory CrmOpportunityBusinessPlan.fromJson(Map<String, dynamic> json) => CrmOpportunityBusinessPlan(
        quoteId: CrmJson.str(json['quoteId']),
        quoteCode: CrmJson.str(json['quoteCode']),
        versionNo: CrmJson.integer(json['versionNo']),
        status: CrmJson.str(json['status']),
        revenue: CrmJson.number(json['revenue']),
        costVisible: CrmJson.boolean(json['costVisible']),
        totalCost: CrmJson.numOrNull(json['totalCost']),
      );
}

/// Chi tiết dự án (`OpportunityDetail`).
class CrmOpportunityDetail extends CrmOpportunitySummary {
  /// Chỉ có ở `GET` một dự án; null là chưa có PAKD (hoặc phản hồi không mang trường này).
  final CrmOpportunityBusinessPlan? latestBusinessPlan;

  /// Chỉ có ở phản hồi đổi giai đoạn sang Thua: `careSuggestion.enabled`.
  final bool careSuggestionEnabled;
  final String? need;
  final double? budget;
  final double? estimateTotalValue;
  final double? estimateCostValue;
  final String? competitorName;
  final double? competitorPrice;
  final String? lostReason;
  final List<CrmStageHistoryEntry> history;
  final List<CrmStageRef> nextStages;

  const CrmOpportunityDetail({
    required super.id,
    required super.name,
    required super.customerId,
    required super.customerCode,
    required super.customerName,
    required super.stage,
    required super.pipeline,
    required super.stageInfo,
    required super.probability,
    required super.expectedValue,
    required super.expectedCloseDate,
    required super.ownerUserId,
    required super.version,
    required super.updatedAt,
    this.latestBusinessPlan,
    this.careSuggestionEnabled = false,
    this.need,
    this.budget,
    this.estimateTotalValue,
    this.estimateCostValue,
    this.competitorName,
    this.competitorPrice,
    this.lostReason,
    this.history = const [],
    this.nextStages = const [],
  });

  factory CrmOpportunityDetail.fromJson(Map<String, dynamic> json) {
    final base = CrmOpportunitySummary.fromJson(json);
    final plan = json['latestBusinessPlan'];
    return CrmOpportunityDetail(
      id: base.id,
      name: base.name,
      customerId: base.customerId,
      customerCode: base.customerCode,
      customerName: base.customerName,
      stage: base.stage,
      pipeline: base.pipeline,
      stageInfo: base.stageInfo,
      probability: base.probability,
      expectedValue: base.expectedValue,
      expectedCloseDate: base.expectedCloseDate,
      ownerUserId: base.ownerUserId,
      version: base.version,
      updatedAt: base.updatedAt,
      latestBusinessPlan: plan is Map ? CrmOpportunityBusinessPlan.fromJson(CrmJson.map(plan)) : null,
      careSuggestionEnabled: CrmJson.map(json['careSuggestion'])['enabled'] == true,
      need: CrmJson.strOrNull(json['need']),
      budget: CrmJson.numOrNull(json['budget']),
      estimateTotalValue: CrmJson.numOrNull(json['estimateTotalValue']),
      estimateCostValue: CrmJson.numOrNull(json['estimateCostValue']),
      competitorName: CrmJson.strOrNull(json['competitorName']),
      competitorPrice: CrmJson.numOrNull(json['competitorPrice']),
      lostReason: CrmJson.strOrNull(json['lostReason']),
      history: CrmJson.list(json['history'], CrmStageHistoryEntry.fromJson),
      nextStages: CrmJson.list(json['nextStages'], CrmStageRef.fromJson),
    );
  }

  /// Giữ PAKD đối chiếu khi phản hồi ghi (PATCH) không mang trường này.
  CrmOpportunityDetail withBusinessPlan(CrmOpportunityBusinessPlan? plan) => CrmOpportunityDetail(
        id: id,
        name: name,
        customerId: customerId,
        customerCode: customerCode,
        customerName: customerName,
        stage: stage,
        pipeline: pipeline,
        stageInfo: stageInfo,
        probability: probability,
        expectedValue: expectedValue,
        expectedCloseDate: expectedCloseDate,
        ownerUserId: ownerUserId,
        version: version,
        updatedAt: updatedAt,
        latestBusinessPlan: plan,
        careSuggestionEnabled: careSuggestionEnabled,
        need: need,
        budget: budget,
        estimateTotalValue: estimateTotalValue,
        estimateCostValue: estimateCostValue,
        competitorName: competitorName,
        competitorPrice: competitorPrice,
        lostReason: lostReason,
        history: history,
        nextStages: nextStages,
      );
}

/// Một dòng kế hoạch giai đoạn (`OpportunityStagePlanItem`); [status] PENDING / ACTIVE / DONE / SKIPPED.
class CrmStagePlanItem {
  final CrmStageRef stage;
  final String status;
  final bool skippable;
  final String? assigneeUserId;
  final String? assigneeWarning;
  final String? dueDate;
  final String? skippedReason;
  final String? skippedBy;
  final String? skippedAt;

  const CrmStagePlanItem({
    required this.stage,
    required this.status,
    required this.skippable,
    this.assigneeUserId,
    this.assigneeWarning,
    this.dueDate,
    this.skippedReason,
    this.skippedBy,
    this.skippedAt,
  });

  bool get finished => status == 'DONE' || status == 'SKIPPED';

  factory CrmStagePlanItem.fromJson(Map<String, dynamic> json) => CrmStagePlanItem(
        stage: CrmStageRef.fromJson(CrmJson.map(json['stage'])),
        status: CrmJson.str(json['status'], 'PENDING'),
        skippable: CrmJson.boolean(json['skippable']),
        assigneeUserId: CrmJson.strOrNull(json['assigneeUserId']),
        assigneeWarning: CrmJson.strOrNull(json['assigneeWarning']),
        dueDate: CrmJson.strOrNull(json['dueDate']),
        skippedReason: CrmJson.strOrNull(json['skippedReason']),
        skippedBy: CrmJson.strOrNull(json['skippedBy']),
        skippedAt: CrmJson.strOrNull(json['skippedAt']),
      );
}

/// Kế hoạch giai đoạn (`OpportunityStagePlan`).
class CrmStagePlan {
  final String opportunityId;
  final List<CrmStagePlanItem> items;

  const CrmStagePlan({required this.opportunityId, required this.items});

  factory CrmStagePlan.fromJson(Map<String, dynamic> json) => CrmStagePlan(
        opportunityId: CrmJson.str(json['opportunityId']),
        items: CrmJson.list(json['items'], CrmStagePlanItem.fromJson),
      );
}

/// Việc của tôi (`MyStageTask`).
class CrmMyStageTask {
  final String opportunityId;
  final String opportunityName;
  final String customerName;
  final CrmStageRef stage;
  final String status;
  final String? dueDate;

  const CrmMyStageTask({
    required this.opportunityId,
    required this.opportunityName,
    required this.customerName,
    required this.stage,
    required this.status,
    this.dueDate,
  });

  factory CrmMyStageTask.fromJson(Map<String, dynamic> json) => CrmMyStageTask(
        opportunityId: CrmJson.str(json['opportunityId']),
        opportunityName: CrmJson.str(json['opportunityName']),
        customerName: CrmJson.str(json['customerName']),
        stage: CrmStageRef.fromJson(CrmJson.map(json['stage'])),
        status: CrmJson.str(json['status'], 'PENDING'),
        dueDate: CrmJson.strOrNull(json['dueDate']),
      );
}

/// Một cột kanban (`OpportunityBoardColumn`).
class CrmBoardColumn {
  final String stage;
  final CrmStageRef stageInfo;
  final int total;
  final double totalValue;
  final List<CrmOpportunitySummary> items;

  const CrmBoardColumn({
    required this.stage,
    required this.stageInfo,
    required this.total,
    required this.totalValue,
    required this.items,
  });

  factory CrmBoardColumn.fromJson(Map<String, dynamic> json) => CrmBoardColumn(
        stage: CrmJson.str(json['stage']),
        stageInfo: CrmStageRef.fromJson(CrmJson.map(json['stageInfo'])),
        total: CrmJson.integer(json['total']),
        totalValue: CrmJson.number(json['totalValue']),
        items: CrmJson.list(json['items'], CrmOpportunitySummary.fromJson),
      );

  CrmBoardColumn copyWith({int? total, double? totalValue, List<CrmOpportunitySummary>? items}) => CrmBoardColumn(
        stage: stage,
        stageInfo: stageInfo,
        total: total ?? this.total,
        totalValue: totalValue ?? this.totalValue,
        items: items ?? this.items,
      );
}

/// Kanban (`OpportunityBoard`).
class CrmOpportunityBoard {
  final CrmPipelineRef pipeline;
  final List<CrmBoardColumn> columns;

  const CrmOpportunityBoard({required this.pipeline, required this.columns});

  factory CrmOpportunityBoard.fromJson(Map<String, dynamic> json) => CrmOpportunityBoard(
        pipeline: CrmPipelineRef.fromJson(CrmJson.map(json['pipeline'])),
        columns: CrmJson.list(json['columns'], CrmBoardColumn.fromJson),
      );

  CrmOpportunityBoard withColumns(List<CrmBoardColumn> columns) =>
      CrmOpportunityBoard(pipeline: pipeline, columns: columns);
}

/// Tổng của một khách theo bộ lọc (`OpportunityCustomerTotal`).
class CrmOpportunityCustomerTotal {
  final String customerId;
  final int count;
  final double totalValue;

  const CrmOpportunityCustomerTotal({required this.customerId, required this.count, required this.totalValue});

  factory CrmOpportunityCustomerTotal.fromJson(Map<String, dynamic> json) => CrmOpportunityCustomerTotal(
        customerId: CrmJson.str(json['customerId']),
        count: CrmJson.integer(json['count']),
        totalValue: CrmJson.number(json['totalValue']),
      );
}

/// Trang dự án theo khách (`OpportunityByCustomerPage`).
class CrmOpportunityByCustomerPage {
  final List<CrmOpportunitySummary> items;
  final List<CrmOpportunityCustomerTotal> customers;
  final int page;
  final int total;

  const CrmOpportunityByCustomerPage({
    required this.items,
    required this.customers,
    required this.page,
    required this.total,
  });

  factory CrmOpportunityByCustomerPage.fromJson(Map<String, dynamic> json) => CrmOpportunityByCustomerPage(
        items: CrmJson.list(json['items'], CrmOpportunitySummary.fromJson),
        customers: CrmJson.list(json['customers'], CrmOpportunityCustomerTotal.fromJson),
        page: CrmJson.integer(json['page'], 1),
        total: CrmJson.integer(json['total']),
      );
}

/// Mục danh mục khuyến mãi (`PromotionCatalogItem`).
class CrmPromotionCatalogItem {
  final String id;
  final String kind;
  final String code;
  final String name;
  final String discountType;
  final double value;
  final String? validFrom;
  final String? validTo;
  final bool active;
  final bool effective;

  const CrmPromotionCatalogItem({
    required this.id,
    required this.kind,
    required this.code,
    required this.name,
    required this.discountType,
    required this.value,
    this.validFrom,
    this.validTo,
    required this.active,
    required this.effective,
  });

  factory CrmPromotionCatalogItem.fromJson(Map<String, dynamic> json) => CrmPromotionCatalogItem(
        id: CrmJson.str(json['id']),
        kind: CrmJson.str(json['kind']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        discountType: CrmJson.str(json['discountType'], 'NONE'),
        value: CrmJson.number(json['value']),
        validFrom: CrmJson.strOrNull(json['validFrom']),
        validTo: CrmJson.strOrNull(json['validTo']),
        active: CrmJson.boolean(json['active']),
        effective: CrmJson.boolean(json['effective']),
      );
}

/// Khuyến mãi đã chọn cho dự án (`OpportunityPromotion`).
class CrmOpportunityPromotion {
  final String id;
  final CrmPromotionCatalogItem catalog;
  final String? note;

  const CrmOpportunityPromotion({required this.id, required this.catalog, this.note});

  factory CrmOpportunityPromotion.fromJson(Map<String, dynamic> json) => CrmOpportunityPromotion(
        id: CrmJson.str(json['id']),
        catalog: CrmPromotionCatalogItem.fromJson(CrmJson.map(json['catalog'])),
        note: CrmJson.strOrNull(json['note']),
      );
}

/// Báo giá của dự án (các trường `QuoteSummary` dùng ở ngăn chi tiết dự án).
class CrmOpportunityQuote {
  final String id;
  final String code;
  final String status;
  final int currentVersion;
  final double totalAmount;

  const CrmOpportunityQuote({
    required this.id,
    required this.code,
    required this.status,
    required this.currentVersion,
    required this.totalAmount,
  });

  factory CrmOpportunityQuote.fromJson(Map<String, dynamic> json) => CrmOpportunityQuote(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        status: CrmJson.str(json['status']),
        currentVersion: CrmJson.integer(json['currentVersion']),
        totalAmount: CrmJson.number(json['totalAmount']),
      );
}
