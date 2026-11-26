// Port spec web: quotes/quote.model.spec.ts, quotes/quote-form-edit.model.spec.ts,
// contracts quote-layout.spec.ts (số tiền bằng chữ, định dạng), quote-layout.data (dòng tổng theo chế độ mẫu).
import 'package:flutter_test/flutter_test.dart';
import 'package:power_quality_analysis/features/crm/domain/crm_capabilities.dart';
import 'package:power_quality_analysis/features/crm/domain/quotes/crm_quote_layout_models.dart';
import 'package:power_quality_analysis/features/crm/domain/quotes/crm_quote_models.dart';
import 'package:power_quality_analysis/features/crm/domain/quotes/crm_quote_support_models.dart';
import 'package:power_quality_analysis/features/crm/presentation/quotes/crm_quote_logic.dart';
import 'package:power_quality_analysis/features/crm/presentation/quotes/layout/crm_quote_layout_data.dart';

CrmQuoteDetail _detail({
  String status = 'DRAFT',
  int versionNo = 1,
  int currentVersion = 1,
  String? submittedBy = 'nv1',
  Map<String, dynamic>? procedure,
  int versions = 1,
  String owner = 'u1',
  Map<String, dynamic> form = const {},
  Map<String, dynamic> totals = const {},
  List<Map<String, dynamic>> lines = const [],
}) =>
    CrmQuoteDetail.fromJson({
      'id': 'q1',
      'code': 'BG1',
      'customerId': 'c1',
      'customerCode': 'KH1',
      'customerName': 'Khách 1',
      'ownerUserId': owner,
      'status': status,
      'currentVersion': currentVersion,
      'totalAmount': 0,
      'updatedAt': '2026-11-01T00:00:00Z',
      'createdAt': '2026-11-01T00:00:00Z',
      'versions': List.generate(versions, (i) => {'versionNo': i + 1, 'status': status, 'totalAmount': 0, 'createdAt': ''}),
      'version': {
        'id': 'v1',
        'versionNo': versionNo,
        'status': status,
        'revision': 1,
        'submittedBy': submittedBy,
        'createdAt': '2026-11-01T00:00:00Z',
        'shipping': {'amount': 0, 'vatRate': 10, 'cost': 0},
        'totals': totals,
        'form': form,
        'lines': lines,
      },
      'procedure': procedure,
      'history': const [],
    });

const _writer = CrmCapabilities(canWriteQuote: true);
const _lead = CrmCapabilities(canWriteQuote: true, canApproveQuote: true);

