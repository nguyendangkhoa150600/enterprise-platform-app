import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/dashboard/crm_dashboard_models.dart';
import '../common/crm_format.dart';
import '../common/crm_ui.dart';
import 'crm_dashboard_model.dart';

/// Màu hai chuỗi của biểu đồ xu hướng (web `REVENUE_COLOR`, `ORDERS_COLOR`).
const Color _revenueColor = Color(0xFF3B82F6);
const Color _ordersColor = Color(0xFFF59E0B);
const double _chartHeight = 180;

/// Màu thanh theo thứ tự giai đoạn, nhạt tới đậm (web `STAGE_SHADES`).
const List<Color> _stageShades = [
  Color(0xFF94A3B8),
  Color(0xFF93C5FD),
  Color(0xFF60A5FA),
  Color(0xFF3B82F6),
  Color(0xFF1D4ED8),
];

/// Web `stageShade`.
Color crmStageShade(int index, int count) {
  if (count <= 1) return _stageShades[3];
  return _stageShades[((index / (count - 1)) * (_stageShades.length - 1)).round()];
}

/// Doanh thu (cột, trục trái) và số đơn mới (đường, trục phải) theo mốc (web `RevenueTrendChart`). Bấm một cột mở
/// trang chi tiết ([onPick]); bấm giữ xem số liệu của mốc.
class CrmRevenueTrendChart extends StatelessWidget {
  final String granularity;
  final List<CrmDashboardTrendBucket> buckets;
  final VoidCallback? onPick;

  const CrmRevenueTrendChart({super.key, required this.granularity, required this.buckets, this.onPick});

  int? _indexAt(double dx, double width) {
    if (buckets.isEmpty || width <= 0) return null;
    final i = (dx / (width / buckets.length)).floor();
    return i.clamp(0, buckets.length - 1);
  }

  void _showBucket(BuildContext context, CrmDashboardTrendBucket bucket) {
    showCrmSnack(
      context,
      'crm.dashboard.trend.tooltip'.tr(
        args: {
          'range': crmBucketRange(bucket),
          'revenue': formatCrmVndCompact(bucket.revenue),
          'orders': formatCrmCount(bucket.orders),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxRevenue = math.max(1.0, buckets.fold<double>(0, (m, b) => math.max(m, b.revenue)));
    final maxOrders = math.max(1, buckets.fold<int>(0, (m, b) => math.max(m, b.orders)));
    // Nhãn trục ngang thưa bớt khi nhiều cột (điện thoại hẹp hơn web: tối đa 6 nhãn).
    final labelEvery = math.max(1, (buckets.length / 6).ceil());
    const axisStyle = TextStyle(fontSize: 10.5, color: CrmColors.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _Legend(color: _revenueColor, label: 'crm.dashboard.trend.legend_revenue'.tr()),
            _Legend(color: _ordersColor, label: 'crm.dashboard.trend.legend_orders'.tr(), line: true),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(formatCrmVndCompact(maxRevenue), style: axisStyle),
            const Spacer(),
            Text(formatCrmCount(maxOrders), style: axisStyle),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, c) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onPick == null ? null : (_) => onPick!(),
            onLongPressStart: (d) {
              final i = _indexAt(d.localPosition.dx, c.maxWidth);
              if (i != null) _showBucket(context, buckets[i]);
            },
            child: SizedBox(
              height: _chartHeight,
              width: c.maxWidth,
              child: CustomPaint(painter: _TrendPainter(buckets, maxRevenue, maxOrders.toDouble())),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < buckets.length; i++)
              Expanded(
                child: i % labelEvery == 0
                    ? Text(
                        crmBucketLabel(buckets[i].start, granularity),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: axisStyle,
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool line;
  const _Legend({required this.color, required this.label, this.line = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: line ? 14 : 10,
        height: line ? 3 : 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11.5, color: CrmColors.body)),
    ],
  );
}

class _TrendPainter extends CustomPainter {
  final List<CrmDashboardTrendBucket> buckets;
  final double maxRevenue;
  final double maxOrders;
  _TrendPainter(this.buckets, this.maxRevenue, this.maxOrders);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final grid = Paint()
      ..color = CrmColors.border
      ..strokeWidth = 0.8;
    for (final ratio in const [0.25, 0.5, 0.75]) {
      canvas.drawLine(Offset(0, h * ratio), Offset(size.width, h * ratio), grid);
    }
    canvas.drawLine(Offset(0, h), Offset(size.width, h), grid);
    if (buckets.isEmpty) return;
    final slot = size.width / buckets.length;
    final bar = slot * 0.62;
    final usable = h - 6;
    final barPaint = Paint()..color = _revenueColor;
    for (var i = 0; i < buckets.length; i++) {
      final revenue = buckets[i].revenue;
      var height = (math.max(revenue, 0) / maxRevenue) * usable;
      if (revenue > 0 && height < 1) height = 1;
      if (height <= 0) continue;
      canvas.drawRect(Rect.fromLTWH(i * slot + (slot - bar) / 2, h - height, bar, height), barPaint);
    }
    if (buckets.length > 1) {
      final path = Path();
      for (var i = 0; i < buckets.length; i++) {
        final x = i * slot + slot / 2;
        final y = h - (buckets[i].orders / maxOrders) * usable;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _ordersColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.buckets != buckets || old.maxRevenue != maxRevenue || old.maxOrders != maxOrders;
}

/// Dự án bán hàng đang mở theo giai đoạn (web `PipelineBars`): thanh theo giá trị, kèm số dự án và giá trị theo
/// xác suất. Bấm để mở Dự án bán hàng.
class CrmPipelineBars extends StatelessWidget {
  final List<CrmDashboardStageRow> rows;
  final VoidCallback onPick;
  const CrmPipelineBars({super.key, required this.rows, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final max = math.max(1.0, rows.fold<double>(0, (m, r) => math.max(m, r.value)));
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          rows[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: CrmColors.body),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCrmVndCompact(rows[i].value),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CrmColors.text),
                          ),
                          Text(
                            'crm.dashboard.pipeline.row_hint'.tr(
                              args: {
                                'count': formatCrmCount(rows[i].count),
                                'weighted': formatCrmVndCompact(rows[i].weightedValue),
                              },
                            ),
                            style: const TextStyle(fontSize: 10.5, color: CrmColors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, c) => Stack(
                      children: [
                        Container(
                          height: 8,
                          width: c.maxWidth,
                          decoration: BoxDecoration(color: CrmColors.divider, borderRadius: BorderRadius.circular(4)),
                        ),
                        Container(
                          height: 8,
                          width: c.maxWidth * (rows[i].value / max).clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            color: crmStageShade(i, rows.length),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
