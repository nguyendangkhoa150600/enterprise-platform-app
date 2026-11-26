import 'package:flutter/widgets.dart';

import '../domain/logic/rcsi_columns.dart';
import '../domain/logic/rcsi_flow_edit.dart';
import '../domain/rcsi_definition_models.dart';
import '../domain/rcsi_flow_models.dart';
import 'state/rcsi_store.dart';

/// Ngữ cảnh truyền cho một trình sửa của giai đoạn 2.
///
/// Luôn đọc lại quy trình qua [definition] (theo id) sau mỗi lần lưu: store nạp
/// lại workspace nên đối tượng cũ không còn mới nhất.
class RcsiEditContext {
  final RcsiStore store;
  final String definitionId;

  /// Bước đang thao tác (null với thuộc tính cấp quy trình / gateway / thêm bước trục chính).
  final String? stepId;

  /// Gateway đang thao tác (trình sửa điều kiện).
  final String? gatewayId;

  /// Ô đang sửa (cột); null với `cellEditor` nghĩa là để trình sửa tự cho chọn cột.
  final MatrixColumn? column;

  /// Nhánh đích khi thêm bước vào nhánh; null = trục chính.
  final BranchTarget? branch;

  /// Cột đang hiển thị trên màn (đã áp sơ đồ/chế độ/tìm chức danh) — như cột của ma trận web.
  final List<MatrixColumn> columns;

  const RcsiEditContext({
    required this.store,
    required this.definitionId,
    this.stepId,
    this.gatewayId,
    this.column,
    this.branch,
    this.columns = const [],
  });

  ProcedureDefinition? get definition => store.definitionById(definitionId);
  ProcedureStepDefinition? get step => stepId == null ? null : definition?.stepById(stepId!);
  ProcedureGatewayDefinition? get gateway => gatewayId == null ? null : definition?.gatewayById(gatewayId!);

  /// Sửa được (có quyền thiết kế và là bản nháp); false = chỉ xem.
  bool get editable {
    final current = definition;
    return current != null && store.isEditable(current);
  }
}

/// Một trình sửa: mở sheet/dialog/màn hình rồi gọi API qua [RcsiEditContext.store].
typedef RcsiEditorHook = Future<void> Function(BuildContext context, RcsiEditContext edit);

/// Điểm cắm của giai đoạn 2. Hook null ⇒ lối vào tương ứng KHÔNG hiển thị.
///
/// Điều kiện hiện lối vào (đã do màn hình kiểm, giống web):
/// - [cellEditor]: bản nháp + quyền thiết kế (ô vai bấm được). `column` có giá trị khi bấm
///   một vai đang gán; null khi bấm "Phân vai" của bước.
/// - [stepConfig]: luôn hiện ("Cấu hình bước" khi sửa được, "Xem cấu hình" khi chỉ xem).
/// - [attributeEditor]: khi sửa được hoặc quy trình/bước đã có thuộc tính (stepId null = QT).
/// - [gatewayEditor]: luôn hiện trên hàng rẽ nhánh ("Cấu hình điều kiện" / "Xem điều kiện").
/// - [dynamicApprover]: khi sửa được, hoặc bước đã có người duyệt động (chỉ xem).
/// - [bulkAssign], [addStep], [renameStep], [removeStep]: chỉ khi sửa được.
/// - [addGateway]: khi sửa được, bước nằm trên trục chính và chưa có rẽ nhánh đứng sau.
class RcsiEditorHooks {
  final RcsiEditorHook? cellEditor;
  final RcsiEditorHook? stepConfig;
  final RcsiEditorHook? attributeEditor;
  final RcsiEditorHook? gatewayEditor;
  final RcsiEditorHook? dynamicApprover;
  final RcsiEditorHook? bulkAssign;
  final RcsiEditorHook? addStep;
  final RcsiEditorHook? renameStep;
  final RcsiEditorHook? removeStep;
  final RcsiEditorHook? addGateway;

  const RcsiEditorHooks({
    this.cellEditor,
    this.stepConfig,
    this.attributeEditor,
    this.gatewayEditor,
    this.dynamicApprover,
    this.bulkAssign,
    this.addStep,
    this.renameStep,
    this.removeStep,
    this.addGateway,
  });
}
