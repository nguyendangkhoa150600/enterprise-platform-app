import '../common/crm_json.dart';
import '../contracts/crm_contract_models.dart';
import '../crm_capabilities.dart';

/// Đơn bán, kế hoạch giao nhiều đợt (contracts `orders.ts`, web `fulfillment.model.ts`).

/// Nguồn đơn (contracts `SALES_ORDER_SOURCES`).
const List<String> kCrmOrderSources = ['QUOTE', 'CONTRACT', 'DIRECT'];

/// Trạng thái đơn bán (contracts `SALES_ORDER_STATUSES`).
const List<String> kCrmOrderStatuses = [
  'DRAFT',
  'CREDIT_PENDING',
  'CONFIRMED',
  'DELIVERING',
  'PARTIAL',
  'DELIVERED',
  'DONE',
  'CANCELLED',
];

/// Bảng chuyển trạng thái đơn (contracts `SALES_ORDER_STATUS_TRANSITIONS`).
const Map<String, List<String>> kCrmOrderTransitions = {
  'DRAFT': ['CONFIRMED', 'CREDIT_PENDING', 'CANCELLED'],
  'CREDIT_PENDING': ['CONFIRMED', 'DRAFT', 'CANCELLED'],
  'CONFIRMED': ['DELIVERING', 'CANCELLED'],
  'DELIVERING': ['PARTIAL', 'DELIVERED', 'CANCELLED'],
  'PARTIAL': ['DELIVERING', 'DELIVERED', 'CANCELLED'],
  'DELIVERED': ['DONE'],
  'DONE': [],
  'CANCELLED': [],
};

/// Độ dài tối đa ghi chú thông tin đơn hàng (contracts `ORDER_INFO_NOTE_MAX`).
const int kCrmOrderInfoNoteMax = 4000;

class CrmOrderLine {
  final String id;
  final int lineNo;
  final String materialId;
  final String materialCode;
  final String materialName;
  final String unit;
  final String materialKind;
  final double quantity;
  final String priceSource;
  final String? priceReferenceCode;
  final double discountPercent;
  final double? overrideUnitPrice;
  final double? overrideDiscountPercent;
  final double? overrideVatRate;
  final double unitPrice;
  final double vatRate;
  final double lineAmount;
  final String? warehouseCode;
  final double reservedQuantity;
  final double plannedQuantity;
  final double deliveredQuantity;
  final double actualCost;
  final List<String> serials;
  final String? reservationStatus;
  final String? reservationSource;

  const CrmOrderLine({
    required this.id,
    required this.lineNo,
    required this.materialId,
    required this.materialCode,
    required this.materialName,
    required this.unit,
    required this.materialKind,
    required this.quantity,
    required this.priceSource,
    this.priceReferenceCode,
    required this.discountPercent,
    this.overrideUnitPrice,
    this.overrideDiscountPercent,
    this.overrideVatRate,
    required this.unitPrice,
    required this.vatRate,
    required this.lineAmount,
    this.warehouseCode,
    required this.reservedQuantity,
    required this.plannedQuantity,
    required this.deliveredQuantity,
    required this.actualCost,
    this.serials = const [],
    this.reservationStatus,
    this.reservationSource,
  });

  bool get isService => materialKind == 'SERVICE';

