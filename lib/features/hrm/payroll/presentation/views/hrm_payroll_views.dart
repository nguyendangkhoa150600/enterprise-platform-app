import 'package:flutter/material.dart';
import 'package:power_quality_analysis/core/i18n/app_i18n.dart';
import 'package:power_quality_analysis/models/hrm_models.dart';
import 'package:power_quality_analysis/services/hrm_service.dart';

/// Màn hình quản lý Tiền lương & Chi trả (Payroll) chuẩn Web 1:1
class HrmPayrollView extends StatefulWidget {
  final List<Map<String, dynamic>> payrollPeriods;
  final List<HrmSalaryAdvanceItem> advances;
  final List<HrmEmployeeItem> employees;
  final HrmService hrmService;
  final Future<void> Function() onRefreshData;
  final void Function(String view) onNavigateToView;
  final String Function(double?) formatCurrency;

  const HrmPayrollView({
    super.key,
    required this.payrollPeriods,
    required this.advances,
    required this.employees,
    required this.hrmService,
    required this.onRefreshData,
    required this.onNavigateToView,
    required this.formatCurrency,
  });

  @override
  State<HrmPayrollView> createState() => _HrmPayrollViewState();
}

class _HrmPayrollViewState extends State<HrmPayrollView> {
  int _payrollSubTab = 0; // 0: Bảng lương, 1: Ứng và thu hồi
  String _payrollMonthFilter = 'ALL';
  String _payrollStatusFilter = 'ALL';
  String _payrollSearchQuery = '';
  final TextEditingController _payrollSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _payrollSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate KPI counts
    final openCount = widget.payrollPeriods.where((p) {
      final s = (p['status'] ?? p['state'] ?? '').toString().toUpperCase();
      return s == 'OPEN' || s == 'DRAFT' || s == 'IN_PROGRESS';
    }).length;

    final pendingCalcCount = widget.payrollPeriods.where((p) {
      final s = (p['status'] ?? p['state'] ?? '').toString().toUpperCase();
      return s == 'PENDING_CALCULATION' || s == 'READY';
    }).length;

    final pendingLockCount = widget.payrollPeriods.where((p) {
      final s = (p['status'] ?? p['state'] ?? '').toString().toUpperCase();
      return s == 'CALCULATED' || s == 'PENDING_LOCK' || s == 'REVIEW';
    }).length;

    final publishedCount = widget.payrollPeriods.where((p) {
      final s = (p['status'] ?? p['state'] ?? '').toString().toUpperCase();
      return s == 'PUBLISHED' || s == 'CLOSED' || s == 'LOCKED' || s == 'PAID';
    }).length;

