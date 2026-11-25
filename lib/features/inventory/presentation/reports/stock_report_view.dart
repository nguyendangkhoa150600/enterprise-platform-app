import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../data/reports/inventory_reports_repository.dart';
import '../../domain/reports/inventory_report_models.dart';
import '../utils/inventory_scope.dart';
import 'inventory_report_export.dart';
import 'inventory_report_labels.dart';
import 'inventory_report_widgets.dart';

String _t(String key, [Map<String, Object?>? args]) => 'inventory.reports.$key'.tr(args: args);

/// Báo cáo tồn theo kho, lô hoặc serial (web `StockReportView`).
class StockReportView extends StatefulWidget {
  final StockReportGroupBy groupBy;
  final List<ReportWarehouse> warehouses;
  final List<String> categories;
  const StockReportView({super.key, required this.groupBy, required this.warehouses, required this.categories});

  @override
  State<StockReportView> createState() => _StockReportViewState();
}

class _StockReportViewState extends State<StockReportView> {
  final _repo = InventoryReportsRepository.instance;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _search = '';
  String _category = '';
  String _warehouseCode = '';
  String _expiringWithinDays = '';
  String _qualityStatus = '';
  String _stockState = 'IN_STOCK';
  bool _includeZero = false;

  int _page = 1;
  int _pageSize = 50;
  StockReport? _report;
  bool _loading = false;
  bool _exporting = false;
  String? _error;
  int _requestId = 0;

