import '../common/crm_json.dart';
import '../common/crm_sales_organization_models.dart';

/// Bố cục in của mẫu báo giá (contracts `quote-layout.ts`): JSON có kiểu, không HTML. Mobile chỉ ĐỌC (xem trước, xuất);
/// trình thiết kế thuộc Cấu hình nên không làm.

class CrmLayoutLabelValue {
  final String label;
  final String value;
  const CrmLayoutLabelValue(this.label, this.value);
  factory CrmLayoutLabelValue.fromJson(Map<String, dynamic> json) =>
      CrmLayoutLabelValue(CrmJson.str(json['label']), CrmJson.str(json['value']));
}

class CrmLayoutTextRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  const CrmLayoutTextRun(this.text, {this.bold = false, this.italic = false, this.underline = false});
  factory CrmLayoutTextRun.fromJson(Map<String, dynamic> json) => CrmLayoutTextRun(
        CrmJson.str(json['text']),
        bold: CrmJson.boolean(json['bold']),
        italic: CrmJson.boolean(json['italic']),
        underline: CrmJson.boolean(json['underline']),
      );
}

/// Cột bảng dòng hàng (`QuoteLayoutLineColumn`).
class CrmLayoutLineColumn {
  final String key;
  final String label;
  final double widthPct;
  final String align;
  final bool visible;
  const CrmLayoutLineColumn(this.key, this.label, this.widthPct, this.align, this.visible);
  factory CrmLayoutLineColumn.fromJson(Map<String, dynamic> json) => CrmLayoutLineColumn(
        CrmJson.str(json['key']),
        CrmJson.str(json['label']),
        CrmJson.number(json['widthPct']),
        CrmJson.str(json['align'], 'left'),
        CrmJson.boolean(json['visible'], true),
      );
  CrmLayoutLineColumn withWidth(double width) => CrmLayoutLineColumn(key, label, width, align, visible);
}

class CrmLayoutTotalRow {
  final String key;
  final String label;
  final bool visible;
  const CrmLayoutTotalRow(this.key, this.label, this.visible);
  factory CrmLayoutTotalRow.fromJson(Map<String, dynamic> json) =>
      CrmLayoutTotalRow(CrmJson.str(json['key']), CrmJson.str(json['label']), CrmJson.boolean(json['visible'], true));
}

class CrmLayoutSignatureParty {
  final String title;
  final String? subtitle;
  final String? name;
  const CrmLayoutSignatureParty(this.title, {this.subtitle, this.name});
  factory CrmLayoutSignatureParty.fromJson(Map<String, dynamic> json) => CrmLayoutSignatureParty(
        CrmJson.str(json['title']),
        subtitle: CrmJson.strOrNull(json['subtitle']),
        name: CrmJson.strOrNull(json['name']),
      );
}

/// Một khối của bố cục. Các trường chỉ có nghĩa theo [type] (image, companyHeader, title, text, fieldGrid, lineTable,
/// totals, terms, signature, spacer, divider).
class CrmLayoutBlock {
  final String id;
  final String type;
  final double marginTopMm;
  final String align;
  // image
  final String? src;
  final double heightMm;
  // companyHeader
  final String name;
  final List<String> lines;
  final String? logo;
  final bool logoFromOrganization;
  final String logoPosition;
  // title
  final String text;
  final String? subtitle;
  final double fontSizePt;
  final bool uppercase;
  // text
  final List<CrmLayoutTextRun> runs;
  // fieldGrid
  final int columns;
  final List<CrmLayoutLabelValue> items;
  final double labelWidthPct;
  // lineTable
  final List<CrmLayoutLineColumn> lineColumns;
  final bool showGroupByCategory;
  final bool zebra;
  // totals
  final List<CrmLayoutTotalRow> rows;
  final bool showAmountInWords;
  // terms
  final bool numbered;
  // signature
  final CrmLayoutSignatureParty? left;
  final CrmLayoutSignatureParty? right;
  // divider
  final double thicknessPt;
  final String style;

