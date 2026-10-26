import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';
import '../models/workspace_models.dart';
import '../services/workspace_service.dart';
import 'workspace/components/workspace_sheets.dart';
import 'workspace/components/workspace_create_dialogs.dart';

class WorkspaceScreen extends StatefulWidget {
  final int initialTab; // 0: Dự án, 1: Khách hàng & Hợp đồng, 2: Việc ngoài dự án

  const WorkspaceScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final WorkspaceService _service = WorkspaceService();

  late int _activeTab;
  bool _isLoading = true;

  // Data states
  List<ProjectItem> _projects = [];
  List<CustomerItem> _customers = [];
  List<StandaloneTaskItem> _tasks = [];
  final Map<String, String> _customerMap = {}; // id -> name
  final Map<String, String> _projectMap = {}; // id -> name

  // Project filters
  String _projectSearch = '';
  final String _projectTypeFilter = 'ALL';
  String _projectStatusFilter = 'ALL';

  // Customer filters
  String _customerSearch = '';

  // Task filters
  String _taskScope = 'assigned_to_me'; // 'assigned_to_me' | 'assigned_by_me' | 'following'
  String _taskStatusFilter = 'ALL';
  String _taskSearch = '';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _loadAllData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Customers
      final customers = await _service.getCustomers();
      _customerMap.clear();
      for (final c in customers) {
        _customerMap[c.id] = c.name;
      }

      // 2. Projects
      final projects = await _service.getProjects(customerMap: _customerMap);
      _projectMap.clear();
      for (final p in projects) {
        _projectMap[p.id] = p.name;
      }

      // 3. Standalone Tasks
      final tasks = await _service.getStandaloneTasks(scope: _taskScope);

