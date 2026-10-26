import 'package:flutter/material.dart';
import '../../../models/hrm_attendance_models.dart';

String _formatTime(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '--:--';
  final dt = DateTime.tryParse(isoString);
  if (dt == null) return '--:--';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

String _formatDate(String isoString) {
  final dt = DateTime.tryParse(isoString);
  if (dt == null) return isoString;
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

class AttendanceHistoryView extends StatefulWidget {
  final List<AttendanceRecord> history;
  final HrmTimesheetBoard? timesheetBoard;
  final bool isLoadingTimesheet;
  final String selectedMonth;
  final List<String> availableMonths;
  final Function(String month) onMonthChanged;
  final VoidCallback onRefreshTimesheet;
  final Function(int day, String dateStr, AttendanceRecord? record, TimesheetCell? boardCell, String weekdayStr) onDaySelected;
  final Function(AttendanceRecord item) onExplainItem;

  const AttendanceHistoryView({
    super.key,
    required this.history,
    required this.timesheetBoard,
    required this.isLoadingTimesheet,
    required this.selectedMonth,
    required this.availableMonths,
    required this.onMonthChanged,
    required this.onRefreshTimesheet,
    required this.onDaySelected,
    required this.onExplainItem,
  });

  @override
  State<AttendanceHistoryView> createState() => _AttendanceHistoryViewState();
}

class _AttendanceHistoryViewState extends State<AttendanceHistoryView> {
  int _historyViewMode = 0;
  int _matrixSubTab = 0;
  String _historyFilter = 'ALL';

  List<AttendanceRecord> get _filteredHistory {
    if (_historyFilter == 'ALL') return widget.history;
    return widget.history.where((r) => r.status == _historyFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _buildHistoryTab();
  }
  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card: Bảng chấm công ma trận cá nhân theo tháng
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.grid_view_rounded, size: 20, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bảng chấm công ma trận cá nhân theo tháng',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Dữ liệu công ghi nhận theo từng ngày trong tháng. Nhấp vào ô bất kỳ để xem chi tiết giờ vào/ra.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Refresh Button
                    InkWell(
                      onTap: widget.isLoadingTimesheet ? null : widget.onRefreshTimesheet,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: widget.isLoadingTimesheet
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF4F46E5)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Controls: Mode Switcher & Month Picker
                Row(
                  children: [
                    // Mode Switcher (Bảng công ma trận vs Nhật ký quẹt thẻ)
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _historyViewMode = 0),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _historyViewMode == 0 ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _historyViewMode == 0
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.grid_view_rounded,
                                        size: 13,
                                        color: _historyViewMode == 0 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Ma trận',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: _historyViewMode == 0 ? FontWeight.bold : FontWeight.w500,
                                          color: _historyViewMode == 0 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _historyViewMode = 1),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _historyViewMode == 1 ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _historyViewMode == 1
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.history_rounded,
                                        size: 14,
                                        color: _historyViewMode == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Nhật ký',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: _historyViewMode == 1 ? FontWeight.bold : FontWeight.w500,
                                          color: _historyViewMode == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Month Picker Dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: widget.selectedMonth,
                            isExpanded: true,
                            menuMaxHeight: 280,
                            borderRadius: BorderRadius.circular(10),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            items: widget.availableMonths.map((m) {
                              return DropdownMenuItem(
                                value: m,
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(m, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                widget.onMonthChanged(val);

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
          const SizedBox(height: 14),

          // 2. Body based on View Mode
          if (_historyViewMode == 0)
            _buildMatrixViewMode()
          else
            _buildLogsViewMode(),
        ],
      ),
    );
  }

  // ==========================================
  // MODE 0: BẢNG CÔNG MA TRẬN VIEW
  // ==========================================
  Widget _buildMatrixViewMode() {
    // Parse Year and Month from widget.selectedMonth (e.g. "Tháng 10/2026")
    final parts = widget.selectedMonth.split('/');
    final year = int.tryParse(parts.length > 1 ? parts[1].trim() : '2026') ?? 2026;
    final monthStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    final month = int.tryParse(monthStr) ?? 10;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    // Map existing history records by date "YYYY-MM-DD"
    final monthPrefix = '$year-${month.toString().padLeft(2, '0')}';
    final Map<int, AttendanceRecord> dayRecordMap = {};
    for (var r in widget.history) {
      if (r.workDate.startsWith(monthPrefix)) {
        final d = int.tryParse(r.workDate.substring(8, 10));
        if (d != null) {
          dayRecordMap[d] = r;
        }
      }
    }

    final MonthlyTimesheetRow? myRow = widget.timesheetBoard?.myEmployee != null
        ? MonthlyTimesheetRow.fromBoardEmployee(widget.timesheetBoard!.myEmployee!, widget.timesheetBoard!.myEmployee?.standard)
        : null;
    final Map<int, TimesheetCell> boardCellMap = myRow?.cells ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isLoadingTimesheet)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Color(0xFFEEF2FF),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            ),
          ),

        // Sub-tabs: [Bảng chấm công] vs [Chi tiết bảng chấm công]
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(width: 1.5, color: Color(0xFFE2E8F0))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _matrixSubTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _matrixSubTab == 0 ? const Color(0xFFDC2626) : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 15,
                          color: _matrixSubTab == 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Bảng chấm công',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _matrixSubTab == 0 ? FontWeight.bold : FontWeight.w500,
                            color: _matrixSubTab == 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _matrixSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _matrixSubTab == 1 ? const Color(0xFFDC2626) : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 15,
                          color: _matrixSubTab == 1 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Chi tiết bảng chấm công',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _matrixSubTab == 1 ? FontWeight.bold : FontWeight.w500,
                            color: _matrixSubTab == 1 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.timesheetBoard?.month != null
                      ? 'Kỳ: ${widget.timesheetBoard!.month.month}'
                      : 'Hiển thị 1 / 1 bản ghi',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_matrixSubTab == 0) ...[
          // Sub-Tab 0: Interactive Scrollable Matrix Table
          _buildMatrixTable(year, month, daysInMonth, dayRecordMap, myRow, boardCellMap),
          const SizedBox(height: 14),

          // Legend Box
          _buildMatrixLegend(),
        ] else ...[
          // Sub-Tab 1: Monthly Detailed KPI Breakdown
          _buildMatrixDetailBreakdown(year, month, daysInMonth, dayRecordMap, myRow, boardCellMap),
        ],
      ],
    );
  }

  // Matrix Table Component
  Widget _buildMatrixTable(
    int year,
    int month,
    int daysInMonth,
    Map<int, AttendanceRecord> dayRecordMap,
    MonthlyTimesheetRow? myRow,
    Map<int, TimesheetCell> boardCellMap,
  ) {
    final weekdaysShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee Info Header Row (Mobile Compact Card)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'STT 1',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    myRow?.employeeCode.isNotEmpty == true ? myRow!.employeeCode : 'ME (NV-001)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        myRow?.employeeName.isNotEmpty == true ? myRow!.employeeName : 'Lịch sử chấm công của tôi',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        myRow != null && (myRow.departmentName.isNotEmpty || myRow.positionName.isNotEmpty)
                            ? '${myRow.departmentName.isNotEmpty ? myRow.departmentName : "Ban Điều hành"} • ${myRow.positionName.isNotEmpty ? myRow.positionName : "Quản trị viên"}'
                            : 'Ban Điều hành • Quản trị viên',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Scrollable Calendar Matrix
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day of Week Header Row (T2, T3, T4, T5, T6, T7, CN)
                Row(
                  children: List.generate(daysInMonth, (index) {
                    final day = index + 1;
                    final dt = DateTime(year, month, day);
                    final weekday = dt.weekday; // 1=Mon, 7=Sun
                    final isSunday = weekday == 7;
                    final isSaturday = weekday == 6;

                    return Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSunday ? const Color(0xFFFEF2F2) : (isSaturday ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC)),
                        border: Border(
                          right: const BorderSide(color: Color(0xFFE2E8F0)),
                          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        weekdaysShort[weekday - 1],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSunday ? const Color(0xFFDC2626) : const Color(0xFF475569),
                        ),
                      ),
                    );
                  }),
                ),

                // Day Number Header Row (01, 02, 03... 31)
                Row(
                  children: List.generate(daysInMonth, (index) {
                    final day = index + 1;
                    final dt = DateTime(year, month, day);
                    final isSunday = dt.weekday == 7;
                    final isToday = day == DateTime.now().day && month == DateTime.now().month && year == DateTime.now().year;

                    return Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFFEFF6FF)
                            : (isSunday ? const Color(0xFFFEF2F2) : const Color(0xFFFFFFFF)),
                        border: Border(
                          right: const BorderSide(color: Color(0xFFE2E8F0)),
                          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        day.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                          color: isToday ? const Color(0xFF2563EB) : (isSunday ? const Color(0xFFDC2626) : const Color(0xFF334155)),
                        ),
                      ),
                    );
                  }),
                ),

                // Data Cells Row (CC, Trễ, BT, P, KL, -)
                Row(
                  children: List.generate(daysInMonth, (index) {
                    final day = index + 1;
                    final dt = DateTime(year, month, day);
                    final isSunday = dt.weekday == 7;
                    final record = dayRecordMap[day];
                    final boardCell = boardCellMap[day];
                    final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                    final weekdayStr = weekdaysShort[dt.weekday - 1];

                    return InkWell(
                      onTap: () => widget.onDaySelected(day, dateStr, record, boardCell, weekdayStr),
                      child: Container(
                        width: 44,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSunday ? const Color(0xFFFFF7ED).withValues(alpha: 0.3) : Colors.white,
                          border: const Border(
                            right: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: _buildMatrixCellBadgeForBoard(boardCell, record),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Matrix Cell Badge Helper for TimesheetCell or fallback to AttendanceRecord
  Widget _buildMatrixCellBadgeForBoard(TimesheetCell? cell, AttendanceRecord? record) {
    if (cell != null) {
      if (cell.isLeave) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Text(
            cell.shiftCode.isNotEmpty ? cell.shiftCode : 'P',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
          ),
        );
      }
      if (cell.isLate) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Text(
            'Trễ',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
          ),
        );
      }
      if (cell.isAbnormal || cell.status == 'ABSENT' || cell.status == 'ABNORMAL') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: const Text(
            'BT',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
          ),
        );
      }
      if (cell.workUnits > 0 || (cell.firstIn != null && cell.firstIn!.isNotEmpty)) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Text(
            cell.workUnits == 1.0 ? 'CC' : (cell.workUnits > 0 ? '${cell.workUnits}' : 'CC'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
          ),
        );
      }
      if (cell.status == 'OFF') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'OFF',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
          ),
        );
      }
      if (cell.status == 'FUTURE' || cell.status == 'NO_SCHEDULE') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '—',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
          ),
        );
      }
    }

    return _buildMatrixCellBadge(record);
  }

  // Matrix Cell Badge Helper
  Widget _buildMatrixCellBadge(AttendanceRecord? record) {
    if (record == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '—',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
        ),
      );
    }

    if (record.status == 'VALID') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Text(
          'CC',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
        ),
      );
    } else if (record.status == 'LATE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Text(
          'Trễ',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
        ),
      );
    } else if (record.status == 'ABNORMAL' || record.status == 'ABSENT') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Text(
          'BT',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
        ),
      );
    } else if (record.status == 'APPROVED_CORRECTION') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: const Text(
          'CC',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
        ),
      );
    } else if (record.status == 'LEAVE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'P',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '—',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
      ),
    );
  }

  // Legend Component (Matching Web Footer)
  Widget _buildMatrixLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              const Text(
                'Ký hiệu chấm công:',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              Text(
                'Kỳ công: $widget.selectedMonth • Nhân sự: Tôi',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLegendChip('CC', 'Có chấm công', const Color(0xFFECFDF5), const Color(0xFF059669), const Color(0xFFA7F3D0)),
              _buildLegendChip('Trễ', 'Đi trễ', const Color(0xFFFEF3C7), const Color(0xFFD97706), const Color(0xFFFDE68A)),
              _buildLegendChip('BT', 'Bất thường / Thiếu quẹt', const Color(0xFFFEE2E2), const Color(0xFFDC2626), const Color(0xFFFECACA)),
              _buildLegendChip('P', 'Nghỉ phép', const Color(0xFFF3E8FF), const Color(0xFF7C3AED), const Color(0xFFDDD6FE)),
              _buildLegendChip('OFF', 'Ngày nghỉ tuần', const Color(0xFFF1F5F9), const Color(0xFF475569), const Color(0xFFCBD5E1)),
              _buildLegendChip('—', 'Chưa có dữ liệu', const Color(0xFFF8FAFC), const Color(0xFF94A3B8), const Color(0xFFE2E8F0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendChip(String code, String label, Color bg, Color text, Color border) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
          child: Text(
            code,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: text),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  // Sub-Tab 1: Monthly Detailed Breakdown Component
  Widget _buildMatrixDetailBreakdown(
    int year,
    int month,
    int daysInMonth,
    Map<int, AttendanceRecord> dayRecordMap,
    MonthlyTimesheetRow? myRow,
    Map<int, TimesheetCell> boardCellMap,
  ) {
    final summary = myRow?.summary;

    int validDays = 0;
    int lateDays = 0;
    int abnormalDays = 0;
    int totalWorkedMinutes = 0;
    int totalLateMinutes = 0;

    for (var r in dayRecordMap.values) {
      if (r.status == 'VALID' || r.status == 'APPROVED_CORRECTION') validDays++;
      if (r.status == 'LATE') {
        lateDays++;
        totalLateMinutes += r.lateMinutes;
      }
      if (r.status == 'ABNORMAL') abnormalDays++;
      totalWorkedMinutes += r.workedMinutes;
    }

    final standardDays = summary?.standardWorkDays ?? 22.0;
    final actualWorkDays = summary?.actualWorkDays ?? (validDays + lateDays).toDouble();
    final lateCount = summary?.lateDays ?? lateDays;
    final lateMins = summary?.lateMinutes ?? totalLateMinutes;
    final earlyCount = summary?.earlyDays ?? 0;
    final earlyMins = summary?.earlyMinutes ?? 0;
    final leaveDays = summary?.leaveDays ?? 0.0;
    final absentCount = summary?.absentDays ?? 0;
    final otHours = summary?.otHours ?? 0.0;
    final abnormalCount = summary?.abnormalDays ?? abnormalDays;
    final tripCount = summary?.tripDays ?? 0;
    final unscheduledCount = summary?.unscheduledDays ?? 0;
    final rate = summary != null
        ? summary.completionRate.toStringAsFixed(1)
        : ((actualWorkDays / (standardDays > 0 ? standardDays : 1)) * 100).clamp(0, 100).toStringAsFixed(1);
    final rateDouble = double.tryParse(rate) ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Summary Cards (100% Synced with Web MyKpiStrip)
        // Row 1: Tổng công thực tế & Đi trễ
        Row(
          children: [
            Expanded(
              child: _buildWebKpiCard(
                label: 'Tổng công thực tế',
                value: actualWorkDays.toStringAsFixed(1),
                unit: '/ ${standardDays % 1 == 0 ? standardDays.toInt() : standardDays.toStringAsFixed(1)}',
                hint: summary?.standardHint ?? 'Động theo ngày công của tháng',
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFF059669),
                iconBg: const Color(0xFFECFDF5),
                progress: rateDouble,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWebKpiCard(
                label: 'Đi trễ',
                value: '$lateCount',
                unit: 'lần',
                hint: lateMins > 0 ? '$lateMins phút' : null,
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFF7ED),
                isAlert: lateCount > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: Về sớm & Nghỉ phép (P)
        Row(
          children: [
            Expanded(
              child: _buildWebKpiCard(
                label: 'Về sớm',
                value: '$earlyCount',
                unit: 'lần',
                hint: earlyMins > 0 ? '$earlyMins phút' : null,
                icon: Icons.history_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFF5F3FF),
                isAlert: earlyCount > 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWebKpiCard(
                label: 'Nghỉ phép (P)',
                value: leaveDays % 1 == 0 ? '${leaveDays.toInt()}' : leaveDays.toStringAsFixed(1),
                unit: 'ngày',
                icon: Icons.date_range_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 3: Nghỉ không phép (KP) & Tăng ca (TC)
        Row(
          children: [
            Expanded(
              child: _buildWebKpiCard(
                label: 'Nghỉ không phép (KP)',
                value: '$absentCount',
                unit: 'ngày',
                icon: Icons.alarm_off_rounded,
                iconColor: const Color(0xFFDC2626),
                iconBg: const Color(0xFFFEF2F2),
                isAlert: absentCount > 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWebKpiCard(
                label: 'Tăng ca (TC)',
                value: otHours.toStringAsFixed(1),
                unit: 'giờ',
                hint: 'Đã duyệt',
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF0284C7),
                iconBg: const Color(0xFFF0F9FF),
              ),
            ),
          ],
        ),

        // Extras Chips (Matching Web extras: Bất thường, Công tác, Chưa có ca)
        if (abnormalCount > 0 || tripCount > 0 || unscheduledCount > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (abnormalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Bất thường: ',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$abnormalCount ngày',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              if (tripCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Công tác (CT): ',
                        style: TextStyle(fontSize: 11, color: Color(0xFF4338CA), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$tripCount ngày',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF4338CA), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              if (unscheduledCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Chưa có ca: ',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$unscheduledCount ngày',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),

        // List of days with records
        Container(
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
                  const Text(
                    'Chi tiết các ngày đã ghi nhận công:',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '${boardCellMap.isNotEmpty ? boardCellMap.length : dayRecordMap.length} ngày',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (boardCellMap.isEmpty && dayRecordMap.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có dữ liệu chấm công cho tháng này.', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                )
              else
                ...List.generate(daysInMonth, (index) {
                  final day = daysInMonth - index;
                  final r = dayRecordMap[day];
                  final cell = boardCellMap[day];

                  // Only render if cell or record has meaningful activity
                  final hasActivity = (cell != null &&
                          (cell.workUnits > 0 ||
                              cell.isLate ||
                              cell.isLeave ||
                              cell.isAbnormal ||
                              (cell.firstIn != null && cell.firstIn!.isNotEmpty))) ||
                      (r != null);

                  if (!hasActivity) return const SizedBox.shrink();

                  final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final weekday = DateTime(year, month, day).weekday;
                  final weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][weekday - 1];

                  final inTime = cell?.firstIn?.isNotEmpty == true ? cell!.firstIn! : _formatTime(r?.firstCheckInAt);
                  final outTime = cell?.lastOut?.isNotEmpty == true ? cell!.lastOut! : _formatTime(r?.lastCheckOutAt);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => widget.onDaySelected(day, dateStr, r, cell, weekdayShort),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$weekdayShort, ${_formatDate(dateStr)}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                if (cell?.shiftName.isNotEmpty == true)
                                  Text(
                                    cell!.shiftName,
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Vào: $inTime  |  Ra: $outTime',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                if (cell != null && cell.workUnits > 0)
                                  Text(
                                    '${cell.workUnits} công',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            _buildMatrixCellBadgeForBoard(cell, r),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MODE 1: NHẬT KÝ QUẸT THẺ VIEW
  // ==========================================
  Widget _buildLogsViewMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildHistoryFilterChip('Tất cả', 'ALL'),
              _buildHistoryFilterChip('Hợp lệ', 'VALID'),
              _buildHistoryFilterChip('Đi muộn', 'LATE'),
              _buildHistoryFilterChip('Bất thường', 'ABNORMAL'),
              _buildHistoryFilterChip('Đã duyệt sửa', 'APPROVED_CORRECTION'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // History List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredHistory.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _filteredHistory[index];
            return _buildHistoryItemCard(item);
          },
        ),
      ],
    );
  }

  Widget _buildHistoryFilterChip(String label, String value) {
    final isSelected = _historyFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFF0F172A),
        backgroundColor: const Color(0xFFF1F5F9),
        showCheckmark: false,
        onSelected: (_) => setState(() => _historyFilter = value),
      ),
    );
  }

  Widget _buildHistoryItemCard(AttendanceRecord item) {
    Color statusBg = const Color(0xFFECFDF5);
    Color statusColor = const Color(0xFF059669);
    String statusText = 'Hợp lệ';

    if (item.status == 'LATE') {
      statusBg = const Color(0xFFFEF3C7);
      statusColor = const Color(0xFFD97706);
      statusText = 'Đi muộn ${item.lateMinutes}p';
    } else if (item.status == 'ABNORMAL') {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFDC2626);
      statusText = 'Bất thường (Thiếu quẹt)';
    } else if (item.status == 'APPROVED_CORRECTION') {
      statusBg = const Color(0xFFF3E8FF);
      statusColor = const Color(0xFF7C3AED);
      statusText = 'Đã duyệt sửa công';
    }

    final canExplain = item.status == 'ABNORMAL' || item.status == 'LATE';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(item.workDate),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Giờ vào:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(item.firstCheckInAt),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Giờ ra:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(item.lastCheckOutAt),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tổng công:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      item.workedMinutes > 0 ? '${(item.workedMinutes / 60).toStringAsFixed(1)} giờ' : '--',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.note != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ghi chú: ${item.note}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],
          if (canExplain) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => widget.onExplainItem(item),
                icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Giải trình công', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ),
          ],
        ],
      ),
    );
  }


  // Web Style KPI Card
  Widget _buildWebKpiCard({
    required String label,
    required String value,
    required String unit,
    String? hint,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    bool isAlert = false,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isAlert ? const Color(0xFFB91C1C) : const Color(0xFF0F172A),
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          unit,
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (hint != null && hint.isNotEmpty)
                  Text(
                    hint,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (progress != null) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progress / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
