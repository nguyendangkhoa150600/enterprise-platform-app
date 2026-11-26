import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/dashboard/dashboard_repository.dart';
import '../../domain/crm_capabilities.dart';
import '../../domain/dashboard/crm_dashboard_models.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../utils/crm_scope.dart';
import 'crm_dashboard_charts.dart';
import 'crm_dashboard_model.dart';

/// Tổng quan Bán hàng (web `dashboard/dashboard-page.tsx`): thẻ chỉ số so với kỳ trước, xu hướng doanh thu và đơn
/// mới, dự án bán hàng theo giai đoạn, khách hàng và sản phẩm doanh thu cao nhất, các việc cần chú ý.
class CrmDashboardScreen extends StatefulWidget {
  const CrmDashboardScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmDashboardScreen> createState() => _CrmDashboardScreenState();
}

class _CrmDashboardScreenState extends State<CrmDashboardScreen> {
  String _period = 'month';
  String? _from;
  String? _to;
  CrmSalesDashboard? _dashboard;
  bool _loading = false;
  String? _error;
  int _request = 0;

  /// Web `dashboardQuery`: tuỳ chọn thiếu ngày thì chưa gọi.
  bool get _hasQuery => _period != 'custom' || (_from != null && _to != null);

  Future<void> _reload() async {
    if (!_hasQuery) return;
    final id = ++_request;
    setState(() => _loading = true);
    try {
      final next = await CrmDashboardRepository.instance.load(
        period: _period,
        from: _period == 'custom' ? _from : null,
        to: _period == 'custom' ? _to : null,
      );
      if (!mounted || id != _request) return;
      setState(() {
        _dashboard = next;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted || id != _request) return;
      setState(() {
        _error = crmErrorMessage(e, 'crm.dashboard.load_failed');
        _loading = false;
      });
    }
  }

  void _setPeriod(String period) {
    // Chuyển sang "Tuỳ chọn" thì bắt đầu từ kỳ đang xem.
    if (period == 'custom' && _dashboard != null && _from == null) {
      _from = _dashboard!.range.from;
      _to = _dashboard!.range.to;
    }
    setState(() => _period = period);
    _reload();
  }

  Future<void> _pickDay(bool from) async {
    final current = parseCrmDay(from ? _from : _to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = crmApiDate(picked);
      } else {
        _to = crmApiDate(picked);
      }
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(
        context,
        CrmView.overview.label,
        actions: [
          IconButton(
            tooltip: 'crm.dashboard.reload'.tr(),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CrmColors.primary),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _reload,
          ),
        ],
      ),
      body: CrmPageGuard(
        view: CrmView.overview,
        onAllowed: _reload,
        builder: (context, status) => RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _toolbar(),
              if (_error != null) CrmBanner(message: _error!),
              if (!_hasQuery)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'crm.dashboard.custom_hint'.tr(),
                    style: const TextStyle(fontSize: 13, color: CrmColors.muted),
                  ),
                ),
              if (_dashboard != null)
                ..._content(_dashboard!, status.capabilities)
              else if (_loading)
                const CrmStateView(loading: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    final d = _dashboard;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.white,
              selectedBackgroundColor: CrmColors.primarySoft,
              selectedForegroundColor: CrmColors.primary,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            segments: [
              for (final p in kCrmDashboardPeriods)
                ButtonSegment(value: p, label: Text('crm.dashboard.period.$p'.tr(), maxLines: 1)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => _setPeriod(s.first),
          ),
          const SizedBox(height: 8),
          if (_period == 'custom')
            Row(
              children: [
                Expanded(child: _dayButton('crm.dashboard.from'.tr(), _from, () => _pickDay(true))),
                const SizedBox(width: 8),
                Expanded(child: _dayButton('crm.dashboard.to'.tr(), _to, () => _pickDay(false))),
              ],
            )
          else if (d != null)
            Text(
              '${formatCrmDay(d.range.from)} – ${formatCrmDay(d.range.to)}',
              style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
            ),
        ],
      ),
    );
  }

  Widget _dayButton(String label, String? value, VoidCallback onTap) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: CrmColors.text,
      side: const BorderSide(color: CrmColors.border),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    icon: const Icon(Icons.event_outlined, size: 16),
    label: Text('$label ${value == null ? '—' : formatCrmDay(value)}', overflow: TextOverflow.ellipsis),
  );

  void _open(CrmView view, [String? sub]) {
    if (sub == null) {
      CrmRoutes.open(context, view);
    } else {
      CrmRoutes.openSub(context, view, sub);
    }
  }

  List<Widget> _content(CrmSalesDashboard d, CrmCapabilities caps) {
    final cards = crmDashboardCards(d, caps);
    final salesView = crmCanOpenReports(caps) ? CrmView.reports : CrmView.orders;
    final k = d.kpis;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'crm.dashboard.scope_line'.tr(
            args: {
              'scope': 'crm.dashboard.scope.${d.scope}'.tr(),
              'from': formatCrmDay(d.previous.from),
              'to': formatCrmDay(d.previous.to),
              'asOf': formatCrmDay(d.asOf),
            },
          ),
          style: const TextStyle(fontSize: 12, color: CrmColors.muted, height: 1.4),
        ),
      ),
      _KpiGrid(cards: cards, onOpen: (card) => _open(card.view)),
      const SizedBox(height: 4),
      CrmCard(
        title: 'crm.dashboard.trend.title'.tr(),
        trailing: Text(
          'crm.dashboard.granularity.${d.granularity}'.tr(),
          style: const TextStyle(fontSize: 11.5, color: CrmColors.muted),
        ),
        child: (k.revenue.value != 0 || k.newOrders.value != 0)
            ? CrmRevenueTrendChart(granularity: d.granularity, buckets: d.buckets, onPick: () => _open(salesView))
            : _empty('crm.dashboard.trend.empty'.tr()),
      ),
      CrmCard(
        title: 'crm.dashboard.pipeline.title'.tr(),
        child: k.pipelineCount > 0
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CrmPipelineBars(rows: d.pipeline, onPick: () => _open(CrmView.opportunities)),
                  const Divider(height: 16, color: CrmColors.border),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'crm.dashboard.card.pipeline_hint'.tr(
                            args: {
                              'count': formatCrmCount(k.pipelineCount),
                              'weighted': formatCrmVndCompact(k.pipelineWeightedValue),
                            },
                          ),
                          style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                        ),
                      ),
                      Text(
                        formatCrmVndCompact(k.pipelineValue),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: CrmColors.text),
                      ),
                    ],
                  ),
                ],
              )
            : _empty('crm.dashboard.pipeline.empty'.tr()),
      ),
      CrmCard(
        title: 'crm.dashboard.top_customers'.tr(),
        trailing: Text('crm.dashboard.in_period'.tr(), style: const TextStyle(fontSize: 11.5, color: CrmColors.muted)),
        child: d.topCustomers.isEmpty
            ? _empty('crm.dashboard.top_empty'.tr())
            : Column(
                children: [
                  for (var i = 0; i < d.topCustomers.length; i++)
                    _RankRow(
                      rank: i + 1,
                      name: d.topCustomers[i].name,
                      code: d.topCustomers[i].code,
                      onTap: () => CrmRoutes.openCustomer(context, d.topCustomers[i].customerId),
                      revenue: d.topCustomers[i].revenue,
                      profit: d.topCustomers[i].profit,
                      extra: 'crm.dashboard.orders_count'.tr(
                        args: {'count': formatCrmCount(d.topCustomers[i].orderCount)},
                      ),
                    ),
                ],
              ),
      ),
      CrmCard(
        title: 'crm.dashboard.top_products'.tr(),
        trailing: Text('crm.dashboard.in_period'.tr(), style: const TextStyle(fontSize: 11.5, color: CrmColors.muted)),
        child: d.topProducts.isEmpty
            ? _empty('crm.dashboard.top_empty'.tr())
            : Column(
                children: [
                  for (var i = 0; i < d.topProducts.length; i++)
                    _RankRow(
                      rank: i + 1,
                      name: d.topProducts[i].name,
                      code: d.topProducts[i].code,
                      revenue: d.topProducts[i].revenue,
                      profit: d.topProducts[i].profit,
                      extra: 'crm.dashboard.quantity'.tr(args: {'value': formatCrmCount(d.topProducts[i].quantity)}),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 4),
      CrmSectionTitle('crm.dashboard.attention'.tr()),
      for (final kind in kCrmDashboardAttentionKinds) _attention(d, kind),
    ];
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, color: CrmColors.muted)),
  );

  Widget _attention(CrmSalesDashboard d, String kind) {
    final list = d.attention[kind] ?? const CrmDashboardAttentionList(0, []);
    final view = kCrmAttentionViews[kind]!;
    final key = crmAttentionKey(kind);
    final base = 'crm.dashboard.attention_kind.$key'.tr();
    final title = kind == 'expiringContracts'
        ? 'crm.dashboard.attention_days'.tr(args: {'label': base, 'days': d.contractExpiringDays})
        : base;
    return CrmCard(
      title: title,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: list.total > 0 ? const Color(0xFFFEF2F2) : CrmColors.divider,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          formatCrmCount(list.total),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: list.total > 0 ? CrmColors.danger : CrmColors.muted,
          ),
        ),
      ),
      child: list.items.isEmpty
          ? _empty('crm.dashboard.attention_empty.$key'.tr())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in list.items)
                  InkWell(
                    onTap: () => _open(view, item.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: CrmColors.link,
                                  ),
                                ),
                              ),
                              if (item.amount != null)
                                Text(
                                  formatCrmVndCompact(item.amount),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: CrmColors.text,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: CrmColors.body),
                          ),
                          Text(item.note, style: const TextStyle(fontSize: 11.5, color: CrmColors.muted)),
                        ],
                      ),
                    ),
                  ),
                if (list.total > list.items.length)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _open(view),
                      child: Text('crm.dashboard.see_all'.tr(args: {'count': formatCrmCount(list.total)})),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Lưới thẻ chỉ số 2 cột (web `kpiGrid`).
