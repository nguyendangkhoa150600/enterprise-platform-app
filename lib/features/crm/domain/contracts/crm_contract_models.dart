import '../common/crm_json.dart';
import '../crm_capabilities.dart';

/// Hợp đồng bán hàng, giá khung và đợt thanh toán (contracts `contracts.ts`, web `fulfillment.model.ts`).

/// Loại hợp đồng (contracts `CONTRACT_TYPES`).
const List<String> kCrmContractTypes = ['SALE', 'FRAMEWORK', 'PRINCIPLE'];

/// Trạng thái hợp đồng (contracts `CONTRACT_STATUSES`).
const List<String> kCrmContractStatuses = ['DRAFT', 'ACTIVE', 'COMPLETED', 'EXPIRED', 'LIQUIDATED', 'CANCELLED'];

/// Bảng chuyển trạng thái hợp đồng (contracts `CONTRACT_STATUS_TRANSITIONS`).
const Map<String, List<String>> kCrmContractTransitions = {
  'DRAFT': ['ACTIVE', 'CANCELLED'],
  'ACTIVE': ['COMPLETED', 'EXPIRED', 'CANCELLED'],
  'COMPLETED': ['LIQUIDATED'],
  'EXPIRED': ['LIQUIDATED'],
  'LIQUIDATED': [],
  'CANCELLED': [],
};

/// Điều kiện đến hạn của đợt thanh toán (contracts `PAYMENT_TERM_CONDITIONS`).
const List<String> kCrmPaymentTermConditions = ['DATE', 'SIGN', 'DELIVERY', 'FULL_DELIVERY', 'ACCEPTANCE'];

/// Trạng thái đợt thanh toán (contracts `PAYMENT_TERM_STATUSES`).
const List<String> kCrmPaymentTermStatuses = ['PENDING', 'DUE', 'INVOICED', 'PAID', 'CANCELLED'];

/// Trạng thái phần giữ hàng (contracts `RESERVATION_STATUSES`).
const List<String> kCrmReservationStatuses = ['HELD', 'RELEASED', 'EXPIRED', 'COMPLETED'];

/// Số ngày của bộ lọc "Sắp hết hạn" (web `expiringWithinDays: 30`).
const int kCrmContractExpiringDays = 30;

/// Một dòng nhật ký chuyển trạng thái (contracts `CrmHistoryEntry`, dùng cho hợp đồng và đơn bán).
class CrmHistoryEntry {
  final String id;
  final String at;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String? actorId;
  final String? reason;

  const CrmHistoryEntry({
    required this.id,
    required this.at,
    required this.action,
    this.fromStatus,
    this.toStatus,
    this.actorId,
    this.reason,
  });

  factory CrmHistoryEntry.fromJson(Map<String, dynamic> json) => CrmHistoryEntry(
        id: CrmJson.str(json['id']),
        at: CrmJson.str(json['at']),
        action: CrmJson.str(json['action']),
        fromStatus: CrmJson.strOrNull(json['fromStatus']),
        toStatus: CrmJson.strOrNull(json['toStatus']),
        actorId: CrmJson.strOrNull(json['actorId']),
        reason: CrmJson.strOrNull(json['reason']),
      );
}

/// Một dòng hợp đồng: giá khung (trước VAT); số lượng chỉ có với hợp đồng mua bán.
class CrmContractLine {
  final String id;
  final int lineNo;
  final String materialId;
  final String materialCode;
  final String materialName;
  final String unit;
  final String materialKind;
  final double? quantity;
  final double unitPrice;
  final double vatRate;
  final double discountPercent;
  final double? lineAmount;
  final String? note;

  /// Kho giữ hàng của dòng (D3-37); rỗng là theo kho mặc định của hợp đồng.
  final String? warehouseCode;

  const CrmContractLine({
    required this.id,
    required this.lineNo,
    required this.materialId,
    required this.materialCode,
    required this.materialName,
    required this.unit,
    required this.materialKind,
    this.quantity,
    required this.unitPrice,
    required this.vatRate,
    this.discountPercent = 0,
    this.lineAmount,
    this.note,
    this.warehouseCode,
  });

  bool get isService => materialKind == 'SERVICE';

  factory CrmContractLine.fromJson(Map<String, dynamic> json) => CrmContractLine(
        id: CrmJson.str(json['id']),
        lineNo: CrmJson.integer(json['lineNo']),
        materialId: CrmJson.str(json['materialId']),
        materialCode: CrmJson.str(json['materialCode']),
        materialName: CrmJson.str(json['materialName']),
        unit: CrmJson.str(json['unit']),
        materialKind: CrmJson.str(json['materialKind']),
        quantity: CrmJson.numOrNull(json['quantity']),
        unitPrice: CrmJson.number(json['unitPrice']),
        vatRate: CrmJson.number(json['vatRate']),
        discountPercent: CrmJson.number(json['discountPercent']),
        lineAmount: CrmJson.numOrNull(json['lineAmount']),
        note: CrmJson.strOrNull(json['note']),
        warehouseCode: CrmJson.strOrNull(json['warehouseCode']),
      );

