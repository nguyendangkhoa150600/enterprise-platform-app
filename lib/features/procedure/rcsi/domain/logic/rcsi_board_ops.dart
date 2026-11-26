/// Các thao tác sửa bản nháp của `rcsi-board.tsx` (web) dưới dạng hàm thuần:
/// mỗi hàm trả [RcsiDefinitionUpdate] — trọn bộ payload PATCH `/definitions/:id`
/// (thay cả bản nháp, server kiểm trên trạng thái đầy đủ). Store chỉ việc gửi đi.
library;

import '../rcsi_definition_models.dart';
import '../rcsi_flow_models.dart';
import 'procedure_flow.dart';
import 'rcsi_board_helpers.dart';
import 'rcsi_columns.dart';
import 'rcsi_flow_edit.dart';
import 'rcsi_labels.dart';

/// Payload `UpdateProcedureDefinitionRequest` mà ma trận gửi: `steps` luôn có;
/// `attributes`/`gateways` null = server giữ nguyên, `[]` = xoá hết.
class RcsiDefinitionUpdate {
  final List<CreateProcedureStepInput> steps;
  final List<ProcedureAttributeDefinition>? attributes;
  final List<ProcedureGatewayDefinition>? gateways;

  const RcsiDefinitionUpdate(this.steps, {this.attributes, this.gateways});

  /// Từ một thao tác luồng: gửi kèm `gateways`.
  factory RcsiDefinitionUpdate.fromFlow(FlowChange change) =>
      RcsiDefinitionUpdate(change.steps, gateways: change.gateways);

  Map<String, dynamic> toJson() => {
        'steps': steps.map((step) => step.toJson()).toList(),
        if (attributes != null) 'attributes': attributes!.map((item) => item.toJson()).toList(),
        if (gateways != null) 'gateways': gateways!.map((item) => item.toJson()).toList(),
      };
}

/// `StepConfigChange` của Dialog cấu hình bước (SLA + nối tiếp + tài chính + đổi nhánh).
class StepConfigChange {
  final num? slaHours;
  final String? linkedDefinitionId;
  final ProcedureStepIntegration? integration;

  /// true = có đổi nhánh (khi đó [branch] null nghĩa là về trục chính); false = giữ nguyên.
  final bool changeBranch;
  final BranchTarget? branch;

  const StepConfigChange({
    this.slaHours,
    this.linkedDefinitionId,
    this.integration,
    this.changeBranch = false,
    this.branch,
  });
}

List<CreateProcedureStepInput> _mapStep(
  ProcedureDefinition definition,
  String stepId,
  CreateProcedureStepInput Function(CreateProcedureStepInput input) change,
) =>
    definition.steps.map((step) {
      final input = toStepInput(step);
      return step.id == stepId ? change(input) : input;
    }).toList();

/// Ghi lại cả bản nháp sau khi đổi đúng một ô (`writeCell`). [change] null = xoá vai khỏi ô.
RcsiDefinitionUpdate rcsiWriteCell(
  ProcedureDefinition definition,
  String stepId,
  MatrixColumn column,
  ProcedureRaciAssignment? change,
) =>
    RcsiDefinitionUpdate(_mapStep(definition, stepId, (input) {
      final kept = input.assignments.where((item) => !isAssignedToColumn(item, column)).toList();
      return input.copyWith(
        assignments: change == null
            ? kept
            : [
                ...kept,
                CreateProcedureRaciAssignmentInput(
                  role: change.role,
                  subjectType: column.subjectType,
                  subjectId: column.subjectId,
                  // Cột "Toàn bộ nhân viên" có nhãn dịch để hiển thị; server lưu nhãn web.
                  subjectLabel: column.subjectType == ProcedureSubjectType.everyone
                      ? defaultRcsiLabels.everyoneLabel
                      : column.label,
                  fixedRollbackStepId: change.fixedRollbackStepId,
                  eTaskSource: change.eTaskSource,
                  eTaskConfig: change.eTaskConfig,
                ),
              ],
      );
    }));

/// Đổi danh sách vật tư của một bước (`setStepMaterials`).
RcsiDefinitionUpdate rcsiSetStepMaterials(
  ProcedureDefinition definition,
  String stepId,
  List<ProcedureStepMaterial> materials,
) =>
    RcsiDefinitionUpdate(
      _mapStep(definition, stepId, (input) => input.copyWith(materials: materials.isEmpty ? null : materials)),
    );

/// Thêm bước trên trục chính (`addStep`): tên mặc định theo số trục chính, mã `B<n>` không trùng.
RcsiDefinitionUpdate rcsiAddStep(
  ProcedureDefinition definition, {
  String? name,
  RcsiLabels labels = defaultRcsiLabels,
}) {
  final order = definition.steps.length + 1;
  final inBranch = {
    for (final gateway in definition.gateways ?? const <ProcedureGatewayDefinition>[])
      for (final branch in gateway.branches) ...branch.stepIds,
  };
  final trimmed = name?.trim() ?? '';
  final trunkCount = definition.steps.where((step) => !inBranch.contains(step.id)).length;
  final stepName = trimmed.isNotEmpty ? trimmed : RcsiLabels.fill(labels.defaultStepName, {'number': trunkCount + 1});
  final existing = definition.steps.map((step) => step.key.trim().toUpperCase()).toSet();
  var next = order;
  while (existing.contains('B$next')) {
    next += 1;
  }
  return RcsiDefinitionUpdate([
    ...definition.steps.map(toStepInput),
    CreateProcedureStepInput(key: 'B$next', order: order, name: stepName),
  ]);
}

