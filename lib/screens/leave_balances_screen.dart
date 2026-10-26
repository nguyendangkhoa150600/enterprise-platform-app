import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';
import '../models/hrm_leave_balance_models.dart';
import '../services/hrm_service.dart';
import 'leave_balances/components/leave_balance_card.dart';
import 'leave_balances/components/leave_adjustments_view.dart';
import 'leave_balances/components/leave_balance_detail_sheet.dart';

class LeaveBalancesScreen extends StatefulWidget {
  const LeaveBalancesScreen({super.key});

  @override
  State<LeaveBalancesScreen> createState() => _LeaveBalancesScreenState();
}

class _LeaveBalancesScreenState extends State<LeaveBalancesScreen> {
  final HrmService _hrmService = HrmService();

  int _selectedYear = DateTime.now().year;
  int _activeTab = 0; // 0: Quỹ phép, 1: Lịch sử điều chỉnh
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // 'ALL', 'OK', 'DEPLETED', 'OVER', 'NO_BALANCE', 'NO_CONTRACT'
  String _selectedDept = 'ALL';
  String _sortBy = 'NAME'; // 'NAME', 'REMAINING_DESC', 'REMAINING_ASC', 'USED_DESC', 'CODE'
  int _currentPage = 1;
  final int _pageSize = 20;

