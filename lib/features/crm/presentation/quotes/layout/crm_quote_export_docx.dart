import 'dart:convert';
import 'dart:typed_data';

import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/quotes/crm_quote_layout_models.dart';
import 'crm_quote_layout_data.dart';

/// Xuất Word (.docx) theo bố cục in (web `export-docx.ts` dùng thư viện `docx`). pubspec không có gói tạo Word nên
/// mobile tự sinh WordprocessingML tối thiểu (document, styles, ảnh nhúng) và đóng gói ZIP không nén (tự tính CRC32),
/// cùng cách chia khối như web: bảng không viền cho đầu trang, bảng thông tin, tổng, chữ ký; bảng có viền cho dòng hàng.
class CrmQuoteDocxExporter {
  CrmQuoteDocxExporter._();

  static Uint8List build(CrmQuoteLayout layout, CrmQuoteLayoutData data) {
    final writer = _DocxWriter(layout, data);
    final body = writer.body();
    final files = <String, List<int>>{
      '[Content_Types].xml': utf8.encode(_contentTypes),
      '_rels/.rels': utf8.encode(_rootRels),
      'word/document.xml': utf8.encode(body),
      'word/styles.xml': utf8.encode(writer.styles()),
      'word/_rels/document.xml.rels': utf8.encode(writer.relationships()),
      for (final media in writer.media) 'word/media/${media.name}': media.bytes,
    };
    return _ZipWriter.build(files);
  }

  static const String _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="png" ContentType="image/png"/>'
      '<Default Extension="jpeg" ContentType="image/jpeg"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '</Types>';

  static const String _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';
}

class _Media {
  final String name;
  final String relId;
  final List<int> bytes;
  final int width;
  final int height;
  _Media(this.name, this.relId, this.bytes, this.width, this.height);
}

