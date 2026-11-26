import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';
import '../features/workspace/presentation/controllers/workspace_controller.dart';
import '../features/workspace/presentation/widgets/tabs/workspace_customers_tab_view.dart';
import '../features/workspace/presentation/widgets/tabs/workspace_other_tasks_tab_view.dart';
import '../features/workspace/presentation/widgets/tabs/workspace_projects_tab_view.dart';
import '../features/workspace/presentation/widgets/tabs/workspace_reports_tab_view.dart';
import '../models/workspace_models.dart';
import '../services/workspace_service.dart';
import '../features/workspace/data/datasources/workspace_task_detail_api.dart';
import '../features/workspace/data/datasources/workspace_calendar_api.dart';
import '../utils/app_toast.dart';
import 'workspace/components/workspace_create_dialogs.dart';
import 'workspace/components/workspace_documents_reports_view.dart';
import 'workspace/components/workspace_my_tasks_view.dart';
import 'workspace/components/workspace_sheets.dart';
import 'workspace/components/workspace_standalone_task_dialog.dart';
import 'workspace/components/workspace_standalone_task_detail_sheet.dart';

/// Màn hình chính phân hệ Workspace
/// Refactor theo Senior Flutter Developer Standard: SRP, Clean Architecture, < 250 lines
class WorkspaceScreen extends StatefulWidget {
  final int initialTab; // 0: Việc của tôi, 1: Việc khác, 2: Dự án, 3: Khách hàng & HĐ, 4: Tài liệu, 5: Báo cáo

  /// Từ thông báo nhắc tên: mở thẳng dự án này ở tab Trao đổi, cuộn tới tin [initialMessageId].
  final String? initialProjectId;
  final String? initialMessageId;

  /// Mở dự án [initialProjectId] ở tab Trao đổi (link nhắc tên/tin mới); false thì mở dự án như bình thường.
  final bool openProjectChat;

  /// Từ thông báo: mở thẳng chi tiết công việc trong dự án (web `#projects/work-item/<id>`, `#my-work/work-item/<id>`).
  final String? initialWorkItemId;

  /// Từ thông báo: mở thẳng chi tiết công việc ngoài dự án (web `#tasks/<id>`).
  final String? initialStandaloneTaskId;

  /// Từ thông báo lịch (web `#projects/calendar/<id>`, `#my-work/calendar/<id>`): mở dự án của sự kiện ở tab Lịch
  /// và mở sự kiện.
  final String? initialCalendarEventId;

