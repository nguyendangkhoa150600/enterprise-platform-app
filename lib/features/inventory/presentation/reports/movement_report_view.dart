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

/// Kỳ báo cáo: mặc định từ đầu tháng tới hôm nay theo giờ Việt Nam (web `initialPeriod`).
class ReportPeriod {
  final String fromDate;
  final String toDate;
  final String warehouseCode;
  const ReportPeriod({required this.fromDate, required this.toDate, this.warehouseCode = ''});

  factory ReportPeriod.initial() {
    final today = ReportFormat.todayInVietnam();
    return ReportPeriod(fromDate: '${today.substring(0, 8)}01', toDate: today);
  }

  ReportPeriod copyWith({String? fromDate, String? toDate, String? warehouseCode}) => ReportPeriod(
    fromDate: fromDate ?? this.fromDate,
    toDate: toDate ?? this.toDate,
    warehouseCode: warehouseCode ?? this.warehouseCode,
  );
}

/// Ba ô Từ ngày, Đến ngày, Kho (web `PeriodFields`).
List<Widget> reportPeriodFields({
  required ReportPeriod value,
  required List<ReportWarehouse> warehouses,
  required ValueChanged<ReportPeriod> onChanged,
}) => [
  ReportDateField(
    label: _t('filter.from_date'),
    value: value.fromDate,
    max: value.toDate,
    onChanged: (v) => onChanged(value.copyWith(fromDate: v)),
  ),
  ReportDateField(
    label: _t('filter.to_date'),
    value: value.toDate,
    min: value.fromDate,
    onChanged: (v) => onChanged(value.copyWith(toDate: v)),
  ),
  ReportSelectField(
    label: _t('filter.warehouse'),
    value: value.warehouseCode,
    options: [
      ReportOption('', _t('filter.all_warehouses')),
      ...warehouses.map((w) => ReportOption(w.code, '${w.code} - ${w.name}')),
    ],
    onChanged: (v) => onChanged(value.copyWith(warehouseCode: v)),
  ),
];

/// Báo cáo nhập xuất theo kỳ (web `MovementReportView`): tổng theo nhóm, theo loại chứng từ và kho, bút toán chi tiết.
class MovementReportView extends StatefulWidget {
  final List<ReportWarehouse> warehouses;
  const MovementReportView({super.key, required this.warehouses});

  @override
  State<MovementReportView> createState() => _MovementReportViewState();
}

class _MovementReportViewState extends State<MovementReportView> {
  static const int _breakdownPageSize = 20;

  final _repo = InventoryReportsRepository.instance;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  ReportPeriod _period = ReportPeriod.initial();
  String _category = '';
  String _docType = '';
  String _search = '';
  int _page = 1;
  int _pageSize = 50;
  int _breakdownPage = 1;
  StockMovementReport? _report;
  bool _loading = false;
  bool _exporting = false;
  String? _error;
  int _requestId = 0;

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

