import 'package:flutter/material.dart';
import '../../../models/hrm_leave_balance_models.dart';

Widget buildLeaveStatCell(String label, String value, {Color? color}) {
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

class EmployeeLeaveBalanceCard extends StatelessWidget {
  final HrmLeaveBalanceItem row;
  final VoidCallback onTap;
  final String Function(double) formatNumber;

  const EmployeeLeaveBalanceCard({
    super.key,
    required this.row,
    required this.onTap,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
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
        onTap: onTap,
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
                    buildLeaveStatCell('Định mức', formatNumber(row.entitlement)),
                    const SizedBox(width: 10),
                    buildLeaveStatCell('Thâm niên', '+${formatNumber(row.seniorityDays)}', color: const Color(0xFF059669)),
                    const SizedBox(width: 10),
                    buildLeaveStatCell('Năm cũ', formatNumber(row.carryover)),
                    const SizedBox(width: 10),
                    buildLeaveStatCell('Đã dùng', formatNumber(row.used), color: const Color(0xFFDC2626)),
                    const Spacer(),
                    // Remaining Days Box
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Còn lại', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        Text(
                          '${formatNumber(row.remaining)} ngày',
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
}
