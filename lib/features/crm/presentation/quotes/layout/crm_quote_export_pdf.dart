import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/quotes/crm_quote_layout_models.dart';
import 'crm_quote_layout_data.dart';

/// Xuất PDF / In (web `export-pdf.ts` dùng lệnh in trình duyệt): dựng cùng bố cục bằng package `pdf` rồi mở hộp in /
/// lưu PDF của hệ điều hành ([Printing.layoutPdf]). Font tiếng Việt: Tinos (thay Times New Roman), Arimo (thay Arial),
/// Roboto — tải qua `PdfGoogleFonts` như các màn in khác của app.
class CrmQuotePdfExporter {
  CrmQuotePdfExporter._();

  static Future<pw.ThemeData> _theme(String family) async {
    switch (family) {
      case 'Arial':
        return pw.ThemeData.withFont(
          base: await PdfGoogleFonts.arimoRegular(),
          bold: await PdfGoogleFonts.arimoBold(),
          italic: await PdfGoogleFonts.arimoItalic(),
          boldItalic: await PdfGoogleFonts.arimoBoldItalic(),
        );
      case 'Roboto':
        return pw.ThemeData.withFont(
          base: await PdfGoogleFonts.robotoRegular(),
          bold: await PdfGoogleFonts.robotoBold(),
          italic: await PdfGoogleFonts.robotoItalic(),
          boldItalic: await PdfGoogleFonts.robotoBoldItalic(),
        );
      default:
        return pw.ThemeData.withFont(
          base: await PdfGoogleFonts.tinosRegular(),
          bold: await PdfGoogleFonts.tinosBold(),
          italic: await PdfGoogleFonts.tinosItalic(),
          boldItalic: await PdfGoogleFonts.tinosBoldItalic(),
        );
    }
  }

  /// Dựng file PDF.
  static Future<Uint8List> build(CrmQuoteLayout layout, CrmQuoteLayoutData data) async {
    final theme = await _theme(layout.fontFamily);
    final page = layout.pageSize;
    final m = layout.marginsMm;
    final format = PdfPageFormat(
      page.width * PdfPageFormat.mm,
      page.height * PdfPageFormat.mm,
      marginTop: m.top * PdfPageFormat.mm,
      marginRight: m.right * PdfPageFormat.mm,
      marginBottom: m.bottom * PdfPageFormat.mm,
      marginLeft: m.left * PdfPageFormat.mm,
    );
    final builder = _PdfBuilder(layout, data);
    final doc = pw.Document(title: crmBindQuoteText('{{quote.code}}', data.values), creator: 'Enterprise Platform CRM');
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: theme.copyWith(defaultTextStyle: pw.TextStyle(fontSize: layout.fontSizePt, lineSpacing: 1)),
        build: (_) => builder.blocks(),
      ),
    );
    return doc.save();
  }

  /// Mở hộp in / lưu PDF với tên `<fileName>.pdf`.
  static Future<void> export(CrmQuoteLayout layout, CrmQuoteLayoutData data, String fileName) async {
    final bytes = await build(layout, data);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
  }
}

class _PdfBuilder {
  final CrmQuoteLayout layout;
  final CrmQuoteLayoutData data;
  _PdfBuilder(this.layout, this.data);

  static const double mm = PdfPageFormat.mm;
  String bind(String text) => crmBindQuoteText(text, data.values);

  pw.TextAlign align(String a) => switch (a) {
    'center' => pw.TextAlign.center,
    'right' => pw.TextAlign.right,
    _ => pw.TextAlign.left,
  };
  pw.CrossAxisAlignment cross(String a) => switch (a) {
    'center' => pw.CrossAxisAlignment.center,
    'right' => pw.CrossAxisAlignment.end,
    _ => pw.CrossAxisAlignment.start,
  };

  pw.Widget? image(String? src, double heightMm, double maxWidthMm) {
    final img = crmEmbeddedImage(src);
    if (img == null) return null;
    try {
      return pw.Container(
        constraints: pw.BoxConstraints(maxWidth: maxWidthMm * mm),
        child: pw.Image(pw.MemoryImage(base64Decode(img.base64)), height: heightMm * mm, fit: pw.BoxFit.contain),
      );
    } catch (_) {
      return null;
    }
  }

