import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../widgets/report/report_kpi_cards.dart';
import '../widgets/report/report_monthly_chart.dart';
import '../widgets/report/report_data_table.dart';
import '../widgets/report/report_ledger_tab_view.dart';
import '../widgets/correspondence_outgoing_dialog.dart';
import '../widgets/correspondence_intake_dialog.dart';

/// Màn hình "Báo cáo Văn thư" (Correspondence Reports) đồng bộ 1:1 với Savina ERP Web
class CorrespondenceReportScreen extends StatefulWidget {
  const CorrespondenceReportScreen({super.key});

  @override
  State<CorrespondenceReportScreen> createState() => _CorrespondenceReportScreenState();
}

class _CorrespondenceReportScreenState extends State<CorrespondenceReportScreen> {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();

  late int _selectedYear;
  String _activeTab = 'stats'; // 'stats' | 'incoming' | 'outgoing'

  bool _isLoading = true;
  String? _errorMessage;

  CorrespondenceReport? _report;
  CorrespondenceStatus _status = const CorrespondenceStatus();
  String _today = '';

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      _today = '$y-$m-$d';

      final results = await Future.wait([
        _repository.getReport(_selectedYear),
        _repository.getStatus(),
      ]);

      if (!mounted) return;

      setState(() {
        _report = results[0] as CorrespondenceReport;
        _status = results[1] as CorrespondenceStatus;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'correspondence.report.load_failed'.tr();
        _isLoading = false;
      });
    }
  }

  void _onYearChanged(int year) {
    if (_selectedYear == year) return;
    setState(() {
      _selectedYear = year;
    });
    _loadData();
  }

  void _onTabChanged(String tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canCreateOutgoing = _status.canCreateOutgoing || _status.isTenantAdmin;
    final canRegister = _status.canRegister || _status.isTenantAdmin;
    final years = List.generate(6, (index) => DateTime.now().year - index);

    final tabs = [
      {'key': 'stats', 'label': 'correspondence.report.tab_stats'.tr()},
      {'key': 'incoming', 'label': 'correspondence.report.tab_incoming_register'.tr()},
      {'key': 'outgoing', 'label': 'correspondence.report.tab_outgoing_register'.tr()},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'correspondence.report.title'.tr(),
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.home_outlined, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'correspondence.report.breadcrumb'.tr(),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Nút Soạn công văn đi
          if (canCreateOutgoing)
            IconButton(
              icon: const Icon(Icons.edit_document, color: Color(0xFF0284C7)),
              tooltip: 'correspondence.overview.action_compose_outgoing'.tr(),
              onPressed: () => CorrespondenceOutgoingDialog.show(
                context,
                onCreated: _loadData,
              ),
            ),
          // Nút Tiếp nhận công văn đến
          if (canRegister)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF059669)),
              tooltip: 'correspondence.overview.action_register_incoming'.tr(),
              onPressed: () => CorrespondenceIntakeDialog.show(
                context,
                onCreated: _loadData,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            tooltip: 'common.refresh'.tr(),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0284C7),
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Toolbar: Dropdown Year Selector & Tabs
              Row(
                children: [
                  // Year Selector
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        onChanged: (val) {
                          if (val != null) _onYearChanged(val);
                        },
                        items: years.map((y) {
                          return DropdownMenuItem<int>(
                            value: y,
                            child: Text('correspondence.report.year_option'.tr(args: {'year': y})),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tabs
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: tabs.map((tab) {
                          final isSelected = _activeTab == tab['key'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => _onTabChanged(tab['key']!),
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Text(
                                  tab['label']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Tab Content
              if (_activeTab == 'stats') ...[
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else if (_errorMessage != null)
                  _buildErrorState()
                else if (_report != null) ...[
                  // KPI Cards
                  ReportKpiCards(totals: _report!.totals),
                  const SizedBox(height: 14),

                  // Theo tháng Chart
                  ReportMonthlyChart(byMonth: _report!.byMonth, year: _selectedYear),
                  const SizedBox(height: 14),

                  // Theo loại văn bản
                  ReportDataTable(title: 'correspondence.report.by_type'.tr(), rows: _report!.byType),
                  const SizedBox(height: 14),

                  // Theo phòng ban
                  ReportDataTable(title: 'correspondence.report.by_unit'.tr(), rows: _report!.byUnit),
                  const SizedBox(height: 20),
                ],
              ] else ...[
                // Sổ công văn đến hoặc Sổ công văn đi
                ReportLedgerTabView(
                  direction: _activeTab,
                  year: _selectedYear,
                  today: _today,
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('common.retry'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
