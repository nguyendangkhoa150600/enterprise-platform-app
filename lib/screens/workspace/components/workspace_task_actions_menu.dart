import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../models/workspace_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/app_toast.dart';
import 'task_detail/task_detail_text_prompt.dart';
import 'task_detail/workspace_reverse_work_item_dialog.dart';
import 'workspace_cancel_work_item_dialog.dart';
import 'workspace_complete_work_item_dialog.dart';
import 'workspace_create_subtask_sheet.dart';
import 'workspace_edit_task_dialog.dart';
import 'workspace_move_task_dialog.dart';

export 'task_detail/task_detail_text_prompt.dart' show showWorkspaceTextPromptDialog;

/// Thao tác nhanh trên khối đầu công việc (web `quickActionFor`).
typedef TaskQuickAction = ({String label, VoidCallback onTap});

/// Ngữ cảnh quyền + menu "⋯" + đổi trạng thái của chi tiết công việc.
/// Việc dự án: web `projects-view.tsx` (allActionsFor / onAction / quickActionFor).
/// Công việc khác: web `standalone-tasks-view.tsx` (allowedStatuses, transitionLabel, vai của tôi).
mixin WorkspaceTaskActionsMixin<T extends StatefulWidget> on State<T> {
  StandaloneTaskItem get actionTask;
  WorkspaceService get actionService;
  VoidCallback get actionOnRefresh;
  Future<void> reloadTaskDetail();
  void openTaskChat();

  ProjectItem? taskProject;
  List<StandaloneTaskItem> taskProjectItems = const [];
  /// Công việc khác: `StandaloneTaskDetail` do màn chi tiết nạp (vai, bước chuyển, quyền...).
  Map<String, dynamic>? standaloneDetail;
  bool taskStatusBusy = false;
  bool _contextRequested = false;

  bool get _isProject => actionTask.isProjectTask;
  String? get taskMe => AuthProvider.instance?.userId;
  ProjectAccess? get taskAccess => taskProject?.access;
  bool get taskArchived => taskProject?.isArchived ?? false;

  String get standaloneRole => standaloneDetail?['myRole']?.toString() ?? actionTask.myRole;
  bool get standaloneIsAssigner => standaloneRole == 'assigner';
  bool get standaloneIsExecutor => standaloneRole == 'assignee' || standaloneRole == 'participant';
  List<String> get standaloneAllowed =>
      (standaloneDetail?['allowedStatuses'] as List?)?.map((e) => e.toString()).toList() ?? const [];
  bool _sd(String key) => standaloneDetail?[key] == true;

  /// Việc lẻ không có quyền dự án: giữ hành vi cũ (được thao tác).
  bool get taskCanWrite => !_isProject || (taskAccess?.canWrite ?? false);
  bool get taskCanManage => !_isProject || (taskAccess?.canManage ?? false);
  bool get taskCanCancelItem => !_isProject || (taskAccess?.canCancelItem ?? false);
  bool get taskCanOwn => _isProject && (taskAccess?.canOwn ?? false);

  /// "Chỉnh sửa": việc dự án cần quyền ghi và việc chưa huỷ hiệu lực; Công việc khác chỉ người giao.
  bool get taskCanEdit => _isProject ? taskCanWrite && !actionTask.isReversed : standaloneIsAssigner;

  bool get taskCanAddChild => _isProject
      ? taskCanWrite && actionTask.meta.depth < ProjectAccess.maxDepth && !actionTask.isReversed
      : _sd('canAddChild');

  bool get taskCanDelete => _isProject
      ? (taskAccess?.canDeleteItem ?? false)
      : standaloneIsAssigner &&
          !actionTask.isReversed &&
          (actionTask.status == 'todo' || actionTask.status == 'cancelled');

  bool get _canCancel => _isProject
      ? taskCanWrite && taskCanCancelItem && _canMoveTo('cancelled')
      : standaloneAllowed.contains('cancelled');

  /// Ghi / sửa lý do vướng mắc: web dự án `canWrite`; Công việc khác: việc đang mở và có bước chuyển.
  bool get taskCanEditBlockedReason => _isProject
      ? taskCanWrite
      : actionTask.status != 'done' && actionTask.status != 'cancelled' && standaloneAllowed.isNotEmpty;

  /// "Huỷ hiệu lực…": việc đã hoàn thành, chủ nhiệm/quản trị (web `reverse-item`).
  bool get taskCanReverse => _isProject && actionTask.status == 'done' && taskCanOwn;

  /// "Lập công việc điều chỉnh": việc đã huỷ hiệu lực, chưa có việc điều chỉnh còn hiệu lực.
  bool get taskCanCreateAdjustment => _isProject
      ? actionTask.isReversed &&
          taskCanWrite &&
          !taskProjectItems.any((i) => i.meta.adjustmentOfId == actionTask.id && i.status != 'cancelled')
      : _sd('canCreateAdjustment');

  bool _canMoveTo(String to) =>
      actionTask.status != to && WorkItemTransitions.canTransition(actionTask.status, to);

  /// Nạp dự án (quyền) và danh sách công việc của dự án — chỉ cho việc thuộc dự án.
  Future<void> loadTaskContext({bool force = false}) async {
    final projectId = actionTask.projectId;
    if (projectId == null || projectId.isEmpty) return;
    if (_contextRequested && !force) return;
    _contextRequested = true;
    try {
      final results = await Future.wait<Object?>([
        actionService.getProjectDetail(projectId),
        actionService.getProjectWorkItems(projectId),
      ]);
      if (!mounted) return;
      setState(() {
        taskProject = (results[0] as ProjectItem?) ?? taskProject;
        taskProjectItems = results[1] as List<StandaloneTaskItem>;
      });
    } catch (e) {
      debugPrint('[TaskActions] loadTaskContext error: $e');
    }
  }

  void afterTaskChange() {
    reloadTaskDetail();
    loadTaskContext(force: true);
    actionOnRefresh();
  }

  // ------------------------------------------------------------- Trạng thái

  Future<bool> _patchStatus(String to, {String? note}) => _isProject
      ? actionService.updateWorkItemStatus(actionTask.id, to, note: note)
      : actionService.changeStandaloneTaskStatus(actionTask.id, to, note: note);

  /// web `toastStatusChanged`: chỉ báo khi Bắt đầu, Hoàn thành hoặc Hoàn tác.
  void _toastStatusChanged(String from, String to, String code) {
    String? action;
    if (to == 'done' && from != 'done') {
      action = 'complete';
    } else if (to == 'in_progress' && from == 'done') {
      action = 'reopen';
    } else if (to == 'in_progress' && from == 'todo') {
      action = 'start';
    }
    if (action != null) AppToast.success(context, 'workspace.task_detail.toast.$action'.tr(args: {'code': code}));
  }

  Future<void> _moveWithToast(String to, String fallbackKey, {String? note}) async {
    final from = actionTask.status;
    final code = actionTask.code;
    setState(() => taskStatusBusy = true);
    final ok = await _patchStatus(to, note: note);
    if (!mounted) return;
    setState(() => taskStatusBusy = false);
    if (ok) {
      _toastStatusChanged(from, to, code);
      afterTaskChange();
    } else {
      AppToast.error(context, actionService.lastError ?? fallbackKey.tr());
    }
  }

  Future<void> _completeProjectItem() async {
    final ok = await showCompleteWorkItemDialog(
      context,
      workItemId: actionTask.id,
      workItemCode: actionTask.code,
      workItemTitle: actionTask.title,
      service: actionService,
    );
    if (ok && mounted) afterTaskChange();
  }

  /// Nút nhanh cho người thực hiện việc dự án (web `quickActionFor`).
  TaskQuickAction? projectQuickAction() {
    final item = actionTask;
    final me = taskMe;
    final performer = me != null && me.isNotEmpty &&
        (item.assigneeUserId == me || item.participantUserIds.contains(me));
    if (taskArchived || item.isReversed || item.meta.isPhase) return null;
    if (item.status == 'done') {
      final policy = item.reopenPolicy ?? 'assignee';
      final allowed = policy != 'none' && taskCanWrite && (taskCanManage || (policy == 'assignee' && performer));
      return allowed
          ? (
              label: 'workspace.task_detail.quick.reopen'.tr(),
              onTap: () => _moveWithToast('in_progress', 'workspace.task_detail.quick.reopen_failed'),
            )
          : null;
    }
    if (!performer) return null;
    if (item.status == 'todo') {
      return (
        label: 'workspace.task.start'.tr(),
        onTap: () => _moveWithToast('in_progress', 'workspace.task_detail.status.update_failed'),
      );
    }
    if (item.status == 'in_progress' || item.status == 'review') {
      return (label: 'workspace.task_detail.quick.complete'.tr(), onTap: _completeProjectItem);
    }
    return null;
  }

  /// Chuyển trạng thái Công việc khác (web `TaskDetail` › thanh trạng thái): vướng mắc qua hộp ghi lý do,
  /// trả lại / huỷ việc bắt buộc lý do, còn lại đổi ngay.
  Future<void> standaloneTransition(String to) async {
    if (to == 'blocked') return editBlockedReason(editing: false);
    final returning = standaloneIsAssigner && actionTask.status == 'review' && to == 'in_progress';
    if (returning || to == 'cancelled') {
      final from = actionTask.status;
      final code = actionTask.code;
      String k(String s) => 'workspace.task_detail.standalone_confirm.$s'.tr();
      final ok = await showWorkspaceTextPromptDialog(
        context,
        title: returning ? k('return_title') : k('cancel_title'),
        subtitle: returning ? k('return_desc') : k('cancel_desc'),
        label: '${returning ? k('return_reason') : k('cancel_reason')} *',
        hint: k('reason_hint'),
        maxLines: 3,
        confirmLabel: returning ? k('return_ok') : k('cancel_ok'),
        accent: returning ? const Color(0xFFD97706) : const Color(0xFFDC2626),
        onSubmit: (reason) async {
          final done = await _patchStatus(to, note: reason);
          return done ? null : (actionService.lastError ?? 'workspace.task_detail.status.update_failed'.tr());
        },
      );
      if (ok && mounted) {
        _toastStatusChanged(from, to, code);
        afterTaskChange();
      }
      return;
    }
    await _moveWithToast(to, 'workspace.task_detail.standalone_confirm.failed');
  }

  /// Báo vướng mắc (bắt buộc lý do) hoặc sửa lý do khi đã vướng mắc.
  Future<void> editBlockedReason({bool editing = true}) async {
    final ok = await showWorkspaceTextPromptDialog(
      context,
      title: (editing ? 'workspace.task_detail.blocked.title_edit' : 'workspace.task_detail.blocked.title').tr(),
      subtitle: '${actionTask.code} · ${actionTask.title}',
      label: '${'workspace.task_detail.blocked.label'.tr()} *',
      hint: 'workspace.task_detail.blocked.hint'.tr(),
      initialText: editing ? (actionTask.blockedReason ?? '') : '',
      maxLines: 5,
      maxLength: 1000,
      confirmLabel: 'workspace.task_detail.blocked.confirm'.tr(),
      accent: const Color(0xFFDC2626),
      icon: Icons.warning_amber_rounded,
      onSubmit: (reason) async {
        final done = await _patchStatus('blocked', note: reason);
        return done ? null : (actionService.lastError ?? 'workspace.task_detail.blocked.failed'.tr());
      },
    );
    if (ok && mounted) afterTaskChange();
  }

  Future<void> _cancelTask() async {
    final ok = await showCancelWorkItemDialog(
      context,
      workItemId: actionTask.id,
      workItemCode: actionTask.code,
      workItemTitle: actionTask.title,
      service: actionService,
      isProjectTask: _isProject,
      openChildren: _openDescendantCount(),
    );
    // Web giữ hộp chi tiết mở, hiện trạng thái "Đã huỷ".
    if (ok && mounted) afterTaskChange();
  }

  // ------------------------------------------------------------- Huỷ hiệu lực / điều chỉnh

  /// "Huỷ hiệu lực…" rồi (việc thủ công, có chọn lập điều chỉnh) mở ngay form công việc điều chỉnh.
  Future<void> _reverseTask() async {
    final original = actionTask;
    final createAdjustment = await showReverseWorkItemDialog(
      context,
      item: original,
      service: actionService,
      projectItems: taskProjectItems,
    );
    if (createAdjustment == null || !mounted) return;
    // Nạp lại trước để form điều chỉnh nhận bản đã huỷ hiệu lực (có lý do huỷ).
    loadTaskContext(force: true);
    actionOnRefresh();
    await reloadTaskDetail();
    if (!mounted) return;
    // `true` chỉ khi có chọn lập điều chỉnh và việc không gắn hồ sơ quy trình (hộp đã xét).
    if (createAdjustment && actionTask.id == original.id) openAdjustmentForm(actionTask);
  }

  /// Form "công việc điều chỉnh" cho việc đã huỷ hiệu lực, cùng cấp cha với việc gốc.
  void openAdjustmentForm([StandaloneTaskItem? item]) {
    final target = item ?? actionTask;
    final pid = target.parentId;
    final parent = pid == null ? null : taskProjectItems.where((i) => i.id == pid).firstOrNull;
    showWorkspaceCreateSubtaskSheet(
      context,
      parentTask: parent,
      adjustmentOf: target,
      service: actionService,
      onCreated: afterTaskChange,
      projectId: target.projectId,
      projectCode: taskProject?.code ?? target.projectCode,
      projectName: taskProject?.name ?? target.projectName,
      projectItems: _isProject ? taskProjectItems : null,
      access: taskAccess,
    );
  }

  // ------------------------------------------------------------- Menu "⋯"

  void openCreateChildTask() {
    if (!taskCanAddChild) return;
    _openCreate(actionTask);
  }

  void _openCreate(StandaloneTaskItem? parent) {
    showWorkspaceCreateSubtaskSheet(
      context,
      parentTask: parent,
      service: actionService,
      onCreated: afterTaskChange,
      projectId: actionTask.projectId,
      projectCode: taskProject?.code ?? actionTask.projectCode,
      projectName: taskProject?.name ?? actionTask.projectName,
      projectItems: _isProject ? taskProjectItems : null,
      access: taskAccess,
    );
  }

  void _addSibling() {
    final pid = actionTask.parentId;
    if (pid == null || pid.isEmpty) return _openCreate(null);
    final parent = taskProjectItems.where((i) => i.id == pid).firstOrNull;
    if (parent == null) {
      AppToast.error(context, 'workspace.task_detail.parent_not_found'.tr());
      return;
    }
    _openCreate(parent);
  }

  void openEditTask() {
    showWorkspaceEditTaskDialog(
      context,
      task: actionTask,
      service: actionService,
      onUpdated: afterTaskChange,
      access: taskAccess,
    );
  }

  Future<void> _moveToRoot() async {
    final ok = await actionService.moveWorkItem(actionTask.id, parentId: null);
    if (!mounted) return;
    if (ok) {
      AppToast.success(context, 'workspace.task_detail.move_to_root_success'.tr());
      afterTaskChange();
    } else {
      AppToast.error(context, actionService.lastError ?? 'workspace.task_detail.move_failed'.tr());
    }
  }

  Set<String> _branch() {
    final branch = {actionTask.id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final item in taskProjectItems) {
        final p = item.parentId;
        if (p != null && branch.contains(p) && branch.add(item.id)) grew = true;
      }
    }
    return branch;
  }

  /// Việc con còn mở (chưa xong, chưa huỷ) trong nhánh — hiện trong hộp huỷ như web.
  int _openDescendantCount() {
    if (!_isProject) return actionTask.openChildCount;
    final branch = _branch();
    return taskProjectItems
        .where((i) => i.id != actionTask.id && branch.contains(i.id) && i.status != 'done' && i.status != 'cancelled')
        .length;
  }

  int _descendantCount() => _isProject ? _branch().length - 1 : actionTask.childCount;

  Future<void> _confirmDelete() async {
    final descendants = _descendantCount();
    var busy = false;
    String? error;
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(
            'workspace.task_detail.delete.title'
                .tr(args: {'name': '${actionTask.code} · ${actionTask.title}'}),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                descendants > 0
                    ? 'workspace.task_detail.delete.message_branch'.tr(args: {'count': descendants})
                    : 'workspace.task_detail.delete.message'.tr(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx, false),
              child: Text('common.no'.tr()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              onPressed: busy
                  ? null
                  : () async {
                      setLocal(() {
                        busy = true;
                        error = null;
                      });
                      final ok = _isProject
                          ? await actionService.deleteWorkItem(actionTask.id)
                          : await actionService.deleteStandaloneTask(actionTask.id);
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.pop(ctx, true);
                      } else {
                        setLocal(() {
                          busy = false;
                          error = actionService.lastError ?? 'workspace.task_detail.delete.failed'.tr();
                        });
                      }
                    },
              child: Text('workspace.task_detail.delete.confirm'.tr()),
            ),
          ],
        ),
      ),
    );
    if (deleted == true && mounted) {
      AppToast.success(context, 'workspace.task_detail.delete.success'.tr());
      Navigator.pop(context);
      actionOnRefresh();
    }
  }

  void _onMenuAction(String id) {
    switch (id) {
      case 'add_child':
        openCreateChildTask();
      case 'add_sibling':
        _addSibling();
      case 'edit':
        openEditTask();
      case 'move':
        showWorkspaceMoveTaskDialog(
          context,
          task: actionTask,
          service: actionService,
          onMoved: afterTaskChange,
          projectItems: taskProjectItems.isEmpty ? null : taskProjectItems,
        );
      case 'move_to_root':
        _moveToRoot();
      case 'chat':
        openTaskChat();
      case 'refresh':
        afterTaskChange();
      case 'cancel':
        _cancelTask();
      case 'delete':
        _confirmDelete();
      case 'reverse':
        _reverseTask();
      case 'adjust':
        openAdjustmentForm();
    }
  }

  Widget buildTaskActionsMenu() {
    final t = actionTask;
    final hasParent = t.parentId != null && t.parentId!.isNotEmpty;
    // (id, icon, enabled, danger, separatorBefore, projectOnly)
    final all = <(String, IconData, bool, bool, bool, bool)>[
      ('add_child', Icons.subdirectory_arrow_right, taskCanAddChild, false, false, false),
      ('add_sibling', Icons.add_circle_outline, taskCanWrite, false, false, true),
      ('edit', Icons.edit_outlined, taskCanEdit, false, true, false),
      ('move', Icons.drive_file_move_outlined, taskCanManage, false, false, true),
      ('move_to_root', Icons.account_tree_outlined, taskCanManage && hasParent, false, false, true),
      ('chat', Icons.chat_bubble_outline, true, false, true, false),
      ('refresh', Icons.refresh, true, false, false, false),
      ('cancel', Icons.cancel_outlined, _canCancel, true, true, false),
      ('delete', Icons.delete_outline, taskCanDelete, true, false, false),
      // Chỉ thêm khi đủ điều kiện (web thêm hẳn dòng, không hiện mờ).
      if (taskCanReverse) ('reverse', Icons.undo, true, true, false, true),
      if (_isProject && taskCanCreateAdjustment) ('adjust', Icons.playlist_add, true, false, false, true),
    ];
    // Dự án lưu trữ: chỉ còn Mở trao đổi và Tải lại (web :845).
    final visible = all.where((a) {
      if (taskArchived) return a.$1 == 'chat' || a.$1 == 'refresh';
      return _isProject || !a.$6;
    }).toList();

    return PopupMenuButton<String>(
      tooltip: 'workspace.task_detail.menu.tooltip'.tr(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: _onMenuAction,
      itemBuilder: (ctx) => [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0 && visible[i].$5) const PopupMenuDivider(),
          _menuItem(visible[i].$1, visible[i].$2, visible[i].$3, visible[i].$4),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          color: Colors.white,
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF334155)),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String id, IconData icon, bool enabled, bool danger) {
    final color = !enabled
        ? const Color(0xFF94A3B8)
        : (danger ? const Color(0xFFDC2626) : const Color(0xFF0F172A));
    return PopupMenuItem(
      value: id,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 16, color: enabled ? (danger ? color : const Color(0xFF475569)) : color),
          const SizedBox(width: 10),
          Text(
            'workspace.task_detail.menu.$id'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: danger ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
