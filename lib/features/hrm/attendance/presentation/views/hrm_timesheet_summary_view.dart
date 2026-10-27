import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../../../../models/hrm_models.dart';
import '../../../../../models/hrm_attendance_models.dart';
import '../../../../../services/hrm_attendance_service.dart';

/// Bảng chấm công tổng hợp & Ma trận công (Timesheet Matrix - 1:1 Web Pixel-Perfect)
class HrmTimesheetSummaryView extends StatefulWidget {
  final HrmAttendanceService attendanceService;
  final List<HrmEmployeeItem> employees;
  final HrmTimesheetBoard? initialBoard;
  final VoidCallback? onRefreshData;

  const HrmTimesheetSummaryView({
    super.key,
    required this.attendanceService,
    required this.employees,
    this.initialBoard,
    this.onRefreshData,
  });

  @override
  State<HrmTimesheetSummaryView> createState() => _HrmTimesheetSummaryViewState();
}

class _HrmTimesheetSummaryViewState extends State<HrmTimesheetSummaryView> {
  HrmAttendanceService get _attendanceService => widget.attendanceService;
  List<HrmEmployeeItem> get _employees => widget.employees;

  String _timesheetMonthKey = '2026-10'; // Default to October 2026 (matching web)
  String _timesheetSearchQuery = '';
  String _timesheetFilterTab = 'ALL';
  int _timesheetCurrentPage = 1;
  int _timesheetPageSize = 10;
  int _timesheetSubTab = 0; // 0: Bảng công, 1: Dữ liệu chấm công
  final Set<String> _selectedTimesheetEmpIds = {};
  HrmTimesheetBoard? _enterpriseTimesheetBoard;
  bool _isLoadingTimesheetBoard = false;
  String _timesheetPeriodState = 'OPEN'; // 'OPEN' | 'REQUESTS_CLOSED' | 'LOCKED'