  /// Dòng gửi lại khi thay toàn bộ dòng (web `contractLineRequest`, giữ kho riêng của dòng). [warehouseCode] thay kho.
  Map<String, dynamic> toRequest({String? warehouseCode, bool replaceWarehouse = false}) => {
        'materialId': materialId,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'vatRate': vatRate,
        'note': note,
        'warehouseCode': replaceWarehouse ? warehouseCode : this.warehouseCode,
      };
}

class CrmPaymentTerm {
  final String id;
  final int seq;
  final String name;
  final double? percent;
  final double amount;
  final String condition;
  final String? dueDate;
  final int? dueDays;
  final String status;
  final String? note;

  const CrmPaymentTerm({
    required this.id,
    required this.seq,
    required this.name,
    this.percent,
    required this.amount,
    required this.condition,
    this.dueDate,
    this.dueDays,
    required this.status,
    this.note,
  });

  factory CrmPaymentTerm.fromJson(Map<String, dynamic> json) => CrmPaymentTerm(
        id: CrmJson.str(json['id']),
        seq: CrmJson.integer(json['seq']),
        name: CrmJson.str(json['name']),
        percent: CrmJson.numOrNull(json['percent']),
        amount: CrmJson.number(json['amount']),
        condition: CrmJson.str(json['condition'], 'SIGN'),
        dueDate: CrmJson.strOrNull(json['dueDate']),
        dueDays: CrmJson.intOrNull(json['dueDays']),
        status: CrmJson.str(json['status'], 'PENDING'),
        note: CrmJson.strOrNull(json['note']),
      );
}

class CrmContractReservation {
  final String reservationId;
  final String reservationCode;
  final String status;
  final String? expiresAt;

  const CrmContractReservation({
    required this.reservationId,
    required this.reservationCode,
    required this.status,
    this.expiresAt,
  });

  factory CrmContractReservation.fromJson(Map<String, dynamic> json) => CrmContractReservation(
        reservationId: CrmJson.str(json['reservationId']),
        reservationCode: CrmJson.str(json['reservationCode']),
        status: CrmJson.str(json['status']),
        expiresAt: CrmJson.strOrNull(json['expiresAt']),
      );
}

/// Đơn bán gắn hợp đồng (contracts `ContractOrderRef`).
class CrmContractOrderRef {
  final String id;
  final String code;
  final String status;
  final double totalAmount;
  final String orderDate;

  const CrmContractOrderRef({
    required this.id,
    required this.code,
    required this.status,
    required this.totalAmount,
    required this.orderDate,
  });

  factory CrmContractOrderRef.fromJson(Map<String, dynamic> json) => CrmContractOrderRef(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        status: CrmJson.str(json['status']),
        totalAmount: CrmJson.number(json['totalAmount']),
        orderDate: CrmJson.str(json['orderDate']),
      );
}

class CrmContractSummary {
  final String id;
  final String code;
  final String type;
  final String title;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String status;
  final String validFrom;
  final String? validTo;
  final double value;
  final String ownerUserId;
  final String? quoteId;
  final String? quoteCode;
  final String updatedAt;

  const CrmContractSummary({
    required this.id,
    required this.code,
    required this.type,
    required this.title,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.status,
    required this.validFrom,
    this.validTo,
    required this.value,
    required this.ownerUserId,
    this.quoteId,
    this.quoteCode,
    this.updatedAt = '',
  });

  factory CrmContractSummary.fromJson(Map<String, dynamic> json) => CrmContractSummary(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        type: CrmJson.str(json['type'], 'SALE'),
        title: CrmJson.str(json['title']),
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        status: CrmJson.str(json['status'], 'DRAFT'),
        validFrom: CrmJson.str(json['validFrom']),
        validTo: CrmJson.strOrNull(json['validTo']),
        value: CrmJson.number(json['value']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        quoteId: CrmJson.strOrNull(json['quoteId']),
        quoteCode: CrmJson.strOrNull(json['quoteCode']),
        updatedAt: CrmJson.str(json['updatedAt']),
      );
}

class CrmContractDetail extends CrmContractSummary {
  final String? signedDate;
  final int? warrantyMonths;
  final String? warehouseCode;
  final String? note;

  /// Gửi lại khi sửa để không ghi đè người khác.
  final int revision;
  final List<CrmContractLine> lines;
  final List<CrmPaymentTerm> paymentTerms;
  final CrmContractReservation? reservation;
  final List<CrmContractOrderRef> orders;
  final List<CrmHistoryEntry> history;