  factory CrmOrderLine.fromJson(Map<String, dynamic> json) => CrmOrderLine(
        id: CrmJson.str(json['id']),
        lineNo: CrmJson.integer(json['lineNo']),
        materialId: CrmJson.str(json['materialId']),
        materialCode: CrmJson.str(json['materialCode']),
        materialName: CrmJson.str(json['materialName']),
        unit: CrmJson.str(json['unit']),
        materialKind: CrmJson.str(json['materialKind']),
        quantity: CrmJson.number(json['quantity']),
        priceSource: CrmJson.str(json['priceSource']),
        priceReferenceCode: CrmJson.strOrNull(json['priceReferenceCode']),
        discountPercent: CrmJson.number(json['discountPercent']),
        overrideUnitPrice: CrmJson.numOrNull(json['overrideUnitPrice']),
        overrideDiscountPercent: CrmJson.numOrNull(json['overrideDiscountPercent']),
        overrideVatRate: CrmJson.numOrNull(json['overrideVatRate']),
        unitPrice: CrmJson.number(json['unitPrice']),
        vatRate: CrmJson.number(json['vatRate']),
        lineAmount: CrmJson.number(json['lineAmount']),
        warehouseCode: CrmJson.strOrNull(json['warehouseCode']),
        reservedQuantity: CrmJson.number(json['reservedQuantity']),
        plannedQuantity: CrmJson.number(json['plannedQuantity']),
        deliveredQuantity: CrmJson.number(json['deliveredQuantity']),
        actualCost: CrmJson.number(json['actualCost']),
        serials: CrmJson.strings(json['serials']),
        reservationStatus: CrmJson.strOrNull(json['reservationStatus']),
        reservationSource: CrmJson.strOrNull(json['reservationSource']),
      );

  /// Dòng gửi lại khi thay toàn bộ dòng của đơn Nháp (web `lineRequest`).
  Map<String, dynamic> toRequest() => {
        'materialId': materialId,
        'quantity': quantity,
        'unit': unit,
        'overrideUnitPrice': overrideUnitPrice,
        'overrideDiscountPercent': overrideDiscountPercent,
        'overrideVatRate': overrideVatRate,
        'warehouseCode': warehouseCode,
      };
}

class CrmDeliveryLine {
  final String id;
  final String orderLineId;
  final int lineNo;
  final String materialCode;
  final String materialName;
  final String unit;
  final String materialKind;
  final double plannedQuantity;
  final double deliveredQuantity;
  final double actualCost;
  final List<String> serials;

  const CrmDeliveryLine({
    required this.id,
    required this.orderLineId,
    required this.lineNo,
    required this.materialCode,
    required this.materialName,
    required this.unit,
    required this.materialKind,
    required this.plannedQuantity,
    required this.deliveredQuantity,
    required this.actualCost,
    this.serials = const [],
  });

  factory CrmDeliveryLine.fromJson(Map<String, dynamic> json) => CrmDeliveryLine(
        id: CrmJson.str(json['id']),
        orderLineId: CrmJson.str(json['orderLineId']),
        lineNo: CrmJson.integer(json['lineNo']),
        materialCode: CrmJson.str(json['materialCode']),
        materialName: CrmJson.str(json['materialName']),
        unit: CrmJson.str(json['unit']),
        materialKind: CrmJson.str(json['materialKind']),
        plannedQuantity: CrmJson.number(json['plannedQuantity']),
        deliveredQuantity: CrmJson.number(json['deliveredQuantity']),
        actualCost: CrmJson.number(json['actualCost']),
        serials: CrmJson.strings(json['serials']),
      );
}

class CrmDeliveryPlan {
  final String id;
  final String code;
  final int seq;
  final String plannedDate;
  final String? warehouseCode;
  final String? address;
  final String? note;
  final String status;
  final String? issueDocumentCode;
  final bool late;
  final List<CrmDeliveryLine> lines;

  const CrmDeliveryPlan({
    required this.id,
    required this.code,
    required this.seq,
    required this.plannedDate,
    this.warehouseCode,
    this.address,
    this.note,
    required this.status,
    this.issueDocumentCode,
    this.late = false,
    this.lines = const [],
  });

  factory CrmDeliveryPlan.fromJson(Map<String, dynamic> json) => CrmDeliveryPlan(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        seq: CrmJson.integer(json['seq']),
        plannedDate: CrmJson.str(json['plannedDate']),
        warehouseCode: CrmJson.strOrNull(json['warehouseCode']),
        address: CrmJson.strOrNull(json['address']),
        note: CrmJson.strOrNull(json['note']),
        status: CrmJson.str(json['status'], 'PLANNED'),
        issueDocumentCode: CrmJson.strOrNull(json['issueDocumentCode']),
        late: CrmJson.boolean(json['late']),
        lines: CrmJson.list(json['lines'], CrmDeliveryLine.fromJson),
      );
}

