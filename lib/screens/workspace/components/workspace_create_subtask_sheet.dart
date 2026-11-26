import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/data/datasources/workspace_reverse_api.dart';
import '../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../models/procedure_models.dart';
import '../../../services/module_business_service.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import '../../../../services/platform_service.dart';
import '../../../../utils/user_resolver.dart';
import '../../../../utils/app_toast.dart';
import 'create_item/create_item_draft.dart';
import 'create_item/create_item_draft_editor.dart';
import 'workspace_create_item_helpers.dart';
import 'workspace_parent_task_picker_sheet.dart';

/// Modal "Công việc mới" tạo một hay nhiều công việc trong một lần gửi.
/// Đồng bộ 1:1 với Web React packages/features/workspace/src/lib/components/work-item-form.tsx (chế độ tạo)
/// và work-item-draft.tsx. [parentTask] null (hoặc id rỗng) ⇒ tạo ở cấp gốc của dự án; khi đó cần [projectId].
/// Không thuộc dự án (việc lẻ) thì giữ cách tạo một việc như cũ.
/// [initialDraft] điền sẵn việc đầu tiên (Trợ lý Savina); [onItemCreated] nhận bản ghi server trả về cho mỗi việc
/// tạo xong trong dự án.
Future<void> showWorkspaceCreateSubtaskSheet(
  BuildContext context, {
  StandaloneTaskItem? parentTask,
  required WorkspaceService service,
  required VoidCallback onCreated,
  String? projectId,
  String? projectCode,
  String? projectName,
  List<StandaloneTaskItem>? projectItems,
  ProjectAccess? access,
  /// Lập "công việc điều chỉnh" cho việc đã huỷ hiệu lực (web `adjustmentOf`, gửi `adjustmentOfId`).
  StandaloneTaskItem? adjustmentOf,
  CreateItemDraft? initialDraft,
  ValueChanged<Map<String, dynamic>>? onItemCreated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CreateSubtaskSheetContent(
      parentTask: parentTask,
      service: service,
      onCreated: onCreated,
      projectId: projectId,
      projectItems: projectItems,
      access: access,
      adjustmentOf: adjustmentOf,
      initialDraft: initialDraft,
      onItemCreated: onItemCreated,
    ),
  );
}

class _CreateSubtaskSheetContent extends StatefulWidget {
  final StandaloneTaskItem? parentTask;
  final WorkspaceService service;
  final VoidCallback onCreated;
  final String? projectId;
  final List<StandaloneTaskItem>? projectItems;
  final ProjectAccess? access;
  final StandaloneTaskItem? adjustmentOf;
  final CreateItemDraft? initialDraft;
  final ValueChanged<Map<String, dynamic>>? onItemCreated;

  const _CreateSubtaskSheetContent({
    required this.parentTask,
    required this.service,
    required this.onCreated,
    this.projectId,
    this.projectItems,
    this.access,
    this.adjustmentOf,
    this.initialDraft,
    this.onItemCreated,
  });

  @override
  State<_CreateSubtaskSheetContent> createState() => _CreateSubtaskSheetContentState();
}

class _CreateSubtaskSheetContentState extends State<_CreateSubtaskSheetContent> {
  final WorkspaceReverseApi _reverseApi = WorkspaceReverseApi();

  /// Các việc sẽ tạo, mỗi việc đủ trường riêng (web `rows`).
  final List<CreateItemDraft> _rows = [];

  /// Các việc đang thu gọn (chỉ dùng khi có từ hai việc trở lên).
  final Set<int> _collapsed = {};

  List<Map<String, dynamic>> _availableTags = [];
  List<String> _recentTitles = [];
  bool _isSubmitting = false;

  List<StandaloneTaskItem> _projectTasks = [];
  bool _isLoadingTasks = false;

  List<ProjectMemberItem> _members = [];
  List<WorkspaceDirectoryPerson> _directoryPeople = [];
  /// Thành viên thật của dự án (từ GET members) — để biết ai là người ngoài dự án.
  Set<String> _memberIds = {};
  List<ParentCandidate> _parentCandidates = [];
  List<ProcedureDefinition>? _procedures;
  bool _loadingProcedures = false;
  String? _error;

