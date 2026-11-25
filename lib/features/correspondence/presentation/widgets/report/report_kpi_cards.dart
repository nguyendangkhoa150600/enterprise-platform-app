import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';

/// 5 thẻ KPI thống kê Báo cáo Văn thư (khớp 1:1 với Web)
class ReportKpiCards extends StatelessWidget {
  final CorrespondenceReportTotals totals;

  const ReportKpiCards({
    super.key,
    required this.totals,
  });

  @override
  Widget build(BuildContext context) {
    // Tone khớp 1:1 với Web:
    // Mặc định: border-left #2563eb (Blue 600)
    // stat-success: border-left #16a34a (Green 600)
    // stat-danger: border-left #dc2626 (Red 600)
    final items = [
      {
        'label': 'correspondence.report.kpi_incoming'.tr(),
        'value': totals.incoming,
        'borderColor': const Color(0xFF2563EB),
        'valueColor': const Color(0xFF0F172A),
      },
      {
        'label': 'correspondence.report.kpi_outgoing'.tr(),
        'value': totals.outgoing,
        'borderColor': const Color(0xFF2563EB),
        'valueColor': const Color(0xFF0F172A),
      },
      {
        'label': 'correspondence.report.kpi_completed'.tr(),
        'value': totals.completed,
        'borderColor': const Color(0xFF16A34A),
        'valueColor': const Color(0xFF0F172A),
      },
      {
        'label': 'correspondence.report.kpi_open'.tr(),
        'value': totals.open,
        'borderColor': const Color(0xFF2563EB),
        'valueColor': const Color(0xFF0F172A),
      },
      {
        'label': 'correspondence.report.kpi_late'.tr(),
        'value': totals.late,
        'borderColor': const Color(0xFFDC2626),
        'valueColor': const Color(0xFF0F172A),
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final borderColor = item['borderColor'] as Color;
          final valueColor = item['valueColor'] as Color;
          final value = item['value'] as int;
          final label = item['label'] as String;

          return Container(
            width: 145,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Viền màu bên trái khớp Web (border-left: 4px solid)
                    Container(
                      width: 4.5,
                      color: borderColor,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$value',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: valueColor,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
