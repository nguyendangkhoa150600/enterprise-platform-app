import 'package:flutter/material.dart';
import '../../../models/hrm_attendance_models.dart';
import '../../../core/i18n/app_i18n.dart';

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
void showAttendanceDayDetailModal(
  BuildContext context, {
  required int day,
  required String dateStr,
  required AttendanceRecord? record,

  required TimesheetCell? boardCell,
  required String weekdayStr,
  required List<AttendanceRecord> history,
  required HrmTimesheetBoard? timesheetBoard,
  required Function(AttendanceRecord? item) onOpenCorrectionDialog,
}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final rawDay = boardCell?.rawBoardDay;

        // Today comparison
        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final isToday = dateStr == todayStr;
        final isFuture = dateStr.compareTo(todayStr) > 0 || (rawDay?.status == 'FUTURE');

        // Status pill matching Web dayStatusPill
        String statusLabel = 'attendance.day.status.none'.tr();
        Color statusBg = const Color(0xFFF1F5F9);
        Color statusColor = const Color(0xFF475569);
        Color statusBorder = const Color(0xFFE2E8F0);

        final rawStatus = rawDay?.status ?? record?.status ?? '';
        final workdayUnits = rawDay?.workdayUnits ?? boardCell?.workUnits ?? (record?.status == 'VALID' ? 1.0 : 0.0);
        final lateMinutes = rawDay?.lateMinutes ?? boardCell?.lateMinutes ?? record?.lateMinutes ?? 0;
        final earlyMinutes = rawDay?.earlyLeaveMinutes ?? boardCell?.earlyMinutes ?? 0;

        if (isFuture) {
          statusLabel = 'attendance.day.status.future'.tr();
          statusBg = const Color(0xFFF1F5F9);
          statusColor = const Color(0xFF475569);
          statusBorder = const Color(0xFFE2E8F0);
        } else if (rawStatus == 'ABSENT') {
          statusLabel = 'attendance.day.status.absent'.tr();
          statusBg = const Color(0xFFFEF2F2);
          statusColor = const Color(0xFFDC2626);
          statusBorder = const Color(0xFFFECACA);
        } else if (rawStatus == 'ABNORMAL') {
          statusLabel = 'attendance.day.status.abnormal'.tr();
          statusBg = const Color(0xFFFDF4FF);
          statusColor = const Color(0xFFC026D3);
          statusBorder = const Color(0xFFF5D0FE);
        } else if (lateMinutes > 0 || earlyMinutes > 0 || rawStatus == 'LATE' || rawStatus == 'LATE_EARLY' || rawStatus == 'EARLY_LEAVE') {
          statusLabel = earlyMinutes > 0 && lateMinutes > 0
              ? 'attendance.day.status.late_early'.tr()
              : (earlyMinutes > 0 ? 'attendance.day.status.early'.tr() : 'attendance.day.status.late'.tr());
          statusBg = const Color(0xFFFFF7ED);
          statusColor = const Color(0xFFEA580C);
          statusBorder = const Color(0xFFFED7AA);
        } else if (rawStatus.contains('LEAVE') || (boardCell?.isLeave ?? false)) {
          statusLabel = 'attendance.day.status.leave'.tr();
          statusBg = const Color(0xFFEFF6FF);
          statusColor = const Color(0xFF2563EB);
          statusBorder = const Color(0xFFBFDBFE);
        } else if (rawStatus == 'OFF') {
          statusLabel = 'attendance.day.status.off'.tr();
          statusBg = const Color(0xFFF1F5F9);
          statusColor = const Color(0xFF64748B);
          statusBorder = const Color(0xFFCBD5E1);
        } else if (rawStatus == 'HOLIDAY') {
          statusLabel = 'attendance.day.status.holiday'.tr();
          statusBg = const Color(0xFFF1F5F9);
          statusColor = const Color(0xFF64748B);
          statusBorder = const Color(0xFFCBD5E1);
        } else if (workdayUnits > 0 || (rawDay?.checkIn != null && rawDay!.checkIn!.isNotEmpty) || record?.status == 'VALID') {
          statusLabel = workdayUnits >= 1.0 ? 'attendance.day.status.full'.tr() : 'attendance.day.status.partial'.tr();
          statusBg = workdayUnits >= 1.0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7);
          statusColor = workdayUnits >= 1.0 ? const Color(0xFF059669) : const Color(0xFFD97706);
          statusBorder = workdayUnits >= 1.0 ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);
        }

        // Subtitle text: "Hôm nay", "Chưa tới ngày", "Đã qua"
        String subtitleText = isToday ? 'attendance.day.subtitle.today'.tr() : (isFuture ? 'attendance.day.status.future'.tr() : 'attendance.day.subtitle.past'.tr());
        if (rawDay?.holidayName != null && rawDay!.holidayName!.isNotEmpty) {
          subtitleText += 'attendance.day.subtitle.holiday'.tr(args: {'name': rawDay.holidayName});
        }

        // 4 KPI tiles values (matching Web):
        final workedMinutes = rawDay?.workedMinutes ?? record?.workedMinutes ?? 0;
        final totalWorkedHours = (workedMinutes / 60.0).toStringAsFixed(1);
        final paidMinutes = rawDay?.paidMinutes ?? (workdayUnits * 480).toInt();
        final paidHours = (paidMinutes / 60.0).toStringAsFixed(1);
        final checkInTime = rawDay?.checkIn?.isNotEmpty == true
            ? rawDay!.checkIn!
            : (boardCell?.firstIn?.isNotEmpty == true
                ? boardCell!.firstIn!
                : (record?.firstCheckInAt != null ? _formatTime(record!.firstCheckInAt) : '--:--'));
        final checkOutTime = rawDay?.checkOut?.isNotEmpty == true
            ? rawDay!.checkOut!
            : (boardCell?.lastOut?.isNotEmpty == true
                ? boardCell!.lastOut!
                : (record?.lastCheckOutAt != null ? _formatTime(record!.lastCheckOutAt) : '--:--'));

        // Real Shift info from API
        final shiftName = rawDay?.shiftName ?? boardCell?.shiftName ?? 'attendance.day.default_shift'.tr();
        final shiftStart = rawDay?.shiftStart ?? '07:30';
        final shiftEnd = rawDay?.shiftEnd ?? '17:00';
        final shiftBreakStart = rawDay?.shiftBreakStart ?? '11:30';
        final shiftBreakEnd = rawDay?.shiftBreakEnd ?? '13:00';
        final shiftBreakMinutes = rawDay?.shiftBreakMinutes ?? 90;
        final scheduledMinutes = rawDay?.scheduledMinutes ?? 480;
        final scheduledHours = (scheduledMinutes / 60.0).round();

        // Requests for THIS SPECIFIC DAY (đơn từ của ngày nào thì chỉ hiển thị ngày đó)
        final dayRequests = <HrmDayRequest>[];
        if (rawDay != null && rawDay.requests.isNotEmpty) {
          dayRequests.addAll(rawDay.requests);
        } else if (timesheetBoard?.myEmployee != null) {
          final d = timesheetBoard!.myEmployee!.days[dateStr];
          if (d != null && d.requests.isNotEmpty) {
            dayRequests.addAll(d.requests);
          }
        }

        int modalTab = 0;
        bool isShiftInfoOpen = true;

        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  // Top Drag Handle
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 8),

                  // Tab Switcher Header (Chi tiết ngày vs Đơn từ trong ngày)
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => modalTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: modalTab == 0 ? const Color(0xFFD97706) : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                'attendance.day.tab.detail'.tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: modalTab == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: modalTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => modalTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: modalTab == 1 ? const Color(0xFFD97706) : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                'attendance.day.tab.requests'.tr(args: {'count': dayRequests.length}),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: modalTab == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: modalTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: modalTab == 0
                          ? _buildModalDayTab(
                              context: context,
                              weekdayStr: weekdayStr,
                              dateStr: dateStr,
                              subtitleText: subtitleText,
                              statusLabel: statusLabel,
                              statusBg: statusBg,
                              statusColor: statusColor,
                              statusBorder: statusBorder,
                              totalWorkedHours: totalWorkedHours,
                              paidHours: paidHours,
                              checkInTime: checkInTime,
                              checkOutTime: checkOutTime,
                              lateMinutes: lateMinutes,
                              earlyMinutes: earlyMinutes,
                              shiftName: shiftName,
                              shiftStart: shiftStart,
                              shiftEnd: shiftEnd,
                              shiftBreakStart: shiftBreakStart,
                              shiftBreakEnd: shiftBreakEnd,
                              shiftBreakMinutes: shiftBreakMinutes,
                              scheduledHours: scheduledHours,
                              isShiftInfoOpen: isShiftInfoOpen,
                              onToggleShiftInfo: () => setModalState(() => isShiftInfoOpen = !isShiftInfoOpen),
                              rawDay: rawDay,
                              record: record,
                              history: history,
                              boardCell: boardCell,
                              dayRequests: dayRequests,
                              onExplain: () {
                                Navigator.pop(ctx);
                                onOpenCorrectionDialog(record);
                              },
                            )
                          : _buildModalRequestsTab(dayRequests),
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

  Widget _buildModalDayTab({
    required BuildContext context,
    required String weekdayStr,
    required String dateStr,
    required String subtitleText,
    required String statusLabel,
    required Color statusBg,
    required Color statusColor,
    required Color statusBorder,
    required String totalWorkedHours,
    required String paidHours,
    required String checkInTime,
    required String checkOutTime,
    required int lateMinutes,
    required int earlyMinutes,
    required String shiftName,
    required String shiftStart,
    required String shiftEnd,
    required String shiftBreakStart,
    required String shiftBreakEnd,
    required int shiftBreakMinutes,
    required int scheduledHours,
    required bool isShiftInfoOpen,
    required VoidCallback onToggleShiftInfo,
    required HrmBoardDay? rawDay,
    required AttendanceRecord? record,
    required List<AttendanceRecord> history,
    required TimesheetCell? boardCell,
    List<HrmDayRequest> dayRequests = const [],
    required VoidCallback onExplain,
  }) {
    final canExplain = rawDay?.status == 'ABSENT' || rawDay?.status == 'ABNORMAL' || lateMinutes > 0 || earlyMinutes > 0;
    final effectiveRequests = dayRequests.isNotEmpty ? dayRequests : (rawDay?.requests ?? const <HrmDayRequest>[]);

    // Leave info for DayBands banner (P)
    final hasLeave = rawDay?.leave != null || effectiveRequests.any((r) => r.kind == 'LEAVE') || (rawDay?.status != null && rawDay!.status.contains('LEAVE')) || (boardCell?.isLeave ?? false);
    String leaveDesc = 'attendance.day.leave.default_desc'.tr();
    if (rawDay?.leave != null) {
      final lv = rawDay!.leave!;
      final name = lv.reasonName ?? 'attendance.day.leave.name_default'.tr();
      final pay = lv.paid ? 'attendance.day.leave.paid'.tr() : 'attendance.day.leave.unpaid'.tr();
      final annual = lv.annual ? 'attendance.day.leave.deduct_annual'.tr() : '';
      leaveDesc = '$name ($pay$annual)';
    } else {
      final req = effectiveRequests.where((r) => r.kind == 'LEAVE').firstOrNull;
      if (req != null) {
        final name = req.label ?? req.reasonName ?? 'attendance.day.leave.annual_name'.tr();
        final isAnnual = name.toLowerCase().contains('năm');
        leaveDesc = '$name (${'attendance.day.leave.paid'.tr()}${isAnnual ? 'attendance.day.leave.deduct_annual'.tr() : ""})';
      }
    }
    final leaveDaysNum = rawDay?.leave?.days ?? (rawDay?.workdayUnits ?? 1.0);
    final leaveDaysStr = leaveDaysNum == leaveDaysNum.roundToDouble()
        ? 'attendance.day.days'.tr(args: {'count': leaveDaysNum.toInt()})
        : 'attendance.day.days'.tr(args: {'count': leaveDaysNum});

    final hasOt = (rawDay?.otMinutes ?? 0) > 0;
    final hasTrip = rawDay?.tripId != null && rawDay!.tripId!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header (Icon, Date, Subtitle, Status Badge)
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3), // Soft yellow background as on Web
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month_rounded, size: 22, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$weekdayStr, ${_formatDate(dateStr)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusBorder),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. 4 Metric Tiles (Grid 2x2: Tổng giờ làm, Giờ công, Giờ vào, Giờ ra)
        Row(
          children: [
            Expanded(child: _buildDayMetricTile(label: 'attendance.day.metric.total_hours'.tr(), value: totalWorkedHours)),
            const SizedBox(width: 8),
            Expanded(child: _buildDayMetricTile(label: 'attendance.day.metric.paid_hours'.tr(), value: paidHours)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDayMetricTile(
                label: 'attendance.day.metric.check_in'.tr(),
                value: checkInTime,
                icon: Icons.login_rounded,
                iconBg: checkInTime != '--:--'
                    ? (lateMinutes > 0 ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5))
                    : const Color(0xFFF1F5F9),
                iconColor: checkInTime != '--:--'
                    ? (lateMinutes > 0 ? const Color(0xFFEA580C) : const Color(0xFF059669))
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDayMetricTile(
                label: 'attendance.day.metric.check_out'.tr(),
                value: checkOutTime,
                icon: Icons.logout_rounded,
                iconBg: checkOutTime != '--:--'
                    ? (earlyMinutes > 0 ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5))
                    : const Color(0xFFF1F5F9),
                iconColor: checkOutTime != '--:--'
                    ? (earlyMinutes > 0 ? const Color(0xFFEA580C) : const Color(0xFF059669))
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3. Shift Timeline (Dòng thời gian ca làm)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimelineStep(label: 'attendance.day.timeline.shift_start'.tr(), time: shiftStart, isLast: false),
              _buildTimelineStep(label: 'attendance.day.timeline.break_start'.tr(), time: shiftBreakStart, isLast: false),
              if (checkInTime != '--:--')
                _buildTimelineStep(
                  label: 'attendance.day.timeline.punch_in'.tr(),
                  time: checkInTime,
                  note: lateMinutes > 0 ? 'attendance.day.timeline.late_note'.tr(args: {'minutes': lateMinutes}) : null,
                  isAlert: lateMinutes > 0,
                  isSuccess: lateMinutes == 0,
                  isLast: false,
                ),
              _buildTimelineStep(label: 'attendance.day.timeline.break_end'.tr(), time: shiftBreakEnd, isLast: false),
              if (checkOutTime != '--:--')
                _buildTimelineStep(
                  label: 'attendance.day.timeline.punch_out'.tr(),
                  time: checkOutTime,
                  note: earlyMinutes > 0 ? 'attendance.day.timeline.early_note'.tr(args: {'minutes': earlyMinutes}) : null,
                  isAlert: earlyMinutes > 0,
                  isSuccess: earlyMinutes == 0,
                  isLast: false,
                ),
              _buildTimelineStep(label: 'attendance.day.timeline.shift_end'.tr(), time: shiftEnd, isLast: true),

              // Note when punch in / punch out are missing (Matching Web text-fuchsia-700)
              if (checkInTime == '--:--' && checkOutTime == '--:--') ...[
                const SizedBox(height: 8),
                Text(
                  'attendance.day.timeline.missing_both'.tr(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA21CAF), // Fuchsia / Purple matching web
                  ),
                ),
              ] else if (checkInTime == '--:--') ...[
                const SizedBox(height: 8),
                Text(
                  'attendance.day.timeline.missing_in'.tr(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA21CAF),
                  ),
                ),
              ] else if (checkOutTime == '--:--') ...[
                const SizedBox(height: 8),
                Text(
                  'attendance.day.timeline.missing_out'.tr(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA21CAF),
                  ),
                ),
              ],
            ],
          ),
        ),

        // DayBands (Dải trạng thái: Nghỉ phép / Tăng ca / Công tác)
        if (hasLeave)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('attendance.day.letter.leave'.tr(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    leaveDesc,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                ),
                Text(
                  leaveDaysStr,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        if (hasOt)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D28D9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('attendance.day.letter.ot'.tr(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'attendance.day.banner.ot_approved'.tr(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5B21B6)),
                  ),
                ),
                Text(
                  'attendance.day.hours_value'.tr(args: {'hours': _formatMinutesToHours(rawDay?.otMinutes)}),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6), fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        if (hasTrip)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4338CA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('attendance.day.letter.trip'.tr(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'attendance.day.banner.trip_approved'.tr(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3730A3)),
                  ),
                ),
              ],
            ),
          ),

        // Section "Đơn từ áp dụng cho ngày này" (Matching Web DayRequestList)
        if (effectiveRequests.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'attendance.day.applied_requests'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                ...effectiveRequests.map((req) => _buildAppliedRequestCard(context, req)),
                const SizedBox(height: 4),
                Text(
                  'attendance.day.applied_note'.tr(),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // 4. Collapsible "Thông tin ca làm"
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: onToggleShiftInfo,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'attendance.day.shift_info.title'.tr(),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Icon(
                      isShiftInfoOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
              if (isShiftInfoOpen) ...[
                const SizedBox(height: 12),
                _buildModalInfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'attendance.day.shift_info.shift'.tr(),
                  value: '$shiftName ($shiftStart - $shiftEnd)',
                ),
                const SizedBox(height: 10),
                _buildModalInfoRow(
                  icon: Icons.access_time_rounded,
                  label: 'attendance.day.shift_info.work_time'.tr(),
                  value: 'attendance.day.shift_info.hours'.tr(args: {'count': scheduledHours}),
                ),
                const SizedBox(height: 10),
                _buildModalInfoRow(
                  icon: Icons.timelapse_outlined,
                  label: 'attendance.day.shift_info.break'.tr(),
                  value: '$shiftBreakStart - $shiftBreakEnd (${(shiftBreakMinutes ~/ 60) > 0 ? "${'attendance.day.shift_info.hours_part'.tr(args: {'count': shiftBreakMinutes ~/ 60})} " : ""}${shiftBreakMinutes % 60 > 0 ? 'attendance.day.shift_info.minutes_part'.tr(args: {'count': shiftBreakMinutes % 60}) : ""})',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. "Xem chi tiết chấm công >" Button (Matching Web MyDayPanel)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              // Open raw punch log / records for this day
              _showDayPunchesDetailSheet(context, dateStr, rawDay, record, history);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'attendance.day.view_punch_detail'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFB45309)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 6. Action Button (Làm đơn giải trình nếu có sai lệch)
        if (canExplain) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onExplain,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: Text('attendance.day.explain_for_day'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('common.close'.tr(), style: const TextStyle(color: Color(0xFF475569))),
          ),
        ),
      ],
    );
  }

  Widget _buildModalRequestsTab(List<HrmDayRequest> requests) {
    if (requests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Text(
          'attendance.day.no_requests'.tr(),
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      );
    }

    return Column(
      children: requests.map((req) {
        Color badgeBg = const Color(0xFFFEF3C7);
        Color badgeColor = const Color(0xFFD97706);
        String badgeText = 'attendance.day.req_status.pending'.tr();

        if (req.status == 'APPROVED') {
          badgeBg = const Color(0xFFECFDF5);
          badgeColor = const Color(0xFF059669);
          badgeText = 'attendance.day.req_status.approved'.tr();
        } else if (req.status == 'REJECTED') {
          badgeBg = const Color(0xFFFEF2F2);
          badgeColor = const Color(0xFFDC2626);
          badgeText = 'attendance.day.req_status.rejected'.tr();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.label ?? (req.reasonName ?? req.kind),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    if (req.fromAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        req.fromAt!.length >= 10 ? req.fromAt!.substring(0, 10) : req.fromAt!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDateTimeVn(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatRequestTimeRange(HrmDayRequest req) {
    final from = _formatDateTimeVn(req.fromAt);
    final to = _formatDateTimeVn(req.toAt);
    if (from.isEmpty || to.isEmpty) return from.isNotEmpty ? from : to;
    if (from.length >= 10 && to.length >= 10 && from.substring(0, 10) == to.substring(0, 10)) {
      final toTime = to.length > 11 ? to.substring(11) : to;
      return '$from - $toTime';
    }
    return '$from - $to';
  }

  String _formatMinutesToHours(int? minutes) {
    if (minutes == null || minutes <= 0) return '0:00';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  String _getRequestLetter(String kind) {
    switch (kind.toUpperCase()) {
      case 'LEAVE':
        return 'attendance.day.letter.leave'.tr();
      case 'OT':
        return 'attendance.day.letter.ot'.tr();
      case 'TRIP':
        return 'attendance.day.letter.trip'.tr();
      case 'CORRECTION':
        return 'attendance.day.letter.correction'.tr();
      case 'SHIFT_CHANGE':
        return 'attendance.day.letter.shift_change'.tr();
      case 'CUSTOM':
        return 'attendance.day.letter.custom'.tr();
      default:
        return 'attendance.day.letter.leave'.tr();
    }
  }

  String _getRequestKindLabel(String kind) {
    switch (kind.toUpperCase()) {
      case 'LEAVE':
        return 'attendance.day.kind.leave'.tr();
      case 'OT':
        return 'attendance.day.kind.ot'.tr();
      case 'TRIP':
        return 'attendance.day.kind.trip'.tr();
      case 'CORRECTION':
        return 'attendance.day.kind.correction'.tr();
      case 'SHIFT_CHANGE':
        return 'attendance.day.kind.shift_change'.tr();
      case 'CUSTOM':
        return 'attendance.day.kind.custom'.tr();
      default:
        return 'attendance.day.kind.default'.tr();
    }
  }

  String _getRequestSummary(HrmDayRequest req) {
    final kindLabel = _getRequestKindLabel(req.kind);
    final label = req.label ?? (req.kind == 'LEAVE' ? 'attendance.day.leave.annual_name'.tr() : '');
    final minutes = req.minutes;
    String hoursPart = '';
    if (minutes != null && minutes > 0) {
      final hours = minutes / 60.0;
      final hoursStr = hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toStringAsFixed(1);
      if (req.kind == 'OT') {
        hoursPart = 'attendance.day.summary.hours_approved'.tr(args: {'hours': hoursStr});
      } else if (req.kind == 'LEAVE') {
        hoursPart = 'attendance.day.summary.hours_paid'.tr(args: {'hours': hoursStr});
      } else {
        hoursPart = 'attendance.day.summary.hours'.tr(args: {'hours': hoursStr});
      }
    }

    final parts = <String>[];
    if (label.isNotEmpty) parts.add(label);
    if (hoursPart.isNotEmpty) parts.add(hoursPart);

    if (parts.isNotEmpty) {
      return '$kindLabel: ${parts.join(" - ")}';
    }
    return kindLabel;
  }

  Widget _buildAppliedRequestCard(BuildContext context, HrmDayRequest req) {
    final letter = _getRequestLetter(req.kind);
    final summary = _getRequestSummary(req);

    Color badgeBg = const Color(0xFFFEF3C7);
    Color badgeColor = const Color(0xFFD97706);
    Color badgeBorder = const Color(0xFFFDE68A);
    String badgeText = 'attendance.day.req_status.pending'.tr();

    if (req.status == 'APPROVED') {
      badgeBg = const Color(0xFFECFDF5);
      badgeColor = const Color(0xFF059669);
      badgeBorder = const Color(0xFFA7F3D0);
      badgeText = 'attendance.day.req_status.approved'.tr();
    } else if (req.status == 'REJECTED') {
      badgeBg = const Color(0xFFFEF2F2);
      badgeColor = const Color(0xFFDC2626);
      badgeBorder = const Color(0xFFFECACA);
      badgeText = 'attendance.day.req_status.rejected'.tr();
    }

    final timeRange = _formatRequestTimeRange(req);
    final createdStr = _formatDateTimeVn(req.createdAt);
    final hoursStr = _formatMinutesToHours(req.minutes);

    final details = <MapEntry<String, String>>[];
    if (timeRange.isNotEmpty) details.add(MapEntry('attendance.day.detail.time'.tr(), timeRange));
    if (req.label != null && req.label!.isNotEmpty) details.add(MapEntry(req.kind == 'LEAVE' ? 'attendance.day.detail.leave_type'.tr() : 'attendance.day.detail.content'.tr(), req.label!));
    if (req.description != null && req.description!.isNotEmpty && req.description != req.label) {
      details.add(MapEntry('common.note'.tr(), req.description!));
    }
    if (req.kind == 'LEAVE' && req.minutes != null && req.minutes! > 0) {
      details.add(MapEntry('attendance.day.detail.paid_hours'.tr(), hoursStr));
    } else if (req.kind == 'OT' && req.minutes != null && req.minutes! > 0) {
      details.add(MapEntry('attendance.day.detail.ot_hours'.tr(), hoursStr));
    }
    if (createdStr.isNotEmpty) details.add(MapEntry('attendance.day.detail.created_at'.tr(), createdStr));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      summary,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showRequestDetailModal(context, req),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'attendance.day.open_request'.tr(),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...details.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _showRequestDetailModal(BuildContext context, HrmDayRequest req) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
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
              const SizedBox(height: 16),
              Text(
                _getRequestSummary(req),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              if (req.fromAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('attendance.day.detail_modal.time'.tr(args: {'value': _formatRequestTimeRange(req)}), style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                ),
              if (req.label != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('attendance.day.detail_modal.type'.tr(args: {'value': req.label}), style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                ),
              if (req.description != null && req.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('attendance.day.detail_modal.reason'.tr(args: {'value': req.description}), style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('common.close'.tr()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDayPunchesDetailSheet(BuildContext context, String dateStr, HrmBoardDay? rawDay, AttendanceRecord? record, List<AttendanceRecord> history) {
    // Gather punches from record or history or rawDay checkIn/checkOut
    final punches = <AttendancePunch>[];
    if (record != null && record.punchList.isNotEmpty) {
      punches.addAll(record.punchList);
    } else {
      for (final h in history) {
        if (h.workDate == dateStr) {
          if (h.punchList.isNotEmpty) {
            punches.addAll(h.punchList);
          } else {
            if (h.firstCheckInAt != null) {
              punches.add(AttendancePunch(
                punchType: 'IN',
                occurredAt: h.firstCheckInAt!,
                verificationMethod: h.attendanceSource,
                siteName: h.matchedSiteName,
              ));
            }
            if (h.lastCheckOutAt != null) {
              punches.add(AttendancePunch(
                punchType: 'OUT',
                occurredAt: h.lastCheckOutAt!,
                verificationMethod: h.attendanceSource,
                siteName: h.matchedSiteName,
              ));
            }
          }
        }
      }
    }

    // Fallback to rawDay checkIn / checkOut if list still empty but check-in exists
    if (punches.isEmpty) {
      if (rawDay?.checkIn != null && rawDay!.checkIn!.isNotEmpty && rawDay.checkIn != '--:--') {
        punches.add(AttendancePunch(
          punchType: 'IN',
          occurredAt: '${dateStr}T${rawDay.checkIn}:00',
          verificationMethod: 'attendance.day.punch.device'.tr(),
          siteName: rawDay.shiftName,
        ));
      }
      if (rawDay?.checkOut != null && rawDay!.checkOut!.isNotEmpty && rawDay.checkOut != '--:--') {
        punches.add(AttendancePunch(
          punchType: 'OUT',
          occurredAt: '${dateStr}T${rawDay.checkOut}:00',
          verificationMethod: 'attendance.day.punch.device'.tr(),
          siteName: rawDay.shiftName,
        ));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'attendance.day.punch.title'.tr(args: {'date': _formatDate(dateStr)}),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (punches.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'attendance.day.punch.empty'.tr(),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: punches.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (c, idx) {
                      final p = punches[idx];
                      final isCheckIn = p.punchType.toUpperCase() == 'IN' || p.punchType == 'Vào';
                      final deviceOrMethod = p.deviceName?.isNotEmpty == true
                          ? p.deviceName
                          : (p.verificationMethod?.isNotEmpty == true
                              ? p.verificationMethod
                              : (p.siteName?.isNotEmpty == true ? p.siteName : null));

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isCheckIn ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                                size: 18,
                                color: isCheckIn ? const Color(0xFF059669) : const Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isCheckIn ? 'attendance.day.punch.in'.tr() : 'attendance.day.punch.out'.tr(),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  if (deviceOrMethod != null)
                                    Text(
                                      'attendance.day.punch.method'.tr(args: {'value': deviceOrMethod}),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              p.occurredAt.length > 5 ? _formatTime(p.occurredAt) : p.occurredAt,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
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
      },
    );
  }

  Widget _buildDayMetricTile({
    required String label,
    required String value,
    IconData? icon,
    Color? iconBg,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg ?? const Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: iconColor ?? const Color(0xFF059669)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String label,
    required String time,
    String? note,
    bool isAlert = false,
    bool isSuccess = false,
    required bool isLast,
  }) {
    Color dotColor = const Color(0xFF94A3B8);
    Color dotBorder = const Color(0xFFCBD5E1);
    if (isAlert) {
      dotColor = const Color(0xFFEA580C);
      dotBorder = const Color(0xFFEA580C);
    } else if (isSuccess) {
      dotColor = const Color(0xFF059669);
      dotBorder = const Color(0xFF059669);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dot and vertical line
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: isAlert || isSuccess ? dotColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotBorder, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                      if (note != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isAlert ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isAlert ? const Color(0xFFEA580C) : const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