  const CrmLayoutBlock({
    required this.id,
    required this.type,
    this.marginTopMm = 0,
    this.align = 'left',
    this.src,
    this.heightMm = 0,
    this.name = '',
    this.lines = const [],
    this.logo,
    this.logoFromOrganization = false,
    this.logoPosition = 'left',
    this.text = '',
    this.subtitle,
    this.fontSizePt = 16,
    this.uppercase = false,
    this.runs = const [],
    this.columns = 1,
    this.items = const [],
    this.labelWidthPct = 35,
    this.lineColumns = const [],
    this.showGroupByCategory = false,
    this.zebra = false,
    this.rows = const [],
    this.showAmountInWords = false,
    this.numbered = false,
    this.left,
    this.right,
    this.thicknessPt = 1,
    this.style = 'solid',
  });

  factory CrmLayoutBlock.fromJson(Map<String, dynamic> json) {
    final type = CrmJson.str(json['type']);
    return CrmLayoutBlock(
      id: CrmJson.str(json['id']),
      type: type,
      marginTopMm: CrmJson.number(json['marginTopMm']),
      align: CrmJson.str(json['align'], 'left'),
      src: CrmJson.strOrNull(json['src']),
      heightMm: CrmJson.number(json['heightMm']),
      name: CrmJson.str(json['name']),
      lines: type == 'companyHeader' ? CrmJson.strings(json['lines']) : const [],
      logo: CrmJson.strOrNull(json['logo']),
      logoFromOrganization: CrmJson.boolean(json['logoFromOrganization']),
      logoPosition: CrmJson.str(json['logoPosition'], 'left'),
      text: CrmJson.str(json['text']),
      subtitle: CrmJson.strOrNull(json['subtitle']),
      fontSizePt: CrmJson.number(json['fontSizePt'], 16),
      uppercase: CrmJson.boolean(json['uppercase']),
      runs: CrmJson.list(json['runs'], CrmLayoutTextRun.fromJson),
      columns: type == 'fieldGrid' ? CrmJson.integer(json['columns'], 1) : 1,
      items: CrmJson.list(json['items'], CrmLayoutLabelValue.fromJson),
      labelWidthPct: CrmJson.number(json['labelWidthPct'], 35),
      lineColumns: type == 'lineTable' ? CrmJson.list(json['columns'], CrmLayoutLineColumn.fromJson) : const [],
      showGroupByCategory: CrmJson.boolean(json['showGroupByCategory']),
      zebra: CrmJson.boolean(json['zebra']),
      rows: CrmJson.list(json['rows'], CrmLayoutTotalRow.fromJson),
      showAmountInWords: CrmJson.boolean(json['showAmountInWords']),
      numbered: CrmJson.boolean(json['numbered']),
      left: json['left'] is Map ? CrmLayoutSignatureParty.fromJson(CrmJson.map(json['left'])) : null,
      right: json['right'] is Map ? CrmLayoutSignatureParty.fromJson(CrmJson.map(json['right'])) : null,
      thicknessPt: CrmJson.number(json['thicknessPt'], 1),
      style: CrmJson.str(json['style'], 'solid'),
    );
  }
}

class CrmLayoutMargins {
  final double top;
  final double right;
  final double bottom;
  final double left;
  const CrmLayoutMargins(this.top, this.right, this.bottom, this.left);
}

/// Bố cục in (contracts `QuoteLayout`).
class CrmQuoteLayout {
  final String paper;
  final String orientation;
  final CrmLayoutMargins marginsMm;
  final String fontFamily;
  final double fontSizePt;
  final List<CrmLayoutBlock> blocks;

  const CrmQuoteLayout({
    this.paper = 'A4',
    this.orientation = 'portrait',
    this.marginsMm = const CrmLayoutMargins(15, 15, 15, 20),
    this.fontFamily = 'Times New Roman',
    this.fontSizePt = 12,
    this.blocks = const [],
  });

  factory CrmQuoteLayout.fromJson(Map<String, dynamic> json) {
    final m = CrmJson.map(json['marginsMm']);
    return CrmQuoteLayout(
      paper: CrmJson.str(json['paper'], 'A4'),
      orientation: CrmJson.str(json['orientation'], 'portrait'),
      marginsMm: CrmLayoutMargins(CrmJson.number(m['top'], 15), CrmJson.number(m['right'], 15),
          CrmJson.number(m['bottom'], 15), CrmJson.number(m['left'], 20)),
      fontFamily: CrmJson.str(json['fontFamily'], 'Times New Roman'),
      fontSizePt: CrmJson.number(json['fontSizePt'], 12),
      blocks: CrmJson.list(json['blocks'], CrmLayoutBlock.fromJson),
    );
  }