class CrmOrderTotals {
  final double netAmount;
  final double shippingAmount;
  final double vatAmount;
  final double totalAmount;

  const CrmOrderTotals({
    this.netAmount = 0,
    this.shippingAmount = 0,
    this.vatAmount = 0,
    this.totalAmount = 0,
  });

  factory CrmOrderTotals.fromJson(Map<String, dynamic> json) => CrmOrderTotals(
        netAmount: CrmJson.number(json['netAmount']),
        shippingAmount: CrmJson.number(json['shippingAmount']),
        vatAmount: CrmJson.number(json['vatAmount']),
        totalAmount: CrmJson.number(json['totalAmount']),
      );
}

/// Công nợ của đơn theo sổ (contracts `OrderReceivableBalance`).
class CrmOrderReceivable {
  final double debited;
  final double collected;
  final double adjusted;
  final double outstanding;

  const CrmOrderReceivable({
    required this.debited,
    required this.collected,
    required this.adjusted,
    required this.outstanding,
  });

  factory CrmOrderReceivable.fromJson(Map<String, dynamic> json) => CrmOrderReceivable(
        debited: CrmJson.number(json['debited']),
        collected: CrmJson.number(json['collected']),
        adjusted: CrmJson.number(json['adjusted']),
        outstanding: CrmJson.number(json['outstanding']),
      );
}

/// Yêu cầu duyệt vượt hạn mức gần nhất của đơn (contracts `OrderCreditRequest`).
class CrmOrderCreditRequest {
  final String id;
  final String status;

  /// `DIRECT` (duyệt trong Bán hàng) hoặc `PROCEDURE` (duyệt trên Quy trình).
  final String mode;
  final double orderAmount;
  final double balance;
  final double creditLimit;
  final String? message;
  final String? decidedBy;
  final String? decisionNote;
  final String? procedureInstanceCode;

  const CrmOrderCreditRequest({
    required this.id,
    required this.status,
    required this.mode,
    required this.orderAmount,
    required this.balance,
    required this.creditLimit,
    this.message,
    this.decidedBy,
    this.decisionNote,
    this.procedureInstanceCode,
  });

  factory CrmOrderCreditRequest.fromJson(Map<String, dynamic> json) => CrmOrderCreditRequest(
        id: CrmJson.str(json['id']),
        status: CrmJson.str(json['status']),
        mode: CrmJson.str(json['mode']),
        orderAmount: CrmJson.number(json['orderAmount']),
        balance: CrmJson.number(json['balance']),
        creditLimit: CrmJson.number(json['creditLimit']),
        message: CrmJson.strOrNull(json['message']),
        decidedBy: CrmJson.strOrNull(json['decidedBy']),
        decisionNote: CrmJson.strOrNull(json['decisionNote']),
        procedureInstanceCode: CrmJson.strOrNull(json['procedureInstanceCode']),
      );
}

class CrmOrderSummary {
  final String id;
  final String code;
  final String source;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String? contractId;
  final String? contractCode;
  final String? quoteId;
  final String? quoteCode;
  final String status;
  final String orderDate;
  final String? expectedDeliveryDate;
  final double totalAmount;
  final String ownerUserId;
  final bool late;
  final double? outstanding;

  const CrmOrderSummary({
    required this.id,
    required this.code,
    required this.source,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    this.contractId,
    this.contractCode,
    this.quoteId,
    this.quoteCode,
    required this.status,
    required this.orderDate,
    this.expectedDeliveryDate,
    required this.totalAmount,
    required this.ownerUserId,
    this.late = false,
    this.outstanding,
  });

