import 'package:flutter/material.dart';
import 'task_detail/workspace_procedure_steps_panel.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/data/datasources/workspace_task_detail_api.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import 'task_detail/task_detail_format.dart';
import 'task_detail/task_detail_header.dart';
import 'task_detail/task_detail_info_tab.dart' show StandaloneInfoSection;
import 'task_detail/task_detail_meta.dart';
import 'task_detail/task_detail_notices.dart';
import 'task_detail/task_detail_standalone.dart';
import 'task_detail/task_detail_subtasks.dart';
import 'task_detail/task_detail_tabs.dart';
import 'task_detail/workspace_activity_list.dart';
import 'task_detail/workspace_checklist_access.dart';
import 'task_detail/workspace_checklist_panel.dart';
import 'task_detail/workspace_external_links_panel.dart';
import 'task_detail/workspace_progress_panel.dart';
import 'workspace_task_actions_menu.dart';
import 'workspace_task_chat_sheet.dart';

/// Hộp chi tiết công việc (bottom sheet), điều phối các khối con trong `task_detail/`.
/// Việc dự án: web `projects-view.tsx` (WorkItemDialog + NodeHeader + ChildItems + Checklist + TabOverview,
/// cột phụ Lịch sử hoạt động). Công việc khác: web `standalone-tasks-view.tsx` › `TaskDetail`.
void showWorkspaceStandaloneTaskDetailSheet(
  BuildContext context, {
  required StandaloneTaskItem task,
  required WorkspaceService service,
  required VoidCallback onRefresh,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TaskDetailContent(initialTask: task, service: service, onRefresh: onRefresh),
  );
}

class _TaskDetailContent extends StatefulWidget {
  final StandaloneTaskItem initialTask;
  final WorkspaceService service;
  final VoidCallback onRefresh;

  const _TaskDetailContent({required this.initialTask, required this.service, required this.onRefresh});

  @override
  State<_TaskDetailContent> createState() => _TaskDetailContentState();
}

