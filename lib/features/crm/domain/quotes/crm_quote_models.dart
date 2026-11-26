import '../common/crm_json.dart';
import '../common/crm_sales_organization_models.dart';
import 'crm_quote_layout_models.dart';
import 'crm_quote_support_models.dart';

/// Trạng thái phiên bản báo giá (contracts `QUOTE_STATUSES`).
class CrmQuoteStatus {
  CrmQuoteStatus._();
  static const String draft = 'DRAFT';
  static const String pending = 'PENDING';
  static const String rejected = 'REJECTED';
  static const String approved = 'APPROVED';
  static const String sent = 'SENT';
  static const String accepted = 'ACCEPTED';
  static const String declined = 'DECLINED';
  static const String expired = 'EXPIRED';
  static const String superseded = 'SUPERSEDED';

  static const List<String> values = [draft, pending, rejected, approved, sent, accepted, declined, expired, superseded];

  /// Bảng chuyển trạng thái (contracts `QUOTE_STATUS_TRANSITIONS`).
  static const Map<String, List<String>> transitions = {
    draft: [pending, approved],
    pending: [approved, rejected],
    rejected: [superseded],
    approved: [sent, superseded, expired],
    sent: [accepted, declined, superseded, expired],
    accepted: [],
    declined: [],
    expired: [],
    superseded: [],
  };

  /// Sửa được bằng cách sinh phiên bản mới (contracts `QUOTE_REVISABLE_STATUSES`).
  static const List<String> revisable = [approved, sent, rejected];

  /// Phiên bản ở các trạng thái này in theo bản chụp bố cục lúc gửi khách (web `SNAPSHOT_STATUSES`).
  static const List<String> snapshot = [sent, accepted, declined, expired, superseded];
}

/// Dòng danh sách báo giá (contracts `QuoteSummary`).
class CrmQuoteSummary {
  final String id;
  final String code;
  final String? opportunityId;
  final String? opportunityName;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String ownerUserId;
  final String status;
  final int currentVersion;
  final String? quoteName;
  final String? validUntil;
  final double totalAmount;
  final String updatedAt;

  const CrmQuoteSummary({
    required this.id,
    required this.code,
    this.opportunityId,
    this.opportunityName,
    this.customerId = '',
    this.customerCode = '',
    this.customerName = '',
    this.ownerUserId = '',
    this.status = CrmQuoteStatus.draft,
    this.currentVersion = 1,
    this.quoteName,
    this.validUntil,
    this.totalAmount = 0,
    this.updatedAt = '',
  });

  factory CrmQuoteSummary.fromJson(Map<String, dynamic> json) => CrmQuoteSummary(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        opportunityId: CrmJson.strOrNull(json['opportunityId']),
        opportunityName: CrmJson.strOrNull(json['opportunityName']),
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        status: CrmJson.str(json['status'], CrmQuoteStatus.draft),
        currentVersion: CrmJson.integer(json['currentVersion'], 1),
        quoteName: CrmJson.strOrNull(json['quoteName']),
        validUntil: CrmJson.strOrNull(json['validUntil']),
        totalAmount: CrmJson.number(json['totalAmount']),
        updatedAt: CrmJson.str(json['updatedAt']),
      );
}

/// Chính sách chiết khấu đã áp trên dòng (contracts `AppliedDiscountPolicy`).
class CrmAppliedPolicy {
  final String policyId;
  final String code;
  final String name;
  final double percent;
  const CrmAppliedPolicy({required this.policyId, required this.code, required this.name, required this.percent});

  factory CrmAppliedPolicy.fromJson(Map<String, dynamic> json) => CrmAppliedPolicy(
        policyId: CrmJson.str(json['policyId']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        percent: CrmJson.number(json['percent']),
      );
}

/// Dòng báo giá (contracts `QuoteLine`).
class CrmQuoteLine {
  final String id;
  final int lineNo;
  final String materialId;
  final String materialCode;
  final String materialName;
  final String unit;
  final String materialKind;
  final String? category;
  final double quantity;
  final double listPrice;
  final String priceSource;
  final String? priceReferenceCode;
  final List<CrmAppliedPolicy> appliedPolicies;
  final double policyPercent;
  final double discountPercent;
  final double? cappedAt;
  final bool overridden;
  final double? overrideUnitPrice;
  final double? overrideDiscountPercent;
  final double? overrideVatRate;
  final double unitPrice;
  final double vatRate;
  final double lineAmount;
  final double vatAmount;
  final double lineTotal;
  final double? estUnitCost;
  final double estCost;
  final double? margin;
  final double? availableStock;