      if (mounted) {
        setState(() {
          _customers = customers;
          _projects = projects;
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[WorkspaceScreen] load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reloadTab() async {
    setState(() => _isLoading = true);
    if (_activeTab == 0) {
      final projects = await _service.getProjects(customerMap: _customerMap);
      if (mounted) setState(() { _projects = projects; _isLoading = false; });
    } else if (_activeTab == 1) {
      final customers = await _service.getCustomers(query: _customerSearch);
      if (mounted) setState(() { _customers = customers; _isLoading = false; });
    } else {
      final tasks = await _service.getStandaloneTasks(scope: _taskScope);
      if (mounted) setState(() { _tasks = tasks; _isLoading = false; });
    }
  }


  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
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
              _activeTab == 0 ? 'workspace.title.projects'.tr() : (_activeTab == 1 ? 'workspace.title.customers'.tr() : 'workspace.title.adhoc'.tr()),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              'workspace.header.breadcrumb'.tr(),
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'common.refresh'.tr(),
            onPressed: _reloadTab,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Navigation Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: _buildNavTab(
                      index: 0,
                      label: 'workspace.tab.projects'.tr(),
                      icon: Icons.folder_open_rounded,
                      badge: _projects.isNotEmpty ? '${_projects.length}' : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildNavTab(
                      index: 1,
                      label: 'workspace.tab.customers'.tr(),
                      icon: Icons.business_outlined,
                      badge: _customers.isNotEmpty ? '${_customers.length}' : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildNavTab(
                      index: 2,
                      label: 'workspace.tab.adhoc'.tr(),
                      icon: Icons.assignment_outlined,
                      badge: _tasks.isNotEmpty ? '${_tasks.length}' : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9AB00)))
                : RefreshIndicator(
                    onRefresh: _reloadTab,
                    color: const Color(0xFFD9AB00),
                    child: _buildCurrentTabContent(),
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    if (_activeTab == 0) {
      return null;
    } else if (_activeTab == 1) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text('workspace.action.add_customer'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: _showCreateCustomerDialog,
      );
    } else {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text('workspace.action.assign_task'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: _showCreateTaskDialog,
      );
    }
  }

  Widget _buildNavTab({
    required int index,
    required String label,
    required IconData icon,
    String? badge,
  }) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () {
        if (_activeTab != index) {
          setState(() => _activeTab = index);
          _reloadTab();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x100F172A), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildProjectsTab();
      case 1:
        return _buildCustomersTab();
      case 2:
      default:
        return _buildStandaloneTasksTab();
    }
  }

  // ==========================================
  // TAB 1: DỰ ÁN
  // ==========================================
  Widget _buildProjectsTab() {
    final filtered = _projects.where((p) {
      if (_projectSearch.isNotEmpty) {
        final q = _projectSearch.toLowerCase();
        if (!p.name.toLowerCase().contains(q) && !p.code.toLowerCase().contains(q)) return false;
      }
      if (_projectStatusFilter != 'ALL' && p.status != _projectStatusFilter) return false;
      if (_projectTypeFilter != 'ALL' && p.typeLabel != _projectTypeFilter) return false;
      return true;
    }).toList();

    // Summary stats
    final total = _projects.length;
    final activeCount = _projects.where((p) => p.status == 'active').length;
    final completedCount = _projects.where((p) => p.status == 'completed').length;
    final overdueCount = _projects.where((p) => p.overdueItems > 0).length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // KPI Cards
        Row(
          children: [
            Expanded(child: _buildMetricTile('workspace.metric.total_projects'.tr(), '$total', const Color(0xFF2563EB), const Color(0xFFEFF6FF), Icons.folder_copy_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('workspace.metric.in_progress'.tr(), '$activeCount', const Color(0xFF059669), const Color(0xFFECFDF5), Icons.play_circle_outline)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricTile('workspace.metric.completed'.tr(), '$completedCount', const Color(0xFF0F172A), const Color(0xFFF1F5F9), Icons.check_circle_outline)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('workspace.metric.overdue_items'.tr(), '$overdueCount', const Color(0xFFDC2626), const Color(0xFFFEF2F2), Icons.warning_amber_rounded)),
          ],
        ),
        const SizedBox(height: 14),

        // Search bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _projectSearch = val),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'workspace.project.search_hint'.tr(),
              hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                selected: _projectStatusFilter == 'ALL',
                label: 'workspace.filter.all_count'.tr(args: {'count': total}),
                onTap: () => setState(() => _projectStatusFilter = 'ALL'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _projectStatusFilter == 'active',
                label: 'workspace.filter.active_count'.tr(args: {'count': activeCount}),
                onTap: () => setState(() => _projectStatusFilter = 'active'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _projectStatusFilter == 'completed',
                label: 'workspace.filter.completed_count'.tr(args: {'count': completedCount}),
                onTap: () => setState(() => _projectStatusFilter = 'completed'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Project List
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.folder_off_outlined, size: 40, color: Color(0xFF94A3B8)),
                SizedBox(height: 8),
                Text('workspace.project.empty'.tr(), style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          )
        else
          for (final p in filtered) ...[
            _buildProjectCard(p),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildProjectCard(ProjectItem project) {
    Color statusColor;
    Color statusBg;
    switch (project.status) {
      case 'active':
        statusColor = const Color(0xFF047857);
        statusBg = const Color(0xFFD1FAE5);
        break;
      case 'completed':
        statusColor = const Color(0xFF1D4ED8);
        statusBg = const Color(0xFFDBEAFE);
        break;
      case 'cancelled':
        statusColor = const Color(0xFFB91C1C);
        statusBg = const Color(0xFFFEE2E2);
        break;
      default:
        statusColor = const Color(0xFF475569);
        statusBg = const Color(0xFFF1F5F9);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _showProjectDetailSheet(project),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Code, Status Badge, Type Chip
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      project.code,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      project.statusLabel,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    project.typeLabel,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Name
              Text(
                project.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),

              // Customer tag
              if (project.customerName != null && project.customerName!.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.business_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'workspace.project.customer'.tr(args: {'name': project.customerName}),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              const SizedBox(height: 10),

              // Row 3: Progress Bar & Items Counts
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (project.progressPercent / 100).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${project.progressPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Items breakdown footer
              Row(
                children: [
                  Text(
                    'workspace.project.items_closed'.tr(args: {'closed': project.closedItems, 'total': project.totalItems}),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  if (project.overdueItems > 0) ...[
                    const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8))),
                    Text(
                      'workspace.project.overdue_count'.tr(args: {'count': project.overdueItems}),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ],
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: KHÁCH HÀNG & HỢP ĐỒNG
  // ==========================================
  Widget _buildCustomersTab() {
    final filtered = _customers.where((c) {
      if (_customerSearch.isNotEmpty) {
        final q = _customerSearch.toLowerCase();
        if (!c.name.toLowerCase().contains(q) && !c.code.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _customerSearch = val),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'workspace.customer.search_hint'.tr(),
              hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 50),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.business_outlined, size: 44, color: Color(0xFF94A3B8)),
                SizedBox(height: 8),
                Text('workspace.customer.empty'.tr(), style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          )
        else
          for (final c in filtered) ...[
            _buildCustomerCard(c),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildCustomerCard(CustomerItem customer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _showCustomerContractsSheet(customer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      customer.code,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'workspace.customer.counts'.tr(args: {'contracts': customer.contractCount, 'projects': customer.projectCount}),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                customer.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (customer.note != null && customer.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  customer.note!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'workspace.customer.created_at'.tr(args: {'date': _formatDate(customer.createdAt)}),
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                  ),
                  Row(
                    children: [
                      Text('workspace.customer.view_contracts'.tr(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF2563EB)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: VIỆC NGOÀI DỰ ÁN (STANDALONE TASKS)
  // ==========================================
  Widget _buildStandaloneTasksTab() {
    final filtered = _tasks.where((t) {
      if (_taskSearch.isNotEmpty) {
        final q = _taskSearch.toLowerCase();
        if (!t.title.toLowerCase().contains(q) && !t.code.toLowerCase().contains(q)) return false;
      }
      if (_taskStatusFilter != 'ALL' && t.status != _taskStatusFilter) return false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Scope Selector (3 buttons)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              Expanded(
                child: _buildScopeItem('assigned_to_me', 'workspace.scope.assigned_to_me'.tr()),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildScopeItem('assigned_by_me', 'workspace.scope.assigned_by_me'.tr()),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildScopeItem('following', 'workspace.scope.following'.tr()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _taskSearch = val),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'workspace.task.search_hint'.tr(),
              hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                selected: _taskStatusFilter == 'ALL',
                label: 'workspace.filter.all_count'.tr(args: {'count': _tasks.length}),
                onTap: () => setState(() => _taskStatusFilter = 'ALL'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _taskStatusFilter == 'todo',
                label: 'workspace.filter.todo_count'.tr(args: {'count': _tasks.where((t) => t.status == 'todo').length}),
                onTap: () => setState(() => _taskStatusFilter = 'todo'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _taskStatusFilter == 'in_progress',
                label: 'workspace.filter.in_progress_count'.tr(args: {'count': _tasks.where((t) => t.status == 'in_progress').length}),
                onTap: () => setState(() => _taskStatusFilter = 'in_progress'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _taskStatusFilter == 'review',
                label: 'workspace.filter.review_count'.tr(args: {'count': _tasks.where((t) => t.status == 'review').length}),
                onTap: () => setState(() => _taskStatusFilter = 'review'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _taskStatusFilter == 'done',
                label: 'workspace.filter.done_count'.tr(args: {'count': _tasks.where((t) => t.status == 'done').length}),
                onTap: () => setState(() => _taskStatusFilter = 'done'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 40, color: Color(0xFF94A3B8)),
                SizedBox(height: 8),
                Text('workspace.task.empty'.tr(), style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          )
        else
          for (final t in filtered) ...[
            _buildStandaloneTaskCard(t),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildScopeItem(String scopeKey, String label) {
    final isSelected = _taskScope == scopeKey;
    return InkWell(
      onTap: () {
        if (_taskScope != scopeKey) {
          setState(() => _taskScope = scopeKey);
          _reloadTab();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x100F172A), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildStandaloneTaskCard(StandaloneTaskItem task) {
    Color priorityColor;
    Color priorityBg;
    switch (task.priority) {
      case 'urgent':
        priorityColor = const Color(0xFFDC2626);
        priorityBg = const Color(0xFFFEF2F2);
        break;
      case 'high':
        priorityColor = const Color(0xFFD97706);
        priorityBg = const Color(0xFFFFFBEB);
        break;
      default:
        priorityColor = const Color(0xFF475569);
        priorityBg = const Color(0xFFF1F5F9);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _showTaskStatusDialog(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.code,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.priorityLabel,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: priorityColor),
                    ),
                  ),
                  const Spacer(),
                  _buildTaskStatusBadge(task.status, task.isReversed),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (task.dueDate != null) ...[
                    const Icon(Icons.schedule, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'workspace.task.due'.tr(args: {'date': _formatDate(task.dueDate)}),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                  if (task.childCount > 0) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.account_tree_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'workspace.task.subtasks'.tr(args: {'open': task.openChildCount, 'total': task.childCount}),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                  const Spacer(),
                  Text('workspace.task.detail'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskStatusBadge(String status, bool isReversed) {
    if (isReversed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('workspace.task.void'.tr(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
      );
    }
    Color color;
    Color bg;
    String label;
    switch (status) {
      case 'in_progress':
        color = const Color(0xFF0284C7);
        bg = const Color(0xFFE0F2FE);
        label = 'workspace.status.in_progress'.tr();
        break;
      case 'review':
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFFFBEB);
        label = 'workspace.status.review'.tr();
        break;
      case 'done':
        color = const Color(0xFF059669);
        bg = const Color(0xFFECFDF5);
        label = 'workspace.status.done'.tr();
        break;
      case 'cancelled':
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        label = 'workspace.status.cancelled'.tr();
        break;
      case 'todo':
      default:
        color = const Color(0xFF64748B);
        bg = const Color(0xFFF1F5F9);
        label = 'workspace.status.todo'.tr();
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
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
      projectMap: _projectMap,
      onRefreshParent: _loadAllData,
    );
  }

  void _showTaskStatusDialog(StandaloneTaskItem task) {
    showWorkspaceTaskStatusSheet(
      context,
      task: task,
      service: _service,
      onStatusChanged: _reloadTab,
    );
  }

  void _showCreateCustomerDialog() {
    showWorkspaceCreateCustomerDialog(
      context,
      service: _service,
      onCustomerCreated: _reloadTab,
    );
  }

  void _showCreateTaskDialog() {
    showWorkspaceCreateTaskDialog(
      context,
      service: _service,
      onTaskCreated: _reloadTab,
    );
  }
}
