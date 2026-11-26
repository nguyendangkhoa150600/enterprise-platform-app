import '../../../../core/i18n/app_i18n.dart';
import '../../../inventory/presentation/utils/inventory_sheet_io.dart';
import '../../domain/reports/crm_report_models.dart';
import '../common/crm_format.dart';

/// Phần thuần của màn Báo cáo (web `reports.model.ts`): kỳ chọn nhanh, nhãn dòng, bảng xuất Excel. Bảng xuất dựng
/// từ đúng dữ liệu API đã trả (đã lọc phạm vi ở server).

/// Bộ lọc chung của các tab (web `Filters`).
class CrmReportFilters {
  final String from;
  final String to;
  final String ownerUserId;
  final String customerGroupId;
  final String region;
  const CrmReportFilters({
    required this.from,
    required this.to,
    this.ownerUserId = '',
    this.customerGroupId = '',
    this.region = '',
  });

  CrmReportFilters copyWith({String? from, String? to, String? ownerUserId, String? customerGroupId, String? region}) =>
      CrmReportFilters(
        from: from ?? this.from,
        to: to ?? this.to,
        ownerUserId: ownerUserId ?? this.ownerUserId,
        customerGroupId: customerGroupId ?? this.customerGroupId,
        region: region ?? this.region,
      );
}

class CrmPeriodPreset {
  final String id;
  final String label;
  final String from;
  final String to;
  const CrmPeriodPreset(this.id, this.label, this.from, this.to);
}

String _ymd(DateTime d) => crmApiDate(d);

/// Web `periodPresets(today)`.
List<CrmPeriodPreset> crmPeriodPresets(String today) {
  final t = parseCrmDay(today) ?? DateTime.now();
  final monthStart = DateTime(t.year, t.month, 1);
  final lastMonthStart = DateTime(t.year, t.month - 1, 1);
  final lastMonthEnd = DateTime(t.year, t.month, 0);
  final quarterMonth = ((t.month - 1) ~/ 3) * 3 + 1;
  return [
    CrmPeriodPreset('month', 'crm.reports.preset.month'.tr(), _ymd(monthStart), today),
    CrmPeriodPreset('last-month', 'crm.reports.preset.last_month'.tr(), _ymd(lastMonthStart), _ymd(lastMonthEnd)),
    CrmPeriodPreset('quarter', 'crm.reports.preset.quarter'.tr(), _ymd(DateTime(t.year, quarterMonth, 1)), today),
    CrmPeriodPreset('year', 'crm.reports.preset.year'.tr(), _ymd(DateTime(t.year, 1, 1)), today),
    CrmPeriodPreset('12-months', 'crm.reports.preset.12_months'.tr(), _ymd(DateTime(t.year, t.month - 11, 1)), today),
  ];
}

/// Nhãn chiều nhóm (web `SALES_REPORT_DIMENSION_LABELS`).
String crmDimensionLabel(String dimension) => switch (dimension) {
  'owner' => 'crm.reports.dimension.owner'.tr(),
  'customer' => 'crm.reports.dimension.customer'.tr(),
  'material' => 'crm.reports.dimension.material'.tr(),
  'category' => 'crm.reports.dimension.category'.tr(),
  'region' => 'crm.reports.dimension.region'.tr(),
  _ => 'crm.reports.dimension.customer_group'.tr(),
};

/// Web `CONVERSION_STAGE_LABELS`.
String crmConversionStageLabel(String stage) => 'crm.reports.stage.${stage.toLowerCase()}'.tr();

/// Web `SALES_ALERT_KIND_LABELS`.
String crmAlertKindLabel(String kind) => 'crm.reports.alert_kind.${kind.toLowerCase()}'.tr();

/// Web `salesRowLabel`: chiều nhân viên đổi id sang tên.
String crmSalesRowLabel(String groupBy, CrmSalesReportRow row, String Function(String userId) personName) {
  if (groupBy == 'owner') {
    return (row.key != null && row.key!.isNotEmpty) ? personName(row.key!) : 'crm.reports.unknown'.tr();
  }
  if (row.label.isNotEmpty) return row.label;
  return (groupBy == 'region' ? 'crm.reports.no_region' : 'crm.reports.no_group').tr();
}

/// Web `barPercent`: độ dài thanh (0..100).
double crmBarPercent(double value, double max) {
  if (!(max > 0) || !(value > 0)) return 0;
  final v = (value / max * 1000).round() / 10;
  return v > 100 ? 100 : v;
}

/// Web `percent` của màn Báo cáo: null → "Không xác định".
String crmReportPercent(double? value) => value == null ? 'crm.reports.undetermined'.tr() : formatCrmPercent(value);

typedef CrmSheet = MapEntry<String, List<List<Object?>>>;

String _h(String key) => 'crm.reports.sheet.$key'.tr();

