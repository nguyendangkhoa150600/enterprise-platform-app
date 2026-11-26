import '../../../domain/common/crm_directory_models.dart';
import '../../../domain/quotes/crm_quote_layout_models.dart';
import '../../../domain/quotes/crm_quote_models.dart';
import '../../../domain/quotes/crm_quote_support_models.dart';

/// Nhãn trạng thái in trên bản báo giá (dữ liệu in, giữ tiếng Việt như contracts `QUOTE_STATUS_LABELS`).
const Map<String, String> _kStatusPrintLabels = {
  'DRAFT': 'Nháp',
  'PENDING': 'Chờ duyệt',
  'REJECTED': 'Từ chối duyệt',
  'APPROVED': 'Đã duyệt',
  'SENT': 'Đã gửi khách',
  'ACCEPTED': 'Khách chấp nhận',
  'DECLINED': 'Khách từ chối',
  'EXPIRED': 'Hết hạn',
  'SUPERSEDED': 'Đã thay thế',
};

/// Một dòng hàng đã định dạng (web `QuoteLayoutLineRow`).
class CrmLayoutLineRow {
  final String id;
  final String category;
  final Map<String, String> cells;
  const CrmLayoutLineRow({required this.id, required this.category, required this.cells});
}

/// Dữ liệu một bản in (web `QuoteLayoutData`): giá trị biến, dòng hàng, dòng tổng đã định dạng sẵn.
class CrmQuoteLayoutData {
  final Map<String, String> values;
  final List<CrmLayoutLineRow> lines;
  final Map<String, String> totals;
  final String amountInWords;
  final String? companyLogo;

  const CrmQuoteLayoutData({
    this.values = const {},
    this.lines = const [],
    this.totals = const {},
    this.amountInWords = '',
    this.companyLogo,
  });

  /// Web `emptyQuoteLayoutData`.
  static const CrmQuoteLayoutData empty = CrmQuoteLayoutData();
}

String _two(int v) => v.toString().padLeft(2, '0');

/// `dd/mm/yyyy` theo giờ máy (web `formatLocalDate`).
String crmFormatLocalDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String _dateValue(String? value) {
  if (value == null || value.isEmpty) return '';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return crmFormatQuoteDate(value);
  final parsed = DateTime.tryParse(value);
  return parsed == null ? crmFormatQuoteDate(value) : crmFormatLocalDate(parsed.toLocal());
}

String _customText(CrmCustomFieldDefinition def, Object? value) {
  if (value == null || value == '') return '';
  if (def.fieldType == 'NUMBER') return value is num ? crmFormatQuoteNumber(value) : value.toString();
  if (def.fieldType == 'DATE') {
    return value is String ? (crmFormatQuoteDate(value).isEmpty ? value : crmFormatQuoteDate(value)) : '';
  }
  return value.toString();
}