  @override
  void initState() {
    super.initState();
    _enterpriseTimesheetBoard = widget.initialBoard;
    if (_enterpriseTimesheetBoard != null && _enterpriseTimesheetBoard!.month.state.isNotEmpty) {
      _timesheetPeriodState = _enterpriseTimesheetBoard!.month.state;
    }
    if (_enterpriseTimesheetBoard == null) {
      _refreshTimesheetBoard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildTimesheetSummaryView();
  }

  String _getEmployeeInitials(String name) {
    if (name.trim().isEmpty) return 'NV';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // 5. BẢNG CÔNG TỔNG HỢP (TIMESHEET MATRIX - PIXEL-PERFECT SYNC WITH WEB)
  // ==========================================

  Future<void> _shiftTimesheetMonth(int delta) async {
    final parts = _timesheetMonthKey.split('-');
    int y = int.tryParse(parts[0]) ?? 2026;
    int m = int.tryParse(parts[1]) ?? 10;
    m += delta;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    final nextKey = '$y-${m.toString().padLeft(2, '0')}';
    setState(() {
      _timesheetMonthKey = nextKey;
      _timesheetCurrentPage = 1;
      _isLoadingTimesheetBoard = true;
    });
    try {
      final board = await _attendanceService.getTimesheetBoard(
        month: nextKey,
        self: false,
        page: 1,
        pageSize: 100,
      );
      if (mounted) {
        setState(() {
          _enterpriseTimesheetBoard = board;
          if (board != null && board.month.state.isNotEmpty) {
            _timesheetPeriodState = board.month.state;
          }
          _isLoadingTimesheetBoard = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTimesheetBoard = false);
    }
  }

  Future<void> _refreshTimesheetBoard() async {
    setState(() => _isLoadingTimesheetBoard = true);
    try {
      final board = await _attendanceService.getTimesheetBoard(
        month: _timesheetMonthKey,
        self: false,
        page: 1,
        pageSize: 100,
      );
      if (mounted) {
        setState(() {
          _enterpriseTimesheetBoard = board;
          if (board != null && board.month.state.isNotEmpty) {
            _timesheetPeriodState = board.month.state;
          }
          _isLoadingTimesheetBoard = false;
        });
      }
    } catch (e) {
      debugPrint('[HrmHubScreen] _refreshTimesheetBoard error: $e');
      if (mounted) setState(() => _isLoadingTimesheetBoard = false);
    }
  }

  String get _timesheetMonthLabel {
    final parts = _timesheetMonthKey.split('-');
    if (parts.length == 2) {
      return 'hrm_ops.timesheet.month_label'.tr(args: {'month': parts[1], 'year': parts[0]});
    }
    return _timesheetMonthKey;
  }

  int get _daysInSelectedMonth {
    final parts = _timesheetMonthKey.split('-');
    final y = int.tryParse(parts[0]) ?? 2026;
    final m = int.tryParse(parts[1]) ?? 10;
    return DateTime(y, m + 1, 0).day;
  }

  String _getDayWeekdayLabel(int day) {
    final parts = _timesheetMonthKey.split('-');
    final y = int.tryParse(parts[0]) ?? 2026;
    final m = int.tryParse(parts[1]) ?? 10;
    final dt = DateTime(y, m, day);
    switch (dt.weekday) {
      case DateTime.monday: return 'hrm_ops.timesheet.wd.mon'.tr();
      case DateTime.tuesday: return 'hrm_ops.timesheet.wd.tue'.tr();
      case DateTime.wednesday: return 'hrm_ops.timesheet.wd.wed'.tr();
      case DateTime.thursday: return 'hrm_ops.timesheet.wd.thu'.tr();
      case DateTime.friday: return 'hrm_ops.timesheet.wd.fri'.tr();
      case DateTime.saturday: return 'hrm_ops.timesheet.wd.sat'.tr();
      case DateTime.sunday: return 'hrm_ops.timesheet.wd.sun'.tr();
      default: return '';
    }
  }

  Color _getTimesheetAvatarBgColor(String code) {
    switch (code) {
      case 'NV001': return const Color(0xFFE0F2FE); // sky 100
      case 'NV002': return const Color(0xFFDCFCE7); // emerald 100
      case 'NV003': return const Color(0xFFF3E8FF); // purple 100
      case 'NV004': return const Color(0xFFFCE7F3); // pink 100
      case 'NV005': return const Color(0xFFEFF6FF); // blue 100
      case 'NV006': return const Color(0xFFFEF3C7); // amber 100
      case 'NV007': return const Color(0xFFEDE9FE); // violet 100
      case 'NV008': return const Color(0xFFCCFBF1); // teal 100
      case 'NV009': return const Color(0xFFFAE8FF); // fuchsia 100
      case 'NV010': return const Color(0xFFFFE4E6); // rose 100
      default:
        const bgs = [
          Color(0xFFE0F2FE), Color(0xFFDCFCE7), Color(0xFFF3E8FF),
          Color(0xFFFCE7F3), Color(0xFFEFF6FF), Color(0xFFFEF3C7),
        ];
        int hash = code.hashCode.abs();
        return bgs[hash % bgs.length];
    }
  }

  Color _getTimesheetAvatarTextColor(String code) {
    switch (code) {
      case 'NV001': return const Color(0xFF0284C7); // sky 600
      case 'NV002': return const Color(0xFF059669); // emerald 600
      case 'NV003': return const Color(0xFF7C3AED); // purple 600
      case 'NV004': return const Color(0xFFDB2777); // pink 600
      case 'NV005': return const Color(0xFF2563EB); // blue 600
      case 'NV006': return const Color(0xFFD97706); // amber 600
      case 'NV007': return const Color(0xFF6D28D9); // violet 600
      case 'NV008': return const Color(0xFF0D9488); // teal 600
      case 'NV009': return const Color(0xFFC026D3); // fuchsia 600
      case 'NV010': return const Color(0xFFE11D48); // rose 600
      default:
        const fgs = [
          Color(0xFF0284C7), Color(0xFF059669), Color(0xFF7C3AED),
          Color(0xFFDB2777), Color(0xFF2563EB), Color(0xFFD97706),
        ];
        int hash = code.hashCode.abs();
        return fgs[hash % fgs.length];
    }
  }

  List<HrmBoardEmployee> get _effectiveTimesheetEmployees {
    if (_enterpriseTimesheetBoard != null && _enterpriseTimesheetBoard!.employees.isNotEmpty) {
      return _enterpriseTimesheetBoard!.employees;
    }
    final daysInMonth = _daysInSelectedMonth;
    final parts = _timesheetMonthKey.split('-');
    final y = int.tryParse(parts[0]) ?? 2026;
    final m = int.tryParse(parts[1]) ?? 10;
    final now = DateTime.now();

    return _employees.map((e) {
      final days = <String, HrmBoardDay>{};
      final isFirstEmp = e.code == 'NV001';

      for (int d = 1; d <= daysInMonth; d++) {
        final dt = DateTime(y, m, d);
        final isSunday = dt.weekday == DateTime.sunday;
        final isFuture = (y > now.year) || (y == now.year && m > now.month) || (y == now.year && m == now.month && d > now.day);

        String st;
        if (isFuture) {
          st = isSunday ? 'OFF' : 'HC';
        } else if (isSunday) {
          st = 'OFF';
        } else {
          if (isFirstEmp && (d == 5 || d == 6 || d == 7 || d == 8 || d == 9 || d == 13 || d == 14)) {
            st = 'PRESENT';
          } else {
            st = 'ABSENT';
          }
        }

        days['$d'] = HrmBoardDay(
          date: '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
          kind: isSunday ? 'OFF' : 'WORK',
          status: st,
          shiftCode: isSunday ? 'OFF' : 'CA_HC',
          shiftName: isSunday ? 'hrm_ops.timesheet.day.off'.tr() : 'hrm_ops.timesheet.shift_name.office'.tr(),
          workdayUnits: (st == 'PRESENT' && !isFuture) ? 1.0 : 0.0,
          lateMinutes: (isFirstEmp && d == 5) ? 14 : 0,
        );
      }

      int absentCount = days.values.where((d) => d.status == 'ABSENT').length;
      int presentCount = days.values.where((d) => d.status == 'PRESENT').length;
      int lateDays = (isFirstEmp) ? 1 : 0;

      return HrmBoardEmployee(
        employeeId: e.id,
        employeeCode: e.code,
        employeeName: e.fullName,
        departmentName: e.department,
        positionName: e.position,
        days: days,
        totals: HrmBoardTotals(
          workdayUnits: presentCount.toDouble(),
          lateDays: lateDays,
          earlyLeaveDays: 0,
          absentDays: absentCount,
          annualLeaveDays: 0,
          abnormalDays: 0,
          otMinutes: 0,
        ),
      );
    }).toList();
  }

  List<HrmBoardEmployee> get _filteredTimesheetEmployees {
    var list = _effectiveTimesheetEmployees;
    if (_timesheetSearchQuery.trim().isNotEmpty) {
      final q = _timesheetSearchQuery.toLowerCase();
      list = list.where((e) =>
        e.employeeName.toLowerCase().contains(q) ||
        e.employeeCode.toLowerCase().contains(q) ||
        (e.departmentName?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    switch (_timesheetFilterTab) {
      case 'LATE_EARLY':
        return list.where((e) => (e.totals.lateDays + e.totals.earlyLeaveDays) > 0).toList();
      case 'ABNORMAL':
        return list.where((e) => e.totals.abnormalDays > 0).toList();
      case 'ABSENT':
        return list.where((e) => e.totals.absentDays > 0).toList();
      case 'PENDING':
        return list.where((e) => e.days.values.any((d) => d.requests.any((r) => r.status == 'PENDING'))).toList();
      default:
        return list;
    }
  }

  int _countTimesheetFilter(String key) {
    final list = _effectiveTimesheetEmployees;
    switch (key) {
      case 'LATE_EARLY':
        return list.where((e) => (e.totals.lateDays + e.totals.earlyLeaveDays) > 0).length;
      case 'ABNORMAL':
        return list.where((e) => e.totals.abnormalDays > 0).length;
      case 'ABSENT':
        return list.where((e) => e.totals.absentDays > 0).length;
      case 'PENDING':
        return list.where((e) => e.days.values.any((d) => d.requests.any((r) => r.status == 'PENDING'))).length;
      default:
        return list.length;
    }
  }

  List<HrmBoardEmployee> get _pagedTimesheetEmployees {
    final all = _filteredTimesheetEmployees;
    final start = (_timesheetCurrentPage - 1) * _timesheetPageSize;
    if (start >= all.length) return [];
    final end = (start + _timesheetPageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get _timesheetTotalPages {
    final total = _filteredTimesheetEmployees.length;
    if (total == 0) return 1;
    return (total / _timesheetPageSize).ceil();
  }

  Widget _buildTimesheetSummaryView() {
    final pagedList = _pagedTimesheetEmployees;
    final totalCount = _filteredTimesheetEmployees.length;
    final startIdx = totalCount == 0 ? 0 : (_timesheetCurrentPage - 1) * _timesheetPageSize + 1;
    final endIdx = (startIdx + pagedList.length - 1).clamp(0, totalCount);
    final daysInMonth = _daysInSelectedMonth;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Breadcrumb & Status badge (Responsive)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Icon(Icons.home_outlined, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text('›', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    SizedBox(width: 4),
                    Text('hrm_ops.timesheet.crumb.hr'.tr(), style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    SizedBox(width: 4),
                    Text('›', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'hrm_ops.timesheet.title'.tr(),
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _timesheetPeriodState == 'REQUESTS_CLOSED'
                      ? const Color(0xFFEFF6FF)
                      : (_timesheetPeriodState == 'LOCKED' ? const Color(0xFFF1F5F9) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _timesheetPeriodState == 'REQUESTS_CLOSED'
                        ? const Color(0xFFBFDBFE)
                        : (_timesheetPeriodState == 'LOCKED' ? const Color(0xFFCBD5E1) : const Color(0xFFFDE68A)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 8,
                      color: _timesheetPeriodState == 'REQUESTS_CLOSED'
                          ? const Color(0xFF2563EB)
                          : (_timesheetPeriodState == 'LOCKED' ? const Color(0xFF64748B) : const Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _timesheetPeriodState == 'REQUESTS_CLOSED'
                          ? 'hrm_ops.timesheet.period.closed'.tr()
                          : (_timesheetPeriodState == 'LOCKED' ? 'hrm_ops.timesheet.period.locked'.tr() : 'hrm_ops.timesheet.period.open'.tr()),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _timesheetPeriodState == 'REQUESTS_CLOSED'
                            ? const Color(0xFF1D4ED8)
                            : (_timesheetPeriodState == 'LOCKED' ? const Color(0xFF475569) : const Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoadingTimesheetBoard)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFFE2E8F0),
                color: Color(0xFFF59E0B),
              ),
            ),
          const SizedBox(height: 8),

          // Title & Description
          Text(
            'hrm_ops.timesheet.title'.tr(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            'hrm_ops.timesheet.subtitle'.tr(),
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // 2. Subtabs: Bảng công | Dữ liệu chấm công
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _timesheetSubTab = 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'hrm_ops.timesheet.title'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _timesheetSubTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2.5,
                      width: 70,
                      decoration: BoxDecoration(
                        color: _timesheetSubTab == 0 ? const Color(0xFFF59E0B) : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => setState(() => _timesheetSubTab = 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'hrm_ops.timesheet.tab.data'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _timesheetSubTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2.5,
                      width: 120,
                      decoration: BoxDecoration(
                        color: _timesheetSubTab == 1 ? const Color(0xFFF59E0B) : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // 3. Month Picker & Search Box
          Row(
            children: [
              // Month Selector: < 📅 Tháng 10/2026 >
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _shiftTimesheetMonth(-1),
                    ),
                    const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(
                      _timesheetMonthLabel,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _shiftTimesheetMonth(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Search field
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _timesheetSearchQuery = v;
                      _timesheetCurrentPage = 1;
                    }),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'hrm_ops.timesheet.search.hint'.tr(),
                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Action Buttons (🔒 Chốt đơn từ, 🧮 Tính công, 🔒 Chốt công, 🔓 Mở lại, 📥 Xuất CSV)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLightActionButton(icon: Icons.lock_outline_rounded, label: 'hrm_ops.timesheet.action.close_requests'.tr(), onTap: _showCloseRequestsModal),
                const SizedBox(width: 6),
                _buildLightActionButton(
                  icon: _isCalculatingTimesheet ? Icons.hourglass_top_rounded : Icons.calculate_outlined,
                  label: _isCalculatingTimesheet ? 'hrm_ops.timesheet.action.calculating'.tr() : 'hrm_ops.timesheet.action.calculate'.tr(),
                  onTap: _handleCalculateTimesheet,
                ),
                const SizedBox(width: 6),
                // Solid Orange Highlighted Action
                InkWell(
                  onTap: _showCloseTimesheetModal,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'hrm_ops.timesheet.action.close_timesheet'.tr(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildLightActionButton(icon: Icons.lock_open_rounded, label: 'hrm_ops.timesheet.action.reopen'.tr(), onTap: _showReopenTimesheetModal),
                const SizedBox(width: 6),
                _buildLightActionButton(
                  icon: Icons.file_download_outlined,
                  label: _selectedTimesheetEmpIds.isNotEmpty ? 'hrm_ops.timesheet.export_csv_count'.tr(args: {'count': _selectedTimesheetEmpIds.length}) : 'hrm_ops.timesheet.action.export_csv'.tr(),
                  onTap: _exportTimesheetCsv,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 5. Quick Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLightFilterTab('hrm_ops.timesheet.filter.all'.tr(args: {'count': _countTimesheetFilter('ALL')}), 'ALL', null),
                const SizedBox(width: 6),
                _buildLightFilterTab('hrm_ops.timesheet.filter.late_early'.tr(args: {'count': _countTimesheetFilter('LATE_EARLY')}), 'LATE_EARLY', const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                _buildLightFilterTab('hrm_ops.timesheet.filter.abnormal'.tr(args: {'count': _countTimesheetFilter('ABNORMAL')}), 'ABNORMAL', const Color(0xFFEAB308)),
                const SizedBox(width: 6),
                _buildLightFilterTab('hrm_ops.timesheet.filter.absent'.tr(args: {'count': _countTimesheetFilter('ABSENT')}), 'ABSENT', const Color(0xFFEF4444)),
                const SizedBox(width: 6),
                _buildLightFilterTab('hrm_ops.timesheet.filter.pending'.tr(args: {'count': _countTimesheetFilter('PENDING')}), 'PENDING', const Color(0xFF3B82F6)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 6. Hint Bar: 👉 Vuốt ngang để xem 31 ngày & cột tổng kết | (?) Chú thích
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.swipe_left_rounded, size: 15, color: Color(0xFFD97706)),
                  SizedBox(width: 5),
                  Text(
                    'hrm_ops.timesheet.swipe_hint'.tr(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showTimesheetLegendBottomSheet(),
                child: Text(
                  'hrm_ops.timesheet.legend_link'.tr(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 7. Matrix Data Table with Fixed Left Column and Scrollable Days
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Frozen Left Column (Checkbox + Avatar + Name + Code)
                    SizedBox(
                      width: 145,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Header
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_selectedTimesheetEmpIds.length == pagedList.length) {
                                        _selectedTimesheetEmpIds.clear();
                                      } else {
                                        _selectedTimesheetEmpIds.addAll(pagedList.map((e) => e.employeeId));
                                      }
                                    });
                                  },
                                  child: Icon(
                                    _selectedTimesheetEmpIds.length == pagedList.length && pagedList.isNotEmpty
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 16,
                                    color: _selectedTimesheetEmpIds.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'hrm_ops.timesheet.col.employee'.tr(),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        'hrm_ops.timesheet.page_headcount'.tr(args: {'count': pagedList.length}),
                                        style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Left Employee Rows
                          ...pagedList.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final emp = entry.value;
                            final isSelected = _selectedTimesheetEmpIds.contains(emp.employeeId);
                            final avatarBg = _getTimesheetAvatarBgColor(emp.employeeCode);
                            final avatarText = _getTimesheetAvatarTextColor(emp.employeeCode);
                            final initials = _getEmployeeInitials(emp.employeeName);
                            final isEven = idx % 2 == 0;

                            return Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                                border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedTimesheetEmpIds.remove(emp.employeeId);
                                        } else {
                                          _selectedTimesheetEmpIds.add(emp.employeeId);
                                        }
                                      });
                                    },
                                    child: Icon(
                                      isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      size: 15,
                                      color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: avatarBg,
                                    child: Text(
                                      initials,
                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: avatarText),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          emp.employeeName,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${emp.employeeCode} · ${emp.departmentName ?? ""}',
                                          style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Divider
                    Container(width: 1, color: const Color(0xFFE2E8F0)),

                    // Scrollable Right Area (Days 1..31 + Summary Columns)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Days Header Row
                            Container(
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              child: Row(
                                children: [
                                  // Days 1..31
                                  ...List.generate(daysInMonth, (dIdx) {
                                    final d = dIdx + 1;
                                    final weekday = _getDayWeekdayLabel(d);
                                    final isSunday = weekday == 'hrm_ops.timesheet.wd.sun'.tr();
                                    final parts = _timesheetMonthKey.split('-');
                                    final y = int.tryParse(parts[0]) ?? 2026;
                                    final m = int.tryParse(parts[1]) ?? 10;
                                    final now = DateTime.now();
                                    final isToday = (y == now.year && m == now.month && d == now.day);
                                    final isFuture = (y > now.year) || (y == now.year && m > now.month) || (y == now.year && m == now.month && d > now.day);

                                    return Container(
                                      width: 36,
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isToday ? const Color(0xFFFEF3C7).withValues(alpha: 0.5) : Colors.transparent,
                                        border: isToday ? const Border(bottom: BorderSide(color: Color(0xFFF59E0B), width: 2)) : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            weekday,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: isSunday ? FontWeight.bold : FontWeight.w500,
                                              color: isSunday
                                                  ? (isFuture ? const Color(0xFFFDA4AF) : const Color(0xFFE11D48))
                                                  : (isToday ? const Color(0xFFD97706) : (isFuture ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$d',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isSunday
                                                  ? (isFuture ? const Color(0xFFFDA4AF) : const Color(0xFFE11D48))
                                                  : (isToday ? const Color(0xFFD97706) : (isFuture ? const Color(0xFF94A3B8) : const Color(0xFF1E293B))),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                  // Summary Columns Header (Công, T/S, P, KP, !, TC)
                                  _buildSummaryHeaderCell('hrm_ops.timesheet.col.work_short'.tr(), 38, const Color(0xFF0284C7)),
                                  _buildSummaryHeaderCell('hrm_ops.timesheet.col.late_early_short'.tr(), 34, const Color(0xFFD97706)),
                                  _buildSummaryHeaderCell('P', 34, const Color(0xFF64748B)),
                                  _buildSummaryHeaderCell('hrm_ops.timesheet.col.absent_short'.tr(), 34, const Color(0xFFE11D48)),
                                  _buildSummaryHeaderCell('!', 32, const Color(0xFFE11D48)),
                                  _buildSummaryHeaderCell('hrm_ops.timesheet.col.ot_short'.tr(), 36, const Color(0xFF059669)),
                                ],
                              ),
                            ),

                            // Days Data Rows
                            ...pagedList.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final emp = entry.value;
                              final isEven = idx % 2 == 0;

                              return Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                                  border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
                                ),
                                child: Row(
                                  children: [
                                    // 31 Days cells
                                    ...List.generate(daysInMonth, (dIdx) {
                                      final d = dIdx + 1;
                                      final dayKey = '$d';
                                      final dayObj = emp.days[dayKey];
                                      final weekday = _getDayWeekdayLabel(d);
                                      final isSunday = weekday == 'hrm_ops.timesheet.wd.sun'.tr();

                                      final parts = _timesheetMonthKey.split('-');
                                      final y = int.tryParse(parts[0]) ?? 2026;
                                      final m = int.tryParse(parts[1]) ?? 10;
                                      final now = DateTime.now();
                                      final isToday = (y == now.year && m == now.month && d == now.day);
                                      final isFuture = (y > now.year) || (y == now.year && m > now.month) || (y == now.year && m == now.month && d > now.day);

                                      return InkWell(
                                        onTap: () => _showDayDetailModal(emp, d, dayObj, isFuture: isFuture),
                                        child: Container(
                                          width: 36,
                                          height: 52,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isToday
                                                ? const Color(0xFFFEF9C3).withValues(alpha: 0.6)
                                                : (isFuture ? const Color(0xFFF8FAFC).withValues(alpha: 0.5) : Colors.transparent),
                                          ),
                                          child: _buildMatrixCellText(dayObj, isSunday, isFuture),
                                        ),
                                      );
                                    }),

                                    // Summary data cells (matching web totals)
                                    _buildSummaryDataCell('${emp.totals.workdayUnits.toStringAsFixed(emp.totals.workdayUnits % 1 == 0 ? 0 : 1)}', 38, const Color(0xFF0284C7), isBold: true),
                                    _buildSummaryDataCell('${emp.totals.lateDays + emp.totals.earlyLeaveDays}', 34, (emp.totals.lateDays + emp.totals.earlyLeaveDays) > 0 ? const Color(0xFFD97706) : const Color(0xFF94A3B8)),
                                    _buildSummaryDataCell('${emp.totals.annualLeaveDays + emp.totals.paidLeaveDays}', 34, const Color(0xFF94A3B8)),
                                    _buildSummaryDataCell('${emp.totals.absentDays}', 34, emp.totals.absentDays > 0 ? const Color(0xFFE11D48) : const Color(0xFF94A3B8)),
                                    _buildSummaryDataCell('${emp.totals.abnormalDays}', 32, emp.totals.abnormalDays > 0 ? const Color(0xFFE11D48) : const Color(0xFF94A3B8)),
                                    _buildSummaryDataCell('${(emp.totals.otMinutes / 60).toStringAsFixed(0)}', 36, (emp.totals.otMinutes > 0) ? const Color(0xFF059669) : const Color(0xFF94A3B8)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Pagination Row at Bottom of Table (Responsive, completely prevents RenderFlex overflow)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'hrm_ops.timesheet.page_showing'.tr(args: {'start': startIdx, 'end': endIdx, 'total': totalCount}),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Page numbers: < [ 1 ] 2 3 4 >
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: _timesheetCurrentPage > 1 ? () => setState(() => _timesheetCurrentPage--) : null,
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Icon(Icons.chevron_left_rounded, size: 15, color: Color(0xFF475569)),
                            ),
                          ),
                          const SizedBox(width: 3),
                          ...List.generate(_timesheetTotalPages, (pIdx) {
                            final pageNum = pIdx + 1;
                            final isActive = pageNum == _timesheetCurrentPage;
                            return InkWell(
                              onTap: () => setState(() => _timesheetCurrentPage = pageNum),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFF59E0B) : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isActive ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  '$pageNum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                    color: isActive ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 3),
                          InkWell(
                            onTap: _timesheetCurrentPage < _timesheetTotalPages ? () => setState(() => _timesheetCurrentPage++) : null,
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Icon(Icons.chevron_right_rounded, size: 15, color: Color(0xFF475569)),
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
          const SizedBox(height: 12),

          // 8. Legend Box (Matching Screenshot: 0 Vắng không phép, HC Hành chính (đủ), OFF Nghỉ tuần/Lễ, P Nghỉ phép)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLegendItem('0', const Color(0xFFEF4444), 'hrm_ops.timesheet.legend_short.absent_full'.tr(), bgColor: const Color(0xFFFEE2E2)),
                  const SizedBox(width: 14),
                  _buildLegendItem('HC', const Color(0xFF0284C7), 'hrm_ops.timesheet.legend_short.hc'.tr(), bgColor: const Color(0xFFE0F2FE)),
                  const SizedBox(width: 14),
                  _buildLegendItem('OFF', const Color(0xFFEF4444), 'hrm_ops.timesheet.legend_short.off'.tr(), bgColor: const Color(0xFFFEE2E2)),
                  const SizedBox(width: 14),
                  _buildLegendItem('P', const Color(0xFF9333EA), 'hrm_ops.timesheet.legend_short.leave'.tr(), bgColor: const Color(0xFFF3E8FF)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLightActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightFilterTab(String label, String key, Color? dotColor) {
    final isActive = _timesheetFilterTab == key;
    return InkWell(
      onTap: () => setState(() {
        _timesheetFilterTab = key;
        _timesheetCurrentPage = 1;
      }),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF59E0B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeaderCell(String title, double width, Color color) {
    return Container(
      width: width,
      alignment: Alignment.center,
      child: Text(
        title,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildSummaryDataCell(String value, double width, Color color, {bool isBold = false}) {
    return Container(
      width: width,
      height: 52,
      alignment: Alignment.center,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMatrixCellText(HrmBoardDay? dayObj, bool isSunday, bool isFuture) {
    if (isFuture) {
      final st = dayObj?.status ?? '';
      final text = (isSunday || st == 'OFF')
          ? 'OFF'
          : (st == 'HC' ? 'HC' : (st.isNotEmpty ? st : 'HC'));
      return Text(
        text,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8), // Màu xám nhạt cho ngày chưa tới
        ),
      );
    }

    if (isSunday || dayObj?.status == 'OFF') {
      return const Text(
        'OFF',
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
      );
    }
    final st = dayObj?.status ?? '';
    if (st == 'HC') {
      return const Text(
        'HC',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
      );
    } else if (st == 'PRESENT') {
      return const Text(
        '8',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
      );
    } else if (st == 'ABSENT') {
      return const Text(
        '0',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
      );
    } else if (st.contains('LEAVE')) {
      return const Text(
        'P',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF9333EA)),
      );
    } else {
      return const Text(
        '0',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
      );
    }
  }

  Widget _buildLegendItem(String tag, Color tagColor, String text, {Color? bgColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: bgColor ?? const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tag,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tagColor),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  void _showTimesheetLegendBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('hrm_ops.timesheet.legend.title'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 14),
            _buildLegendDetailRow('0', const Color(0xFFEF4444), 'hrm_ops.timesheet.legend_detail.absent'.tr(), bgColor: const Color(0xFFFEE2E2)),
            const SizedBox(height: 8),
            _buildLegendDetailRow('HC', const Color(0xFF0284C7), 'hrm_ops.timesheet.legend_detail.hc'.tr(), bgColor: const Color(0xFFE0F2FE)),
            const SizedBox(height: 8),
            _buildLegendDetailRow('OFF', const Color(0xFFEF4444), 'hrm_ops.timesheet.legend_detail.off'.tr(), bgColor: const Color(0xFFFEE2E2)),
            const SizedBox(height: 8),
            _buildLegendDetailRow('P', const Color(0xFF9333EA), 'hrm_ops.timesheet.legend_detail.leave'.tr(), bgColor: const Color(0xFFF3E8FF)),
            const SizedBox(height: 8),
            _buildLegendDetailRow('hrm_ops.timesheet.legend_detail.future_tag'.tr(), const Color(0xFF94A3B8), 'hrm_ops.timesheet.legend_detail.future'.tr(), bgColor: const Color(0xFFF1F5F9)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDetailRow(String tag, Color tagColor, String desc, {Color? bgColor}) {
    return Row(
      children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor ?? const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tagColor)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
      ],
    );
  }

  bool _isCalculatingTimesheet = false;

  // ==========================================
  // TÍNH CÔNG (CALCULATE TIMESHEET - API THẬT)
  // ==========================================
  Future<void> _handleCalculateTimesheet() async {
    if (_isCalculatingTimesheet) return;
    setState(() => _isCalculatingTimesheet = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('hrm_ops.timesheet.calc.in_progress'.tr()),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final res = await _attendanceService.calculateTimesheet(month: _timesheetMonthKey);
      await _refreshTimesheetBoard();

      if (!mounted) return;
      if (res != null) {
        final notice = res.abnormal > 0
            ? 'hrm_ops.timesheet.calc.done_abnormal'.tr(args: {'count': res.count, 'abnormal': res.abnormal})
            : 'hrm_ops.timesheet.calc.done_ok'.tr(args: {'count': res.count});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notice),
            backgroundColor: res.abnormal > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('hrm_ops.timesheet.calc.failed'.tr()),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('hrm_ops.timesheet.calc.error'.tr(args: {'error': e})),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculatingTimesheet = false);
    }
  }

  // ==========================================
  // CHỐT ĐƠN TỪ (CLOSE REQUESTS - API THẬT)
  // ==========================================
  void _showCloseRequestsModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        bool isLoadingState = true;
        HrmMonthCloseState? closeState;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            if (isLoadingState) {
              _attendanceService.getTimesheetCloseState(month: _timesheetMonthKey).then((s) {
                if (dialogCtx.mounted) {
                  setModalState(() {
                    closeState = s;
                    isLoadingState = false;
                  });
                }
              }).catchError((err) {
                if (dialogCtx.mounted) {
                  setModalState(() {
                    isLoadingState = false;
                  });
                }
              });
            }

            final blockers = closeState?.blockersForRequests ?? [];
            final hasBlockers = blockers.isNotEmpty;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(22),
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Title & Close Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'hrm_ops.timesheet.close_requests.title'.tr(args: {'month': _timesheetMonthKey}),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'hrm_ops.timesheet.close_requests.desc'.tr(),
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: isSubmitting ? null : () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (isLoadingState)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFF59E0B))),
                            SizedBox(height: 10),
                            Text('hrm_ops.timesheet.close_requests.checking'.tr(), style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      )
                    else if (hasBlockers)
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 220),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'hrm_ops.timesheet.blockers'.tr(),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            ),
                            const SizedBox(height: 8),
                            Flexible(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: blockers.map((b) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '• ',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${b.message}${b.count > 0 ? " (${b.count})" : ""}',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF92400E),
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'hrm_ops.timesheet.close_requests.all_clear'.tr(),
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF166534), height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Action Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('hrm_ops.timesheet.skip'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: (hasBlockers || isLoadingState || isSubmitting)
                              ? (hasBlockers
                                  ? () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('hrm_ops.timesheet.close_requests.blocked'.tr()),
                                          backgroundColor: Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  : null)
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  final res = await _attendanceService.closeRequests(month: _timesheetMonthKey);
                                  if (!dialogCtx.mounted) return;

                                  if (res['success'] == true) {
                                    Navigator.pop(ctx);
                                    await _refreshTimesheetBoard();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('hrm_ops.timesheet.close_requests.done'.tr(args: {'month': _timesheetMonthKey})),
                                          backgroundColor: const Color(0xFF16A34A),
                                        ),
                                      );
                                    }
                                  } else {
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['message']?.toString() ?? 'hrm_ops.timesheet.close_requests.failed'.tr()),
                                          backgroundColor: const Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasBlockers ? const Color(0xFFFDE68A) : const Color(0xFFF59E0B),
                            foregroundColor: hasBlockers ? const Color(0xFFB45309) : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  'hrm_ops.timesheet.close_requests.confirm'.tr(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: hasBlockers ? const Color(0xFFB45309) : Colors.white,
                                  ),
                                ),
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

  void _showCloseTimesheetModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        bool isLoadingState = true;
        HrmMonthCloseState? closeState;
        String? loadError;
        bool isSubmitting = false;
        bool hasFetched = false;

        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            void fetchState() async {
              try {
                final state = await _attendanceService.getTimesheetCloseState(month: _timesheetMonthKey);
                setModalState(() {
                  closeState = state;
                  isLoadingState = false;
                  loadError = state == null ? 'hrm_ops.timesheet.close.load_error'.tr() : null;
                });
              } catch (e) {
                setModalState(() {
                  isLoadingState = false;
                  loadError = 'hrm_ops.timesheet.close.load_conn_error'.tr(args: {'error': e});
                });
              }
            }

            if (!hasFetched) {
              hasFetched = true;
              fetchState();
            }

            final blockers = closeState?.blockersForLock ?? [];
            final hasBlockers = blockers.isNotEmpty;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'hrm_ops.timesheet.close.title'.tr(args: {'month': _timesheetMonthKey}),
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'hrm_ops.timesheet.close.desc'.tr(),
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: isSubmitting ? null : () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Loading or Content
                      if (isLoadingState)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFD97706)),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'hrm_ops.timesheet.close.checking'.tr(),
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (loadError != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(loadError!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                              ),
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    isLoadingState = true;
                                    loadError = null;
                                  });
                                  fetchState();
                                },
                                child: Text('common.retry'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      else if (hasBlockers)
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 250),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'hrm_ops.timesheet.blockers'.tr(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: blockers.map((b) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  '• ',
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    '${b.message}${b.count > 0 ? " (${b.count})" : ""}',
                                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (b.items.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 12, top: 4),
                                                child: Column(
                                                  children: b.items.map((item) {
                                                    final desc = '${item.employeeCode.isNotEmpty ? item.employeeCode : ""} ${item.employeeName.isNotEmpty ? "- ${item.employeeName}" : ""} ${item.date.isNotEmpty ? "- ${item.date}" : ""}: ${item.reason}'.trim();
                                                    return Padding(
                                                      padding: const EdgeInsets.only(bottom: 4),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              desc,
                                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.3),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          InkWell(
                                                            onTap: () {
                                                              Navigator.pop(ctx);
                                                              setState(() {
                                                                _timesheetSearchQuery = item.employeeCode.isNotEmpty
                                                                    ? item.employeeCode
                                                                    : item.employeeName;
                                                              });
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text('hrm_ops.timesheet.close.filter_to'.tr(args: {'code': item.employeeCode, 'name': item.employeeName, 'reason': item.reason})),
                                                                  backgroundColor: const Color(0xFFD97706),
                                                                ),
                                                              );
                                                            },
                                                            child: Text(
                                                              'hrm_ops.timesheet.close.open_cell'.tr(),
                                                              style: TextStyle(
                                                                fontSize: 11.5,
                                                                fontWeight: FontWeight.w600,
                                                                color: Color(0xFF0F172A),
                                                                decoration: TextDecoration.underline,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'hrm_ops.timesheet.close.all_clear'.tr(),
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF166534), height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('hrm_ops.timesheet.skip'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: (isLoadingState || isSubmitting)
                                ? null
                                : hasBlockers
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('hrm_ops.timesheet.close.blocked'.tr()),
                                            backgroundColor: Color(0xFFDC2626),
                                          ),
                                        );
                                      }
                                    : () async {
                                        setModalState(() => isSubmitting = true);
                                        final res = await _attendanceService.closeTimesheet(month: _timesheetMonthKey);
                                        if (res['success'] == true) {
                                          await _refreshTimesheetBoard();
                                          if (ctx.mounted) Navigator.pop(ctx);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('hrm_ops.timesheet.close.done'.tr(args: {'month': _timesheetMonthKey})),
                                                backgroundColor: const Color(0xFF16A34A),
                                              ),
                                            );
                                          }
                                        } else {
                                          setModalState(() => isSubmitting = false);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(res['message']?.toString() ?? 'hrm_ops.timesheet.close.failed'.tr()),
                                                backgroundColor: const Color(0xFFDC2626),
                                              ),
                                            );
                                          }
                                        }
                                      },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasBlockers ? const Color(0xFFFDE68A) : const Color(0xFFF59E0B),
                              foregroundColor: hasBlockers ? const Color(0xFFB45309) : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    'hrm_ops.timesheet.close.confirm'.tr(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: hasBlockers ? const Color(0xFFB45309) : Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReopenTimesheetModal() {
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'hrm_ops.timesheet.reopen.title'.tr(args: {'month': _timesheetMonthKey}),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'hrm_ops.timesheet.reopen.desc'.tr(),
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: isSubmitting ? null : () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: 'hrm_ops.timesheet.reopen.reason_label'.tr(),
                    hintText: 'hrm_ops.timesheet.reopen.reason_hint'.tr(),
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('hrm_ops.timesheet.skip'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              final res = await _attendanceService.reopenTimesheet(
                                month: _timesheetMonthKey,
                                reason: reasonCtrl.text.trim(),
                              );
                              if (res['success'] == true) {
                                await _refreshTimesheetBoard();
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('hrm_ops.timesheet.reopen.done'.tr(args: {'month': _timesheetMonthKey})),
                                      backgroundColor: const Color(0xFF16A34A),
                                    ),
                                  );
                                }
                              } else {
                                setModalState(() => isSubmitting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['message']?.toString() ?? 'hrm_ops.timesheet.reopen.failed'.tr()),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'hrm_ops.timesheet.reopen.confirm'.tr(),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // XUẤT CSV BẢNG CÔNG (ĐỒNG BỘ CHUẨN WEB ENTERPRISE PLATFORM)
  // ==========================================
  Future<void> _exportTimesheetCsv() async {
    final chosen = _selectedTimesheetEmpIds.isNotEmpty
        ? _effectiveTimesheetEmployees.where((e) => _selectedTimesheetEmpIds.contains(e.employeeId)).toList()
        : _filteredTimesheetEmployees;

    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('hrm_ops.timesheet.csv.no_data'.tr()),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final daysInMonth = _daysInSelectedMonth;
    final parts = _timesheetMonthKey.split('-');
    final y = int.tryParse(parts[0]) ?? 2026;
    final m = int.tryParse(parts[1]) ?? 10;
    final now = DateTime.now();

    // Helper to safely format CSV cells with formula injection protection
    String csvCell(dynamic value) {
      if (value == null) return '""';
      String text = value.toString();
      if (text.startsWith('=') || text.startsWith('+') || text.startsWith('-') || text.startsWith('@') || text.startsWith('\t') || text.startsWith('\r')) {
        text = "'$text";
      }
      return '"${text.replaceAll('"', '""')}"';
    }

    // 1. Header row matching web: Mã NV, Họ tên, Đơn vị, [01/10/2026 ... 31/10/2026], [BOARD_TOTAL_COLUMNS]
    final headers = <String>[
      'hrm_ops.timesheet.csv.h.code'.tr(),
      'hrm_ops.timesheet.csv.h.name'.tr(),
      'hrm_ops.timesheet.csv.h.unit'.tr(),
    ];

    for (int d = 1; d <= daysInMonth; d++) {
      final dayStr = d.toString().padLeft(2, '0');
      final monthStr = m.toString().padLeft(2, '0');
      headers.add('$dayStr/$monthStr/$y');
    }

    headers.addAll([
      'hrm_ops.timesheet.csv.h.work'.tr(),
      'hrm_ops.timesheet.csv.h.late'.tr(),
      'hrm_ops.timesheet.csv.h.early'.tr(),
      'hrm_ops.timesheet.csv.h.abnormal'.tr(),
      'hrm_ops.timesheet.csv.h.absent'.tr(),
      'hrm_ops.timesheet.csv.h.annual'.tr(),
      'hrm_ops.timesheet.csv.h.paid'.tr(),
      'hrm_ops.timesheet.csv.h.unpaid'.tr(),
      'hrm_ops.timesheet.csv.h.trip'.tr(),
      'OT',
    ]);

    final rows = <List<String>>[headers];

    // 2. Data rows
    for (final emp in chosen) {
      final row = <String>[
        emp.employeeCode,
        emp.employeeName,
        emp.departmentName ?? '',
      ];

      // Day columns 1..daysInMonth
      for (int d = 1; d <= daysInMonth; d++) {
        final dayStr = '$d';
        final dateKey = '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        final dayObj = emp.days[dayStr] ?? emp.days[dateKey];
        final isSunday = DateTime(y, m, d).weekday == DateTime.sunday;
        final isFuture = (y > now.year) || (y == now.year && m > now.month) || (y == now.year && m == now.month && d > now.day);

        String cellVal = '';
        if (dayObj != null) {
          final st = dayObj.status;
          if (isFuture) {
            cellVal = (isSunday || st == 'OFF') ? 'OFF' : (st.isNotEmpty ? st : 'HC');
          } else if (isSunday || st == 'OFF') {
            cellVal = 'OFF';
          } else if (st == 'PRESENT') {
            cellVal = dayObj.workdayUnits > 0
                ? (dayObj.workdayUnits % 1 == 0 ? dayObj.workdayUnits.toInt().toString() : dayObj.workdayUnits.toString())
                : '8';
          } else if (st == 'ABSENT') {
            cellVal = '0';
          } else if (st == 'ABNORMAL') {
            cellVal = '!';
          } else if (st == 'ANNUAL_LEAVE') {
            cellVal = 'PN';
          } else if (st == 'PAID_LEAVE') {
            cellVal = 'CP';
          } else if (st == 'UNPAID_LEAVE') {
            cellVal = 'KL';
          } else if (st == 'TRIP') {
            cellVal = 'CT';
          } else if (st == 'HC') {
            cellVal = 'HC';
          } else {
            cellVal = dayObj.workdayUnits > 0
                ? (dayObj.workdayUnits % 1 == 0 ? dayObj.workdayUnits.toInt().toString() : dayObj.workdayUnits.toString())
                : (st.isNotEmpty ? st : '0');
          }
        } else {
          cellVal = isSunday ? 'OFF' : (isFuture ? 'HC' : '0');
        }
        row.add(cellVal);
      }

      // Totals columns matching web BOARD_TOTAL_COLUMNS
      final t = emp.totals;
      row.add(t.workdayUnits % 1 == 0 ? t.workdayUnits.toInt().toString() : t.workdayUnits.toString());
      row.add(t.lateDays > 0 ? 'hrm_ops.timesheet.csv.late'.tr(args: {'days': t.lateDays, 'minutes': t.lateMinutes}) : '0');
      row.add(t.earlyLeaveDays > 0 ? 'hrm_ops.timesheet.csv.early'.tr(args: {'days': t.earlyLeaveDays, 'minutes': t.earlyLeaveMinutes}) : '0');
      row.add(t.abnormalDays % 1 == 0 ? t.abnormalDays.toInt().toString() : t.abnormalDays.toString());
      row.add(t.absentDays % 1 == 0 ? t.absentDays.toInt().toString() : t.absentDays.toString());
      row.add(t.annualLeaveDays % 1 == 0 ? t.annualLeaveDays.toInt().toString() : t.annualLeaveDays.toString());
      row.add(t.paidLeaveDays % 1 == 0 ? t.paidLeaveDays.toInt().toString() : t.paidLeaveDays.toString());
      row.add(t.unpaidLeaveDays % 1 == 0 ? t.unpaidLeaveDays.toInt().toString() : t.unpaidLeaveDays.toString());
      row.add(t.tripDays % 1 == 0 ? t.tripDays.toInt().toString() : t.tripDays.toString());
      row.add(t.otMinutes > 0 ? '${(t.otMinutes / 60).toStringAsFixed(1)}h (${t.otMinutes}p)' : '0');

      rows.add(row);
    }

    // 3. Assemble CSV string with UTF-8 BOM
    final csvContent = '\uFEFF${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}';
    final bytes = Uint8List.fromList(utf8.encode(csvContent));
    final fileName = 'bang-cong-$_timesheetMonthKey.csv';

    String? savedFilePath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      savedFilePath = file.path;
    } catch (e) {
      debugPrint('[HrmHubScreen] File write error: $e');
    }

    // 4. Trigger system native share/download sheet
    try {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      debugPrint('[HrmHubScreen] Printing.sharePdf error: $e');
    }

    // 5. Show Export Information & Action Bottom Sheet
    if (!mounted) return;
    _showCsvExportedBottomSheet(
      fileName: fileName,
      fileSizeKb: (bytes.length / 1024).toStringAsFixed(1),
      employeeCount: chosen.length,
      savedPath: savedFilePath,
      csvContent: csvContent,
      bytes: bytes,
    );
  }

  void _showCsvExportedBottomSheet({
    required String fileName,
    required String fileSizeKb,
    required int employeeCount,
    required String? savedPath,
    required String csvContent,
    required Uint8List bytes,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'hrm_ops.timesheet.csv.done_title'.tr(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'hrm_ops.timesheet.csv.done_subtitle'.tr(args: {'period': _timesheetMonthLabel, 'count': employeeCount}),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildCsvDetailRow('hrm_ops.timesheet.csv.file_name'.tr(), fileName, isBold: true),
                  const SizedBox(height: 8),
                  _buildCsvDetailRow('hrm_ops.timesheet.csv.size'.tr(), '$fileSizeKb KB'),
                  const SizedBox(height: 8),
                  _buildCsvDetailRow('hrm_ops.timesheet.csv.employees'.tr(), 'hrm_ops.timesheet.csv.employee_count'.tr(args: {'count': employeeCount})),
                  const SizedBox(height: 8),
                  _buildCsvDetailRow('hrm_ops.timesheet.csv.encoding'.tr(), 'hrm_ops.timesheet.csv.encoding_val'.tr()),
                  if (savedPath != null) ...[
                    const SizedBox(height: 8),
                    _buildCsvDetailRow('hrm_ops.timesheet.csv.saved_at'.tr(), savedPath, isSmall: true),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: csvContent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('hrm_ops.timesheet.csv.copied'.tr()),
                          backgroundColor: Color(0xFF16A34A),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text('hrm_ops.timesheet.csv.copy'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Printing.sharePdf(bytes: bytes, filename: fileName);
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: Text('hrm_ops.timesheet.csv.save_share'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('common.close'.tr(), style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCsvDetailRow(String label, String value, {bool isBold = false, bool isSmall = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              color: const Color(0xFF0F172A),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showDayDetailModal(HrmBoardEmployee emp, int dayNumber, HrmBoardDay? dayObj, {bool isFuture = false}) {
    final parts = _timesheetMonthKey.split('-');
    final weekday = _getDayWeekdayLabel(dayNumber);
    final dateStr = 'hrm_ops.timesheet.day.date_line'.tr(args: {'weekday': weekday, 'date': '${dayNumber.toString().padLeft(2, '0')}/${parts[1]}/${parts[0]}'});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.employeeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('${emp.employeeCode} · $dateStr', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFE2E8F0)),

            // Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('hrm_ops.timesheet.day.status_label'.tr(), style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFuture
                        ? const Color(0xFFF1F5F9)
                        : ((dayObj?.status == 'PRESENT' || dayObj?.status == 'HC')
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isFuture
                          ? const Color(0xFFCBD5E1)
                          : ((dayObj?.status == 'PRESENT' || dayObj?.status == 'HC')
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFECACA)),
                    ),
                  ),
                  child: Text(
                    isFuture
                        ? (dayObj?.status == 'OFF' ? 'hrm_ops.timesheet.day.future_off'.tr() : 'hrm_ops.timesheet.day.future_hc'.tr())
                        : (dayObj?.status == 'HC'
                            ? 'hrm_ops.timesheet.day.hc_full'.tr()
                            : (dayObj?.status == 'PRESENT'
                                ? 'hrm_ops.timesheet.day.full_work'.tr()
                                : (dayObj?.status == 'OFF' ? 'hrm_ops.timesheet.day.off'.tr() : 'hrm_ops.timesheet.day.absent_nopunch'.tr()))),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isFuture
                          ? const Color(0xFF64748B)
                          : ((dayObj?.status == 'PRESENT' || dayObj?.status == 'HC')
                              ? const Color(0xFF15803D)
                              : const Color(0xFFDC2626)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Shift
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('hrm_ops.timesheet.day.shift_label'.tr(), style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Text(dayObj?.shiftName ?? 'hrm_ops.timesheet.day.default_shift'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 10),

            // Punch In/Out
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('hrm_ops.timesheet.day.punch_label'.tr(), style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Text(
                  dayObj?.checkIn != null ? 'hrm_ops.timesheet.day.punch'.tr(args: {'in': dayObj!.checkIn, 'out': dayObj.checkOut ?? '--:--'}) : 'hrm_ops.timesheet.day.no_punch'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            if (dayObj != null && dayObj.lateMinutes > 0) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('hrm_ops.timesheet.day.late_label'.tr(), style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                  Text('hrm_ops.timesheet.day.late_minutes'.tr(args: {'minutes': dayObj.lateMinutes}), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