  String? get _projectId {
    final explicit = widget.projectId;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return widget.parentTask?.projectId;
  }

  bool get _inProject => (_projectId ?? '').isNotEmpty;

  bool get _readOnly => widget.access != null && !widget.access!.canWrite;

  /// Công việc điều chỉnh chỉ có nghĩa với công việc dự án (web `WorkItemForm.adjustmentOf`).
  StandaloneTaskItem? get _adjustmentOf => _inProject ? widget.adjustmentOf : null;

  /// Nhãn "CODE · tên" của công việc cha (không kèm hậu tố trạng thái).
  String _parentPlain(CreateItemDraft d) {
    if (d.parentId.isEmpty) return '';
    for (final t in _projectTasks) {
      if (t.id == d.parentId) return '${t.code} · ${t.title}';
    }
    final p = widget.parentTask;
    if (p != null && p.id == d.parentId && p.code.isNotEmpty) return '${p.code} · ${p.title}';
    return d.parentTitle;
  }

  /// Cha đang chọn đã hoàn thành (web: `parentOptions[].done`).
  bool _parentDone(CreateItemDraft d) {
    if (d.parentId.isEmpty) return false;
    for (final c in _parentCandidates) {
      if (c.id == d.parentId) return c.done;
    }
    for (final t in _projectTasks) {
      if (t.id == d.parentId) return t.status == 'done';
    }
    final p = widget.parentTask;
    return p != null && p.id == d.parentId && p.status == 'done';
  }

