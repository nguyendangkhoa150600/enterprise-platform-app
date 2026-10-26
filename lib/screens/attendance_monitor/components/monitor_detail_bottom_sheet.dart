import 'package:flutter/material.dart';
import '../../../models/hrm_attendance_monitor_models.dart';
import '../../hrm_hub_screen.dart';

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
                          child: MonitorMetricCard(label: 'Ca làm', value: row.shiftName ?? 'Ca Hành Chính'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MonitorMetricCard(label: 'Giờ dự kiến', value: row.shiftTimeText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: MonitorMetricCard(label: 'Giờ vào', value: row.checkIn ?? 'Chưa chấm'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MonitorMetricCard(label: 'Giờ ra', value: row.checkOut ?? 'Chưa chấm'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: MonitorMetricCard(label: 'Đi trễ', value: row.lateMinutes > 0 ? '${row.lateMinutes} phút' : 'Không'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MonitorMetricCard(label: 'Về sớm', value: row.earlyLeaveMinutes > 0 ? '${row.earlyLeaveMinutes} phút' : 'Không'),
                        ),
                      ],
                    ),
                    if (row.leaveName != null || row.leaveDays > 0) ...[
                      const SizedBox(height: 10),
                      MonitorMetricCard(
                        label: 'Nghỉ phép',
                        value: [row.leaveName, row.leaveDays > 0 ? '${row.leaveDays} ngày' : null].where((e) => e != null).join(' · '),
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
