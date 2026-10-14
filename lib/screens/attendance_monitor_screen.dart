import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hrm_attendance_monitor_models.dart';
import '../services/hrm_service.dart';
import 'hrm_hub_screen.dart';

class AttendanceMonitorScreen extends StatefulWidget {
  final String? initialDate;

  const AttendanceMonitorScreen({super.key, this.initialDate});

  @override
  State<AttendanceMonitorScreen> createState() => _AttendanceMonitorScreenState();
}

class _AttendanceMonitorScreenState extends State<AttendanceMonitorScreen> {
  final HrmService _hrmService = HrmService();

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
    const weekdays = [
      'Chủ nhật',
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
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
            _errorMessage = 'Không có quyền truy cập hoặc không thể tải dữ liệu giám sát chấm công.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'Lỗi kết nối: $e';
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

  List<HrmMonitorRow> get _filteredAttentionRows {
    final rows = _monitorData?.rows ?? [];
    return rows.where((row) {
      // 1. Must be an attention status
      if (!_attentionStatuses.contains(row.status)) return false;

      // 2. Tab filter
      switch (_selectedTab) {
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
          break;
      }

      // 3. Shift filter
      if (_selectedShift != 'ALL' && row.shiftName != _selectedShift) {
        return false;
      }

      // 4. Department filter
      if (_selectedDepartment != 'ALL' && row.departmentName != _selectedDepartment) {
        return false;
      }

      // 5. Status filter
      if (_selectedStatus != 'ALL' && row.status != _selectedStatus) {
        return false;
      }

      // 6. Search query
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
      if (!_attentionStatuses.contains(row.status)) return false;
      if (_selectedShift != 'ALL' && row.shiftName != _selectedShift) return false;
      if (_selectedDepartment != 'ALL' && row.departmentName != _selectedDepartment) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = row.employeeName.toLowerCase();
        final code = row.employeeCode.toLowerCase();
        if (!name.contains(q) && !code.contains(q)) return false;
      }

      switch (tabKey) {
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
          return true;
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
      final name = row.departmentName ?? 'Chưa có phòng ban';
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
          tooltip: 'Quay lại',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isToday ? 'Giám sát chấm công hôm nay' : 'Giám sát chấm công theo ngày',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Text(
              'SVN DTS / Quản trị Nhân sự',
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
            tooltip: 'Làm mới',
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
                          'Cập nhật: $updatedTime',
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
              label: 'Tổng quan',
              icon: Icons.dashboard_outlined,
              badge: null,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildMonitorTabItem(
              id: 'ATTENTION',
              label: 'Cần theo dõi',
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
    return InkWell(
      onTap: () {
        setState(() {
          _activeMonitorTab = 'ATTENTION';
        });
        _resetAttentionListScroll();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Có $count nhân sự cần theo dõi',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                  ),
                  const Text(
                    'Chưa vào ca, đi trễ, về sớm hoặc thiếu lượt chấm',
                    style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF991B1B)),
          ],
        ),
      ),
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
                label: const Text(
                  'Làm mới',
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
                    child: Text(shift == 'ALL' ? 'Tất cả ca làm việc' : shift),
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
  // 6 KPI CARDS GRID
  // ==========================================
  Widget _buildKpiSection(HrmMonitorSummary s) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                icon: Icons.people_outline,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                label: 'Tổng nhân sự\nđi ca ${_isToday ? 'hôm nay' : 'ngày này'}',
                value: '${s.scheduled}',
                subText: '/ ${s.totalPeople} nhân sự',
                onTap: () {
                  setState(() {
                    _activeMonitorTab = 'ATTENTION';
                    _selectedTab = 'ALL';
                    _selectedStatus = 'ALL';
                    _attentionPage = 1;
                  });
                  _resetAttentionListScroll();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                icon: Icons.check_circle_outline,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF059669),
                label: 'Đã vào ca',
                value: '${s.checkedIn}',
                subText: s.percentText(s.checkedIn),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                icon: Icons.schedule_outlined,
                iconBg: const Color(0xFFFEF2F2),
                iconColor: const Color(0xFFDC2626),
                label: 'Chưa chấm công',
                value: '${s.notCheckedIn}',
                subText: s.percentText(s.notCheckedIn),
                onTap: () {
                  setState(() {
                    _activeMonitorTab = 'ATTENTION';
                    _selectedTab = 'NOT_CHECKED_IN';
                    _selectedStatus = 'NOT_CHECKED_IN';
                    _attentionPage = 1;
                  });
                  _resetAttentionListScroll();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                icon: Icons.warning_amber_rounded,
                iconBg: const Color(0xFFFFFBEB),
                iconColor: const Color(0xFFD97706),
                label: 'Đi trễ',
                value: '${s.late}',
                subText: s.percentText(s.late),
                onTap: () {
                  setState(() {
                    _activeMonitorTab = 'ATTENTION';
                    _selectedTab = 'LATE';
                    _selectedStatus = 'LATE';
                    _attentionPage = 1;
                  });
                  _resetAttentionListScroll();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                icon: Icons.logout_rounded,
                iconBg: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFEA580C),
                label: 'Về sớm',
                value: '${s.earlyLeave}',
                subText: s.percentText(s.earlyLeave),
                onTap: () {
                  setState(() {
                    _activeMonitorTab = 'ATTENTION';
                    _selectedTab = 'EARLY_LEAVE';
                    _selectedStatus = 'EARLY_LEAVE';
                    _attentionPage = 1;
                  });
                  _resetAttentionListScroll();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                icon: Icons.calendar_month_outlined,
                iconBg: const Color(0xFFFAF5FF),
                iconColor: const Color(0xFF7C3AED),
                label: 'Đang nghỉ phép',
                value: '${s.onLeave}',
                subText: s.percentText(s.onLeave),
                onTap: () {
                  setState(() {
                    _activeMonitorTab = 'ATTENTION';
                    _selectedTab = 'ALL';
                    _selectedStatus = 'ALL';
                    _attentionPage = 1;
                  });
                  _resetAttentionListScroll();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required String subText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    subText,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SECTION: DANH SÁCH CẦN THEO DÕI
  // ==========================================
  Widget _buildAttentionListSection() {
    final list = _filteredAttentionRows;
    final totalItems = list.length;
    final totalPages = (totalItems / _attentionPageSize).ceil().clamp(1, 9999);
    final currentPage = _attentionPage.clamp(1, totalPages);
    final startIndex = totalItems == 0 ? 0 : (currentPage - 1) * _attentionPageSize;
    final endIndex = (startIndex + _attentionPageSize).clamp(0, totalItems);
    final pagedList = totalItems == 0 ? <HrmMonitorRow>[] : list.sublist(startIndex, endIndex);

    return Container(
      key: _attentionSectionKey,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Danh sách cần theo dõi ($totalItems)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (totalItems > _attentionPageSize)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Trang $currentPage / $totalPages',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Các nhân viên chưa vào ca, đi trễ, về sớm hoặc thiếu lượt chấm công.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {
              _searchQuery = v;
              _attentionPage = 1;
            }),
            decoration: InputDecoration(
              hintText: 'Tìm tên hoặc mã nhân viên...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _searchQuery = '';
                          _attentionPage = 1;
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 8),

          // Filters Row: Phòng ban & Trạng thái
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDepartment,
                      isExpanded: true,
                      menuMaxHeight: 260,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                      items: _availableDepartments.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept,
                          child: Text(dept == 'ALL' ? 'Tất cả phòng ban' : dept, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedDepartment = val;
                            _attentionPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      isExpanded: true,
                      menuMaxHeight: 260,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
                        DropdownMenuItem(value: 'NOT_CHECKED_IN', child: Text('Chưa vào ca')),
                        DropdownMenuItem(value: 'LATE', child: Text('Đi trễ')),
                        DropdownMenuItem(value: 'EARLY_LEAVE', child: Text('Về sớm')),
                        DropdownMenuItem(value: 'MISSING_PUNCH', child: Text('Thiếu lượt chấm')),
                        DropdownMenuItem(value: 'ABSENT', child: Text('Vắng mặt')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStatus = val;
                            _attentionPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabPill('ALL', 'Tất cả', _countForTab('ALL'), const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                const SizedBox(width: 6),
                _buildTabPill('NOT_CHECKED_IN', 'Chưa vào ca', _countForTab('NOT_CHECKED_IN'), const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                const SizedBox(width: 6),
                _buildTabPill('LATE', 'Đi trễ', _countForTab('LATE'), const Color(0xFFD97706), const Color(0xFFFFFBEB)),
                const SizedBox(width: 6),
                _buildTabPill('EARLY_LEAVE', 'Về sớm', _countForTab('EARLY_LEAVE'), const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
                const SizedBox(width: 6),
                _buildTabPill('MISSING_PUNCH', 'Thiếu lượt chấm', _countForTab('MISSING_PUNCH'), const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // List of Rows (Paginated to 10 per page)
          if (list.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  Icon(Icons.check_circle_outline, size: 36, color: Color(0xFF10B981)),
                  SizedBox(height: 8),
                  Text(
                    'Không có nhân viên nào cần theo dõi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tất cả nhân sự trong ca đều đã chấm công đúng quy định.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          else ...[
            // Khung cuộn hiển thị giới hạn 5 mục, cuộn được để xem đủ 10 mục của trang
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              padding: const EdgeInsets.all(4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: RawScrollbar(
                  controller: _attentionListScrollController,
                  thumbVisibility: true,
                  thumbColor: const Color(0xFF94A3B8),
                  radius: const Radius.circular(4),
                  thickness: 4,
                  child: ListView.separated(
                    controller: _attentionListScrollController,
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(4),
                    itemCount: pagedList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final row = pagedList[idx];
                      return _buildEmployeeAttentionCard(row);
                    },
                  ),
                ),
              ),
            ),
            if (totalItems > _attentionPageSize) ...[
              const SizedBox(height: 12),
              _buildPaginationControls(
                totalItems: totalItems,
                totalPages: totalPages,
                currentPage: currentPage,
                startIndex: startIndex,
                endIndex: endIndex,
              ),
            ],
          ],
        ],
      ),
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

  Widget _buildPaginationControls({
    required int totalItems,
    required int totalPages,
    required int currentPage,
    required int startIndex,
    required int endIndex,
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hiển thị ${startIndex + 1} – $endIndex / $totalItems nhân sự',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  '10 người / trang',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Nút "Trước"
              _buildPageActionButton(
                label: 'Trước',
                icon: Icons.chevron_left,
                enabled: currentPage > 1,
                onTap: () => _goToPage(currentPage - 1),
              ),
              const SizedBox(width: 8),

              // Danh sách số trang
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildPageNumberPills(totalPages, currentPage),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút "Sau"
              _buildPageActionButton(
                label: 'Sau',
                icon: Icons.chevron_right,
                iconAfter: true,
                enabled: currentPage < totalPages,
                onTap: () => _goToPage(currentPage + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageActionButton({
    required String label,
    required IconData icon,
    bool iconAfter = false,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!iconAfter) Icon(icon, size: 16, color: enabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
            if (!iconAfter) const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              ),
            ),
            if (iconAfter) const SizedBox(width: 2),
            if (iconAfter) Icon(icon, size: 16, color: enabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPageNumberPills(int totalPages, int currentPage) {
    final List<Widget> pills = [];

    if (totalPages <= 6) {
      for (int i = 1; i <= totalPages; i++) {
        pills.add(_buildSinglePagePill(i, i == currentPage));
        if (i < totalPages) pills.add(const SizedBox(width: 4));
      }
      return pills;
    }

    final Set<int> pagesToShow = {1, totalPages, currentPage, currentPage - 1, currentPage + 1};
    final sorted = pagesToShow.where((p) => p >= 1 && p <= totalPages).toList()..sort();

    int? prev;
    for (final p in sorted) {
      if (prev != null && p - prev > 1) {
        pills.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        );
      }
      pills.add(_buildSinglePagePill(p, p == currentPage));
      pills.add(const SizedBox(width: 4));
      prev = p;
    }
    if (pills.isNotEmpty) pills.removeLast();

    return pills;
  }

  Widget _buildSinglePagePill(int pageNumber, bool isActive) {
    return InkWell(
      onTap: () => _goToPage(pageNumber),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          '$pageNumber',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildTabPill(String id, String label, int count, Color activeColor, Color activeBg) {
    final active = _selectedTab == id;
    return InkWell(
      onTap: () => setState(() {
        _selectedTab = id;
        _attentionPage = 1;
      }),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? activeColor : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? activeColor : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // Employee Card item in list (compact to display 5 items comfortably per view)
  Widget _buildEmployeeAttentionCard(HrmMonitorRow row) {
    return InkWell(
      onTap: () => _showDetailBottomSheet(row),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Avatar with Initials
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDBEAFE),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    row.initials,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                  ),
                ),
                const SizedBox(width: 8),
                // Name & Code/Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.employeeName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [row.positionName, row.employeeCode].where((e) => e != null && e.isNotEmpty).join(' · '),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: row.statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: row.statusBorderColor),
                  ),
                  child: Text(
                    row.statusDisplayLabel,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: row.statusTextColor),
                  ),
                ),
                const SizedBox(width: 6),
                // Compact "Chi tiết" Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Text(
                    'Chi tiết',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Department & Shift info (2x2 Grid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Col 1: Phòng ban
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const Text('Phòng: ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                row.departmentName ?? '----',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Col 2: Ca làm việc
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            const Text('Ca: ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                row.shiftName ?? '----',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Col 1: Giờ dự kiến
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const Text('Dự kiến: ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                row.shiftTimeText,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Col 2: Thực tế
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            const Text('Thực tế: ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                row.actualText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: row.checkIn != null ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SECTION: ĐƠN TỪ LIÊN QUAN HÔM NAY
  // ==========================================
  Widget _buildRelatedRequestsSection() {
    final list = _relatedRequests;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đơn từ liên quan hôm nay (${list.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              InkWell(
                onTap: () {
                  // Switch to Approvals or pop
                  Navigator.pop(context);
                },
                child: const Text(
                  'Mở danh sách đơn',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Không có đơn từ nào liên quan tới ngày này.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length > 5 ? 5 : list.length,
              separatorBuilder: (_, _) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final item = list[idx];
                final name = item['employeeName'] as String;
                final initials = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join('').toUpperCase();

                return Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            item['departmentName'] ?? '----',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item['kindLabel'] as String,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item['statusBgColor'] as Color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item['statusLabel'] as String,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item['statusTextColor'] as Color),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION: TÌNH HÌNH THEO PHÒNG BAN
  // ==========================================
  Widget _buildDepartmentStatsSection(String updatedTime) {
    final list = _departmentStats;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tình hình theo phòng ban',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),

          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Chưa có dữ liệu phòng ban cho ngày này.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
            )
          else ...[
            // Header
            Row(
              children: const [
                Expanded(flex: 5, child: Text('Phòng ban', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                Expanded(flex: 4, child: Text('Đã vào ca / Tổng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                SizedBox(width: 40, child: Text('Tỷ lệ', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              ],
            ),
            const SizedBox(height: 8),

            // Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final item = list[idx];
                final name = item['name'] as String;
                final checkedIn = item['checkedIn'] as int;
                final total = item['total'] as int;
                final rate = item['rate'] as double;

                final rateColor = rate >= 90
                    ? const Color(0xFF059669)
                    : (rate >= 50 ? const Color(0xFF2563EB) : const Color(0xFFD97706));

                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: total > 0 ? (checkedIn / total).clamp(0.0, 1.0) : 0,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$checkedIn/$total',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${rate.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rateColor),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          if (updatedTime.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  'Số liệu cập nhật lúc $updatedTime',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // DETAIL BOTTOM SHEET
  // ==========================================
  void _showDetailBottomSheet(HrmMonitorRow row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: Employee name + subtitle & close button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.employeeName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [row.employeeCode, row.positionName, row.departmentName]
                                      .where((e) => e != null && e.isNotEmpty)
                                      .join(' · '),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 14),

                      // Status Badge & Date Tag
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: row.statusBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: row.statusBorderColor),
                            ),
                            child: Text(
                              row.statusDisplayLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: row.statusTextColor,
                              ),
                            ),
                          ),
                          Text(
                            _formatLongDateVn(_selectedDate),
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 2-Column Grid of 6 Cards (matching Web 1:1)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard('Ca làm', row.shiftName ?? 'Ca Hành Chính'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard('Giờ dự kiến', row.shiftTimeText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard('Giờ vào', row.checkIn ?? 'Chưa chấm'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard('Giờ ra', row.checkOut ?? 'Chưa chấm'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard('Đi trễ', row.lateMinutes > 0 ? '${row.lateMinutes} phút' : 'Không'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard('Về sớm', row.earlyLeaveMinutes > 0 ? '${row.earlyLeaveMinutes} phút' : 'Không'),
                          ),
                        ],
                      ),
                      if (row.leaveName != null || row.leaveDays > 0) ...[
                        const SizedBox(height: 10),
                        _buildMetricCard(
                          'Nghỉ phép',
                          [row.leaveName, row.leaveDays > 0 ? '${row.leaveDays} ngày' : null].where((e) => e != null).join(' · '),
                        ),
                      ],
                      const SizedBox(height: 22),

                      // Section: Đơn từ liên quan
                      Text(
                        'Đơn từ liên quan (${row.requests.length})',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (row.requests.isEmpty)
                        const Text(
                          'Không có đơn từ nào liên quan tới ngày này.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        )
                      else
                        ...row.requests.map((req) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.kindLabel,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    if (req.reasonName != null || req.label != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        req.reasonName ?? req.label ?? '',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: req.statusBgColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    req.statusLabel,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: req.statusTextColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 18),

                      // Link: Xem bảng công của tháng
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HrmHubScreen(initialView: 'timesheet'),
                            ),
                          );
                        },
                        child: const Text(
                          'Xem bảng công của tháng',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
