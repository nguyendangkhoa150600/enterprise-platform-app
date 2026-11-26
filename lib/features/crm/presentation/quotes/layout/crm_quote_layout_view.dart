import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/quotes/crm_quote_layout_models.dart';
import 'crm_quote_layout_data.dart';

/// Dựng bản in báo giá theo bố cục (web `QuoteLayoutView` chế độ `preview` + `quote-layout-blocks.tsx`): trang theo mm,
/// thu cho vừa bề ngang khung; bảng hàng rỗng có dòng "Chưa có dòng hàng". Chỉ xem, không thiết kế.
class CrmQuoteLayoutView extends StatelessWidget {
  final CrmQuoteLayout layout;
  final CrmQuoteLayoutData data;
  const CrmQuoteLayoutView({super.key, required this.layout, required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final page = layout.pageSize;
        final mm = constraints.maxWidth / page.width;
        final ctx = _Ctx(layout: layout, data: data, mm: mm);
        final m = layout.marginsMm;
        return Container(
          width: constraints.maxWidth,
          constraints: BoxConstraints(minHeight: page.height * mm),
          padding: EdgeInsets.fromLTRB(m.left * mm, m.top * mm, m.right * mm, m.bottom * mm),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: _fontFamily(layout.fontFamily),
              fontSize: ctx.pt(layout.fontSizePt),
              color: Colors.black,
              height: 1.3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final block in layout.blocks)
                  Padding(
                    padding: EdgeInsets.only(top: block.marginTopMm * mm),
                    child: _BlockView(block: block, ctx: ctx),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String? _fontFamily(String font) => switch (font) {
  'Times New Roman' => 'serif',
  'Arial' => 'sans-serif',
  _ => null,
};

class _Ctx {
  final CrmQuoteLayout layout;
  final CrmQuoteLayoutData data;
  final double mm;
  const _Ctx({required this.layout, required this.data, required this.mm});

  /// 1 pt = 0,3528 mm.
  double pt(double value) => value * 0.3528 * mm;
  String bind(String text) => crmBindQuoteText(text, data.values);
}

TextAlign _textAlign(String align) => switch (align) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  _ => TextAlign.left,
};

CrossAxisAlignment _cross(String align) => switch (align) {
  'center' => CrossAxisAlignment.center,
  'right' => CrossAxisAlignment.end,
  _ => CrossAxisAlignment.start,
};

Widget? _image(String? src, double height) {
  final image = crmEmbeddedImage(src);
  if (image == null) return null;
  try {
    return Image.memory(base64Decode(image.base64), height: height, fit: BoxFit.contain, gaplessPlayback: true);
  } catch (_) {
    return null;
  }
}

class _BlockView extends StatelessWidget {
  final CrmLayoutBlock block;
  final _Ctx ctx;
  const _BlockView({required this.block, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final mm = ctx.mm;
    switch (block.type) {
      case 'image':
        final img = _image(block.src, block.heightMm * mm);
        if (img == null) return const SizedBox.shrink();
        return Align(
          alignment: switch (block.align) {
            'center' => Alignment.center,
            'right' => Alignment.centerRight,
            _ => Alignment.centerLeft,
          },
          child: img,
        );
      case 'companyHeader':
        final logo = _image(crmCompanyHeaderLogo(block, ctx.data), 22 * mm);
        final text = Expanded(
          child: Column(
            crossAxisAlignment: _cross(block.align),
            children: [
              Text(
                ctx.bind(block.name),
                textAlign: _textAlign(block.align),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: ctx.pt(ctx.layout.fontSizePt * 1.15)),
              ),
              for (final line in block.lines) Text(ctx.bind(line), textAlign: _textAlign(block.align)),
            ],
          ),
        );
        final logoBox = logo == null
            ? null
            : ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 45 * mm),
                child: logo,
              );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: block.logoPosition == 'right'
              ? [
                  text,
                  if (logoBox != null) ...[SizedBox(width: 4 * mm), logoBox],
                ]
              : [
                  if (logoBox != null) ...[logoBox, SizedBox(width: 4 * mm)],
                  text,
                ],
        );
      case 'title':
        final title = ctx.bind(block.text);
        return Column(
          crossAxisAlignment: _cross(block.align),
          children: [
            Text(
              block.uppercase ? title.toUpperCase() : title,
              textAlign: _textAlign(block.align),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: ctx.pt(block.fontSizePt)),
            ),
            if ((block.subtitle ?? '').isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 1 * mm),
                child: Text(
                  ctx.bind(block.subtitle!),
                  textAlign: _textAlign(block.align),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        );
      case 'text':
        return Text.rich(
          TextSpan(
            children: [
              for (final run in block.runs)
                TextSpan(
                  text: ctx.bind(run.text),
                  style: TextStyle(
                    fontWeight: run.bold ? FontWeight.bold : null,
                    fontStyle: run.italic ? FontStyle.italic : null,
                    decoration: run.underline ? TextDecoration.underline : null,
                  ),
                ),
            ],
          ),
          textAlign: _textAlign(block.align),
        );
      case 'fieldGrid':
        return _fieldGrid();
      case 'lineTable':
        return _lineTable();
      case 'totals':
        return _totals();
      case 'terms':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < block.items.length; i++)
              Padding(
                padding: EdgeInsets.only(top: 0.6 * mm),
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (block.numbered) TextSpan(text: '${i + 1}. '),
                      if (block.items[i].label.isNotEmpty)
                        TextSpan(
                          text:
                              '${ctx.bind(block.items[i].label)}:${ctx.bind(block.items[i].value).contains('\n') ? '\n' : ' '}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      TextSpan(text: ctx.bind(block.items[i].value)),
                    ],
                  ),
                ),
              ),
          ],
        );
      case 'signature':
        Widget party(CrmLayoutSignatureParty? p) => Expanded(
          child: p == null
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    Text(
                      ctx.bind(p.title),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if ((p.subtitle ?? '').isNotEmpty)
                      Text(
                        ctx.bind(p.subtitle!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    SizedBox(height: block.heightMm * mm),
                    if ((p.name ?? '').isNotEmpty)
                      Text(
                        ctx.bind(p.name!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
        );
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [party(block.left), party(block.right)]);
      case 'spacer':
        return SizedBox(height: block.heightMm * mm);
      case 'divider':
        return Padding(
          padding: EdgeInsets.only(bottom: 1 * mm),
          child: block.style == 'dashed'
              ? LayoutBuilder(
                  builder: (context, c) {
                    final dash = 2 * mm;
                    final count = (c.maxWidth / (dash * 2)).floor();
                    return Row(
                      children: List.generate(
                        count,
                        (_) => Container(
                          width: dash,
                          height: ctx.pt(block.thicknessPt),
                          color: Colors.black,
                          margin: EdgeInsets.only(right: dash),
                        ),
                      ),
                    );
                  },
                )
              : Container(height: ctx.pt(block.thicknessPt), color: Colors.black),
        );
    }
    return const SizedBox.shrink();
  }

  Widget _fieldGrid() {
    final cols = block.columns == 2 ? 2 : 1;
    final rows = <Widget>[];
    for (var start = 0; start < block.items.length; start += cols) {
      final cells = <Widget>[];
      for (var c = 0; c < cols; c++) {
        final index = start + c;
        if (index >= block.items.length) {
          cells.add(const Expanded(child: SizedBox.shrink()));
          continue;
        }
        final item = block.items[index];
        cells.add(
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: block.labelWidthPct.round().clamp(1, 99),
                  child: Text(
                    item.label.isEmpty ? '' : '${ctx.bind(item.label)}:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(flex: (100 - block.labelWidthPct).round().clamp(1, 99), child: Text(ctx.bind(item.value))),
              ],
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: 0.6 * ctx.mm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _lineTable() {
    final columns = crmVisibleLineColumns(block);
    if (columns.isEmpty) return const SizedBox.shrink();
    final border = BorderSide(color: Colors.black, width: ctx.pt(0.75).clamp(0.5, 2));
    final pad = EdgeInsets.symmetric(horizontal: 1 * ctx.mm, vertical: 0.8 * ctx.mm);
    final small = TextStyle(fontSize: ctx.pt(ctx.layout.fontSizePt * 0.92));
    Widget cell(String text, String align, {bool bold = false}) => Padding(
      padding: pad,
      child: Text(
        text,
        textAlign: _textAlign(align),
        style: small.copyWith(fontWeight: bold ? FontWeight.bold : null),
      ),
    );
    final rows = crmLineTableRows(block, ctx.data.lines, 'crm.quotes.layout.ungrouped'.tr());
    final tableRows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
        children: [for (final c in columns) cell(ctx.bind(c.label), 'center', bold: true)],
      ),
    ];
    final extras = <Widget>[];
    if (rows.isEmpty) {
      extras.add(
        Container(
          decoration: BoxDecoration(
            border: Border(left: border, right: border, bottom: border),
          ),
          padding: pad,
          child: Text(
            'crm.quotes.layout.empty_lines'.tr(),
            textAlign: TextAlign.center,
            style: small.copyWith(color: Colors.black54),
          ),
        ),
      );
    }
    // Hàng nhóm trải hết bề ngang không có trong Table: dựng thành bảng con nối tiếp.
    final groups = <Widget>[];
    var current = <TableRow>[...tableRows];
    void flush() {
      if (current.isEmpty) return;
      groups.add(
        Table(
          border: TableBorder(
            left: border,
            right: border,
            top: groups.isEmpty ? border : BorderSide.none,
            bottom: border,
            horizontalInside: border,
            verticalInside: border,
          ),
          columnWidths: {for (var i = 0; i < columns.length; i++) i: FlexColumnWidth(columns[i].widthPct)},
          children: current,
        ),
      );
      current = [];
    }

    for (final row in rows) {
      if (row.group != null) {
        flush();
        groups.add(
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              border: Border(left: border, right: border, bottom: border),
            ),
            padding: pad,
            child: Text(row.group!, style: small.copyWith(fontWeight: FontWeight.bold)),
          ),
        );
      } else {
        current.add(
          TableRow(
            decoration: block.zebra && row.stripe ? const BoxDecoration(color: Color(0xFFF8FAFC)) : null,
            children: [for (final c in columns) cell(row.line!.cells[c.key] ?? '', c.align)],
          ),
        );
      }
    }
    flush();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...groups, ...extras]);
  }

  Widget _totals() {
    final visible = block.rows.where((r) => r.visible).toList();
    return Column(
      crossAxisAlignment: _cross(block.align),
      children: [
        if (visible.isNotEmpty)
          FractionallySizedBox(
            widthFactor: 0.6,
            child: Column(
              children: [
                for (final row in visible)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 0.4 * ctx.mm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ctx.bind(row.label),
                            style: TextStyle(fontWeight: row.key == 'grandTotal' ? FontWeight.bold : FontWeight.w600),
                          ),
                        ),
                        Text(
                          ctx.data.totals[row.key] ?? '',
                          style: TextStyle(fontWeight: row.key == 'grandTotal' ? FontWeight.bold : null),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (block.showAmountInWords)
          Padding(
            padding: EdgeInsets.only(top: 1.5 * ctx.mm),
            child: Text(
              '${'crm.quotes.layout.amount_in_words'.tr()} ${ctx.data.values['totals.amountInWords'] ?? ''}',
              textAlign: _textAlign(block.align),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
