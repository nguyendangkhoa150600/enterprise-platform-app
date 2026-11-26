import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/data/datasources/workspace_api_base.dart';
import '../../../features/workspace/data/datasources/workspace_calendar_api.dart';
import '../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../models/workspace_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/workspace_service.dart';
import '../../workspace/components/create_item/create_item_draft.dart';
import '../../workspace/components/project_tabs/calendar/calendar_event_form_sheet.dart';
import '../../workspace/components/project_tabs/calendar/calendar_people_picker.dart';
import '../../workspace/components/workspace_create_subtask_sheet.dart';
import '../../workspace/components/workspace_standalone_task_dialog.dart';
import 'assistant_form_registry.dart';

// Form tạo của Workspace mà Trợ lý Savina mở với bản nháp (web `components/assistant-forms.tsx` +
// `assistant-drafts.ts`): cuộc họp / sự kiện, công việc trong dự án, việc ngoài dự án. Form và API là của chính phân
// hệ; người dùng xem lại rồi bấm lưu như khi tự nhập. Bản nháp khoá theo tên trường của request API, giá trị chưa được
// tin: ô sai kiểu bị bỏ để form kiểm như khi người dùng tự nhập.

const _eventTypes = ['meeting', 'activity', 'other'];
const _workItemTypes = ['task', 'milestone', 'phase'];
const _priorities = ['low', 'normal', 'high', 'urgent'];
const _defaultEventMinutes = 60;
final _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

String? _text(dynamic value) => value is String && value.trim().isNotEmpty ? value.trim() : null;

String? _oneOf(List<String> values, dynamic value) => value is String && values.contains(value) ? value : null;

/// Mảng mã không rỗng, bỏ trùng; vắng hoặc sai kiểu là null (web `idList`).
List<String>? _idList(dynamic value, [List<String> exclude = const []]) {
  if (value is! List) return null;
  final ids = <String>[];
  for (final id in value) {
    if (id is String && id.trim().isNotEmpty && !exclude.contains(id) && !ids.contains(id)) ids.add(id);
  }
  return ids;
}

/// Mốc ISO 8601 (kèm múi giờ) đổi về giờ máy.
DateTime? _instant(dynamic value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// `YYYY-MM-DD`, hoặc mốc ISO đổi về ngày theo giờ máy (web `dateValue`).
DateTime? _dateValue(dynamic value) {
  if (value is String && _dateOnly.hasMatch(value)) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }
  final parsed = _instant(value);
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
}

String? get _currentUserId {
  final id = AuthProvider.instance?.userId;
  return id == null || id.isEmpty ? null : id;
}

/// `CODE · tên` của bản ghi vừa tạo, như nhãn web gửi về card.
String _codeTitle(Map<String, dynamic> record) {
  final code = record['code']?.toString() ?? '';
  final title = record['title']?.toString() ?? '';
  return code.isEmpty ? title : '$code · $title';
}

