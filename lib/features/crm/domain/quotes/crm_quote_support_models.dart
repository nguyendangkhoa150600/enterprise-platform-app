import '../common/crm_json.dart';

/// Mẫu báo giá (contracts `QuoteTemplate`).
class CrmQuoteTemplate {
  final String id;
  final String name;
  final String discountMode;
  final String taxMode;
  final bool active;
  final bool isDefault;
  final bool hasLayout;

  const CrmQuoteTemplate({
    required this.id,
    required this.name,
    this.discountMode = 'LINE',
    this.taxMode = 'LINE',
    this.active = true,
    this.isDefault = false,
    this.hasLayout = false,
  });

  factory CrmQuoteTemplate.fromJson(Map<String, dynamic> json) => CrmQuoteTemplate(
        id: CrmJson.str(json['id']),
        name: CrmJson.str(json['name']),
        discountMode: CrmJson.str(json['discountMode'], 'LINE'),
        taxMode: CrmJson.str(json['taxMode'], 'LINE'),
        active: CrmJson.boolean(json['active'], true),
        isDefault: CrmJson.boolean(json['isDefault']),
        hasLayout: CrmJson.boolean(json['hasLayout']),
      );
}

/// Loại báo giá (contracts `QuoteType`).
class CrmQuoteType {
  final String id;
  final String name;
  final bool isDefault;
  const CrmQuoteType({required this.id, required this.name, this.isDefault = false});

  factory CrmQuoteType.fromJson(Map<String, dynamic> json) => CrmQuoteType(
        id: CrmJson.str(json['id']),
        name: CrmJson.str(json['name']),
        isDefault: CrmJson.boolean(json['isDefault']),
      );
}

/// Định nghĩa trường tuỳ biến (contracts `CustomFieldDefinition`).
class CrmCustomFieldDefinition {
  final String id;
  final String name;

  /// SELECT | TEXT | NUMBER | DATE.
  final String fieldType;
  final List<String> options;
  final bool required;
  final int sortOrder;
  final bool active;

  const CrmCustomFieldDefinition({
    required this.id,
    required this.name,
    required this.fieldType,
    this.options = const [],
    this.required = false,
    this.sortOrder = 0,
    this.active = true,
  });

  factory CrmCustomFieldDefinition.fromJson(Map<String, dynamic> json) => CrmCustomFieldDefinition(
        id: CrmJson.str(json['id']),
        name: CrmJson.str(json['name']),
        fieldType: CrmJson.str(json['fieldType'], 'TEXT'),
        options: CrmJson.strings(json['options']),
        required: CrmJson.boolean(json['required']),
        sortOrder: CrmJson.integer(json['sortOrder']),
        active: CrmJson.boolean(json['active'], true),
      );
}

class CrmQuoteFollower {
  final String userId;
  const CrmQuoteFollower({required this.userId});
  factory CrmQuoteFollower.fromJson(Map<String, dynamic> json) => CrmQuoteFollower(userId: CrmJson.str(json['userId']));
}

/// Loại đối tượng liên quan (contracts `QUOTE_LINK_TARGET_TYPES`).
const List<String> kCrmQuoteLinkTargetTypes = ['CUSTOMER', 'OPPORTUNITY', 'CONTRACT', 'SALES_ORDER', 'QUOTE'];

class CrmQuoteLink {
  final String id;
  final String targetType;
  final String targetId;
  final String targetLabel;
  const CrmQuoteLink({required this.id, required this.targetType, required this.targetId, required this.targetLabel});

  factory CrmQuoteLink.fromJson(Map<String, dynamic> json) => CrmQuoteLink(
        id: CrmJson.str(json['id']),
        targetType: CrmJson.str(json['targetType']),
        targetId: CrmJson.str(json['targetId']),
        targetLabel: CrmJson.str(json['targetLabel']),
      );
}

/// Bảng giá (contracts `PriceListSummary`, phần ô chọn dùng).
class CrmPriceListSummary {
  final String id;
  final String code;
  final String name;
  final String validFrom;
  final String? validTo;

  /// ACTIVE | INACTIVE.
  final String status;

  const CrmPriceListSummary(
      {required this.id, required this.code, required this.name, this.validFrom = '', this.validTo, this.status = 'ACTIVE'});

  /// Web `isPriceListEffective`.
  bool effectiveOn(String date) =>
      status == 'ACTIVE' && validFrom.compareTo(date) <= 0 && (validTo == null || validTo!.compareTo(date) >= 0);

  factory CrmPriceListSummary.fromJson(Map<String, dynamic> json) => CrmPriceListSummary(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        validFrom: CrmJson.str(json['validFrom']),
        validTo: CrmJson.strOrNull(json['validTo']),
        status: CrmJson.str(json['status'], 'ACTIVE'),
      );
}

