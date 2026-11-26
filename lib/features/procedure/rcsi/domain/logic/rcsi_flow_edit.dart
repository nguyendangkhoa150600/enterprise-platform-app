/// Thao tác sửa cấu trúc rẽ nhánh trên ma trận RCSI — port 1:1
/// `components/rcsi/flow-edit.ts`, hàm thuần.
///
/// Mọi thao tác trả về TRỌN BỘ `steps` + `gateways` mới để gửi lên (thay cả bản
/// nháp). `order` luôn được đánh lại liền mạch theo cấu trúc: trục chính → bước
/// của từng nhánh → điểm hợp.
library;

import '../rcsi_definition_models.dart';
import '../rcsi_flow_models.dart';
import 'procedure_flow.dart';
import 'rcsi_labels.dart';
import 'vietnamese_text.dart';

/// Hàm chuyển bước đã lưu sang payload ghi — thường là `toStepInput`.
typedef StepToInput = CreateProcedureStepInput Function(ProcedureStepDefinition step);

/// `Number.MAX_SAFE_INTEGER` — order tạm của bước được thêm vào cuối.
const int maxSafeInteger = 9007199254740991;

class FlowRowBranch {
  final ProcedureGatewayDefinition gateway;
  final ProcedureBranchDefinition branch;
  final int branchIndex;

  /// Chữ cái nhánh (A, B, C…), liên tục qua các điểm rẽ nhánh.
  final String letter;

  /// Bước cuối của nhánh — ô "Thêm bước vào nhánh" đứng ngay sau nó.
  final bool isLast;

  const FlowRowBranch({
    required this.gateway,
    required this.branch,
    required this.branchIndex,
    required this.letter,
    required this.isLast,
  });
}

class FlowRowInfo {
  /// Nhánh chứa bước này, nếu có.
  final FlowRowBranch? branch;

  /// Gateway đứng ngay sau bước này, nếu có.
  final ProcedureGatewayDefinition? gatewayAfter;

  /// Bước này là điểm hợp của các gateway nào.
  final List<ProcedureGatewayDefinition> joinOf;

  /// Số hiển thị: trục chính 1, 2, 3…; bước trong nhánh là chữ + vị trí (A1, B2).
  final String label;

  const FlowRowInfo({this.branch, this.gatewayAfter, this.joinOf = const [], required this.label});
}

String _letterOf(int index) {
  final base = String.fromCharCode(65 + (index % 26));
  return index < 26 ? base : '$base${index ~/ 26 + 1}';
}

/// Chữ cái của từng nhánh theo thứ tự điểm rẽ trên trục chính. Khoá: `gatewayId:branchIndex`.
Map<String, String> branchLetters(ProcedureDefinition definition) {
  final index = flowIndexOf(definition);
  final letters = <String, String>{};
  var counter = 0;
  for (final stepId in index.trunk) {
    final gateway = index.gatewayAfter[stepId];
    if (gateway == null) continue;
    for (var branchIndex = 0; branchIndex < gateway.branches.length; branchIndex += 1) {
      letters['${gateway.id}:$branchIndex'] = _letterOf(counter);
      counter += 1;
    }
  }
  return letters;
}

Map<String, FlowRowInfo> flowRowInfo(ProcedureDefinition definition) {
  final gateways = definition.gateways ?? const <ProcedureGatewayDefinition>[];
  final index = flowIndexOf(definition);
  final letters = branchLetters(definition);
  final trunkNumber = {for (var i = 0; i < index.trunk.length; i += 1) index.trunk[i]: i + 1};
  String? trunkAfter(String stepId) {
    final next = index.trunk.indexOf(stepId) + 1;
    return next < index.trunk.length ? index.trunk[next] : null;
  }

  final info = <String, FlowRowInfo>{};
  for (final step in definition.steps) {
    final position = index.branchOf[step.id];
    final branchIndex = position == null ? -1 : position.gateway.branches.indexOf(position.branch);
    final letter = position == null ? '' : letters['${position.gateway.id}:$branchIndex'] ?? '?';
    final indexInBranch = position == null ? -1 : position.branch.stepIds.indexOf(step.id);
    info[step.id] = FlowRowInfo(
      branch: position == null
          ? null
          : FlowRowBranch(
              gateway: position.gateway,
              branch: position.branch,
              branchIndex: branchIndex,
              letter: letter,
              isLast: indexInBranch == position.branch.stepIds.length - 1,
            ),
      gatewayAfter: index.gatewayAfter[step.id],
      joinOf: gateways.where((gateway) => trunkAfter(gateway.afterStepId) == step.id).toList(),
      label: position != null ? '$letter${indexInBranch + 1}' : '${trunkNumber[step.id] ?? step.order}',
    );
  }
  return info;
}

