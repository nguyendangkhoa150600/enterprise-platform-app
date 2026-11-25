import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import 'finance_ui.dart';

const Color _receiptColor = Color(0xFF059669);
const Color _paymentColor = Color(0xFFDC2626);

/// Mốc trục tung "đẹp" (1, 2, 5 × 10^n) cho giá trị lớn nhất (web `niceMax`).
double financeNiceMax(double value) {
  if (!(value > 0)) return 1;
  final exponent = (math.log(value) / math.ln10).floor();
  final base = math.pow(10, exponent).toDouble();
  final fraction = value / base;
  final step = fraction <= 1 ? 1 : fraction <= 2 ? 2 : fraction <= 5 ? 5 : 10;
  return step * base;
}

/// Nhãn kỳ: "2026-11" → "T11/2026", "2026-11-05" → "05/11" (web `periodLabel`).
String financePeriodLabel(String period) {
  final month = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(period);
  if (month != null) return 'T${int.parse(month.group(2)!)}/${month.group(1)}';
  final day = RegExp(r'^\d{4}-(\d{2})-(\d{2})$').firstMatch(period);
  return day != null ? '${day.group(2)}/${day.group(1)}' : period;
}

/// Biểu đồ cột đôi thu/chi theo kỳ (web `CashflowChart`), vẽ bằng CustomPaint. Chạm một cột để xem số tiền.
class FinanceCashflowChart extends StatefulWidget {
  final List<FinanceCashflowPoint> points;
  final double height;
  const FinanceCashflowChart({super.key, required this.points, this.height = 220});

  @override
  State<FinanceCashflowChart> createState() => _FinanceCashflowChartState();
}

class _FinanceCashflowChartState extends State<FinanceCashflowChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant FinanceCashflowChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text('finance.dashboard.chart_empty'.tr(),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: FinanceColors.muted)),
      );
    }
    final sel = _selected != null && _selected! < points.length ? points[_selected!] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Legend(color: _receiptColor, label: 'finance.dashboard.chart_receipts'.tr()),
            const SizedBox(width: 16),
            _Legend(color: _paymentColor, label: 'finance.dashboard.chart_payments'.tr()),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, constraints) {
          // Như web: mỗi kỳ ~44px; hẹp hơn thì cuộn ngang.
          final minWidth = points.length * 44.0 + 70;
          final width = math.max(constraints.maxWidth, minWidth);
          final chart = GestureDetector(
            onTapDown: (d) {
              const left = 54.0;
              final slot = (width - left - 8) / points.length;
              final i = ((d.localPosition.dx - left) / slot).floor();
              setState(() => _selected = (i >= 0 && i < points.length && i != _selected) ? i : null);
            },
            child: CustomPaint(
              size: Size(width, widget.height),
              painter: _CashflowPainter(points: points, selected: _selected),
            ),
          );
          return width > constraints.maxWidth
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: chart)
              : chart;
        }),
        if (sel != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'finance.dashboard.chart_tip'.tr(args: {
                'period': financePeriodLabel(sel.period),
                'receipts': formatFinanceMoney(sel.receipts),
                'payments': formatFinanceMoney(sel.payments),
              }),
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
      ],
    );
  }
}

class _CashflowPainter extends CustomPainter {
  final List<FinanceCashflowPoint> points;
  final int? selected;
  _CashflowPainter({required this.points, this.selected});

  static const double _left = 54;
  static const double _top = 12;
  static const double _bottom = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final innerH = size.height - _top - _bottom;
    final peak = financeNiceMax(points.fold<double>(0, (m, p) => math.max(m, math.max(p.receipts, p.payments))));
    final slot = (size.width - _left - 8) / points.length;
    final barW = math.min(18.0, math.max(4.0, slot / 2 - 3));
    double y(double v) => _top + innerH - (v / peak) * innerH;

    final grid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final tick = f * peak;
      final ty = y(tick);
      canvas.drawLine(Offset(_left, ty), Offset(size.width - 4, ty), grid);
      _text(canvas, formatFinanceMoneyShort(tick), Offset(_left - 6, ty), align: TextAlign.right);
    }

    if (selected != null && selected! < points.length) {
      final x = _left + selected! * slot;
      canvas.drawRect(Rect.fromLTWH(x, _top, slot, innerH), Paint()..color = const Color(0x14000000));
    }

    final labelEvery = (points.length / 12).ceil();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = _left + i * slot + slot / 2;
      final base = _top + innerH;
      void bar(double left, double value, Color color) {
        final top = y(value);
        if (base - top <= 0) return;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(left, top, left + barW, base), const Radius.circular(2)),
          Paint()..color = color,
        );
      }

      bar(x - barW - 1, p.receipts, _receiptColor);
      bar(x + 1, p.payments, _paymentColor);
      if (i % labelEvery == 0) {
        _text(canvas, financePeriodLabel(p.period), Offset(x, size.height - 10), align: TextAlign.center);
      }
    }
  }

  void _text(Canvas canvas, String text, Offset anchor, {required TextAlign align}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => anchor.dx - tp.width,
      TextAlign.center => anchor.dx - tp.width / 2,
      _ => anchor.dx,
    };
    tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_CashflowPainter old) => old.points != points || old.selected != selected;
}