void main() {
  group('quoteActions', () {
    test('nút theo trạng thái và quyền', () {
      expect(crmQuoteActions(_detail(status: 'DRAFT'), _writer, null), ['edit', 'submit']);
      expect(crmQuoteActions(_detail(status: 'APPROVED'), _writer, null), ['revise', 'send']);
      expect(crmQuoteActions(_detail(status: 'SENT'), _writer, null), ['revise', 'accept', 'decline']);
      expect(crmQuoteActions(_detail(status: 'PENDING'), _writer, null), isEmpty);
      expect(crmQuoteActions(_detail(status: 'PENDING'), _lead, 'tn'), ['approve', 'reject']);
      expect(crmQuoteActions(_detail(status: 'EXPIRED'), _lead, null), isEmpty);
    });

    test('không tự duyệt; đang duyệt qua Quy trình thì không duyệt tay; phiên bản cũ không có nút', () {
      expect(crmQuoteActions(_detail(status: 'PENDING'), _lead, 'nv1'), isEmpty);
      final running = {'id': 'l', 'status': 'RUNNING', 'instanceId': 'i', 'attempts': 1};
      expect(crmQuoteActions(_detail(status: 'PENDING', procedure: running), _lead, 'tn'), isEmpty);
      expect(crmQuoteActions(_detail(status: 'APPROVED', currentVersion: 2), _writer, null), isEmpty);
    });

    test('số có dấu', () {
      String plain(double v) => crmNumText(v);
      expect(crmSigned(1000, plain), '+1000');
      expect(crmSigned(-5, plain), '-5');
      expect(crmSigned(0, plain), '0');
    });
  });

  group('canDeleteQuote', () {
    test('người phụ trách xoá được báo giá Nháp, Chờ duyệt có một phiên bản', () {
      expect(crmCanDeleteQuote(_detail(status: 'DRAFT'), _writer, 'u1'), isTrue);
      expect(crmCanDeleteQuote(_detail(status: 'PENDING'), _writer, 'u1'), isTrue);
    });
    test('đã duyệt, đã gửi, hoặc có phiên bản trước: không xoá', () {
      expect(crmCanDeleteQuote(_detail(status: 'APPROVED'), _writer, 'u1'), isFalse);
      expect(crmCanDeleteQuote(_detail(status: 'SENT'), _writer, 'u1'), isFalse);
      expect(crmCanDeleteQuote(_detail(status: 'DRAFT', versions: 2), const CrmCapabilities(canWriteQuote: true, canManage: true), 'u1'),
          isFalse);
    });
    test('người khác chỉ xoá được khi có quyền quản trị bán hàng', () {
      expect(crmCanDeleteQuote(_detail(status: 'DRAFT'), _writer, 'u2'), isFalse);
      expect(crmCanDeleteQuote(_detail(status: 'DRAFT'), const CrmCapabilities(canWriteQuote: true, canManage: true), 'u2'), isTrue);
      expect(crmCanDeleteQuote(_detail(status: 'DRAFT'), CrmCapabilities.none, 'u1'), isFalse);
    });
  });

  group('chiết khấu, thuế tổng đơn', () {
    test('ô bị khoá khi ô kia có giá trị', () {
      expect(const CrmOrderAmountText(percent: '10').locked, 'amount');
      expect(const CrmOrderAmountText(amount: '1').locked, 'percent');
      expect(const CrmOrderAmountText().locked, isNull);
    });
    test('dựng yêu cầu: rỗng là null, phần trăm, số tiền, lỗi', () {
      final empty = crmBuildOrderAmount(const CrmOrderAmountText(), 'tax');
      expect(empty.value, isNull);
      expect(empty.error, isNull);
      expect(crmBuildOrderAmount(const CrmOrderAmountText(percent: '8,5'), 'tax').value, {'percent': 8.5});
      expect(crmBuildOrderAmount(const CrmOrderAmountText(amount: '1.000.000'), 'discount').value, {'amount': 1000000});
      expect(crmBuildOrderAmount(const CrmOrderAmountText(percent: '101'), 'tax').error, isNotNull);
      expect(crmBuildOrderAmount(const CrmOrderAmountText(percent: '5', amount: '5'), 'tax').error, isNotNull);
      expect(crmBuildOrderAmount(const CrmOrderAmountText(amount: '-1'), 'discount').error, isNotNull);
    });
    test('điền lại theo kiểu đã nhập', () {
      final p = CrmOrderAmountText.of(const CrmQuoteOrderAmount(percent: 5, amount: 100, inputKind: 'PERCENT'));
      expect([p.percent, p.amount], ['5', '']);
      final a = CrmOrderAmountText.of(const CrmQuoteOrderAmount(percent: 5, amount: 100, inputKind: 'AMOUNT'));
      expect([a.percent, a.amount], ['', '100']);
      final n = CrmOrderAmountText.of(const CrmQuoteOrderAmount());
      expect([n.percent, n.amount], ['', '']);
    });
    test('mẫu quyết định chế độ', () {
      expect(crmTemplateModes(null, null), (discount: 'LINE', tax: 'LINE'));
      expect(crmTemplateModes('ORDER', 'LINE'), (discount: 'ORDER', tax: 'LINE'));
    });
    test('đọc số kiểu Việt và kiểu quốc tế', () {
      expect(crmParseDecimal('1.234,5'), 1234.5);
      expect(crmParseDecimal('1,234.5'), 1234.5);
      expect(crmParseDecimal('1,5'), 1.5);
      expect(crmParseDecimal('1,000,000'), 1000000);
      expect(crmParseDecimal('1.000.000'), 1000000);
      expect(crmParseDecimal('abc'), isNull);
      expect(crmParseDecimal(' '), isNull);
    });
  });

  group('khoản phí', () {
    test('bỏ dòng trống, kiểm số tiền', () {
      final ok = crmBuildFees([CrmFeeRow(), CrmFeeRow(feeType: 'Vận hành', amount: '1000')]);
      expect(ok.error, isNull);
      expect(ok.fees, [
        {'feeType': 'Vận hành', 'amount': 1000.0}
      ]);
      expect(crmBuildFees([CrmFeeRow(feeType: 'A', amount: '-1')]).error, isNotNull);
      expect(crmBuildFees([CrmFeeRow(feeType: 'A')]).error, isNotNull);
      expect(crmBuildFees(List.generate(21, (_) => CrmFeeRow(feeType: 'A', amount: '1'))).error, isNotNull);
    });
  });

  group('trường tuỳ biến', () {
    CrmCustomFieldDefinition field(String id,
            {String name = 'Nguồn', String type = 'TEXT', List<String> options = const [], bool required = false, int sort = 1, bool active = true}) =>
        CrmCustomFieldDefinition(
            id: id, name: name, fieldType: type, options: options, required: required, sortOrder: sort, active: active);

    test('báo tên trường bắt buộc còn thiếu', () {
      final defs = [
        field('a', name: 'Nguồn', required: true),
        field('b', name: 'Ghi chú', required: true, sort: 2),
        field('c', required: true, active: false),
      ];
      expect(crmMissingRequiredFields(defs, {'a': 'x'}), ['Ghi chú']);
    });
    test('dựng giá trị theo kiểu; rỗng là null', () {
      final defs = [
        field('n', type: 'NUMBER'),
        field('s', type: 'SELECT', options: ['A', 'B'], sort: 2),
        field('t', sort: 3),
      ];
      final built = crmBuildCustomFields(defs, {'n': '12,5', 's': 'A'});
      expect(built.error, isNull);
      expect(built.values, {'n': 12.5, 's': 'A', 't': null});
      expect(crmBuildCustomFields(defs, {'n': 'x'}).error, isNotNull);
      expect(crmBuildCustomFields(defs, {'s': 'Z'}).error, isNotNull);
    });
  });

  group('khối thông tin thêm (buildQuoteDetailsPatch)', () {
    const modesLine = (discount: 'LINE', tax: 'LINE');
    const modesOrder = (discount: 'ORDER', tax: 'ORDER');
    test('vận chuyển: rỗng là null; chỉ chi phí bên bán vẫn gửi', () {
      final none = crmBuildQuoteDetailsPatch(const CrmQuoteDetailsState(shippingVat: '10'), const [], modesLine);
      expect(none.error, isNull);
      expect(none.patch['shipping'], isNull);
      expect(none.patch.containsKey('orderDiscount'), isFalse);
      final cost = crmBuildQuoteDetailsPatch(const CrmQuoteDetailsState(shippingCost: '50.000', shippingVat: '8'), const [], modesLine);
      // Giống web `parseDecimal`: một dấu chấm duy nhất là dấu thập phân ("50.000" → 50).
      expect(cost.patch['shipping'], {'amount': 0.0, 'vatRate': 8.0, 'cost': 50.0});
      expect(crmBuildQuoteDetailsPatch(const CrmQuoteDetailsState(shipping: '-1'), const [], modesLine).error, isNotNull);
      expect(crmBuildQuoteDetailsPatch(const CrmQuoteDetailsState(shippingCost: 'x'), const [], modesLine).error, isNotNull);
    });
    test('chiết khấu, thuế tổng đơn chỉ gửi khi mẫu tính theo tổng đơn', () {
      const state = CrmQuoteDetailsState(discount: CrmOrderAmountText(percent: '5'), tax: CrmOrderAmountText(amount: '1000'));
      final line = crmBuildQuoteDetailsPatch(state, const [], modesLine);
      expect(line.patch.containsKey('orderDiscount'), isFalse);
      expect(line.patch.containsKey('orderTax'), isFalse);
      final order = crmBuildQuoteDetailsPatch(state, const [], modesOrder);
      expect(order.patch['orderDiscount'], {'percent': 5.0});
      expect(order.patch['orderTax'], {'amount': 1000.0});
      final cleared = crmBuildQuoteDetailsPatch(const CrmQuoteDetailsState(), const [], modesOrder);
      expect(cleared.patch.containsKey('orderDiscount'), isTrue);
      expect(cleared.patch['orderDiscount'], isNull);
    });
  });

  group('số tiền bằng chữ (TC-TL-03)', () {
    final cases = <num, String>{
      0: 'Không đồng',
      5: 'Năm đồng',
      10: 'Mười đồng',
      15: 'Mười lăm đồng',
      21: 'Hai mươi mốt đồng',
      24: 'Hai mươi tư đồng',
      25: 'Hai mươi lăm đồng',
      101: 'Một trăm linh một đồng',
      105: 'Một trăm linh năm đồng',
      1000: 'Một nghìn đồng',
      1005000: 'Một triệu không trăm linh năm nghìn đồng',
      1000000000: 'Một tỷ đồng',
      1234567890: 'Một tỷ hai trăm ba mươi tư triệu năm trăm sáu mươi bảy nghìn tám trăm chín mươi đồng',
      999999999999:
          'Chín trăm chín mươi chín tỷ chín trăm chín mươi chín triệu chín trăm chín mươi chín nghìn chín trăm chín mươi chín đồng',
      1500.6: 'Một nghìn năm trăm linh một đồng',
      -2000: 'Âm hai nghìn đồng',
      2000000005: 'Hai tỷ không trăm linh năm đồng',
    };
    cases.forEach((amount, words) {
      test('$amount', () => expect(crmAmountInWordsVi(amount), words));
    });
    test('không phải số: chuỗi rỗng', () {
      expect(crmAmountInWordsVi(double.nan), '');
      expect(crmAmountInWordsVi(null), '');
    });
  });

  group('định dạng in', () {
    test('tiền, số, phần trăm, ngày theo kiểu Việt Nam', () {
      expect(crmFormatQuoteMoney(1234567), '1.234.567');
      expect(crmFormatQuoteMoney(1234567.6), '1.234.568');
      expect(crmFormatQuoteMoney(-1000), '-1.000');
      expect(crmFormatQuoteMoney(0), '0');
      expect(crmFormatQuoteMoney(-0.4), '0');
      expect(crmFormatQuoteMoney(2.5), '3');
      expect(crmFormatQuoteMoney(-2.5), '-3');
      expect(crmFormatQuoteNumber(1234.5), '1.234,5');
      expect(crmFormatQuotePercent(10), '10%');
      expect(crmFormatQuotePercent(7.5), '7,5%');
      expect(crmFormatQuoteDate('2026-11-06'), '06/11/2026');
      expect(crmFormatQuoteDate('2026-11-06T10:00:00.000Z'), '06/11/2026');
      expect(crmFormatQuoteDate(null), '');
    });
  });

  group('dữ liệu in: dòng tổng theo chế độ mẫu (buildQuoteLayoutData)', () {
    final line = {
      'id': 'l1',
      'lineNo': 1,
      'materialId': 'm1',
      'materialCode': 'VT1',
      'materialName': 'Máy bơm',
      'unit': 'Cái',
      'quantity': 2,
      'listPrice': 1000000,
      'discountPercent': 5,
      'unitPrice': 950000,
      'lineAmount': 1900000,
      'vatRate': 10,
      'vatAmount': 190000,
      'lineTotal': 2090000,
    };
    const totals = {
      'grossAmount': 2000000,
      'discountAmount': 300000,
      'netAmount': 1700000,
      'shippingAmount': 0,
      'vatAmount': 170000,
      'totalAmount': 1870000,
    };

    test('mẫu theo tổng đơn: tạm tính cộng lại chiết khấu tổng đơn, cột VAT dòng để trống', () {
      final d = _detail(
        totals: totals,
        lines: [line],
        form: {
          'discountMode': 'ORDER',
          'taxMode': 'ORDER',
          'orderDiscount': {'percent': 10.5263, 'amount': 200000, 'inputKind': 'AMOUNT'},
          'orderTax': {'percent': 10, 'amount': 170000, 'inputKind': 'PERCENT'},
          'fees': const [],
          'feesAmount': 0,
        },
      );
      final data = crmBuildQuoteLayoutData(detail: d);
      expect(data.totals['subtotal'], '1.900.000');
      expect(data.totals['lineDiscount'], '100.000');
      expect(data.totals['orderDiscount'], '200.000');
      expect(data.totals['orderTax'], '170.000');
      expect(data.totals['grandTotal'], '1.870.000');
      expect(data.lines.single.cells['vatRate'], '');
      expect(data.lines.single.cells['vatAmount'], '');
      expect(data.lines.single.cells['lineTotal'], '1.900.000');
      expect(data.amountInWords, 'Một triệu tám trăm bảy mươi nghìn đồng');
    });

    test('mẫu theo dòng: VAT trên từng dòng, không có chiết khấu/thuế tổng đơn', () {
      final d = _detail(totals: totals, lines: [line], form: {'discountMode': 'LINE', 'taxMode': 'LINE'});
      final data = crmBuildQuoteLayoutData(detail: d);
      expect(data.totals['subtotal'], '1.700.000');
      expect(data.totals['orderDiscount'], '0');
      expect(data.totals['lineDiscount'], '300.000');
      final cells = data.lines.single.cells;
      expect(cells['discountPercent'], '5%');
      expect(cells['vatRate'], '10%');
      expect(cells['vatAmount'], '190.000');
      expect(cells['lineTotal'], '2.090.000');
    });
  });
}