/// Đổi tên bước (`renameStep`); null nếu tên rỗng.
RcsiDefinitionUpdate? rcsiRenameStep(ProcedureDefinition definition, String stepId, String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  return RcsiDefinitionUpdate(_mapStep(definition, stepId, (input) => input.copyWith(name: trimmed)));
}

/// Xoá bước và dọn tham chiếu (`removeStep`); null khi quy trình chỉ còn một bước.
RcsiDefinitionUpdate? rcsiRemoveStep(ProcedureDefinition definition, String stepId) {
  if (definition.steps.length <= 1) return null;
  return RcsiDefinitionUpdate.fromFlow(removeFlowStep(definition, stepId, toStepInput));
}

/// Lưu thuộc tính (`saveAttributes`): [stepId] null = cấp quy trình (gửi `attributes`).
RcsiDefinitionUpdate rcsiSaveAttributes(
  ProcedureDefinition definition,
  String? stepId,
  List<ProcedureAttributeDefinition> attributes,
) {
  if (stepId == null) {
    return RcsiDefinitionUpdate(definition.steps.map(toStepInput).toList(), attributes: attributes);
  }
  return RcsiDefinitionUpdate(
    _mapStep(definition, stepId, (input) => input.copyWith(attributes: attributes.isEmpty ? null : attributes)),
  );
}

/// Đặt/bỏ người duyệt động "Quản lý trực tiếp" (`saveDynamicApprover`). [role] null = bỏ.
RcsiDefinitionUpdate rcsiSaveDynamicApprover(
  ProcedureDefinition definition,
  String stepId, {
  String? role,
  ProcedureManagerFallback? managerFallback,
  RcsiLabels labels = defaultRcsiLabels,
}) =>
    RcsiDefinitionUpdate(_mapStep(definition, stepId, (input) {
      final kept =
          input.assignments.where((item) => item.subjectType != ProcedureSubjectType.initiatorManager).toList();
      return input.copyWith(
        assignments: role == null
            ? kept
            : [
                ...kept,
                CreateProcedureRaciAssignmentInput(
                  role: role,
                  subjectType: ProcedureSubjectType.initiatorManager,
                  subjectId: '',
                  subjectLabel: labels.dynamicApproverLabel,
                  managerFallback: managerFallback,
                ),
              ],
      );
    }));

/// Gán (hoặc xoá khi [role] null) một vai cho nhiều cột của một bước trong MỘT lần ghi.
RcsiDefinitionUpdate? rcsiBulkAssign(
  ProcedureDefinition definition,
  String stepId,
  String? role,
  List<MatrixColumn> picked,
) {
  if (picked.isEmpty) return null;
  return RcsiDefinitionUpdate(_mapStep(definition, stepId, (input) {
    final kept = input.assignments
        .where((item) => !picked.any((column) => isAssignedToColumn(item, column)))
        .toList();
    return input.copyWith(
      assignments: role == null
          ? kept
          : [
              ...kept,
              for (final column in picked)
                CreateProcedureRaciAssignmentInput(
                  role: role,
                  subjectType: column.subjectType,
                  subjectId: column.subjectId,
                  subjectLabel: column.label,
                ),
            ],
    );
  }));
}

/// Lưu Dialog cấu hình bước: SLA + nối tiếp + tài chính (+ đổi nhánh) trong MỘT lần ghi.
RcsiDefinitionUpdate rcsiSaveStepConfig(ProcedureDefinition definition, String stepId, StepConfigChange change) {
  CreateProcedureStepInput withStep(ProcedureStepDefinition step) => step.id == stepId
      ? toStepInput(step).copyWith(
          slaHours: change.slaHours,
          linkedDefinitionId: change.linkedDefinitionId,
          integration: change.integration,
        )
      : toStepInput(step);
  if (change.changeBranch) {
    return RcsiDefinitionUpdate.fromFlow(moveStepToBranch(definition, stepId, change.branch, withStep));
  }
  return RcsiDefinitionUpdate(definition.steps.map(withStep).toList());
}

// ------------------------------------------------------------------ Luật ô vai trò (RolePopover)

/// Các bước được chọn làm điểm quay về của C: chắc chắn đã đi qua trước bước này.
List<ProcedureStepDefinition> rcsiRollbackCandidates(ProcedureDefinition definition, String stepId) {
  final allowed = dominatorStepIds(flowIndexOf(definition), stepId);
  return definition.orderedSteps.where((step) => allowed.contains(step.id)).toList();
}

/// Một vai có bị khoá ở ô này không, và vì sao (khoá i18n lý do), theo luật web.
String? rcsiRoleBlockReasonKey(ProcedureStepDefinition step, MatrixColumn column, String role) {
  if (column.subjectType == ProcedureSubjectType.everyone && role != 'S') {
    return 'procedure.rcsi.cell.everyone_only_s';
  }
  if (role == 'C' && step.assignments.any((item) => item.role == 'C' && item.subjectId != column.subjectId)) {
    return 'procedure.rcsi.cell.c_taken';
  }
  if (role == 'E' && column.subjectType == ProcedureSubjectType.position && column.isHead != true) {
    return 'procedure.rcsi.cell.e_head_only';
  }
  return null;
}
