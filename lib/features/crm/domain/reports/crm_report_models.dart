import '../common/crm_json.dart';

/// Báo cáo Bán hàng (contracts `reports.ts`): doanh thu, chuyển đổi, cảnh báo, công nợ. Dữ liệu đã lọc phạm vi ở server.

/// Chiều nhóm của báo cáo doanh thu (contracts `SALES_REPORT_DIMENSIONS`).
const List<String> kCrmSalesReportDimensions = ['owner', 'customer', 'material', 'category', 'region', 'customerGroup'];

/// Bước chuyển đổi (contracts `CONVERSION_STAGES`).
const List<String> kCrmConversionStages = ['OPPORTUNITY', 'QUOTE', 'CONTRACT', 'ORDER'];

/// Loại cảnh báo (contracts `SALES_ALERT_KINDS`).
const List<String> kCrmSalesAlertKinds = ['QUOTE_PENDING', 'CONTRACT_EXPIRING', 'DELIVERY_LATE'];

/// Số liệu cộng dồn của một nhóm hoặc tổng (contracts `SalesFigures`).
class CrmSalesFigures {
  final double quantity;
  final double revenue;
  final double vatAmount;
  final double costAmount;
  final double profit;
  final double? marginPercent;
  final int orderCount;

  const CrmSalesFigures({
    required this.quantity,
    required this.revenue,
    required this.vatAmount,
    required this.costAmount,
    required this.profit,
    this.marginPercent,
    required this.orderCount,
  });

  factory CrmSalesFigures.fromJson(Map<String, dynamic> json) => CrmSalesFigures(
        quantity: CrmJson.number(json['quantity']),
        revenue: CrmJson.number(json['revenue']),
        vatAmount: CrmJson.number(json['vatAmount']),
        costAmount: CrmJson.number(json['costAmount']),
        profit: CrmJson.number(json['profit']),
        marginPercent: CrmJson.numOrNull(json['marginPercent']),
        orderCount: CrmJson.integer(json['orderCount']),
      );
}

class CrmSalesReportRow {
  final String? key;
  final String? code;
  final String label;
  final CrmSalesFigures figures;
  const CrmSalesReportRow({this.key, this.code, required this.label, required this.figures});

  factory CrmSalesReportRow.fromJson(Map<String, dynamic> json) => CrmSalesReportRow(
        key: CrmJson.strOrNull(json['key']),
        code: CrmJson.strOrNull(json['code']),
        label: CrmJson.str(json['label']),
        figures: CrmSalesFigures.fromJson(json),
      );
}

class CrmSalesReport {
  final String from;
  final String to;
  final String groupBy;
  final List<CrmSalesReportRow> rows;
  final bool truncated;
  final CrmSalesFigures totals;
  const CrmSalesReport({
    required this.from,
    required this.to,
    required this.groupBy,
    required this.rows,
    required this.truncated,
    required this.totals,
  });

  factory CrmSalesReport.fromJson(Map<String, dynamic> json) => CrmSalesReport(
        from: CrmJson.str(json['from']),
        to: CrmJson.str(json['to']),
        groupBy: CrmJson.str(json['groupBy'], 'owner'),
        rows: CrmJson.list(json['rows'], CrmSalesReportRow.fromJson),
        truncated: CrmJson.boolean(json['truncated']),
        totals: CrmSalesFigures.fromJson(CrmJson.map(json['totals'])),
      );
}

class CrmConversionStep {
  final String stage;
  final int count;
  final double? stepPercent;
  final double? overallPercent;
  const CrmConversionStep(this.stage, this.count, this.stepPercent, this.overallPercent);

  factory CrmConversionStep.fromJson(Map<String, dynamic> json) => CrmConversionStep(
        CrmJson.str(json['stage']),
        CrmJson.integer(json['count']),
        CrmJson.numOrNull(json['stepPercent']),
        CrmJson.numOrNull(json['overallPercent']),
      );
}

class CrmConversionOwnerRow {
  final String ownerUserId;
  final List<CrmConversionStep> steps;
  const CrmConversionOwnerRow(this.ownerUserId, this.steps);

  factory CrmConversionOwnerRow.fromJson(Map<String, dynamic> json) => CrmConversionOwnerRow(
        CrmJson.str(json['ownerUserId']),
        CrmJson.list(json['steps'], CrmConversionStep.fromJson),
      );
}

class CrmConversionReport {
  final String from;
  final String to;
  final List<CrmConversionStep> steps;
  final List<CrmConversionOwnerRow> byOwner;
  const CrmConversionReport(this.from, this.to, this.steps, this.byOwner);

  factory CrmConversionReport.fromJson(Map<String, dynamic> json) => CrmConversionReport(
        CrmJson.str(json['from']),
        CrmJson.str(json['to']),
        CrmJson.list(json['steps'], CrmConversionStep.fromJson),
        CrmJson.list(json['byOwner'], CrmConversionOwnerRow.fromJson),
      );
}

class CrmSalesAlert {
  final String kind;
  final String id;
  final String code;
  final String customerId;
  final String customerName;
  final String ownerUserId;
  final String? date;
  final int days;
  final String summary;
  final String deepLink;
  const CrmSalesAlert({
    required this.kind,
    required this.id,
    required this.code,
    required this.customerId,
    required this.customerName,
    required this.ownerUserId,
    this.date,
    required this.days,
    required this.summary,
    required this.deepLink,
  });

