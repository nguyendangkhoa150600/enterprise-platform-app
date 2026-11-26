import '../common/crm_json.dart';
import '../crm_capabilities.dart';

/// Công nợ phải thu (contracts `receivables.ts`): sổ công nợ chỉ ghi thêm, lần thu tiền sinh phiếu thu nháp bên
/// Tài chính, phân bổ, điều chỉnh có duyệt, tuổi nợ, hạn mức công nợ.

/// Nhóm tuổi nợ (contracts `AGING_BUCKETS`), đúng thứ tự hiển thị.
const List<String> kCrmAgingBuckets = ['NOT_DUE', 'D0_30', 'D31_60', 'D61_90', 'D90_PLUS'];

/// Trạng thái lần thu (contracts `RECEIPT_STATUSES`).
const List<String> kCrmReceiptStatuses = [
  'PENDING_VOUCHER',
  'VOUCHER_DRAFT',
  'POSTED',
  'RETURNED',
  'REVERSED',
  'CANCELLED',
];

/// Hình thức thu (contracts `RECEIPT_METHODS`).
const List<String> kCrmReceiptMethods = ['CASH', 'BANK_TRANSFER'];

/// Loại điều chỉnh (contracts `ADJUSTMENT_DIRECTIONS`).
const List<String> kCrmAdjustmentDirections = ['DECREASE', 'INCREASE'];

/// Trạng thái điều chỉnh (contracts `ADJUSTMENT_STATUSES`).
const List<String> kCrmAdjustmentStatuses = ['DRAFT', 'APPROVED', 'CANCELLED'];

/// Vượt hạn mức công nợ khi xác nhận đơn (contracts `CREDIT_LIMIT_MODES`).
const List<String> kCrmCreditLimitModes = ['APPROVAL', 'BLOCK'];

/// Số tiền theo nhóm tuổi nợ.
class CrmAgingTotals {
  final Map<String, double> values;
  const CrmAgingTotals(this.values);

  factory CrmAgingTotals.fromJson(Object? raw) {
    final json = CrmJson.map(raw);
    return CrmAgingTotals({for (final b in kCrmAgingBuckets) b: CrmJson.number(json[b])});
  }

  double operator [](String bucket) => values[bucket] ?? 0;
}

/// Một dòng tuổi nợ theo khách (contracts `CustomerAgingRow`).
class CrmCustomerAgingRow {
  final String customerId;
  final String customerCode;
  final String customerName;
  final String ownerUserId;
  final double? creditLimit;
  final int? paymentTermDays;
  final double balance;
  final double overdueAmount;
  final CrmAgingTotals buckets;
  final bool creditExceeded;

  const CrmCustomerAgingRow({
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.ownerUserId,
    required this.creditLimit,
    required this.paymentTermDays,
    required this.balance,
    required this.overdueAmount,
    required this.buckets,
    required this.creditExceeded,
  });

  factory CrmCustomerAgingRow.fromJson(Map<String, dynamic> json) => CrmCustomerAgingRow(
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        creditLimit: CrmJson.numOrNull(json['creditLimit']),
        paymentTermDays: CrmJson.intOrNull(json['paymentTermDays']),
        balance: CrmJson.number(json['balance']),
        overdueAmount: CrmJson.number(json['overdueAmount']),
        buckets: CrmAgingTotals.fromJson(json['buckets']),
        creditExceeded: CrmJson.boolean(json['creditExceeded']),
      );
}

/// Một dòng sổ công nợ (contracts `ReceivableEntry`); [amount] có dấu: dương tăng nợ, âm giảm nợ.
class CrmReceivableEntry {
  final String id;
  final String kind;
  final String? orderId;
  final String? orderCode;
  final String? contractCode;
  final String? receiptCode;
  final String? adjustmentCode;
  final double amount;
  final String entryDate;
  final String? dueDate;
  final String? description;

  const CrmReceivableEntry({
    required this.id,
    required this.kind,
    this.orderId,
    this.orderCode,
    this.contractCode,
    this.receiptCode,
    this.adjustmentCode,
    required this.amount,
    required this.entryDate,
    this.dueDate,
    this.description,
  });

  factory CrmReceivableEntry.fromJson(Map<String, dynamic> json) => CrmReceivableEntry(
        id: CrmJson.str(json['id']),
        kind: CrmJson.str(json['kind']),
        orderId: CrmJson.strOrNull(json['orderId']),
        orderCode: CrmJson.strOrNull(json['orderCode']),
        contractCode: CrmJson.strOrNull(json['contractCode']),
        receiptCode: CrmJson.strOrNull(json['receiptCode']),
        adjustmentCode: CrmJson.strOrNull(json['adjustmentCode']),
        amount: CrmJson.number(json['amount']),
        entryDate: CrmJson.str(json['entryDate']),
        dueDate: CrmJson.strOrNull(json['dueDate']),
        description: CrmJson.strOrNull(json['description']),
      );

