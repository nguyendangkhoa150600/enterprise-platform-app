import 'package:flutter/material.dart';
import '../../../domain/models/workspace_report_models.dart';

/// Thẻ gom Theo nhóm dự án, Theo nhãn dự án và Khối tài chính
/// Đồng bộ 1:1 với Web React `reports-view.tsx`
class WorkspaceReportGroupsSection extends StatelessWidget {
  final ReportBundle bundle;
  final void Function(String title, String kind, {Map<String, String>? extra}) onDrillDown;

  const WorkspaceReportGroupsSection({
    super.key,
    required this.bundle,
    required this.onDrillDown,
  });

  String _formatVndCompact(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} tỷ';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} tr';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildClickableCount(int count, VoidCallback? onTap, {bool isDanger = false}) {
    if (count <= 0) {
      return const Text('0', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)));
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDanger ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupTable(String title, List<ReportGroupRow> rows, String filterType) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 46,
              horizontalMargin: 8,
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: [
                DataColumn(label: Text(filterType == 'group' ? 'NHÓM DỰ ÁN' : 'NHÃN', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                const DataColumn(label: Text('DỰ ÁN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                const DataColumn(label: Text('TIẾN ĐỘ TB', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                const DataColumn(label: Text('ĐANG MỞ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                const DataColumn(label: Text('QUÁ HẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                const DataColumn(label: Text('XONG TRONG KỲ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              ],
              rows: rows.map((row) {
                final extra = filterType == 'group'
                    ? {'groups': row.key}
                    : {'tagIds': row.key};

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (row.color != null && row.color!.isNotEmpty) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(int.parse(row.color!.replaceAll('#', '0xFF'))),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              row.label,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text('${row.projectCount}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 45,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: row.progressPercent / 100,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  row.progressPercent >= 80 ? const Color(0xFF2563EB) : const Color(0xFFEA580C),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${row.progressPercent}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        ],
                      ),
                    ),
                    DataCell(_buildClickableCount(row.openItems, () => onDrillDown('Việc đang mở · ${row.label}', 'open', extra: extra))),
                    DataCell(_buildClickableCount(row.overdueItems, () => onDrillDown('Việc quá hạn · ${row.label}', 'overdue', extra: extra), isDanger: true)),
                    DataCell(_buildClickableCount(row.completedInPeriod, () => onDrillDown('Hoàn thành · ${row.label}', 'completed', extra: extra))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceCard() {
    final fin = bundle.finance;
    if (fin == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tài chính các dự án trong phạm vi',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          Text(
            _formatVndCompact(fin.contractValue),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tổng giá trị hợp đồng',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thu chi thực tế xem ở tab Tài chính của từng dự án, và báo cáo thu chi theo dự án ở module Tài chính.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroupTable('Theo nhóm dự án', bundle.byGroup, 'group'),
        _buildGroupTable('Theo nhãn dự án', bundle.byTag, 'tag'),
        _buildFinanceCard(),
      ],
    );
  }
}