  /// Kích thước trang (mm) theo khổ và hướng (web `quoteLayoutPageSize`).
  ({double width, double height}) get pageSize {
    final portrait = paper == 'A3' ? (width: 297.0, height: 420.0) : (width: 210.0, height: 297.0);
    return orientation == 'landscape' ? (width: portrait.height, height: portrait.width) : portrait;
  }
}

/// Nhãn mặc định cột bảng hàng (contracts `QUOTE_LAYOUT_LINE_COLUMN_LABELS`; là dữ liệu in, giữ tiếng Việt như web).
const Map<String, String> kCrmLayoutLineColumnLabels = {
  'index': 'TT',
  'materialCode': 'Mã hàng',
  'materialName': 'Tên hàng hoá, dịch vụ',
  'unit': 'ĐVT',
  'quantity': 'Số lượng',
  'listPrice': 'Đơn giá gốc',
  'discountPercent': 'Chiết khấu (%)',
  'unitPrice': 'Đơn giá',
  'lineAmount': 'Thành tiền',
  'vatRate': 'VAT (%)',
  'vatAmount': 'Tiền VAT',
  'lineTotal': 'Tổng cộng',
  'category': 'Nhóm hàng',
};

const Map<String, String> kCrmLayoutTotalRowLabels = {
  'subtotal': 'Cộng tiền hàng',
  'lineDiscount': 'Chiết khấu',
  'orderDiscount': 'Chiết khấu tổng đơn',
  'fees': 'Phí',
  'shipping': 'Phí vận chuyển',
  'vat': 'Thuế GTGT',
  'orderTax': 'Thuế tổng đơn',
  'grandTotal': 'Tổng cộng',
};

/// Bố cục mặc định khi mẫu chưa thiết kế (contracts `defaultQuoteLayout`).
CrmQuoteLayout crmDefaultQuoteLayout() {
  CrmLayoutLineColumn column(String key, double width, String align, bool visible) =>
      CrmLayoutLineColumn(key, kCrmLayoutLineColumnLabels[key]!, width, align, visible);
  CrmLayoutTotalRow total(String key, bool visible) => CrmLayoutTotalRow(key, kCrmLayoutTotalRowLabels[key]!, visible);
  return CrmQuoteLayout(blocks: [
    const CrmLayoutBlock(
      id: 'company',
      type: 'companyHeader',
      name: '{{company.name}}',
      lines: ['Địa chỉ: {{company.address}}', 'Mã số thuế: {{company.taxCode}}', 'Điện thoại: {{company.phone}}', 'Email: {{company.email}}'],
      logoFromOrganization: true,
      logoPosition: 'left',
      align: 'left',
    ),
    const CrmLayoutBlock(id: 'company-divider', type: 'divider', thicknessPt: 1, style: 'solid'),
    const CrmLayoutBlock(
      id: 'title',
      type: 'title',
      text: 'BÁO GIÁ',
      subtitle: 'Số: {{quote.code}} - Ngày: {{quote.date}}',
      fontSizePt: 20,
      align: 'center',
      uppercase: true,
      marginTopMm: 4,
    ),
    const CrmLayoutBlock(id: 'customer', type: 'fieldGrid', columns: 2, labelWidthPct: 35, marginTopMm: 4, items: [
      CrmLayoutLabelValue('Báo giá đến', '{{customer.name}}'),
      CrmLayoutLabelValue('Mã số thuế', '{{customer.taxCode}}'),
      CrmLayoutLabelValue('Địa chỉ', '{{customer.address}}'),
      CrmLayoutLabelValue('Điện thoại', '{{customer.phone}}'),
      CrmLayoutLabelValue('Email', '{{customer.email}}'),
      CrmLayoutLabelValue('Hiệu lực đến', '{{quote.validUntil}}'),
      CrmLayoutLabelValue('Người báo giá', '{{owner.name}}'),
      CrmLayoutLabelValue('Điện thoại', '{{owner.phone}}'),
    ]),
    const CrmLayoutBlock(
      id: 'intro',
      type: 'text',
      align: 'left',
      marginTopMm: 4,
      runs: [CrmLayoutTextRun('Công ty chúng tôi trân trọng gửi tới Quý khách báo giá như sau:', italic: true)],
    ),
    CrmLayoutBlock(id: 'lines', type: 'lineTable', marginTopMm: 2, lineColumns: [
      column('index', 5, 'center', true),
      column('materialCode', 10, 'left', false),
      column('materialName', 30, 'left', true),
      column('unit', 8, 'center', true),
      column('quantity', 8, 'right', true),
      column('listPrice', 12, 'right', false),
      column('discountPercent', 8, 'right', false),
      column('unitPrice', 14, 'right', true),
      column('vatRate', 7, 'right', true),
      column('lineAmount', 14, 'right', true),
      column('vatAmount', 12, 'right', false),
      column('lineTotal', 14, 'right', true),
      column('category', 12, 'left', false),
    ]),
    CrmLayoutBlock(id: 'totals', type: 'totals', align: 'right', showAmountInWords: true, marginTopMm: 2, rows: [
      total('subtotal', true),
      total('lineDiscount', false),
      total('orderDiscount', false),
      total('fees', false),
      total('shipping', false),
      total('vat', true),
      total('orderTax', false),
      total('grandTotal', true),
    ]),
    const CrmLayoutBlock(id: 'terms', type: 'terms', numbered: true, marginTopMm: 4, items: [
      CrmLayoutLabelValue('Hiệu lực báo giá', 'Đến hết ngày {{quote.validUntil}}'),
      CrmLayoutLabelValue('Ghi chú', '{{quote.note}}'),
    ]),
    const CrmLayoutBlock(
      id: 'signature',
      type: 'signature',
      heightMm: 30,
      marginTopMm: 8,
      left: CrmLayoutSignatureParty('ĐẠI DIỆN BÊN MUA', subtitle: '(Ký, ghi rõ họ tên)'),
      right: CrmLayoutSignatureParty('ĐẠI DIỆN BÊN BÁN', subtitle: '(Ký, đóng dấu)', name: '{{owner.name}}'),
    ),
  ]);
}

