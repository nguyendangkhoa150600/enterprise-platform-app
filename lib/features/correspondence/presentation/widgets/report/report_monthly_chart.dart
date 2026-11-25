import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';

/// Biểu đồ phân bổ công văn đến và đi theo từng tháng (T1 - T12)
class ReportMonthlyChart extends StatelessWidget {
  final List<CorrespondenceReportRow> byMonth;
  final int year;

  const ReportMonthlyChart({
    super.key,
    required this.byMonth,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    // Tìm giá trị max để scale tỷ lệ
    int maxTotal = 1;
    for (final row in byMonth) {
      final total = row.incoming + row.outgoing;
      if (total > maxTotal) maxTotal = total;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'correspondence.report.chart.title'.tr(),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  _buildLegendItem(const Color(0xFF2563EB), 'correspondence.report.chart.legend_incoming'.tr()),
                  const SizedBox(width: 12),
                  _buildLegendItem(const Color(0xFFF59E0B), 'correspondence.report.chart.legend_outgoing'.tr()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 12 Tháng Bars
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (index) {
                final row = index < byMonth.length
                    ? byMonth[index]
                    : CorrespondenceReportRow(label: 'correspondence.report.chart.month_short'.tr(args: {'month': index + 1}));

                final incomingHeight = maxTotal > 0 ? (row.incoming / maxTotal) * 110 : 0.0;
                final outgoingHeight = maxTotal > 0 ? (row.outgoing / maxTotal) * 110 : 0.0;

                return Expanded(
                  child: Tooltip(
                    message: 'correspondence.report.chart.tooltip'.tr(args: {'label': row.label, 'incoming': row.incoming, 'outgoing': row.outgoing}),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Stacked Bar Container
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Đến (Blue) nằm ở trên (khớp 1:1 với Web flex-direction: column-reverse)
                                if (incomingHeight > 0)
                                  Container(
                                    width: double.infinity,
                                    height: max(incomingHeight, 3.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: outgoingHeight > 0
                                          ? const BorderRadius.vertical(top: Radius.circular(3))
                                          : BorderRadius.circular(3),
                                    ),
                                  ),
                                // Đi (Amber) nằm ở dưới
                                if (outgoingHeight > 0)
                                  Container(
                                    width: double.infinity,
                                    height: max(outgoingHeight, 3.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B),
                                      borderRadius: incomingHeight > 0
                                          ? const BorderRadius.vertical(bottom: Radius.circular(3))
                                          : BorderRadius.circular(3),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Month Label
                          Text(
                            'correspondence.report.chart.month_short'.tr(args: {'month': index + 1}),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: (row.incoming > 0 || row.outgoing > 0)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: (row.incoming > 0 || row.outgoing > 0)
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