  const CrmContractDetail({
    required super.id,
    required super.code,
    required super.type,
    required super.title,
    required super.customerId,
    required super.customerCode,
    required super.customerName,
    required super.status,
    required super.validFrom,
    super.validTo,
    required super.value,
    required super.ownerUserId,
    super.quoteId,
    super.quoteCode,
    super.updatedAt,
    this.signedDate,
    this.warrantyMonths,
    this.warehouseCode,
    this.note,
    required this.revision,
    this.lines = const [],
    this.paymentTerms = const [],
    this.reservation,
    this.orders = const [],
    this.history = const [],
  });

  factory CrmContractDetail.fromJson(Map<String, dynamic> json) {
    final s = CrmContractSummary.fromJson(json);
    final reservation = json['reservation'];
    return CrmContractDetail(
      id: s.id,
      code: s.code,
      type: s.type,
      title: s.title,
      customerId: s.customerId,
      customerCode: s.customerCode,
      customerName: s.customerName,
      status: s.status,
      validFrom: s.validFrom,
      validTo: s.validTo,
      value: s.value,
      ownerUserId: s.ownerUserId,
      quoteId: s.quoteId,
      quoteCode: s.quoteCode,
      updatedAt: s.updatedAt,
      signedDate: CrmJson.strOrNull(json['signedDate']),
      warrantyMonths: CrmJson.intOrNull(json['warrantyMonths']),
      warehouseCode: CrmJson.strOrNull(json['warehouseCode']),
      note: CrmJson.strOrNull(json['note']),
      revision: CrmJson.integer(json['revision']),
      lines: CrmJson.list(json['lines'], CrmContractLine.fromJson),
      paymentTerms: CrmJson.list(json['paymentTerms'], CrmPaymentTerm.fromJson),
      reservation: reservation is Map ? CrmContractReservation.fromJson(CrmJson.map(reservation)) : null,
      orders: CrmJson.list(json['orders'], CrmContractOrderRef.fromJson),
      history: CrmJson.list(json['history'], CrmHistoryEntry.fromJson),
    );
  }
}

/// Bộ lọc danh sách hợp đồng (contracts `ContractListQuery`).
class CrmContractListQuery {
  final String? q;
  final String? status;
  final String? type;
  final String? ownerUserId;
  final int? expiringWithinDays;
  final int? page;
  final int? limit;

  const CrmContractListQuery({
    this.q,
    this.status,
    this.type,
    this.ownerUserId,
    this.expiringWithinDays,
    this.page,
    this.limit,
  });

  Map<String, dynamic> toQuery() => {
        'q': q,
        'status': status,
        'type': type,
        'ownerUserId': ownerUserId,
        'expiringWithinDays': expiringWithinDays,
        'page': page,
        'limit': limit,
      };
}

// ---------------------------------------------------------------------------
// Logic thuần (web `fulfillment.model.ts`)
// ---------------------------------------------------------------------------

/// Thao tác trên hợp đồng (web `ContractUiAction`).
enum CrmContractAction { edit, confirm, complete, liquidate, cancel }

/// Web `contractActions`: nút nào hiện theo trạng thái và quyền `crm.contract.write`.
List<CrmContractAction> crmContractActions(String status, CrmCapabilities caps) {
  if (!(caps.isTenantAdmin || caps.canWriteContract)) return const [];
  final next = kCrmContractTransitions[status] ?? const <String>[];
  return [
    if (status == 'DRAFT') CrmContractAction.edit,
    if (next.contains('ACTIVE')) CrmContractAction.confirm,
    if (next.contains('COMPLETED')) CrmContractAction.complete,
    if (next.contains('LIQUIDATED')) CrmContractAction.liquidate,
    if (next.contains('CANCELLED')) CrmContractAction.cancel,
  ];
}

/// Web `canTriggerPaymentTerm`: đợt nghiệm thu / giao đủ ghi nhận tay khi hợp đồng Hiệu lực hoặc Hoàn thành.
bool crmCanTriggerPaymentTerm(String contractStatus, CrmPaymentTerm term, CrmCapabilities caps) {
  if (!(caps.isTenantAdmin || caps.canWriteContract)) return false;
  if (contractStatus != 'ACTIVE' && contractStatus != 'COMPLETED') return false;
  return (term.condition == 'ACCEPTANCE' || term.condition == 'FULL_DELIVERY') && term.status == 'PENDING';
}

/// Web `paymentTermTotals`: tổng phần trăm và số tiền của lưới đợt (đợt phần trăm quy ra tiền).
({double percent, double amount, bool balanced}) crmPaymentTermTotals(
  List<({double? percent, double? amount})> terms,
  double value,
) {
  var percent = 0.0;
  var amount = 0.0;
  for (final term in terms) {
    if (term.percent != null) {
      percent += term.percent!;
      amount += (value * term.percent! / 100).roundToDouble();
    } else if (term.amount != null) {
      amount += term.amount!;
      percent += value > 0 ? term.amount! / value * 100 : 0;
    }
  }
  final rounded = (percent * 10000).roundToDouble() / 10000;
  return (percent: rounded, amount: amount, balanced: terms.isEmpty || (amount - value).abs() <= terms.length);
}
