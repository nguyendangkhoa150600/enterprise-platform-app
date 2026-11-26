import 'rcsi_editor_hooks.dart';
import 'widgets/sheets/rcsi_attribute_editor_sheet.dart';
import 'widgets/sheets/rcsi_bulk_assign_sheet.dart';
import 'widgets/sheets/rcsi_cell_editor_sheet.dart';
import 'widgets/sheets/rcsi_dynamic_approver_sheet.dart';
import 'widgets/sheets/rcsi_gateway_editor_sheet.dart';
import 'widgets/sheets/rcsi_step_actions.dart';
import 'widgets/sheets/rcsi_step_config_sheet.dart';

/// Trình sửa bản nháp của Ma trận RCSI. Mỗi trình sửa là một hàm top-level đúng kiểu
/// [RcsiEditorHook] (tear-off hàm top-level vẫn là hằng). Hook để trống thì lối vào tương ứng bị ẩn.
const RcsiEditorHooks rcsiEditorHooks = RcsiEditorHooks(
  cellEditor: openRcsiCellEditor, // Sửa vai trò một ô (RolePopover): S/R/E/C/A/I, C → bước quay về, E → nguồn đầu việc.
  stepConfig: rcsiStepConfigHook, // Cấu hình bước (StepConfigDialog): SLA, nối tiếp, nhánh, bước Tài chính.
  attributeEditor: openRcsiAttributeEditor, // Thuộc tính quy trình / bước (AttributeEditor).
  gatewayEditor: rcsiGatewayEditorHook, // Điều kiện rẽ nhánh (GatewayEditor).
  dynamicApprover: openRcsiDynamicApprover, // Quản lý trực tiếp (DynamicApproverEditor).
  bulkAssign: openRcsiBulkAssign, // Gán nhiều chức danh (BulkAssignDialog).
  addStep: rcsiAddStepHook, // Thêm bước trên trục chính / vào nhánh.
  renameStep: rcsiRenameStepHook, // Đổi tên bước.
  removeStep: rcsiRemoveStepHook, // Xoá bước.
  addGateway: rcsiAddGatewayHook, // Thêm rẽ nhánh sau bước.
);