class _KpiGrid extends StatelessWidget {
  final List<CrmDashboardCard> cards;
  final ValueChanged<CrmDashboardCard> onOpen;
  const _KpiGrid({required this.cards, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _KpiCard(card: card, onTap: () => onOpen(card)),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final CrmDashboardCard card;
  final VoidCallback onTap;
  const _KpiCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final delta = card.delta;
    final deltaColor = switch (delta?.tone) {
      CrmDeltaTone.good => CrmColors.success,
      CrmDeltaTone.bad => CrmColors.danger,
      _ => CrmColors.muted,
    };
    return Material(
      color: card.danger ? const Color(0xFFFEF2F2) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: card.danger ? const Color(0xFFFECACA) : CrmColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: card.title == null ? null : () => showCrmSnack(context, '${card.label}: ${card.title}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: CrmColors.muted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  card.value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: card.danger ? CrmColors.danger : CrmColors.text,
                  ),
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 3),
                Text(
                  delta.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: deltaColor),
                ),
              ],
              if (card.hint != null) ...[
                const SizedBox(height: 3),
                Text(
                  card.hint!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: CrmColors.faint, height: 1.3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Một dòng bảng xếp hạng (khách hàng, sản phẩm): hạng, tên + mã, doanh thu, lợi nhuận, số phụ.
class _RankRow extends StatelessWidget {
  final int rank;
  final String name;
  final String code;
  final double revenue;
  final double profit;
  final String extra;
  final VoidCallback? onTap;

  const _RankRow({
    required this.rank,
    required this.name,
    required this.code,
    required this.revenue,
    required this.profit,
    required this.extra,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CrmColors.faint),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onTap == null ? CrmColors.text : CrmColors.link,
                    ),
                  ),
                  Text('$code · $extra', style: const TextStyle(fontSize: 11.5, color: CrmColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCrmVndCompact(revenue),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CrmColors.text),
                ),
                Text(
                  'crm.dashboard.profit_short'.tr(args: {'value': formatCrmVndCompact(profit)}),
                  style: TextStyle(fontSize: 11.5, color: profit < 0 ? CrmColors.danger : CrmColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