// --- Biến ----------------------------------------------------------------------------------------------------------

const Set<String> _kVariableKeys = {
  'company.name', 'company.shortName', 'company.address', 'company.taxCode', 'company.phone', 'company.email', //
  'company.website', 'company.bankAccount', 'company.bankName', 'company.representative',
  'company.representativeTitle', 'quote.code', 'quote.name', 'quote.date', 'quote.validUntil', 'quote.priceDate',
  'quote.versionNo', 'quote.typeName', 'quote.templateName', 'quote.note', 'quote.status', 'customer.code',
  'customer.name', 'customer.taxCode', 'customer.address', 'customer.phone', 'customer.email', 'opportunity.code',
  'opportunity.name', 'owner.name', 'owner.email', 'owner.phone', 'totals.subtotal', 'totals.discount', 'totals.fees',
  'totals.vat', 'totals.grandTotal', 'totals.amountInWords', 'today',
};

const String kCrmLayoutCustomPrefix = 'custom.';
final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
final RegExp _token = RegExp(r'(\{*)\{\{([A-Za-z0-9_.-]+)\}\}(\}*)');

bool crmIsLayoutVariable(String name) =>
    _kVariableKeys.contains(name) ||
    (name.startsWith(kCrmLayoutCustomPrefix) && _uuid.hasMatch(name.substring(kCrmLayoutCustomPrefix.length)));

/// Thay biến bằng giá trị, trả chữ thuần (contracts `bindQuoteText`, chế độ `view`): biến hợp lệ không có giá trị thành
/// chuỗi rỗng; biến lạ, ngoặc thừa giữ nguyên văn.
String crmBindQuoteText(String text, Map<String, String> values) {
  final out = StringBuffer();
  var last = 0;
  for (final match in _token.allMatches(text)) {
    if (match.start > last) out.write(text.substring(last, match.start));
    final literal = match.group(1)!.isNotEmpty || match.group(3)!.isNotEmpty;
    final name = match.group(2)!;
    if (literal || !crmIsLayoutVariable(name)) {
      out.write(match.group(0));
    } else {
      final value = values[name];
      if (value != null && value.isNotEmpty) out.write(value);
    }
    last = match.end;
  }
  if (last < text.length) out.write(text.substring(last));
  return out.toString();
}

// --- Định dạng in --------------------------------------------------------------------------------------------------