String _esc(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

/// 1 mm = 56,7 twip (web `mmToTwip`).
int _twip(double mm) => (mm * 56.7).round();

/// Kích thước điểm ảnh PNG/JPEG (web `readImageSize`).
({int width, int height})? _imageSize(Uint8List b) {
  if (b.length >= 24 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e && b[3] == 0x47) {
    final v = ByteData.sublistView(b);
    return (width: v.getUint32(16), height: v.getUint32(20));
  }
  if (b.length >= 4 && b[0] == 0xff && b[1] == 0xd8) {
    var o = 2;
    while (o + 9 < b.length) {
      if (b[o] != 0xff) {
        o++;
        continue;
      }
      final marker = b[o + 1];
      if (marker == 0xd8 || marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
        o += 2;
        continue;
      }
      final length = (b[o + 2] << 8) | b[o + 3];
      final frame = marker >= 0xc0 && marker <= 0xcf && marker != 0xc4 && marker != 0xc8 && marker != 0xcc;
      if (frame) return (height: (b[o + 5] << 8) | b[o + 6], width: (b[o + 7] << 8) | b[o + 8]);
      o += 2 + length;
    }
  }
  return null;
}

class _DocxWriter {
  final CrmQuoteLayout layout;
  final CrmQuoteLayoutData data;
  final List<_Media> media = [];
  _DocxWriter(this.layout, this.data);

  String bind(String text) => crmBindQuoteText(text, data.values);
  double get contentMm => layout.pageSize.width - layout.marginsMm.left - layout.marginsMm.right;
  int get contentTwips => _twip(contentMm);
  int halfPoints(double pt) => (pt * 2).round();
  String jc(String align) => switch (align) {
    'center' => 'center',
    'right' => 'right',
    _ => 'left',
  };

  String runs(
    String text, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    double? sizePt,
    bool caps = false,
  }) {
    final props = StringBuffer();
    if (bold) props.write('<w:b/>');
    if (italic) props.write('<w:i/>');
    if (underline) props.write('<w:u w:val="single"/>');
    if (caps) props.write('<w:caps/>');
    if (sizePt != null) props.write('<w:sz w:val="${halfPoints(sizePt)}"/>');
    final rPr = props.isEmpty ? '' : '<w:rPr>$props</w:rPr>';
    final parts = text.split(RegExp(r'\r?\n'));
    final out = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      out.write('<w:r>$rPr${i > 0 ? '<w:br/>' : ''}<w:t xml:space="preserve">${_esc(parts[i])}</w:t></w:r>');
    }
    return out.toString();
  }

  String paragraph(
    String children, {
    String? align,
    int before = 0,
    int after = 0,
    bool keepNext = false,
    int? indentLeft,
    int hanging = 0,
    String extra = '',
  }) {
    final pPr = StringBuffer();
    if (keepNext) pPr.write('<w:keepNext/>');
    pPr.write(extra);
    pPr.write('<w:spacing w:before="$before" w:after="$after"/>');
    if (indentLeft != null) pPr.write('<w:ind w:left="$indentLeft" w:hanging="$hanging"/>');
    if (align != null) pPr.write('<w:jc w:val="${jc(align)}"/>');
    return '<w:p><w:pPr>$pPr</w:pPr>$children</w:p>';
  }

  /// Đoạn rỗng cao đúng [heightMm] (khoảng cách trên của khối, khối khoảng trắng).
  String gap(double heightMm) {
    final line = _twip(heightMm) < 20 ? 20 : _twip(heightMm);
    return '<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="$line" w:lineRule="exact"/></w:pPr>'
        '<w:r><w:rPr><w:sz w:val="2"/></w:rPr><w:t></w:t></w:r></w:p>';
  }

  String cell(String content, int width, {String extra = '', int span = 1}) =>
      '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>${span > 1 ? '<w:gridSpan w:val="$span"/>' : ''}$extra</w:tcPr>'
      '${content.isEmpty ? paragraph('') : content}</w:tc>';

  String table(List<String> rows, List<int> widths, {bool borders = false, String? align}) {
    final b = borders ? 'single" w:sz="4" w:color="000000' : 'nil';
    final border = ['top', 'left', 'bottom', 'right', 'insideH', 'insideV'].map((s) => '<w:$s w:val="$b"/>').join();
    final total = widths.fold<int>(0, (s, w) => s + w);
    return '<w:tbl><w:tblPr><w:tblW w:w="$total" w:type="dxa"/>${align != null ? '<w:jc w:val="${jc(align)}"/>' : ''}'
        '<w:tblBorders>$border</w:tblBorders><w:tblLayout w:type="fixed"/>'
        '<w:tblCellMar><w:left w:w="60" w:type="dxa"/><w:right w:w="60" w:type="dxa"/></w:tblCellMar></w:tblPr>'
        '<w:tblGrid>${widths.map((w) => '<w:gridCol w:w="$w"/>').join()}</w:tblGrid>${rows.join()}</w:tbl>';
  }

  String row(List<String> cells, {bool header = false}) =>
      '<w:tr><w:trPr><w:cantSplit/>${header ? '<w:tblHeader/>' : ''}</w:trPr>${cells.join()}</w:tr>';

  String shade(String fill) => '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/>';

  /// Ảnh nhúng; trả `<w:r>` chứa drawing, hoặc chuỗi rỗng khi ảnh không đọc được.
  String imageRun(String? src, double heightMm, double maxWidthMm) {
    final img = crmEmbeddedImage(src);
    if (img == null) return '';
    Uint8List bytes;
    try {
      bytes = base64Decode(img.base64);
    } catch (_) {
      return '';
    }
    final size = _imageSize(bytes);
    if (size == null || size.width <= 0 || size.height <= 0) return '';
    var h = heightMm;
    var w = h * size.width / size.height;
    if (w > maxWidthMm) {
      h = h * maxWidthMm / w;
      w = maxWidthMm;
    }
    final index = media.length + 1;
    final ext = img.type == 'png' ? 'png' : 'jpeg';
    final m = _Media('image$index.$ext', 'rIdImg$index', bytes, size.width, size.height);
    media.add(m);
    final cx = (w * 36000).round();
    final cy = (h * 36000).round();
    return '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$cx" cy="$cy"/><wp:docPr id="$index" name="Picture $index"/>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr><pic:cNvPr id="$index" name="${m.name}"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="${m.relId}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
  }

  List<String> block(CrmLayoutBlock b) {
    switch (b.type) {
      case 'image':
        final run = imageRun(b.src, b.heightMm, contentMm);
        return run.isEmpty ? const [] : [paragraph(run, align: b.align)];
      case 'companyHeader':
        final text = [
          paragraph(runs(bind(b.name), bold: true, sizePt: layout.fontSizePt * 1.15), align: b.align),
          ...b.lines.map((l) => paragraph(runs(bind(l)), align: b.align)),
        ];
        final logoWidthMm = contentMm / 3 < 45 ? contentMm / 3 : 45.0;
        final logo = imageRun(crmCompanyHeaderLogo(b, data), 22, logoWidthMm);
        if (logo.isEmpty) return text;
        final logoTw = _twip(logoWidthMm + 4);
        final textTw = contentTwips - logoTw;
        const center = '<w:vAlign w:val="center"/>';
        final logoCell = cell(paragraph(logo, align: b.logoPosition), logoTw, extra: center);
        final textCell = cell(text.join(), textTw, extra: center);
        final right = b.logoPosition == 'right';
        return [
          table([
            row(right ? [textCell, logoCell] : [logoCell, textCell]),
          ], right ? [textTw, logoTw] : [logoTw, textTw]),
        ];
      case 'title':
        return [
          paragraph(
            runs(bind(b.text), bold: true, sizePt: b.fontSizePt, caps: b.uppercase),
            align: b.align,
          ),
          if ((b.subtitle ?? '').isNotEmpty)
            paragraph(runs(bind(b.subtitle!), italic: true), align: b.align, before: _twip(1)),
        ];
      case 'text':
        return [
          paragraph(
            b.runs.map((r) => runs(bind(r.text), bold: r.bold, italic: r.italic, underline: r.underline)).join(),
            align: b.align,
          ),
        ];
      case 'fieldGrid':
        final cols = b.columns == 2 ? 2 : 1;
        final pair = contentTwips ~/ cols;
        final labelTw = (pair * b.labelWidthPct / 100).round();
        final valueTw = pair - labelTw;
        final widths = [
          for (var c = 0; c < cols; c++) ...[labelTw, valueTw],
        ];
        final rows = <String>[];
        for (var start = 0; start < b.items.length; start += cols) {
          final cells = <String>[];
          for (var c = 0; c < cols; c++) {
            final i = start + c;
            if (i >= b.items.length) {
              cells.addAll([cell('', labelTw), cell('', valueTw)]);
              continue;
            }
            final item = b.items[i];
            cells.add(cell(paragraph(runs(item.label.isEmpty ? '' : '${bind(item.label)}:', bold: true)), labelTw));
            cells.add(cell(paragraph(runs(bind(item.value))), valueTw));
          }
          rows.add(row(cells));
        }
        return rows.isEmpty ? const [] : [table(rows, widths)];
      case 'lineTable':
        final columns = crmVisibleLineColumns(b);
        if (columns.isEmpty) return const [];
        final widths = columns.map((c) => (contentTwips * c.widthPct / 100).round()).toList();
        final rows = <String>[
          row([
            for (var i = 0; i < columns.length; i++)
              cell(
                paragraph(runs(bind(columns[i].label), bold: true), align: 'center'),
                widths[i],
                extra: '${shade('F1F5F9')}<w:vAlign w:val="center"/>',
              ),
          ], header: true),
        ];
        for (final r in crmLineTableRows(b, data.lines, 'crm.quotes.layout.ungrouped'.tr())) {
          if (r.group != null) {
            rows.add(
              row([
                cell(paragraph(runs(r.group!, bold: true)), contentTwips, span: columns.length, extra: shade('F1F5F9')),
              ]),
            );
          } else {
            final fill = b.zebra && r.stripe ? shade('F8FAFC') : '';
            rows.add(
              row([
                for (var i = 0; i < columns.length; i++)
                  cell(
                    paragraph(runs(r.line!.cells[columns[i].key] ?? ''), align: columns[i].align),
                    widths[i],
                    extra: fill,
                  ),
              ]),
            );
          }
        }
        return [table(rows, widths, borders: true)];
      case 'totals':
        final visible = b.rows.where((r) => r.visible).toList();
        final tableTw = (contentTwips * 0.55).round();
        final labelTw = (tableTw * 0.6).round();
        final valueTw = tableTw - labelTw;
        return [
          if (visible.isNotEmpty)
            table(
              [
                for (final r in visible)
                  row([
                    cell(paragraph(runs(bind(r.label), bold: r.key == 'grandTotal')), labelTw),
                    cell(
                      paragraph(runs(data.totals[r.key] ?? '', bold: r.key == 'grandTotal'), align: 'right'),
                      valueTw,
                    ),
                  ]),
              ],
              [labelTw, valueTw],
              align: b.align,
            ),
          if (b.showAmountInWords)
            paragraph(
              runs('${'crm.quotes.layout.amount_in_words'.tr()} ${data.amountInWords}', italic: true),
              align: b.align,
              before: _twip(1.5),
            ),
        ];
      case 'terms':
        return [
          for (var i = 0; i < b.items.length; i++)
            () {
              final item = b.items[i];
              final value = bind(item.value);
              final label = item.label.isEmpty ? '' : '${bind(item.label)}:${value.contains('\n') ? '\n' : ' '}';
              return paragraph(
                runs(b.numbered ? '${i + 1}. ' : '') + runs(label, bold: true) + runs(value),
                before: _twip(0.6),
                indentLeft: b.numbered ? _twip(6) : null,
                hanging: b.numbered ? _twip(6) : 0,
              );
            }(),
        ];
      case 'signature':
        final half = contentTwips ~/ 2;
        String party(CrmLayoutSignatureParty? p, int width) {
          if (p == null) return cell('', width);
          final line = _twip(b.heightMm);
          return cell(
            [
              paragraph(runs(bind(p.title), bold: true), align: 'center', keepNext: true),
              if ((p.subtitle ?? '').isNotEmpty)
                paragraph(runs(bind(p.subtitle!), italic: true), align: 'center', keepNext: true),
              '<w:p><w:pPr><w:keepNext/><w:spacing w:before="0" w:after="0" w:line="$line" w:lineRule="exact"/></w:pPr>'
                  '<w:r><w:rPr><w:sz w:val="2"/></w:rPr><w:t></w:t></w:r></w:p>',
              if ((p.name ?? '').isNotEmpty) paragraph(runs(bind(p.name!), bold: true), align: 'center'),
            ].join(),
            width,
          );
        }
        return [
          table(
            [
              row([party(b.left, half), party(b.right, contentTwips - half)]),
            ],
            [half, contentTwips - half],
          ),
        ];
      case 'spacer':
        return [gap(b.heightMm)];
      case 'divider':
        final size = (b.thicknessPt * 8).round() < 2 ? 2 : (b.thicknessPt * 8).round();
        return [
          paragraph(
            '',
            after: _twip(1),
            extra:
                '<w:pBdr><w:bottom w:val="${b.style == 'dashed' ? 'dashed' : 'single'}" w:sz="$size" w:space="1" w:color="000000"/></w:pBdr>',
          ),
        ];
    }
    return const [];
  }

  String body() {
    final children = <String>[];
    for (final b in layout.blocks) {
      if (b.marginTopMm > 0) children.add(gap(b.marginTopMm));
      children.addAll(block(b));
    }
    // Word cần đoạn văn sau bảng cuối cùng.
    if (children.isEmpty || children.last.startsWith('<w:tbl>')) children.add(paragraph(''));
    final portrait = layout.paper == 'A3' ? (w: 297.0, h: 420.0) : (w: 210.0, h: 297.0);
    final landscape = layout.orientation == 'landscape';
    final m = layout.marginsMm;
    final pgSz = landscape
        ? '<w:pgSz w:w="${_twip(portrait.h)}" w:h="${_twip(portrait.w)}" w:orient="landscape"/>'
        : '<w:pgSz w:w="${_twip(portrait.w)}" w:h="${_twip(portrait.h)}"/>';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
        '<w:body>${children.join()}<w:sectPr>$pgSz'
        '<w:pgMar w:top="${_twip(m.top)}" w:right="${_twip(m.right)}" w:bottom="${_twip(m.bottom)}" w:left="${_twip(m.left)}" '
        'w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>';
  }

  String styles() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults>'
      '<w:rPrDefault><w:rPr><w:rFonts w:ascii="${_esc(layout.fontFamily)}" w:hAnsi="${_esc(layout.fontFamily)}" '
      'w:cs="${_esc(layout.fontFamily)}" w:eastAsia="${_esc(layout.fontFamily)}"/>'
      '<w:sz w:val="${halfPoints(layout.fontSizePt)}"/><w:szCs w:val="${halfPoints(layout.fontSizePt)}"/><w:lang w:val="vi-VN"/></w:rPr></w:rPrDefault>'
      '<w:pPrDefault><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr></w:pPrDefault></w:docDefaults></w:styles>';

  String relationships() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '${media.map((m) => '<Relationship Id="${m.relId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${m.name}"/>').join()}'
      '</Relationships>';
}

