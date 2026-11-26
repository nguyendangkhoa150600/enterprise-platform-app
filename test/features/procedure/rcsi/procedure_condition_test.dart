// Port 1:1 phần điều kiện của `procedure-flow.spec.ts` (backend web) + kiểm
// describeConditionRule / attributeChoices của trình sửa điểm rẽ nhánh.
import 'package:flutter_test/flutter_test.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/logic/procedure_condition.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/rcsi_definition_models.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/rcsi_flow_models.dart';

const ref = ProcedureAttributeRef.step('A', 'x');

ProcedureConditionRule rule(String operator, {Object? value, Object? valueTo}) =>
    ProcedureConditionRule(id: 'r', attribute: ref, operator: operator, value: value, valueTo: valueTo);

ProcedureBranchDefinition conditional(String id, List<ProcedureConditionRule> rules) => ProcedureBranchDefinition(
      id: id,
      key: id.toUpperCase(),
      label: id,
      isDefault: false,
      condition: ProcedureConditionGroup(combinator: 'and', rules: rules),
    );

ProcedureGatewayDefinition gateway(List<ProcedureBranchDefinition> branches) =>
    ProcedureGatewayDefinition(id: 'g', key: 'G', name: 'G', afterStepId: 'A', branches: branches);

void main() {
  group('evaluateConditionRule', () {
    ProcedureAttributeValue money(num value) => ProcedureAttributeValue('money', value);

    test('khoảng nửa mở: gồm cận dưới, không gồm cận trên', () {
      final between = rule('between', value: 100, valueTo: 200);
      expect(evaluateConditionRule(between, money(100)), isTrue);
      expect(evaluateConditionRule(between, money(199)), isTrue);
      expect(evaluateConditionRule(between, money(200)), isFalse);
    });

    test('giá trị trống chỉ thoả "trống"', () {
      expect(evaluateConditionRule(rule('lt', value: 10), null), isFalse);
      expect(evaluateConditionRule(rule('empty'), null), isTrue);
      expect(evaluateConditionRule(rule('not_empty'), money(0)), isTrue);
    });

    test('danh sách và ngày', () {
      ProcedureAttributeValue select(String value) => ProcedureAttributeValue('select', value);
      expect(evaluateConditionRule(rule('in', value: ['a', 'b']), select('b')), isTrue);
      expect(evaluateConditionRule(rule('is_not', value: 'a'), select('a')), isFalse);
      ProcedureAttributeValue date(String value) => ProcedureAttributeValue('date', value);
      expect(evaluateConditionRule(rule('before', value: '2026-10-01'), date('2026-09-30')), isTrue);
      expect(
        evaluateConditionRule(rule('date_between', value: '2026-10-01', valueTo: '2026-10-31'), date('2026-10-31')),
        isTrue,
      );
    });

    test('nhóm không có luật thì không khớp; HOẶC/VÀ', () {
      expect(evaluateConditionGroup(const ProcedureConditionGroup(), (_) => null), isFalse);
      final group = ProcedureConditionGroup(combinator: 'or', rules: [rule('lt', value: 10), rule('gt', value: 100)]);
      expect(evaluateConditionGroup(group, (_) => money(200)), isTrue);
      expect(evaluateConditionGroup(group.copyWith(combinator: 'and'), (_) => money(200)), isFalse);
    });
  });

  group('findBranchOverlaps', () {
    test('khoảng liền kề không chồng lấn', () {
      final result = findBranchOverlaps(gateway([
        conditional('b1', [rule('lt', value: 100)]),
        conditional('b2', [rule('between', value: 100, valueTo: 200)]),
      ]));
      expect(result, isEmpty);
    });

    test('phát hiện nhánh bị che hoàn toàn', () {
      final result = findBranchOverlaps(gateway([
        conditional('b1', [rule('lt', value: 1000)]),
        conditional('b2', [rule('between', value: 100, valueTo: 200)]),
      ]));
      expect(result, [const ProcedureBranchOverlap(branchId: 'b2', overlapsBranchId: 'b1', shadowed: true)]);
    });

    test('chồng một phần không phải che hoàn toàn; ngày cũng được phân tích', () {
      final result = findBranchOverlaps(gateway([
        conditional('b1', [rule('after', value: '2026-01-01')]),
        conditional('b2', [rule('date_between', value: '2025-12-01', valueTo: '2026-02-01')]),
      ]));
      expect(result, [const ProcedureBranchOverlap(branchId: 'b2', overlapsBranchId: 'b1', shadowed: false)]);
    });
  });

  group('describeConditionRule', () {
    const money = ProcedureAttributeDefinition(id: 'm', code: 'x', name: 'Giá trị báo giá', type: 'money');
    test('khoảng tiền', () {
      expect(
        describeConditionRule(rule('between', value: 100000000, valueTo: 1000000000), money),
        'Giá trị báo giá ≥ 100.000.000 đ và < 1.000.000.000 đ',
      );
    });
    test('toán tử không cần giá trị, danh sách, ngày, có/không', () {
      expect(describeConditionRule(rule('empty'), money), 'Giá trị báo giá trống');
      const select = ProcedureAttributeDefinition(
        id: 's',
        code: 'x',
        name: 'Loại',
        type: 'select',
        options: [ProcedureAttributeOption(code: 'a', label: 'Loại A'), ProcedureAttributeOption(code: 'b', label: 'Loại B')],
      );
      expect(describeConditionRule(rule('in', value: ['a', 'b']), select), 'Loại thuộc một trong Loại A, Loại B');
      const date = ProcedureAttributeDefinition(id: 'd', code: 'x', name: 'Ngày', type: 'date');
      expect(
        describeConditionRule(rule('date_between', value: '2026-10-01', valueTo: '2026-10-31'), date),
        'Ngày từ 01/10/2026 đến 31/10/2026',
      );
      const flag = ProcedureAttributeDefinition(id: 'b', code: 'x', name: 'Gấp', type: 'boolean');
      expect(describeConditionRule(rule('is', value: true), flag), 'Gấp là Có');
      expect(describeConditionRule(rule('gt', value: 1.5), null), 'x > 1,5');
    });
  });

  group('số kiểu vi-VN', () {
    test('định dạng và đọc lại', () {
      expect(formatViNumber(1234567.891), '1.234.567,89');
      expect(formatViNumber(-1000), '-1.000');
      expect(parseViNumber('1.000.000'), 1000000);
      expect(parseViNumber('12,5'), 12.5);
      expect(parseViNumber(''), isNull);
      expect(parseViNumber('abc'), isNull);
    });
  });

  group('conditionAttributeChoices', () {
    ProcedureStepDefinition step(String id, int order, [List<ProcedureAttributeDefinition>? attributes]) =>
        ProcedureStepDefinition(id: id, key: id.toUpperCase(), order: order, name: id, attributes: attributes);
    const amount = ProcedureAttributeDefinition(id: '1', code: 'so_tien', name: 'Số tiền', type: 'money');
    const note = ProcedureAttributeDefinition(id: '2', code: 'ghi_chu', name: 'Ghi chú', type: 'text');

    test('chỉ lấy bước chắc chắn đã đi qua trước điểm rẽ nhánh', () {
      final definition = ProcedureDefinition(
        id: 'def',
        code: 'QT',
        name: 'QT',
        status: 'draft',
        attributes: const [note],
        steps: [step('a', 1, const [amount]), step('b', 2, const [amount]), step('c', 3, const [amount])],
        gateways: const [
          ProcedureGatewayDefinition(id: 'g1', key: 'G1', name: 'G', afterStepId: 'a', branches: [
            ProcedureBranchDefinition(id: 'n1', key: 'N1', label: 'N1', isDefault: false, stepIds: ['b']),
            ProcedureBranchDefinition(id: 'd', key: 'MAC_DINH', label: 'Ngược lại', isDefault: true),
          ]),
        ],
      );
      final choices = conditionAttributeChoices(definition, 'c');
      expect(choices.map((item) => item.value), ['process:ghi_chu', 'step:a:so_tien', 'step:c:so_tien']);
      expect(choices[1].stepLabel, '1');
    });
  });
}