/// Trạng thái đồng bộ bảng giá mặc định với Kho (contracts `PriceListSyncStatus`).
class CrmPriceListSyncStatus {
  final bool needsSync;
  final String? reason;
  const CrmPriceListSyncStatus({required this.needsSync, this.reason});
  factory CrmPriceListSyncStatus.fromJson(Map<String, dynamic> json) =>
      CrmPriceListSyncStatus(needsSync: CrmJson.boolean(json['needsSync']), reason: CrmJson.strOrNull(json['reason']));
}

class CrmPriceListSyncResult {
  final int added;
  final int updated;
  final int removed;
  final int skippedWithoutUnit;
  final int derivedListsUpdated;
  const CrmPriceListSyncResult(
      {this.added = 0, this.updated = 0, this.removed = 0, this.skippedWithoutUnit = 0, this.derivedListsUpdated = 0});
  factory CrmPriceListSyncResult.fromJson(Map<String, dynamic> json) => CrmPriceListSyncResult(
        added: CrmJson.integer(json['added']),
        updated: CrmJson.integer(json['updated']),
        removed: CrmJson.integer(json['removed']),
        skippedWithoutUnit: CrmJson.integer(json['skippedWithoutUnit']),
        derivedListsUpdated: CrmJson.integer(json['derivedListsUpdated']),
      );
}

/// Khuyến mãi trong danh mục (contracts `PromotionCatalogItem`, phần cần cho báo giá).
class CrmPromotionCatalogItem {
  final String id;
  final String kind;
  final String code;
  final String name;
  final String discountType;
  final double value;
  final bool effective;
  const CrmPromotionCatalogItem({
    required this.id,
    required this.kind,
    required this.code,
    required this.name,
    required this.discountType,
    this.value = 0,
    this.effective = true,
  });
  factory CrmPromotionCatalogItem.fromJson(Map<String, dynamic> json) => CrmPromotionCatalogItem(
        id: CrmJson.str(json['id']),
        kind: CrmJson.str(json['kind'], 'PROGRAM'),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        discountType: CrmJson.str(json['discountType'], 'NONE'),
        value: CrmJson.number(json['value']),
        effective: CrmJson.boolean(json['effective']),
      );
}

/// Khuyến mãi của dự án (contracts `OpportunityPromotion`).
class CrmOpportunityPromotion {
  final String id;
  final CrmPromotionCatalogItem catalog;
  const CrmOpportunityPromotion({required this.id, required this.catalog});
  factory CrmOpportunityPromotion.fromJson(Map<String, dynamic> json) => CrmOpportunityPromotion(
        id: CrmJson.str(json['id']),
        catalog: CrmPromotionCatalogItem.fromJson(CrmJson.map(json['catalog'])),
      );
}

/// Ảnh chụp khuyến mãi trên phiên bản (contracts `QuotePromotionSnapshot`).
class CrmQuotePromotionSnapshot {
  final String catalogId;
  final String kind;
  final String code;
  final String name;
  final String discountType;
  final double value;
  const CrmQuotePromotionSnapshot({
    required this.catalogId,
    required this.kind,
    required this.code,
    required this.name,
    required this.discountType,
    this.value = 0,
  });
  factory CrmQuotePromotionSnapshot.fromJson(Map<String, dynamic> json) => CrmQuotePromotionSnapshot(
        catalogId: CrmJson.str(json['catalogId']),
        kind: CrmJson.str(json['kind'], 'PROGRAM'),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        discountType: CrmJson.str(json['discountType'], 'NONE'),
        value: CrmJson.number(json['value']),
      );
}

// --- Phương án kinh doanh -----------------------------------------------------------------------------------------

const List<String> kCrmBusinessPlanCostKinds = ['DISCOUNT', 'PRICE_REDUCTION', 'SUBCONTRACT', 'OTHER'];
const int kCrmBusinessPlanLinesMax = 50;
const double kCrmBusinessPlanAmountMax = 1e13;

class CrmBusinessPlanLine {
  final String id;
  final String kind;
  final String? description;
  final double amount;
  const CrmBusinessPlanLine({required this.id, required this.kind, this.description, this.amount = 0});
  factory CrmBusinessPlanLine.fromJson(Map<String, dynamic> json) => CrmBusinessPlanLine(
        id: CrmJson.str(json['id']),
        kind: CrmJson.str(json['kind'], 'OTHER'),
        description: CrmJson.strOrNull(json['description']),
        amount: CrmJson.number(json['amount']),
      );
}