/// Mã kế tiếp chưa dùng: `<prefix><n>` với n bắt đầu từ số phần tử + 1.
String nextFlowKey(List<String> existing, String prefix) {
  final taken = existing.map((key) => key.toUpperCase()).toSet();
  var counter = existing.length + 1;
  while (taken.contains('$prefix$counter')) {
    counter += 1;
  }
  return '$prefix$counter';
}

/// Sắp lại bước theo cấu trúc rồi đánh `order` 1..n.
List<CreateProcedureStepInput> _renumber(
  List<CreateProcedureStepInput> steps,
  String Function(CreateProcedureStepInput step) refOf,
  List<ProcedureGatewayDefinition> gateways,
) {
  final byRef = <String, CreateProcedureStepInput>{};
  for (final step in steps) {
    byRef[refOf(step)] = step;
  }
  final inBranch = {
    for (final gateway in gateways)
      for (final branch in gateway.branches) ...branch.stepIds,
  };
  int byOrder(CreateProcedureStepInput left, CreateProcedureStepInput right) => left.order.compareTo(right.order);
  final trunk = steps.where((step) => !inBranch.contains(refOf(step))).toList();
  stableSort(trunk, byOrder);
  final ordered = <CreateProcedureStepInput>[];
  final placed = <String>{};
  for (final step in trunk) {
    ordered.add(step);
    placed.add(refOf(step));
    ProcedureGatewayDefinition? gateway;
    for (final item in gateways) {
      if (item.afterStepId == refOf(step)) {
        gateway = item;
        break;
      }
    }
    if (gateway == null) continue;
    for (final branch in gateway.branches) {
      for (final ref in branch.stepIds) {
        final branchStep = byRef[ref];
        if (branchStep != null && !placed.contains(ref)) {
          ordered.add(branchStep);
          placed.add(ref);
        }
      }
    }
  }
  // Bước mồ côi (nhánh của gateway không còn điểm đặt): giữ ở cuối, luật công bố sẽ báo.
  final rest = [...steps];
  stableSort(rest, byOrder);
  for (final step in rest) {
    if (!placed.contains(refOf(step))) ordered.add(step);
  }
  return [for (var i = 0; i < ordered.length; i += 1) ordered[i].copyWith(order: i + 1)];
}

/// Kết quả một thao tác luồng: gửi cả hai qua `updateDefinition(steps, gateways: …)`.
class FlowChange {
  final List<CreateProcedureStepInput> steps;
  final List<ProcedureGatewayDefinition> gateways;

  const FlowChange({required this.steps, required this.gateways});
}

String Function(CreateProcedureStepInput step) _refResolver(ProcedureDefinition definition) {
  final idByKey = {for (final step in definition.steps) step.key: step.id};
  return (step) => idByKey[step.key] ?? step.key;
}

/// Thêm điểm rẽ nhánh sau một bước, sẵn một nhánh có điều kiện và nhánh "Ngược lại".
FlowChange addGateway(
  ProcedureDefinition definition,
  String afterStepId,
  StepToInput toInput, {
  RcsiLabels labels = defaultRcsiLabels,
}) {
  final gateways = definition.gateways ?? const <ProcedureGatewayDefinition>[];
  final gateway = ProcedureGatewayDefinition(
    id: '',
    key: nextFlowKey(gateways.map((item) => item.key).toList(), 'G'),
    name: labels.gatewayDefaultName,
    afterStepId: afterStepId,
    branches: [
      ProcedureBranchDefinition(
        id: '',
        key: 'N1',
        label: labels.firstBranchLabel,
        isDefault: false,
        condition: const ProcedureConditionGroup(combinator: 'and', rules: []),
        stepIds: const [],
      ),
      ProcedureBranchDefinition(id: '', key: 'MAC_DINH', label: labels.defaultBranchLabel, isDefault: true),
    ],
  );
  return FlowChange(steps: definition.steps.map(toInput).toList(), gateways: [...gateways, gateway]);
}

/// Xoá điểm rẽ nhánh; bước trong nhánh KHÔNG bị xoá mà về trục chính.
FlowChange removeGateway(ProcedureDefinition definition, String gatewayId, StepToInput toInput) => FlowChange(
      steps: definition.steps.map(toInput).toList(),
      gateways: (definition.gateways ?? const <ProcedureGatewayDefinition>[])
          .where((gateway) => gateway.id != gatewayId)
          .toList(),
    );

/// Thay một gateway (sau khi sửa điều kiện/nhánh), đánh lại thứ tự bước.
FlowChange replaceGateway(ProcedureDefinition definition, ProcedureGatewayDefinition next, StepToInput toInput) {
  final gateways = (definition.gateways ?? const <ProcedureGatewayDefinition>[])
      .map((gateway) => gateway.id == next.id ? next : gateway)
      .toList();
  return FlowChange(
    steps: _renumber(definition.steps.map(toInput).toList(), _refResolver(definition), gateways),
    gateways: gateways,
  );
}

