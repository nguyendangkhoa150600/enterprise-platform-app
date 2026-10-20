import 'package:flutter/material.dart';
import '../models/hrm_leave_balance_models.dart';
import '../services/hrm_service.dart';

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

  // Summary Metrics
  int get _totalWithBalance => _balances.where((r) => r.hasBalance).length;
  double get _totalEntitlement => _balances.where((r) => r.hasBalance).fold(0.0, (s, r) => s + r.entitlement);
  double get _totalUsed => _balances.where((r) => r.hasBalance).fold(0.0, (s, r) => s + r.used);
  double get _totalRemaining => _balances.where((r) => r.hasBalance).fold(0.0, (s, r) => s + r.remaining);

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
          tooltip: 'Quay lại',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quỹ phép năm & Thâm niên',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              'SVN DTS / Quản trị Nhân sự · Năm $_selectedYear',
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
                PopupMenuItem(value: y, child: Text('Năm $y')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Làm mới',
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
                      label: 'Quỹ phép',
                      icon: Icons.calendar_view_month_rounded,
                      count: _balances.length,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildSubTab(
                      index: 1,
                      label: 'Lịch sử điều chỉnh',
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
        ? 'Tất cả phòng ban (${_allDepartments.length - 1})'
        : _selectedDept;

    final sortLabel = {
      'NAME': 'Tên A-Z',
      'REMAINING_DESC': 'Còn phép ↓',
      'REMAINING_ASC': 'Còn phép ↑',
      'USED_DESC': 'Đã dùng ↓',
      'CODE': 'Mã NV',
    }[_sortBy] ?? 'Sắp xếp';

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(14),
      children: [
        // KPI Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Có quỹ năm',
                value: '$_totalWithBalance / ${_balances.length}',
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                icon: Icons.people_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                label: 'Tổng định mức',
                value: '${_formatNumber(_totalEntitlement)} ngày',
                color: const Color(0xFF0F172A),
                bgColor: const Color(0xFFF1F5F9),
                icon: Icons.calendar_today_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Đã sử dụng',
                value: '${_formatNumber(_totalUsed)} ngày',
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
                icon: Icons.event_busy_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                label: 'Còn lại khả dụng',
                value: '${_formatNumber(_totalRemaining)} ngày',
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

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
              hintText: 'Tìm nhân viên, mã số hoặc phòng ban...',
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
              _buildFilterChip('ALL', 'Tất cả (${_balances.length})'),
              const SizedBox(width: 6),
              _buildFilterChip('OK', 'Còn phép (${_balances.where((r) => r.hasBalance && r.remaining > 0).length})'),
              const SizedBox(width: 6),
              _buildFilterChip('DEPLETED', 'Hết phép (${_balances.where((r) => r.hasBalance && r.remaining == 0).length})'),
              const SizedBox(width: 6),
              _buildFilterChip('OVER', 'Vượt quỹ (${_balances.where((r) => r.hasBalance && r.remaining < 0).length})'),
              const SizedBox(width: 6),
              _buildFilterChip('NO_BALANCE', 'Chưa có quỹ (${_balances.where((r) => !r.hasBalance).length})'),
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
                'Danh sách nhân sự ($totalFiltered)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                'Hiển thị ${displayed.length} / $totalFiltered',
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
                const Text('Không có nhân viên nào phù hợp bộ lọc', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                  label: const Text('Đặt lại bộ lọc', style: TextStyle(fontSize: 12)),
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
                    'Tải thêm (còn ${totalFiltered - displayed.length} nhân sự)',
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
            if (d == 'ALL') return 'Tất cả phòng ban'.toLowerCase().contains(sheetSearch.toLowerCase());
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
                      const Text(
                        'Chọn phòng ban',
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
                      decoration: const InputDecoration(
                        hintText: 'Tìm nhanh phòng ban...',
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
                      final label = dept == 'ALL' ? 'Tất cả phòng ban' : dept;

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
                                '$count NS',
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
      {'key': 'NAME', 'label': 'Họ và tên (A → Z)', 'icon': Icons.sort_by_alpha_rounded},
      {'key': 'REMAINING_DESC', 'label': 'Còn phép nhiều nhất', 'icon': Icons.arrow_downward_rounded},
      {'key': 'REMAINING_ASC', 'label': 'Còn phép ít nhất / Đã hết', 'icon': Icons.arrow_upward_rounded},
      {'key': 'USED_DESC', 'label': 'Đã dùng phép nhiều nhất', 'icon': Icons.event_busy_rounded},
      {'key': 'CODE', 'label': 'Mã nhân viên (A → Z)', 'icon': Icons.tag_rounded},
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Sắp xếp danh sách', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
    final state = row.balanceState;
    Color stateTextColor;
    Color stateBgColor;

    switch (state) {
      case 'Còn phép':
        stateTextColor = const Color(0xFF047857);
        stateBgColor = const Color(0xFFD1FAE5);
        break;
      case 'Đang ứng phép':
        stateTextColor = const Color(0xFF1D4ED8);
        stateBgColor = const Color(0xFFDBEAFE);
        break;
      case 'Đã hết phép':
        stateTextColor = const Color(0xFFB45309);
        stateBgColor = const Color(0xFFFEF3C7);
        break;
      case 'Vượt quỹ':
        stateTextColor = const Color(0xFFB91C1C);
        stateBgColor = const Color(0xFFFEE2E2);
        break;
      case 'Chưa có HĐLĐ':
        stateTextColor = const Color(0xFFB45309);
        stateBgColor = const Color(0xFFFFFBEB);
        break;
      case 'Chưa có quỹ':
      default:
        stateTextColor = const Color(0xFF475569);
        stateBgColor = const Color(0xFFF1F5F9);
        break;
    }

    final deptName = (row.department ?? '').trim().isNotEmpty ? row.department!.trim() : 'Chưa phân phòng ban';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showHistoryDrawer(row),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Avatar, Name, Code, Department, Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF0F172A),
                    child: Text(
                      row.avatarInitials,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                row.employeeName,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                row.employeeCode,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.business_outlined, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                deptName,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: stateBgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: stateTextColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      state,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: stateTextColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Metrics Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildStatCell('Định mức', _formatNumber(row.entitlement)),
                    const SizedBox(width: 10),
                    _buildStatCell('Thâm niên', '+${_formatNumber(row.seniorityDays)}', color: const Color(0xFF059669)),
                    const SizedBox(width: 10),
                    _buildStatCell('Năm cũ', _formatNumber(row.carryover)),
                    const SizedBox(width: 10),
                    _buildStatCell('Đã dùng', _formatNumber(row.used), color: const Color(0xFFDC2626)),
                    const Spacer(),
                    // Remaining Days Box
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Còn lại', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        Text(
                          '${_formatNumber(row.remaining)} ngày',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: row.remaining > 0
                                ? const Color(0xFF059669)
                                : (row.remaining == 0 ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF0F172A)),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: LỊCH SỬ ĐIỀU CHỈNH
  // ==========================================
  Widget _buildAdjustmentsView() {
    final list = _filteredAdjustments;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Header Banner matching Web
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Text(
                    'Lịch sử điều chỉnh phép năm',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Mọi lần điều chỉnh và đảo điều chỉnh quỹ phép năm, kèm tài khoản đã thực hiện.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
              ),
              const SizedBox(height: 12),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _adjSearchCtrl,
                  onChanged: (val) {
                    setState(() => _adjSearchQuery = val.trim());
                  },
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo nhân viên, tài khoản thực hiện, lý do...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _adjSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _adjSearchCtrl.clear();
                              setState(() => _adjSearchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Row: Year & Type Dropdowns matching Web
              Row(
                children: [
                  // Year Filter Dropdown
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _adjYear,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                          items: [
                            const DropdownMenuItem<int>(
                              value: 0,
                              child: Text('Tất cả các năm', maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            for (int y = DateTime.now().year + 1; y >= DateTime.now().year - 3; y--)
                              DropdownMenuItem<int>(
                                value: y,
                                child: Text('Năm $y', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null && _adjYear != val) {
                              setState(() => _adjYear = val);
                              _loadData();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Type Filter Dropdown
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _adjType,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Tất cả điều chỉnh', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'ADJUSTMENT', child: Text('Điều chỉnh', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'REVERSAL', child: Text('Đảo điều chỉnh', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) {
                            if (val != null && _adjType != val) {
                              setState(() => _adjType = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Result count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Text(
                '${list.length} lần điều chỉnh',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const Spacer(),
              if (_adjSearchQuery.isNotEmpty || _adjType != 'ALL' || _adjYear != 0)
                InkWell(
                  onTap: () {
                    setState(() {
                      _adjSearchCtrl.clear();
                      _adjSearchQuery = '';
                      _adjType = 'ALL';
                      _adjYear = 0;
                    });
                    _loadData();
                  },
                  child: const Text(
                    'Đặt lại bộ lọc',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // List or Empty
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 50),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.history_toggle_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 10),
                const Text(
                  'Không tìm thấy lịch sử điều chỉnh phù hợp',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (_adjSearchQuery.isNotEmpty || _adjType != 'ALL') ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Thử thay đổi từ khóa tìm kiếm hoặc bộ lọc',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ],
            ),
          )
        else
          ...list.map((tx) => _buildAdjustmentCard(tx)),
      ],
    );
  }

  Widget _buildAdjustmentCard(HrmLeaveTransactionItem tx) {
    final isReversal = tx.safeTransactionType.toUpperCase() == 'REVERSAL' || tx.isReversed;
    final isNegative = tx.safeDaysChanged < 0;
    final isPositive = tx.safeDaysChanged > 0;
    final reasonText = (tx.reason ?? tx.note ?? '').trim();
    final actorName = tx.actorLabel ?? tx.createdByName ?? 'Hệ thống';
    final actorEmail = tx.actorEmail?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x050F172A), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Employee info on left, Badge & Days changed on right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    tx.employeeInitials,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.safeEmployeeName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${tx.safeEmployeeCode}${tx.department != null && tx.department!.isNotEmpty ? ' · ${tx.department}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Badge: "Điều chỉnh" (#FEF3C7, #B45309) / "Đảo điều chỉnh" (#EDE9FE, #6D28D9)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isReversal ? const Color(0xFFEDE9FE) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isReversal ? const Color(0xFFDDD6FE) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Text(
                        isReversal ? 'Đảo điều chỉnh' : 'Điều chỉnh',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isReversal ? const Color(0xFF6D28D9) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${tx.formattedDaysChanged} ngày',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: isNegative
                            ? const Color(0xFFDC2626)
                            : (isPositive ? const Color(0xFF059669) : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Row 2: Compact Strip (Time · Năm · Còn lại sau)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(tx.safeCreatedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                    ),
                  ),
                  if (tx.balanceYear != null) ...[
                    const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    Text(
                      'Năm ${tx.balanceYear}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Text(
                    'Còn lại sau: ',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  Text(
                    '${tx.formattedBalanceAfter} ngày',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),

            // Row 3: Lý do (Reason)
            if (reasonText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.3),
                    children: [
                      const TextSpan(
                        text: 'Lý do: ',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                      TextSpan(text: reasonText),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 6),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 5),

            // Row 4: Người thực hiện (Explicit Label)
            Row(
              children: [
                const Icon(Icons.account_circle_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                const Text(
                  'Người thực hiện: ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Expanded(
                  child: Text(
                    actorEmail != null && actorEmail.isNotEmpty
                        ? '$actorName ($actorEmail)'
                        : actorName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DRAWER LỊCH SỬ QUỸ PHÉP 1 NHÂN VIÊN
  // ==========================================
  void _showHistoryDrawer(HrmLeaveBalanceItem balance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LeaveBalanceDetailSheet(
        balance: balance,
        hrmService: _hrmService,
      ),
    );
  }
}

class _LeaveBalanceDetailSheet extends StatefulWidget {
  final HrmLeaveBalanceItem balance;
  final HrmService hrmService;

  const _LeaveBalanceDetailSheet({
    required this.balance,
    required this.hrmService,
  });

  @override
  State<_LeaveBalanceDetailSheet> createState() => _LeaveBalanceDetailSheetState();
}

class _LeaveBalanceDetailSheetState extends State<_LeaveBalanceDetailSheet> {
  bool _isLoading = true;
  List<HrmLeaveTransactionItem> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final raw = await widget.hrmService.getLeaveTransactions(
        employeeId: widget.balance.employeeId,
        year: widget.balance.year,
        leaveTypeId: widget.balance.leaveTypeId,
      );
      if (mounted) {
        setState(() {
          _transactions = raw.map((e) => HrmLeaveTransactionItem.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatNumber(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.balance;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.employeeName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${b.employeeCode} · ${b.department ?? 'Chưa có phòng ban'} · Năm ${b.year}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Balance Overview Strip
          Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderMetric('Định mức', _formatNumber(b.entitlement)),
                _buildHeaderMetric('Thâm niên', '+${_formatNumber(b.seniorityDays)}', color: const Color(0xFF059669)),
                _buildHeaderMetric('Chuyển tiếp', _formatNumber(b.carryover)),
                _buildHeaderMetric('Đã dùng', _formatNumber(b.used), color: const Color(0xFFDC2626)),
                _buildHeaderMetric('Còn lại', '${_formatNumber(b.remaining)} ngày',
                    color: b.remaining > 0 ? const Color(0xFF059669) : const Color(0xFFDC2626), isBold: true),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Transactions title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF0F172A)),
                const SizedBox(width: 6),
                const Text(
                  'Lịch sử giao dịch quỹ phép',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Text(
                  '${_transactions.length} giao dịch',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Transaction list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9AB00)))
                : _transactions.isEmpty
                    ? const Center(
                        child: Text('Chưa có phát sinh giao dịch nào', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, idx) {
                          final tx = _transactions[idx];
                          final isPositive = tx.isPositive;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  child: Icon(
                                    isPositive ? Icons.add : Icons.remove,
                                    size: 14,
                                    color: isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.typeLabel,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      if (tx.reason != null && tx.reason!.isNotEmpty)
                                        Text(
                                          tx.reason!,
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tx.safeCreatedAt.day.toString().padLeft(2, '0')}/${tx.safeCreatedAt.month.toString().padLeft(2, '0')}/${tx.safeCreatedAt.year}'
                                        '${tx.createdByName != null ? ' · ${tx.createdByName}' : ''}',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isPositive ? '+' : ''}${_formatNumber(tx.safeAmount)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                    Text(
                                      'Dư: ${_formatNumber(tx.safeBalanceAfter)}',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMetric(String label, String value, {Color? color, bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 13 : 11.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
