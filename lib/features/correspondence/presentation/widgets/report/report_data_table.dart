import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';

/// Bảng dữ liệu phân tích Báo cáo (Theo loại văn bản / Theo phòng ban) khớp 1:1 với Web
class ReportDataTable extends StatelessWidget {
  final String title;
  final List<CorrespondenceReportRow> rows;

  const ReportDataTable({
    super.key,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final columnTitle = title.replaceAll('Theo ', '').trim();

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
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Table Content
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'correspondence.report.no_data'.tr(),
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 460),
                child: DataTable(
                  horizontalMargin: 12,
                  columnSpacing: 18,
                  headingRowHeight: 38,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 44,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: [
                    DataColumn(
                      label: Text(
                        columnTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'correspondence.report.col_incoming'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'correspondence.report.col_outgoing'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'correspondence.report.col_done'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'correspondence.report.col_late'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                  rows: rows.map((row) {
                    final hasLate = row.late > 0;
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            row.label,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${row.incoming}',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${row.outgoing}',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${row.completed}',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                          ),
                        ),
                        DataCell(
                          hasLate
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${row.late}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                )
                              : Text(
                                  '${row.late}',
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