  StockReportGroupBy get _g => widget.groupBy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<StockReport> _fetch(int limit, int offset) => _repo.loadStockReport(
    groupBy: _g,
    search: _search.trim().isEmpty ? null : _search.trim(),
    category: _category.isEmpty ? null : _category,
    warehouseCode: _warehouseCode.isEmpty ? null : _warehouseCode,
    expiringWithinDays: _g == StockReportGroupBy.lot && _expiringWithinDays.isNotEmpty
        ? int.tryParse(_expiringWithinDays)
        : null,
    qualityStatus: _g != StockReportGroupBy.warehouse && _qualityStatus.isNotEmpty ? _qualityStatus : null,
    stockState: _g == StockReportGroupBy.serial ? _stockState : null,
    includeZero: _g != StockReportGroupBy.serial ? _includeZero : null,
    limit: limit,
    offset: offset,
  );

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _fetch(_pageSize, (_page - 1) * _pageSize);
      if (!mounted || id != _requestId) return;
      setState(() => _report = result);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted || id != _requestId) return;
      setState(() => _error = inventoryErrorMessage(e, 'inventory.reports.stock.load_error'));
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
    _load();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _update(() => _search = value);
    });
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      StockReport? last;
      final wh = <StockReportWarehouseRow>[];
      final lot = <StockReportLotRow>[];
      final serial = <StockReportSerialRow>[];
      final all = await loadAllReportPages<Object>((limit, offset) async {
        final page = await _fetch(limit, offset);
        last = page;
        wh.addAll(page.warehouseRows);
        lot.addAll(page.lotRows);
        serial.addAll(page.serialRows);
        final rows = <Object>[...page.warehouseRows, ...page.lotRows, ...page.serialRows];
        return (rows: rows, total: page.total);
      });
      final report = last;
      if (report == null) return;
      final intro = [
        _t('export.stock_intro', {
          'view': ReportLabels.groupLabel(_g).toLowerCase(),
          'at': ReportFormat.dateTime(report.asOf),
        }),
        if (all.truncated) _t('export.truncated_rows', {'max': kMaxExportRows, 'total': all.total}),
      ];
      final rows = StockReport(
        groupBy: report.groupBy,
        total: all.total,
        asOf: report.asOf,
        warehouseRows: wh,
        lotRows: lot,
        serialRows: serial,
      );
      await shareReportSheets('bao-cao-ton-${_g.api.toLowerCase()}-${ReportFormat.todayInVietnam()}', [
        stockReportSheet(report, rows, intro),
      ]);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (mounted) {
        showReportSnack(context, inventoryErrorMessage(e, 'inventory.reports.common.export_error'), error: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<ReportOption> get _warehouseOptions => [
    ReportOption('', _t('filter.all_warehouses')),
    ...widget.warehouses.map((w) => ReportOption(w.code, '${w.code} - ${w.name}')),
  ];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _filters(),
          const SizedBox(height: 12),
          if (_error != null) ReportErrorBanner(_error!),
          if (_report != null) _totals(_report!),
          ..._rows(),
        ],
      ),
    );
  }

  Widget _filters() {
    final searchHint = switch (_g) {
      StockReportGroupBy.serial => _t('stock.search_serial'),
      StockReportGroupBy.lot => _t('stock.search_lot'),
      StockReportGroupBy.warehouse => _t('stock.search_material'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('filter.search'),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.slate600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearch,
          style: const TextStyle(fontSize: 13),
          decoration: reportInputDecoration(hint: searchHint, icon: Icons.search),
        ),
        const SizedBox(height: 10),
        ReportFilterGrid(
          children: [
            ReportSelectField(
              label: _t('filter.category'),
              value: _category,
              options: [
                ReportOption('', _t('filter.all_categories')),
                ...widget.categories.map((c) => ReportOption(c, c)),
              ],
              onChanged: (v) => _update(() => _category = v),
            ),
            ReportSelectField(
              label: _t('filter.warehouse'),
              value: _warehouseCode,
              options: _warehouseOptions,
              onChanged: (v) => _update(() => _warehouseCode = v),
            ),
            if (_g == StockReportGroupBy.lot)
              ReportSelectField(
                label: _t('filter.expiry'),
                value: _expiringWithinDays,
                options: [
                  ReportOption('', _t('filter.all_expiry')),
                  ...ReportLabels.expiryDays.map((d) => ReportOption(d, _t('filter.expiry_$d'))),
                ],
                onChanged: (v) => _update(() => _expiringWithinDays = v),
              ),
            if (_g == StockReportGroupBy.serial)
              ReportSelectField(
                label: _t('filter.stock_state'),
                value: _stockState,
                options: [
                  ReportOption('ALL', _t('filter.all_stock_states')),
                  ...ReportLabels.serialStates.map((s) => ReportOption(s, ReportLabels.serialState(s))),
                ],
                onChanged: (v) => _update(() => _stockState = v.isEmpty ? 'IN_STOCK' : v),
              ),
            if (_g != StockReportGroupBy.warehouse)
              ReportSelectField(
                label: _t('filter.quality'),
                value: _qualityStatus,
                options: [
                  ReportOption('', _t('filter.all_quality')),
                  ...ReportLabels.qualityStatuses.map((s) => ReportOption(s, ReportLabels.quality(s))),
                ],
                onChanged: (v) => _update(() => _qualityStatus = v),
              ),
          ],
        ),
        if (_g != StockReportGroupBy.serial)
          InkWell(
            onTap: () => _update(() => _includeZero = !_includeZero),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Checkbox(value: _includeZero, onChanged: (v) => _update(() => _includeZero = v ?? false)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _t('filter.include_zero'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.slate600),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ReportActions(loading: _loading, exporting: _exporting, onReload: _load, onExport: _export),
      ],
    );
  }

  Widget _totals(StockReport report) {
    if (report.groupBy == StockReportGroupBy.serial) {
      final t = report.serialTotals;
      return ReportStatStrip([
        ReportStat(_t('stats.serials'), t.serials),
        ReportStat(_t('stats.in_stock'), t.inStock),
        ReportStat(ReportLabels.blocked, t.blocked, warn: t.blocked != 0),
        ReportStat(ReportLabels.available, t.available),
      ]);
    }
    final t = report.quantityTotals;
    return ReportStatStrip([
      ReportStat(ReportLabels.onHand, t.onHand),
      ReportStat(ReportLabels.reserved, t.reserved),
      ReportStat(ReportLabels.blocked, t.blocked, warn: t.blocked != 0),
      ReportStat(ReportLabels.available, t.available),
      if (report.stockValueTotal != null) ReportStat(_t('col.stock_value'), report.stockValueTotal!),
    ]);
  }

  List<(String, String)> _qty(StockQuantities q) => [
    (ReportLabels.onHand, ReportFormat.number(q.onHand)),
    (ReportLabels.reserved, ReportFormat.number(q.reserved)),
    (ReportLabels.blocked, ReportFormat.number(q.blocked)),
    (ReportLabels.available, ReportFormat.number(q.available)),
  ];

  List<Widget> _rows() {
    final report = _report;
    if (_loading && (report == null || report.groupBy != _g)) return const [ReportLoading()];
    if (report == null) return const [];
    final cards = <Widget>[];
    switch (_g) {
      case StockReportGroupBy.warehouse:
        for (final r in report.warehouseRows) {
          cards.add(
            ReportRowCard(
              title: r.materialCode,
              subtitle: r.materialName,
              trailing: Text(
                r.warehouseCode,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
              ),
              fields: [
                (_t('col.warehouse'), r.warehouseName.isEmpty ? r.warehouseCode : r.warehouseName),
                (_t('col.category'), r.category ?? '—'),
                (_t('col.unit'), r.unit ?? '—'),
                ..._qty(r.qty),
                (_t('col.avg_cost'), ReportFormat.number(r.avgCost)),
                (_t('col.stock_value'), ReportFormat.number(r.stockValue)),
              ],
            ),
          );
        }
      case StockReportGroupBy.lot:
        for (final r in report.lotRows) {
          final d = r.daysToExpiry;
          final expiry = r.expiresOn == null
              ? '—'
              : [
                  ReportFormat.date(r.expiresOn),
                  if (d != null) d < 0 ? _t('lot.expired_days', {'n': -d}) : _t('lot.days_left', {'n': d}),
                ].join(' · ');
          cards.add(
            ReportRowCard(
              title: r.materialCode,
              subtitle: r.materialName,
              trailing: ReportBadge(ReportLabels.quality(r.qualityStatus), ReportLabels.qualityColors(r.qualityStatus)),
              fields: [
                (_t('col.lot_no'), r.lotNo),
                (_t('col.warehouse'), r.warehouseCode),
                (_t('col.expires_on'), expiry),
                ..._qty(r.qty),
              ],
            ),
          );
        }
      case StockReportGroupBy.serial:
        for (final r in report.serialRows) {
          cards.add(
            ReportRowCard(
              title: r.materialCode,
              subtitle: r.materialName,
              trailing: ReportBadge(ReportLabels.quality(r.qualityStatus), ReportLabels.qualityColors(r.qualityStatus)),
              fields: [
                (_t('col.serial'), r.serialNumber),
                (_t('col.warehouse'), r.warehouseCode ?? '—'),
                (_t('col.stock_state'), r.stockState == null ? '—' : ReportLabels.serialState(r.stockState)),
                (_t('col.updated_at'), ReportFormat.dateTime(r.updatedAt)),
              ],
            ),
          );
        }
    }
    if (cards.isEmpty) {
      final empty = switch (_g) {
        StockReportGroupBy.warehouse => _t('stock.empty_warehouse'),
        StockReportGroupBy.lot => _t('stock.empty_lot'),
        StockReportGroupBy.serial => _t('stock.empty_serial'),
      };
      return [if (_loading) const LinearProgressIndicator(minHeight: 2), ReportEmpty(empty)];
    }
    return [
      if (_loading) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 2)),
      ...cards,
      ReportPager(
        page: _page,
        pageSize: _pageSize,
        total: report.total,
        totalLabel: _t('common.rows_total', {'n': ReportFormat.number(report.total)}),
        onChange: (p, s) {
          setState(() {
            _page = p;
            _pageSize = s;
          });
          _load();
        },
      ),
    ];
  }
}