  List<HrmLeaveBalanceItem> _balances = [];
  List<HrmLeaveTransactionItem> _adjustments = [];
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Tab 2: Lịch sử điều chỉnh state
  int _adjYear = 0; // 0 = Tất cả các năm
  String _adjType = 'ALL'; // 'ALL', 'ADJUSTMENT', 'REVERSAL'
  String _adjSearchQuery = '';
  final TextEditingController _adjSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _adjYear = _selectedYear;
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (_currentPage * _pageSize < _filteredBalances.length) {
        setState(() {
          _currentPage++;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _adjSearchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (_activeTab == 0) {
        final raw = await _hrmService.getLeaveBalances(year: _selectedYear, annualOnly: true);
        final list = raw.map((e) => HrmLeaveBalanceItem.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _balances = list;
            _isLoading = false;
            _currentPage = 1;
          });
        }
      } else {
        final raw = await _hrmService.getLeaveAdjustmentsHistory(
          year: _adjYear == 0 ? null : _adjYear,
        );
        final list = raw.map((e) => HrmLeaveTransactionItem.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _adjustments = list;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[LeaveBalancesScreen] load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  List<HrmLeaveTransactionItem> get _filteredAdjustments {
    return _adjustments.where((tx) {
      if (_adjType != 'ALL') {
        final typeStr = tx.safeTransactionType.toUpperCase();
        if (_adjType == 'ADJUSTMENT' && typeStr != 'ADJUSTMENT') return false;
        if (_adjType == 'REVERSAL' && typeStr != 'REVERSAL') return false;
      }
      if (_adjYear != 0 && tx.balanceYear != null && tx.balanceYear != _adjYear) {
        return false;
      }
      if (_adjSearchQuery.isNotEmpty) {
        final q = _adjSearchQuery.toLowerCase();
        final name = tx.safeEmployeeName.toLowerCase();
        final code = tx.safeEmployeeCode.toLowerCase();
        final dept = (tx.department ?? '').toLowerCase();
        final actor = (tx.actorLabel ?? tx.createdByName ?? '').toLowerCase();
        final email = (tx.actorEmail ?? '').toLowerCase();
        final note = (tx.note ?? '').toLowerCase();
        final reason = (tx.reason ?? '').toLowerCase();
        if (!name.contains(q) &&
            !code.contains(q) &&
            !dept.contains(q) &&
            !actor.contains(q) &&
            !email.contains(q) &&
            !note.contains(q) &&
            !reason.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // All distinct departments
  List<String> get _allDepartments {
    final set = <String>{};
    for (final b in _balances) {
      final dept = (b.department ?? '').trim();
      if (dept.isNotEmpty) set.add(dept);
    }
    final list = set.toList()..sort();
    return ['ALL', ...list];
  }

  // Filtered and sorted rows for Flat List
  List<HrmLeaveBalanceItem> get _filteredBalances {
    final list = _balances.where((r) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = r.employeeName.toLowerCase();
        final code = r.employeeCode.toLowerCase();
        final dept = (r.department ?? '').toLowerCase();
        if (!name.contains(q) && !code.contains(q) && !dept.contains(q)) return false;
      }
      if (_selectedDept != 'ALL') {
        final d = (r.department ?? '').trim();
        if (d != _selectedDept) return false;
      }
      switch (_statusFilter) {
        case 'OK':
          return r.hasBalance && r.remaining > 0;
        case 'DEPLETED':
          return r.hasBalance && r.remaining == 0;
        case 'OVER':
          return r.hasBalance && r.remaining < 0;
        case 'NO_BALANCE':
          return !r.hasBalance;
        case 'NO_CONTRACT':
          return r.signDate == null && r.eligibleFrom == null;
        case 'ALL':
        default:
          return true;
      }
    }).toList();

    switch (_sortBy) {
      case 'REMAINING_DESC':
        list.sort((a, b) => b.remaining.compareTo(a.remaining));
        break;
      case 'REMAINING_ASC':
        list.sort((a, b) => a.remaining.compareTo(b.remaining));
        break;
      case 'USED_DESC':
        list.sort((a, b) => b.used.compareTo(a.used));
        break;
      case 'CODE':
        list.sort((a, b) => a.employeeCode.compareTo(b.employeeCode));
        break;
      case 'NAME':
      default:
        list.sort((a, b) => a.employeeName.compareTo(b.employeeName));
        break;
    }

    return list;
  }

  // Paginated rows
  List<HrmLeaveBalanceItem> get _displayedBalances {
    return _filteredBalances.take(_currentPage * _pageSize).toList();
  }


  String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'common.back'.tr(),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'leave.title'.tr(),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              'leave.header.breadcrumb'.tr(args: {'year': _selectedYear}),
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          // Year Selector
          PopupMenuButton<int>(
            initialValue: _selectedYear,
            onSelected: (y) {
              if (y != _selectedYear) {
                setState(() => _selectedYear = y);
                _loadData();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '$_selectedYear',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                ],
              ),
            ),
            itemBuilder: (_) => [
              for (int y = DateTime.now().year + 1; y >= DateTime.now().year - 3; y--)
                PopupMenuItem(value: y, child: Text('leave.year_label'.tr(args: {'year': y}))),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'common.refresh'.tr(),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Sub Tabs (Quỹ phép / Lịch sử điều chỉnh)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubTab(
                      index: 0,
                      label: 'leave.tab.balances'.tr(),
                      icon: Icons.calendar_view_month_rounded,
                      count: _balances.length,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildSubTab(
                      index: 1,
                      label: 'leave.tab.adjustments'.tr(),
                      icon: Icons.history_rounded,
                      count: _adjustments.isNotEmpty ? _adjustments.length : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Body view
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9AB00)))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFFD9AB00),
                    child: _activeTab == 0 ? _buildBalancesView() : _buildAdjustmentsView(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab({
    required int index,
    required String label,
    required IconData icon,
    int? count,
  }) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () {
        if (_activeTab != index) {
          setState(() => _activeTab = index);
          _loadData();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x100F172A), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: DANH SÁCH QUỸ PHÉP (FLAT LIST OPTIMIZED)
  // ==========================================
  Widget _buildBalancesView() {
    final totalFiltered = _filteredBalances.length;
    final displayed = _displayedBalances;
    final selectedDeptLabel = _selectedDept == 'ALL'
        ? 'leave.filter.all_departments_count'.tr(args: {'count': _allDepartments.length - 1})
        : _selectedDept;

    final sortLabel = {
      'NAME': 'leave.sort.name_short'.tr(),
      'REMAINING_DESC': 'leave.sort.remaining_desc_short'.tr(),
      'REMAINING_ASC': 'leave.sort.remaining_asc_short'.tr(),
      'USED_DESC': 'leave.sort.used_desc_short'.tr(),
      'CODE': 'leave.sort.code_short'.tr(),
    }[_sortBy] ?? 'leave.sort.label'.tr();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(14),
      children: [
        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _currentPage = 1;
              });
            },
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'leave.search_hint'.tr(),
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _searchQuery = '';
                          _currentPage = 1;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Department Picker Button & Sort Button
        Row(
          children: [
            // Department Picker Button
            Expanded(
              child: InkWell(
                onTap: _showDepartmentPickerSheet,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedDept != 'ALL' ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedDept != 'ALL' ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business_rounded,
                        size: 15,
                        color: _selectedDept != 'ALL' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          selectedDeptLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _selectedDept != 'ALL' ? FontWeight.bold : FontWeight.w500,
                            color: _selectedDept != 'ALL' ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedDept != 'ALL') ...[
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedDept = 'ALL';
                              _currentPage = 1;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.close, size: 14, color: Color(0xFF1D4ED8)),
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Sort Button
            InkWell(
              onTap: _showSortPickerSheet,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      sortLabel,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL', 'leave.chip.all'.tr(args: {'count': _balances.length})),
              const SizedBox(width: 6),
              _buildFilterChip('OK', 'leave.chip.ok'.tr(args: {'count': _balances.where((r) => r.hasBalance && r.remaining > 0).length})),
              const SizedBox(width: 6),
              _buildFilterChip('DEPLETED', 'leave.chip.depleted'.tr(args: {'count': _balances.where((r) => r.hasBalance && r.remaining == 0).length})),
              const SizedBox(width: 6),
              _buildFilterChip('OVER', 'leave.chip.over'.tr(args: {'count': _balances.where((r) => r.hasBalance && r.remaining < 0).length})),
              const SizedBox(width: 6),
              _buildFilterChip('NO_BALANCE', 'leave.chip.no_balance'.tr(args: {'count': _balances.where((r) => !r.hasBalance).length})),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Header Count Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'leave.list_title'.tr(args: {'count': totalFiltered}),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                'leave.showing'.tr(args: {'shown': displayed.length, 'total': totalFiltered}),
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Flat List of Employees
        if (totalFiltered == 0)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.person_search_outlined, size: 44, color: Color(0xFF94A3B8)),
                const SizedBox(height: 10),
                Text('leave.empty_filtered'.tr(), style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchCtrl.clear();
                      _searchQuery = '';
                      _selectedDept = 'ALL';
                      _statusFilter = 'ALL';
                      _currentPage = 1;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text('leave.filter.reset'.tr(), style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          )
        else ...[
          for (final item in displayed)
            _buildEmployeeBalanceCard(item),

          if (displayed.length < totalFiltered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentPage++;
                    });
                  },
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: Text(
                    'leave.load_more'.tr(args: {'count': totalFiltered - displayed.length}),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    backgroundColor: const Color(0xFFEFF6FF),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  void _showDepartmentPickerSheet() {
    String sheetSearch = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final depts = _allDepartments.where((d) {
            if (sheetSearch.isEmpty) return true;
            if (d == 'ALL') return 'leave.filter.all_departments'.tr().toLowerCase().contains(sheetSearch.toLowerCase());
            return d.toLowerCase().contains(sheetSearch.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'leave.dept.select'.tr(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Search inside sheet
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      onChanged: (val) => setSheetState(() => sheetSearch = val),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'leave.dept.search_hint'.tr(),
                        prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Expanded(
                  child: ListView.separated(
                    itemCount: depts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (c, i) {
                      final dept = depts[i];
                      final isSelected = _selectedDept == dept;
                      final count = dept == 'ALL'
                          ? _balances.length
                          : _balances.where((b) => (b.department ?? '').trim() == dept).length;
                      final label = dept == 'ALL' ? 'leave.filter.all_departments'.tr() : dept;

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          dept == 'ALL' ? Icons.apps_rounded : Icons.business_rounded,
                          size: 18,
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'leave.dept.staff_count'.tr(args: {'count': count}),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_rounded, size: 18, color: Color(0xFF2563EB)),
                            ],
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedDept = dept;
                            _currentPage = 1;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSortPickerSheet() {
    final options = [
      {'key': 'NAME', 'label': 'leave.sort.name'.tr(), 'icon': Icons.sort_by_alpha_rounded},
      {'key': 'REMAINING_DESC', 'label': 'leave.sort.remaining_desc'.tr(), 'icon': Icons.arrow_downward_rounded},
      {'key': 'REMAINING_ASC', 'label': 'leave.sort.remaining_asc'.tr(), 'icon': Icons.arrow_upward_rounded},
      {'key': 'USED_DESC', 'label': 'leave.sort.used_desc'.tr(), 'icon': Icons.event_busy_rounded},
      {'key': 'CODE', 'label': 'leave.sort.code'.tr(), 'icon': Icons.tag_rounded},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('leave.sort.sheet_title'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const SizedBox(height: 8),
            for (final opt in options)
              ListTile(
                dense: true,
                leading: Icon(opt['icon'] as IconData, size: 18, color: _sortBy == opt['key'] ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                title: Text(
                  opt['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _sortBy == opt['key'] ? FontWeight.bold : FontWeight.w500,
                    color: _sortBy == opt['key'] ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                  ),
                ),
                trailing: _sortBy == opt['key'] ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  setState(() => _sortBy = opt['key'] as String);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeBalanceCard(HrmLeaveBalanceItem row) {
    return EmployeeLeaveBalanceCard(
      row: row,
      onTap: () => _showHistoryDrawer(row),
      formatNumber: _formatNumber,
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = key;
          _currentPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ==========================================
  // TAB 2: Lá»ŠCH Sá»¬ ÄIá»€U CHá»ˆNH
  // ==========================================
  Widget _buildAdjustmentsView() {
    return LeaveAdjustmentsView(
      adjustments: _filteredAdjustments,
      searchCtrl: _adjSearchCtrl,
      searchQuery: _adjSearchQuery,
      selectedYear: _adjYear,
      selectedType: _adjType,
      onSearchChanged: (val) => setState(() => _adjSearchQuery = val.trim()),
      onClearSearch: () {
        _adjSearchCtrl.clear();
        setState(() => _adjSearchQuery = '');
      },
      onYearChanged: (val) {
        setState(() => _adjYear = val);
        _loadData();
      },
      onTypeChanged: (val) => setState(() => _adjType = val),
      onResetFilter: () {
        setState(() {
          _adjSearchCtrl.clear();
          _adjSearchQuery = '';
          _adjType = 'ALL';
          _adjYear = 0;
        });
        _loadData();
      },
      formatDateTime: _formatDateTime,
    );
  }

  // ==========================================
  // DRAWER Lá»ŠCH Sá»¬ QUá»¸ PHÃ‰P 1 NHÃ‚N VIÃŠN
  // ==========================================
  void _showHistoryDrawer(HrmLeaveBalanceItem balance) {
    showLeaveBalanceDetailSheet(
      context,
      balance: balance,
      hrmService: _hrmService,
    );
  }
}
