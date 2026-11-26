// Port 1:1 `components/rcsi/finance-step.spec.ts` (web).
import 'package:flutter_test/flutter_test.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/logic/rcsi_finance_step.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/logic/vietnamese_text.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/rcsi_definition_models.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/rcsi_flow_models.dart';

ProcedureAttributeDefinition attribute(String code, String type, [String? name]) =>
    ProcedureAttributeDefinition(id: 'a-$code', code: code, name: name ?? code, type: type);

ProcedureStepDefinition step(String id, int order, [List<ProcedureAttributeDefinition>? attributes]) =>
    ProcedureStepDefinition(id: id, key: id.toUpperCase(), order: order, name: 'Bước $id', attributes: attributes);

/// Lập đề nghị → (nhánh a | nhánh b) → chi tiền.
ProcedureDefinition definition() => ProcedureDefinition(
      id: 'def',
      code: 'DNTT',
      name: 'Đề nghị thanh toán',
      status: 'draft',
      attributes: [attribute('noi_dung', 'text', 'Nội dung đề nghị')],
      steps: [
        step('lap', 1, [attribute('so_tien', 'money', 'Số tiền đề nghị'), attribute('ghi_chu', 'text')]),
        step('a', 2, [attribute('amount', 'number')]),
        step('b', 3),
        step('chi', 4, [attribute('tong_tien', 'money')]),
      ],
      gateways: const [
        ProcedureGatewayDefinition(
          id: 'g1',
          key: 'G1',
          name: 'Theo giá trị',
          afterStepId: 'lap',
          branches: [
            ProcedureBranchDefinition(id: 'n1', key: 'N1', label: 'Lớn', isDefault: false, stepIds: ['a']),
            ProcedureBranchDefinition(id: 'n2', key: 'N2', label: 'Nhỏ', isDefault: true, stepIds: ['b']),
          ],
        ),
      ],
    );

void main() {
  group('bước Tài chính trên màn thiết kế', () {
    test('chỉ chào mời thuộc tính cấp quy trình và của bước chắc chắn đã đi qua', () {
      final keys = financeAttributeCandidates(definition(), 'chi').map((item) => item.key).toList();
      expect(keys, ['process:noi_dung', 'step:lap:so_tien', 'step:lap:ghi_chu']);
    });

    test('lọc theo kiểu và tự khớp theo thứ tự mã của server', () {
      final candidates = financeAttributeCandidates(definition(), 'chi');
      expect(candidatesForField('amount', candidates).map((item) => item.key).toList(), ['step:lap:so_tien']);
      expect(autoMatchedCandidate('amount', candidates)?.key, 'step:lap:so_tien');
      expect(autoMatchedCandidate('content', candidates)?.key, 'process:noi_dung');
      expect(autoMatchedCandidate('voucherDate', candidates), isNull);
    });

    test('bước nhận hồ sơ khi trả về là các bước chắc chắn đứng trước', () {
      expect(financeReturnTargets(definition(), 'chi').map((item) => item.id).toList(), ['lap']);
    });

    test('bỏ ánh xạ trống trước khi gửi', () {
      expect(
        cleanIntegration(const ProcedureStepIntegration(
          voucherKind: 'PAYMENT',
          mapping: {'amount': 'step:lap:so_tien', 'content': ''},
        )).toJson(),
        {
          'module': 'finance',
          'action': 'voucher',
          'voucherKind': 'PAYMENT',
          'mapping': {'amount': 'step:lap:so_tien'},
        },
      );
      expect(
        cleanIntegration(const ProcedureStepIntegration(voucherKind: 'RECEIPT', mapping: {})).toJson(),
        {'module': 'finance', 'action': 'voucher', 'voucherKind': 'RECEIPT'},
      );
    });
  });

  group('thẻ phiếu trên hồ sơ', () {
    ProcedureStepFinanceVoucher voucher(String state,
            {int activation = 1, String? code, num? amount, String? postedByName, String? returnedReason}) =>
        ProcedureStepFinanceVoucher(
          activation: activation,
          state: state,
          requestedAt: '2026-10-15T00:00:00Z',
          code: code,
          amount: amount,
          postedByName: postedByName,
          returnedReason: returnedReason,
        );

    test('hiển thị theo tiến trình phiếu', () {
      expect(financeVoucherCard(voucher('requested')).title, 'Chờ Tài chính tạo phiếu');
      expect(financeVoucherCard(voucher('requested', activation: 2, code: 'NHAP_PC_2610_0045')).title,
          'NHAP_PC_2610_0045 · Chờ Tài chính cập nhật phiếu');
      expect(financeVoucherCard(voucher('linked', code: 'NHAP_PC_2610_0045', amount: 12500000)).title,
          'NHAP_PC_2610_0045 · Chờ ghi sổ · 12.500.000 đ');
      expect(
        financeVoucherCard(voucher('posted', code: 'PC-2610-0045', amount: 1000, postedByName: 'Kế toán A')).title,
        'PC-2610-0045 · Đã ghi sổ bởi Kế toán A · 1.000 đ',
      );
      final returned = financeVoucherCard(voucher('returned', returnedReason: 'Thiếu hoá đơn'));
      expect(returned.title, 'Kế toán đã trả hồ sơ');
      expect(returned.detail, 'Lý do: Thiếu hoá đơn');
    });

    test('dựng link mở phiếu theo loại phiếu', () {
      expect(financeVoucherHref('PAYMENT', 'v1'), '/modules/finance/payments/v1');
      expect(financeVoucherHref('RECEIPT', 'v2'), '/modules/finance/receipts/v2');
    });

    test('định dạng số kiểu vi-VN', () {
      expect(formatViNumber(12500000), '12.500.000');
      expect(formatViNumber(1234.5), '1.234,5');
    });
  });
}
