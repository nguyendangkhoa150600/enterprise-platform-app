import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';

/// Top Summary Metric Banner for Income and Total Net Earnings
class PayrollMetricHeader extends StatelessWidget {
  final num totalGross;
  final num totalNet;
  final num totalDeductions;
  final num totalTax;
  final int selectedYear;
  final Function(int) onYearChanged;

  const PayrollMetricHeader({
    super.key,
    required this.totalGross,
    required this.totalNet,
    required this.totalDeductions,
    required this.totalTax,
    required this.selectedYear,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkNavy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Year Picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TỔNG THU NHẬP NĂM $selectedYear',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.slate400,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.formatCurrency(totalNet),
                    style: AppTextStyles.h1.copyWith(
                      color: AppColors.emerald,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.slate800,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slate700),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedYear,
                    dropdownColor: AppColors.slate800,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    items: [2024, 2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (val) {
                      if (val != null) onYearChanged(val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.slate800),
          const SizedBox(height: 14),

          // Sub metrics (Gross, Khấu trừ BHXH, Thuế TNCN)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSubMetric('Tổng Gross', Formatters.formatCurrency(totalGross)),
              _buildSubMetric('Khấu trừ BHXH', Formatters.formatCurrency(totalDeductions)),
              _buildSubMetric('Thuế TNCN', Formatters.formatCurrency(totalTax)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.slate400)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
