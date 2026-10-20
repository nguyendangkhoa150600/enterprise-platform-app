import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/pdf_export_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../widgets/hrm_payslip_modals.dart';

/// Card item displaying individual monthly payslip
class PayslipItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String userName;
  final String employeeCode;
  final String department;
  final String position;
  final VoidCallback? onRefresh;

  const PayslipItemCard({
    super.key,
    required this.item,
    required this.userName,
    required this.employeeCode,
    required this.department,
    required this.position,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = item['snapshotJson'] is Map ? item['snapshotJson'] as Map<String, dynamic> : null;
    final periodInfo = snapshot?['period'] as Map?;
    final totalInfo = snapshot?['total'] as Map?;

    final periodCode = periodInfo?['periodCode']?.toString() ?? item['periodCode']?.toString() ?? 'Kỳ hiện tại';
    final fromDate = periodInfo?['fromDate']?.toString() ?? item['fromDate']?.toString() ?? '';
    final toDate = periodInfo?['toDate']?.toString() ?? item['toDate']?.toString() ?? '';
    final paymentDate = periodInfo?['paymentDate']?.toString() ?? item['issuedAt']?.toString() ?? '';
    final payslipNo = item['payslipNo']?.toString() ?? 'PL-${item['id'] ?? '001'}';
    final status = item['status']?.toString() ?? 'PAID';

    final netSalary = totalInfo?['net_salary'] ?? item['netSalary'] ?? item['net_salary'] ?? 0;
    final grossSalary = totalInfo?['gross_salary'] ?? item['baseSalary'] ?? item['base_salary'] ?? 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header (Mã phiếu lương & Badge Trạng thái)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payslipNo,
                        style: AppTextStyles.h3.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kỳ $periodCode (${Formatters.formatDate(fromDate)} - ${Formatters.formatDate(toDate)})',
                        style: AppTextStyles.caption.copyWith(color: AppColors.slate500),
                      ),
                    ],
                  ),
                ],
              ),
              AppStatusBadge(status: status, customLabel: status == 'PAID' ? 'ĐÃ CHI TRẢ' : 'CHỜ DUYỆT'),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Row 2: Gross & Net Breakdown
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TỔNG THU NHẬP (GROSS)', style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.formatCurrency(grossSalary),
                      style: AppTextStyles.h3.copyWith(fontSize: 14, color: AppColors.slate800),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THỰC LĨNH (NET)', style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.formatCurrency(netSalary),
                      style: AppTextStyles.h2.copyWith(fontSize: 16, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 3: Action Buttons (Xem bảng kê + Xuất PDF)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HrmPayslipModals.showPayslipBreakdownSheet(
                      context,
                      item,
                      profile: {
                        'fullName': userName,
                        'code': employeeCode,
                        'department': department,
                        'position': position,
                      },
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('Xem bảng kê', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.slate700,
                    side: const BorderSide(color: AppColors.slate300),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  PdfExportService.exportPayslipPdf(
                    payslip: item,
                    employeeName: userName,
                    employeeCode: employeeCode,
                    department: department,
                    position: position,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 15, color: AppColors.primary),
                label: const Text('In PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
