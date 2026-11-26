import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/workspace_report_models.dart';

/// Khối biểu đồ Xu hướng, Phân bố trạng thái và Mức độ ưu tiên
/// Đồng bộ 1:1 với Web React `report-charts.tsx`
class WorkspaceReportChartsSection extends StatelessWidget {
  final ReportBundle bundle;
  final void Function(String title, String kind, {Map<String, String>? extra}) onDrillDown;

  /// Kỳ đang xem (`YYYY-MM-DD`), để cắt cột đầu/cuối chờm ra ngoài kỳ (web `pickTrend`).
  final String rangeFrom;
  final String rangeTo;

  const WorkspaceReportChartsSection({
    super.key,
    required this.bundle,
    required this.onDrillDown,
    this.rangeFrom = '',
    this.rangeTo = '',
  });

  static String _dayBefore(String day) {
    final d = DateTime.parse(day.substring(0, 10));
    final prev = d.subtract(const Duration(days: 1));
    return '${prev.year.toString().padLeft(4, '0')}-${prev.month.toString().padLeft(2, '0')}-${prev.day.toString().padLeft(2, '0')}';
  }

  static String _dmy(String day) {
    final p = day.substring(0, 10).split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : day;
  }

  /// Web `pickTrend`: mở danh sách việc của đúng loại cột (Tạo mới / Hoàn thành / Lỡ hạn) trong khoảng ngày của cột,
  /// cắt theo kỳ đang xem; ngày tính theo giờ máy, đầu ngày tới cuối ngày.
  void _pickTrend(int index, String kind, String label) {
    final buckets = bundle.trend.buckets;
    final start = buckets[index].start.substring(0, 10);
    final next = index + 1 < buckets.length ? buckets[index + 1].start.substring(0, 10) : null;
    final startDay = (rangeFrom.isNotEmpty && start.compareTo(rangeFrom) < 0) ? rangeFrom : start;
    var endDay = next != null ? _dayBefore(next) : (rangeTo.isNotEmpty ? rangeTo : start);
    if (rangeTo.isNotEmpty && endDay.compareTo(rangeTo) > 0) endDay = rangeTo;
    onDrillDown(label, kind, extra: {
      'from': DateTime.parse('${startDay}T00:00:00').toUtc().toIso8601String(),
      'to': DateTime.parse('${endDay}T23:59:59').toUtc().toIso8601String(),
      'subtitle': '${_dmy(startDay)} – ${_dmy(endDay)}',
    });
  }

