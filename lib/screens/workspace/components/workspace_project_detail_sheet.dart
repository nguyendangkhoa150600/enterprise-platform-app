import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/data/datasources/workspace_project_api.dart';
import '../../../features/workspace/data/datasources/workspace_remote_datasource.dart';
import '../../../features/workspace/domain/models/workspace_report_models.dart' show TagItem;
import '../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../models/workspace_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/app_toast.dart';
import 'project_detail/project_header.dart';
import 'project_detail/project_menu.dart';
import 'project_detail/project_work_model.dart';
import 'project_detail/project_work_tab.dart';
import 'project_tabs/workspace_project_calendar_tab.dart';
import 'project_tabs/workspace_project_finance_tab.dart';
import 'project_tabs/workspace_project_requests_tab.dart';
import 'task_detail/workspace_activity_list.dart';
import 'workspace_create_subtask_sheet.dart';
import 'workspace_documents_reports_view.dart';
import 'workspace_landscape_fullscreen_screen.dart';
import 'workspace_project_members_sheet.dart';
import 'workspace_standalone_task_detail_sheet.dart';
import 'workspace_tab_chats.dart';

/// Trang chi tiết dự án (web projects-view.tsx): điều phối tải dữ liệu, tab, menu "⋯" và các lệnh cấp dự án.
/// Phần hiển thị nằm trong `project_detail/` (header, tab Công việc, cây WBS, bộ lọc, menu).
class ProjectDetailSheet extends StatefulWidget {
  final ProjectItem project;
  final WorkspaceService service;

  /// Đã đổi trạng thái, mở lưu trữ hay huỷ dự án: trang cha nạp lại danh sách (web `onProjectsChanged`).
  final VoidCallback? onProjectsChanged;

  const ProjectDetailSheet({
    super.key,
    required this.project,
    required this.service,
    this.onProjectsChanged,
  });

  @override
  State<ProjectDetailSheet> createState() => _ProjectDetailSheetState();
}

/// Các tab theo web (projects-view.tsx TABS); "Trao đổi công việc" là nút riêng ở cuối hàng.
const List<String> _kTabs = ['work', 'calendar', 'documents', 'finance', 'requests', 'activity'];
const String _kChatsTab = 'chats';

class _ProjectDetailSheetState extends State<ProjectDetailSheet> {
  final _projectApi = WorkspaceProjectApi();
  late ProjectItem _project;
  bool _isLoadingTasks = true;
  List<StandaloneTaskItem> _tasks = [];
  List<ProjectMemberItem> _members = [];
  bool _loadFailed = false;
  int? _documentCount;
  ProjectProgressInfo? _progress;
  Map<String, TagItem> _tags = const {};

  String _tab = 'work';
  String _view = 'table';
  WorkFilter _filter = WorkFilter.none;