  double get contentWidthMm => layout.pageSize.width - layout.marginsMm.left - layout.marginsMm.right;

  List<pw.Widget> blocks() {
    final out = <pw.Widget>[];
    for (final block in layout.blocks) {
      if (block.marginTopMm > 0) out.add(pw.SizedBox(height: block.marginTopMm * mm));
      out.addAll(_block(block));
    }
    return out;
  }

  List<pw.Widget> _block(CrmLayoutBlock b) {
    switch (b.type) {
      case 'image':
        final img = image(b.src, b.heightMm, contentWidthMm);
        return img == null
            ? const []
            : [
                pw.Align(
                  alignment: switch (b.align) {
                    'center' => pw.Alignment.center,
                    'right' => pw.Alignment.centerRight,
                    _ => pw.Alignment.centerLeft,
                  },
                  child: img,
                ),
              ];
      case 'companyHeader':
        final text = pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: cross(b.align),
            children: [
              pw.Text(
                bind(b.name),
                textAlign: align(b.align),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: layout.fontSizePt * 1.15),
              ),
              for (final line in b.lines) pw.Text(bind(line), textAlign: align(b.align)),
            ],
          ),
        );
        final logo = image(crmCompanyHeaderLogo(b, data), 22, contentWidthMm / 3 < 45 ? contentWidthMm / 3 : 45);
        return [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: b.logoPosition == 'right'
                ? [
                    text,
                    if (logo != null) ...[pw.SizedBox(width: 4 * mm), logo],
                  ]
                : [
                    if (logo != null) ...[logo, pw.SizedBox(width: 4 * mm)],
                    text,
                  ],
          ),
        ];
      case 'title':
        final title = bind(b.text);
        return [
          pw.Text(
            b.uppercase ? title.toUpperCase() : title,
            textAlign: align(b.align),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: b.fontSizePt),
          ),
          if ((b.subtitle ?? '').isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1 * mm),
              child: pw.Text(
                bind(b.subtitle!),
                textAlign: align(b.align),
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
              ),
            ),
        ].map((w) => pw.SizedBox(width: double.infinity, child: w)).toList();
      case 'text':
        return [
          pw.SizedBox(
            width: double.infinity,
            child: pw.RichText(
              textAlign: align(b.align),
              text: pw.TextSpan(
                children: [
                  for (final run in b.runs)
                    pw.TextSpan(
                      text: bind(run.text),
                      style: pw.TextStyle(
                        fontWeight: run.bold ? pw.FontWeight.bold : null,
                        fontStyle: run.italic ? pw.FontStyle.italic : null,
                        decoration: run.underline ? pw.TextDecoration.underline : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ];
      case 'fieldGrid':
        final cols = b.columns == 2 ? 2 : 1;
        final rows = <pw.TableRow>[];
        for (var start = 0; start < b.items.length; start += cols) {
          final cells = <pw.Widget>[];
          for (var c = 0; c < cols; c++) {
            final i = start + c;
            if (i >= b.items.length) {
              cells.addAll([pw.SizedBox(), pw.SizedBox()]);
              continue;
            }
            final item = b.items[i];
            cells.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 0.6 * mm, right: 1 * mm),
                child: pw.Text(
                  item.label.isEmpty ? '' : '${bind(item.label)}:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            );
            cells.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 0.6 * mm, right: 2 * mm),
                child: pw.Text(bind(item.value)),
              ),
            );
          }
          rows.add(pw.TableRow(children: cells));
        }
        final label = b.labelWidthPct / 100;
        return rows.isEmpty
            ? const []
            : [
                pw.Table(
                  columnWidths: {
                    for (var c = 0; c < cols; c++) ...{
                      c * 2: pw.FlexColumnWidth(label),
                      c * 2 + 1: pw.FlexColumnWidth(1 - label),
                    },
                  },
                  children: rows,
                ),
              ];
      case 'lineTable':
        return _lineTable(b);
      case 'totals':
        final visible = b.rows.where((r) => r.visible).toList();
        return [
          if (visible.isNotEmpty)
            pw.Align(
              alignment: switch (b.align) {
                'center' => pw.Alignment.center,
                'left' => pw.Alignment.centerLeft,
                _ => pw.Alignment.centerRight,
              },
              child: pw.SizedBox(
                width: contentWidthMm * 0.55 * mm,
                child: pw.Table(
                  columnWidths: const {0: pw.FlexColumnWidth(6), 1: pw.FlexColumnWidth(4)},
                  children: [
                    for (final row in visible)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 0.4 * mm),
                            child: pw.Text(
                              bind(row.label),
                              style: pw.TextStyle(fontWeight: row.key == 'grandTotal' ? pw.FontWeight.bold : null),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 0.4 * mm),
                            child: pw.Text(
                              data.totals[row.key] ?? '',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontWeight: row.key == 'grandTotal' ? pw.FontWeight.bold : null),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (b.showAmountInWords)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1.5 * mm),
              child: pw.SizedBox(
                width: double.infinity,
                child: pw.Text(
                  '${'crm.quotes.layout.amount_in_words'.tr()} ${data.amountInWords}',
                  textAlign: align(b.align),
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                ),
              ),
            ),
        ];
      case 'terms':
        return [
          for (var i = 0; i < b.items.length; i++)
            pw.Padding(
              padding: pw.EdgeInsets.only(top: 0.6 * mm, left: b.numbered ? 0 : 0),
              child: pw.SizedBox(
                width: double.infinity,
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      if (b.numbered) pw.TextSpan(text: '${i + 1}. '),
                      if (b.items[i].label.isNotEmpty)
                        pw.TextSpan(
                          text: '${bind(b.items[i].label)}:${bind(b.items[i].value).contains('\n') ? '\n' : ' '}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      pw.TextSpan(text: bind(b.items[i].value)),
                    ],
                  ),
                ),
              ),
            ),
        ];
      case 'signature':
        pw.Widget party(CrmLayoutSignatureParty? p) => pw.Expanded(
          child: p == null
              ? pw.SizedBox()
              : pw.Column(
                  children: [
                    pw.Text(
                      bind(p.title),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if ((p.subtitle ?? '').isNotEmpty)
                      pw.Text(
                        bind(p.subtitle!),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                      ),
                    pw.SizedBox(height: b.heightMm * mm),
                    if ((p.name ?? '').isNotEmpty)
                      pw.Text(
                        bind(p.name!),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                  ],
                ),
        );
        return [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [party(b.left), party(b.right)]),
        ];
      case 'spacer':
        return [pw.SizedBox(height: b.heightMm * mm)];
      case 'divider':
        return [
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 1 * mm),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  width: b.thicknessPt,
                  style: b.style == 'dashed' ? pw.BorderStyle.dashed : pw.BorderStyle.solid,
                ),
              ),
            ),
          ),
        ];
    }
    return const [];
  }

  List<pw.Widget> _lineTable(CrmLayoutBlock b) {
    final columns = crmVisibleLineColumns(b);
    if (columns.isEmpty) return const [];
    final small = pw.TextStyle(fontSize: layout.fontSizePt * 0.92);
    const pad = pw.EdgeInsets.symmetric(horizontal: 1 * mm, vertical: 0.8 * mm);
    pw.Widget cell(String text, String a, {bool bold = false}) => pw.Padding(
      padding: pad,
      child: pw.Text(
        text,
        textAlign: align(a),
        style: small.copyWith(fontWeight: bold ? pw.FontWeight.bold : null),
      ),
    );
    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
        children: [for (final c in columns) cell(bind(c.label), 'center', bold: true)],
      ),
    ];
    for (final row in crmLineTableRows(b, data.lines, 'crm.quotes.layout.ungrouped'.tr())) {
      if (row.group != null) {
        rows.add(
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
            children: [cell(row.group!, 'left', bold: true), for (var i = 1; i < columns.length; i++) pw.SizedBox()],
          ),
        );
      } else {
        rows.add(
          pw.TableRow(
            decoration: b.zebra && row.stripe ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)) : null,
            children: [for (final c in columns) cell(row.line!.cells[c.key] ?? '', c.align)],
          ),
        );
      }
    }
    return [
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: {for (var i = 0; i < columns.length; i++) i: pw.FlexColumnWidth(columns[i].widthPct)},
        children: rows,
      ),
    ];
  }
}