class CrmBusinessPlanFigures {
  final double grossAmount;
  final double revenue;
  final double goodsCost;
  final double discountAmount;
  final double extraCostTotal;
  final double totalCost;
  final double profit;
  final double? marginPercent;
  final double discountPercent;
  const CrmBusinessPlanFigures({
    this.grossAmount = 0,
    this.revenue = 0,
    this.goodsCost = 0,
    this.discountAmount = 0,
    this.extraCostTotal = 0,
    this.totalCost = 0,
    this.profit = 0,
    this.marginPercent,
    this.discountPercent = 0,
  });
  factory CrmBusinessPlanFigures.fromJson(Map<String, dynamic> json) => CrmBusinessPlanFigures(
        grossAmount: CrmJson.number(json['grossAmount']),
        revenue: CrmJson.number(json['revenue']),
        goodsCost: CrmJson.number(json['goodsCost']),
        discountAmount: CrmJson.number(json['discountAmount']),
        extraCostTotal: CrmJson.number(json['extraCostTotal']),
        totalCost: CrmJson.number(json['totalCost']),
        profit: CrmJson.number(json['profit']),
        marginPercent: CrmJson.numOrNull(json['marginPercent']),
        discountPercent: CrmJson.number(json['discountPercent']),
      );
}

class CrmBusinessPlanRound {
  final int roundNo;
  final int quoteVersionNo;
  final String submittedAt;
  final String submittedBy;
  final String? decidedAt;
  final String? decidedBy;
  final String? decision;
  final String? reason;
  final CrmBusinessPlanFigures? figures;
  const CrmBusinessPlanRound({
    required this.roundNo,
    required this.quoteVersionNo,
    this.submittedAt = '',
    this.submittedBy = '',
    this.decidedAt,
    this.decidedBy,
    this.decision,
    this.reason,
    this.figures,
  });
  factory CrmBusinessPlanRound.fromJson(Map<String, dynamic> json) => CrmBusinessPlanRound(
        roundNo: CrmJson.integer(json['roundNo']),
        quoteVersionNo: CrmJson.integer(json['quoteVersionNo']),
        submittedAt: CrmJson.str(json['submittedAt']),
        submittedBy: CrmJson.str(json['submittedBy']),
        decidedAt: CrmJson.strOrNull(json['decidedAt']),
        decidedBy: CrmJson.strOrNull(json['decidedBy']),
        decision: CrmJson.strOrNull(json['decision']),
        reason: CrmJson.strOrNull(json['reason']),
        figures: json['figures'] is Map ? CrmBusinessPlanFigures.fromJson(CrmJson.map(json['figures'])) : null,
      );
}

class CrmBusinessPlanDeviation {
  final int baselineVersionNo;
  final String mode;
  final double thresholdPercent;
  final double? deviationPercent;
  final bool exceeded;
  const CrmBusinessPlanDeviation(
      {this.baselineVersionNo = 0, this.mode = 'PROFIT', this.thresholdPercent = 0, this.deviationPercent, this.exceeded = false});
  factory CrmBusinessPlanDeviation.fromJson(Map<String, dynamic> json) => CrmBusinessPlanDeviation(
        baselineVersionNo: CrmJson.integer(json['baselineVersionNo']),
        mode: CrmJson.str(json['mode'], 'PROFIT'),
        thresholdPercent: CrmJson.number(json['thresholdPercent']),
        deviationPercent: CrmJson.numOrNull(json['deviationPercent']),
        exceeded: CrmJson.boolean(json['exceeded']),
      );
}

/// PAKD của phiên bản báo giá (contracts `BusinessPlanDetail`).
class CrmBusinessPlan {
  final String id;
  final int quoteVersionNo;

  /// DRAFT | PENDING | APPROVED | REJECTED.
  final String status;
  final int version;
  final String? note;
  final bool costVisible;
  final CrmBusinessPlanFigures? figures;
  final CrmBusinessPlanFigures visibleFigures;
  final List<CrmBusinessPlanLine> lines;
  final String? submittedBy;
  final String? decidedBy;
  final String? decisionReason;
  final List<CrmBusinessPlanRound> rounds;
  final bool editable;
  final CrmBusinessPlanDeviation? deviation;

  const CrmBusinessPlan({
    required this.id,
    required this.quoteVersionNo,
    required this.status,
    required this.version,
    this.note,
    this.costVisible = false,
    this.figures,
    this.visibleFigures = const CrmBusinessPlanFigures(),
    this.lines = const [],
    this.submittedBy,
    this.decidedBy,
    this.decisionReason,
    this.rounds = const [],
    this.editable = false,
    this.deviation,
  });