  const WorkspaceScreen({
    super.key,
    this.initialTab = 0,
    this.initialProjectId,
    this.initialMessageId,
    this.openProjectChat = true,
    this.initialWorkItemId,
    this.initialStandaloneTaskId,
    this.initialCalendarEventId,
  });

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final WorkspaceService _service = WorkspaceService();
  late final WorkspaceController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WorkspaceController(initialTab: widget.initialTab);
    _controller.loadAllData().then((_) => _openInitialTarget());
  }

  Future<void> _openInitialTarget() async {
    final workItemId = widget.initialWorkItemId;
    final taskId = widget.initialStandaloneTaskId;
    if ((workItemId ?? '').isNotEmpty || (taskId ?? '').isNotEmpty) {
      final api = WorkspaceTaskDetailApi();
      final isWorkItem = (workItemId ?? '').isNotEmpty;
      final res = isWorkItem ? await api.getWorkItem(workItemId!) : await api.getStandaloneTask(taskId!);
      if (!mounted) return;
      if (!res.ok || res.data == null || res.data!.isEmpty) {
        AppToast.error(context, res.error ?? 'workspace.task_detail.load_failed'.tr());
        return;
      }
      var task = StandaloneTaskItem.fromJson(res.data!);
      if (isWorkItem && task.projectId == null && (widget.initialProjectId ?? '').isNotEmpty) {
        task = task.copyWith(projectId: widget.initialProjectId);
      }
      showWorkspaceStandaloneTaskDetailSheet(context, task: task, service: _service, onRefresh: _controller.loadAllData);
      return;
    }
    await _openInitialProject();
  }

  Future<void> _openInitialProject() async {
    var projectId = widget.initialProjectId;
    final eventId = widget.initialCalendarEventId;
    if ((eventId ?? '').isNotEmpty && (projectId ?? '').isEmpty) {
      // Link "Việc của tôi" không kèm dự án: hỏi sự kiện để biết dự án của nó.
      final res = await WorkspaceCalendarApi().getEvent(eventId!);
      if (!mounted) return;
      projectId = res.data?.occurrence?.projectId;
      if (projectId == null) {
        if (!res.ok) AppToast.error(context, res.error ?? 'workspace.calendar.error_load'.tr());
        return;
      }
    }
    if (projectId == null || projectId.isEmpty || !mounted) return;
    ProjectItem? target;
    for (final p in [..._controller.projects, ..._controller.myWorkProjects]) {
      if (p.id == projectId) {
        target = p;
        break;
      }
    }
    try {
      target ??= await _service.getProjectDetail(projectId);
    } catch (_) {}
    if (target == null || !mounted) return;
    showWorkspaceProjectDetailSheet(
      context,
      project: target,
      service: _service,
      onProjectsChanged: _controller.loadAllData,
      openChat: widget.openProjectChat && (eventId ?? '').isEmpty,
      initialMessageId: widget.initialMessageId,
      initialCalendarEventId: eventId,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getAppBarTitle(int activeTab) {
    switch (activeTab) {
      case 0:
        return 'workspace.title.my_tasks'.tr();
      case 1:
        return 'workspace.title.adhoc'.tr();
      case 2:
        return 'workspace.title.projects'.tr();
      case 3:
        return 'workspace.title.customers'.tr();
      case 4:
        return 'workspace.title.documents'.tr();
      case 5:
        return 'workspace.title.reports'.tr();
      default:
        return 'workspace.title.my_tasks'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final activeTab = _controller.activeTab;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              tooltip: 'common.back'.tr(),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getAppBarTitle(activeTab),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  'workspace.header.breadcrumb'.tr(),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'common.refresh'.tr(),
                onPressed: _controller.reloadTab,
              ),
            ],
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9AB00)))
              : RefreshIndicator(
                  onRefresh: _controller.reloadTab,
                  color: const Color(0xFFD9AB00),
                  child: _buildCurrentTabContent(activeTab),
                ),
          floatingActionButton: _buildFab(activeTab),
        );
      },
    );
  }

  Widget? _buildFab(int activeTab) {
    if (activeTab == 0) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          'workspace.action.assign_task'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: _showCreateTaskDialog,
      );
    } else if (activeTab == 1) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFFEAB308),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Giao việc',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: _showAssignStandaloneTaskModal,
      );
    } else if (activeTab == 2) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text('workspace.action.assign_task'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: _showCreateProjectDialog,
      );
    } else if (activeTab == 3) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text('workspace.action.add_customer'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: _showCreateCustomerDialog,
      );
    }
    return null;
  }

  Widget _buildCurrentTabContent(int activeTab) {
    switch (activeTab) {
      case 0:
        return WorkspaceMyTasksView(
          projects: _controller.myWorkProjects.isNotEmpty ? _controller.myWorkProjects : _controller.projects,
          tasks: _controller.tasks,
          onTaskTap: _showTaskStatusDialog,
          onProjectTap: _showProjectDetailSheet,
          onRefresh: _controller.reloadTab,
        );
      case 1:
        return WorkspaceOtherTasksTabView(
          controller: _controller,
          onTaskTap: _showTaskStatusDialog,
        );
      case 2:
        return WorkspaceProjectsTabView(
          controller: _controller,
          onProjectTap: _showProjectDetailSheet,
        );
      case 3:
        return WorkspaceCustomersTabView(
          controller: _controller,
          onCustomerTap: _showCustomerContractsSheet,
        );
      case 4:
        return WorkspaceDocumentsView(
          projects: _controller.projects,
          onRefresh: _controller.reloadTab,
        );
      case 5:
        return WorkspaceReportsTabView(
          projects: _controller.projects,
          service: _service,
          onRefresh: _controller.reloadTab,
        );
      default:
        return WorkspaceProjectsTabView(
          controller: _controller,
          onProjectTap: _showProjectDetailSheet,
        );
    }
  }

  // ==========================================
  // DETAIL BOTTOM SHEETS & DIALOGS
  // ==========================================
  void _showProjectDetailSheet(ProjectItem project) {
    showWorkspaceProjectDetailSheet(
      context,
      project: project,
      service: _service,
      onProjectsChanged: _controller.loadAllData,
    );
  }

  void _showCustomerContractsSheet(CustomerItem customer) {
    showWorkspaceCustomerContractsSheet(
      context,
      customer: customer,
      service: _service,
      projectMap: _controller.projectMap,
      onRefreshParent: _controller.loadAllData,
    );
  }

  void _showTaskStatusDialog(StandaloneTaskItem task) {
    showWorkspaceStandaloneTaskDetailSheet(
      context,
      task: task,
      service: _service,
      onRefresh: _controller.reloadTab,
    );
  }

  void _showCreateCustomerDialog() {
    showWorkspaceCreateCustomerDialog(
      context,
      service: _service,
      onCustomerCreated: _controller.reloadTab,
    );
  }

  void _showCreateTaskDialog() {
    showWorkspaceCreateModal(
      context,
      service: _service,
      projects: _controller.projects,
      customers: _controller.customers,
      onCreated: _controller.reloadTab,
      initialTab: 0,
    );
  }

  void _showAssignStandaloneTaskModal() {
    showWorkspaceAssignStandaloneTaskModal(
      context,
      service: _service,
      onCreated: () {
        _controller.setTaskScope('assigned_by_me');
      },
    );
  }

  void _showCreateProjectDialog() {
    showWorkspaceCreateModal(
      context,
      service: _service,
      projects: _controller.projects,
      customers: _controller.customers,
      onCreated: _controller.reloadTab,
      initialTab: 1,
    );
  }
}
