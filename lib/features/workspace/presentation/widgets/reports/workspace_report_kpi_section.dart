import 'package:flutter/material.dart';
import '../../../domain/models/workspace_report_models.dart';

/// Khối thẻ chỉ số KPI & Tóm tắt phạm vi
/// Đồng bộ 1:1 với Web React `reports-view.tsx`
class WorkspaceReportKpiSection extends StatelessWidget {
  final ReportBundle bundle;
  final void Function(String title, String kind, {Map<String, String>? extra}) onDrillDown;

  const WorkspaceReportKpiSection({
    super.key,
    required this.bundle,
    required this.onDrillDown,
  });

  String _formatDisplayDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildSummaryText() {
    final scopeLevel = bundle.scope.level == 'tenant'
        ? 'Toàn bộ tenant'
        : bundle.scope.level == 'managed'
            ? 'Các dự án bạn phụ trách'
            : 'Số liệu của riêng bạn';

    final prevFrom = _formatDisplayDate(bundle.previous.from);
    final prevTo = _formatDisplayDate(bundle.previous.to);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$scopeLevel · ${bundle.scope.projectCount} dự án · so với kỳ trước $prevFrom – $prevTo\n'
          'Của tôi: ${bundle.mine.openItems} đang mở, ${bundle.mine.overdueItems} quá hạn, ${bundle.mine.completedInPeriod} xong trong kỳ',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    String? deltaText,
    Color? deltaColor,
    String? hint,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDanger ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          ),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDanger ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                  ),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
                ],
              ],
            ),
            const SizedBox(height: 4),
            if (deltaText != null)
              Text(
                deltaText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: deltaColor ?? const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else if (hint != null)
              Text(
                hint,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kpis = bundle.kpis;
    final prev = bundle.previous;

    // Tính delta tạo mới
    final createdDelta = kpis.createdItems - prev.createdItems;
    final createdDeltaText = createdDelta > 0
        ? '▲ +$createdDelta so với kỳ trước'
        : createdDelta < 0
            ? '▼ $createdDelta so với kỳ trước'
            : '= 0 so với kỳ trước';

    // Tính delta hoàn thành
    final completedDelta = kpis.completedItems - prev.completedItems;
    final completedDeltaText = completedDelta > 0
        ? '▲ +$completedDelta so với kỳ trước'
        : completedDelta < 0
            ? '▼ $completedDelta so với kỳ trước'
            : '= 0 so với kỳ trước';
    final completedDeltaColor = completedDelta > 0
        ? const Color(0xFF16A34A)
        : (completedDelta < 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B));

    // Tính tỉ lệ đúng hạn
    final totalCompleted = kpis.completedItems;
    final onTimeRate = totalCompleted > 0 ? ((kpis.completedOnTime / totalCompleted) * 100).round() : 100;
    final prevTotal = prev.completedItems;
    final prevRate = prevTotal > 0 ? ((prev.completedOnTime / prevTotal) * 100).round() : 100;
    final rateDelta = onTimeRate - prevRate;
    final rateDeltaText = rateDelta > 0
        ? '▲ +$rateDelta% (${kpis.completedOnTime} đúng - ${kpis.completedLate} trễ)'
        : (rateDelta < 0
            ? '▼ $rateDelta% (${kpis.completedOnTime} đúng - ${kpis.completedLate} trễ)'
            : '= 0% (${kpis.completedOnTime} đúng - ${kpis.completedLate} trễ)');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryText(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.75,
            children: [
              // 1. Việc tạo mới
              _buildKpiCard(
                label: 'Việc tạo mới',
                value: '${kpis.createdItems}',
                deltaText: createdDeltaText,
                onTap: () => onDrillDown('Việc tạo mới trong kỳ', 'created'),
              ),
              // 2. Hoàn thành
              _buildKpiCard(
                label: 'Hoàn thành',
                value: '${kpis.completedItems}',
                deltaText: completedDeltaText,
                deltaColor: completedDeltaColor,
                onTap: () => onDrillDown('Việc hoàn thành trong kỳ', 'completed'),
              ),
              // 3. Tỉ lệ đúng hạn
              _buildKpiCard(
                label: 'Tỉ lệ đúng hạn',
                value: '$onTimeRate%',
                deltaText: rateDeltaText,
                deltaColor: onTimeRate >= 80 ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                onTap: kpis.completedLate > 0
                    ? () => onDrillDown('Việc hoàn thành trễ hạn', 'completedLate')
                    : null,
              ),
              // 4. Giờ đã hoàn thành
              _buildKpiCard(
                label: 'Giờ đã hoàn thành',
                value: kpis.completedHours.toStringAsFixed(kpis.completedHours.truncateToDouble() == kpis.completedHours ? 0 : 1),
                hint: 'Theo giờ ước lượng',
              ),
              // 5. Đang mở
              _buildKpiCard(
                label: 'Đang mở',
                value: '${kpis.openItems}',
                hint: 'Tại hôm nay',
                onTap: () => onDrillDown('Việc đang mở', 'open'),
              ),
              // 6. Quá hạn
              _buildKpiCard(
                label: 'Quá hạn',
                value: '${kpis.overdueItems}',
                hint: 'Tại hôm nay',
                isDanger: kpis.overdueItems > 0,
                onTap: () => onDrillDown('Việc quá hạn', 'overdue'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