class _TaskDetailContentState extends State<_TaskDetailContent>
    with WorkspaceTaskActionsMixin<_TaskDetailContent> {
  final _api = WorkspaceTaskDetailApi();
  late StandaloneTaskItem _task;
  /// Bản `WorkItem` thô vừa nạp (để đọc `reversal.adjustmentRequested`...).
  Map<String, dynamic>? _raw;
  bool _loading = true;
  String? _error;
  int _seq = 0;
  /// Các việc đã đi qua (nút "← CODE" như web lùi lịch sử).
  final List<StandaloneTaskItem> _back = [];
  int _unread = 0;
  int _linkCount = 0;
  int? _depCount;
  int? _docCount;
  List<Map<String, dynamic>> _tags = const [];
  TaskOverviewTab _tab = TaskOverviewTab.detail;

  bool get _isProject => _task.isProjectTask;

  @override
  StandaloneTaskItem get actionTask => _task;
  @override
  WorkspaceService get actionService => widget.service;
  @override
  VoidCallback get actionOnRefresh => widget.onRefresh;
  @override
  Future<void> reloadTaskDetail() => _fetchDetail();

  @override
  void openTaskChat() => showWorkspaceTaskChatSheet(context, task: _task, service: widget.service);

  @override
  void initState() {
    super.initState();
    _task = widget.initialTask;
    _tab = TaskTabMemory.restore(_task.id);
    _fetchDetail();
    loadTaskContext();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await widget.service.getTags();
    if (!mounted) return;
    setState(() => _tags = tags);
  }

  /// Nạp đúng endpoint theo loại việc (không rơi sang endpoint kia).
  Future<void> _fetchDetail() async {
    final seq = ++_seq;
    final id = _task.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (_isProject) {
      final pid = _task.projectId!;
      final itemF = _api.getWorkItem(id);
      final linksF = countWorkItemExternalLinks(projectId: pid, workItemId: id);
      final unreadF = _api.getRolledUpUnread(pid, id);
      final res = await itemF;
      final links = await linksF;
      final unread = await unreadF;
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _linkCount = links;
        _unread = unread.data ?? 0;
        if (res.ok && res.data != null && res.data!.isNotEmpty) {
          final parsed = StandaloneTaskItem.fromJson(res.data!);
          _raw = res.data;
          _task = parsed.copyWith(
            projectId: parsed.projectId ?? pid,
            projectCode: taskProject?.code ?? _task.projectCode,
            projectName: taskProject?.name ?? _task.projectName,
          );
        } else {
          _error = res.error ?? 'workspace.task_detail.load_failed'.tr();
        }
      });
    } else {
      final res = await _api.getStandaloneTask(id);
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        if (res.ok && res.data != null && res.data!['task'] is Map) {
          standaloneDetail = res.data;
          _task = StandaloneTaskItem.fromJson(res.data!);
        } else {
          _error = res.error ?? 'workspace.task_detail.load_failed'.tr();
        }
      });
    }
  }

  // ------------------------------------------------------------- Điều hướng giữa các việc

  void _show(StandaloneTaskItem next, {required bool push}) {
    setState(() {
      if (push) _back.add(_task);
      _task = next;
      _raw = null;
      if (!next.isProjectTask) standaloneDetail = null;
      _error = null;
      _unread = 0;
      _linkCount = 0;
      _depCount = null;
      _docCount = null;
      _tab = TaskTabMemory.restore(next.id);
    });
    _fetchDetail();
  }

  void _openProjectItem(String id) {
    if (id == _task.id) return;
    final next = taskProjectItems.where((i) => i.id == id).firstOrNull;
    if (next != null) _show(next, push: true);
  }

  /// Mở một việc khác của Công việc khác từ tham chiếu `{id, code, title}` hoặc bản `StandaloneTask`.
  void _openStandaloneRef(Map<String, dynamic> ref) {
    if (ref['id'] == null || ref['id'] == _task.id) return;
    _show(StandaloneTaskItem.fromJson(ref), push: true);
  }

  void _goBack() {
    if (_back.isEmpty) return;
    _show(_back.removeLast(), push: false);
  }

  void _afterPanelChange() {
    _fetchDetail();
    loadTaskContext(force: true);
    widget.onRefresh();
  }

  Future<void> _reportProgress() async {
    final ok = await showReportProgressDialog(context, item: _task, service: widget.service);
    if (ok && mounted) afterTaskChange();
  }

  // ------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          TaskDetailTopBar(
            heading: 'workspace.task_detail.heading'.tr(args: {'code': _task.code}),
            backLabel: _back.isEmpty ? null : _back.last.code,
            onBack: _goBack,
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2, color: Color(0xFF1D4ED8)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (_error != null) ...[
                  TaskNotice.text(_error!, alert: true),
                  const SizedBox(height: 10),
                ],
                ...(_isProject ? _projectBody() : _standaloneBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gap([double h = 12]) => SizedBox(height: h);

  Widget get _chatButton => TaskActionButton(
        label: 'workspace.task_detail.chat'.tr(),
        icon: Icons.chat_bubble_outline_rounded,
        badge: _unread,
        onPressed: openTaskChat,
      );

  Widget get _editButton =>
      TaskActionButton(label: 'common.edit'.tr(), icon: Icons.edit_outlined, onPressed: openEditTask);

  Widget get _busy => const SizedBox(
        width: 22,
        height: 22,
        child: Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2)),
      );

  // ---- Việc dự án

  List<Widget> _projectBody() {
    final t = _task;
    final items = taskProjectItems;
    final byId = {for (final i in items) i.id: i};
    final chain = <StandaloneTaskItem>[];
    final seen = <String>{t.id};
    var cursor = t.parentId == null ? null : byId[t.parentId];
    while (cursor != null && seen.add(cursor.id)) {
      chain.insert(0, cursor);
      cursor = cursor.parentId == null ? null : byId[cursor.parentId];
    }
    final projectCode = taskProject?.code ?? t.projectCode ?? '';
    final quick = projectQuickAction();
    final hasChildren = items.any((i) => i.parentId == t.id);

    // web `progressCellMode` với canWrite = có quyền sửa việc.
    String? lockReason;
    var editable = false;
    if (taskCanEdit) {
      if (t.status == 'done') {
        lockReason = 'workspace.task_detail.progress_lock.done'.tr();
      } else if (t.status == 'cancelled') {
        lockReason = null;
      } else if (hasChildren) {
        lockReason = 'workspace.task_detail.progress_lock.children'.tr();
      } else if (t.progressMethod == 'checklist') {
        lockReason = 'workspace.task_detail.progress_lock.checklist'.tr();
      } else {
        editable = true;
      }
    }

    final reversal = _raw?['reversal'] is Map ? Map<String, dynamic>.from(_raw!['reversal'] as Map) : null;
    final adjustment = items.where((i) => i.meta.adjustmentOfId == t.id && i.status != 'cancelled').firstOrNull;
    final original = t.meta.adjustmentOfId == null ? null : byId[t.meta.adjustmentOfId];
    final me = taskMe;

    return [
      TaskDetailHeader(
        item: t,
        crumbs: [
          if (projectCode.isNotEmpty) TaskDetailCrumb(projectCode, () => Navigator.pop(context)),
          for (final a in chain) TaskDetailCrumb('${a.code} · ${a.title}', () => _openProjectItem(a.id)),
        ],
        kindLabel: taskItemTypeLabel(t.meta.itemType),
        primaryActions: [
          if (taskStatusBusy) _busy,
          if (quick != null && !taskStatusBusy) TaskActionButton(label: quick.label, filled: true, onPressed: quick.onTap),
          if (taskCanAddChild)
            TaskActionButton(
              label: 'workspace.task_detail.add_child'.tr(),
              icon: Icons.add,
              filled: quick == null,
              onPressed: openCreateChildTask,
            ),
        ],
        secondaryActions: [
          _chatButton,
          if (taskCanEdit) _editButton,
          buildTaskActionsMenu(),
        ],
      ),
      if (t.isReversed) ...[
        _gap(8),
        TaskReversalNotice(
          reversedByName: reversal?['reversedByName']?.toString() ?? t.meta.reversedByName,
          reversedAt: DateTime.tryParse(reversal?['reversedAt']?.toString() ?? '') ?? t.meta.reversedAt,
          reason: reversal?['reason']?.toString() ?? t.reversalReason,
          adjustmentCode: adjustment?.code,
          onOpenAdjustment: adjustment == null ? null : () => _openProjectItem(adjustment.id),
          adjustmentRequested: reversal?['adjustmentRequested'] == true,
        ),
      ],
      if (t.meta.adjustmentOfId != null) ...[
        _gap(8),
        TaskAdjustmentOfNotice(
          code: original?.code,
          onOpen: original == null ? null : () => _openProjectItem(original.id),
        ),
      ],
      _gap(),
      TaskDetailMeta(
        item: t,
        projectItems: items,
        tagCatalog: _tags,
        onProgressTap: editable ? _reportProgress : null,
        progressLockedReason: lockReason,
      ),
      if (t.status == 'blocked' && !t.isReversed) ...[
        _gap(),
        TaskBlockedNotice(
          reason: t.blockedReason,
          onEdit: taskCanEditBlockedReason ? editBlockedReason : null,
        ),
      ],
      if (hasChildren) ...[
        _gap(),
        TaskChildItems(
          parent: t,
          items: items,
          canAdd: taskCanAddChild,
          onOpen: (c) => _openProjectItem(c.id),
          onAdd: openCreateChildTask,
        ),
      ],
      if (canShowChecklist(t, items)) ...[
        _gap(),
        WorkspaceChecklistPanel(
          key: ValueKey('checklist-${t.id}'),
          item: t,
          service: widget.service,
          canEdit: canEditChecklist(item: t, userId: me, canWrite: taskCanWrite, canManage: taskCanManage),
          currentUserId: me,
          onChanged: _afterPanelChange,
        ),
      ],
      _gap(),
      ProjectTaskTabs(
        item: t,
        projectItems: items,
        service: widget.service,
        selected: _tab,
        onSelect: (tab) => setState(() => _tab = tab),
        linkCount: _linkCount,
        dependencyCount: _depCount,
        documentCount: _docCount,
        onDependencyCount: (n) {
          if (mounted && n != _depCount) setState(() => _depCount = n);
        },
        onDocumentCount: (n) {
          if (mounted && n != _docCount) setState(() => _docCount = n);
        },
        canWrite: taskCanWrite,
        canManage: taskCanManage,
        canDelete: taskCanDelete,
        onChanged: _afterPanelChange,
        onOpenItem: _openProjectItem,
        onReportQuantity: _reportProgress,
      ),
      _gap(),
      // Trao đổi của công việc hiện ngay trong màn chi tiết, trên "Lịch sử hoạt động".
      WorkspaceTaskChatPanel(key: ValueKey('chat-${t.id}'), task: t, service: widget.service),
      _gap(),
      TaskPanel(
        title: Text('workspace.task_detail.activity_title'.tr()),
        child: WorkspaceActivityList(
          key: ValueKey('activity-${t.id}'),
          projectId: t.projectId!,
          service: widget.service,
          projectItems: items,
          itemIds: taskBranchOf(items, t.id),
          onOpenItem: _openProjectItem,
        ),
      ),
    ];
  }

  // ---- Công việc khác

  List<Widget> _standaloneBody() {
    final t = _task;
    final d = standaloneDetail;
    final procedure = (d?['task'] as Map?)?['procedure'];
    final procedureInstanceId =
        procedure is Map && (procedure['instanceId']?.toString() ?? '').isNotEmpty ? procedure['instanceId'].toString() : null;
    final ancestors = (d?['ancestors'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ??
        const <Map<String, dynamic>>[];
    final children = (d?['children'] as List?)
            ?.whereType<Map>()
            .map((e) => StandaloneTaskItem.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <StandaloneTaskItem>[];
    final open = t.status != 'done' && t.status != 'cancelled';
    final canProgress = open && (standaloneIsAssigner || standaloneIsExecutor);
    final roleLabel = 'workspace.task_detail.standalone.role.$standaloneRole'.tr();

    return [
      TaskDetailHeader(
        item: t,
        crumbs: [
          for (final a in ancestors) TaskDetailCrumb('${a['code'] ?? ''} · ${a['title'] ?? ''}', () => _openStandaloneRef(a)),
        ],
        subtitle: d == null
            ? null
            : '${'workspace.task_detail.standalone.your_role'.tr(args: {'role': roleLabel})}'
                '${t.parentId != null ? 'workspace.task_detail.standalone.child_note'.tr() : ''}',
        primaryActions: [
          if (taskStatusBusy) _busy,
          if (!taskStatusBusy)
            for (final next in standaloneAllowed)
              TaskActionButton(
                label: standaloneTransitionLabel(t.status, next, standaloneIsAssigner),
                filled: next == 'done' || next == 'review',
                danger: next == 'cancelled',
                onPressed: () => standaloneTransition(next),
              ),
        ],
        secondaryActions: [
          _chatButton,
          if (taskCanEdit) _editButton,
          buildTaskActionsMenu(),
        ],
      ),
      if (t.status == 'blocked' && !t.isReversed) ...[
        _gap(),
        TaskBlockedNotice(reason: t.blockedReason, onEdit: taskCanEditBlockedReason ? editBlockedReason : null),
      ],
      _gap(),
      StandaloneTaskNotices(
        task: t,
        detail: d,
        isAssigner: standaloneIsAssigner,
        isExecutor: standaloneIsExecutor,
        canCreateAdjustment: taskCanCreateAdjustment,
        onOpenRef: _openStandaloneRef,
        onCreateAdjustment: () => openAdjustmentForm(),
      ),
      StandaloneInfoSection(
        task: t,
        onProgressTap: canProgress && !taskStatusBusy ? _reportProgress : null,
        progressLockedReason: t.status == 'done' ? 'workspace.task_detail.progress_lock.done'.tr() : null,
      ),
      // Web: việc có hồ sơ quy trình đã mở thì hiện các bước của hồ sơ.
      if (procedureInstanceId != null) ...[
        _gap(),
        WorkspaceProcedureStepsPanel(
          key: ValueKey('procedure-steps-${t.id}'),
          id: t.id,
          standalone: true,
          version: '${(d?['task'] as Map?)?['updatedAt'] ?? ''}|${t.status}|$procedureInstanceId',
        ),
      ],
      if (canShowChecklist(t, const [])) ...[
        _gap(),
        WorkspaceChecklistPanel(
          key: ValueKey('checklist-${t.id}'),
          item: t,
          service: widget.service,
          canEdit: canEditStandaloneChecklist(standaloneRole),
          currentUserId: taskMe,
          onChanged: _afterPanelChange,
        ),
      ],
      _gap(),
      TaskPanel(
        title: Text('workspace.task_detail.tab.progress'.tr()),
        child: WorkspaceProgressPanel(
          key: ValueKey('progress-${t.id}'),
          item: t,
          service: widget.service,
          canReport: canProgress,
          onChanged: _afterPanelChange,
        ),
      ),
      _gap(),
      StandaloneChildItems(
        parent: t,
        children: children,
        canAdd: taskCanAddChild,
        onOpen: (c) => _show(c, push: true),
        onAdd: openCreateChildTask,
      ),
      _gap(),
      StandaloneHistoryList(entries: standaloneHistoryOf(d)),
    ];
  }
}