  factory CrmBusinessPlan.fromJson(Map<String, dynamic> json) => CrmBusinessPlan(
        id: CrmJson.str(json['id']),
        quoteVersionNo: CrmJson.integer(json['quoteVersionNo'], 1),
        status: CrmJson.str(json['status'], 'DRAFT'),
        version: CrmJson.integer(json['version']),
        note: CrmJson.strOrNull(json['note']),
        costVisible: CrmJson.boolean(json['costVisible']),
        figures: json['figures'] is Map ? CrmBusinessPlanFigures.fromJson(CrmJson.map(json['figures'])) : null,
        visibleFigures: CrmBusinessPlanFigures.fromJson(CrmJson.map(json['visibleFigures'])),
        lines: CrmJson.list(json['lines'], CrmBusinessPlanLine.fromJson),
        submittedBy: CrmJson.strOrNull(json['submittedBy']),
        decidedBy: CrmJson.strOrNull(json['decidedBy']),
        decisionReason: CrmJson.strOrNull(json['decisionReason']),
        rounds: CrmJson.list(json['rounds'], CrmBusinessPlanRound.fromJson),
        editable: CrmJson.boolean(json['editable']),
        deviation:
            json['deviation'] is Map ? CrmBusinessPlanDeviation.fromJson(CrmJson.map(json['deviation'])) : null,
      );
}

// --- Tài liệu tham chiếu ------------------------------------------------------------------------------------------

const List<String> kCrmQuoteDocumentSourceTypes = ['customer', 'opportunity', 'quote'];

class CrmQuoteDocumentInfo {
  final String id;
  final String name;
  final int? sizeBytes;
  const CrmQuoteDocumentInfo({required this.id, required this.name, this.sizeBytes});
  factory CrmQuoteDocumentInfo.fromJson(Map<String, dynamic> json) => CrmQuoteDocumentInfo(
        id: CrmJson.str(json['id']),
        name: CrmJson.str(json['name']),
        sizeBytes: CrmJson.intOrNull(json['sizeBytes']),
      );
}

class CrmQuoteDocumentSource {
  final String entityType;
  final String label;
  const CrmQuoteDocumentSource({required this.entityType, required this.label});
  factory CrmQuoteDocumentSource.fromJson(Map<String, dynamic> json) =>
      CrmQuoteDocumentSource(entityType: CrmJson.str(json['entityType']), label: CrmJson.str(json['label']));
}

/// Tham chiếu đã đính kèm hoặc ứng viên (contracts `QuoteDocumentReference`, `QuoteDocumentCandidate`).
class CrmQuoteDocumentItem {
  /// Id tham chiếu (rỗng với ứng viên).
  final String id;
  final CrmQuoteDocumentInfo document;
  final CrmQuoteDocumentSource source;
  final bool attached;
  const CrmQuoteDocumentItem({required this.id, required this.document, required this.source, this.attached = false});

  CrmQuoteDocumentItem markAttached() => CrmQuoteDocumentItem(id: id, document: document, source: source, attached: true);

  factory CrmQuoteDocumentItem.fromJson(Map<String, dynamic> json) => CrmQuoteDocumentItem(
        id: CrmJson.str(json['id']),
        document: CrmQuoteDocumentInfo.fromJson(CrmJson.map(json['document'])),
        source: CrmQuoteDocumentSource.fromJson(CrmJson.map(json['source'])),
        attached: CrmJson.boolean(json['attached']),
      );
}

// --- Dữ liệu tra cứu cho màn lập (khách, dự án) --------------------------------------------------------------------

/// Thông tin khách cho biến in `customer.*` (web `getCustomer`, chỉ các trường cần).
class CrmQuoteCustomerInfo {
  final String id;
  final String code;
  final String name;
  final String? taxCode;
  final String? address;
  final String? phone;
  final String? email;
  const CrmQuoteCustomerInfo(
      {required this.id, required this.code, required this.name, this.taxCode, this.address, this.phone, this.email});
  factory CrmQuoteCustomerInfo.fromJson(Map<String, dynamic> json) => CrmQuoteCustomerInfo(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        taxCode: CrmJson.strOrNull(json['taxCode']),
        address: CrmJson.strOrNull(json['address']),
        phone: CrmJson.strOrNull(json['phone']),
        email: CrmJson.strOrNull(json['email']),
      );
}

/// Dự án bán hàng để chọn khi lập báo giá (web `OpportunitySummary`, phần cần).
class CrmQuoteOpportunityOption {
  final String id;
  final String name;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String ownerUserId;
  final String stage;
  const CrmQuoteOpportunityOption({
    required this.id,
    required this.name,
    this.customerId = '',
    this.customerCode = '',
    this.customerName = '',
    this.ownerUserId = '',
    this.stage = '',
  });
  factory CrmQuoteOpportunityOption.fromJson(Map<String, dynamic> json) => CrmQuoteOpportunityOption(
        id: CrmJson.str(json['id']),
        name: CrmJson.str(json['name']),
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        stage: CrmJson.str(json['stage']),
      );
}

/// Một lựa chọn đối tượng liên quan (khách, dự án, hợp đồng, đơn, báo giá).
class CrmQuoteLinkTarget {
  final String id;
  final String label;
  final String? badge;
  final String? description;
  const CrmQuoteLinkTarget({required this.id, required this.label, this.badge, this.description});
}
