import 'package:flutter/widgets.dart';

import 'assistant_forms_hrm.dart';
import 'assistant_forms_other.dart';
import 'assistant_forms_workspace.dart';

/// Kết quả một thao tác form của Trợ lý (web contracts-assistant `AssistantActionResult`).
class AssistantFormResult {
  /// `saved` | `cancelled` | `unavailable` | `failed`.
  final String outcome;

  /// Mã bản ghi vừa tạo (khi `saved`).
  final String? id;

  /// Tên ngắn của bản ghi, ví dụ tiêu đề cuộc họp.
  final String? label;

  /// Đường dẫn web mở bản ghi (ứng dụng mở bằng `NotificationRouter.resolveWebLink`).
  final String? href;

  /// Câu lỗi đọc được (khi `failed`/`unavailable`).
  final String? message;

  const AssistantFormResult(this.outcome, {this.id, this.label, this.href, this.message});

  static const AssistantFormResult cancelled = AssistantFormResult('cancelled');
}

/// Mở form tạo mới của phân hệ, điền sẵn [draft] (khoá theo tên trường của request — xem
/// `packages/contracts/<phân hệ>/src/lib/assistant-actions.ts` bên web), để người dùng xem, sửa và lưu như khi tự nhập.
/// [variant] là mã biến thể (loại đơn tuỳ chỉnh, quy trình) khi thao tác khai `variants`.
/// Đóng form không lưu thì trả [AssistantFormResult.cancelled].
typedef AssistantFormOpener = Future<AssistantFormResult> Function(
  BuildContext context,
  Map<String, dynamic> draft,
  String? variant,
);

/// Các thao tác Trợ lý mobile mở được (web: trang form nhúng `/assistant/form` của từng phân hệ).
const Map<String, AssistantFormOpener> assistantFormOpeners = {
  'workspace.event.create': openAssistantEventForm,
  'workspace.work-item.create': openAssistantWorkItemForm,
  'workspace.standalone-task.create': openAssistantStandaloneTaskForm,
  'hrm.leave-request.create': openAssistantLeaveForm,
  'hrm.ot-request.create': openAssistantOtForm,
  'hrm.business-trip-request.create': openAssistantBusinessTripForm,
  'hrm.custom-request.create': openAssistantCustomRequestForm,
  'maintenance.incident.create': openAssistantIncidentForm,
  'procedure.instance.create': openAssistantProcedureForm,
};
