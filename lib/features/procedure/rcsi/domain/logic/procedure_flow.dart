/// Cấu trúc luồng của quy trình có rẽ nhánh — port 1:1 `procedure-flow.ts`
/// (contracts web), hàm thuần dùng chung cho UI.
///
/// "Trục chính" là các bước không thuộc nhánh nào, chạy theo `order`. Mỗi
/// gateway đứng ngay sau một bước trục chính; mọi nhánh hợp về bước trục chính
/// kế tiếp (điểm hợp).
library;

import '../rcsi_definition_models.dart';
import '../rcsi_flow_models.dart';
import 'vietnamese_text.dart';

/// Một bước tối thiểu để dựng chỉ mục luồng.
typedef ProcedureFlowStep = ({String id, num order});

class ProcedureBranchPosition {
  final ProcedureGatewayDefinition gateway;
  final ProcedureBranchDefinition branch;
  final int index;

  const ProcedureBranchPosition({required this.gateway, required this.branch, required this.index});
}

class ProcedureFlowIndex {
  /// Id bước trục chính, theo thứ tự chạy.
  final List<String> trunk;
  final Map<String, ProcedureBranchPosition> branchOf;
  final Map<String, ProcedureGatewayDefinition> gatewayAfter;
  final List<ProcedureGatewayDefinition> gateways;
  final Set<String> stepIds;

  ProcedureFlowIndex._({
    required this.trunk,
    required this.branchOf,
    required this.gatewayAfter,
    required this.gateways,
    required this.stepIds,
  });
}

ProcedureFlowIndex buildFlowIndex(
  Iterable<ProcedureFlowStep> steps,
  List<ProcedureGatewayDefinition>? gateways,
) {
  final list = gateways ?? const <ProcedureGatewayDefinition>[];
  final branchOf = <String, ProcedureBranchPosition>{};
  final gatewayAfter = <String, ProcedureGatewayDefinition>{};
  for (final gateway in list) {
    // Gateway trùng điểm đặt: giữ cái đầu tiên. Luật công bố báo lỗi trường hợp này.
    gatewayAfter.putIfAbsent(gateway.afterStepId, () => gateway);
    for (final branch in gateway.branches) {
      for (var index = 0; index < branch.stepIds.length; index += 1) {
        branchOf.putIfAbsent(
          branch.stepIds[index],
          () => ProcedureBranchPosition(gateway: gateway, branch: branch, index: index),
        );
      }
    }
  }
  final all = steps.toList();
  final trunkSteps = all.where((step) => !branchOf.containsKey(step.id)).toList();
  stableSort<ProcedureFlowStep>(trunkSteps, (left, right) => left.order.compareTo(right.order));
  return ProcedureFlowIndex._(
    trunk: trunkSteps.map((step) => step.id).toList(),
    branchOf: branchOf,
    gatewayAfter: gatewayAfter,
    gateways: list,
    stepIds: all.map((step) => step.id).toSet(),
  );
}

/// Chỉ mục luồng của một quy trình đã lưu.
ProcedureFlowIndex flowIndexOf(ProcedureDefinition definition) =>
    buildFlowIndex(definition.steps.map((step) => (id: step.id, order: step.order)), definition.gateways);

String? firstFlowStepId(ProcedureFlowIndex index) => index.trunk.isEmpty ? null : index.trunk.first;

String? nextTrunkStepId(ProcedureFlowIndex index, String stepId) {
  final position = index.trunk.indexOf(stepId);
  if (position < 0) return null;
  return position + 1 < index.trunk.length ? index.trunk[position + 1] : null;
}

/// Điểm hợp của một gateway: bước trục chính kế tiếp sau bước đặt gateway.
String? gatewayJoinStepId(ProcedureFlowIndex index, ProcedureGatewayDefinition gateway) =>
    nextTrunkStepId(index, gateway.afterStepId);

String? branchEntryStepId(
  ProcedureFlowIndex index,
  ProcedureGatewayDefinition gateway,
  ProcedureBranchDefinition branch,
) =>
    branch.stepIds.isNotEmpty ? branch.stepIds.first : gatewayJoinStepId(index, gateway);

/// Bước kế tiếp của một bước KHÔNG có gateway đứng sau.
String? sequentialNextStepId(ProcedureFlowIndex index, String stepId) {
  final position = index.branchOf[stepId];
  if (position != null) {
    final next = position.index + 1;
    return next < position.branch.stepIds.length
        ? position.branch.stepIds[next]
        : gatewayJoinStepId(index, position.gateway);
  }
  return nextTrunkStepId(index, stepId);
}

