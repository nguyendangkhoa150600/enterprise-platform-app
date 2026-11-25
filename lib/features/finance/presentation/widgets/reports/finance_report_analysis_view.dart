import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../utils/finance_csv_exporter.dart';
import '../common/finance_export_button.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_scope.dart';
import '../common/finance_ui.dart';
import '../common/finance_cashflow_chart.dart';
import '../common/finance_error_banner.dart';
import 'finance_report_sections.dart';
import 'finance_select_sheet.dart';

/// Báo cáo phân tích (web `AnalysisView`): KPI, dòng tiền, phân tích theo lý do/dự án, biến động tài khoản.
class FinanceReportAnalysisView extends StatefulWidget {
  final String from;
  final String to;
  final String accountId;
  final int refreshKey;

  /// Bộ lọc chung đặt ở đầu danh sách (cuộn cùng nội dung).
  final Widget header;

  const FinanceReportAnalysisView({
    super.key,
    required this.from,
    required this.to,
    required this.accountId,
    required this.refreshKey,
    required this.header,
  });

  @override
  State<FinanceReportAnalysisView> createState() => _FinanceReportAnalysisViewState();
}

class _FinanceReportAnalysisViewState extends State<FinanceReportAnalysisView> {
  final _scope = FinanceScope.instance;
  String _projectId = '';
  // Workspace tắt / chưa kết nối: không có ô lọc dự án, báo cáo vẫn chạy.
  List<FinanceWorkspaceProject> _projects = const [];
  FinanceReport? _report;
  bool _loading = true;
  String? _error;
  int _session = 0;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _load();
  }

  @override
  void didUpdateWidget(covariant FinanceReportAnalysisView old) {
    super.didUpdateWidget(old);
    if (old.from != widget.from ||
        old.to != widget.to ||
        old.accountId != widget.accountId ||
        old.refreshKey != widget.refreshKey) {
      _load();
    }
  }

  Future<void> _loadProjects() async {
    try {
      final result = await _scope.repository.getWorkspaceProjectOptions();
      if (!mounted) return;
      setState(() => _projects = result.items);
    } catch (_) {
      // Như web: lỗi tải dự án thì bỏ qua, ẩn ô lọc.
    }
  }

  Future<void> _load() async {
    if (widget.from.isEmpty || widget.to.isEmpty) return;
    final mine = ++_session;
    setState(() => _loading = true);
    try {
      final report = await _scope.repository.getReport(
        from: widget.from,
        to: widget.to,
        accountId: widget.accountId.isEmpty ? null : widget.accountId,
        projectId: _projectId.isEmpty ? null : _projectId,
      );
      if (!mounted || mine != _session) return;
      setState(() {
        _report = report;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      _scope.onError(e);
      if (!mounted || mine != _session) return;
      setState(() {
        _error = financeErrorMessage(e, 'finance.reports.load_error');
        _loading = false;
      });
    }
  }

  Future<void> _pickProject() async {
    final result = await showFinanceSelectSheet(
      context,
      title: 'finance.reports.all_projects'.tr(),
      options: [for (final p in _projects) FinanceSelectOption(value: p.id, label: p.label)],
      selected: _projectId,
      clearLabel: 'finance.reports.all_projects'.tr(),
    );
    if (!mounted || result == null) return;
    _setProject(result.value ?? '');
  }

  void _setProject(String id) {
    if (id == _projectId) return;
    setState(() => _projectId = id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    String? projectName;
    for (final p in _projects) {
      if (p.id == _projectId) projectName = p.label;
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          widget.header,
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FinanceExportButton(
                label: 'finance.export.button_excel'.tr(),
                errorKey: 'finance.export.failed',
                onExport: report == null ? null : () => FinanceCsvExporter.exportReport(report),
              ),
            ),
          ),
          if (_projects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FinancePickerField(
                value: projectName,
                placeholder: 'finance.reports.all_projects'.tr(),
                onTap: _pickProject,
                onClear: () => _setProject(''),
              ),
            ),
          if (_error != null)
            report == null
                ? FinanceStateView(error: _error, onRetry: _load)
                : FinanceBanner(message: _error!),
          if (_loading && report == null) const FinanceStateView(loading: true),
          if (report != null) ..._content(report),
        ],
      ),
    );
  }

  List<Widget> _content(FinanceReport r) {
    final t = r.totals;
    return [
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 92,
        ),
        children: [
          FinanceStatTile(
              label: 'finance.reports.kpi_receipts'.tr(),
              value: formatFinanceMoney(t.receipts),
              valueColor: FinanceColors.income),
          FinanceStatTile(
              label: 'finance.reports.kpi_payments'.tr(),
              value: formatFinanceMoney(t.payments),
              valueColor: const Color(0xFFDC2626)),
          FinanceStatTile(
              label: 'finance.reports.kpi_net'.tr(),
              value: formatFinanceMoney(t.net),
              valueColor: t.net < 0 ? const Color(0xFFDC2626) : FinanceColors.income),
          FinanceStatTile(
              label: 'finance.reports.kpi_counts'.tr(),
              value: '${t.receiptCount} / ${t.paymentCount} / ${t.transferCount}'),
        ],
      ),
      const SizedBox(height: 12),
      FinanceCard(
        title: r.granularity == 'month'
            ? 'finance.reports.cashflow_month'.tr()
            : 'finance.reports.cashflow_day'.tr(),
        child: FinanceCashflowChart(points: r.cashflow),
      ),
      FinanceReportBreakdown(
          title: 'finance.reports.receipts_by_reason'.tr(),
          rows: r.receiptsByReason,
          total: t.receipts,
          color: FinanceColors.income),
      FinanceReportBreakdown(
          title: 'finance.reports.payments_by_reason'.tr(),
          rows: r.paymentsByReason,
          total: t.payments,
          color: const Color(0xFFDC2626)),
      FinanceReportBreakdown(
          title: 'finance.reports.receipts_by_project'.tr(),
          rows: r.receiptsByProject,
          total: t.receipts,
          color: FinanceColors.income),
      FinanceReportBreakdown(
          title: 'finance.reports.payments_by_project'.tr(),
          rows: r.paymentsByProject,
          total: t.payments,
          color: const Color(0xFFDC2626)),
      FinanceAccountMovementCard(accounts: r.accounts),
    ];
  }
}
