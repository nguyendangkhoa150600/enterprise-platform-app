import '../common/crm_json.dart';

/// Dashboard Tổng quan Bán hàng (contracts `dashboard.ts`, `GET /dashboard`). Số liệu đã lọc theo phạm vi của
/// người xem ở server.

/// Kỳ chọn nhanh (contracts `DASHBOARD_PERIODS`).
const List<String> kCrmDashboardPeriods = ['month', 'quarter', 'year', 'custom'];

/// Danh sách "Cần chú ý" (contracts `DASHBOARD_ATTENTION_KINDS`), theo thứ tự hiển thị.
const List<String> kCrmDashboardAttentionKinds = [
  'lateDeliveries',
  'pendingQuotes',
  'expiringContracts',
  'activities',
  'overdueReceivables',
];

class CrmDashboardRange {
  final String from;
  final String to;
  const CrmDashboardRange(this.from, this.to);

  factory CrmDashboardRange.fromJson(Object? raw) {
    final json = CrmJson.map(raw);
    return CrmDashboardRange(CrmJson.str(json['from']), CrmJson.str(json['to']));
  }
}

/// Một chỉ số so với kỳ trước.
class CrmDashboardMetric {
  final double value;
  final double previous;

  /// % thay đổi; kỳ trước 0 mà kỳ này khác 0 thì null.
  final double? changePercent;
  const CrmDashboardMetric(this.value, this.previous, this.changePercent);

  factory CrmDashboardMetric.fromJson(Object? raw) {
    final json = CrmJson.map(raw);
    return CrmDashboardMetric(
      CrmJson.number(json['value']),
      CrmJson.number(json['previous']),
      CrmJson.numOrNull(json['changePercent']),
    );
  }
}

/// Tỷ lệ (%) so với kỳ trước.
class CrmDashboardRate {
  final double? value;
  final double? previous;
  final double? changePoints;
  const CrmDashboardRate(this.value, this.previous, this.changePoints);

  factory CrmDashboardRate.fromJson(Object? raw) {
    final json = CrmJson.map(raw);
    return CrmDashboardRate(
      CrmJson.numOrNull(json['value']),
      CrmJson.numOrNull(json['previous']),
      CrmJson.numOrNull(json['changePoints']),
    );
  }
}

class CrmDashboardKpis {
  final CrmDashboardMetric revenue;
  final CrmDashboardMetric profit;
  final CrmDashboardRate marginPercent;
  final CrmDashboardMetric newOrders;
  final CrmDashboardRate winRate;
  final int winRateWon;
  final int winRateLost;
  final int pipelineCount;
  final double pipelineValue;
  final double pipelineWeightedValue;
  final double receivablesBalance;
  final double receivablesOverdue;
  final int receivablesOverdueCustomers;
  final int pendingQuotesCount;
  final double pendingQuotesValue;

  const CrmDashboardKpis({
    required this.revenue,
    required this.profit,
    required this.marginPercent,
    required this.newOrders,
    required this.winRate,
    required this.winRateWon,
    required this.winRateLost,
    required this.pipelineCount,
    required this.pipelineValue,
    required this.pipelineWeightedValue,
    required this.receivablesBalance,
    required this.receivablesOverdue,
    required this.receivablesOverdueCustomers,
    required this.pendingQuotesCount,
    required this.pendingQuotesValue,
  });

  factory CrmDashboardKpis.fromJson(Object? raw) {
    final json = CrmJson.map(raw);
    final win = CrmJson.map(json['winRate']);
    final pipeline = CrmJson.map(json['pipeline']);
    final receivables = CrmJson.map(json['receivables']);
    final pending = CrmJson.map(json['pendingQuotes']);
    return CrmDashboardKpis(
      revenue: CrmDashboardMetric.fromJson(json['revenue']),
      profit: CrmDashboardMetric.fromJson(json['profit']),
      marginPercent: CrmDashboardRate.fromJson(json['marginPercent']),
      newOrders: CrmDashboardMetric.fromJson(json['newOrders']),
      winRate: CrmDashboardRate.fromJson(win),
      winRateWon: CrmJson.integer(win['won']),
      winRateLost: CrmJson.integer(win['lost']),
      pipelineCount: CrmJson.integer(pipeline['count']),
      pipelineValue: CrmJson.number(pipeline['value']),
      pipelineWeightedValue: CrmJson.number(pipeline['weightedValue']),
      receivablesBalance: CrmJson.number(receivables['balance']),
      receivablesOverdue: CrmJson.number(receivables['overdue']),
      receivablesOverdueCustomers: CrmJson.integer(receivables['overdueCustomers']),
      pendingQuotesCount: CrmJson.integer(pending['count']),
      pendingQuotesValue: CrmJson.number(pending['value']),
    );
  }
}

class CrmDashboardTrendBucket {
  final String start;
  final String end;
  final double revenue;
  final int orders;
  const CrmDashboardTrendBucket(this.start, this.end, this.revenue, this.orders);

  factory CrmDashboardTrendBucket.fromJson(Map<String, dynamic> json) => CrmDashboardTrendBucket(
        CrmJson.str(json['start']),
        CrmJson.str(json['end']),
        CrmJson.number(json['revenue']),
        CrmJson.integer(json['orders']),
      );
}

