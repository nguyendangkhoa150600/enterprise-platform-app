/// Hằng số và helper của `rcsi-board.tsx` (web), port 1:1, thuần Dart.
library;

import '../rcsi_definition_models.dart';
import '../rcsi_flow_models.dart';
import 'rcsi_columns.dart';

/// `ROLE_ORDER` — thứ tự hiển thị vai trò.
const List<String> rcsiRoleOrder = ['S', 'R', 'E', 'C', 'A', 'I'];

/// Khoá i18n `ROLE_LABEL` đầy đủ, vd S → "Submit — khởi tạo".
String rcsiRoleLabelKey(String role) => 'procedure.rcsi.role.$role';

/// Khoá i18n phần ngắn của nhãn vai (sau dấu "— "), vd S → "khởi tạo".
String rcsiRoleShortLabelKey(String role) => 'procedure.rcsi.role_short.$role';

/// `BRANCH_COLORS` (ARGB) — nhánh thứ i dùng màu `i % 6`.
const List<int> rcsiBranchColors = [0xFF60A5FA, 0xFF34D399, 0xFFF59E0B, 0xFFA78BFA, 0xFFF472B6, 0xFF94A3B8];

/// Màu ARGB của nhánh theo chỉ số nhánh.
int rcsiBranchColor(int branchIndex) => rcsiBranchColors[branchIndex % rcsiBranchColors.length];

/// `DEFINITIONS_PER_PAGE`.
const int rcsiDefinitionsPerPage = 10;

/// `E_TASK_SOURCE_OPTIONS` theo đúng thứ tự web. Nhãn/mô tả: `procedure.rcsi.e_task_source.<value>` và `….<value>_desc`.
const List<String> rcsiETaskSourceOptions = [
  'manual',
  'task_list',
  'equipment_template',
  'inventory_asset',
  'inventory_material',
];

String rcsiETaskSourceLabelKey(String value) => 'procedure.rcsi.e_task_source.$value';
String rcsiETaskSourceDescriptionKey(String value) => 'procedure.rcsi.e_task_source.${value}_desc';

/// Khoá i18n nhãn trạng thái quy trình (Nháp / Đã công bố / Lưu trữ).
String rcsiStatusLabelKey(String status) => 'procedure.rcsi.status.$status';

/// Một phân công có thuộc về một cột hay không (`sameSubject`).
bool sameSubject(RaciSubjectRef assignment, MatrixColumn column) {
  if (assignment.subjectId != column.subjectId) return false;
  return (assignment.subjectType == ProcedureSubjectType.user) == (column.subjectType == ProcedureSubjectType.user);
}

/// Phân công thuộc cột chức danh: trùng chủ thể, hoặc phân công cũ cấp đơn vị
/// gán cho đơn vị của chức danh Quản lý (`isAssignedToColumn`).
bool isAssignedToColumn(RaciSubjectRef assignment, MatrixColumn column) {
  if (sameSubject(assignment, column)) return true;
  return column.isHead == true &&
      assignment.subjectType == ProcedureSubjectType.organizationUnit &&
      assignment.subjectId == column.unitId;
}

/// Phân công của một bước thuộc về một cột (`ownedBy`).
List<ProcedureRaciAssignment> assignmentsOfColumn(ProcedureStepDefinition step, MatrixColumn column) =>
    step.assignments.where((item) => isAssignedToColumn(item, column)).toList();

/// Phễu duy nhất chuyển bước đã lưu sang payload ghi (`toStepInput`): thiếu một
/// trường ở đây là mất trường đó mỗi lần sửa một ô.
CreateProcedureStepInput toStepInput(ProcedureStepDefinition step) => CreateProcedureStepInput(
      key: step.key,
      order: step.order,
      name: step.name,
      description: step.description,
      linkedDefinitionId: step.linkedDefinitionId,
      slaHours: step.slaHours,
      materials: step.materials?.toList(),
      attributes: step.attributes?.toList(),
      integration: step.integration?.copy(),
      assignments: step.assignments
          .map((item) => CreateProcedureRaciAssignmentInput(
                role: item.role,
                subjectType: item.subjectType,
                subjectId: item.subjectId,
                subjectLabel: item.subjectLabel,
                fixedRollbackStepId: item.fixedRollbackStepId,
                eTaskSource: item.eTaskSource,
                eTaskConfig: item.eTaskConfig,
                managerFallback: item.managerFallback,
              ))
          .toList(),
    );

/// Mã thuộc tính đang được điều kiện rẽ nhánh dùng, theo phạm vi ([stepId] null = quy trình).
Set<String> usedAttributeCodes(ProcedureDefinition definition, String? stepId) {
  final codes = <String>{};
  for (final gateway in definition.gateways ?? const <ProcedureGatewayDefinition>[]) {
    for (final branch in gateway.branches) {
      for (final rule in branch.condition?.rules ?? const <ProcedureConditionRule>[]) {
        final ref = rule.attribute;
        final matches = stepId == null ? ref.isProcess : (ref.scope == 'step' && ref.stepId == stepId);
        if (matches) codes.add(ref.code);
      }
    }
  }
  return codes;
}

/// Mọi subjectId có phân vai trong các quy trình (`subjectsOf`).
Set<String> rcsiSubjectsOf(Iterable<ProcedureDefinition> definitions) => {
      for (final definition in definitions)
        for (final step in definition.steps)
          for (final assignment in step.assignments) assignment.subjectId,
    };

/// Lọc danh sách quy trình như `visibleDefinitions` của web: nhóm trước, rồi tìm
/// theo tên/mã quy trình HOẶC tên đơn vị tham gia; quy trình vừa tạo ghim đầu.
List<ProcedureDefinition> filterRcsiDefinitions(
  List<ProcedureDefinition> definitions, {
  String search = '',
  String? groupFilter,
  String? pinnedCode,
}) {
  final needle = search.trim().toLowerCase();
  final filtered = definitions.where((definition) {
    if (groupFilter != null && groupFilter.isNotEmpty && definition.category != groupFilter) return false;
    if (needle.isEmpty) return true;
    if (definition.name.toLowerCase().contains(needle) || definition.code.toLowerCase().contains(needle)) {
      return true;
    }
    return definition.steps.any(
      (step) => step.assignments.any((assignment) => (assignment.subjectLabel ?? '').toLowerCase().contains(needle)),
    );
  }).toList();
  if (pinnedCode == null) return filtered;
  final pinned = filtered.where((item) => item.code == pinnedCode);
  return [...pinned, ...filtered.where((item) => item.code != pinnedCode)];
}