  const CrmQuoteLine({
    required this.id,
    required this.lineNo,
    required this.materialId,
    required this.materialCode,
    required this.materialName,
    required this.unit,
    this.materialKind = 'STOCK',
    this.category,
    this.quantity = 0,
    this.listPrice = 0,
    this.priceSource = 'GROUP_LIST',
    this.priceReferenceCode,
    this.appliedPolicies = const [],
    this.policyPercent = 0,
    this.discountPercent = 0,
    this.cappedAt,
    this.overridden = false,
    this.overrideUnitPrice,
    this.overrideDiscountPercent,
    this.overrideVatRate,
    this.unitPrice = 0,
    this.vatRate = 0,
    this.lineAmount = 0,
    this.vatAmount = 0,
    this.lineTotal = 0,
    this.estUnitCost,
    this.estCost = 0,
    this.margin,
    this.availableStock,
  });

  bool get isService => materialKind == 'SERVICE';

  factory CrmQuoteLine.fromJson(Map<String, dynamic> json) => CrmQuoteLine(
        id: CrmJson.str(json['id']),
        lineNo: CrmJson.integer(json['lineNo']),
        materialId: CrmJson.str(json['materialId']),
        materialCode: CrmJson.str(json['materialCode']),
        materialName: CrmJson.str(json['materialName']),
        unit: CrmJson.str(json['unit']),
        materialKind: CrmJson.str(json['materialKind'], 'STOCK'),
        category: CrmJson.strOrNull(json['category']),
        quantity: CrmJson.number(json['quantity']),
        listPrice: CrmJson.number(json['listPrice']),
        priceSource: CrmJson.str(json['priceSource'], 'GROUP_LIST'),
        priceReferenceCode: CrmJson.strOrNull(json['priceReferenceCode']),
        appliedPolicies: CrmJson.list(json['appliedPolicies'], CrmAppliedPolicy.fromJson),
        policyPercent: CrmJson.number(json['policyPercent']),
        discountPercent: CrmJson.number(json['discountPercent']),
        cappedAt: CrmJson.numOrNull(json['cappedAt']),
        overridden: CrmJson.boolean(json['overridden']),
        overrideUnitPrice: CrmJson.numOrNull(json['overrideUnitPrice']),
        overrideDiscountPercent: CrmJson.numOrNull(json['overrideDiscountPercent']),
        overrideVatRate: CrmJson.numOrNull(json['overrideVatRate']),
        unitPrice: CrmJson.number(json['unitPrice']),
        vatRate: CrmJson.number(json['vatRate']),
        lineAmount: CrmJson.number(json['lineAmount']),
        vatAmount: CrmJson.number(json['vatAmount']),
        lineTotal: CrmJson.number(json['lineTotal']),
        estUnitCost: CrmJson.numOrNull(json['estUnitCost']),
        estCost: CrmJson.number(json['estCost']),
        margin: CrmJson.numOrNull(json['margin']),
        availableStock: CrmJson.numOrNull(json['availableStock']),
      );
}

class CrmQuoteShipping {
  final double amount;
  final double vatRate;
  final double cost;
  const CrmQuoteShipping({this.amount = 0, this.vatRate = 0, this.cost = 0});

  factory CrmQuoteShipping.fromJson(Map<String, dynamic> json) => CrmQuoteShipping(
        amount: CrmJson.number(json['amount']),
        vatRate: CrmJson.number(json['vatRate']),
        cost: CrmJson.number(json['cost']),
      );
}

class CrmQuoteTotals {
  final double grossAmount;
  final double discountAmount;
  final double netAmount;
  final double shippingAmount;
  final double vatAmount;
  final double totalAmount;
  final double estCost;
  final double profit;
  final double? marginPercent;
  final double discountPercent;