  /// Cột "Chứng từ" của web: lần thu, điều chỉnh, hợp đồng hoặc đơn.
  String get reference => receiptCode ?? adjustmentCode ?? contractCode ?? orderCode ?? '';
}

/// Khoản nợ còn mở (contracts `ReceivableOpenItem`).
class CrmReceivableOpenItem {
  final String entryId;
  final String kind;
  final String? orderId;
  final String? orderCode;
  final String? description;
  final String entryDate;
  final String? dueDate;
  final double amount;
  final double openAmount;
  final double pendingAmount;
  final double allocatableAmount;
  final int? daysOverdue;
  final String bucket;

  const CrmReceivableOpenItem({
    required this.entryId,
    required this.kind,
    this.orderId,
    this.orderCode,
    this.description,
    required this.entryDate,
    this.dueDate,
    required this.amount,
    required this.openAmount,
    required this.pendingAmount,
    required this.allocatableAmount,
    this.daysOverdue,
    required this.bucket,
  });

  factory CrmReceivableOpenItem.fromJson(Map<String, dynamic> json) => CrmReceivableOpenItem(
        entryId: CrmJson.str(json['entryId']),
        kind: CrmJson.str(json['kind']),
        orderId: CrmJson.strOrNull(json['orderId']),
        orderCode: CrmJson.strOrNull(json['orderCode']),
        description: CrmJson.strOrNull(json['description']),
        entryDate: CrmJson.str(json['entryDate']),
        dueDate: CrmJson.strOrNull(json['dueDate']),
        amount: CrmJson.number(json['amount']),
        openAmount: CrmJson.number(json['openAmount']),
        pendingAmount: CrmJson.number(json['pendingAmount']),
        allocatableAmount: CrmJson.number(json['allocatableAmount']),
        daysOverdue: CrmJson.intOrNull(json['daysOverdue']),
        bucket: CrmJson.str(json['bucket'], 'NOT_DUE'),
      );

  /// Bản sao với số còn phân bổ được khác (sửa lần thu: cộng lại phần đang giữ của chính nó).
  CrmReceivableOpenItem withAllocatable(double value) => CrmReceivableOpenItem(
        entryId: entryId,
        kind: kind,
        orderId: orderId,
        orderCode: orderCode,
        description: description,
        entryDate: entryDate,
        dueDate: dueDate,
        amount: amount,
        openAmount: openAmount,
        pendingAmount: pendingAmount,
        allocatableAmount: value,
        daysOverdue: daysOverdue,
        bucket: bucket,
      );
}

/// Sổ công nợ của một khách (contracts `CustomerLedger`).
class CrmCustomerLedger {
  final String customerId;
  final String customerCode;
  final String customerName;
  final String ownerUserId;
  final double? creditLimit;
  final int? paymentTermDays;
  final double balance;
  final double overdueAmount;
  final CrmAgingTotals buckets;
  final bool creditExceeded;
  final double unappliedAmount;
  final List<CrmReceivableOpenItem> openItems;
  final List<CrmReceivableEntry> entries;

  const CrmCustomerLedger({
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.ownerUserId,
    required this.creditLimit,
    required this.paymentTermDays,
    required this.balance,
    required this.overdueAmount,
    required this.buckets,
    required this.creditExceeded,
    required this.unappliedAmount,
    required this.openItems,
    required this.entries,
  });

  factory CrmCustomerLedger.fromJson(Map<String, dynamic> json) => CrmCustomerLedger(
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        creditLimit: CrmJson.numOrNull(json['creditLimit']),
        paymentTermDays: CrmJson.intOrNull(json['paymentTermDays']),
        balance: CrmJson.number(json['balance']),
        overdueAmount: CrmJson.number(json['overdueAmount']),
        buckets: CrmAgingTotals.fromJson(json['buckets']),
        creditExceeded: CrmJson.boolean(json['creditExceeded']),
        unappliedAmount: CrmJson.number(json['unappliedAmount']),
        openItems: CrmJson.list(json['openItems'], CrmReceivableOpenItem.fromJson),
        entries: CrmJson.list(json['entries'], CrmReceivableEntry.fromJson),
      );
}