    // 2. Filter periods
    final filteredPeriods = widget.payrollPeriods.where((p) {
      if (_payrollMonthFilter != 'ALL') {
        final m = (p['month'] ?? '').toString();
        if (m.isNotEmpty && m != _payrollMonthFilter) return false;
      }
      if (_payrollStatusFilter != 'ALL') {
        final s = (p['status'] ?? p['state'] ?? '').toString().toUpperCase();
        if (s != _payrollStatusFilter) return false;
      }
      if (_payrollSearchQuery.isNotEmpty) {
        final q = _payrollSearchQuery.toLowerCase();
        final code = (p['code'] ?? p['periodCode'] ?? '').toString().toLowerCase();
        final name = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
        if (!code.contains(q) && !name.contains(q)) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER TITLE & SUBTITLE ---
            Text(
              'hrm_ops.payroll.title'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'hrm_ops.payroll.subtitle'.tr(),
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),

            // --- TOP ACTIONS BAR ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showPayrollConfigBottomSheet,
                    icon: const Icon(Icons.settings_outlined, size: 15, color: Color(0xFF334155)),
                    label: Text(
                      'hrm_ops.payroll.config_btn'.tr(),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showCreatePayrollPeriodDialog,
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF0F172A)),
                  label: Text(
                    'hrm_ops.payroll.create_period'.tr(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAB308), // Web gold yellow
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // --- SUB TABS: BẢNG LƯƠNG | ỨNG VÀ THU HỒI ---
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  _buildPayrollSubTabItem(0, 'hrm_ops.payroll.tab.payroll'.tr()),
                  const SizedBox(width: 20),
                  _buildPayrollSubTabItem(1, 'hrm_ops.payroll.tab.advances'.tr()),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // --- TAB CONTENT ---
            if (_payrollSubTab == 1) ...[
              _buildSalaryAdvancesContent(),
            ] else ...[
              // 4 STAT CARDS (2x2 GRID)
              Row(
                children: [
                  Expanded(
                    child: _buildPayrollStatCard(
                      title: 'hrm_ops.payroll.status.open'.tr(),
                      count: openCount,
                      icon: Icons.calendar_today_outlined,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFEFF6FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPayrollStatCard(
                      title: 'hrm_ops.payroll.status.pending_calc'.tr(),
                      count: pendingCalcCount,
                      icon: Icons.description_outlined,
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildPayrollStatCard(
                      title: 'hrm_ops.payroll.status.pending_lock'.tr(),
                      count: pendingLockCount,
                      icon: Icons.access_time_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFF3E8FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPayrollStatCard(
                      title: 'hrm_ops.payroll.status.published'.tr(),
                      count: publishedCount,
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: const Color(0xFF059669),
                      iconBg: const Color(0xFFECFDF5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // FILTER BAR (Month, Search, Status)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Month Dropdown
                        Expanded(
                          flex: 5,
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _payrollMonthFilter,
                                isExpanded: true,
                                menuMaxHeight: 280,
                                borderRadius: BorderRadius.circular(10),
                                icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                items: [
                                  DropdownMenuItem(value: 'ALL', child: Text('hrm_ops.payroll.filter.all_months'.tr())),
                                  DropdownMenuItem(value: '2026-10', child: Text('hrm_ops.payroll.filter.month_10'.tr())),
                                  DropdownMenuItem(value: '2026-09', child: Text('hrm_ops.payroll.filter.month_09'.tr())),
                                  DropdownMenuItem(value: '2026-08', child: Text('hrm_ops.payroll.filter.month_08'.tr())),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _payrollMonthFilter = v);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Dropdown
                        Expanded(
                          flex: 5,
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _payrollStatusFilter,
                                isExpanded: true,
                                menuMaxHeight: 280,
                                borderRadius: BorderRadius.circular(10),
                                icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                items: [
                                  DropdownMenuItem(value: 'ALL', child: Text('hrm_ops.payroll.filter.all_statuses'.tr())),
                                  DropdownMenuItem(value: 'OPEN', child: Text('hrm_ops.payroll.status.open'.tr())),
                                  DropdownMenuItem(value: 'PENDING_CALCULATION', child: Text('hrm_ops.payroll.status.pending_calc'.tr())),
                                  DropdownMenuItem(value: 'CALCULATED', child: Text('hrm_ops.payroll.status.pending_lock'.tr())),
                                  DropdownMenuItem(value: 'PUBLISHED', child: Text('hrm_ops.payroll.status.published'.tr())),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _payrollStatusFilter = v);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Search box
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _payrollSearchCtrl,
                        onChanged: (val) => setState(() => _payrollSearchQuery = val.trim()),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'hrm_ops.payroll.search.hint'.tr(),
                          hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: _payrollSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _payrollSearchCtrl.clear();
                                    setState(() => _payrollSearchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // MAIN CONTENT: LIST OR EMPTY STATE
              if (filteredPeriods.isEmpty) ...[
                // 1:1 PIXEL-PERFECT WEB EMPTY STATE
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Document icon with blue calculator badge (matching web)
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              size: 38,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.calculate_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'hrm_ops.payroll.empty.title'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'hrm_ops.payroll.empty.desc'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _showCreatePayrollPeriodDialog,
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFF0F172A)),
                        label: Text(
                          'hrm_ops.payroll.empty.create_first'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEAB308),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // PERIOD LIST CARDS
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredPeriods.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final p = filteredPeriods[idx];
                    return _buildPayrollPeriodCard(p);
                  },
                ),
              ],
              const SizedBox(height: 16),

              // 3-STEP PROCESS WORKFLOW BANNER (QUY TRÌNH TẠO KỲ LƯƠNG)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Icon(Icons.menu_book_rounded, size: 17, color: Color(0xFF475569)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'hrm_ops.payroll.guide.title'.tr(),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'hrm_ops.payroll.guide.subtitle'.tr(),
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildPayrollProcessStep(
                      stepNum: '1',
                      title: 'hrm_ops.payroll.guide.step1.title'.tr(),
                      desc: 'hrm_ops.payroll.guide.step1.desc'.tr(),
                      isLast: false,
                    ),
                    _buildPayrollProcessStep(
                      stepNum: '2',
                      title: 'hrm_ops.payroll.guide.step2.title'.tr(),
                      desc: 'hrm_ops.payroll.guide.step2.desc'.tr(),
                      isLast: false,
                    ),
                    _buildPayrollProcessStep(
                      stepNum: '3',
                      title: 'hrm_ops.payroll.guide.step3.title'.tr(),
                      desc: 'hrm_ops.payroll.guide.step3.desc'.tr(),
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- SUB TAB BUTTON ITEM ---
  Widget _buildPayrollSubTabItem(int index, String label) {
    final isActive = _payrollSubTab == index;
    return InkWell(
      onTap: () => setState(() => _payrollSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFFD97706) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? const Color(0xFFB45309) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // --- KPI STAT CARD ---
  Widget _buildPayrollStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$count',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 4),
              Text(
                'hrm_ops.payroll.period_unit'.tr(),
                style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- PROCESS WORKFLOW STEP ITEM ---
  Widget _buildPayrollProcessStep({
    required String stepNum,
    required String title,
    required String desc,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEFF6FF),
                border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                stepNum,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 28,
                color: const Color(0xFFCBD5E1),
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- SALARY ADVANCES CONTENT FOR TAB 1 ---
  Widget _buildSalaryAdvancesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('hrm_ops.payroll.advances.list_title'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('hrm_ops.payroll.advances.total'.tr(args: {'count': widget.advances.length}), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('hrm_ops.payroll.advances.create_hint'.tr())),
                );
              },
              icon: const Icon(Icons.add, size: 15),
              label: Text('hrm_ops.payroll.advances.create_btn'.tr(), style: TextStyle(fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.advances.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.price_check_outlined, size: 40, color: Color(0xFF94A3B8)),
                SizedBox(height: 10),
                Text('hrm_ops.payroll.advances.empty_title'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                SizedBox(height: 4),
                Text('hrm_ops.payroll.advances.empty_desc'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.advances.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final adv = widget.advances[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(adv.employeeName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(widget.formatCurrency(adv.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(adv.reason, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('hrm_ops.payroll.advances.repayment_period'.tr(args: {'period': adv.repaymentPeriod}), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text('hrm_ops.payroll.advances.repaid'.tr(args: {'amount': widget.formatCurrency(adv.repaidAmount)}), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // --- PERIOD LIST CARD ---
  Widget _buildPayrollPeriodCard(Map<String, dynamic> p) {
    final code = p['code'] ?? p['periodCode'] ?? 'KL-2026';
    final name = p['name'] ?? p['title'] ?? 'hrm_ops.payroll.period.default_name'.tr();
    final status = (p['status'] ?? p['state'] ?? 'OPEN').toString().toUpperCase();
    final paymentDate = p['paymentDate'] ?? p['expectedPaymentDate'] ?? '05/11/2026';
    final empCount = p['employeeCount'] ?? p['totalEmployees'] ?? 0;
    final totalNet = (p['totalNet'] ?? p['netAmount'] ?? 0.0) as num;

    Color badgeBg;
    Color badgeText;
    String statusLabel;
    switch (status) {
      case 'OPEN':
      case 'DRAFT':
        badgeBg = const Color(0xFFEFF6FF);
        badgeText = const Color(0xFF1D4ED8);
        statusLabel = 'hrm_ops.payroll.status.open_short'.tr();
        break;
      case 'PENDING_CALCULATION':
      case 'READY':
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFB45309);
        statusLabel = 'hrm_ops.payroll.status.pending_calc'.tr();
        break;
      case 'CALCULATED':
      case 'PENDING_LOCK':
        badgeBg = const Color(0xFFF3E8FF);
        badgeText = const Color(0xFF6B21A8);
        statusLabel = 'hrm_ops.payroll.status.pending_lock'.tr();
        break;
      case 'PUBLISHED':
      case 'CLOSED':
      case 'PAID':
        badgeBg = const Color(0xFFECFDF5);
        badgeText = const Color(0xFF047857);
        statusLabel = 'hrm_ops.payroll.status.published'.tr();
        break;
      default:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF475569);
        statusLabel = status;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      code.toString(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name.toString(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('hrm_ops.payroll.period.pay_date'.tr(args: {'date': paymentDate}), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text('hrm_ops.payroll.period.headcount'.tr(args: {'count': empCount}), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('hrm_ops.payroll.period.total_net'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
              Text(widget.formatCurrency(totalNet.toDouble()), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _showPayrollPeriodDetailBottomSheet(p),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('common.view_detail'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
              ),
              const SizedBox(width: 6),
              if (status == 'OPEN' || status == 'DRAFT')
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('hrm_ops.payroll.period.calculating'.tr(args: {'code': p['code']}))),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  child: Text('hrm_ops.payroll.period.calc_btn'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              if (status == 'CALCULATED')
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('hrm_ops.payroll.period.finalized'.tr(args: {'code': p['code']}))),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  child: Text('hrm_ops.payroll.period.lock_btn'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MODAL: CẤU HÌNH LƯƠNG / OT ---
  void _showPayrollConfigBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('hrm_ops.payroll.config.title'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('hrm_ops.payroll.config.subtitle'.tr(), style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              _buildConfigAttributeRow('hrm_ops.payroll.config.std_days'.tr(), 'hrm_ops.payroll.config.std_days_val'.tr()),
              _buildConfigAttributeRow('hrm_ops.payroll.config.ot_weekday'.tr(), 'hrm_ops.payroll.config.ot_weekday_val'.tr()),
              _buildConfigAttributeRow('hrm_ops.payroll.config.ot_weekend'.tr(), 'hrm_ops.payroll.config.ot_weekend_val'.tr()),
              _buildConfigAttributeRow('hrm_ops.payroll.config.ot_holiday'.tr(), 'hrm_ops.payroll.config.ot_holiday_val'.tr()),
              _buildConfigAttributeRow('hrm_ops.payroll.config.night'.tr(), 'hrm_ops.payroll.config.night_val'.tr()),
              _buildConfigAttributeRow('hrm_ops.payroll.config.insurance'.tr(), 'hrm_ops.payroll.config.insurance_val'.tr()),
              _buildConfigAttributeRow('hrm_ops.payroll.config.self_deduction'.tr(), 'hrm_ops.payroll.config.self_deduction_val'.tr()),
              _buildConfigAttributeRow('hrm_ops.payroll.config.dependent_deduction'.tr(), 'hrm_ops.payroll.config.dependent_deduction_val'.tr()),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onNavigateToView('config');
                  },
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: Text('hrm_ops.payroll.config.goto_center'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- HELPER: REQUIRED FIELD LABEL WITH RED ASTERISK (1:1 WEB) ---
  Widget _buildRequiredLabel(String text) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        children: [
          TextSpan(text: text),
          const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- MODAL: TẠO KỲ LƯƠNG MỚI (MATCHING WEB 1:1) ---
  void _showCreatePayrollPeriodDialog() {
    final now = DateTime.now();
    final codeCtrl = TextEditingController();
    String? selectedTimesheetCode;
    String? selectedTimesheetName;
    DateTime? paymentDate;
    bool isSubmitting = false;

    final lockedOptions = [
      {'code': 'KC-2026-10', 'name': 'hrm_ops.payroll.create.ts1'.tr()},
      {'code': 'KC-2026-09', 'name': 'hrm_ops.payroll.create.ts2'.tr()},
      {'code': 'KC-2026-08', 'name': 'hrm_ops.payroll.create.ts3'.tr()},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'hrm_ops.payroll.create.title'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 1. Mã kỳ (VD: KL-2026-09) *
                    _buildRequiredLabel('hrm_ops.payroll.create.code_label'.tr()),
                    const SizedBox(height: 8),
                    TextField(
                      controller: codeCtrl,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Bảng công đã khóa *
                    _buildRequiredLabel('hrm_ops.payroll.create.timesheet_label'.tr()),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        _showSelectLockedTimesheetSheet(
                          context: ctx,
                          options: lockedOptions,
                          currentSelected: selectedTimesheetCode,
                          onSelected: (code, name) {
                            setModalState(() {
                              selectedTimesheetCode = code;
                              selectedTimesheetName = name;
                            });
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 17, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedTimesheetName ?? 'hrm_ops.payroll.create.timesheet_hint'.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: selectedTimesheetName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Ngày trả lương dự kiến *
                    _buildRequiredLabel('hrm_ops.payroll.create.pay_date_label'.tr()),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: paymentDate ?? DateTime(now.year, now.month + 1, 5),
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() => paymentDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              paymentDate != null
                                  ? '${paymentDate!.day.toString().padLeft(2, '0')}/${paymentDate!.month.toString().padLeft(2, '0')}/${paymentDate!.year}'
                                  : 'dd/mm/yyyy',
                              style: TextStyle(
                                fontSize: 13,
                                color: paymentDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions Footer (Hủy | Xác nhận) matching Web 1:1
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF8FAFC),
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('common.cancel'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final code = codeCtrl.text.trim();
                                  if (code.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('hrm_ops.payroll.create.err_code'.tr())),
                                    );
                                    return;
                                  }
                                  if (selectedTimesheetName == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('hrm_ops.payroll.create.err_timesheet'.tr())),
                                    );
                                    return;
                                  }
                                  if (paymentDate == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('hrm_ops.payroll.create.err_pay_date'.tr())),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSubmitting = true);
                                  final paymentDateStr =
                                      '${paymentDate!.day.toString().padLeft(2, '0')}/${paymentDate!.month.toString().padLeft(2, '0')}/${paymentDate!.year}';

                                  final payload = {
                                    'code': code,
                                    'name': 'hrm_ops.payroll.create.default_name'.tr(args: {'code': code}),
                                    'month': '2026-10',
                                    'timesheetPeriod': selectedTimesheetName,
                                    'paymentDate': paymentDateStr,
                                    'status': 'OPEN',
                                    'employeeCount': widget.employees.isNotEmpty ? widget.employees.length : 12,
                                    'totalGross': 125000000.0,
                                    'totalNet': 108500000.0,
                                  };

                                  final ok = await widget.hrmService.createPayrollPeriod(payload);
                                  if (!ok) {
                                    widget.payrollPeriods.insert(0, payload);
                                  } else {
                                    await widget.onRefreshData();
                                  }

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('hrm_ops.payroll.create.success'.tr(args: {'code': code})),
                                      backgroundColor: const Color(0xFF059669),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEAB308), // Web yellow
                            foregroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                                )
                              : Text('common.confirm'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- BOTTOM SHEET: CHỌN BẢNG CÔNG ĐÃ KHÓA (TÌM KIẾM HỖ TRỢ TIẾNG VIỆT) ---
  void _showSelectLockedTimesheetSheet({
    required BuildContext context,
    required List<Map<String, String>> options,
    required String? currentSelected,
    required void Function(String code, String name) onSelected,
  }) {
    String search = '';
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (pickerCtx) {
        return StatefulBuilder(
          builder: (pCtx, setPickerState) {
            final filtered = options.where((o) {
              if (search.isEmpty) return true;
              final q = search.toLowerCase();
              final code = (o['code'] ?? '').toLowerCase();
              final name = (o['name'] ?? '').toLowerCase();
              return code.contains(q) || name.contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(pickerCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'hrm_ops.payroll.picker.title'.tr(),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(pickerCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (v) => setPickerState(() => search = v.trim()),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'hrm_ops.payroll.picker.search_hint'.tr(),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        final isChosen = item['code'] == currentSelected;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          title: Text(
                            item['name'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isChosen ? FontWeight.bold : FontWeight.w500,
                              color: isChosen ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            'hrm_ops.payroll.picker.code'.tr(args: {'code': item['code']}),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          trailing: isChosen ? const Icon(Icons.check, size: 18, color: Color(0xFF2563EB)) : null,
                          onTap: () {
                            onSelected(item['code']!, item['name']!);
                            Navigator.pop(pickerCtx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL: CHI TIẾT KỲ LƯƠNG ---
  void _showPayrollPeriodDetailBottomSheet(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p['name'] ?? 'hrm_ops.payroll.detail.default_title'.tr(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildConfigAttributeRow('hrm_ops.payroll.detail.code'.tr(), p['code']?.toString() ?? 'N/A'),
              _buildConfigAttributeRow('hrm_ops.payroll.detail.timesheet'.tr(), p['timesheetPeriod']?.toString() ?? 'hrm_ops.payroll.detail.timesheet_default'.tr()),
              _buildConfigAttributeRow('hrm_ops.payroll.detail.pay_date'.tr(), p['paymentDate']?.toString() ?? '05/11/2026'),
              _buildConfigAttributeRow('hrm_ops.payroll.detail.employees'.tr(), 'hrm_ops.payroll.detail.employees_val'.tr(args: {'count': p['employeeCount'] ?? 12})),
              _buildConfigAttributeRow('hrm_ops.payroll.detail.gross'.tr(), widget.formatCurrency((p['totalGross'] as num?)?.toDouble() ?? 125000000.0)),
              _buildConfigAttributeRow('hrm_ops.payroll.detail.net'.tr(), widget.formatCurrency((p['totalNet'] as num?)?.toDouble() ?? 108500000.0)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('common.close'.tr()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfigAttributeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Màn hình Độc lập theo dõi Ứng & Thu hồi lương (salary advances)
class HrmSalaryAdvancesStandaloneView extends StatelessWidget {
  final List<HrmSalaryAdvanceItem> advances;
  final String Function(double?) formatCurrency;

  const HrmSalaryAdvancesStandaloneView({
    super.key,
    required this.advances,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('hrm_ops.payroll.advances.section_title'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('hrm_ops.payroll.advances.section_subtitle'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('hrm_ops.payroll.advances.create_hint'.tr())),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text('hrm_ops.payroll.advances.create_btn'.tr(), style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (advances.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.price_check_outlined, size: 40, color: Color(0xFF94A3B8)),
                  SizedBox(height: 10),
                  Text('hrm_ops.payroll.advances.empty_title'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 4),
                  Text('hrm_ops.payroll.advances.empty_desc'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: advances.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final adv = advances[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(adv.employeeName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text(formatCurrency(adv.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(adv.reason, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('hrm_ops.payroll.advances.repayment_period'.tr(args: {'period': adv.repaymentPeriod}), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text('hrm_ops.payroll.advances.repaid'.tr(args: {'amount': formatCurrency(adv.repaidAmount)}), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Màn hình Phiếu lương cá nhân (Personal Payslips)
class HrmPersonalPayslipsView extends StatelessWidget {
  final List<HrmPayslipItem> payslips;
  final String Function(double?) formatCurrency;

  const HrmPersonalPayslipsView({
    super.key,
    required this.payslips,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('hrm_ops.payroll.payslip.title'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Text('hrm_ops.payroll.payslip.subtitle'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          if (payslips.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
                  SizedBox(height: 10),
                  Text('hrm_ops.payroll.payslip.empty_title'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 4),
                  Text('hrm_ops.payroll.payslip.empty_desc'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payslips.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ps = payslips[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(ps.period, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('hrm_ops.payroll.payslip.paid'.tr(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 6),
                      _buildPayslipLine('hrm_ops.payroll.payslip.base'.tr(), formatCurrency(ps.baseSalary)),
                      _buildPayslipLine('hrm_ops.payroll.payslip.allowances'.tr(), formatCurrency(ps.allowances + ps.bonuses)),
                      _buildPayslipLine('hrm_ops.payroll.payslip.overtime'.tr(), formatCurrency(ps.overtimePay)),
                      _buildPayslipLine('hrm_ops.payroll.payslip.deductions'.tr(), '-${formatCurrency(ps.deductions)}', isDeduction: true),
                      const SizedBox(height: 6),
                      const Divider(color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('hrm_ops.payroll.payslip.net'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text(formatCurrency(ps.netSalary), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPayslipLine(String label, String value, {bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDeduction ? const Color(0xFFDC2626) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
