import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hrm_attendance_monitor_models.dart';
import '../services/hrm_service.dart';
import '../core/i18n/app_i18n.dart';
import 'hrm_hub_screen.dart';
import 'attendance_monitor/components/monitor_kpi_section.dart';
import 'attendance_monitor/components/monitor_attention_section.dart';
import 'attendance_monitor/components/monitor_department_stats_section.dart';
import 'attendance_monitor/components/monitor_related_requests_section.dart';
import 'attendance_monitor/components/monitor_detail_bottom_sheet.dart';

class AttendanceMonitorScreen extends StatefulWidget {
  final String? initialDate;
  final VoidCallback? onOpenApprovals;

  const AttendanceMonitorScreen({
    super.key,
    this.initialDate,
    this.onOpenApprovals,
  });

  @override
  State<AttendanceMonitorScreen> createState() => _AttendanceMonitorScreenState();
}

class _AttendanceMonitorScreenState extends State<AttendanceMonitorScreen> {
  final HrmService _hrmService = HrmService();

  void _openApprovalsScreen() {
    if (widget.onOpenApprovals != null) {
      Navigator.pop(context, 'approvals');
      widget.onOpenApprovals!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HrmHubScreen(initialView: 'approvals'),
        ),
      );
    }
  }

  late DateTime _selectedDate;
  HrmAttendanceMonitor? _monitorData;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  Timer? _autoRefreshTimer;

  // Active Screen Tab: 'OVERVIEW' | 'ATTENTION'
  String _activeMonitorTab = 'OVERVIEW';

  // Filter state
  String _selectedTab = 'ALL'; // 'ALL', 'NOT_CHECKED_IN', 'LATE', 'EARLY_LEAVE', 'MISSING_PUNCH'
  String _selectedShift = 'ALL';
  String _selectedDepartment = 'ALL';
  String _selectedStatus = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Pagination for Attention List
  int _attentionPage = 1;
  static const int _attentionPageSize = 10;
  final GlobalKey _attentionSectionKey = GlobalKey();
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _attentionListScrollController = ScrollController();

  void _resetAttentionListScroll() {
    if (_attentionListScrollController.hasClients) {
      _attentionListScrollController.jumpTo(0.0);
    }
  }

  int get _totalAttentionCount {
    final rows = _monitorData?.rows ?? [];
    return rows.where((r) => _attentionStatuses.contains(r.status)).length;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      final parts = widget.initialDate!.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]) ?? DateTime.now().year;
        final m = int.tryParse(parts[1]) ?? DateTime.now().month;
        final d = int.tryParse(parts[2]) ?? DateTime.now().day;
        _selectedDate = DateTime(y, m, d);
      } else {
        _selectedDate = DateTime.now();
      }
    } else {
      _selectedDate = DateTime.now();
    }

    _loadData();

    // Auto-refresh every 60s when viewing today
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && _isToday) {
        _loadData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchCtrl.dispose();
    _mainScrollController.dispose();
    _attentionListScrollController.dispose();
    super.dispose();
  }

  String get _dateIsoString {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  String _formatLongDateVn(DateTime dt) {
    final weekdays = [
      'attendance.weekday.sun'.tr(),
      'attendance.weekday.mon'.tr(),
      'attendance.weekday.tue'.tr(),
      'attendance.weekday.wed'.tr(),
      'attendance.weekday.thu'.tr(),
      'attendance.weekday.fri'.tr(),
      'attendance.weekday.sat'.tr(),
    ];
    final w = weekdays[dt.weekday % 7];
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return '$w, $d/$m/$y';
  }

  String _formatDisplayDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return '$d/$m/$y';
  }

  String _formatUpdatedTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$h:$min';
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final data = await _hrmService.getAttendanceMonitor(date: _dateIsoString);
      if (mounted) {
        setState(() {
          _monitorData = data;
          _isLoading = false;
          _isRefreshing = false;
          if (data == null) {
            _errorMessage = 'att_monitor.error.no_access'.tr();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'att_monitor.error.connection'.tr(args: {'error': '$e'});
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD9AB00),
              onPrimary: Color(0xFF1A1A1A),
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _attentionPage = 1;
      });
      _loadData();
    }
  }

  // Shift & Department Options
  List<String> get _availableShifts {
    final rows = _monitorData?.rows ?? [];
    final set = <String>{};
    for (final r in rows) {
      if (r.shiftName != null && r.shiftName!.isNotEmpty) {
        set.add(r.shiftName!);
      }
    }
    return ['ALL', ...set.toList()..sort()];
  }

  List<String> get _availableDepartments {
    final rows = _monitorData?.rows ?? [];
    final set = <String>{};
    for (final r in rows) {
      if (r.departmentName != null && r.departmentName!.isNotEmpty) {
        set.add(r.departmentName!);
      }
    }
    return ['ALL', ...set.toList()..sort()];
  }

  // Attention status list matching Web
  static const List<String> _attentionStatuses = [
    'NOT_CHECKED_IN',
    'ABSENT',
    'LATE',
    'EARLY_LEAVE',
    'LATE_EARLY',
    'MISSING_PUNCH',
  ];

  bool _isRowCheckedIn(HrmMonitorRow row) {
    if (row.checkIn != null && row.checkIn!.trim().isNotEmpty) return true;
    return row.status == 'CHECKED_IN' || row.status == 'COMPLETED';
  }

  List<HrmMonitorRow> get _filteredAttentionRows {
    final rows = _monitorData?.rows ?? [];
    return rows.where((row) {
      // 1. Tab filter
      switch (_selectedTab) {
        case 'CHECKED_IN':
          if (!_isRowCheckedIn(row)) return false;
          break;
        case 'NOT_CHECKED_IN':
          if (row.status != 'NOT_CHECKED_IN' && row.status != 'ABSENT') return false;
          break;
        case 'LATE':
          if (row.status != 'LATE' && row.status != 'LATE_EARLY') return false;
          break;
        case 'EARLY_LEAVE':
          if (row.status != 'EARLY_LEAVE' && row.status != 'LATE_EARLY') return false;
          break;
        case 'MISSING_PUNCH':
          if (row.status != 'MISSING_PUNCH') return false;
          break;
        case 'ALL':
        default:
          if (row.status == 'DAY_OFF' || row.status == 'NO_SCHEDULE') return false;
          break;
      }

      // 2. Shift filter
      if (_selectedShift != 'ALL' && row.shiftName != _selectedShift) {
        return false;
      }

      // 3. Department filter
      if (_selectedDepartment != 'ALL' && row.departmentName != _selectedDepartment) {
        return false;
      }

      // 4. Status filter
      if (_selectedStatus != 'ALL') {
        if (_selectedStatus == 'CHECKED_IN') {
          if (!_isRowCheckedIn(row)) return false;
        } else if (row.status != _selectedStatus) {
          return false;
        }
      }

      // 5. Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = row.employeeName.toLowerCase();
        final code = row.employeeCode.toLowerCase();
        final dept = (row.departmentName ?? '').toLowerCase();
        if (!name.contains(q) && !code.contains(q) && !dept.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Tab counts
  int _countForTab(String tabKey) {
    final rows = _monitorData?.rows ?? [];
    return rows.where((row) {
      if (_selectedShift != 'ALL' && row.shiftName != _selectedShift) return false;
      if (_selectedDepartment != 'ALL' && row.departmentName != _selectedDepartment) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = row.employeeName.toLowerCase();
        final code = row.employeeCode.toLowerCase();
        if (!name.contains(q) && !code.contains(q)) return false;
      }

      switch (tabKey) {
        case 'CHECKED_IN':
          return _isRowCheckedIn(row);
        case 'NOT_CHECKED_IN':
          return row.status == 'NOT_CHECKED_IN' || row.status == 'ABSENT';
        case 'LATE':
          return row.status == 'LATE' || row.status == 'LATE_EARLY';
        case 'EARLY_LEAVE':
          return row.status == 'EARLY_LEAVE' || row.status == 'LATE_EARLY';
        case 'MISSING_PUNCH':
          return row.status == 'MISSING_PUNCH';
        case 'ALL':
        default:
          return row.status != 'DAY_OFF' && row.status != 'NO_SCHEDULE';
      }
    }).length;
  }

  // Related Requests
  List<Map<String, dynamic>> get _relatedRequests {
    final rows = _monitorData?.rows ?? [];
    final List<Map<String, dynamic>> out = [];
    for (final row in rows) {
      for (final req in row.requests) {
        if (req.status.toUpperCase() == 'REJECTED') continue;
        out.add({
          'employeeName': row.employeeName,
          'departmentName': row.departmentName,
          'kindLabel': req.kindLabel,
          'status': req.status,
          'statusLabel': req.statusLabel,
          'statusTextColor': req.statusTextColor,
          'statusBgColor': req.statusBgColor,
        });
      }
    }
    // Sort PENDING first
    out.sort((a, b) {
      final aPending = a['status'] == 'PENDING' ? 0 : 1;
      final bPending = b['status'] == 'PENDING' ? 0 : 1;
      return aPending.compareTo(bPending);
    });
    return out;
  }

  // Department Stats
  List<Map<String, dynamic>> get _departmentStats {
    final rows = _monitorData?.rows ?? [];
    final Map<String, List<int>> map = {}; // name -> [checkedIn, total]
    for (final row in rows) {
      if (row.status == 'DAY_OFF' || row.status == 'NO_SCHEDULE') continue;
      final name = row.departmentName ?? 'att_monitor.no_department'.tr();
      map.putIfAbsent(name, () => [0, 0]);
      map[name]![1] += 1;
      if (row.checkIn != null && row.checkIn!.isNotEmpty) {
        map[name]![0] += 1;
      }
    }
    final List<Map<String, dynamic>> list = [];
    map.forEach((name, counts) {
      final checkedIn = counts[0];
      final total = counts[1];
      final rate = total > 0 ? (checkedIn / total) * 100 : 0.0;
      list.add({
        'name': name,
        'checkedIn': checkedIn,
        'total': total,
        'rate': rate,
      });
    });
    list.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _monitorData?.summary ?? const HrmMonitorSummary();
    final updatedTime = _formatUpdatedTime(_monitorData?.generatedAt);

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
              _isToday ? 'att_monitor.title_today'.tr() : 'att_monitor.title_by_date'.tr(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              'att_monitor.subtitle'.tr(),
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh, size: 20),
            tooltip: 'common.refresh'.tr(),
            onPressed: () => _loadData(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9AB00)))
          : RefreshIndicator(
              onRefresh: () => _loadData(),
              color: const Color(0xFFD9AB00),
              child: ListView(
                controller: _mainScrollController,
                padding: const EdgeInsets.all(14),
                children: [
                  // 1. Controls Header: Date Picker, Shift Filter, Refresh Button
                  _buildTopControls(),
                  const SizedBox(height: 6),

                  // Subtext: Date + updated time + live green indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatLongDateVn(_selectedDate),
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      if (updatedTime.isNotEmpty) ...[
                        const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8))),
                        Text(
                          'att_monitor.updated_at'.tr(args: {'time': updatedTime}),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        if (_isToday) ...[
                          const SizedBox(width: 5),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tab Selector: Tổng quan & Cần theo dõi
                  _buildMonitorTabBar(_totalAttentionCount),
                  const SizedBox(height: 14),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_activeMonitorTab == 'OVERVIEW') ...[
                    // 2. 6 KPI Cards Grid matching Web
                    _buildKpiSection(summary),
                    const SizedBox(height: 14),

                    // Quick banner leading to Attention tab if any
                    if (_totalAttentionCount > 0) ...[
                      _buildAttentionQuickBanner(_totalAttentionCount),
                      const SizedBox(height: 14),
                    ],

                    // 3. Section: Tình hình theo phòng ban
                    _buildDepartmentStatsSection(updatedTime),
                    const SizedBox(height: 14),

                    // 4. Section: Đơn từ liên quan hôm nay
                    _buildRelatedRequestsSection(),
                    const SizedBox(height: 24),
                  ] else ...[
                    // TAB: CẦN THEO DÕI
                    _buildAttentionListSection(),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }

  // ==========================================
  // TAB BAR: Tổng quan & Cần theo dõi
  // ==========================================
  Widget _buildMonitorTabBar(int attentionCount) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildMonitorTabItem(
              id: 'OVERVIEW',
              label: 'att_monitor.tab.overview'.tr(),
              icon: Icons.dashboard_outlined,
              badge: null,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildMonitorTabItem(
              id: 'ATTENTION',
              label: 'att_monitor.tab.attention'.tr(),
              icon: Icons.warning_amber_rounded,
              badge: attentionCount > 0 ? '$attentionCount' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorTabItem({
    required String id,
    required String label,
    required IconData icon,
    String? badge,
  }) {
    final isActive = _activeMonitorTab == id;
    return InkWell(
      onTap: () {
        if (_activeMonitorTab != id) {
          setState(() {
            _activeMonitorTab = id;
          });
          if (id == 'ATTENTION') {
            _resetAttentionListScroll();
          }
        }
      },
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isActive
              ? const [
                  BoxShadow(color: Color(0x120F172A), blurRadius: 4, offset: Offset(0, 1)),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionQuickBanner(int count) {
    return MonitorAttentionQuickBanner(
      count: count,
      onTap: () {
        setState(() {
          _activeMonitorTab = 'ATTENTION';
        });
        _resetAttentionListScroll();
      },
    );
  }

  // ==========================================
  // TOP CONTROLS: Date, Shift, Button
  // ==========================================
  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x050F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Date picker button
              Expanded(
                flex: 5,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF475569)),
                        const SizedBox(width: 8),
                        Text(
                          _formatDisplayDate(_selectedDate),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Refresh button matching Web Savina Yellow
              ElevatedButton.icon(
                onPressed: () => _loadData(),
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF1A1A1A)),
                label: Text(
                  'common.refresh'.tr(),
                  style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC90A),
                  foregroundColor: const Color(0xFF1A1A1A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Shift dropdown filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedShift,
                isExpanded: true,
                menuMaxHeight: 260,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                items: _availableShifts.map((shift) {
                  return DropdownMenuItem<String>(
                    value: shift,
                    child: Text(shift == 'ALL' ? 'att_monitor.all_shifts'.tr() : shift),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedShift = val;
                      _attentionPage = 1;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ==========================================
  // DELEGATED SECTIONS
  // ==========================================
  Widget _buildKpiSection(HrmMonitorSummary s) {
    return MonitorKpiSection(
      summary: s,
      isToday: _isToday,
      onSelectKpiFilter: ({required String tab, required String status}) {
        setState(() {
          _activeMonitorTab = 'ATTENTION';
          _selectedTab = tab;
          _selectedStatus = status;
          _attentionPage = 1;
        });
        _resetAttentionListScroll();
      },
    );
  }

  void _goToPage(int page) {
    if (page == _attentionPage) return;
    setState(() {
      _attentionPage = page;
    });
    _resetAttentionListScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_attentionSectionKey.currentContext != null) {
        Scrollable.ensureVisible(
          _attentionSectionKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
      }
    });
  }

  Widget _buildAttentionListSection() {
    return MonitorAttentionSection(
      sectionKey: _attentionSectionKey,
      listScrollController: _attentionListScrollController,
      filteredRows: _filteredAttentionRows,
      currentPage: _attentionPage,
      pageSize: _attentionPageSize,
      selectedTab: _selectedTab,
      selectedDepartment: _selectedDepartment,
      selectedStatus: _selectedStatus,
      searchQuery: _searchQuery,
      searchCtrl: _searchCtrl,
      availableDepartments: _availableDepartments,
      countForTab: _countForTab,
      onTabChanged: (tab) {
        setState(() {
          _selectedTab = tab;
          _attentionPage = 1;
        });
      },
      onDepartmentChanged: (dept) {
        setState(() {
          _selectedDepartment = dept;
          _attentionPage = 1;
        });
      },
      onStatusChanged: (status) {
        setState(() {
          _selectedStatus = status;
          _attentionPage = 1;
        });
      },
      onSearchChanged: (v) {
        setState(() {
          _searchQuery = v;
          _attentionPage = 1;
        });
      },
      onClearSearch: () {
        _searchCtrl.clear();
        setState(() {
          _searchQuery = '';
          _attentionPage = 1;
        });
      },
      onGoToPage: _goToPage,
      onRowTap: _showDetailBottomSheet,
    );
  }

  Widget _buildRelatedRequestsSection() {
    return MonitorRelatedRequestsSection(
      requests: _relatedRequests,
      onOpenApprovals: _openApprovalsScreen,
    );
  }

  Widget _buildDepartmentStatsSection(String updatedTime) {
    return MonitorDepartmentStatsSection(
      departmentStats: _departmentStats,
      updatedTime: updatedTime,
    );
  }

  void _showDetailBottomSheet(HrmMonitorRow row) {
    showMonitorDetailBottomSheet(
      context,
      row: row,
      formattedSelectedDate: _formatLongDateVn(_selectedDate),
    );
  }
}