  factory CrmSalesAlert.fromJson(Map<String, dynamic> json) => CrmSalesAlert(
        kind: CrmJson.str(json['kind']),
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        customerId: CrmJson.str(json['customerId']),
        customerName: CrmJson.str(json['customerName']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        date: CrmJson.strOrNull(json['date']),
        days: CrmJson.integer(json['days']),
        summary: CrmJson.str(json['summary']),
        deepLink: CrmJson.str(json['deepLink']),
      );
}

class CrmSalesAlertList {
  final List<CrmSalesAlert> items;
  final int contractExpiringDays;
  const CrmSalesAlertList(this.items, this.contractExpiringDays);

  factory CrmSalesAlertList.fromJson(Map<String, dynamic> json) => CrmSalesAlertList(
        CrmJson.list(json['items'], CrmSalesAlert.fromJson),
        CrmJson.integer(json['contractExpiringDays']),
      );
}

class CrmReceivableReportCustomerRow {
  final String customerId;
  final String customerCode;
  final String customerName;
  final String ownerUserId;
  final String? customerGroupName;
  final String? region;
  final double revenue;
  final double collected;
  final double adjusted;
  final double balance;
  final double uncollectedRevenue;
  final double overdueAmount;
  final String? nextDueDate;
  final String? oldestOverdueDate;
  final int overdueOrderCount;

  const CrmReceivableReportCustomerRow({
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.ownerUserId,
    this.customerGroupName,
    this.region,
    required this.revenue,
    required this.collected,
    required this.adjusted,
    required this.balance,
    required this.uncollectedRevenue,
    required this.overdueAmount,
    this.nextDueDate,
    this.oldestOverdueDate,
    required this.overdueOrderCount,
  });

  factory CrmReceivableReportCustomerRow.fromJson(Map<String, dynamic> json) => CrmReceivableReportCustomerRow(
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        customerGroupName: CrmJson.strOrNull(json['customerGroupName']),
        region: CrmJson.strOrNull(json['region']),
        revenue: CrmJson.number(json['revenue']),
        collected: CrmJson.number(json['collected']),
        adjusted: CrmJson.number(json['adjusted']),
        balance: CrmJson.number(json['balance']),
        uncollectedRevenue: CrmJson.number(json['uncollectedRevenue']),
        overdueAmount: CrmJson.number(json['overdueAmount']),
        nextDueDate: CrmJson.strOrNull(json['nextDueDate']),
        oldestOverdueDate: CrmJson.strOrNull(json['oldestOverdueDate']),
        overdueOrderCount: CrmJson.integer(json['overdueOrderCount']),
      );
}

class CrmOverdueOrderRow {
  final String orderId;
  final String orderCode;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String ownerUserId;
  final String dueDate;
  final int daysOverdue;
  final double overdueAmount;

  const CrmOverdueOrderRow({
    required this.orderId,
    required this.orderCode,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.ownerUserId,
    required this.dueDate,
    required this.daysOverdue,
    required this.overdueAmount,
  });

  factory CrmOverdueOrderRow.fromJson(Map<String, dynamic> json) => CrmOverdueOrderRow(
        orderId: CrmJson.str(json['orderId']),
        orderCode: CrmJson.str(json['orderCode']),
        customerId: CrmJson.str(json['customerId']),
        customerCode: CrmJson.str(json['customerCode']),
        customerName: CrmJson.str(json['customerName']),
        ownerUserId: CrmJson.str(json['ownerUserId']),
        dueDate: CrmJson.str(json['dueDate']),
        daysOverdue: CrmJson.integer(json['daysOverdue']),
        overdueAmount: CrmJson.number(json['overdueAmount']),
      );
}

class CrmReceivableReportTotals {
  final double revenue;
  final double collected;
  final double adjusted;
  final double balance;
  final double uncollectedRevenue;
  final double overdueAmount;
  const CrmReceivableReportTotals({
    required this.revenue,
    required this.collected,
    required this.adjusted,
    required this.balance,
    required this.uncollectedRevenue,
    required this.overdueAmount,
  });

  factory CrmReceivableReportTotals.fromJson(Map<String, dynamic> json) => CrmReceivableReportTotals(
        revenue: CrmJson.number(json['revenue']),
        collected: CrmJson.number(json['collected']),
        adjusted: CrmJson.number(json['adjusted']),
        balance: CrmJson.number(json['balance']),
        uncollectedRevenue: CrmJson.number(json['uncollectedRevenue']),
        overdueAmount: CrmJson.number(json['overdueAmount']),
      );
}

class CrmReceivableReport {
  final String asOf;
  final List<CrmReceivableReportCustomerRow> customers;
  final List<CrmOverdueOrderRow> overdueOrders;
  final CrmReceivableReportTotals totals;
  const CrmReceivableReport(this.asOf, this.customers, this.overdueOrders, this.totals);

  factory CrmReceivableReport.fromJson(Map<String, dynamic> json) => CrmReceivableReport(
        CrmJson.str(json['asOf']),
        CrmJson.list(json['customers'], CrmReceivableReportCustomerRow.fromJson),
        CrmJson.list(json['overdueOrders'], CrmOverdueOrderRow.fromJson),
        CrmReceivableReportTotals.fromJson(CrmJson.map(json['totals'])),
      );
}