  @override
  void initState() {
    super.initState();
    final parent = widget.parentTask;
    final parentId = (parent == null || parent.id.isEmpty) ? '' : parent.id;
    final parentTitle = parentId.isEmpty
        ? ''
        : (parent!.code.isNotEmpty ? '${parent.code} · ${parent.title}' : parent.title);
    final adjustment = _adjustmentOf;
    final initial = widget.initialDraft;
    _rows.add(initial ??
        (adjustment != null
            ? CreateItemDraft.adjustmentOf(adjustment, parentId: parentId, parentTitle: parentTitle)
            : CreateItemDraft(parentId: parentId, parentTitle: parentTitle)));
    _loadMembers();
    _loadProjectTasks();
    _loadTags();
    _loadRecentTitles();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRecentTitles() async {
    try {
      final list = await widget.service.getRecentWorkItemTitles();
      if (mounted && list.isNotEmpty) {
        setState(() => _recentTitles = list);
      }
    } catch (_) {}
  }

  Future<void> _loadTags() async {
    try {
      final tags = await widget.service.getTags();
      if (mounted && tags.isNotEmpty) {
        setState(() => _availableTags = tags);
      }
    } catch (_) {}
  }

  Future<void> _loadMembers() async {
    final pId = _projectId;
    final peopleMap = <String, WorkspaceDirectoryPerson>{};

    try {
      final dir = await widget.service.getDirectory();
      if (dir != null) {
        for (final p in dir.people) {
          if (p.userId.isNotEmpty) peopleMap[p.userId] = p;
        }
      }
    } catch (_) {}

    try {
      final uList = await PlatformService().getTenantUsers();
      for (final u in uList) {
        if (u.id.isNotEmpty && !peopleMap.containsKey(u.id)) {
          final name = u.fullName.isNotEmpty ? u.fullName : (u.username ?? u.email);
          final pos = u.systemRole == 'tenant-admin' ? 'Quản trị viên' : 'Nhân viên';
          peopleMap[u.id] = WorkspaceDirectoryPerson(
            userId: u.id,
            displayName: name,
            email: u.email,
            positionName: pos,
          );
        }
      }
    } catch (_) {}

    if (mounted && peopleMap.isNotEmpty) {
      setState(() => _directoryPeople = peopleMap.values.toList());
    }

    if (pId != null && pId.isNotEmpty) {
      try {
        final list = await widget.service.getProjectMembers(pId);
        if (mounted && list.isNotEmpty) {
          setState(() {
            _members = list;
            _memberIds = list.map((m) => m.userId).toSet();
          });
          return;
        }
      } catch (_) {}
    }

    // Fallback nếu chưa có thành viên từ project
    final fallbackList = <ProjectMemberItem>[];
    final parentTask = widget.parentTask;
    if (parentTask != null && parentTask.assigneeUserId.isNotEmpty) {
      fallbackList.add(ProjectMemberItem(
        userId: parentTask.assigneeUserId,
        fullName: parentTask.assigneeName,
        role: 'assignee',
      ));
    }
    if (UserResolver.allRawNames.isNotEmpty) {
      for (final entry in UserResolver.allRawNames.entries) {
        if (entry.key.isNotEmpty && entry.value != 'Người dùng' && entry.value != '—') {
          if (!fallbackList.any((m) => m.userId == entry.key)) {
            fallbackList.add(ProjectMemberItem(
              userId: entry.key,
              fullName: entry.value,
              role: 'member',
            ));
          }
        }
      }
    }
    if (mounted) setState(() => _members = fallbackList);
  }

  Future<void> _loadProjectTasks() async {
    final provided = widget.projectItems;
    if (provided != null) {
      _projectTasks = provided;
      _parentCandidates = buildParentCandidates(provided);
      return;
    }
    final pId = _projectId;
    if (pId != null && pId.isNotEmpty) {
      setState(() => _isLoadingTasks = true);
      try {
        final list = await widget.service.getProjectWorkItems(pId);
        if (mounted) {
          setState(() {
            _projectTasks = list;
            _parentCandidates = buildParentCandidates(list);
            _isLoadingTasks = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingTasks = false);
      }
    }
  }

  void _openParentTaskPicker(CreateItemDraft d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ParentTaskPickerSheet(
        initialSelectedId: d.parentId,
        options: _parentCandidates,
        isLoading: _isLoadingTasks,
        onSelected: (id, label) {
          setState(() {
            d.parentId = id;
            d.parentTitle = label;
            d.reopenParent = false;
          });
        },
      ),
    );
  }

  /// Chỉ hỏi module Quy trình khi người dùng chọn "Theo quy trình", một lần mỗi lần mở form (như web).
  Future<void> _ensureProcedures() async {
    if (_procedures != null || _loadingProcedures) return;
    _loadingProcedures = true;
    List<ProcedureDefinition> published = const [];
    try {
      final ws = await ModuleBusinessService().getProcedureWorkspace();
      published = ws.definitions.where((d) => d.status == 'published').toList();
    } catch (_) {}
    _loadingProcedures = false;
    if (mounted) setState(() => _procedures = published);
  }

  String _personName(String userId) {
    for (final p in _directoryPeople) {
      if (p.userId == userId) return p.displayName;
    }
    return UserResolver.resolveName(userId);
  }

  // ---- Thao tác trên danh sách việc (web addRow / duplicateRow / pasteLines) ----

  void _addRow() => setState(() => _rows.add(_rows.isEmpty ? CreateItemDraft() : _rows.last.next()));

  void _duplicateRow(CreateItemDraft d) {
    final i = _rows.indexOf(d);
    if (i < 0) return;
    setState(() => _rows.insert(i + 1, d.copy()));
  }

  void _removeRow(CreateItemDraft d) {
    setState(() {
      _rows.remove(d);
      _collapsed.remove(d.key);
    });
    d.dispose();
  }

  /// Dán nhiều dòng vào ô tên: dòng đầu điền vào ô đó, các dòng sau thành việc mới chép mọi trường khác.
  void _pasteLines(CreateItemDraft d, List<String> lines) {
    final i = _rows.indexOf(d);
    if (i < 0 || lines.isEmpty || !mounted) return;
    setState(() {
      d.titleCtrl.text = lines.first;
      d.titleCtrl.selection = TextSelection.collapsed(offset: lines.first.length);
      _rows.insertAll(i + 1, lines.skip(1).map((t) => d.copy(title: t)));
    });
  }

  void _toggleCollapsed(int key) => setState(() => _collapsed.contains(key) ? _collapsed.remove(key) : _collapsed.add(key));

  void _fail(String message, {int? rowKey}) {
    setState(() {
      // Báo lỗi của một việc: mở rộng việc đó ra để người dùng thấy ngay chỗ cần sửa.
      if (rowKey != null) _collapsed.remove(rowKey);
      _error = message;
      _isSubmitting = false;
    });
  }

  /// Người phụ trách / cùng làm đã chọn nhưng chưa thuộc dự án (web `outsidePeople`), trên mọi việc có tên.
  List<WorkspaceDirectoryPerson> _outsidePeople() {
    final ids = <String>{};
    for (final row in _rows) {
      if (!row.filled || row.isPhase) continue;
      if (row.assigneeUserId.isNotEmpty) ids.add(row.assigneeUserId);
      ids.addAll(row.participantUserIds);
    }
    ids.removeWhere(_memberIds.contains);
    return ids.map((id) {
      for (final p in _directoryPeople) {
        if (p.userId == id) return p;
      }
      return WorkspaceDirectoryPerson(userId: id, displayName: _personName(id));
    }).toList();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_readOnly) return;
    final pId = _projectId;
    final inProject = _inProject;
    // Việc lẻ chỉ tạo một việc; dự án tạo mọi việc đã có tên.
    final filled = (inProject ? _rows : _rows.take(1)).where((r) => r.filled).toList();
    if (filled.isEmpty) {
      _fail('workspace.create_item.err_title_required'.tr());
      return;
    }
    for (final row in filled) {
      final problem = row.problem(inProject: inProject, parentDone: _parentDone(row));
      if (problem != null) {
        final prefix = filled.length > 1
            ? 'workspace.create_item.row_prefix'.tr(args: {'index': '${_rows.indexOf(row) + 1}'})
            : '';
        _fail('$prefix$problem', rowKey: row.key);
        return;
      }
    }

    if (!inProject) {
      setState(() => _isSubmitting = true);
      try {
        final error = await filled.first
            .createStandalone(service: widget.service, fallbackAssignee: widget.parentTask?.assigneeUserId);
        if (!mounted) return;
        if (error != null) {
          _fail(error);
          return;
        }
        _finish();
      } catch (_) {
        if (mounted) _fail('workspace.create_item.err_create_failed'.tr());
      }
      return;
    }

    // Người ngoài dự án: hỏi xác nhận, rồi GET + gộp + PUT danh sách thành viên một lần trước khi tạo.
    final outside = _outsidePeople();
    if (outside.isNotEmpty) {
      final ok = await confirmAddOutsideMembers(context, outside);
      if (!ok || !mounted) return;
      setState(() => _isSubmitting = true);
      final ids = outside.map((p) => p.userId).toList();
      try {
        final existing = await widget.service.getProjectMembers(pId!);
        final res = await widget.service.setProjectMembersWithResult(pId, mergeOutsideProjectMembers(existing, ids));
        if (!mounted) return;
        if (!res.success) {
          _fail(res.errorMessage ?? 'workspace.create_item.err_add_members'.tr());
          return;
        }
        _memberIds = {..._memberIds, ...existing.map((m) => m.userId), ...ids};
      } catch (_) {
        if (mounted) _fail('workspace.create_item.err_add_members'.tr());
        return;
      }
    }

    setState(() => _isSubmitting = true);
    await _runCreate(pId!, filled);
  }

  /// Tạo lần lượt từng việc có tên. Việc nào tạo xong thì rút khỏi danh sách ngay: hỏng giữa chừng thì người
  /// dùng sửa rồi bấm lại, không tạo trùng các việc đã xong (web `runCreate`).
  Future<void> _runCreate(String projectId, List<CreateItemDraft> pending) async {
    var created = 0;
    for (final row in pending) {
      String? error;
      try {
        error = await row.createInProject(
          service: widget.service,
          projectId: projectId,
          parentDone: _parentDone(row),
          adjustmentOfId: _adjustmentOf?.id,
          reverseApi: _reverseApi,
        );
      } catch (_) {
        error = 'workspace.create_item.err_create_failed'.tr();
      }
      if (!mounted) return;
      if (error != null) {
        if (created > 0) widget.onCreated();
        _fail(created > 0
            ? 'workspace.create_item.partial_created'
                .tr(args: {'created': '$created', 'total': '${pending.length}', 'message': error})
            : error);
        return;
      }
      created += 1;
      final record = _adjustmentOf == null ? widget.service.lastCreated : null;
      if (record != null) widget.onItemCreated?.call(record);
      setState(() {
        _rows.remove(row);
        _collapsed.remove(row.key);
        if (_rows.isEmpty) _rows.add(CreateItemDraft());
      });
      row.dispose();
    }
    _finish();
  }

  void _finish() {
    setState(() => _isSubmitting = false);
    Navigator.pop(context);
    AppToast.success(context, 'Tạo công việc thành công!');
    widget.onCreated();
  }

  CreateItemDraftContext _draftContext() => CreateItemDraftContext(
        history: _recentTitles,
        members: _members,
        directoryPeople: _directoryPeople,
        memberIds: _memberIds,
        availableTags: _availableTags,
        onTagCreated: (tag) => setState(() => _availableTags.add(tag)),
        createTag: widget.service.createTag,
        procedures: _procedures,
        ensureProcedures: _ensureProcedures,
        nameOf: _personName,
        inProject: _inProject,
      );

  Widget _toolbar() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text('workspace.create_item.row_count'.tr(args: {'count': '${_rows.length}'}),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ),
            TextButton(
              onPressed: _rows.every((r) => _collapsed.contains(r.key))
                  ? null
                  : () => setState(() => _collapsed.addAll(_rows.map((r) => r.key))),
              child: Text('workspace.create_item.collapse_all'.tr(), style: const TextStyle(fontSize: 12.5)),
            ),
            TextButton(
              onPressed: _rows.every((r) => !_collapsed.contains(r.key)) ? null : () => setState(_collapsed.clear),
              child: Text('workspace.create_item.expand_all'.tr(), style: const TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
      );

  Widget _addRowFooter() => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _readOnly ? null : _addRow,
              icon: const Icon(Icons.add, size: 15),
              label: Text('workspace.create_item.add_row'.tr(), style: const TextStyle(fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 6),
            Text('workspace.create_item.add_row_hint'.tr(),
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          ],
        ),
      );

  String _subtitle() {
    final adjustment = _adjustmentOf;
    if (adjustment != null) {
      return 'workspace.adjustment.subtitle'
          .tr(args: {'code': adjustment.code, 'reason': adjustment.reversalReason ?? ''});
    }
    final parentId = _rows.isNotEmpty ? _rows.first.parentId : '';
    return parentId.isNotEmpty
        ? 'workspace.create_item.subtitle_under'.tr(args: {'parent': _parentPlain(_rows.first)})
        : 'workspace.create_item.subtitle_root'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final multi = _inProject && _rows.length > 1;
    final filledCount = _rows.where((r) => r.filled).length;
    final draftCtx = _draftContext();

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header matching Web 1:1
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adjustmentOf != null ? 'workspace.adjustment.title'.tr() : 'workspace.create_item.title'.tr(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 3),
                      Text(_subtitle(), style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (_readOnly) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'workspace.create_item.read_only'.tr(),
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (multi) _toolbar(),
                for (var i = 0; i < _rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  CreateItemDraftEditor(
                    key: ValueKey(_rows[i].key),
                    draft: _rows[i],
                    index: i,
                    multi: multi,
                    collapsed: _collapsed.contains(_rows[i].key),
                    parentDone: _parentDone(_rows[i]),
                    parentLabel: _rows[i].parentTitle.isNotEmpty ? _rows[i].parentTitle : _parentPlain(_rows[i]),
                    ctx: draftCtx,
                    onChanged: () => setState(() {}),
                    onToggleCollapsed: () => _toggleCollapsed(_rows[i].key),
                    onDuplicate: _inProject ? () => _duplicateRow(_rows[i]) : null,
                    onRemove: () => _removeRow(_rows[i]),
                    onPasteLines: _inProject ? (lines) => _pasteLines(_rows[i], lines) : null,
                    onPickParent: () => _openParentTaskPicker(_rows[i]),
                  ),
                ],
                if (_inProject) _addRowFooter(),
              ],
            ),
          ),

          if (_error != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
            ),
          // Footer matching Web 1:1
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text('workspace.action.cancel'.tr(), style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_isSubmitting || _readOnly) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAB308),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                        )
                      : Text(
                          _inProject && filledCount > 1
                              ? 'workspace.create_item.submit_many'.tr(args: {'count': '$filledCount'})
                              : 'workspace.create_item.submit'.tr(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
