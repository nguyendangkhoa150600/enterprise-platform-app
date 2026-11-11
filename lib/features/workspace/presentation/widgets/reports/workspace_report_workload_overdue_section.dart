import 'package:flutter/material.dart';
import '../../../domain/models/workspace_report_models.dart';

/// Bảng Tải công việc (Workload) và Danh sách Công việc quá hạn (Overdue)
/// Đồng bộ 1:1 với Web React `reports-view.tsx`
class WorkspaceReportWorkloadOverdueSection extends StatefulWidget {
  final List<WorkloadRow> workload;
  final List<OverdueRow> overdue;
  final Map<String, String> userNames;
  final void Function(String title, String kind, {Map<String, String>? extra}) onDrillDown;

  const WorkspaceReportWorkloadOverdueSection({
    super.key,
    required this.workload,
    required this.overdue,
    required this.userNames,
    required this.onDrillDown,
  });

  @override
  State<WorkspaceReportWorkloadOverdueSection> createState() =>
      _WorkspaceReportWorkloadOverdueSectionState();
}

class _WorkspaceReportWorkloadOverdueSectionState
    extends State<WorkspaceReportWorkloadOverdueSection> {
  static const int _pageSize = 10;
  int _workloadPage = 1;
  int _overduePage = 1;

  String _nameOf(String? userId) {
    if (userId == null || userId.isEmpty) return '—';
    return widget.userNames[userId] ?? userId;
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '—';
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

  Widget _buildWorkloadCard() {
    final list = widget.workload;
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
          child: Text('Không có việc nào đang mở trong phạm vi.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
      );
    }

    int workloadMax = 1;
    for (final r in list) {
      if (r.openItems > workloadMax) workloadMax = r.openItems;
    }

    final totalPages = ((list.length - 1) / _pageSize).floor() + 1;
    final startIndex = (_workloadPage - 1) * _pageSize;
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
            'Tải công việc',
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
              columnSpacing: 18,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('NGƯỜI PHỤ TRÁCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('ĐANG MỞ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('QUÁ HẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('ĐẾN HẠN TRONG TUẦN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('GIỜ ƯỚC LƯỢNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              ],
              rows: pageItems.map((row) {
                final name = _nameOf(row.userId);
                final ratio = (row.openItems / workloadMax).clamp(0.0, 1.0);

                return DataRow(
                  cells: [
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildClickableCount(
                            row.openItems,
                            () => widget.onDrillDown('Việc đang mở · $name', 'open', extra: {'assigneeUserId': row.userId}),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      _buildClickableCount(
                        row.overdueItems,
                        () => widget.onDrillDown('Việc quá hạn · $name', 'overdue', extra: {'assigneeUserId': row.userId}),
                        isDanger: true,
                      ),
                    ),
                    DataCell(
                      _buildClickableCount(
                        row.dueThisWeek,
                        () => widget.onDrillDown('Đến hạn trong tuần · $name', 'dueThisWeek', extra: {'assigneeUserId': row.userId}),
                      ),
                    ),
                    DataCell(
                      Text(
                        row.estimatedHours.toStringAsFixed(row.estimatedHours.truncateToDouble() == row.estimatedHours ? 0 : 1),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Pager
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
                onPressed: _workloadPage > 1 ? () => setState(() => _workloadPage--) : null,
              ),
              Text(
                '$_workloadPage / $totalPages',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _workloadPage < totalPages ? () => setState(() => _workloadPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueCard() {
    final list = widget.overdue;
    if (list.isEmpty) return const SizedBox.shrink();

    final totalPages = ((list.length - 1) / _pageSize).floor() + 1;
    final startIndex = (_overduePage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, list.length);
    final pageItems = list.sublist(startIndex, endIndex);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
              const SizedBox(width: 6),
              const Text(
                'Công việc quá hạn',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
              ),
              const Spacer(),
              Text(
                '${list.length} công việc',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
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
              headingRowColor: WidgetStateProperty.all(const Color(0xFFFEF2F2)),
              columns: const [
                DataColumn(label: Text('MÃ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                DataColumn(label: Text('CÔNG VIỆC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                DataColumn(label: Text('DỰ ÁN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                DataColumn(label: Text('NGƯỜI PHỤ TRÁCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                DataColumn(label: Text('HẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                DataColumn(label: Text('TRỄ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
              ],
              rows: pageItems.map((row) {
                return DataRow(
                  cells: [
                    DataCell(Text(row.code, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          row.title,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(row.projectCode, style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB)))),
                    DataCell(Text(_nameOf(row.assigneeUserId), style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
                    DataCell(Text(_formatDate(row.plannedEnd), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)))),
                    DataCell(
                      Text(
                        '${row.daysLate} ngày',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          row.status == 'blocked' ? 'Vướng mắc' : (row.status == 'in_progress' ? 'Đang làm' : 'Chưa làm'),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Pager
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
                onPressed: _overduePage > 1 ? () => setState(() => _overduePage--) : null,
              ),
              Text(
                '$_overduePage / $totalPages',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _overduePage < totalPages ? () => setState(() => _overduePage++) : null,
              ),
            ],
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
        _buildWorkloadCard(),
        _buildOverdueCard(),
      ],
    );
  }
}