  const CrmQuoteTotals({
    this.grossAmount = 0,
    this.discountAmount = 0,
    this.netAmount = 0,
    this.shippingAmount = 0,
    this.vatAmount = 0,
    this.totalAmount = 0,
    this.estCost = 0,
    this.profit = 0,
    this.marginPercent,
    this.discountPercent = 0,
  });

  factory CrmQuoteTotals.fromJson(Map<String, dynamic> json) => CrmQuoteTotals(
        grossAmount: CrmJson.number(json['grossAmount']),
        discountAmount: CrmJson.number(json['discountAmount']),
        netAmount: CrmJson.number(json['netAmount']),
        shippingAmount: CrmJson.number(json['shippingAmount']),
        vatAmount: CrmJson.number(json['vatAmount']),
        totalAmount: CrmJson.number(json['totalAmount']),
        estCost: CrmJson.number(json['estCost']),
        profit: CrmJson.number(json['profit']),
        marginPercent: CrmJson.numOrNull(json['marginPercent']),
        discountPercent: CrmJson.number(json['discountPercent']),
      );
}

/// Chiết khấu hoặc thuế tổng đơn đã tính (contracts `QuoteOrderAmount`).
class CrmQuoteOrderAmount {
  final double percent;
  final double amount;

  /// `PERCENT` | `AMOUNT` | null (không nhập).
  final String? inputKind;
  const CrmQuoteOrderAmount({this.percent = 0, this.amount = 0, this.inputKind});

  factory CrmQuoteOrderAmount.fromJson(Map<String, dynamic> json) => CrmQuoteOrderAmount(
        percent: CrmJson.number(json['percent']),
        amount: CrmJson.number(json['amount']),
        inputKind: CrmJson.strOrNull(json['inputKind']),
      );
}

class CrmQuoteFee {
  final String feeType;
  final double amount;
  const CrmQuoteFee({required this.feeType, required this.amount});

  factory CrmQuoteFee.fromJson(Map<String, dynamic> json) =>
      CrmQuoteFee(feeType: CrmJson.str(json['feeType']), amount: CrmJson.number(json['amount']));

  Map<String, dynamic> toJson() => {'feeType': feeType, 'amount': amount};
}

/// Trường theo mẫu của phiên bản (contracts `QuoteFormData`).
class CrmQuoteForm {
  final String? quoteName;
  final String? quoteDate;
  final String? templateId;
  final String? templateName;
  final String? quoteTypeId;
  final String? quoteTypeName;

  /// `LINE` | `ORDER`.
  final String discountMode;
  final String taxMode;
  final CrmQuoteOrderAmount orderDiscount;
  final CrmQuoteOrderAmount orderTax;
  final List<CrmQuoteFee> fees;
  final double feesAmount;

  /// Giá trị trường tuỳ biến (chuỗi hoặc số).
  final Map<String, Object> customFields;
  final String? organizationId;
  final String? organizationName;
  final CrmQuoteSeller? seller;

  const CrmQuoteForm({
    this.quoteName,
    this.quoteDate,
    this.templateId,
    this.templateName,
    this.quoteTypeId,
    this.quoteTypeName,
    this.discountMode = 'LINE',
    this.taxMode = 'LINE',
    this.orderDiscount = const CrmQuoteOrderAmount(),
    this.orderTax = const CrmQuoteOrderAmount(),
    this.fees = const [],
    this.feesAmount = 0,
    this.customFields = const {},
    this.organizationId,
    this.organizationName,
    this.seller,
  });

