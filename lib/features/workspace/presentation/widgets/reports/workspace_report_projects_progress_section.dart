import 'package:flutter/material.dart';
import '../../../domain/models/workspace_report_models.dart';

/// Bảng Tiến độ dự án
/// Đồng bộ 1:1 với Web React `reports-view.tsx`
class WorkspaceReportProjectsProgressSection extends StatefulWidget {
  final List<ProjectProgressRow> projects;
  final void Function(String title, String kind, {Map<String, String>? extra}) onDrillDown;

  const WorkspaceReportProjectsProgressSection({
    super.key,
    required this.projects,
    required this.onDrillDown,
  });

  @override
  State<WorkspaceReportProjectsProgressSection> createState() =>
      _WorkspaceReportProjectsProgressSectionState();
}

class _WorkspaceReportProjectsProgressSectionState
    extends State<WorkspaceReportProjectsProgressSection> {
  static const int _pageSize = 10;
  int _page = 1;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'running':
        return const Color(0xFF2563EB);
      case 'planning':
        return const Color(0xFF64748B);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'archived':
      case 'cancelled':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'running':
        return 'Đang chạy';
      case 'planning':
        return 'Lập kế hoạch';
      case 'completed':
        return 'Hoàn thành';
      case 'archived':
        return 'Lưu trữ';
      case 'cancelled':
        return 'Đã huỷ';
      default:
        return status;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
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

  @override
  Widget build(BuildContext context) {
    final list = widget.projects;
    if (list.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('Chưa có dự án nào trong phạm vi.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
      );
    }

    final totalPages = ((list.length - 1) / _pageSize).floor() + 1;
    final startIndex = (_page - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, list.length);
    final pageItems = list.sublist(startIndex, endIndex);

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
          const Text(
            'Tiến độ dự án',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 50,
              horizontalMargin: 8,
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('MÃ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('DỰ ÁN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('TIẾN ĐỘ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('VIỆC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('QUÁ HẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('KỲ HẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              ],
              rows: pageItems.map((row) {
                final statusColor = _getStatusColor(row.status);

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        row.projectCode,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          row.projectName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStatusLabel(row.status),
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 50,
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
                    DataCell(Text('${row.closedItems}/${row.totalItems}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
                    DataCell(
                      _buildClickableCount(
                        row.overdueItems,
                        () => widget.onDrillDown('Việc quá hạn · ${row.projectCode}', 'overdue', extra: {'projectIds': row.projectId}),
                        isDanger: true,
                      ),
                    ),
                    DataCell(
                      Text(
                        '${_formatDate(row.startDate)} → ${_formatDate(row.endDate)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Paging controls
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${startIndex + 1}–$endIndex / ${list.length}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _page > 1 ? () => setState(() => _page--) : null,
              ),
              Text(
                '$_page / $totalPages',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _page < totalPages ? () => setState(() => _page++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