/// Một dòng phân bổ của lần thu (contracts `ReceiptAllocation`).
class CrmReceiptAllocation {
  final String id;
  final String entryId;
  final String? orderCode;
  final String? entryDescription;
  final String? dueDate;
  final double amount;
  final bool effective;

  const CrmReceiptAllocation({
    required this.id,
    required this.entryId,
    this.orderCode,
    this.entryDescription,
    this.dueDate,
    required this.amount,
    required this.effective,
  });

  factory CrmReceiptAllocation.fromJson(Map<String, dynamic> json) => CrmReceiptAllocation(
        id: CrmJson.str(json['id']),
        entryId: CrmJson.str(json['entryId']),
        orderCode: CrmJson.strOrNull(json['orderCode']),
        entryDescription: CrmJson.strOrNull(json['entryDescription']),
        dueDate: CrmJson.strOrNull(json['dueDate']),
        amount: CrmJson.number(json['amount']),
        effective: CrmJson.boolean(json['effective']),
      );
}

/// Lần thu tiền (contracts `ReceiptSummary` + phần chi tiết `ReceiptDetail`; danh sách không có phần chi tiết).
class CrmReceipt {
  final String id;
  final String code;
  final String customerId;
  final String customerCode;
  final String customerName;
  final double amount;
  final double allocatedAmount;
  final String method;
  final String receiptDate;
  final String status;
  final String? financeVoucherCode;
  final String createdBy;
  final String? note;
  final String? voucherError;
  final String? returnReason;
  final int revision;
  final List<CrmReceiptAllocation> allocations;

  const CrmReceipt({
    required this.id,
    required this.code,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.amount,
    required this.allocatedAmount,
    required this.method,
    required this.receiptDate,
    required this.status,
    this.financeVoucherCode,
    required this.createdBy,
    this.note,
    this.voucherError,
    this.returnReason,
    this.revision = 0,
    this.allocations = const [],
  });

  factory CrmReceipt.fromJson(Map<String, dynamic> json) => CrmReceipt(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        amount: CrmJson.number(json['amount']),
        allocatedAmount: CrmJson.number(json['allocatedAmount']),
        method: CrmJson.str(json['method']),
        receiptDate: CrmJson.str(json['receiptDate']),
        status: CrmJson.str(json['status']),
        financeVoucherCode: CrmJson.strOrNull(json['financeVoucherCode']),
        createdBy: CrmJson.str(json['createdBy']),
        note: CrmJson.strOrNull(json['note']),
        voucherError: CrmJson.strOrNull(json['voucherError']),
        returnReason: CrmJson.strOrNull(json['returnReason']),
        revision: CrmJson.integer(json['revision']),
        allocations: CrmJson.list(json['allocations'], CrmReceiptAllocation.fromJson),
      );
}

/// Điều chỉnh công nợ (contracts `ReceivableAdjustment`).
class CrmReceivableAdjustment {
  final String id;
  final String code;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String? orderCode;
  final String direction;
  final double amount;
  final String reason;
  final String status;
  final String? approvedBy;
  final int revision;
  final String createdBy;

  const CrmReceivableAdjustment({
    required this.id,
    required this.code,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    this.orderCode,
    required this.direction,
    required this.amount,
    required this.reason,
    required this.status,
    this.approvedBy,
    required this.revision,
    required this.createdBy,
  });

  factory CrmReceivableAdjustment.fromJson(Map<String, dynamic> json) => CrmReceivableAdjustment(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        orderCode: CrmJson.strOrNull(json['orderCode']),
        direction: CrmJson.str(json['direction']),
        amount: CrmJson.number(json['amount']),
        reason: CrmJson.str(json['reason']),
        status: CrmJson.str(json['status']),
        approvedBy: CrmJson.strOrNull(json['approvedBy']),
        revision: CrmJson.integer(json['revision']),
        createdBy: CrmJson.str(json['createdBy']),
      );
}

/// Cấu hình công nợ (contracts `ReceivableSettings`).
class CrmReceivableSettings {
  final String recognitionMode;
  final String creditLimitMode;
  final List<String> alertUserIds;

  const CrmReceivableSettings({
    required this.recognitionMode,
    required this.creditLimitMode,
    required this.alertUserIds,
  });

  factory CrmReceivableSettings.fromJson(Map<String, dynamic> json) => CrmReceivableSettings(
        recognitionMode: CrmJson.str(json['recognitionMode'], 'ON_DELIVERY'),
        creditLimitMode: CrmJson.str(json['creditLimitMode'], 'APPROVAL'),
        alertUserIds: CrmJson.strings(json['alertUserIds']),
      );
}

