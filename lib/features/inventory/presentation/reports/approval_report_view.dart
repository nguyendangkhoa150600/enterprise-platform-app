import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../../../utils/user_resolver.dart';
import '../../data/reports/inventory_reports_repository.dart';
import '../../domain/reports/inventory_report_models.dart';
import '../utils/inventory_scope.dart';
import 'inventory_report_export.dart';
import 'inventory_report_labels.dart';
import 'inventory_report_widgets.dart';
import 'movement_report_view.dart' show ReportPeriod, reportPeriodFields;

String _t(String key, [Map<String, Object?>? args]) => 'inventory.reports.$key'.tr(args: args);

/// Lịch sử chứng từ phải duyệt theo kỳ (web `ApprovalReportView`).
class ApprovalReportView extends StatefulWidget {
  final List<ReportWarehouse> warehouses;
  const ApprovalReportView({super.key, required this.warehouses});

  @override
  State<ApprovalReportView> createState() => _ApprovalReportViewState();
}

class _ApprovalReportViewState extends State<ApprovalReportView> {
  final _repo = InventoryReportsRepository.instance;

  ReportPeriod _period = ReportPeriod.initial();
  String _docType = '';
  String _status = '';
  int _page = 1;
  int _pageSize = 50;
  StockApprovalReport? _report;
  bool _loading = false;
  bool _exporting = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<StockApprovalReport> _fetch(int limit, int offset) => _repo.loadApprovalReport(
    fromDate: _period.fromDate.isEmpty ? null : _period.fromDate,
    toDate: _period.toDate.isEmpty ? null : _period.toDate,
    warehouseCode: _period.warehouseCode.isEmpty ? null : _period.warehouseCode,
    docType: _docType.isEmpty ? null : _docType,
    status: _status.isEmpty ? null : _status,
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
      setState(() => _error = inventoryErrorMessage(e, 'inventory.reports.approvals.load_error'));
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

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final all = await loadAllReportPages<StockApprovalReportRow>((limit, offset) async {
        final page = await _fetch(limit, offset);
        return (rows: page.rows, total: page.total);
      });
      final intro = [
        _t('export.approval_intro', {
          'from': _period.fromDate.isEmpty ? '' : ReportFormat.date(_period.fromDate),
          'to': _period.toDate.isEmpty ? '' : ReportFormat.date(_period.toDate),
        }),
        _t('export.approval_actor_note'),
      ];
      await shareReportSheets('lich-su-duyet-kho-${_period.fromDate}-${_period.toDate}', [
        approvalReportSheet(all.rows, intro),
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

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ReportFilterGrid(
            children: [
              ...reportPeriodFields(
                value: _period,
                warehouses: widget.warehouses,
                onChanged: (p) => _update(() => _period = p),
              ),
              ReportSelectField(
                label: _t('filter.doc_type'),
                value: _docType,
                options: [
                  ReportOption('', _t('filter.all_approval_types')),
                  ...ReportLabels.approvalDocTypes.map((d) => ReportOption(d, ReportLabels.docType(d))),
                ],
                onChanged: (v) => _update(() => _docType = v),
              ),
              ReportSelectField(
                label: _t('filter.status'),
                value: _status,
                options: [
                  ReportOption('', _t('filter.all_statuses')),
                  ...ReportLabels.docStatuses.map((s) => ReportOption(s, ReportLabels.docStatus(s))),
                ],
                onChanged: (v) => _update(() => _status = v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ReportActions(loading: _loading, exporting: _exporting, onReload: _load, onExport: _export),
          const SizedBox(height: 12),
          if (_error != null) ReportErrorBanner(_error!),
          if (_loading && report == null) const ReportLoading(),
          if (_loading && report != null)
            const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 2)),
          if (report != null && report.rows.isEmpty) ReportEmpty(_t('approvals.empty')),
          if (report != null)
            ValueListenableBuilder<int>(
              valueListenable: UserResolver.changeNotifier,
              builder: (context, _, _) => Column(children: report.rows.map(_card).toList()),
            ),
          if (report != null && report.total > 0)
            ReportPager(
              page: _page,
              pageSize: _pageSize,
              total: report.total,
              totalLabel: _t('approvals.documents_total', {'n': ReportFormat.number(report.total)}),
              onChange: (p, s) {
                setState(() {
                  _page = p;
                  _pageSize = s;
                });
                _load();
              },
            ),
        ],
      ),
    );
  }

  /// Người thực hiện: thời điểm và tên tra từ danh bạ; không tra được thì hiện 8 ký tự đầu của id (web `Actor`).
  String _actor(String? id, String? at) {
    if ((id == null || id.isEmpty) && (at == null || at.isEmpty)) return '—';
    final time = at == null || at.isEmpty ? '—' : ReportFormat.dateTime(at);
    if (id == null || id.isEmpty) return time;
    final short = id.length > 8 ? id.substring(0, 8) : id;
    return '$time\n${UserResolver.resolve(id, fallback: short)}';
  }

  Widget _card(StockApprovalReportRow r) {
    final decision = r.rejectedAt != null ? _actor(r.rejectedBy, r.rejectedAt) : _actor(r.approvedBy, r.approvedAt);
    return ReportRowCard(
      title: r.documentCode,
      subtitle: '${ReportLabels.docType(r.docType)} · ${ReportFormat.date(r.documentDate)}',
      trailing: ReportBadge(ReportLabels.docStatus(r.status), ReportLabels.statusColors(r.status)),
      fields: [
        (_t('col.warehouse'), r.warehouseCode),
        (_t('col.reason'), r.reason ?? '—'),
        (_t('approvals.created'), _actor(r.createdBy, r.createdAt)),
        (_t('approvals.decision'), decision),
        (_t('col.posted_short'), _actor(r.postedBy, r.postedAt)),
        (_t('col.qty_increase'), ReportFormat.number(r.quantityIn)),
        (_t('col.qty_decrease'), ReportFormat.number(r.quantityOut)),
        (_t('col.value'), ReportFormat.number(r.value)),
      ],
      extra: [
        if (r.rejectReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _t('approvals.rejected_reason', {'reason': r.rejectReason}),
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ),
      ],
    );
  }
}
