import 'package:flutter/material.dart';
import '../models/workspace_models.dart';
import '../services/workspace_service.dart';

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
          tooltip: 'Quay lại',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _activeTab == 0 ? 'Quản lý Dự án' : (_activeTab == 1 ? 'Khách hàng & Hợp đồng' : 'Việc ngoài dự án'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Text(
              'SVN DTS / Không gian làm việc',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Làm mới',
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
                      label: 'Dự án',
                      icon: Icons.folder_open_rounded,
                      badge: _projects.isNotEmpty ? '${_projects.length}' : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildNavTab(
                      index: 1,
                      label: 'Khách hàng',
                      icon: Icons.business_outlined,
                      badge: _customers.isNotEmpty ? '${_customers.length}' : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildNavTab(
                      index: 2,
                      label: 'Việc giao lẻ',
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
        label: const Text('Thêm khách hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: _showCreateCustomerDialog,
      );
    } else {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Giao việc mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
            Expanded(child: _buildMetricTile('Tổng dự án', '$total', const Color(0xFF2563EB), const Color(0xFFEFF6FF), Icons.folder_copy_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('Đang triển khai', '$activeCount', const Color(0xFF059669), const Color(0xFFECFDF5), Icons.play_circle_outline)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricTile('Đã hoàn thành', '$completedCount', const Color(0xFF0F172A), const Color(0xFFF1F5F9), Icons.check_circle_outline)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('Hạng mục quá hạn', '$overdueCount', const Color(0xFFDC2626), const Color(0xFFFEF2F2), Icons.warning_amber_rounded)),
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
            decoration: const InputDecoration(
              hintText: 'Tìm dự án hoặc mã số...',
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
                label: 'Tất cả ($total)',
                onTap: () => setState(() => _projectStatusFilter = 'ALL'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _projectStatusFilter == 'active',
                label: 'Đang triển khai ($activeCount)',
                onTap: () => setState(() => _projectStatusFilter = 'active'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _projectStatusFilter == 'completed',
                label: 'Hoàn thành ($completedCount)',
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
            child: const Column(
              children: [
                Icon(Icons.folder_off_outlined, size: 40, color: Color(0xFF94A3B8)),
                SizedBox(height: 8),
                Text('Không có dự án nào phù hợp', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                      'Khách hàng: ${project.customerName}',
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
                    '${project.closedItems} / ${project.totalItems} công việc đã đóng',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  if (project.overdueItems > 0) ...[
                    const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8))),
                    Text(
                      '${project.overdueItems} quá hạn',
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
            decoration: const InputDecoration(
              hintText: 'Tìm khách hàng theo tên hoặc mã...',
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
            child: const Column(
              children: [
                Icon(Icons.business_outlined, size: 44, color: Color(0xFF94A3B8)),
                SizedBox(height: 8),
                Text('Chưa có khách hàng nào', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                      '${customer.contractCount} hợp đồng · ${customer.projectCount} dự án',
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
                    'Ngày tạo: ${_formatDate(customer.createdAt)}',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                  ),
                  const Row(
                    children: [
                      Text('Xem hợp đồng', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
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
                child: _buildScopeItem('assigned_to_me', 'Giao cho tôi'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildScopeItem('assigned_by_me', 'Tôi đã giao'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildScopeItem('following', 'Theo dõi'),
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
            decoration: const InputDecoration(
              hintText: 'Tìm việc theo tên hoặc mã...',
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
                label: 'Tất cả (${_tasks.length})',
                onTap: () => setState(() => _taskStatusFilter = 'ALL'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _taskStatusFilter == 'todo',
                label: 'Cần làm (${_tasks.where((t) => t.status == 'todo').length})',
                onTap: () => setState(() => _taskStatusFilter = 'todo'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _taskStatusFilter == 'in_progress',
                label: 'Đang làm (${_tasks.where((t) => t.status == 'in_progress').length})',
                onTap: () => setState(() => _taskStatusFilter = 'in_progress'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _taskStatusFilter == 'review',
                label: 'Chờ duyệt (${_tasks.where((t) => t.status == 'review').length})',
                onTap: () => setState(() => _taskStatusFilter = 'review'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: _taskStatusFilter == 'done',
                label: 'Hoàn thành (${_tasks.where((t) => t.status == 'done').length})',
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
            child: const Column(
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 40, color: Color(0xFF94A3B8)),
                SizedBox(height: 8),
                Text('Không có công việc nào', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                      'Hạn: ${_formatDate(task.dueDate)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                  if (task.childCount > 0) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.account_tree_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      '${task.openChildCount}/${task.childCount} việc con',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                  const Spacer(),
                  const Text('Chi tiết', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
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
        child: const Text('Đã huỷ hiệu lực', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
      );
    }
    Color color;
    Color bg;
    String label;
    switch (status) {
      case 'in_progress':
        color = const Color(0xFF0284C7);
        bg = const Color(0xFFE0F2FE);
        label = 'Đang làm';
        break;
      case 'review':
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFFFBEB);
        label = 'Chờ duyệt';
        break;
      case 'done':
        color = const Color(0xFF059669);
        bg = const Color(0xFFECFDF5);
        label = 'Hoàn thành';
        break;
      case 'cancelled':
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        label = 'Đã huỷ';
        break;
      case 'todo':
      default:
        color = const Color(0xFF64748B);
        bg = const Color(0xFFF1F5F9);
        label = 'Cần làm';
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProjectDetailSheet(project: project, service: _service),
    );
  }

  void _showCustomerContractsSheet(CustomerItem customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerContractsSheet(
        customer: customer,
        service: _service,
        projectMap: _projectMap,
        onRefreshParent: _loadAllData,
      ),
    );
  }

  void _showTaskStatusDialog(StandaloneTaskItem task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskStatusSheet(
        task: task,
        service: _service,
        onStatusChanged: () {
          _reloadTab();
        },
      ),
    );
  }

  void _showCreateCustomerDialog() {
    final codeCtrl = TextEditingController(text: 'KH-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Thêm khách hàng mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Mã khách hàng *', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên khách hàng / Đối tác *', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Ghi chú', isDense: true),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () async {
              if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
              final ok = await _service.createCustomer(
                code: codeCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                note: noteCtrl.text.trim(),
              );
              if (ok) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  _reloadTab();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm khách hàng thành công')));
                }
              }
            },
            child: const Text('Tạo mới'),
          ),
        ],
      ),
    );
  }

  void _showCreateTaskDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'normal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Giao việc ngoài dự án', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Tiêu đề công việc *', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Nội dung chi tiết', isDense: true),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Mức độ ưu tiên: ', style: TextStyle(fontSize: 12)),
                  DropdownButton<String>(
                    value: priority,
                    onChanged: (val) => setDialogState(() => priority = val ?? 'normal'),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('Bình thường')),
                      DropdownMenuItem(value: 'high', child: Text('Cao')),
                      DropdownMenuItem(value: 'urgent', child: Text('Khẩn cấp')),
                      DropdownMenuItem(value: 'low', child: Text('Thấp')),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                // Assign to self by default if user is creator
                final ok = await _service.createStandaloneTask(
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  priority: priority,
                  assigneeUserId: '', // Handled by server or principal
                );
                if (ok) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    _reloadTab();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo việc giao lẻ')));
                  }
                }
              },
              child: const Text('Giao việc'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// CUSTOMER CONTRACTS BOTTOM SHEET
// ==========================================
class _CustomerContractsSheet extends StatefulWidget {
  final CustomerItem customer;
  final WorkspaceService service;
  final Map<String, String> projectMap;
  final VoidCallback onRefreshParent;

  const _CustomerContractsSheet({
    required this.customer,
    required this.service,
    required this.projectMap,
    required this.onRefreshParent,
  });

  @override
  State<_CustomerContractsSheet> createState() => _CustomerContractsSheetState();
}

class _CustomerContractsSheetState extends State<_CustomerContractsSheet> {
  bool _isLoading = true;
  List<ContractItem> _contracts = [];

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    final list = await widget.service.getCustomerContracts(widget.customer.id, widget.projectMap);
    if (mounted) {
      setState(() {
        _contracts = list;
        _isLoading = false;
      });
    }
  }

  String _formatVnd(double? val) {
    if (val == null) return '0 ₫';
    final str = val.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')} ₫';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('${c.code} · ${c.note ?? 'Không có ghi chú'}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Header with Add Contract button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Danh sách hợp đồng (${_contracts.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm hợp đồng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _showCreateContractDialog,
                ),
              ],
            ),
          ),

          // Contracts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9AB00)))
                : _contracts.isEmpty
                    ? const Center(child: Text('Khách hàng này chưa có hợp đồng nào', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _contracts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final ct = _contracts[idx];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(ct.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                                    ),
                                    const Spacer(),
                                    Text(ct.statusLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(ct.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Giá trị: ${_formatVnd(ct.value)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
                                    if (ct.projectName != null && ct.projectName!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('Dự án: ${ct.projectName}', style: const TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showCreateContractDialog() {
    final codeCtrl = TextEditingController(text: 'HD-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Thêm hợp đồng mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Số / Mã hợp đồng *', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên hợp đồng *', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: valueCtrl, decoration: const InputDecoration(labelText: 'Giá trị hợp đồng (VNĐ)', isDense: true), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Ghi chú', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () async {
              if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
              final ok = await widget.service.createContract(
                customerId: widget.customer.id,
                code: codeCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                value: double.tryParse(valueCtrl.text.trim()),
                note: noteCtrl.text.trim(),
              );
              if (ok) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  _loadContracts();
                  widget.onRefreshParent();
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PROJECT DETAIL BOTTOM SHEET
// ==========================================
class _ProjectDetailSheet extends StatefulWidget {
  final ProjectItem project;
  final WorkspaceService service;

  const _ProjectDetailSheet({
    required this.project,
    required this.service,
  });

  @override
  State<_ProjectDetailSheet> createState() => _ProjectDetailSheetState();
}

class _ProjectDetailSheetState extends State<_ProjectDetailSheet> {
  bool _isLoadingMembers = true;
  List<ProjectMemberItem> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final list = await widget.service.getProjectMembers(widget.project.id);
    if (mounted) {
      setState(() {
        _members = list;
        _isLoadingMembers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('${p.code} · ${p.typeLabel} · ${p.statusLabel}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Overview Metrics
          Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Tiến độ', '${p.progressPercent.toStringAsFixed(0)}%', const Color(0xFF059669)),
                _buildMetric('Đã hoàn thành', '${p.closedItems}/${p.totalItems}', const Color(0xFF0F172A)),
                _buildMetric('Quá hạn', '${p.overdueItems}', const Color(0xFFDC2626)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Project Members Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 16, color: Color(0xFF0F172A)),
                const SizedBox(width: 6),
                const Text('Thành viên & Phân quyền vai trò', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Spacer(),
                Text('${_members.length} thành viên', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),

          Expanded(
            child: _isLoadingMembers
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9AB00)))
                : _members.isEmpty
                    ? const Center(child: Text('Chưa phân bổ thành viên dự án', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _members.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, idx) {
                          final m = _members[idx];
                          Color roleColor;
                          Color roleBg;
                          switch (m.role) {
                            case 'manager':
                              roleColor = const Color(0xFF1D4ED8);
                              roleBg = const Color(0xFFEFF6FF);
                              break;
                            case 'technician':
                              roleColor = const Color(0xFF047857);
                              roleBg = const Color(0xFFECFDF5);
                              break;
                            default:
                              roleColor = const Color(0xFF475569);
                              roleBg = const Color(0xFFF1F5F9);
                              break;
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF0F172A),
                                  child: Text(m.fullName != null && m.fullName!.isNotEmpty ? m.fullName![0] : 'U', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.fullName ?? 'Thành viên', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      if (m.email != null) Text(m.email!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(4)),
                                  child: Text(m.roleLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: roleColor)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ==========================================
// TASK STATUS BOTTOM SHEET
// ==========================================
class _TaskStatusSheet extends StatelessWidget {
  final StandaloneTaskItem task;
  final WorkspaceService service;
  final VoidCallback onStatusChanged;

  const _TaskStatusSheet({
    required this.task,
    required this.service,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text(task.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Text('${task.code} · ${task.statusLabel} · Ưu tiên: ${task.priorityLabel}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(task.description!, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          ],
          const SizedBox(height: 16),
          const Text('Cập nhật trạng thái công việc:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 8),

          Row(
            children: [
              if (task.status == 'todo')
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                    onPressed: () async {
                      await service.changeStandaloneTaskStatus(task.id, 'in_progress');
                      if (context.mounted) {
                        Navigator.pop(context);
                        onStatusChanged();
                      }
                    },
                    child: const Text('Bắt đầu làm'),
                  ),
                ),
              if (task.status == 'in_progress') ...[
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                    onPressed: () async {
                      await service.changeStandaloneTaskStatus(task.id, 'review');
                      if (context.mounted) {
                        Navigator.pop(context);
                        onStatusChanged();
                      }
                    },
                    child: const Text('Gửi duyệt'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                    onPressed: () async {
                      await service.changeStandaloneTaskStatus(task.id, 'done');
                      if (context.mounted) {
                        Navigator.pop(context);
                        onStatusChanged();
                      }
                    },
                    child: const Text('Hoàn thành'),
                  ),
                ),
              ],
              if (task.status == 'review')
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                    onPressed: () async {
                      await service.changeStandaloneTaskStatus(task.id, 'done');
                      if (context.mounted) {
                        Navigator.pop(context);
                        onStatusChanged();
                      }
                    },
                    child: const Text('Phê duyệt hoàn thành'),
                  ),
                ),
              if (task.status == 'done')
                const Expanded(
                  child: Center(child: Text('Công việc đã hoàn thành', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