  factory CrmOrderSummary.fromJson(Map<String, dynamic> json) => CrmOrderSummary(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        source: CrmJson.str(json['source'], 'DIRECT'),
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        contractId: CrmJson.strOrNull(json['contractId']),
        contractCode: CrmJson.strOrNull(json['contractCode']),
        quoteId: CrmJson.strOrNull(json['quoteId']),
        quoteCode: CrmJson.strOrNull(json['quoteCode']),
        status: CrmJson.str(json['status'], 'DRAFT'),
        orderDate: CrmJson.str(json['orderDate']),
        expectedDeliveryDate: CrmJson.strOrNull(json['expectedDeliveryDate']),
        totalAmount: CrmJson.number(json['totalAmount']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        late: CrmJson.boolean(json['late']),
        outstanding: CrmJson.numOrNull(json['outstanding']),
      );
}

class CrmOrderDetail {
  final CrmOrderSummary summary;
  final String? warehouseCode;
  final String? deliveryAddress;
  final String? note;
  final String? infoNote;
  final String? infoNotedBy;
  final String? infoNotedAt;
  final String? priceDate;
  final String? priceListId;
  final String? priceListCode;
  final String? priceListName;
  final String? priceListStatus;
  final CrmOrderTotals totals;
  final int revision;
  final List<CrmOrderLine> lines;
  final List<CrmDeliveryPlan> deliveries;
  final String? reservationExpiresAt;
  final String? cancelReason;
  final String? closeReason;
  final List<CrmHistoryEntry> history;
  final CrmOrderReceivable? receivable;
  final CrmOrderCreditRequest? creditRequest;

  const CrmOrderDetail({
    required this.summary,
    this.warehouseCode,
    this.deliveryAddress,
    this.note,
    this.infoNote,
    this.infoNotedBy,
    this.infoNotedAt,
    this.priceDate,
    this.priceListId,
    this.priceListCode,
    this.priceListName,
    this.priceListStatus,
    this.totals = const CrmOrderTotals(),
    required this.revision,
    this.lines = const [],
    this.deliveries = const [],
    this.reservationExpiresAt,
    this.cancelReason,
    this.closeReason,
    this.history = const [],
    this.receivable,
    this.creditRequest,
  });

  String get id => summary.id;
  String get code => summary.code;
  String get status => summary.status;
  String get source => summary.source;
  String get customerId => summary.customerId;

  factory CrmOrderDetail.fromJson(Map<String, dynamic> json) {
    final receivable = json['receivable'];
    final credit = json['creditRequest'];
    return CrmOrderDetail(
      summary: CrmOrderSummary.fromJson(json),
      warehouseCode: CrmJson.strOrNull(json['warehouseCode']),
      deliveryAddress: CrmJson.strOrNull(json['deliveryAddress']),
      note: CrmJson.strOrNull(json['note']),
      infoNote: CrmJson.strOrNull(json['infoNote']),
      infoNotedBy: CrmJson.strOrNull(json['infoNotedBy']),
      infoNotedAt: CrmJson.strOrNull(json['infoNotedAt']),
      priceDate: CrmJson.strOrNull(json['priceDate']),
      priceListId: CrmJson.strOrNull(json['priceListId']),
      priceListCode: CrmJson.strOrNull(json['priceListCode']),
      priceListName: CrmJson.strOrNull(json['priceListName']),
      priceListStatus: CrmJson.strOrNull(json['priceListStatus']),
      totals: CrmOrderTotals.fromJson(CrmJson.map(json['totals'])),
      revision: CrmJson.integer(json['revision']),
      lines: CrmJson.list(json['lines'], CrmOrderLine.fromJson),
      deliveries: CrmJson.list(json['deliveries'], CrmDeliveryPlan.fromJson),
      reservationExpiresAt: CrmJson.strOrNull(json['reservationExpiresAt']),
      cancelReason: CrmJson.strOrNull(json['cancelReason']),
      closeReason: CrmJson.strOrNull(json['closeReason']),
      history: CrmJson.list(json['history'], CrmHistoryEntry.fromJson),
      receivable: receivable is Map ? CrmOrderReceivable.fromJson(CrmJson.map(receivable)) : null,
      creditRequest: credit is Map ? CrmOrderCreditRequest.fromJson(CrmJson.map(credit)) : null,
    );
  }
}

/// Bộ lọc danh sách đơn (contracts `SalesOrderListQuery`).
class CrmOrderListQuery {
  final String? q;
  final String? status;
  final String? ownerUserId;
  final bool late;
  final int? page;
  final int? limit;

