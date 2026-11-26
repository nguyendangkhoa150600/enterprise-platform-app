import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/crm_capabilities.dart';
import '../../domain/dashboard/crm_dashboard_models.dart';
import '../common/crm_format.dart';
import '../crm_nav.dart';

/// Phần thuần của Tổng quan (web `dashboard.model.ts`): thẻ chỉ số, so với kỳ trước, trang mở khi bấm.

final NumberFormat _oneDecimal = NumberFormat('#,##0.#', 'vi_VN');

enum CrmDeltaTone { good, bad, flat }

class CrmCardDelta {
  final String text;
  final CrmDeltaTone tone;
  const CrmCardDelta(this.text, this.tone);
}

/// Web `formatDelta`: [points] = đơn vị " điểm" thay cho "%".
CrmCardDelta crmFormatDelta(double? change, {bool points = false, bool goodWhenUp = true}) {
  if (change == null) return CrmCardDelta('crm.dashboard.delta.no_previous'.tr(), CrmDeltaTone.flat);
  if (change == 0) return CrmCardDelta('crm.dashboard.delta.unchanged'.tr(), CrmDeltaTone.flat);
  final up = change > 0;
  final unit = points ? 'crm.dashboard.delta.points_unit'.tr() : '%';
  final text = 'crm.dashboard.delta.text'.tr(
    args: {'arrow': up ? '▲ +' : '▼ ', 'value': '${_oneDecimal.format(change)}$unit'},
  );
  return CrmCardDelta(text, up == goodWhenUp ? CrmDeltaTone.good : CrmDeltaTone.bad);
}

class CrmDashboardCard {
  final String key;
  final String label;
  final String value;

  /// Giá trị đầy đủ (giữ để xem khi bấm giữ).
  final String? title;
  final CrmCardDelta? delta;
  final String? hint;
  final bool danger;
  final CrmView view;
  const CrmDashboardCard({
    required this.key,
    required this.label,
    required this.value,
    this.title,
    this.delta,
    this.hint,
    this.danger = false,
    required this.view,
  });
}

/// Web `canOpenReports`.
bool crmCanOpenReports(CrmCapabilities caps) => caps.isTenantAdmin || caps.canReadReport;

