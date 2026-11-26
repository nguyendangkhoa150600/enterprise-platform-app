import 'workspace_api_base.dart';

/// Một lần báo cáo tiến độ (`WorkItemProgressReport` / `StandaloneTaskProgressReport`).
class ProgressReportEntry {
  final String id;
  /// Ngày báo cáo `YYYY-MM-DD`.
  final String reportedOn;
  final String reportedBy;
  final int percent;
  final double? quantityDone;
  final String? description;

  const ProgressReportEntry({
    required this.id,
    required this.reportedOn,
    required this.reportedBy,
    required this.percent,
    this.quantityDone,
    this.description,
  });

  factory ProgressReportEntry.fromJson(Map<String, dynamic> json) => ProgressReportEntry(
        id: json['id']?.toString() ?? '',
        reportedOn: json['reportedOn']?.toString() ?? '',
        reportedBy: json['reportedBy']?.toString() ?? '',
        percent: num.tryParse(json['percent']?.toString() ?? '')?.round() ?? 0,
        quantityDone: num.tryParse(json['quantityDone']?.toString() ?? '')?.toDouble(),
        description: json['description']?.toString(),
      );
}

/// Kết quả sau khi báo cáo / đưa về tự động: trạng thái và tiến độ mới của công việc.
class ProgressOutcome {
  final String? status;
  final int? percent;
  const ProgressOutcome({this.status, this.percent});

  /// Việc dự án trả `WorkItem`; Công việc khác trả `StandaloneTaskDetail` `{task: ...}`.
  factory ProgressOutcome.fromJson(dynamic data) {
    final map = data is Map ? (data['task'] is Map ? data['task'] as Map : data) : const {};
    return ProgressOutcome(
      status: map['status']?.toString(),
      percent: num.tryParse(map['progressPercent']?.toString() ?? '')?.round(),
    );
  }
}

/// Cài đặt báo cáo tiến độ (`ProjectArchiveSettings`): trạng thái sau khi báo 100% và có bắt buộc mô tả không.
class ProgressReportSettings {
  final String completeStatus;
  final bool requireDescription;
  const ProgressReportSettings({this.completeStatus = 'done', this.requireDescription = false});
}

/// Báo cáo tiến độ: việc dự án `/work-items/:id/...`, Công việc khác `/standalone-tasks/:id/...` (không lẫn nhau).
class WorkspaceProgressApi extends WorkspaceApiBase {
  static final WorkspaceProgressApi _instance = WorkspaceProgressApi._internal();
  factory WorkspaceProgressApi() => _instance;
  WorkspaceProgressApi._internal();

  String _task(String id, bool isProjectTask) => isProjectTask
      ? '${WorkspaceApiBase.root}/work-items/$id'
      : '${WorkspaceApiBase.root}/standalone-tasks/$id';

  Future<WorkspaceApiResult<List<ProgressReportEntry>>> listReports({
    required String taskId,
    required bool isProjectTask,
  }) =>
      send(
        'GET',
        '${_task(taskId, isProjectTask)}/progress-reports',
        parse: (data) => WorkspaceApiBase.itemsOf(data).map(ProgressReportEntry.fromJson).toList(),
      );

  /// `ReportWorkItemProgressRequest`: `percent` (số nguyên) hoặc `quantityDone`, `description`, `reportedOn`.
  Future<WorkspaceApiResult<ProgressOutcome>> report({
    required String taskId,
    required bool isProjectTask,
    int? percent,
    double? quantityDone,
    String? description,
    String? reportedOn,
  }) =>
      send(
        'POST',
        '${_task(taskId, isProjectTask)}/progress-reports',
        body: {
          'percent': ?percent,
          'quantityDone': ?quantityDone,
          'description': ?description,
          'reportedOn': ?reportedOn,
        },
        parse: ProgressOutcome.fromJson,
      );

  /// "Về tiến độ tự động": bỏ số nhập tay, không tạo báo cáo.
  Future<WorkspaceApiResult<ProgressOutcome>> clearManual({required String taskId, required bool isProjectTask}) =>
      send('PATCH', _task(taskId, isProjectTask), body: {'manualProgressPercent': null}, parse: ProgressOutcome.fromJson);

  Future<WorkspaceApiResult<ProgressReportSettings>> loadSettings() => send(
        'GET',
        '${WorkspaceApiBase.root}/project-archive-settings',
        parse: (data) {
          final map = data is Map ? data : const {};
          final status = map['progressReportCompleteStatus']?.toString();
          return ProgressReportSettings(
            completeStatus: (status == null || status.isEmpty) ? 'done' : status,
            requireDescription: map['progressReportRequireDescription'] == true,
          );
        },
      );
}