  factory CrmQuoteForm.fromJson(Map<String, dynamic> json) {
    final custom = <String, Object>{};
    CrmJson.map(json['customFields']).forEach((key, value) {
      if (value is num || value is String) custom[key] = value as Object;
    });
    final seller = json['seller'];
    return CrmQuoteForm(
      quoteName: CrmJson.strOrNull(json['quoteName']),
      quoteDate: CrmJson.strOrNull(json['quoteDate']),
      templateId: CrmJson.strOrNull(json['templateId']),
      templateName: CrmJson.strOrNull(json['templateName']),
      quoteTypeId: CrmJson.strOrNull(json['quoteTypeId']),
      quoteTypeName: CrmJson.strOrNull(json['quoteTypeName']),
      discountMode: CrmJson.str(json['discountMode'], 'LINE'),
      taxMode: CrmJson.str(json['taxMode'], 'LINE'),
      orderDiscount: CrmQuoteOrderAmount.fromJson(CrmJson.map(json['orderDiscount'])),
      orderTax: CrmQuoteOrderAmount.fromJson(CrmJson.map(json['orderTax'])),
      fees: CrmJson.list(json['fees'], CrmQuoteFee.fromJson),
      feesAmount: CrmJson.number(json['feesAmount']),
      customFields: custom,
      organizationId: CrmJson.strOrNull(json['organizationId']),
      organizationName: CrmJson.strOrNull(json['organizationName']),
      seller: seller is Map ? CrmQuoteSeller.fromJson(CrmJson.map(seller)) : null,
    );
  }

  CrmQuoteForm copyWith({
    String? quoteName,
    String? quoteDate,
    String? templateId,
    String? templateName,
    String? quoteTypeId,
    String? quoteTypeName,
    bool clearOrganization = false,
    String? organizationId,
    String? organizationName,
    CrmQuoteSeller? seller,
    bool clearSeller = false,
    bool clearDate = false,
  }) =>
      CrmQuoteForm(
        quoteName: quoteName ?? this.quoteName,
        quoteDate: clearDate ? null : (quoteDate ?? this.quoteDate),
        templateId: templateId ?? this.templateId,
        templateName: templateName ?? this.templateName,
        quoteTypeId: quoteTypeId ?? this.quoteTypeId,
        quoteTypeName: quoteTypeName ?? this.quoteTypeName,
        discountMode: discountMode,
        taxMode: taxMode,
        orderDiscount: orderDiscount,
        orderTax: orderTax,
        fees: fees,
        feesAmount: feesAmount,
        customFields: customFields,
        organizationId: clearOrganization ? null : (organizationId ?? this.organizationId),
        organizationName: clearOrganization ? null : (organizationName ?? this.organizationName),
        seller: clearSeller ? null : (seller ?? this.seller),
      );
}

class CrmQuoteApprovalReason {
  final String code;
  final String message;
  const CrmQuoteApprovalReason({required this.code, required this.message});

  factory CrmQuoteApprovalReason.fromJson(Map<String, dynamic> json) =>
      CrmQuoteApprovalReason(code: CrmJson.str(json['code']), message: CrmJson.str(json['message']));
}

class CrmQuoteVersionSummary {
  final int versionNo;
  final String status;
  final double totalAmount;
  final String createdAt;
  const CrmQuoteVersionSummary(
      {required this.versionNo, required this.status, this.totalAmount = 0, this.createdAt = ''});

  factory CrmQuoteVersionSummary.fromJson(Map<String, dynamic> json) => CrmQuoteVersionSummary(
        versionNo: CrmJson.integer(json['versionNo'], 1),
        status: CrmJson.str(json['status']),
        totalAmount: CrmJson.number(json['totalAmount']),
        createdAt: CrmJson.str(json['createdAt']),
      );
}

/// Phiên bản báo giá (contracts `QuoteVersion`).
class CrmQuoteVersion {
  final String id;
  final int versionNo;
  final String status;
  final int revision;
  final String? validUntil;
  final String? priceDate;
  final String? pricedOn;
  final String? priceListId;
  final String? priceListCode;
  final String? priceListName;
  final String? priceListStatus;
  final String? note;
  final CrmQuoteShipping shipping;
  final CrmQuoteTotals totals;
  final CrmQuoteForm form;
  final List<CrmQuotePromotionSnapshot> promotions;
  final bool costHidden;
  final List<CrmQuoteApprovalReason> approvalReasons;
  final String? submittedBy;
  final String? decisionReason;
  final String? sentAt;
  final String createdAt;
  final CrmQuoteLayout? layoutSnapshot;
  final String? sellerLogo;
  final List<CrmQuoteLine> lines;

