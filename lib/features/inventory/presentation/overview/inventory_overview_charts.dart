import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import 'inventory_overview_format.dart';

class OverviewChartSlice {
  final String label;
  final double value;
  const OverviewChartSlice(this.label, this.value);
}

/// Bảng màu chung của web `charts.tsx` (`PALETTE`), xoay vòng theo thứ tự.
const List<Color> _palette = [
  Color(0xFF2F6FED),
  Color(0xFF16845E),
  Color(0xFFE0A83A),
  Color(0xFFB23B3B),
  Color(0xFF7B5EA7),
  Color(0xFF3AA0A8),
  Color(0xFF8494A8),
];

Color _colorAt(int i) => _palette[i % _palette.length];

Widget _emptyHint(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
    );

/// Biểu đồ tròn (web `DonutChart`): tỉ trọng từng phần + tổng ở giữa.
class InventoryDonutChart extends StatelessWidget {
  final List<OverviewChartSlice> slices;
  final String unit;
  final String emptyHint;

  const InventoryDonutChart({super.key, required this.slices, required this.unit, required this.emptyHint});

  @override
  Widget build(BuildContext context) {
    final visible = slices.where((s) => s.value > 0).toList();
    final total = visible.fold<double>(0, (sum, s) => sum + s.value);
    if (visible.isEmpty || total <= 0) return _emptyHint(emptyHint);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutPainter(visible.map((s) => s.value).toList(), total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    InventoryOverviewFormat.quantity(total),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate900),
                  ),
                  Text(unit, style: const TextStyle(fontSize: 10.5, color: AppColors.slate500)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < visible.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: _colorAt(i), borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          visible[i].label,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.slate700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${InventoryOverviewFormat.quantity(visible[i].value)} · ${(visible[i].value / total * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final double total;
  _DonutPainter(this.values, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      final paint = Paint()
        ..color = _colorAt(i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.values != values || old.total != total;
}

/// Biểu đồ cột ngang (web `BarChart`): bỏ giá trị ≤ 0, xếp giảm dần, tối đa [max] cột,
/// phần còn lại gộp vào một cột "Khác".
class InventoryBarChart extends StatelessWidget {
  final List<OverviewChartSlice> slices;
  final String emptyHint;
  final int max;

  const InventoryBarChart({super.key, required this.slices, required this.emptyHint, this.max = 6});

  @override
  Widget build(BuildContext context) {
    final all = slices.where((s) => s.value.isFinite && s.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (all.isEmpty) return _emptyHint(emptyHint);
    final rest = all.skip(max).toList();
    final bars = [
      ...all.take(max),
      if (rest.isNotEmpty)
        OverviewChartSlice(
          'inventory.overview.chart.other'.tr(),
          rest.fold<double>(0, (sum, s) => sum + s.value),
        ),
    ];
    final maxValue = bars.fold<double>(0, (m, s) => math.max(m, s.value));
    return Column(
      children: [
        for (var i = 0; i < bars.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bars[i].label,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.slate700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      InventoryOverviewFormat.quantity(bars[i].value),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate900),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, c) {
                    final ratio = maxValue > 0 ? (bars[i].value / maxValue).clamp(0.0, 1.0) : 0.0;
                    return Stack(
                      children: [
                        Container(
                          height: 8,
                          width: c.maxWidth,
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: c.maxWidth * ratio,
                          decoration: BoxDecoration(
                            color: _colorAt(i),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