String _groupThousands(String digits) => digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// Contracts `formatQuoteNumber`: `1.234,5`, bỏ số 0 thừa.
String crmFormatQuoteNumber(num? value, [int maxFractionDigits = 3]) {
  if (value == null || !value.isFinite) return '';
  final fixed = value.abs().toStringAsFixed(maxFractionDigits);
  final parts = fixed.split('.');
  final trimmed = parts.length > 1 ? parts[1].replaceAll(RegExp(r'0+$'), '') : '';
  final body = _groupThousands(parts[0]) + (trimmed.isNotEmpty ? ',$trimmed' : '');
  return value < 0 && body != '0' ? '-$body' : body;
}

double _roundDong(num value) {
  final rounded = value.sign * (value.abs()).roundToDouble();
  return rounded == 0 ? 0 : rounded.toDouble();
}

/// Contracts `formatQuoteMoney`: số nguyên đồng, không ký hiệu.
String crmFormatQuoteMoney(num? value) {
  if (value == null || !value.isFinite) return '';
  return crmFormatQuoteNumber(_roundDong(value), 0);
}

String crmFormatQuotePercent(num? value) {
  final body = crmFormatQuoteNumber(value, 2);
  return body.isEmpty ? '' : '$body%';
}

/// Contracts `formatQuoteDate`: `dd/mm/yyyy` từ `yyyy-mm-dd...`.
String crmFormatQuoteDate(String? value) {
  if (value == null || value.isEmpty) return '';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (m == null) return '';
  return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
}

const List<String> _digitWords = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];

String _readHundreds(int value, bool full) {
  final hundreds = value ~/ 100;
  final tens = (value % 100) ~/ 10;
  final units = value % 10;
  final words = <String>[];
  if (full || hundreds > 0) words.addAll([_digitWords[hundreds], 'trăm']);
  if (tens == 0) {
    if (units > 0 && words.isNotEmpty) words.add('linh');
  } else if (tens == 1) {
    words.add('mười');
  } else {
    words.addAll([_digitWords[tens], 'mươi']);
  }
  if (units > 0) {
    if (units == 1 && tens > 1) {
      words.add('mốt');
    } else if (units == 4 && tens > 1) {
      words.add('tư');
    } else if (units == 5 && tens > 0) {
      words.add('lăm');
    } else {
      words.add(_digitWords[units]);
    }
  }
  return words.join(' ');
}

String _readBelowBillion(int value, bool full) {
  final groups = [value ~/ 1000000, (value % 1000000) ~/ 1000, value % 1000];
  const scales = ['triệu', 'nghìn', ''];
  final words = <String>[];
  var started = full;
  for (var i = 0; i < 3; i++) {
    if (groups[i] == 0) continue;
    words.add(_readHundreds(groups[i], started));
    if (scales[i].isNotEmpty) words.add(scales[i]);
    started = true;
  }
  return words.join(' ');
}

String _readNumber(int value) {
  if (value == 0) return _digitWords[0];
  if (value < 1000000000) return _readBelowBillion(value, false);
  final billions = value ~/ 1000000000;
  final rest = value % 1000000000;
  final head = '${_readNumber(billions)} tỷ';
  return rest > 0 ? '$head ${_readBelowBillion(rest, true)}' : head;
}

/// Contracts `amountInWordsVi`: "Một triệu không trăm linh năm nghìn đồng".
String crmAmountInWordsVi(num? amount) {
  if (amount == null || !amount.isFinite) return '';
  final rounded = _roundDong(amount);
  if (rounded.abs() > 9007199254740991) return '';
  final body = '${_readNumber(rounded.abs().toInt())} đồng';
  final text = rounded < 0 ? 'âm $body' : body;
  return text[0].toUpperCase() + text.substring(1);
}

/// Contracts `companyVariableValues`.
Map<String, String> crmCompanyVariableValues(CrmQuoteSeller? seller) => {
      'company.name': seller?.name ?? '',
      'company.shortName': seller?.shortName ?? '',
      'company.address': seller?.address ?? '',
      'company.taxCode': seller?.taxCode ?? '',
      'company.phone': seller?.phone ?? '',
      'company.email': seller?.email ?? '',
      'company.website': seller?.website ?? '',
      'company.bankAccount': seller?.bankAccount ?? '',
      'company.bankName': seller?.bankName ?? '',
      'company.representative': seller?.representative ?? '',
      'company.representativeTitle': seller?.representativeTitle ?? '',
    };