/// Web `dashboardCards`.
List<CrmDashboardCard> crmDashboardCards(CrmSalesDashboard dashboard, CrmCapabilities caps) {
  final k = dashboard.kpis;
  final salesView = crmCanOpenReports(caps) ? CrmView.reports : CrmView.orders;
  final margin = k.marginPercent;
  String marginHint() {
    if (margin.value == null) return 'crm.dashboard.card.margin_none'.tr();
    final cp = margin.changePoints;
    final suffix = (cp == null || cp == 0)
        ? ''
        : ' (${cp > 0 ? '+' : ''}${_oneDecimal.format(cp)} ${'crm.dashboard.delta.points_word'.tr()})';
    return 'crm.dashboard.card.margin'.tr(args: {'rate': formatCrmRate(margin.value)}) + suffix;
  }

  CrmCardDelta? winDelta() {
    if (k.winRate.value == null) return null;
    if (k.winRate.previous == null) return crmFormatDelta(null, points: true);
    return crmFormatDelta(k.winRate.changePoints, points: true);
  }

  return [
    CrmDashboardCard(
      key: 'revenue',
      label: 'crm.dashboard.card.revenue'.tr(),
      value: formatCrmVndCompact(k.revenue.value),
      title: formatCrmMoney(k.revenue.value),
      delta: crmFormatDelta(k.revenue.changePercent),
      hint: 'crm.dashboard.card.revenue_hint'.tr(),
      view: salesView,
    ),
    CrmDashboardCard(
      key: 'profit',
      label: 'crm.dashboard.card.profit'.tr(),
      value: formatCrmVndCompact(k.profit.value),
      title: formatCrmMoney(k.profit.value),
      delta: crmFormatDelta(k.profit.changePercent),
      hint: marginHint(),
      danger: k.profit.value < 0,
      view: salesView,
    ),
    CrmDashboardCard(
      key: 'newOrders',
      label: 'crm.dashboard.card.new_orders'.tr(),
      value: formatCrmCount(k.newOrders.value),
      delta: crmFormatDelta(k.newOrders.changePercent),
      hint: 'crm.dashboard.card.new_orders_hint'.tr(),
      view: CrmView.orders,
    ),
    CrmDashboardCard(
      key: 'pipeline',
      label: 'crm.dashboard.card.pipeline'.tr(),
      value: formatCrmVndCompact(k.pipelineValue),
      title: formatCrmMoney(k.pipelineValue),
      hint: 'crm.dashboard.card.pipeline_hint'.tr(
        args: {'count': formatCrmCount(k.pipelineCount), 'weighted': formatCrmVndCompact(k.pipelineWeightedValue)},
      ),
      view: CrmView.opportunities,
    ),
    CrmDashboardCard(
      key: 'winRate',
      label: 'crm.dashboard.card.win_rate'.tr(),
      value: formatCrmRate(k.winRate.value),
      delta: winDelta(),
      hint: (k.winRateWon + k.winRateLost) > 0
          ? 'crm.dashboard.card.win_rate_hint'.tr(
              args: {'won': formatCrmCount(k.winRateWon), 'lost': formatCrmCount(k.winRateLost)},
            )
          : 'crm.dashboard.card.win_rate_none'.tr(),
      view: CrmView.opportunities,
    ),
    CrmDashboardCard(
      key: 'receivables',
      label: 'crm.dashboard.card.receivables'.tr(),
      value: formatCrmVndCompact(k.receivablesBalance),
      title: formatCrmMoney(k.receivablesBalance),
      hint: k.receivablesOverdue != 0
          ? 'crm.dashboard.card.receivables_overdue'.tr(
              args: {
                'amount': formatCrmVndCompact(k.receivablesOverdue),
                'count': formatCrmCount(k.receivablesOverdueCustomers),
              },
            )
          : 'crm.dashboard.card.receivables_none'.tr(),
      danger: k.receivablesOverdue > 0,
      view: CrmView.receivables,
    ),
    CrmDashboardCard(
      key: 'pendingQuotes',
      label: 'crm.dashboard.card.pending_quotes'.tr(),
      value: formatCrmCount(k.pendingQuotesCount),
      hint: k.pendingQuotesCount > 0
          ? 'crm.dashboard.card.pending_quotes_hint'.tr(args: {'value': formatCrmVndCompact(k.pendingQuotesValue)})
          : 'crm.dashboard.card.pending_quotes_none'.tr(),
      view: CrmView.quotes,
    ),
  ];
}

/// Web `ATTENTION_VIEWS`: trang mở khi bấm một mục "Cần chú ý".
const Map<String, CrmView> kCrmAttentionViews = {
  'lateDeliveries': CrmView.orders,
  'pendingQuotes': CrmView.quotes,
  'expiringContracts': CrmView.contracts,
  'activities': CrmView.activities,
  'overdueReceivables': CrmView.receivables,
};

/// Khoá i18n của kind (camelCase → snake_case).
String crmAttentionKey(String kind) => switch (kind) {
  'lateDeliveries' => 'late_deliveries',
  'pendingQuotes' => 'pending_quotes',
  'expiringContracts' => 'expiring_contracts',
  'activities' => 'activities',
  _ => 'overdue_receivables',
};

/// Web `bucketLabel`: ngày, tuần `21/10`; tháng `T10`.
String crmBucketLabel(String start, String granularity) {
  final parts = start.split('-');
  if (parts.length < 3) return start;
  return granularity == 'month'
      ? 'crm.dashboard.month_short'.tr(args: {'month': int.tryParse(parts[1]) ?? parts[1]})
      : '${parts[2]}/${parts[1]}';
}

/// Khoảng ngày của một mốc (chú giải khi bấm cột).
String crmBucketRange(CrmDashboardTrendBucket bucket) => bucket.start == bucket.end
    ? formatCrmDay(bucket.start)
    : '${formatCrmDay(bucket.start)} – ${formatCrmDay(bucket.end)}';
