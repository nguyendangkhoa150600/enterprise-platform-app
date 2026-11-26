import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/reports/reports_repository.dart';
import '../../domain/reports/crm_report_models.dart';
import '../common/crm_format.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_routes.dart';
import 'crm_report_widgets.dart';
import 'crm_reports_model.dart';

typedef CrmNameOf = String Function(String userId);

const double _lw = 120;

Widget _money(double value, {bool bold = false}) => Text(
  formatCrmMoney(value),
  textAlign: TextAlign.right,
  style: TextStyle(
    fontSize: 13,
    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
    color: value < 0 ? CrmColors.danger : CrmColors.text,
  ),
);

Widget _toolbar(List<Widget> children) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: children),
);

// ---------------------------------------------------------------------------
// Doanh thu, lợi nhuận
// ---------------------------------------------------------------------------

/// Tab "Doanh thu, lợi nhuận" (web `SalesTab`).
class CrmSalesReportTab extends StatefulWidget {
  final CrmReportFilters filters;
  final CrmNameOf nameOf;
  final String today;
  const CrmSalesReportTab({super.key, required this.filters, required this.nameOf, required this.today});

  @override
  State<CrmSalesReportTab> createState() => _CrmSalesReportTabState();
}

class _CrmSalesReportTabState extends State<CrmSalesReportTab> {
  String _groupBy = 'owner';

  /// Sắp xếp như cột có `sorter` của web (Doanh thu, Lợi nhuận gộp); rỗng = thứ tự server.
  String _sort = '';

  List<CrmSalesReportRow> _sorted(List<CrmSalesReportRow> rows) {
    if (_sort.isEmpty) return rows;
    final list = [...rows];
    double pick(CrmSalesReportRow r) => _sort.startsWith('revenue') ? r.figures.revenue : r.figures.profit;
    list.sort((a, b) => _sort.endsWith('asc') ? pick(a).compareTo(pick(b)) : pick(b).compareTo(pick(a)));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filters;
    final query = {
      'from': f.from,
      'to': f.to,
      'ownerUserId': f.ownerUserId,
      'customerGroupId': f.customerGroupId,
      'region': f.region,
      'groupBy': _groupBy,
    };
    return CrmReportLoader<CrmSalesReport>(
      query: query,
      loader: CrmReportsRepository.instance.sales,
      fallbackKey: 'crm.reports.sales.load_failed',
      builder: (context, data, loading, error) {
        final groupBy = data?.groupBy ?? _groupBy;
        final rows = data == null ? const <CrmSalesReportRow>[] : _sorted(data.rows);
        final maxRevenue = rows.fold<double>(0, (m, r) => math.max(m, r.figures.revenue));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar([
              CrmFilterChip(
                placeholder: 'crm.reports.group_by'.tr(),
                value: _groupBy,
                searchable: false,
                options: [
                  for (final d in kCrmSalesReportDimensions) CrmSelectOption(value: d, label: crmDimensionLabel(d)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _groupBy = v);
                },
              ),
              CrmFilterChip(
                placeholder: 'crm.reports.sort.default'.tr(),
                value: _sort,
                searchable: false,
                options: [
                  for (final s in const ['revenue_desc', 'revenue_asc', 'profit_desc', 'profit_asc'])
                    CrmSelectOption(value: s, label: 'crm.reports.sort.$s'.tr()),
                ],
                onChanged: (v) => setState(() => _sort = v ?? ''),
              ),
              CrmReportExportButton(
                enabled: data != null,
                onExport: () =>
                    crmShareWorkbook('bao-cao-doanh-thu', widget.today, [crmSalesSheet(data!, widget.nameOf)]),
              ),
            ]),
            CrmReportNote('crm.reports.sales.note'.tr()),
            if (error != null) CrmBanner(message: error),
            if (data != null)
              CrmReportStats(
                stats: [
                  ('crm.reports.stat.revenue'.tr(), formatCrmMoney(data.totals.revenue)),
                  ('crm.reports.stat.cost'.tr(), formatCrmMoney(data.totals.costAmount)),
                  ('crm.reports.stat.profit'.tr(), formatCrmMoney(data.totals.profit)),
                  ('crm.reports.stat.margin'.tr(), crmReportPercent(data.totals.marginPercent)),
                  ('crm.reports.stat.quantity'.tr(), formatCrmQuantity(data.totals.quantity)),
                  ('crm.reports.stat.orders'.tr(), formatCrmCount(data.totals.orderCount)),
                ],
              ),
            if (data?.truncated == true) CrmReportNote('crm.reports.sales.truncated'.tr()),
            CrmLocalPagedList<CrmSalesReportRow>(
              items: rows,
              loading: loading,
              emptyText: 'crm.reports.sales.empty'.tr(),
              noun: 'crm.reports.noun_row'.tr(),
              itemBuilder: (context, row) => _SalesRowCard(
                row: row,
                label: crmSalesRowLabel(groupBy, row, widget.nameOf),
                barPercent: crmBarPercent(row.figures.revenue, maxRevenue),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SalesRowCard extends StatelessWidget {
  final CrmSalesReportRow row;
  final String label;
  final double barPercent;
  const _SalesRowCard({required this.row, required this.label, required this.barPercent});

  @override
  Widget build(BuildContext context) {
    final f = row.figures;
    return CrmCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (row.code != null && row.code!.isNotEmpty) ...[CrmCodeBadge(row.code!), const SizedBox(width: 6)],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: CrmColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: CrmReportBar(percent: barPercent)),
              const SizedBox(width: 10),
              _money(f.revenue, bold: true),
            ],
          ),
          const SizedBox(height: 6),
          CrmInfoRow(label: 'crm.reports.field.quantity'.tr(), value: formatCrmQuantity(f.quantity), labelWidth: _lw),
          CrmInfoRow(label: 'crm.reports.field.cost'.tr(), labelWidth: _lw, child: _alignLeft(_money(f.costAmount))),
          CrmInfoRow(label: 'crm.reports.field.profit'.tr(), labelWidth: _lw, child: _alignLeft(_money(f.profit))),
          CrmInfoRow(label: 'crm.reports.field.margin'.tr(), value: crmReportPercent(f.marginPercent), labelWidth: _lw),
          CrmInfoRow(label: 'crm.reports.field.orders'.tr(), value: formatCrmCount(f.orderCount), labelWidth: _lw),
        ],
      ),
    );
  }
}

