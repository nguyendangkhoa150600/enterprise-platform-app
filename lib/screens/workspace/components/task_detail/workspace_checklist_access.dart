import '../../../../models/workspace_models.dart';

/// Giới hạn từ contract `MAX_CHECKLIST_ITEMS` / `CHECKLIST_TITLE_MAX_LENGTH`.
const int maxChecklistItems = 50;
const int checklistTitleMaxLength = 200;

/// Khoá i18n của các lời giải thích (web `checklist-access.ts`).
const String checklistNotTrackedNoteKey = 'workspace.checklist.note_not_tracked';
const String standaloneChecklistReadonlyNoteKey = 'workspace.checklist.note_standalone_readonly';

/// Trạng thái panel checklist; [reasonKey] là khoá i18n (rỗng khi không có lời giải thích).
class ChecklistPanelState {
  final bool visible;
  final bool editable;
  final bool canAdd;
  final String reasonKey;

  const ChecklistPanelState({
    required this.visible,
    required this.editable,
    required this.canAdd,
    required this.reasonKey,
  });
}

/// Việc có thể có checklist (web `canShowChecklist` / `canShowStandaloneChecklist`, chọn theo loại việc).
/// Việc dự án: loại task, chưa huỷ hiệu lực, không có việc con còn hiệu lực.
/// Công việc khác: không có việc con, không chạy theo quy trình, chưa huỷ hiệu lực.
/// Việc đã xong / huỷ mà chưa có đầu việc nào ([checklistCount] == 0) thì không hiện.
bool canShowChecklist(StandaloneTaskItem item, List<StandaloneTaskItem> projectItems, [int? checklistCount]) {
  if (item.isReversed) return false;
  if (item.isProjectTask) {
    if (item.meta.itemType != 'task') return false;
    if (projectItems.any((child) => child.parentId == item.id && child.status != 'cancelled')) return false;
  } else {
    if (item.childCount > 0 || item.meta.executionType == 'procedure') return false;
  }
  final closed = item.status == 'done' || item.status == 'cancelled';
  return !(closed && checklistCount == 0);
}

/// Quyền sửa checklist ở giao diện (server mới là nơi chặn thật).
/// Việc dự án: có quyền ghi và là quản lý, người phụ trách, người cùng làm hoặc người tạo việc.
/// Công việc khác: người giao, người phụ trách, người cùng làm (`myRole`).
bool canEditChecklist({
  required StandaloneTaskItem item,
  required String? userId,
  required bool canWrite,
  required bool canManage,
}) {
  if (!item.isProjectTask) return canEditStandaloneChecklist(item.myRole);
  if (!canWrite || item.isReversed) return false;
  if (canManage) return true;
  if (userId == null || userId.isEmpty) return false;
  return item.assigneeUserId == userId || item.participantUserIds.contains(userId) || item.createdBy == userId;
}

bool canEditStandaloneChecklist(String? role) => role == 'assigner' || role == 'assignee' || role == 'participant';

/// Giao diện chỉ mở thao tác mà server sẽ nhận: tích / sửa / xoá khi cách tính là `checklist`; thêm khi là
/// `checklist` hoặc `manual` chưa có đầu việc nào (thêm đầu việc đầu tiên tự chuyển sang `checklist`).
ChecklistPanelState checklistPanelState({
  String? method,
  required bool closed,
  required bool canEdit,
  required int total,
  int max = maxChecklistItems,
  String? cannotEditReasonKey,
}) {
  final m = method ?? 'manual';
  final open = canEdit && !closed;
  final editable = open && m == 'checklist';
  final canAdd = open && total < max && (m == 'checklist' || (m == 'manual' && total == 0));
  final visible = !(total == 0 && (closed || m == 'quantity'));
  var reason = '';
  if (closed) {
    reason = 'workspace.checklist.note_closed';
  } else if (!canEdit) {
    reason = cannotEditReasonKey ?? 'workspace.checklist.note_no_permission';
  } else if (m == 'quantity') {
    reason = 'workspace.checklist.note_quantity';
  } else if (m == 'child_weight' || (m == 'manual' && total > 0)) {
    reason = checklistNotTrackedNoteKey;
  }
  return ChecklistPanelState(visible: visible, editable: editable, canAdd: canAdd, reasonKey: reason);
}

/// Phần trăm đầu việc đã tích, làm tròn; 0 khi chưa có đầu việc.
int checklistPercent(int done, int total) => total <= 0 ? 0 : ((done / total) * 100).round();

final RegExp _linePrefix = RegExp(r'^\s*(?:(?:[-*•]|\d{1,2}[.)])\s+)?(?:\[[ xX]?\]\s*)?');

/// Tách văn bản dán thành nhiều đầu việc: mỗi dòng một đầu việc, bỏ dòng trống, gạch đầu dòng, số thứ tự ngắn và ô tích.
List<String> splitChecklistLines(String text) => text
    .split(RegExp(r'\r?\n'))
    .map((line) => line.replaceFirst(_linePrefix, '').trim())
    .where((line) => line.isNotEmpty)
    .toList();