/// ZIP tối thiểu, các tệp lưu không nén (method 0).
class _ZipWriter {
  static final List<int> _table = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static int _crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc = _table[(crc ^ b) & 0xFF] ^ (crc >> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static Uint8List build(Map<String, List<int>> files) {
    final out = BytesBuilder();
    final central = BytesBuilder();
    void u16(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
    void u32(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    var count = 0;
    files.forEach((name, data) {
      final nameBytes = utf8.encode(name);
      final crc = _crc32(data);
      final offset = out.length;
      u32(out, 0x04034b50);
      u16(out, 20);
      u16(out, 0x0800);
      u16(out, 0);
      u16(out, 0);
      u16(out, 0x21);
      u32(out, crc);
      u32(out, data.length);
      u32(out, data.length);
      u16(out, nameBytes.length);
      u16(out, 0);
      out.add(nameBytes);
      out.add(data);

      u32(central, 0x02014b50);
      u16(central, 20);
      u16(central, 20);
      u16(central, 0x0800);
      u16(central, 0);
      u16(central, 0);
      u16(central, 0x21);
      u32(central, crc);
      u32(central, data.length);
      u32(central, data.length);
      u16(central, nameBytes.length);
      u16(central, 0);
      u16(central, 0);
      u16(central, 0);
      u16(central, 0);
      u32(central, 0);
      u32(central, offset);
      central.add(nameBytes);
      count++;
    });
    final centralOffset = out.length;
    final centralBytes = central.takeBytes();
    out.add(centralBytes);
    u32(out, 0x06054b50);
    u16(out, 0);
    u16(out, 0);
    u16(out, count);
    u16(out, count);
    u32(out, centralBytes.length);
    u32(out, centralOffset);
    u16(out, 0);
    return out.takeBytes();
  }
}