/// Web `salesSheet`.
CrmSheet crmSalesSheet(CrmSalesReport report, String Function(String) personName) {
  final dimension = crmDimensionLabel(report.groupBy);
  List<Object?> figures(CrmSalesFigures f) => [
    f.quantity,
    f.revenue,
    f.vatAmount,
    f.costAmount,
    f.profit,
    f.marginPercent,
    f.orderCount,
  ];
  return MapEntry(_h('sales_name'), [
    [
      'crm.reports.sheet.sales_title'.tr(
        args: {'dimension': dimension.toLowerCase(), 'from': formatCrmDay(report.from), 'to': formatCrmDay(report.to)},
      ),
    ],
    [
      dimension,
      _h('code'),
      _h('quantity'),
      _h('revenue'),
      _h('vat'),
      _h('cost'),
      _h('profit'),
      _h('margin'),
      _h('orders'),
    ],
    for (final row in report.rows)
      [crmSalesRowLabel(report.groupBy, row, personName), row.code, ...figures(row.figures)],
    [_h('total'), null, ...figures(report.totals)],
  ]);
}

/// Web `conversionSheet`.
CrmSheet crmConversionSheet(CrmConversionReport report, String Function(String) personName) {
  final header = [
    for (final step in report.steps) ...[
      crmConversionStageLabel(step.stage),
      '${crmConversionStageLabel(step.stage)} (%)',
    ],
  ];
  List<Object?> cells(List<CrmConversionStep> steps) => [
    for (final s in steps) ...[s.count, s.stepPercent],
  ];
  return MapEntry(_h('conversion_name'), [
    [
      'crm.reports.sheet.conversion_title'.tr(args: {'from': formatCrmDay(report.from), 'to': formatCrmDay(report.to)}),
    ],
    [_h('employee'), ...header, _h('overall')],
    for (final owner in report.byOwner)
      [
        personName(owner.ownerUserId),
        ...cells(owner.steps),
        owner.steps.isEmpty ? null : owner.steps.last.overallPercent,
      ],
    [_h('total'), ...cells(report.steps), report.steps.isEmpty ? null : report.steps.last.overallPercent],
  ]);
}

/// Web `alertsSheet`.
CrmSheet crmAlertsSheet(CrmSalesAlertList list, String Function(String) personName) => MapEntry(_h('alerts_name'), [
  [_h('kind'), _h('code'), _h('customer'), _h('date'), _h('days'), _h('summary'), _h('owner')],
  for (final item in list.items)
    [
      crmAlertKindLabel(item.kind),
      item.code,
      item.customerName,
      formatCrmDay(item.date),
      item.days,
      item.summary,
      personName(item.ownerUserId),
    ],
]);

/// Web `receivableSheets`.
List<CrmSheet> crmReceivableSheets(CrmReceivableReport report, String Function(String) personName) {
  final t = report.totals;
  return [
    MapEntry(_h('receivables_name'), [
      [
        'crm.reports.sheet.receivables_title'.tr(args: {'date': formatCrmDay(report.asOf)}),
      ],
      [
        _h('customer_code'),
        _h('customer'),
        _h('customer_group'),
        _h('region'),
        _h('debit_revenue'),
        _h('collected'),
        _h('adjusted'),
        _h('balance'),
        _h('uncollected'),
        _h('overdue'),
        _h('oldest_overdue'),
        _h('next_due'),
        _h('overdue_orders'),
        _h('owner'),
      ],
      for (final row in report.customers)
        [
          row.customerCode,
          row.customerName,
          row.customerGroupName,
          row.region,
          row.revenue,
          row.collected,
          row.adjusted,
          row.balance,
          row.uncollectedRevenue,
          row.overdueAmount,
          formatCrmDay(row.oldestOverdueDate),
          formatCrmDay(row.nextDueDate),
          row.overdueOrderCount,
          personName(row.ownerUserId),
        ],
      [
        _h('total'),
        null,
        null,
        null,
        t.revenue,
        t.collected,
        t.adjusted,
        t.balance,
        t.uncollectedRevenue,
        t.overdueAmount,
      ],
    ]),
    MapEntry(_h('overdue_orders_name'), [
      [
        _h('order_code'),
        _h('customer_code'),
        _h('customer'),
        _h('due_date'),
        _h('days_overdue'),
        _h('overdue_amount'),
        _h('owner'),
      ],
      for (final row in report.overdueOrders)
        [
          row.orderCode,
          row.customerCode,
          row.customerName,
          formatCrmDay(row.dueDate),
          row.daysOverdue,
          row.overdueAmount,
          personName(row.ownerUserId),
        ],
    ]),
  ];
}

/// Ghi file Excel (web `downloadWorkbook` + `exportFileName(prefix, today)`) rồi mở hộp chia sẻ.
Future<void> crmShareWorkbook(String prefix, String today, List<CrmSheet> sheets) =>
    InventorySheetIO.shareXlsx('$prefix-$today', Map.fromEntries(sheets));
