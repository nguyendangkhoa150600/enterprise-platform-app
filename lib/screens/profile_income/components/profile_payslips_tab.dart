import 'package:flutter/material.dart';
import '../../../features/payroll/widgets/payslip_item_card.dart';
import '../../../widgets/hrm_payslip_modals.dart';
import '../../../shared/widgets/empty_state_view.dart';

class ProfilePayslipsTabContent extends StatelessWidget {
  final List<dynamic> payslips;
  final String userFullName;
  final String userEmail;
  final String employeeCode;
  final String department;
  final String position;
  final String statusLabel;
  final Future<void> Function() onRefresh;

  const ProfilePayslipsTabContent({
    super.key,
    required this.payslips,
    required this.userFullName,
    required this.userEmail,
    required this.employeeCode,
    required this.department,
    required this.position,
    required this.statusLabel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Page Header Card (Matching Web 1:1)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.receipt_long_rounded, size: 22, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phiếu lương Cá nhân',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Xem chi tiết cấu thành thu nhập, các khoản khấu trừ bảo hiểm, thuế TNCN và thực lĩnh theo từng kỳ đã phát hành.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Section Header: KỲ NHẬN LƯƠNG (N)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KỲ NHẬN LƯƠNG (${payslips.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5),
                  ),
                  InkWell(
                    onTap: onRefresh,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text('Làm mới', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (payslips.isEmpty)
              const EmptyStateView(
                icon: Icons.receipt_outlined,
                title: 'Chưa có phiếu lương được phát hành.',
                subtitle: 'Khi phòng Kế toán / Nhân sự khóa sổ kỳ lương và phát hành phiếu lương, bạn sẽ nhận được thông báo và xem chi tiết tại đây.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payslips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final item = payslips[idx];
                  return PayslipItemCard(
                    item: item,
                    userName: userFullName,
                    employeeCode: employeeCode,
                    department: department,
                    position: position,
                    onRefresh: onRefresh,
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static void showPayslipDetailModal(
    BuildContext context,
    Map<String, dynamic> item,
    String userFullName,
    String employeeCode,
    String department,
    String position,
  ) {
    HrmPayslipModals.showPayslipBreakdownSheet(
      context,
      item,
      profile: {
        'fullName': userFullName,
        'code': employeeCode,
        'department': department,
        'position': position,
      },
    );
  }
}