  String? get _currentUserId => AuthProvider.instance?.userId;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _tasks = List.from(widget.project.tasks);
    _loadAllData();
    _loadTags();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadProjectDetail(),
      _loadWorkItems(),
      _loadMembers(),
      _loadDocumentCount(),
      _loadProgressInfo(),
    ]);
  }

  // getProjectWorkItems nuốt lỗi và trả [], nên lỗi tải dự án được nhận biết qua getProjectDetail trả null.
  Future<void> _loadProjectDetail() async {
    ProjectItem? updated;
    try {
      updated = await widget.service.getProjectDetail(_project.id);
    } catch (e) {
      debugPrint('[ProjectDetailSheet] loadProjectDetail error: $e');
    }
    if (!mounted) return;
    setState(() {
      _loadFailed = updated == null;
      if (updated != null) _project = updated;
      // Tab Tài chính chỉ có khi server gửi `finance`; đang đứng ở đó thì lùi về Công việc.
      if (_tab == 'finance' && _project.finance == null) _tab = 'work';
    });
  }

  Future<void> _loadProgressInfo() async {
    final res = await _projectApi.getProgressInfo(_project.id);
    if (!mounted || !res.ok) return;
    setState(() => _progress = res.data);
  }

  // Số tài liệu của dự án như web (project-header: documentCount = tài liệu lọc theo projectId).
  Future<void> _loadDocumentCount() async {
    try {
      final raw = await WorkspaceRemoteDataSource().getDocumentsRaw(projectId: _project.id);
      final data = raw is Map<String, dynamic> ? (raw['data'] ?? raw) : raw;
      final list = data is Map<String, dynamic> ? data['items'] : data;
      if (list is List && mounted) setState(() => _documentCount = list.length);
    } catch (e) {
      debugPrint('[ProjectDetailSheet] loadDocumentCount error: $e');
    }
  }

  Future<void> _loadWorkItems() async {
    setState(() => _isLoadingTasks = true);
    try {
      final items = await widget.service.getProjectWorkItems(_project.id);
      if (!mounted) return;
      setState(() {
        _tasks = items;
        _isLoadingTasks = false;
      });
    } catch (e) {
      debugPrint('[ProjectDetailSheet] loadWorkItems error: $e');
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  Future<void> _loadMembers() async {
    try {
      final list = await widget.service.getProjectMembers(_project.id);
      // Chỉ dùng thành viên thật của dự án (GET /projects/{id}/members), không ghép người được giao việc.
      if (!mounted) return;
      setState(() => _members = list.where((m) => m.userId.isNotEmpty).toList());
    } catch (e) {
      debugPrint('[ProjectDetailSheet] loadMembers error: $e');
    }
  }

  Future<void> _loadTags() async {
    try {
      final tags = await widget.service.getWorkspaceTags();
      if (!mounted) return;
      setState(() => _tags = {for (final t in tags) t.id: t});
    } catch (e) {
      debugPrint('[ProjectDetailSheet] loadTags error: $e');
    }
  }

  /* ------------------------------------------------------------ Điều hướng */

  void _openItem(StandaloneTaskItem item) {
    showWorkspaceStandaloneTaskDetailSheet(
      context,
      task: item.copyWith(projectId: _project.id, projectCode: _project.code, projectName: _project.name),
      service: widget.service,
      onRefresh: _loadWorkItems,
    );
  }

  void _openItemById(String itemId) {
    for (final t in _tasks) {
      if (t.id == itemId) return _openItem(t);
    }
  }

  void _addRootItem() {
    showWorkspaceCreateSubtaskSheet(
      context,
      parentTask: null,
      projectId: _project.id,
      projectCode: _project.code,
      projectName: _project.name,
      projectItems: _tasks,
      access: _project.access,
      service: widget.service,
      onCreated: _loadWorkItems,
    );
  }

  void _openLandscape() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => WorkspaceLandscapeFullscreenScreen(
        project: _project,
        tasks: _tasks,
        initialViewMode: _view,
        service: widget.service,
        onRefresh: _loadWorkItems,
        initialFilter: _filter,
        tags: _tags,
        currentUserId: _currentUserId,
      ),
    ));
  }

  void _openMembers() {
    showWorkspaceProjectMembersSheet(
      context,
      project: _project,
      service: widget.service,
      initialMembers: _members,
      onMembersUpdated: _loadMembers,
      access: _project.access,
    );
  }

  /* ------------------------------------------------------ Lệnh cấp dự án */

  Future<void> _changeStatus(String status) async {
    final res = await _projectApi.updateStatus(_project.id, status);
    if (!mounted) return;
    if (!res.ok) {
      AppToast.error(context, res.error ?? 'workspace.work_tab.status_change_failed'.tr());
      return;
    }
    AppToast.success(
      context,
      'workspace.work_tab.status_changed'.tr(args: {'name': _project.name, 'status': projectStatusLabel(status)}),
    );
    widget.onProjectsChanged?.call();
    await _loadAllData();
  }

  Future<void> _unarchive() async {
    final ok = await showProjectConfirmDialog(
      context,
      title: 'workspace.work_tab.unarchive_title'.tr(),
      message: 'workspace.work_tab.unarchive_message'.tr(),
      confirmLabel: 'workspace.work_tab.unarchive'.tr(),
      danger: false,
      onConfirm: () async {
        final res = await _projectApi.unarchive(_project.id);
        return res.ok ? null : (res.error ?? 'workspace.work_tab.unarchive_failed'.tr());
      },
    );
    if (!ok || !mounted) return;
    widget.onProjectsChanged?.call();
    await _loadAllData();
  }

  Future<void> _cancelProject() async {
    final ok = await showProjectConfirmDialog(
      context,
      title: 'workspace.project_menu.cancel_title'.tr(args: {'code': _project.code, 'name': _project.name}),
      message: 'workspace.project_menu.cancel_message'.tr(),
      confirmLabel: 'workspace.project_menu.cancel_project'.tr(),
      danger: true,
      onConfirm: () async {
        final done = await widget.service.deleteProject(_project.id);
        return done ? null : (widget.service.lastError ?? 'workspace.project_menu.cancel_failed'.tr());
      },
    );
    if (!ok || !mounted) return;
    widget.onProjectsChanged?.call();
    Navigator.pop(context);
  }

  Future<void> _openMenu() async {
    final action = await showProjectMenu(context, project: _project);
    if (!mounted || action == null) return;
    switch (action) {
      case ProjectMenuAction.addRootItem:
        _addRootItem();
      case ProjectMenuAction.editProject:
        break; // Mobile chưa có form sửa dự án: mục luôn tắt (xem showProjectMenu).
      case ProjectMenuAction.openChat:
        setState(() => _tab = _kChatsTab);
      case ProjectMenuAction.refresh:
        await _loadAllData();
      case ProjectMenuAction.cancelProject:
        await _cancelProject();
    }
  }

  /* ------------------------------------------------------------------ Dựng */

  @override
  Widget build(BuildContext context) {
    final access = _project.access;
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _topBar(),
            ProjectHeader(
              project: _project,
              members: _members,
              documentCount: _documentCount ?? 0,
              progress: _progress,
              onOpenMembers: _openMembers,
              onChangeStatus: access.canChangeProjectStatus ? _changeStatus : null,
            ),
            if (_project.isArchived)
              ProjectArchivedBanner(canUnarchive: access.canUnarchive, onUnarchive: _unarchive),
            _tabsBar(),
            Expanded(child: _tabContent()),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    // Phải giãn hết bề ngang: không thì Stack chỉ rộng bằng thanh kéo 40px và nút bị dồn vào giữa.
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 20, color: Color(0xFF64748B)),
                  tooltip: 'workspace.project_menu.title'.tr(),
                  onPressed: _openMenu,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  tooltip: 'common.close'.tr(),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int? _tabCount(String id) {
    if (id == 'work') return _tasks.length;
    if (id == 'documents') return _documentCount;
    return null;
  }

  Widget _tabsBar() {
    final tabs = _kTabs.where((id) => id != 'finance' || _project.finance != null);
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            for (final id in tabs) _tabChip(id),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _tab = _kChatsTab),
              icon: const Icon(Icons.chat_bubble_outline, size: 14),
              label: Text('workspace.work_tab.tab_chats'.tr(), style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: _tab == _kChatsTab ? const Color(0xFFFACC15) : null,
                foregroundColor: const Color(0xFF0F172A),
                side: BorderSide(color: _tab == _kChatsTab ? const Color(0xFFEAB308) : const Color(0xFFCBD5E1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(String id) {
    final selected = _tab == id;
    final count = _tabCount(id);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _tab = id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFACC15) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? const Color(0xFFEAB308) : Colors.transparent),
          ),
          child: Text(
            count != null && count > 0
                ? '${'workspace.work_tab.tab_$id'.tr()} ($count)'
                : 'workspace.work_tab.tab_$id'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? const Color(0xFF0F172A) : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabContent() {
    final access = _project.access;
    switch (_tab) {
      case 'calendar':
        return WorkspaceProjectCalendarTab(
          project: _project,
          service: widget.service,
          access: access,
          projectItems: _tasks,
          onOpenItem: _openItemById,
        );
      case 'documents':
        return WorkspaceDocumentsView(
          projects: [_project],
          initialProjectId: _project.id,
          scopeProjectId: _project.id,
          access: access,
          onRefresh: _loadWorkItems,
          onCount: (count) {
            if (mounted && count != _documentCount) setState(() => _documentCount = count);
          },
        );
      case 'finance':
        return WorkspaceProjectFinanceTab(project: _project, service: widget.service, access: access);
      case 'requests':
        return WorkspaceProjectRequestsTab(project: _project, service: widget.service, access: access);
      case 'activity':
        return WorkspaceActivityList(
          projectId: _project.id,
          service: widget.service,
          projectItems: _tasks,
          itemIds: null,
          onOpenItem: _openItemById,
          embedded: false,
          projectCreatedBy: _project.createdBy,
          projectCreatedAt: _progress?.createdAt,
        );
      case _kChatsTab:
        return WorkspaceTabChatsView(
          projectId: _project.id,
          service: widget.service,
          items: _tasks,
          members: _members,
          canWrite: !_project.isArchived,
          onOpenTaskDetail: _openItem,
        );
      default:
        return ProjectWorkTab(
          project: _project,
          items: _tasks,
          tags: _tags,
          service: widget.service,
          view: _view,
          filter: _filter,
          currentUserId: _currentUserId,
          loading: _isLoadingTasks,
          loadFailed: _loadFailed,
          onViewChanged: (v) => setState(() => _view = v),
          onFilterChanged: (f) => setState(() => _filter = f),
          onOpenItem: _openItem,
          onAddRoot: _addRootItem,
          onOpenLandscape: _openLandscape,
          onRefresh: _loadWorkItems,
          onRetry: _loadAllData,
        );
    }
  }
}
