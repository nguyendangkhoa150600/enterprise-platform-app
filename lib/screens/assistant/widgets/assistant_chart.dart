import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/i18n/app_i18n.dart';

const List<Color> _palette = [
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF06B6D4),
  Color(0xFF84CC16),
];

/// Biểu đồ trong câu trả lời (khối ```chart của web, `Nme`): `[{name, <series>: số...}]` hoặc
/// `{title, type, data}`; type: auto | line | area | bar | grouped_bar | stacked_bar | radar | pie | composed.
/// Hàng có `name` chứa "Dự đoán" vẽ nét đứt nối tiếp số liệu thật (line/area).
class AssistantChart extends StatelessWidget {
  final dynamic config;
  const AssistantChart({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> rows = const [];
    String? title;
    var type = 'auto';
    final c = config;
    if (c is List) {
      rows = [for (final r in c) if (r is Map) Map<String, dynamic>.from(r)];
    } else if (c is Map) {
      rows = [for (final r in (c['data'] as List? ?? const [])) if (r is Map) Map<String, dynamic>.from(r)];
      title = c['title']?.toString();
      type = c['type']?.toString() ?? 'auto';
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final keys = rows.first.keys.where((k) => k != 'name').toList();
    if (keys.isEmpty) return const SizedBox.shrink();
    if (type == 'auto') type = rows.length > 1 ? 'line' : 'bar';
    final names = [for (final r in rows) r['name']?.toString() ?? ''];
    double v(Map<String, dynamic> r, String k) {
      final x = r[k];
      if (x is num) return x.toDouble();
      return double.tryParse(x?.toString() ?? '') ?? 0;
    }

    final forecastWord = 'assistant.chart.forecast'.tr();
    Widget chart;
    switch (type) {
      case 'pie':
        final totals = [for (final k in keys) rows.fold<double>(0, (s, r) => s + v(r, k))];
        final sum = totals.fold<double>(0, (s, x) => s + x);
        chart = PieChart(PieChartData(
          sectionsSpace: 3,
          centerSpaceRadius: 40,
          sections: [
            for (var i = 0; i < keys.length; i++)
              PieChartSectionData(
                value: totals[i],
                color: _palette[i % _palette.length],
                radius: 50,
                title: sum <= 0 ? '' : '${(totals[i] / sum * 100).toStringAsFixed(1)}%',
                titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
              ),
          ],
        ));
      case 'radar':
        chart = rows.length < 3
            ? _bars(rows, keys, names, v, stacked: false)
            : RadarChart(RadarChartData(
                dataSets: [
                  for (var i = 0; i < keys.length; i++)
                    RadarDataSet(
                      dataEntries: [for (final r in rows) RadarEntry(value: v(r, keys[i]))],
                      borderColor: _palette[i % _palette.length],
                      fillColor: _palette[i % _palette.length].withValues(alpha: 0.2),
                      entryRadius: 2,
                    ),
                ],
                getTitle: (index, angle) => RadarChartTitle(text: names[index], angle: 0),
                titleTextStyle: const TextStyle(fontSize: 10),
                tickCount: 3,
                ticksTextStyle: const TextStyle(fontSize: 8, color: Colors.transparent),
              ));
      case 'bar':
      case 'grouped_bar':
      case 'composed':
        chart = _bars(rows, keys, names, v, stacked: false);
      case 'stacked_bar':
        chart = _bars(rows, keys, names, v, stacked: true);
      default:
        // line / area, có đoạn dự đoán nét đứt.
        final firstForecast = names.indexWhere((n) => n.contains(forecastWord));
        final area = type == 'area';
        final bars = <LineChartBarData>[];
        for (var i = 0; i < keys.length; i++) {
          final color = _palette[i % _palette.length];
          final actualEnd = firstForecast < 0 ? rows.length : firstForecast;
          bars.add(LineChartBarData(
            spots: [for (var x = 0; x < actualEnd; x++) FlSpot(x.toDouble(), v(rows[x], keys[i]))],
            color: color,
            barWidth: 2,
            isCurved: true,
            preventCurveOverShooting: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: area, color: color.withValues(alpha: 0.15)),
          ));
          if (firstForecast >= 0) {
            final start = math.max(0, firstForecast - 1);
            bars.add(LineChartBarData(
              spots: [for (var x = start; x < rows.length; x++) FlSpot(x.toDouble(), v(rows[x], keys[i]))],
              color: color,
              barWidth: 2,
              isCurved: true,
              preventCurveOverShooting: true,
              dashArray: const [5, 5],
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: area, color: color.withValues(alpha: 0.08)),
            ));
          }
        }
        chart = LineChart(LineChartData(
          lineBarsData: bars,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: _titles(names),
        ));
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null && title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          SizedBox(height: 220, child: chart),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              for (var i = 0; i < keys.length; i++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, color: _palette[i % _palette.length]),
                  const SizedBox(width: 4),
                  Text(keys[i], style: TextStyle(fontSize: 11, color: _palette[i % _palette.length])),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  FlTitlesData _titles(List<String> names) => FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Text(_compact(value), style: const TextStyle(fontSize: 10)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final i = value.round();
              if (i < 0 || i >= names.length || value != i.toDouble()) return const SizedBox.shrink();
              final step = (names.length / 6).ceil();
              if (step > 1 && i % step != 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(names[i], style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
              );
            },
          ),
        ),
      );

  Widget _bars(
    List<Map<String, dynamic>> rows,
    List<String> keys,
    List<String> names,
    double Function(Map<String, dynamic>, String) v, {
    required bool stacked,
  }) {
    return BarChart(BarChartData(
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: _titles(names),
      barGroups: [
        for (var x = 0; x < rows.length; x++)
          if (stacked)
            BarChartGroupData(x: x, barRods: [
              () {
                var from = 0.0;
                final items = <BarChartRodStackItem>[];
                for (var i = 0; i < keys.length; i++) {
                  final to = from + v(rows[x], keys[i]);
                  items.add(BarChartRodStackItem(from, to, _palette[i % _palette.length]));
                  from = to;
                }
                return BarChartRodData(toY: from, rodStackItems: items, width: 16, borderRadius: BorderRadius.zero);
              }(),
            ])
          else
            BarChartGroupData(x: x, barsSpace: 2, barRods: [
              for (var i = 0; i < keys.length; i++)
                BarChartRodData(
                  toY: v(rows[x], keys[i]),
                  color: _palette[i % _palette.length],
                  width: math.max(4, 24 / keys.length),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
            ]),
      ],
    ));
  }

  static String _compact(double value) {
    final a = value.abs();
    if (a >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
    if (a >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (a >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}