  const CrmQuoteVersion({
    this.id = '',
    this.versionNo = 1,
    this.status = CrmQuoteStatus.draft,
    this.revision = 0,
    this.validUntil,
    this.priceDate,
    this.pricedOn,
    this.priceListId,
    this.priceListCode,
    this.priceListName,
    this.priceListStatus,
    this.note,
    this.shipping = const CrmQuoteShipping(),
    this.totals = const CrmQuoteTotals(),
    this.form = const CrmQuoteForm(),
    this.promotions = const [],
    this.costHidden = false,
    this.approvalReasons = const [],
    this.submittedBy,
    this.decisionReason,
    this.sentAt,
    this.createdAt = '',
    this.layoutSnapshot,
    this.sellerLogo,
    this.lines = const [],
  });

  factory CrmQuoteVersion.fromJson(Map<String, dynamic> json) {
    final snapshot = json['layoutSnapshot'];
    return CrmQuoteVersion(
      id: CrmJson.str(json['id']),
      versionNo: CrmJson.integer(json['versionNo'], 1),
      status: CrmJson.str(json['status'], CrmQuoteStatus.draft),
      revision: CrmJson.integer(json['revision']),
      validUntil: CrmJson.strOrNull(json['validUntil']),
      priceDate: CrmJson.strOrNull(json['priceDate']),
      pricedOn: CrmJson.strOrNull(json['pricedOn']),
      priceListId: CrmJson.strOrNull(json['priceListId']),
      priceListCode: CrmJson.strOrNull(json['priceListCode']),
      priceListName: CrmJson.strOrNull(json['priceListName']),
      priceListStatus: CrmJson.strOrNull(json['priceListStatus']),
      note: CrmJson.strOrNull(json['note']),
      shipping: CrmQuoteShipping.fromJson(CrmJson.map(json['shipping'])),
      totals: CrmQuoteTotals.fromJson(CrmJson.map(json['totals'])),
      form: CrmQuoteForm.fromJson(CrmJson.map(json['form'])),
      promotions: CrmJson.list(json['promotions'], CrmQuotePromotionSnapshot.fromJson),
      costHidden: CrmJson.boolean(json['costHidden']),
      approvalReasons: CrmJson.list(json['approvalReasons'], CrmQuoteApprovalReason.fromJson),
      submittedBy: CrmJson.strOrNull(json['submittedBy']),
      decisionReason: CrmJson.strOrNull(json['decisionReason']),
      sentAt: CrmJson.strOrNull(json['sentAt']),
      createdAt: CrmJson.str(json['createdAt']),
      layoutSnapshot: snapshot is Map ? CrmQuoteLayout.fromJson(CrmJson.map(snapshot)) : null,
      sellerLogo: CrmJson.strOrNull(json['sellerLogo']),
      lines: CrmJson.list(json['lines'], CrmQuoteLine.fromJson),
    );
  }

  CrmQuoteVersion copyWith({
    String? validUntil,
    bool clearValidUntil = false,
    String? note,
    String? priceListId,
    String? priceListCode,
    String? priceListName,
    String? priceListStatus,
    CrmQuoteForm? form,
    String? sellerLogo,
    bool clearSellerLogo = false,
  }) =>
      CrmQuoteVersion(
        id: id,
        versionNo: versionNo,
        status: status,
        revision: revision,
        validUntil: clearValidUntil ? null : (validUntil ?? this.validUntil),
        priceDate: priceDate,
        pricedOn: pricedOn,
        priceListId: priceListId ?? this.priceListId,
        priceListCode: priceListCode ?? this.priceListCode,
        priceListName: priceListName ?? this.priceListName,
        priceListStatus: priceListStatus ?? this.priceListStatus,
        note: note ?? this.note,
        shipping: shipping,
        totals: totals,
        form: form ?? this.form,
        promotions: promotions,
        costHidden: costHidden,
        approvalReasons: approvalReasons,
        submittedBy: submittedBy,
        decisionReason: decisionReason,
        sentAt: sentAt,
        createdAt: createdAt,
        layoutSnapshot: layoutSnapshot,
        sellerLogo: clearSellerLogo ? null : (sellerLogo ?? this.sellerLogo),
        lines: lines,
      );
}

/// Phiên duyệt qua Quy trình (contracts `QuoteProcedureLink`).
class CrmQuoteProcedureLink {
  final String id;