  const CrmOrderListQuery({this.q, this.status, this.ownerUserId, this.late = false, this.page, this.limit});

  Map<String, dynamic> toQuery() => {
        'q': q,
        'status': status,
        'ownerUserId': ownerUserId,
        'late': late ? 'true' : null,
        'page': page,
        'limit': limit,
      };
}

/// Bảng giá để chọn ở đơn (contracts `PriceListSummary`, phần dùng ở ô chọn).
class CrmPriceListOption {
  final String id;
  final String code;
  final String name;
  final String validFrom;
  final String? validTo;
  final String status;

  const CrmPriceListOption({
    required this.id,
    required this.code,
    required this.name,
    required this.validFrom,
    this.validTo,
    required this.status,
  });

  factory CrmPriceListOption.fromJson(Map<String, dynamic> json) => CrmPriceListOption(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        validFrom: CrmJson.str(json['validFrom']),
        validTo: CrmJson.strOrNull(json['validTo']),
        status: CrmJson.str(json['status']),
      );

  /// Web `isPriceListEffective`: đang bật và còn hiệu lực tại [date] (`YYYY-MM-DD`).
  bool effectiveOn(String date) =>
      status == 'ACTIVE' &&
      validFrom.compareTo(date) <= 0 &&
      (validTo == null || validTo!.isEmpty || validTo!.compareTo(date) >= 0);
}

// ---------------------------------------------------------------------------
// Logic thuần (web `fulfillment.model.ts`)
// ---------------------------------------------------------------------------

/// Web `OrderUiAction`.
enum CrmOrderAction { edit, confirm, plan, cancel, close }

/// Web `orderActions`.
List<CrmOrderAction> crmOrderActions(CrmOrderDetail detail, CrmCapabilities caps) {
  if (!(caps.isTenantAdmin || caps.canWriteOrder)) return const [];
  final status = detail.status;
  final next = kCrmOrderTransitions[status] ?? const <String>[];
  return [
    if (status == 'DRAFT') CrmOrderAction.edit,
    // Chờ duyệt hạn mức chỉ sang Đã xác nhận qua quyết định duyệt (D5), không xác nhận tay.
    if (next.contains('CONFIRMED') && detail.lines.isNotEmpty && status != 'CREDIT_PENDING') CrmOrderAction.confirm,
    if (const ['DRAFT', 'CREDIT_PENDING', 'CONFIRMED', 'DELIVERING', 'PARTIAL'].contains(status)) CrmOrderAction.plan,
    if (next.contains('CANCELLED')) CrmOrderAction.cancel,
    if (next.contains('DONE') && (caps.isTenantAdmin || caps.canReadAll || caps.canManage)) CrmOrderAction.close,
  ];
}

/// Web `canRequestDelivery`: đợt Kế hoạch của đơn đã xác nhận, chưa giao đủ.
bool crmCanRequestDelivery(String orderStatus, CrmDeliveryPlan delivery) =>
    const ['CONFIRMED', 'DELIVERING', 'PARTIAL'].contains(orderStatus) && delivery.status == 'PLANNED';

/// Web `canApproveReceivable`: duyệt vượt hạn mức trực tiếp.
bool crmCanApproveReceivable(CrmCapabilities caps) => caps.isTenantAdmin || caps.canManage || caps.canReadAll;

/// Web `remainingToPlan`: số còn lập đợt được của từng dòng; sửa một đợt thì cộng lại phần của chính đợt đó.
Map<String, double> crmRemainingToPlan(CrmOrderDetail order, [CrmDeliveryPlan? editing]) {
  final remaining = <String, double>{};
  for (final line in order.lines) {
    var own = 0.0;
    for (final entry in editing?.lines ?? const <CrmDeliveryLine>[]) {
      if (entry.orderLineId == line.id) own = entry.plannedQuantity;
    }
    final value = ((line.quantity - line.plannedQuantity + own) * 1000).roundToDouble() / 1000;
    remaining[line.id] = value < 0 ? 0 : value;
  }
  return remaining;
}
