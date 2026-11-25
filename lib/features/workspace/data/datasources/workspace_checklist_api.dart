import 'workspace_api_base.dart';

/// Một đầu việc trong checklist tiến độ (`WorkItemChecklistItem` / `StandaloneTaskChecklistItem`).
class ChecklistEntry {
  final String id;
  final String title;
  final bool done;
  final DateTime? doneAt;
  final String? doneBy;
  final int sortOrder;

  const ChecklistEntry({
    required this.id,
    required this.title,
    required this.done,
    this.doneAt,
    this.doneBy,
    this.sortOrder = 0,
  });

  factory ChecklistEntry.fromJson(Map<String, dynamic> json) => ChecklistEntry(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        done: json['done'] == true,
        doneAt: DateTime.tryParse(json['doneAt']?.toString() ?? '')?.toLocal(),
        doneBy: json['doneBy']?.toString(),
        sortOrder: num.tryParse(json['sortOrder']?.toString() ?? '')?.toInt() ?? 0,
      );

  /// Bản sao với trạng thái tích mới; người tích / giờ tích bỏ khi bỏ tích (server ghi lại).
  ChecklistEntry withDone(bool value, {String? by, DateTime? at}) => ChecklistEntry(
        id: id,
        title: title,
        done: value,
        doneBy: value ? by : null,
        doneAt: value ? at : null,
        sortOrder: sortOrder,
      );

  ChecklistEntry withTitle(String value) =>
      ChecklistEntry(id: id, title: value, done: done, doneAt: doneAt, doneBy: doneBy, sortOrder: sortOrder);
}

/// Checklist tiến độ: việc trong dự án `/work-items/:id/checklist`, Công việc khác `/standalone-tasks/:id/checklist`.
/// Mọi lời gọi ghi trả lại cả danh sách `{items}` như web.
class WorkspaceChecklistApi extends WorkspaceApiBase {
  static final WorkspaceChecklistApi _instance = WorkspaceChecklistApi._internal();
  factory WorkspaceChecklistApi() => _instance;
  WorkspaceChecklistApi._internal();

  String _base(String id, bool isProjectTask) => isProjectTask
      ? '${WorkspaceApiBase.root}/work-items/$id/checklist'
      : '${WorkspaceApiBase.root}/standalone-tasks/$id/checklist';

  static List<ChecklistEntry> _parse(dynamic data) =>
      WorkspaceApiBase.itemsOf(data).map(ChecklistEntry.fromJson).toList();

  Future<WorkspaceApiResult<List<ChecklistEntry>>> list({required String taskId, required bool isProjectTask}) =>
      send('GET', _base(taskId, isProjectTask), parse: _parse);

  Future<WorkspaceApiResult<List<ChecklistEntry>>> add({
    required String taskId,
    required bool isProjectTask,
    required List<String> titles,
  }) =>
      send('POST', _base(taskId, isProjectTask), body: {'titles': titles}, parse: _parse);

  Future<WorkspaceApiResult<List<ChecklistEntry>>> update({
    required String taskId,
    required bool isProjectTask,
    required String itemId,
    String? title,
    bool? done,
  }) =>
      send(
        'PATCH',
        '${_base(taskId, isProjectTask)}/$itemId',
        body: {'title': ?title, 'done': ?done},
        parse: _parse,
      );

  Future<WorkspaceApiResult<List<ChecklistEntry>>> remove({
    required String taskId,
    required bool isProjectTask,
    required String itemId,
  }) =>
      send('DELETE', '${_base(taskId, isProjectTask)}/$itemId', parse: _parse);
}