  /// START_PENDING | RUNNING | FAILED | APPLIED | CLOSED.
  final String status;
  final String? instanceId;
  final String? instanceCode;
  final String? lastError;

  const CrmQuoteProcedureLink({required this.id, required this.status, this.instanceId, this.instanceCode, this.lastError});

  factory CrmQuoteProcedureLink.fromJson(Map<String, dynamic> json) => CrmQuoteProcedureLink(
        id: CrmJson.str(json['id']),
        status: CrmJson.str(json['status']),
        instanceId: CrmJson.strOrNull(json['instanceId']),
        instanceCode: CrmJson.strOrNull(json['instanceCode']),
        lastError: CrmJson.strOrNull(json['lastError']),
      );
}

class CrmQuoteHistoryEntry {
  final String id;
  final String at;
  final String action;
  final String? toStatus;
  final String? actorId;
  final String? reason;
  final int? versionNo;

  const CrmQuoteHistoryEntry(
      {required this.id, required this.at, required this.action, this.toStatus, this.actorId, this.reason, this.versionNo});

  factory CrmQuoteHistoryEntry.fromJson(Map<String, dynamic> json) => CrmQuoteHistoryEntry(
        id: CrmJson.str(json['id']),
        at: CrmJson.str(json['at']),
        action: CrmJson.str(json['action']),
        toStatus: CrmJson.strOrNull(json['toStatus']),
        actorId: CrmJson.strOrNull(json['actorId']),
        reason: CrmJson.strOrNull(json['reason']),
        versionNo: CrmJson.intOrNull(json['versionNo']),
      );
}

/// Đích duyệt đang chờ chính người xem (contracts `CrmTaskApprovalTarget`).
class CrmQuoteApprovalTarget {
  /// QUOTE | BUSINESS_PLAN.
  final String subject;

  /// DIRECT | PROCEDURE.
  final String mode;
  final String? procedureInstanceId;
  final String? procedureInstanceCode;

  const CrmQuoteApprovalTarget(
      {required this.subject, required this.mode, this.procedureInstanceId, this.procedureInstanceCode});

  bool get isPlan => subject == 'BUSINESS_PLAN';
  bool get viaProcedure => mode == 'PROCEDURE';

  /// Web `procedureHrefOf`: có hồ sơ Quy trình để mở.
  String? get procedureInstance => viaProcedure && (procedureInstanceId ?? '').isNotEmpty ? procedureInstanceId : null;

  factory CrmQuoteApprovalTarget.fromJson(Map<String, dynamic> json) => CrmQuoteApprovalTarget(
        subject: CrmJson.str(json['subject'], 'QUOTE'),
        mode: CrmJson.str(json['mode'], 'DIRECT'),
        procedureInstanceId: CrmJson.strOrNull(json['procedureInstanceId']),
        procedureInstanceCode: CrmJson.strOrNull(json['procedureInstanceCode']),
      );
}

/// Chi tiết báo giá (contracts `QuoteDetail`).
class CrmQuoteDetail {
  final CrmQuoteSummary summary;
  final int? acceptedVersion;
  final String? convertedAt;
  final String createdAt;
  final List<CrmQuoteVersionSummary> versions;
  final CrmQuoteVersion version;
  final CrmQuoteProcedureLink? procedure;
  final List<CrmQuoteHistoryEntry> history;

  /// Null: phiên bản không phải Nháp hiện tại.
  final List<CrmQuoteApprovalReason>? approvalCheck;

  /// Chưa tải (`businessPlanLoaded == false`) khác với chưa lập (null).
  final CrmBusinessPlan? businessPlan;
  final bool hasBusinessPlanField;
  final CrmQuoteApprovalTarget? awaitingMyApproval;

  const CrmQuoteDetail({
    required this.summary,
    this.acceptedVersion,
    this.convertedAt,
    this.createdAt = '',
    this.versions = const [],
    required this.version,
    this.procedure,
    this.history = const [],
    this.approvalCheck,
    this.businessPlan,
    this.hasBusinessPlanField = false,
    this.awaitingMyApproval,
  });

