import 'package:flutter/material.dart';
import '../../../models/hrm_attendance_monitor_models.dart';
import '../../hrm_hub_screen.dart';
import '../../../core/i18n/app_i18n.dart';

class MonitorMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const MonitorMetricCard({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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

void showMonitorDetailBottomSheet(
  BuildContext context, {
  required HrmMonitorRow row,
  required String formattedSelectedDate,
}) {
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
                          formattedSelectedDate,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 2-Column Grid of 6 Cards (matching Web 1:1)
                    Row(
                      children: [
                        Expanded(
                          child: MonitorMetricCard(label: 'att_monitor.detail.shift'.tr(), value: row.shiftName ?? 'att_monitor.detail.default_shift'.tr()),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MonitorMetricCard(label: 'att_monitor.detail.expected_time'.tr(), value: row.shiftTimeText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: MonitorMetricCard(label: 'att_monitor.detail.check_in'.tr(), value: row.checkIn ?? 'att_monitor.detail.not_punched'.tr()),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MonitorMetricCard(label: 'att_monitor.detail.check_out'.tr(), value: row.checkOut ?? 'att_monitor.detail.not_punched'.tr()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: MonitorMetricCard(label: 'att_monitor.detail.late'.tr(), value: row.lateMinutes > 0 ? 'att_monitor.detail.minutes'.tr(args: {'count': row.lateMinutes}) : 'att_monitor.detail.none'.tr()),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MonitorMetricCard(label: 'att_monitor.detail.early_leave'.tr(), value: row.earlyLeaveMinutes > 0 ? 'att_monitor.detail.minutes'.tr(args: {'count': row.earlyLeaveMinutes}) : 'att_monitor.detail.none'.tr()),
                        ),
                      ],
                    ),
                    if (row.leaveName != null || row.leaveDays > 0) ...[
                      const SizedBox(height: 10),
                      MonitorMetricCard(
                        label: 'att_monitor.detail.leave'.tr(),
                        value: [row.leaveName, row.leaveDays > 0 ? 'att_monitor.detail.days'.tr(args: {'count': row.leaveDays}) : null].where((e) => e != null).join(' · '),
                      ),
                    ],
                    const SizedBox(height: 22),

                    // Section: Đơn từ liên quan
                    Text(
                      'att_monitor.detail.related_requests'.tr(args: {'count': row.requests.length}),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (row.requests.isEmpty)
                      Text(
                        'att_monitor.requests.empty'.tr(),
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
                      child: Text(
                        'att_monitor.detail.view_timesheet'.tr(),
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