// ---------------------------------------------------------------------------
// Logic thuần (web `receivables.model.ts`): chỉ để ẩn hiện nút, server kiểm lại.
// ---------------------------------------------------------------------------

/// Được thu tiền, lập điều chỉnh (`crm.receivable.write`).
bool crmCanWriteReceivable(CrmCapabilities c) => c.isTenantAdmin || c.canWriteReceivable;

/// Được duyệt điều chỉnh: quản lý kinh doanh (thấy toàn bộ dữ liệu).
bool crmCanApproveReceivable(CrmCapabilities c) => c.isTenantAdmin || c.canManage || c.canReadAll;

/// Thao tác trên lần thu: bị trả lại hoặc Tài chính từ chối → sửa gửi lại (`resend`) hoặc huỷ (`cancel`).
List<String> crmReceiptActions(CrmReceipt receipt, CrmCapabilities c) {
  if (!crmCanWriteReceivable(c)) return const [];
  final fixable = receipt.status == 'RETURNED' ||
      (receipt.status == 'PENDING_VOUCHER' && (receipt.voucherError?.isNotEmpty ?? false));
  return fixable ? const ['resend', 'cancel'] : const [];
}

/// Thao tác trên điều chỉnh: duyệt (người khác người lập), huỷ (người lập hoặc người duyệt).
List<String> crmAdjustmentActions(CrmReceivableAdjustment a, CrmCapabilities c, String? userId) {
  if (a.status != 'DRAFT') return const [];
  final approver = crmCanApproveReceivable(c);
  return [
    if (approver && a.createdBy != userId) 'approve',
    if (approver || a.createdBy == userId) 'cancel',
  ];
}

/// Làm tròn đến đồng, kiểu xa số 0 như server.
double crmRoundVnd(double value) => value.sign * value.abs().roundToDouble();

/// Chia số thu vào các khoản theo hạn thanh toán sớm trước (web `autoAllocate`).
Map<String, double> crmAutoAllocate(List<CrmReceivableOpenItem> items, double amount) {
  final ordered = [...items]..sort((a, b) {
      final byDue = (a.dueDate ?? '9999-12-31').compareTo(b.dueDate ?? '9999-12-31');
      return byDue != 0 ? byDue : a.entryDate.compareTo(b.entryDate);
    });
  var remaining = crmRoundVnd(amount < 0 ? 0 : amount);
  final result = <String, double>{};
  for (final item in ordered) {
    if (remaining <= 0) break;
    final cap = crmRoundVnd(item.allocatableAmount);
    final take = remaining < cap ? remaining : cap;
    if (take <= 0) continue;
    result[item.entryId] = take;
    remaining = crmRoundVnd(remaining - take);
  }
  return result;
}

/// Lỗi phân bổ (web `allocationError`); [orderCode] chỉ có với [CrmAllocationProblem.exceeds].
enum CrmAllocationProblem { amountNotPositive, negative, notOpen, exceeds, totalExceeds }

class CrmAllocationError {
  final CrmAllocationProblem problem;
  final String? orderCode;
  const CrmAllocationError(this.problem, [this.orderCode]);
}

/// Kiểm phân bổ trước khi gửi: số thu dương; mỗi khoản không vượt phần còn phân bổ được; tổng không vượt số thu.
CrmAllocationError? crmAllocationError(
    double amount, Map<String, double> allocations, List<CrmReceivableOpenItem> items) {
  if (!(amount > 0)) return const CrmAllocationError(CrmAllocationProblem.amountNotPositive);
  var total = 0.0;
  for (final entry in allocations.entries) {
    final value = entry.value;
    if (value == 0) continue;
    if (value < 0) return const CrmAllocationError(CrmAllocationProblem.negative);
    CrmReceivableOpenItem? item;
    for (final candidate in items) {
      if (candidate.entryId == entry.key) item = candidate;
    }
    if (item == null) return const CrmAllocationError(CrmAllocationProblem.notOpen);
    if (value > item.allocatableAmount) return CrmAllocationError(CrmAllocationProblem.exceeds, item.orderCode);
    total += value;
  }
  if (crmRoundVnd(total) > crmRoundVnd(amount)) return const CrmAllocationError(CrmAllocationProblem.totalExceeds);
  return null;
}

/// Danh sách phân bổ gửi API (bỏ dòng 0).
List<Map<String, dynamic>> crmAllocationRequests(Map<String, double> allocations) => [
      for (final e in allocations.entries)
        if (e.value > 0) {'entryId': e.key, 'amount': crmRoundVnd(e.value)},
    ];