Widget _alignLeft(Widget child) => Align(alignment: Alignment.centerLeft, child: child);

// ---------------------------------------------------------------------------
// Tỷ lệ chuyển đổi
// ---------------------------------------------------------------------------

/// Tab "Tỷ lệ chuyển đổi" (web `ConversionTab`).
class CrmConversionReportTab extends StatelessWidget {
  final CrmReportFilters filters;
  final CrmNameOf nameOf;
  final String today;
  const CrmConversionReportTab({super.key, required this.filters, required this.nameOf, required this.today});

  String _stepText(CrmConversionStep? step) {
    if (step == null) return '';
    return step.stepPercent == null
        ? formatCrmCount(step.count)
        : '${formatCrmCount(step.count)} (${crmReportPercent(step.stepPercent)})';
  }

  @override
  Widget build(BuildContext context) {
    final query = {'from': filters.from, 'to': filters.to, 'ownerUserId': filters.ownerUserId};
    return CrmReportLoader<CrmConversionReport>(
      query: query,
      loader: CrmReportsRepository.instance.conversion,
      fallbackKey: 'crm.reports.conversion.load_failed',
      builder: (context, data, loading, error) {
        final opportunities = (data == null || data.steps.isEmpty) ? 0 : data.steps.first.count;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar([
              CrmReportExportButton(
                enabled: data != null,
                onExport: () => crmShareWorkbook('ty-le-chuyen-doi', today, [crmConversionSheet(data!, nameOf)]),
              ),
            ]),
            CrmReportNote('crm.reports.conversion.note'.tr()),
            if (error != null) CrmBanner(message: error),
            if (data != null)
              CrmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final step in data.steps)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              crmConversionStageLabel(step.stage),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CrmColors.text),
                            ),
                            const SizedBox(height: 4),
                            CrmReportBar(
                              height: 22,
                              percent: math.max(
                                crmBarPercent(step.count.toDouble(), opportunities.toDouble()),
                                step.count > 0 ? 4 : 0,
                              ),
                              label: Text(
                                formatCrmCount(step.count),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                step.stepPercent == null
                                    ? 'crm.reports.conversion.first_step'.tr()
                                    : 'crm.reports.conversion.vs_previous'.tr(
                                        args: {'value': crmReportPercent(step.stepPercent)},
                                      ),
                                if (step.stage != 'OPPORTUNITY')
                                  'crm.reports.conversion.overall'.tr(
                                    args: {'value': crmReportPercent(step.overallPercent)},
                                  ),
                              ].join(' · '),
                              style: const TextStyle(fontSize: 11.5, color: CrmColors.muted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            CrmLocalPagedList<CrmConversionOwnerRow>(
              items: data?.byOwner ?? const [],
              loading: loading,
              emptyText: 'crm.reports.conversion.empty'.tr(),
              noun: 'crm.reports.noun_row'.tr(),
              itemBuilder: (context, owner) => CrmCard(
                margin: const EdgeInsets.only(bottom: 10),
                title: nameOf(owner.ownerUserId),
                child: Column(
                  children: [
                    for (var i = 0; i < kCrmConversionStages.length; i++)
                      CrmInfoRow(
                        label: crmConversionStageLabel(kCrmConversionStages[i]),
                        value: _stepText(i < owner.steps.length ? owner.steps[i] : null),
                        labelWidth: _lw,
                      ),
                    CrmInfoRow(
                      label: 'crm.reports.conversion.total'.tr(),
                      value: crmReportPercent(owner.steps.isEmpty ? null : owner.steps.last.overallPercent),
                      labelWidth: _lw,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Cảnh báo
// ---------------------------------------------------------------------------

CrmTone _alertTone(String kind) => switch (kind) {
  'QUOTE_PENDING' => CrmTone.warning,
  'CONTRACT_EXPIRING' => CrmTone.info,
  _ => CrmTone.danger,
};

/// Tab "Cảnh báo" (web `AlertsTab`). Bấm thẻ mở báo giá / hợp đồng / đơn bán.
class CrmAlertsReportTab extends StatefulWidget {
  final String ownerUserId;
  final CrmNameOf nameOf;
  final String today;
  const CrmAlertsReportTab({super.key, required this.ownerUserId, required this.nameOf, required this.today});

  @override
  State<CrmAlertsReportTab> createState() => _CrmAlertsReportTabState();
}

class _CrmAlertsReportTabState extends State<CrmAlertsReportTab> {
  String _kind = '';

  void _open(CrmSalesAlert alert) {
    switch (alert.kind) {
      case 'QUOTE_PENDING':
        CrmRoutes.openQuote(context, alert.id);
      case 'CONTRACT_EXPIRING':
        CrmRoutes.openContract(context, alert.id);
      default:
        CrmRoutes.openOrder(context, alert.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = {'ownerUserId': widget.ownerUserId, 'kind': _kind};
    return CrmReportLoader<CrmSalesAlertList>(
      query: query,
      loader: CrmReportsRepository.instance.alerts,
      fallbackKey: 'crm.reports.alerts.load_failed',
      builder: (context, data, loading, error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar([
            CrmFilterChip(
              placeholder: 'crm.reports.alerts.all_kinds'.tr(),
              value: _kind,
              searchable: false,
              options: crmLabelOptions({for (final k in kCrmSalesAlertKinds) k: crmAlertKindLabel(k)}),
              onChanged: (v) => setState(() => _kind = v ?? ''),
            ),
            CrmReportExportButton(
              enabled: data != null,
              onExport: () =>
                  crmShareWorkbook('canh-bao-ban-hang', widget.today, [crmAlertsSheet(data!, widget.nameOf)]),
            ),
          ]),
          if (data != null) CrmReportNote('crm.reports.alerts.note'.tr(args: {'days': data.contractExpiringDays})),
          if (error != null) CrmBanner(message: error),
          CrmLocalPagedList<CrmSalesAlert>(
            items: data?.items ?? const [],
            loading: loading,
            emptyText: 'crm.reports.alerts.empty'.tr(),
            noun: 'crm.reports.alerts.noun'.tr(),
            itemBuilder: (context, alert) => CrmCard(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () => _open(alert),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CrmCodeBadge(alert.code),
                      const Spacer(),
                      Flexible(
                        child: CrmStatusPill(
                          label: crmAlertKindLabel(alert.kind),
                          tone: _alertTone(alert.kind),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(alert.summary, style: const TextStyle(fontSize: 13, color: CrmColors.text, height: 1.35)),
                  const SizedBox(height: 4),
                  Text(widget.nameOf(alert.ownerUserId), style: const TextStyle(fontSize: 12, color: CrmColors.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Công nợ phải thu
// ---------------------------------------------------------------------------

/// Tab "Công nợ phải thu" (web `ReceivablesTab`). Bấm khách mở sổ công nợ; bấm đơn quá hạn mở đơn bán.
class CrmReceivablesReportTab extends StatelessWidget {
  final CrmReportFilters filters;
  final CrmNameOf nameOf;
  final String today;
  const CrmReceivablesReportTab({super.key, required this.filters, required this.nameOf, required this.today});

  @override
  Widget build(BuildContext context) {
    final query = {
      'ownerUserId': filters.ownerUserId,
      'customerGroupId': filters.customerGroupId,
      'region': filters.region,
    };
    return CrmReportLoader<CrmReceivableReport>(
      query: query,
      loader: CrmReportsRepository.instance.receivables,
      fallbackKey: 'crm.reports.receivables.load_failed',
      builder: (context, data, loading, error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar([
            CrmReportExportButton(
              enabled: data != null,
              onExport: () => crmShareWorkbook('cong-no-phai-thu', today, crmReceivableSheets(data!, nameOf)),
            ),
          ]),
          CrmReportNote('crm.reports.receivables.note'.tr(args: {'date': formatCrmDay(data?.asOf ?? today)})),
          if (error != null) CrmBanner(message: error),
          if (data != null)
            CrmReportStats(
              stats: [
                ('crm.reports.field.debit_revenue'.tr(), formatCrmMoney(data.totals.revenue)),
                ('crm.reports.field.collected'.tr(), formatCrmMoney(data.totals.collected)),
                ('crm.reports.field.uncollected'.tr(), formatCrmMoney(data.totals.uncollectedRevenue)),
                ('crm.reports.field.balance'.tr(), formatCrmMoney(data.totals.balance)),
                ('crm.reports.field.overdue'.tr(), formatCrmMoney(data.totals.overdueAmount)),
              ],
            ),
          CrmLocalPagedList<CrmReceivableReportCustomerRow>(
            items: data?.customers ?? const [],
            loading: loading,
            emptyText: 'crm.reports.receivables.empty'.tr(),
            noun: 'crm.reports.receivables.noun_customer'.tr(),
            itemBuilder: (context, row) => _ReceivableCustomerCard(row: row, nameOf: nameOf),
          ),
          const SizedBox(height: 4),
          CrmSectionTitle('crm.reports.receivables.overdue_orders'.tr()),
          if (loading && data == null)
            const CrmStateView(loading: true)
          else
            CrmLocalPagedList<CrmOverdueOrderRow>(
              items: data?.overdueOrders ?? const [],
              loading: loading,
              emptyText: 'crm.reports.receivables.no_overdue_orders'.tr(),
              noun: 'crm.reports.receivables.noun_order'.tr(),
              itemBuilder: (context, row) => CrmCard(
                margin: const EdgeInsets.only(bottom: 10),
                onTap: () => CrmRoutes.openOrder(context, row.orderId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [CrmCodeBadge(row.orderCode), const Spacer(), _money(row.overdueAmount, bold: true)]),
                    const SizedBox(height: 6),
                    Text(
                      '${row.customerCode} · ${row.customerName}',
                      style: const TextStyle(fontSize: 13, color: CrmColors.text),
                    ),
                    CrmInfoRow(
                      label: 'crm.reports.field.due_date'.tr(),
                      value: formatCrmDay(row.dueDate),
                      labelWidth: _lw,
                    ),
                    CrmInfoRow(
                      label: 'crm.reports.field.days_overdue'.tr(),
                      value: 'crm.reports.days'.tr(args: {'count': row.daysOverdue}),
                      labelWidth: _lw,
                    ),
                    CrmInfoRow(label: 'crm.reports.field.owner'.tr(), value: nameOf(row.ownerUserId), labelWidth: _lw),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReceivableCustomerCard extends StatelessWidget {
  final CrmReceivableReportCustomerRow row;
  final CrmNameOf nameOf;
  const _ReceivableCustomerCard({required this.row, required this.nameOf});

  @override
  Widget build(BuildContext context) {
    return CrmCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => CrmRoutes.openReceivables(context, row.customerId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CrmCodeBadge(row.customerCode),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  row.customerName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: CrmColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CrmInfoRow(
            label: 'crm.reports.field.debit_revenue'.tr(),
            labelWidth: _lw,
            child: _alignLeft(_money(row.revenue)),
          ),
          CrmInfoRow(
            label: 'crm.reports.field.collected'.tr(),
            labelWidth: _lw,
            child: _alignLeft(_money(row.collected)),
          ),
          CrmInfoRow(
            label: 'crm.reports.field.uncollected'.tr(),
            labelWidth: _lw,
            child: _alignLeft(_money(row.uncollectedRevenue)),
          ),
          CrmInfoRow(
            label: 'crm.reports.field.balance'.tr(),
            labelWidth: _lw,
            child: _alignLeft(_money(row.balance, bold: true)),
          ),
          if (row.overdueAmount != 0)
            CrmInfoRow(
              label: 'crm.reports.field.overdue'.tr(),
              labelWidth: _lw,
              child: Text(
                formatCrmMoney(row.overdueAmount),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CrmColors.danger),
              ),
            ),
          if (row.nextDueDate != null && row.nextDueDate!.isNotEmpty)
            CrmInfoRow(label: 'crm.reports.field.next_due'.tr(), value: formatCrmDay(row.nextDueDate), labelWidth: _lw),
          if (row.overdueOrderCount > 0)
            CrmInfoRow(
              label: 'crm.reports.field.overdue_orders'.tr(),
              value: formatCrmCount(row.overdueOrderCount),
              labelWidth: _lw,
            ),
          CrmInfoRow(label: 'crm.reports.field.owner'.tr(), value: nameOf(row.ownerUserId), labelWidth: _lw),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'crm.reports.receivables.ledger'.tr(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CrmColors.link),
            ),
          ),
        ],
      ),
    );
  }
}