  String _formatBucketDate(String ymd) {
    if (ymd.length >= 10) {
      final parts = ymd.substring(0, 10).split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}';
      }
    }
    return ymd;
  }

  Color _getStatusColor(String key) {
    switch (key.toLowerCase()) {
      case 'todo':
        return const Color(0xFF64748B);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'blocked':
        return const Color(0xFFEF4444);
      case 'review':
        return const Color(0xFFF59E0B);
      case 'done':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFCBD5E1);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _getStatusLabel(String key) {
    switch (key.toLowerCase()) {
      case 'todo':
        return 'Chưa làm';
      case 'in_progress':
        return 'Đang làm';
      case 'blocked':
        return 'Vướng mắc';
      case 'review':
        return 'Chờ duyệt';
      case 'done':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã huỷ';
      default:
        return key;
    }
  }

  Color _getPriorityColor(String key) {
    switch (key.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFEA580C);
      case 'normal':
        return const Color(0xFF2563EB);
      case 'low':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getPriorityLabel(String key) {
    switch (key.toLowerCase()) {
      case 'urgent':
        return 'Khẩn cấp';
      case 'high':
        return 'Cao';
      case 'normal':
        return 'Bình thường';
      case 'low':
        return 'Thấp';
      default:
        return key;
    }
  }

  Widget _buildTrendChart() {
    final buckets = bundle.trend.buckets;
    if (buckets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('Chưa có dữ liệu xu hướng', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
      );
    }

    int maxVal = 1;
    for (final b in buckets) {
      if (b.created > maxVal) maxVal = b.created;
      if (b.completed > maxVal) maxVal = b.completed;
      if (b.missedDeadline > maxVal) maxVal = b.missedDeadline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chú thích
        Row(
          children: [
            _buildLegendItem('Tạo mới', const Color(0xFF38BDF8)),
            const SizedBox(width: 12),
            _buildLegendItem('Hoàn thành', const Color(0xFF10B981)),
            const SizedBox(width: 12),
            _buildLegendItem('Lỡ hạn', const Color(0xFFF87171)),
          ],
        ),
        const SizedBox(height: 14),

        // Biểu đồ cột
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: buckets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final b = buckets[index];
              final dateLabel = _formatBucketDate(b.start);

              // Ngày chỉ có một loại có số: bấm chỗ nào trong ngày (kể cả nhãn ngày) cũng mở loại đó.
              final picks = <VoidCallback>[
                if (b.created > 0) () => _pickTrend(index, 'created', 'workspace.report.trend_created'.tr()),
                if (b.completed > 0) () => _pickTrend(index, 'completed', 'workspace.report.trend_completed'.tr()),
                if (b.missedDeadline > 0)
                  () => _pickTrend(index, 'missedDeadline', 'workspace.report.trend_missed'.tr()),
              ];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: picks.length == 1 ? picks.first : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Cột Tạo mới, Hoàn thành, Lỡ hạn
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBar(b.created, maxVal, const Color(0xFF38BDF8),
                              () => _pickTrend(index, 'created', 'workspace.report.trend_created'.tr())),
                          _buildBar(b.completed, maxVal, const Color(0xFF10B981),
                              () => _pickTrend(index, 'completed', 'workspace.report.trend_completed'.tr())),
                          _buildBar(b.missedDeadline, maxVal, const Color(0xFFF87171),
                              () => _pickTrend(index, 'missedDeadline', 'workspace.report.trend_missed'.tr())),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateLabel,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Một cột; bấm được khi có giá trị (web: `value > 0 && onPick`). Vùng bấm là cả dải dọc của cột (cao bằng biểu đồ,
  /// rộng hơn thanh màu) để cột thấp vẫn dễ bấm.
  Widget _buildBar(int value, int max, Color color, VoidCallback onTap) {
    const maxHeight = 100.0;
    final h = value > 0 ? (value / max * maxHeight).clamp(4.0, maxHeight) : 0.0;
    final bar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value > 0)
          Text(
            '$value',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
          ),
        Container(
          width: 9,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ],
    );
    final lane = SizedBox(
      width: 13,
      height: maxHeight + 14,
      child: Align(alignment: Alignment.bottomCenter, child: bar),
    );
    if (value <= 0) return lane;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: lane);
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
      ],
    );
  }

  Widget _buildStatusChip({
    required String label,
    required int count,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final statusList = bundle.statusBreakdown;
    final total = statusList.fold<int>(0, (sum, item) => sum + item.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tổng số việc
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$total việc',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Thanh tiến trình ngang tổng hợp các màu
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: statusList.where((s) => s.count > 0).map((s) {
                  final flex = ((s.count / total) * 1000).toInt();
                  return Expanded(
                    flex: flex > 0 ? flex : 1,
                    child: Container(color: _getStatusColor(s.key)),
                  );
                }).toList(),
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Các tab con chọn nhanh trạng thái
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatusChip(
                label: 'Tất cả',
                count: total,
                onTap: () => onDrillDown(
                  'Tất cả công việc',
                  'all',
                  extra: {'statusScope': 'true'},
                ),
              ),
              const SizedBox(width: 6),
              ...statusList.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildStatusChip(
                    label: _getStatusLabel(s.key),
                    count: s.count,
                    color: _getStatusColor(s.key),
                    onTap: () => onDrillDown(
                      'Việc ${_getStatusLabel(s.key).toLowerCase()}',
                      'all',
                      extra: {'status': s.key, 'statusScope': 'true'},
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Danh sách trạng thái
        ...statusList.map((s) {
          final count = s.count;
          final pct = total > 0 ? ((count / total) * 100).round() : 0;
          final color = _getStatusColor(s.key);

          return InkWell(
            onTap: () => onDrillDown(
              'Việc ${_getStatusLabel(s.key).toLowerCase()}',
              'all',
              extra: {'status': s.key, 'statusScope': 'true'},
            ),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getStatusLabel(s.key),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                  Text(
                    '$count',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPrioritySection() {
    final priorities = bundle.priorityBreakdown;
    final total = priorities.fold<int>(0, (sum, item) => sum + item.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: priorities.map((p) {
        final count = p.count;
        final color = _getPriorityColor(p.key);
        final ratio = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

        return InkWell(
          onTap: () => onDrillDown(
            'Việc đang mở · ưu tiên ${_getPriorityLabel(p.key).toLowerCase()}',
            'open',
            extra: {'priority': p.key},
          ),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 75,
                  child: Text(
                    _getPriorityLabel(p.key),
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCard({required String title, String? subtitle, required Widget child}) {
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
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (subtitle != null) ...[
                const Spacer(),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Xu hướng
        _buildCard(
          title: 'Xu hướng',
          subtitle: 'Bấm cột để xem danh sách',
          child: _buildTrendChart(),
        ),

        // 2. Công việc theo trạng thái
        _buildCard(
          title: 'Công việc theo trạng thái',
          child: _buildStatusSection(),
        ),

        // 3. Việc đang mở theo độ ưu tiên
        _buildCard(
          title: 'Việc đang mở theo độ ưu tiên',
          child: _buildPrioritySection(),
        ),
      ],
    );
  }
}