class BranchTarget {
  final String gatewayId;
  final String branchId;

  const BranchTarget({required this.gatewayId, required this.branchId});

  @override
  bool operator ==(Object other) => other is BranchTarget && other.gatewayId == gatewayId && other.branchId == branchId;

  @override
  int get hashCode => Object.hash(gatewayId, branchId);
}

/// Nhánh đang chứa một bước, nếu có.
BranchTarget? branchOfStep(ProcedureDefinition definition, String stepId) {
  for (final gateway in definition.gateways ?? const <ProcedureGatewayDefinition>[]) {
    for (final branch in gateway.branches) {
      if (branch.stepIds.contains(stepId)) return BranchTarget(gatewayId: gateway.id, branchId: branch.id);
    }
  }
  return null;
}

/// Chuyển một bước vào cuối một nhánh, hoặc về trục chính ([target] = null):
/// về trục chính thì đặt ngay SAU điểm hợp của nhánh cũ.
FlowChange moveStepToBranch(
  ProcedureDefinition definition,
  String stepId,
  BranchTarget? target,
  StepToInput toInput,
) {
  final index = flowIndexOf(definition);
  final previous = index.branchOf[stepId];
  final gateways = (definition.gateways ?? const <ProcedureGatewayDefinition>[]).map((gateway) {
    return gateway.copyWith(
      branches: gateway.branches.map((branch) {
        final stepIds = branch.stepIds.where((id) => id != stepId).toList();
        return gateway.id == target?.gatewayId && branch.id == target?.branchId
            ? branch.copyWith(stepIds: [...stepIds, stepId])
            : branch.copyWith(stepIds: stepIds);
      }).toList(),
    );
  }).toList();

  num? trunkOrder;
  if (target == null && previous != null) {
    final joinIndex = index.trunk.indexOf(previous.gateway.afterStepId) + 1;
    final joinId = joinIndex < index.trunk.length ? index.trunk[joinIndex] : null;
    final join = joinId == null ? null : definition.stepById(joinId);
    trunkOrder = join != null ? join.order + 0.5 : maxSafeInteger;
  }
  final steps = definition.steps.map((step) {
    final input = toInput(step);
    return step.id == stepId && trunkOrder != null ? input.copyWith(order: trunkOrder) : input;
  }).toList();
  return FlowChange(steps: _renumber(steps, _refResolver(definition), gateways), gateways: gateways);
}

/// Thêm một bước mới vào cuối một nhánh; nhánh tham chiếu bước mới bằng `key`.
FlowChange addStepToBranch(
  ProcedureDefinition definition,
  BranchTarget target,
  String name,
  StepToInput toInput,
) {
  final key = nextFlowKey(definition.steps.map((step) => step.key).toList(), 'B');
  final gateways = (definition.gateways ?? const <ProcedureGatewayDefinition>[]).map((gateway) {
    return gateway.copyWith(
      branches: gateway.branches
          .map((branch) => gateway.id == target.gatewayId && branch.id == target.branchId
              ? branch.copyWith(stepIds: [...branch.stepIds, key])
              : branch)
          .toList(),
    );
  }).toList();
  final steps = [
    ...definition.steps.map(toInput),
    CreateProcedureStepInput(key: key, order: maxSafeInteger, name: name),
  ];
  return FlowChange(steps: _renumber(steps, _refResolver(definition), gateways), gateways: gateways);
}

/// Xoá một bước và dọn mọi tham chiếu: khỏi nhánh, khỏi điểm quay về của C,
/// và gỡ gateway đặt ngay sau nó.
FlowChange removeFlowStep(ProcedureDefinition definition, String stepId, StepToInput toInput) {
  final gateways = (definition.gateways ?? const <ProcedureGatewayDefinition>[])
      .where((gateway) => gateway.afterStepId != stepId)
      .map((gateway) => gateway.copyWith(
            branches: gateway.branches
                .map((branch) => branch.copyWith(stepIds: branch.stepIds.where((id) => id != stepId).toList()))
                .toList(),
          ))
      .toList();
  final steps = definition.steps.where((step) => step.id != stepId).map((step) {
    final input = toInput(step);
    return input.copyWith(
      assignments: input.assignments
          .map((assignment) =>
              assignment.fixedRollbackStepId == stepId ? assignment.copyWith(fixedRollbackStepId: null) : assignment)
          .toList(),
    );
  }).toList();
  return FlowChange(steps: _renumber(steps, _refResolver(definition), gateways), gateways: gateways);
}
