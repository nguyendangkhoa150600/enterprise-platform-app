import 'package:flutter/material.dart';
import '../../../domain/models/workspace_report_models.dart';

/// Bảng Hiệu suất theo người phụ trách
/// Đồng bộ 1:1 với Web React `reports-view.tsx`
class WorkspaceReportPerformanceSection extends StatefulWidget {
  final List<PerformanceRow> performance;
  final Map<String, String> userNames;
  final void Function(String title, String kind, {Map<String, String>? extra}) onDrillDown;

  const WorkspaceReportPerformanceSection({
    super.key,
    required this.performance,
    required this.userNames,
    required this.onDrillDown,
  });

  @override
  State<WorkspaceReportPerformanceSection> createState() => _WorkspaceReportPerformanceSectionState();
}

class _WorkspaceReportPerformanceSectionState extends State<WorkspaceReportPerformanceSection> {
  static const int _pageSize = 10;
  int _page = 1;

  String _nameOf(String userId) {
    return widget.userNames[userId] ?? userId;
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
    final list = widget.performance;
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
          child: Text('Chưa có ai có việc trong kỳ.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
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
          // Tiêu đề
          const Row(
            children: [
              Text(
                'Hiệu suất theo người',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Spacer(),
              Text(
                'Tính theo người phụ trách',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bảng cuộn ngang
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 48,
              horizontalMargin: 8,
              columnSpacing: 18,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('NGƯỜI PHỤ TRÁCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('HOÀN THÀNH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('ĐÚNG HẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('TRỄ HẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('TỈ LỆ ĐÚNG HẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('TRỄ TB', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('GIỜ ĐÃ XONG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('ĐANG MỞ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('QUÁ HẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              ],
              rows: pageItems.map((row) {
                final name = _nameOf(row.userId);
                final rate = row.completedItems > 0
                    ? ((row.completedOnTime / row.completedItems) * 100).round()
                    : null;

                return DataRow(
                  cells: [
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      _buildClickableCount(
                        row.completedItems,
                        () => widget.onDrillDown('Hoàn thành · $name', 'completed', extra: {'assigneeUserId': row.userId}),
                      ),
                    ),
                    DataCell(
                      _buildClickableCount(
                        row.completedOnTime,
                        () => widget.onDrillDown('Hoàn thành đúng hạn · $name', 'completedOnTime', extra: {'assigneeUserId': row.userId}),
                      ),
                    ),
                    DataCell(
                      _buildClickableCount(
                        row.completedLate,
                        () => widget.onDrillDown('Hoàn thành trễ hạn · $name', 'completedLate', extra: {'assigneeUserId': row.userId}),
                        isDanger: true,
                      ),
                    ),
                    DataCell(
                      rate == null
                          ? const Text('—', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: rate / 100,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        rate >= 80 ? const Color(0xFF2563EB) : const Color(0xFFEA580C),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('$rate%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              ],
                            ),
                    ),
                    DataCell(
                      Text(
                        row.averageDaysLate > 0 ? '${row.averageDaysLate} ngày' : '—',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                    DataCell(
                      Text(
                        row.completedHours.toStringAsFixed(row.completedHours.truncateToDouble() == row.completedHours ? 0 : 1),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                    ),
                    DataCell(
                      _buildClickableCount(
                        row.openItems,
                        () => widget.onDrillDown('Việc đang mở · $name', 'open', extra: {'assigneeUserId': row.userId}),
                      ),
                    ),
                    DataCell(
                      _buildClickableCount(
                        row.overdueItems,
                        () => widget.onDrillDown('Việc quá hạn · $name', 'overdue', extra: {'assigneeUserId': row.userId}),
                        isDanger: true,
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
