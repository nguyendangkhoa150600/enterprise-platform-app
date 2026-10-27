import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';
import '../features/workspace/presentation/controllers/workspace_controller.dart';
import '../features/workspace/presentation/widgets/tabs/workspace_customers_tab_view.dart';
import '../features/workspace/presentation/widgets/tabs/workspace_other_tasks_tab_view.dart';
import '../features/workspace/presentation/widgets/tabs/workspace_projects_tab_view.dart';
import '../models/workspace_models.dart';
import '../services/workspace_service.dart';
import 'workspace/components/workspace_create_dialogs.dart';
import 'workspace/components/workspace_documents_reports_view.dart';
import 'workspace/components/workspace_my_tasks_view.dart';
import 'workspace/components/workspace_sheets.dart';

/// Màn hình chính phân hệ Workspace
/// Refactor theo Senior Flutter Developer Standard: SRP, Clean Architecture, < 250 lines
class WorkspaceScreen extends StatefulWidget {
  final int initialTab; // 0: Việc của tôi, 1: Việc khác, 2: Dự án, 3: Khách hàng & HĐ, 4: Tài liệu, 5: Báo cáo

  const WorkspaceScreen({
    super.key,
    this.initialTab = 0,
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
    _controller.loadAllData();
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
    if (activeTab == 0 || activeTab == 1) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text('workspace.action.assign_task'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: _showCreateTaskDialog,
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
          projects: _controller.projects,
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
        return WorkspaceReportsView(
          projects: _controller.projects,
          tasks: _controller.tasks,
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
    showWorkspaceTaskStatusSheet(
      context,
      task: task,
      service: _service,
      onStatusChanged: _controller.reloadTab,
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