/// Trạng thái Workspace (`GET /status`) để biết người dùng có tạo được gì không (web `loadWorkspaceStatus`).
class _WorkspaceStatusApi extends WorkspaceApiBase {
  Future<WorkspaceApiResult<Map<String, dynamic>>> status() => send(
        'GET',
        '${WorkspaceApiBase.root}/status',
        parse: (data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
      );
}

/// Web `assistantUnavailableReason`: dữ liệu tenant đang khởi tạo, hoặc thiếu quyền ghi. Chưa đọc được trạng thái thì
/// không chặn, server vẫn kiểm khi lưu.
Future<String?> _unavailableReason() async {
  final res = await _WorkspaceStatusApi().status();
  final status = res.data;
  if (!res.ok || status == null) return null;
  if (status['tablesReady'] == false) return 'workspace.assistant.unavailable_tables'.tr();
  final capabilities = status['capabilities'];
  if (capabilities is Map && capabilities['canWriteTasks'] != true && capabilities['isTenantAdmin'] != true) {
    return 'workspace.assistant.unavailable_permission'.tr();
  }
  return null;
}

/// Dự án của bản nháp, kiểm người dùng thấy và ghi được (form tạo trong dự án cần quyền ghi).
Future<({ProjectItem? project, String? problem})> _writableProject(WorkspaceService service, String projectId) async {
  final project = await service.getProjectDetail(projectId);
  if (project == null) return (project: null, problem: 'workspace.assistant.project_not_found'.tr());
  if (!project.access.canWrite) return (project: null, problem: 'workspace.assistant.project_read_only'.tr());
  return (project: project, problem: null);
}

// ---------------------------------------------------------------------------------------------------------------
// Cuộc họp / sự kiện (`workspace.event.create`, `CreateEventRequest`)

/// Web `eventDraftToForm`.
CalendarEventPrefill _eventPrefill(Map<String, dynamic> draft, String? organizerUserId) {
  final start = _instant(draft['startAt']);
  final end = _instant(draft['endAt']);
  DateTime? date;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  if (start != null) {
    date = start;
    startTime = TimeOfDay.fromDateTime(start);
    // Không nói giờ kết thúc: một tiếng sau giờ bắt đầu, không vượt qua nửa đêm (form chỉ có một ngày).
    final until = end != null && end.isAfter(start) ? end : start.add(const Duration(minutes: _defaultEventMinutes));
    final sameDay = until.year == start.year && until.month == start.month && until.day == start.day;
    endTime = sameDay ? TimeOfDay.fromDateTime(until) : const TimeOfDay(hour: 23, minute: 59);
  } else if (end != null) {
    endTime = TimeOfDay.fromDateTime(end);
  }
  final allDay = draft['allDay'];
  return CalendarEventPrefill(
    title: _text(draft['title']),
    description: _text(draft['description']),
    location: _text(draft['location']),
    eventType: _oneOf(_eventTypes, draft['eventType']),
    date: date,
    startTime: startTime,
    endTime: endTime,
    allDay: allDay is bool ? allDay : null,
    participantUserIds: _idList(draft['participantUserIds'], [?organizerUserId]),
  );
}

/// Đường dẫn mở sự kiện vừa tạo; sự kiện cá nhân không có trang riêng, nó hiện ở lịch của "Công việc của tôi".
String _eventHref(String eventId, String? projectId) => projectId != null
    ? '/modules/workspace?project=${Uri.encodeComponent(projectId)}#projects/calendar/$eventId'
    : '/modules/workspace#my-work';

Future<AssistantFormResult> openAssistantEventForm(
  BuildContext context,
  Map<String, dynamic> draft,
  String? variant,
) async {
  final unavailable = await _unavailableReason();
  if (unavailable != null) return AssistantFormResult('unavailable', message: unavailable);

  final service = WorkspaceService();
  final projectId = _text(draft['projectId']);
  ProjectItem? project;
  if (projectId != null) {
    final checked = await _writableProject(service, projectId);
    if (checked.problem != null) return AssistantFormResult('unavailable', message: checked.problem);
    project = checked.project;
  }

  final directory = await service.getDirectory();
  final members = projectId != null ? await service.getProjectMembers(projectId) : const <ProjectMemberItem>[];
  final people = {for (final p in directory?.people ?? const <WorkspaceDirectoryPerson>[]) p.userId: p};
  String nameOf(String userId) {
    final person = people[userId];
    if (person != null) return person.displayName;
    final member = members.where((m) => m.userId == userId).firstOrNull;
    return member?.fullName ?? member?.email ?? userId;
  }

  // Sự kiện của dự án chỉ mời được thành viên dự án; sự kiện cá nhân mời được cả tổ chức.
  final invitable = projectId != null
      ? [
          for (final m in members)
            CalendarPerson(
              userId: m.userId,
              name: nameOf(m.userId),
              subtitle: people[m.userId]?.positionName ?? people[m.userId]?.email ?? m.email,
            ),
        ]
      : [
          for (final p in people.values)
            CalendarPerson(userId: p.userId, name: p.displayName, subtitle: p.positionName ?? p.email),
        ];

  if (!context.mounted) return AssistantFormResult.cancelled;
  final organizer = _currentUserId;
  CalendarOccurrence? created;
  await showCalendarEventFormSheet(
    context,
    api: WorkspaceCalendarApi(),
    projectId: projectId,
    currentUserId: organizer ?? '',
    isTenantAdmin: AuthProvider.instance?.isTenantAdmin == true,
    invitable: invitable,
    nameOf: nameOf,
    onChanged: () {},
    prefill: _eventPrefill(draft, organizer),
    projectLabel: project == null ? null : '${project.code}-${project.name}',
    onCreated: (occurrence) => created ??= occurrence,
  );
  final event = created;
  if (event == null) return AssistantFormResult.cancelled;
  return AssistantFormResult(
    'saved',
    id: event.eventId,
    label: event.title,
    href: _eventHref(event.eventId, event.projectId ?? projectId),
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Công việc trong dự án (`workspace.work-item.create`, `CreateWorkItemRequest`)

/// Web `workItemDraftToForm`: không nói người phụ trách thì chọn sẵn chính người dùng.
CreateItemDraft _workItemDraft(Map<String, dynamic> draft, String? defaultAssigneeUserId) {
  final assignee = _text(draft['assigneeUserId']) ?? defaultAssigneeUserId;
  final rawHours = draft['estimateHours'];
  final hours = rawHours is String ? num.tryParse(rawHours.trim()) : (rawHours is num ? rawHours : null);
  final validHours = hours != null && hours.isFinite && hours >= 0 ? hours : null;
  return CreateItemDraft(
    title: _text(draft['title']) ?? '',
    description: _text(draft['description']) ?? '',
    itemType: _oneOf(_workItemTypes, draft['itemType']) ?? 'task',
    priority: _oneOf(_priorities, draft['priority']) ?? 'normal',
    assigneeUserId: assignee ?? '',
    participantUserIds: _idList(draft['participantUserIds'], [?assignee]) ?? const [],
    startDate: _dateValue(draft['plannedStart']),
    dueDate: _dateValue(draft['plannedEnd']),
    estHours: validHours == null
        ? ''
        : (validHours == validHours.roundToDouble() ? '${validHours.toInt()}' : '$validHours'),
  );
}

Future<AssistantFormResult> openAssistantWorkItemForm(
  BuildContext context,
  Map<String, dynamic> draft,
  String? variant,
) async {
  final unavailable = await _unavailableReason();
  if (unavailable != null) return AssistantFormResult('unavailable', message: unavailable);

  final projectId = _text(draft['projectId']);
  if (projectId == null) {
    return AssistantFormResult('unavailable', message: 'workspace.assistant.project_required'.tr());
  }
  final service = WorkspaceService();
  final checked = await _writableProject(service, projectId);
  final project = checked.project;
  if (project == null) return AssistantFormResult('unavailable', message: checked.problem);

  if (!context.mounted) return AssistantFormResult.cancelled;
  Map<String, dynamic>? created;
  await showWorkspaceCreateSubtaskSheet(
    context,
    parentTask: null,
    projectId: project.id,
    projectCode: project.code,
    projectName: project.name,
    access: project.access,
    service: service,
    onCreated: () {},
    initialDraft: _workItemDraft(draft, _currentUserId),
    onItemCreated: (record) => created ??= record,
  );
  final record = created;
  final id = record?['id']?.toString() ?? '';
  if (record == null || id.isEmpty) return AssistantFormResult.cancelled;
  final itemProjectId = _text(record['projectId']) ?? project.id;
  return AssistantFormResult(
    'saved',
    id: id,
    label: _codeTitle(record),
    href: '/modules/workspace?project=${Uri.encodeComponent(itemProjectId)}#projects/work-item/$id',
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Việc ngoài dự án (`workspace.standalone-task.create`, `CreateStandaloneTaskRequest`)

/// Web `standaloneTaskDraftToForm`: một người chỉ giữ một vai, như khi chọn trên form.
StandaloneTaskPrefill _standaloneTaskPrefill(Map<String, dynamic> draft, String? defaultAssigneeUserId) {
  final assignee = _text(draft['assigneeUserId']) ?? defaultAssigneeUserId;
  final participants = _idList(draft['participantUserIds'], [?assignee]);
  final followers = _idList(draft['followerUserIds'], [?assignee, ...?participants]);
  return StandaloneTaskPrefill(
    title: _text(draft['title']),
    description: _text(draft['description']),
    priority: _oneOf(_priorities, draft['priority']),
    assigneeUserId: assignee,
    participantUserIds: participants,
    followerUserIds: followers,
    plannedStart: _dateValue(draft['plannedStart']),
    dueDate: _dateValue(draft['dueDate']),
  );
}

Future<AssistantFormResult> openAssistantStandaloneTaskForm(
  BuildContext context,
  Map<String, dynamic> draft,
  String? variant,
) async {
  final unavailable = await _unavailableReason();
  if (unavailable != null) return AssistantFormResult('unavailable', message: unavailable);
  if (!context.mounted) return AssistantFormResult.cancelled;

  Map<String, dynamic>? created;
  await showWorkspaceAssignStandaloneTaskModal(
    context,
    service: WorkspaceService(),
    onCreated: () {},
    prefill: _standaloneTaskPrefill(draft, _currentUserId),
    onTaskCreated: (record) => created ??= record,
  );
  final record = created;
  final id = record?['id']?.toString() ?? '';
  if (record == null || id.isEmpty) return AssistantFormResult.cancelled;
  return AssistantFormResult(
    'saved',
    id: id,
    label: _codeTitle(record),
    href: '/modules/workspace#tasks/$id',
  );
}
