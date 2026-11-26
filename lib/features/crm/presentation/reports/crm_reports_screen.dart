import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/common/crm_directory_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_paging.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../utils/crm_scope.dart';
import 'crm_report_tabs.dart';
import 'crm_reports_model.dart';

/// Báo cáo Bán hàng (web `reports/reports-page.tsx`): doanh thu, sản lượng, lợi nhuận theo chiều; tỷ lệ chuyển đổi;
/// cảnh báo; công nợ phải thu. Cần `crm.report.read` hoặc quản trị tenant (CrmPageGuard chặn theo menu). Xuất Excel
/// đúng bảng đang xem.
class CrmReportsScreen extends StatefulWidget {
  const CrmReportsScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmReportsScreen> createState() => _CrmReportsScreenState();
}

const List<String> _tabs = ['sales', 'conversion', 'alerts', 'receivables'];

class _CrmReportsScreenState extends State<CrmReportsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: _tabs.length, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });
  final String _today = crmTodayVn();
  late final List<CrmPeriodPreset> _presets = crmPeriodPresets(_today);
  late CrmReportFilters _filters = CrmReportFilters(from: _presets.first.from, to: _today);
  final TextEditingController _regionCtrl = TextEditingController();
  final CrmDebouncer _regionDebounce = CrmDebouncer(delay: const Duration(milliseconds: 400));

  @override
  void dispose() {
    _tabController.dispose();
    _regionCtrl.dispose();
    _regionDebounce.dispose();
    super.dispose();
  }

  String get _tab => _tabs[_tabController.index];

  void _set(CrmReportFilters next) => setState(() => _filters = next);

  Future<void> _pickDay(bool from) async {
    final current = parseCrmDay(from ? _filters.from : _filters.to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      // Web `max={filters.to}` / `min={filters.from}`.
      firstDate: from ? DateTime(2000) : (parseCrmDay(_filters.from) ?? DateTime(2000)),
      lastDate: from ? (parseCrmDay(_filters.to) ?? DateTime(2100)) : DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final value = crmApiDate(picked);
    _set(from ? _filters.copyWith(from: value) : _filters.copyWith(to: value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(
        context,
        CrmView.reports.label,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: CrmColors.primary,
          unselectedLabelColor: CrmColors.muted,
          indicatorColor: CrmColors.primary,
          labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          tabs: [for (final t in _tabs) Tab(text: 'crm.reports.tab.$t'.tr())],
        ),
      ),
      body: CrmPageGuard(
        view: CrmView.reports,
        builder: (context, _) => ValueListenableBuilder<List<CrmPerson>>(
          valueListenable: CrmScope.instance.people,
          builder: (context, people, _) =>
              ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [_filtersBar(people), _content()]),
        ),
      ),
    );
  }

  Widget _filtersBar(List<CrmPerson> people) {
    final periodTab = _tab == 'sales' || _tab == 'conversion';
    final groupTab = _tab == 'sales' || _tab == 'receivables';
    String? preset;
    for (final p in _presets) {
      if (p.from == _filters.from && p.to == _filters.to) preset = p.id;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (periodTab) ...[
            Row(
              children: [
                Expanded(child: _dayButton(_filters.from, () => _pickDay(true))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: CrmColors.muted)),
                ),
                Expanded(child: _dayButton(_filters.to, () => _pickDay(false))),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (periodTab)
                CrmFilterChip(
                  placeholder: 'crm.reports.custom_period'.tr(),
                  value: preset,
                  searchable: false,
                  options: [for (final p in _presets) CrmSelectOption(value: p.id, label: p.label)],
                  onChanged: (id) {
                    for (final p in _presets) {
                      if (p.id == id) _set(_filters.copyWith(from: p.from, to: p.to));
                    }
                  },
                ),
              CrmFilterChip(
                placeholder: 'crm.reports.all_employees'.tr(),
                value: _filters.ownerUserId,
                options: crmPeopleOptions(people),
                onChanged: (v) => _set(_filters.copyWith(ownerUserId: v ?? '')),
              ),
              if (groupTab)
                ValueListenableBuilder<List<CrmCustomerGroup>>(
                  valueListenable: CrmScope.instance.groups,
                  builder: (context, groups, _) => CrmFilterChip(
                    placeholder: 'crm.reports.all_groups'.tr(),
                    value: _filters.customerGroupId,
                    options: crmGroupOptions(groups),
                    onChanged: (v) => _set(_filters.copyWith(customerGroupId: v ?? '')),
                  ),
                ),
            ],
          ),
          if (groupTab) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _regionCtrl,
              maxLength: 100,
              decoration: crmInputDecoration(
                hint: 'crm.reports.region_hint'.tr(),
                prefixIcon: const Icon(Icons.place_outlined, size: 18, color: CrmColors.muted),
              ).copyWith(counterText: ''),
              onChanged: (_) => _regionDebounce.run(() {
                if (!mounted) return;
                final region = _regionCtrl.text.trim();
                if (region != _filters.region) _set(_filters.copyWith(region: region));
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayButton(String value, VoidCallback onTap) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: CrmColors.text,
      backgroundColor: Colors.white,
      side: const BorderSide(color: CrmColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    icon: const Icon(Icons.event_outlined, size: 16),
    label: Text(formatCrmDay(value)),
  );

  Widget _content() {
    final nameOf = CrmScope.instance.personName;
    return switch (_tab) {
      'sales' => CrmSalesReportTab(filters: _filters, nameOf: nameOf, today: _today),
      'conversion' => CrmConversionReportTab(filters: _filters, nameOf: nameOf, today: _today),
      'alerts' => CrmAlertsReportTab(ownerUserId: _filters.ownerUserId, nameOf: nameOf, today: _today),
      _ => CrmReceivablesReportTab(filters: _filters, nameOf: nameOf, today: _today),
    };
  }
}