  Future<StockMovementReport> _fetch(int limit, int offset) => _repo.loadMovementReport(
    fromDate: _period.fromDate.isEmpty ? null : _period.fromDate,
    toDate: _period.toDate.isEmpty ? null : _period.toDate,
    warehouseCode: _period.warehouseCode.isEmpty ? null : _period.warehouseCode,
    category: _category.isEmpty ? null : _category,
    docType: _docType.isEmpty ? null : _docType,
    search: _search.trim().isEmpty ? null : _search.trim(),
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
      setState(() => _error = inventoryErrorMessage(e, 'inventory.reports.movements.load_error'));
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  /// Đổi bộ lọc thì về trang 1 (web `useEffect(() => setPage(1), [query])`).
  void _update(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
      _breakdownPage = 1;
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
      StockMovementReport? last;
      final all = await loadAllReportPages<StockMovementLine>((limit, offset) async {
        final page = await _fetch(limit, offset);
        last = page;
        return (rows: page.lines, total: page.total);
      });
      final report = last;
      if (report == null) return;
      final warehouse = _period.warehouseCode;
      final intro = [
        _t('export.movement_intro', {
              'from': ReportFormat.date(report.fromDate),
              'to': ReportFormat.date(report.toDate),
            }) +
            (warehouse.isNotEmpty ? _t('export.warehouse_suffix', {'code': warehouse}) : ''),
        if (all.truncated) _t('export.truncated_entries', {'max': kMaxExportRows, 'total': all.total}),
      ];
      await shareReportSheets(
        'bao-cao-nhap-xuat-${report.fromDate}-${report.toDate}',
        movementReportSheets(report, all.rows, intro),
      );
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (mounted) {
        showReportSnack(context, inventoryErrorMessage(e, 'inventory.reports.common.export_error'), error: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _filters(),
          const SizedBox(height: 12),
          if (_error != null) ReportErrorBanner(_error!),
          if (report != null)
            ReportStatStrip([
              ReportStat(_t('col.qty_in'), report.totals.quantityIn),
              ReportStat(_t('col.qty_out'), report.totals.quantityOut),
              ReportStat(_t('col.value_in'), report.totals.valueIn),
              ReportStat(_t('col.value_out'), report.totals.valueOut),
              ReportStat(_t('stats.entries'), report.totals.entries),
            ]),
          if (_loading && report == null) const ReportLoading(),
          if (_loading && report != null)
            const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 2)),
          if (report != null) ..._content(report),
        ],
      ),
    );
  }

  Widget _filters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportFilterGrid(
          children: [
            ...reportPeriodFields(
              value: _period,
              warehouses: widget.warehouses,
              onChanged: (p) => _update(() => _period = p),
            ),
            ReportSelectField(
              label: _t('filter.group'),
              value: _category,
              options: [
                ReportOption('', _t('filter.all_groups')),
                ...kStockMovementCategories.map((c) => ReportOption(c, ReportLabels.movementCategory(c))),
              ],
              onChanged: (v) => _update(() => _category = v),
            ),
            ReportSelectField(
              label: _t('filter.doc_type'),
              value: _docType,
              options: [
                ReportOption('', _t('filter.all_doc_types')),
                ...ReportLabels.docTypes.map((d) => ReportOption(d, ReportLabels.docType(d))),
              ],
              onChanged: (v) => _update(() => _docType = v),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _t('filter.search'),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.slate600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearch,
          style: const TextStyle(fontSize: 13),
          decoration: reportInputDecoration(hint: _t('movements.search_hint'), icon: Icons.search),
        ),
        const SizedBox(height: 10),
        ReportActions(loading: _loading, exporting: _exporting, onReload: _load, onExport: _export),
      ],
    );
  }

  List<(String, String)> _amounts(StockMovementAmounts a) => [
    (_t('col.qty_in'), ReportFormat.number(a.quantityIn)),
    (_t('col.qty_out'), ReportFormat.number(a.quantityOut)),
    (_t('col.value_in'), ReportFormat.number(a.valueIn)),
    (_t('col.value_out'), ReportFormat.number(a.valueOut)),
    (_t('col.entries'), ReportFormat.number(a.entries)),
  ];

  List<Widget> _content(StockMovementReport report) {
    // Tải lại có thể làm danh sách ngắn đi: giữ trang trong phạm vi (antd tự kẹp trang).
    final bPages = (report.breakdown.length / _breakdownPageSize).ceil().clamp(1, 1 << 30);
    final bPage = _breakdownPage.clamp(1, bPages);
    final bStart = (bPage - 1) * _breakdownPageSize;
    final breakdown = report.breakdown.skip(bStart).take(_breakdownPageSize).toList();
    return [
      ReportSectionTitle(_t('movements.by_group')),
      ...report.summary.map(
        (r) => ReportRowCard(title: ReportLabels.movementCategory(r.category), fields: _amounts(r.amounts)),
      ),
      ReportSectionTitle(_t('movements.by_type_warehouse')),
      if (report.breakdown.isEmpty) ReportEmpty(_t('movements.empty_breakdown')),
      ...breakdown.map(
        (r) => ReportRowCard(
          title: ReportLabels.movementCategory(r.category),
          subtitle: r.docType == null ? _t('movements.no_document') : ReportLabels.docType(r.docType),
          trailing: Text(
            r.warehouseCode,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
          ),
          fields: _amounts(r.amounts),
        ),
      ),
      if (report.breakdown.length > _breakdownPageSize)
        ReportPager(
          page: bPage,
          pageSize: _breakdownPageSize,
          total: report.breakdown.length,
          totalLabel: '',
          showSizeChanger: false,
          onChange: (p, _) => setState(() => _breakdownPage = p),
        ),
      ReportSectionTitle(_t('movements.lines')),
      if (report.lines.isEmpty) ReportEmpty(_t('movements.empty_lines')),
      ...report.lines.map(_lineCard),
      if (report.lines.isNotEmpty || report.total > 0)
        ReportPager(
          page: _page,
          pageSize: _pageSize,
          total: report.total,
          totalLabel: _t('movements.entries_total', {'n': ReportFormat.number(report.total)}),
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

  Widget _lineCard(StockMovementLine l) {
    final docLabel = [
      l.docType == null ? _t('movements.no_document') : ReportLabels.docType(l.docType),
      if (l.reversesDocumentCode != null) _t('movements.reverses', {'code': l.reversesDocumentCode}),
    ].join(' · ');
    final positive = l.quantity >= 0;
    return ReportRowCard(
      title: l.documentCode ?? l.transactionCode,
      subtitle: docLabel,
      trailing: Text(
        '${l.quantity > 0 ? '+' : ''}${ReportFormat.number(l.quantity)}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: positive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
        ),
      ),
      fields: [
        (_t('col.posted_short'), ReportFormat.dateTime(l.postedAt)),
        (_t('col.group'), ReportLabels.movementCategory(l.category)),
        (_t('col.warehouse'), l.warehouseCode),
        (_t('col.material'), '${l.materialCode}\n${l.materialName}'),
        (_t('col.unit_cost'), ReportFormat.number(l.unitCost)),
        (_t('col.value'), ReportFormat.number(l.value)),
      ],
    );
  }
}