  String get id => summary.id;
  String get code => summary.code;
  String get customerId => summary.customerId;
  String get customerCode => summary.customerCode;
  String get customerName => summary.customerName;
  String? get opportunityId => summary.opportunityId;
  String? get opportunityName => summary.opportunityName;
  String get ownerUserId => summary.ownerUserId;
  String get status => summary.status;
  int get currentVersion => summary.currentVersion;
  String? get quoteName => summary.quoteName;

  factory CrmQuoteDetail.fromJson(Map<String, dynamic> json) {
    final check = json['approvalCheck'];
    final plan = json['businessPlan'];
    final awaiting = json['awaitingMyApproval'];
    final procedure = json['procedure'];
    return CrmQuoteDetail(
      summary: CrmQuoteSummary.fromJson(json),
      acceptedVersion: CrmJson.intOrNull(json['acceptedVersion']),
      convertedAt: CrmJson.strOrNull(json['convertedAt']),
      createdAt: CrmJson.str(json['createdAt']),
      versions: CrmJson.list(json['versions'], CrmQuoteVersionSummary.fromJson),
      version: CrmQuoteVersion.fromJson(CrmJson.map(json['version'])),
      procedure: procedure is Map ? CrmQuoteProcedureLink.fromJson(CrmJson.map(procedure)) : null,
      history: CrmJson.list(json['history'], CrmQuoteHistoryEntry.fromJson),
      approvalCheck: check is List ? CrmJson.list(check, CrmQuoteApprovalReason.fromJson) : null,
      businessPlan: plan is Map ? CrmBusinessPlan.fromJson(CrmJson.map(plan)) : null,
      hasBusinessPlanField: json.containsKey('businessPlan'),
      awaitingMyApproval: awaiting is Map ? CrmQuoteApprovalTarget.fromJson(CrmJson.map(awaiting)) : null,
    );
  }

  CrmQuoteDetail copyWith({String? code, CrmQuoteVersion? version}) => CrmQuoteDetail(
        summary: code == null
            ? summary
            : CrmQuoteSummary(
                id: summary.id,
                code: code,
                opportunityId: summary.opportunityId,
                opportunityName: summary.opportunityName,
                customerId: summary.customerId,
                customerCode: summary.customerCode,
                customerName: summary.customerName,
                ownerUserId: summary.ownerUserId,
                status: summary.status,
                currentVersion: summary.currentVersion,
                quoteName: summary.quoteName,
                validUntil: summary.validUntil,
                totalAmount: summary.totalAmount,
                updatedAt: summary.updatedAt,
              ),
        acceptedVersion: acceptedVersion,
        convertedAt: convertedAt,
        createdAt: createdAt,
        versions: versions,
        version: version ?? this.version,
        procedure: procedure,
        history: history,
        approvalCheck: approvalCheck,
        businessPlan: businessPlan,
        hasBusinessPlanField: hasBusinessPlanField,
        awaitingMyApproval: awaitingMyApproval,
      );
}

/// Một dòng khác nhau giữa hai phiên bản (contracts `QuoteLineDifference`).
class CrmQuoteLineDifference {
  final String materialId;
  final String materialCode;
  final String materialName;
  final String unit;

  /// ADDED | REMOVED | CHANGED.
  final String change;
  final List<String> fields;
  final Map<String, dynamic>? from;
  final Map<String, dynamic>? to;

  const CrmQuoteLineDifference({
    required this.materialId,
    required this.materialCode,
    required this.materialName,
    required this.unit,
    required this.change,
    this.fields = const [],
    this.from,
    this.to,
  });

  factory CrmQuoteLineDifference.fromJson(Map<String, dynamic> json) => CrmQuoteLineDifference(
        materialId: CrmJson.str(json['materialId']),
        materialCode: CrmJson.str(json['materialCode']),
        materialName: CrmJson.str(json['materialName']),
        unit: CrmJson.str(json['unit']),
        change: CrmJson.str(json['change']),
        fields: CrmJson.strings(json['fields']),
        from: json['from'] is Map ? CrmJson.map(json['from']) : null,
        to: json['to'] is Map ? CrmJson.map(json['to']) : null,
      );
}

class CrmQuoteComparison {
  final List<CrmQuoteLineDifference> lines;
  final double netDelta;
  final double vatDelta;
  final double totalDelta;
  final double profitDelta;

