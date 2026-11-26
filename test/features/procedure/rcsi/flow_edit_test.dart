// Port 1:1 `components/rcsi/flow-edit.spec.ts` (web) + kiểm thêm phễu ghi của bảng.
import 'package:flutter_test/flutter_test.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/logic/rcsi_board_ops.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/logic/rcsi_columns.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/logic/rcsi_flow_edit.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/rcsi_definition_models.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/rcsi_flow_models.dart';

ProcedureStepDefinition step(String id, int order) =>
    ProcedureStepDefinition(id: id, key: id.toUpperCase(), order: order, name: id);

CreateProcedureStepInput toInput(ProcedureStepDefinition item) =>
    CreateProcedureStepInput(key: item.key, order: item.order, name: item.name);

ProcedureBranchDefinition branch(String id, String key, String label, bool isDefault, List<String> stepIds) =>
    ProcedureBranchDefinition(id: id, key: key, label: label, isDefault: isDefault, stepIds: stepIds);

/// Giống quy trình Thanh lý hợp đồng: 1 bước lập, 3 nhánh (3, 2, 1 bước), rồi bước hợp.
ProcedureDefinition definition() => ProcedureDefinition(
      id: 'def',
      code: 'THANH-LY',
      name: 'Thanh lý',
      status: 'draft',
      steps: [
        for (final (index, id) in ['lap', 'a1', 'a2', 'a3', 'b1', 'b2', 'c1', 'ky'].indexed) step(id, index + 1),
      ],
      gateways: [
        ProcedureGatewayDefinition(
          id: 'g1',
          key: 'G1',
          name: 'Theo công nợ',
          afterStepId: 'lap',
          branches: [
            branch('n1', 'N1', 'Còn nợ trên 100tr', false, ['a1', 'a2', 'a3']),
            branch('n2', 'N2', 'Còn nợ', false, ['b1', 'b2']),
            branch('n3', 'N3', 'Không công nợ', true, ['c1']),
          ],
        ),
      ],
    );

ProcedureDefinition withSteps(ProcedureDefinition base, List<ProcedureStepDefinition> steps,
        List<ProcedureGatewayDefinition> gateways) =>
    ProcedureDefinition(
      id: base.id,
      code: base.code,
      name: base.name,
      status: base.status,
      steps: steps,
      gateways: gateways,
    );

void main() {
  group('flowRowInfo — số hiển thị', () {
    test('trục chính đếm liên tục bỏ qua bước trong nhánh; bước nhánh là chữ + vị trí', () {
      final info = flowRowInfo(definition());
      final labels = ['lap', 'a1', 'a2', 'a3', 'b1', 'b2', 'c1', 'ky'].map((id) => info[id]?.label).toList();
      expect(labels, ['1', 'A1', 'A2', 'A3', 'B1', 'B2', 'C1', '2']);
    });

    test('đánh dấu bước cuối của mỗi nhánh', () {
      final info = flowRowInfo(definition());
      expect(['a3', 'b2', 'c1'].every((id) => info[id]?.branch?.isLast == true), true);
      expect(info['a1']?.branch?.isLast, false);
    });

    test('chữ nhánh chạy tiếp qua điểm rẽ nhánh thứ hai', () {
      final base = definition();
      final second = withSteps(base, [...base.steps, step('d1', 9), step('e1', 10), step('ket', 11)], [
        ...base.gateways!,
        ProcedureGatewayDefinition(
          id: 'g2',
          key: 'G2',
          name: 'Theo hình thức',
          afterStepId: 'ky',
          branches: [branch('m1', 'M1', 'Online', false, ['d1']), branch('m2', 'M2', 'Ngược lại', true, ['e1'])],
        ),
      ]);
      expect(branchLetters(second).values.toList(), ['A', 'B', 'C', 'D', 'E']);
      expect(flowRowInfo(second)['ket']?.label, '3');
    });
  });

  group('addStepToBranch', () {
    test('thêm bước vào cuối nhánh, tham chiếu bằng key, order liền mạch theo cấu trúc', () {
      final change = addStepToBranch(
        definition(),
        const BranchTarget(gatewayId: 'g1', branchId: 'n2'),
        'Kế toán xác nhận',
        toInput,
      );
      final added = change.steps.where((item) => item.name == 'Kế toán xác nhận').firstOrNull;
      expect(added, isNotNull);
      expect(change.gateways[0].branches[1].stepIds, ['b1', 'b2', added!.key]);
      num? orderOf(String key) => change.steps.where((item) => item.key == key).firstOrNull?.order;
      expect(orderOf(added.key), (orderOf('B2') ?? 0) + 1);
      expect(orderOf('KY'), change.steps.length);
    });

    test('thêm được vào nhánh rỗng', () {
      final base = definition();
      final empty = withSteps(base, base.steps, [
        for (final gateway in base.gateways!)
          gateway.copyWith(
            branches: [
              for (final b in gateway.branches) b.id == 'n3' ? b.copyWith(stepIds: const []) : b,
            ],
          ),
      ]);
      final change = addStepToBranch(empty, const BranchTarget(gatewayId: 'g1', branchId: 'n3'), 'Bước C1', toInput);
      expect(change.gateways[0].branches[2].stepIds, hasLength(1));
    });
  });

  group('thao tác luồng khác', () {
    test('removeFlowStep dọn khỏi nhánh và đánh lại order', () {
      final change = removeFlowStep(definition(), 'b1', toInput);
      expect(change.steps.any((item) => item.key == 'B1'), false);
      expect(change.gateways[0].branches[1].stepIds, ['b2']);
      expect(change.steps.map((item) => item.order).toList(), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('moveStepToBranch về trục chính đặt sau điểm hợp', () {
      final change = moveStepToBranch(definition(), 'a1', null, toInput);
      expect(change.gateways[0].branches[0].stepIds, ['a2', 'a3']);
      expect(change.steps.last.key, 'A1');
    });

    test('addGateway sẵn nhánh điều kiện và nhánh mặc định', () {
      final change = addGateway(definition(), 'ky', toInput);
      final gateway = change.gateways.last;
      expect(gateway.key, 'G2');
      expect(gateway.name, 'Điểm rẽ nhánh');
      expect(gateway.branches.map((b) => b.label).toList(), ['Nhánh 1', 'Ngược lại']);
      expect(gateway.branches.last.isDefault, true);
    });

    test('rcsiAddStep: mã B<n> không trùng, tên theo số trục chính', () {
      final update = rcsiAddStep(definition());
      expect(update.steps.last.key, 'B9');
      expect(update.steps.last.name, 'Bước 3');
      expect(update.toJson().containsKey('gateways'), false);
    });

    test('rcsiWriteCell: cột "Toàn bộ nhân viên" luôn lưu nhãn web dù nhãn hiển thị đã dịch', () {
      const everyone = MatrixColumn(
        key: 'everyone',
        subjectType: ProcedureSubjectType.everyone,
        subjectId: procedureEveryoneSubjectId,
        label: 'All employees',
      );
      final change = ProcedureRaciAssignment(
        id: '',
        role: 'S',
        subjectType: everyone.subjectType,
        subjectId: everyone.subjectId,
      );
      final update = rcsiWriteCell(definition(), 'lap', everyone, change);
      final assignment = update.steps.firstWhere((item) => item.key == 'LAP').assignments.single;
      expect(assignment.subjectLabel, 'Toàn bộ nhân viên');
      expect(assignment.role, 'S');
    });
  });
}