/// Web `buildQuoteLayoutData`. Không lấy giá vốn, lợi nhuận (mẫu in không được lộ).
CrmQuoteLayoutData crmBuildQuoteLayoutData({
  required CrmQuoteDetail detail,
  CrmQuoteCustomerInfo? customer,
  List<CrmPerson> people = const [],
  List<CrmCustomFieldDefinition> customFields = const [],
  DateTime? now,
}) {
  final version = detail.version;
  final form = version.form;
  final totals = version.totals;
  CrmPerson? owner;
  for (final p in people) {
    if (p.userId == detail.ownerUserId) owner = p;
  }
  final orderDiscount = form.discountMode == 'ORDER' ? form.orderDiscount.amount : 0.0;
  final orderTax = form.taxMode == 'ORDER' ? form.orderTax.amount : 0.0;
  final lineTax = form.taxMode == 'LINE';

  final values = <String, String>{
    ...crmCompanyVariableValues(form.seller),
    'quote.code': detail.code,
    'quote.name': form.quoteName ?? detail.quoteName ?? '',
    'quote.date': form.quoteDate != null && form.quoteDate!.isNotEmpty
        ? _dateValue(form.quoteDate)
        : _dateValue(version.createdAt.isNotEmpty ? version.createdAt : detail.createdAt),
    'quote.validUntil': _dateValue(version.validUntil),
    'quote.priceDate': _dateValue(version.priceDate),
    'quote.versionNo': '${version.versionNo}',
    'quote.typeName': form.quoteTypeName ?? '',
    'quote.templateName': form.templateName ?? '',
    'quote.note': version.note ?? '',
    'quote.status': _kStatusPrintLabels[version.status] ?? '',
    'customer.code': customer?.code ?? detail.customerCode,
    'customer.name': customer?.name ?? detail.customerName,
    'customer.taxCode': customer?.taxCode ?? '',
    'customer.address': customer?.address ?? '',
    'customer.phone': customer?.phone ?? '',
    'customer.email': customer?.email ?? '',
    'opportunity.code': '',
    'opportunity.name': detail.opportunityId != null ? (detail.opportunityName ?? '') : '',
    'owner.name': owner?.displayName ?? '',
    'owner.email': '',
    'owner.phone': '',
    'totals.subtotal': crmFormatQuoteMoney(totals.netAmount + orderDiscount),
    'totals.discount': crmFormatQuoteMoney(totals.discountAmount),
    'totals.fees': crmFormatQuoteMoney(form.feesAmount),
    'totals.vat': crmFormatQuoteMoney(totals.vatAmount),
    'totals.grandTotal': crmFormatQuoteMoney(totals.totalAmount),
    'totals.amountInWords': crmAmountInWordsVi(totals.totalAmount),
    'today': crmFormatLocalDate(now ?? DateTime.now()),
  };

  final defs = {for (final d in customFields) d.id: d};
  form.customFields.forEach((id, value) {
    final def = defs[id];
    if (def == null) return;
    values['$kCrmLayoutCustomPrefix$id'] = _customText(def, value);
  });

  final lines = <CrmLayoutLineRow>[];
  for (var i = 0; i < version.lines.length; i++) {
    final line = version.lines[i];
    lines.add(
      CrmLayoutLineRow(
        id: line.id,
        category: line.category ?? '',
        cells: {
          'index': '${i + 1}',
          'materialCode': line.materialCode,
          'materialName': line.materialName,
          'unit': line.unit,
          'quantity': crmFormatQuoteNumber(line.quantity),
          'listPrice': crmFormatQuoteMoney(line.listPrice),
          'discountPercent': line.discountPercent != 0 ? crmFormatQuotePercent(line.discountPercent) : '',
          'unitPrice': crmFormatQuoteMoney(line.unitPrice),
          'lineAmount': crmFormatQuoteMoney(line.lineAmount),
          'vatRate': lineTax ? crmFormatQuotePercent(line.vatRate) : '',
          'vatAmount': lineTax ? crmFormatQuoteMoney(line.vatAmount) : '',
          'lineTotal': crmFormatQuoteMoney(lineTax ? line.lineTotal : line.lineAmount),
          'category': line.category ?? '',
        },
      ),
    );
  }

  return CrmQuoteLayoutData(
    values: values,
    lines: lines,
    totals: {
      'subtotal': crmFormatQuoteMoney(totals.netAmount + orderDiscount),
      'lineDiscount': crmFormatQuoteMoney(totals.discountAmount - orderDiscount),
      'orderDiscount': crmFormatQuoteMoney(orderDiscount),
      'fees': crmFormatQuoteMoney(form.feesAmount),
      'shipping': crmFormatQuoteMoney(totals.shippingAmount),
      'vat': crmFormatQuoteMoney(totals.vatAmount),
      'orderTax': crmFormatQuoteMoney(orderTax),
      'grandTotal': crmFormatQuoteMoney(totals.totalAmount),
    },
    amountInWords: crmAmountInWordsVi(totals.totalAmount),
    companyLogo: (version.sellerLogo ?? '').isEmpty ? null : version.sellerLogo,
  );
}

/// Web `visibleLineColumns`: cột hiện, độ rộng chuẩn hoá về 100%.
List<CrmLayoutLineColumn> crmVisibleLineColumns(CrmLayoutBlock block) {
  final visible = block.lineColumns.where((c) => c.visible).toList();
  final total = visible.fold<double>(0, (s, c) => s + c.widthPct);
  return visible.map((c) => c.withWidth(total > 0 ? c.widthPct / total * 100 : 100 / visible.length)).toList();
}

/// Một hàng bảng in: tiêu đề nhóm ([group] khác null) hoặc dòng hàng.
class CrmLayoutTableRow {
  final String? group;
  final CrmLayoutLineRow? line;
  final bool stripe;
  const CrmLayoutTableRow({this.group, this.line, this.stripe = false});
}

/// Web `lineTableRows`.
List<CrmLayoutTableRow> crmLineTableRows(CrmLayoutBlock block, List<CrmLayoutLineRow> lines, String ungroupedLabel) {
  final rows = <CrmLayoutTableRow>[];
  String? current;
  var stripe = false;
  for (final line in lines) {
    if (block.showGroupByCategory && line.category != current) {
      current = line.category;
      rows.add(CrmLayoutTableRow(group: line.category.isEmpty ? ungroupedLabel : line.category));
      stripe = false;
    }
    rows.add(CrmLayoutTableRow(line: line, stripe: stripe));
    stripe = !stripe;
  }
  return rows;
}

/// Logo khối đầu trang (web `companyHeaderLogo`).
String? crmCompanyHeaderLogo(CrmLayoutBlock block, CrmQuoteLayoutData data) {
  if (block.logoFromOrganization && (data.companyLogo ?? '').isNotEmpty) return data.companyLogo;
  return block.logo;
}

final RegExp _embedded = RegExp(r'^data:image/(png|jpeg);base64,([A-Za-z0-9+/]+=*)$');

/// Ảnh nhúng PNG/JPEG (web `isEmbeddedImage`): trả `(type, base64)` hoặc null.
({String type, String base64})? crmEmbeddedImage(String? src) {
  if (src == null) return null;
  final m = _embedded.firstMatch(src);
  if (m == null) return null;
  return (type: m.group(1)!, base64: m.group(2)!);
}