class CrmDashboardStageRow {
  final String stage;
  final String name;
  final int count;
  final double value;
  final double weightedValue;
  const CrmDashboardStageRow(this.stage, this.name, this.count, this.value, this.weightedValue);

  factory CrmDashboardStageRow.fromJson(Map<String, dynamic> json) => CrmDashboardStageRow(
        CrmJson.str(json['stage']),
        CrmJson.str(json['name']),
        CrmJson.integer(json['count']),
        CrmJson.number(json['value']),
        CrmJson.number(json['weightedValue']),
      );
}

class CrmDashboardTopCustomer {
  final String customerId;
  final String code;
  final String name;
  final double revenue;
  final double profit;
  final int orderCount;
  const CrmDashboardTopCustomer(this.customerId, this.code, this.name, this.revenue, this.profit, this.orderCount);

  factory CrmDashboardTopCustomer.fromJson(Map<String, dynamic> json) => CrmDashboardTopCustomer(
        CrmJson.str(json['customerId']),
        CrmJson.str(json['code']),
        CrmJson.str(json['name']),
        CrmJson.number(json['revenue']),
        CrmJson.number(json['profit']),
        CrmJson.integer(json['orderCount']),
      );
}

class CrmDashboardTopProduct {
  final String materialId;
  final String code;
  final String name;
  final double quantity;
  final double revenue;
  final double profit;
  const CrmDashboardTopProduct(this.materialId, this.code, this.name, this.quantity, this.revenue, this.profit);

  factory CrmDashboardTopProduct.fromJson(Map<String, dynamic> json) => CrmDashboardTopProduct(
        CrmJson.str(json['materialId']),
        CrmJson.str(json['code']),
        CrmJson.str(json['name']),
        CrmJson.number(json['quantity']),
        CrmJson.number(json['revenue']),
        CrmJson.number(json['profit']),
      );
}

class CrmDashboardAttentionItem {
  final String id;
  final String title;
  final String subtitle;
  final String? date;
  final int days;
  final double? amount;
  final String note;
  final String deepLink;
  const CrmDashboardAttentionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.date,
    required this.days,
    this.amount,
    required this.note,
    required this.deepLink,
  });

  factory CrmDashboardAttentionItem.fromJson(Map<String, dynamic> json) => CrmDashboardAttentionItem(
        id: CrmJson.str(json['id']),
        title: CrmJson.str(json['title']),
        subtitle: CrmJson.str(json['subtitle']),
        date: CrmJson.strOrNull(json['date']),
        days: CrmJson.integer(json['days']),
        amount: CrmJson.numOrNull(json['amount']),
        note: CrmJson.str(json['note']),
        deepLink: CrmJson.str(json['deepLink']),
      );
}

class CrmDashboardAttentionList {
  final int total;
  final List<CrmDashboardAttentionItem> items;
  const CrmDashboardAttentionList(this.total, this.items);

  factory CrmDashboardAttentionList.fromJson(Object? raw) {
    final json = CrmJson.map(raw);
    return CrmDashboardAttentionList(
      CrmJson.integer(json['total']),
      CrmJson.list(json['items'], CrmDashboardAttentionItem.fromJson),
    );
  }
}

class CrmSalesDashboard {
  final String period;
  final CrmDashboardRange range;
  final CrmDashboardRange previous;
  final String asOf;

  /// `mine` | `team` | `all`.
  final String scope;
  final CrmDashboardKpis kpis;

  /// `day` | `week` | `month`.
  final String granularity;
  final List<CrmDashboardTrendBucket> buckets;
  final List<CrmDashboardStageRow> pipeline;
  final List<CrmDashboardTopCustomer> topCustomers;
  final List<CrmDashboardTopProduct> topProducts;
  final Map<String, CrmDashboardAttentionList> attention;
  final int contractExpiringDays;

  const CrmSalesDashboard({
    required this.period,
    required this.range,
    required this.previous,
    required this.asOf,
    required this.scope,
    required this.kpis,
    required this.granularity,
    required this.buckets,
    required this.pipeline,
    required this.topCustomers,
    required this.topProducts,
    required this.attention,
    required this.contractExpiringDays,
  });

  factory CrmSalesDashboard.fromJson(Map<String, dynamic> json) {
    final trend = CrmJson.map(json['trend']);
    final attention = CrmJson.map(json['attention']);
    return CrmSalesDashboard(
      period: CrmJson.str(json['period'], 'month'),
      range: CrmDashboardRange.fromJson(json['range']),
      previous: CrmDashboardRange.fromJson(json['previous']),
      asOf: CrmJson.str(json['asOf']),
      scope: CrmJson.str(json['scope'], 'mine'),
      kpis: CrmDashboardKpis.fromJson(json['kpis']),
      granularity: CrmJson.str(trend['granularity'], 'day'),
      buckets: CrmJson.list(trend['buckets'], CrmDashboardTrendBucket.fromJson),
      pipeline: CrmJson.list(json['pipeline'], CrmDashboardStageRow.fromJson),
      topCustomers: CrmJson.list(json['topCustomers'], CrmDashboardTopCustomer.fromJson),
      topProducts: CrmJson.list(json['topProducts'], CrmDashboardTopProduct.fromJson),
      attention: {
        for (final kind in kCrmDashboardAttentionKinds) kind: CrmDashboardAttentionList.fromJson(attention[kind]),
      },
      contractExpiringDays: CrmJson.integer(json['contractExpiringDays']),
    );
  }
}