  const CrmQuoteComparison(
      {required this.lines, this.netDelta = 0, this.vatDelta = 0, this.totalDelta = 0, this.profitDelta = 0});

  factory CrmQuoteComparison.fromJson(Map<String, dynamic> json) {
    final delta = CrmJson.map(json['totalsDelta']);
    return CrmQuoteComparison(
      lines: CrmJson.list(json['lines'], CrmQuoteLineDifference.fromJson),
      netDelta: CrmJson.number(delta['netAmount']),
      vatDelta: CrmJson.number(delta['vatAmount']),
      totalDelta: CrmJson.number(delta['totalAmount']),
      profitDelta: CrmJson.number(delta['profit']),
    );
  }
}

/// Kết quả chuyển báo giá thành hợp đồng, đơn (contracts `ConvertQuoteResult`).
class CrmConvertQuoteResult {
  final bool created;
  final String contractCode;
  final String orderId;
  final String orderCode;
  const CrmConvertQuoteResult(
      {required this.created, required this.contractCode, required this.orderId, required this.orderCode});

  factory CrmConvertQuoteResult.fromJson(Map<String, dynamic> json) => CrmConvertQuoteResult(
        created: CrmJson.boolean(json['created']),
        contractCode: CrmJson.str(json['contractCode']),
        orderId: CrmJson.str(json['orderId']),
        orderCode: CrmJson.str(json['orderCode']),
      );
}

/// Việc "Cần tôi duyệt" (contracts `CrmTask`, phần khối đầu danh sách báo giá dùng).
class CrmQuoteTask {
  final String kind;
  final String quoteId;
  final String quoteCode;
  final String? quoteName;
  final int versionNo;
  final String? customerName;
  final double totalAmount;
  final CrmQuoteApprovalTarget? approval;

  const CrmQuoteTask({
    required this.kind,
    required this.quoteId,
    required this.quoteCode,
    this.quoteName,
    this.versionNo = 1,
    this.customerName,
    this.totalAmount = 0,
    this.approval,
  });

  bool get isWaiting => kind == 'QUOTE_PENDING' || kind == 'BUSINESS_PLAN_PENDING';
  bool get isBusinessPlan =>
      kind == 'BUSINESS_PLAN_APPROVAL' || kind == 'BUSINESS_PLAN_REJECTED' || kind == 'BUSINESS_PLAN_PENDING';

  factory CrmQuoteTask.fromJson(Map<String, dynamic> json) => CrmQuoteTask(
        kind: CrmJson.str(json['kind']),
        quoteId: CrmJson.str(json['quoteId']),
        quoteCode: CrmJson.str(json['quoteCode']),
        quoteName: CrmJson.strOrNull(json['quoteName']),
        versionNo: CrmJson.integer(json['versionNo'], 1),
        customerName: CrmJson.strOrNull(json['customerName']),
        totalAmount: CrmJson.number(json['totalAmount']),
        approval: json['approval'] is Map ? CrmQuoteApprovalTarget.fromJson(CrmJson.map(json['approval'])) : null,
      );
}

/// Bộ lọc `GET /quotes` (contracts `QuoteListQuery`).
class CrmQuoteListQuery {
  final String? q;
  final String? status;
  final String? ownerUserId;
  final bool awaitingMyApproval;
  final int? page;
  final int? limit;

  const CrmQuoteListQuery({this.q, this.status, this.ownerUserId, this.awaitingMyApproval = false, this.page, this.limit});

  Map<String, dynamic> toQuery() => {
        'q': q,
        'status': status,
        'ownerUserId': ownerUserId,
        // Chỉ gửi khi bật (web: `toQuery` đổi `false` thành chuỗi "false").
        'awaitingMyApproval': awaitingMyApproval ? 'true' : null,
        'page': page,
        'limit': limit,
      };
}