/// Mọi điểm tới có thể có sau một bước (null = kết thúc quy trình).
List<String?> possibleNextStepIds(ProcedureFlowIndex index, String stepId) {
  final gateway = index.gatewayAfter[stepId];
  if (gateway == null) return [sequentialNextStepId(index, stepId)];
  final targets = <String?>{};
  for (final branch in gateway.branches) {
    targets.add(branchEntryStepId(index, gateway, branch));
  }
  return targets.toList();
}

final Expando<Set<String>> _reachableCache = Expando<Set<String>>();

/// Các bước đi tới được từ bước đầu theo mọi nhánh.
Set<String> reachable(ProcedureFlowIndex index) {
  final cached = _reachableCache[index];
  if (cached != null) return cached;
  final seen = <String>{};
  final first = firstFlowStepId(index);
  final queue = <String>[?first];
  while (queue.isNotEmpty) {
    final id = queue.removeAt(0);
    if (seen.contains(id) || !index.stepIds.contains(id)) continue;
    seen.add(id);
    for (final target in possibleNextStepIds(index, id)) {
      if (target != null) queue.add(target);
    }
  }
  _reachableCache[index] = seen;
  return seen;
}

/// Tập bước chắc chắn đã đi qua trước khi tới [stepId] trên MỌI đường từ bước
/// đầu (dominator, không gồm chính nó).
Set<String> dominatorStepIds(ProcedureFlowIndex index, String stepId) {
  final first = firstFlowStepId(index);
  final all = index.stepIds.toList();
  final predecessors = <String, List<String>>{for (final id in all) id: <String>[]};
  for (final id in all) {
    for (final target in possibleNextStepIds(index, id)) {
      if (target != null && predecessors.containsKey(target)) predecessors[target]!.add(id);
    }
  }
  final dominators = <String, Set<String>>{
    for (final id in all) id: id == first ? {id} : all.toSet(),
  };
  final reach = reachable(index);
  var changed = true;
  while (changed) {
    changed = false;
    for (final id in all) {
      if (id == first) continue;
      final preds = (predecessors[id] ?? const <String>[]).where(reach.contains).toList();
      Set<String> next;
      if (preds.isEmpty) {
        next = {id};
      } else {
        next = Set<String>.of(dominators[preds.first] ?? const <String>{});
        for (final pred in preds.skip(1)) {
          final other = dominators[pred] ?? const <String>{};
          next.removeWhere((candidate) => !other.contains(candidate));
        }
        next.add(id);
      }
      final current = dominators[id] ?? const <String>{};
      if (next.length != current.length || next.any((candidate) => !current.contains(candidate))) {
        dominators[id] = next;
        changed = true;
      }
    }
  }
  final result = Set<String>.of(dominators[stepId] ?? const <String>{});
  result.remove(stepId);
  return result;
}

/// True nếu đi theo cấu trúc từ bước đầu mà quay lại một bước đã qua.
bool hasFlowCycle(ProcedureFlowIndex index) {
  final state = <String, bool>{}; // false = đang thăm, true = xong
  bool visit(String id) {
    final mark = state[id];
    if (mark == false) return true;
    if (mark == true) return false;
    state[id] = false;
    for (final target in possibleNextStepIds(index, id)) {
      if (target != null && index.stepIds.contains(target) && visit(target)) return true;
    }
    state[id] = true;
    return false;
  }

  final first = firstFlowStepId(index);
  return first != null && visit(first);
}

/// Số bước còn lại tính từ sau [fromStepId] (`countRemainingSteps`).
({int remaining, bool isEstimate}) countRemainingSteps(
  ProcedureFlowIndex index,
  String? fromStepId,
  ProcedureBranchDefinition? Function(ProcedureGatewayDefinition gateway) decided,
) {
  var remaining = 0;
  var isEstimate = false;
  final seen = <String>{};
  var cursor = fromStepId;
  while (cursor != null) {
    if (!seen.add(cursor)) break;
    final gateway = index.gatewayAfter[cursor];
    String? next;
    if (gateway != null) {
      final branch = decided(gateway);
      if (branch != null) {
        next = branchEntryStepId(index, gateway, branch);
      } else {
        isEstimate = true;
        if (gateway.branches.isNotEmpty) {
          remaining += gateway.branches.map((item) => item.stepIds.length).reduce((a, b) => a < b ? a : b);
        }
        next = gatewayJoinStepId(index, gateway);
      }
    } else {
      next = sequentialNextStepId(index, cursor);
    }
    if (next != null) remaining += 1;
    cursor = next;
  }
  return (remaining: remaining, isEstimate: isEstimate);
}
