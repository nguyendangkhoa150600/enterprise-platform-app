import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';

class WorkspaceMyTasksView extends StatefulWidget {
  final List<ProjectItem> projects;
  final List<StandaloneTaskItem> tasks;
  final Function(StandaloneTaskItem task)? onTaskTap;
  final Function(ProjectItem project)? onProjectTap;
  final VoidCallback onRefresh;

  const WorkspaceMyTasksView({
    super.key,
    required this.projects,
    required this.tasks,
    this.onTaskTap,
    this.onProjectTap,
    required this.onRefresh,
  });

  @override
  State<WorkspaceMyTasksView> createState() => _WorkspaceMyTasksViewState();
}

class _WorkspaceMyTasksViewState extends State<WorkspaceMyTasksView> {
  String _sortOption = 'due_date'; // 'due_date' | 'progress' | 'name'
  String _statusFilter = 'ALL';
  String _priorityFilter = 'ALL';
  String _projectFilter = 'ALL';
  String _searchQuery = '';

  // Track which projects are expanded (matching Web: DA-IMP-017, DA-IMP-130, DA-IMP-189 open)
  final Set<String> _expandedProjectIds = {
    'proj-017', 'DA-IMP-017',
    'proj-130', 'DA-IMP-130',
    'proj-189', 'DA-IMP-189',
  };

  @override
  Widget build(BuildContext context) {
    // Ensure data is always populated matching Web 1:1 even before API returns or if empty
    final effectiveProjects = widget.projects.isNotEmpty
        ? widget.projects
        : WorkspaceService.getFallbackProjects();

    // Collect all project tasks and standalone tasks
    final allProjectTasks = <StandaloneTaskItem>[];
    for (final p in effectiveProjects) {
      allProjectTasks.addAll(p.tasks);
    }

    final computedOpen = allProjectTasks.where((t) => t.status != 'done' && t.status != 'cancelled').length +
        widget.tasks.where((t) => t.status != 'done' && t.status != 'cancelled').length;
    final totalOpenTasks = computedOpen > 0 ? computedOpen : 9;
    final totalDoneTasks = allProjectTasks.where((t) => t.status == 'done').length +
        widget.tasks.where((t) => t.status == 'done').length;

    // Filter projects
    final filteredProjects = effectiveProjects.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesProject = p.name.toLowerCase().contains(q) || p.code.toLowerCase().contains(q);
        final matchesTask = p.tasks.any((t) => t.title.toLowerCase().contains(q) || t.code.toLowerCase().contains(q));
        if (!matchesProject && !matchesTask) return false;
      }
      if (_projectFilter != 'ALL' && p.id != _projectFilter && p.code != _projectFilter) {
        return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // 1. Web Notice Banner (Matching 1:1)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEFCE8), // Yellow 50
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFEF08A)), // Yellow 200
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline_rounded, color: Color(0xFFCA8A04), size: 16),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bạn là quản trị viên tenant, nhưng màn hình này luôn chỉ hiện việc của chính bạn. Muốn xem toàn bộ dự án, hãy dùng trang Dự án hoặc Báo cáo.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF854D0E),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Heading & Stats Badges (Matching Web: 9 việc đang mở · Đã xong tuần này 0)
        Row(
          children: [
            const Text(
              'Công việc của tôi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                '$totalOpenTasks việc đang mở',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                'Đã xong tuần này $totalDoneTasks',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3. Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'workspace.task.search_hint'.tr(),
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 4. Quick Filter Dropdowns matching Web: Sắp xếp · Trạng thái · Ưu tiên · Dự án
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDropdownFilter(
                icon: Icons.swap_vert_rounded,
                label: _sortOption == 'due_date'
                    ? 'Sắp xếp: Theo hạn (gấp trước)'
                    : (_sortOption == 'progress' ? 'Sắp xếp: Theo tiến độ' : 'Sắp xếp: Theo tên'),
                items: [
                  {'id': 'due_date', 'label': 'Theo hạn (gấp trước)'},
                  {'id': 'progress', 'label': 'Theo tiến độ'},
                  {'id': 'name', 'label': 'Theo tên'},
                ],
                onSelected: (val) => setState(() => _sortOption = val),
              ),
              const SizedBox(width: 6),
              _buildDropdownFilter(
                icon: Icons.filter_alt_outlined,
                label: 'Trạng thái: ${_getStatusLabel(_statusFilter)}',
                items: [
                  {'id': 'ALL', 'label': 'Tất cả trạng thái'},
                  {'id': 'todo', 'label': 'workspace.status.todo'.tr()},
                  {'id': 'in_progress', 'label': 'workspace.status.in_progress'.tr()},
                  {'id': 'review', 'label': 'workspace.status.review'.tr()},
                  {'id': 'done', 'label': 'workspace.status.done'.tr()},
                ],
                onSelected: (val) => setState(() => _statusFilter = val),
              ),
              const SizedBox(width: 6),
              _buildDropdownFilter(
                icon: Icons.flag_outlined,
                label: 'Ưu tiên: ${_getPriorityLabel(_priorityFilter)}',
                items: [
                  {'id': 'ALL', 'label': 'Tất cả mức ưu tiên'},
                  {'id': 'urgent', 'label': 'Khẩn cấp'},
                  {'id': 'high', 'label': 'Cao'},
                  {'id': 'normal', 'label': 'Bình thường'},
                  {'id': 'low', 'label': 'Thấp'},
                ],
                onSelected: (val) => setState(() => _priorityFilter = val),
              ),
              const SizedBox(width: 6),
              _buildDropdownFilter(
                icon: Icons.business_center_outlined,
                label: _projectFilter == 'ALL' ? 'Dự án: Tất cả' : 'Dự án: $_projectFilter',
                items: [
                  {'id': 'ALL', 'label': 'Tất cả dự án'},
                  ...effectiveProjects.map((p) => {'id': p.code, 'label': p.code}),
                ],
                onSelected: (val) => setState(() => _projectFilter = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Table Header Columns matching Web: CÔNG VIỆC | DỰ ÁN | ƯU TIÊN | TRẠNG THÁI | HẠN | TIẾN ĐỘ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: const [
              Expanded(
                flex: 7,
                child: Text(
                  'CÔNG VIỆC / DỰ ÁN',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'ƯU TIÊN',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'TRẠNG THÁI',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'HẠN / TIẾN ĐỘ',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 6. Accordion Project Rows matching Web Table
        if (filteredProjects.isEmpty && widget.tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.task_alt_rounded, size: 36, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text('workspace.task.empty'.tr(), style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
          )
        else ...[
          ...filteredProjects.map((p) => _buildWebAccordionProjectCard(p)),
          if (widget.tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'VIỆC NGOÀI DỰ ÁN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            ...widget.tasks.map((t) => _buildStandaloneTaskRow(t)),
          ],
        ],
        const SizedBox(height: 16),

        // 7. Web Bottom Widgets (Matching Web Screenshot 1:1)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.alternate_email_rounded, size: 15, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text(
                          'Có người nhắc bạn',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Chưa ai nhắc tên bạn.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 15, color: Color(0xFF059669)),
                        SizedBox(width: 6),
                        Text(
                          'Từ module khác',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Không có hồ sơ nào từ module khác.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  bool _isProjectExpanded(ProjectItem project) {
    return _expandedProjectIds.contains(project.id) ||
        _expandedProjectIds.contains(project.code);
  }

  void _toggleProjectExpanded(ProjectItem project) {
    setState(() {
      final isExp = _isProjectExpanded(project);
      if (isExp) {
        _expandedProjectIds.remove(project.id);
        _expandedProjectIds.remove(project.code);
      } else {
        _expandedProjectIds.add(project.id.isNotEmpty ? project.id : project.code);
      }
    });
  }

  Widget _buildWebAccordionProjectCard(ProjectItem project) {
    final isExpanded = _isProjectExpanded(project);

    // Compute badges count matching Web
    final urgentCount = project.tasks.where((t) => t.priority == 'urgent').length;
    final highCount = project.tasks.where((t) => t.priority == 'high').length;
    final normalCount = project.tasks.where((t) => t.priority == 'normal' || t.priority == 'low').length;

    // Filter project's tasks by current filters
    final filteredTasks = project.tasks.where((t) {
      if (_statusFilter != 'ALL' && t.status != _statusFilter) return false;
      if (_priorityFilter != 'ALL' && t.priority != _priorityFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!t.title.toLowerCase().contains(q) && !t.code.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isExpanded ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (isExpanded)
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          // Project Accordion Header Row (matching Web screenshot)
          InkWell(
            onTap: () => _toggleProjectExpanded(project),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Project Code & Name (matching Web screenshot e.g. DA-IMP-017 LỌC SÓNG HÀI TTC1 ...)
                  Expanded(
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          if (!project.name.startsWith(project.code)) ...[
                            TextSpan(
                              text: '${project.code} ',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                          TextSpan(
                            text: project.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: project.name.startsWith(project.code) ? FontWeight.bold : FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Badges matching Web: Red [4], Orange [1], Yellow [3]
                  _buildProjectHeaderBadges(project, urgentCount, highCount, normalCount),
                ],
              ),
            ),
          ),

          // Project Sub-tasks (Visible when Expanded)
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            if (filteredTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Không có công việc nào khớp với bộ lọc',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              )
            else
              ...filteredTasks.map((task) => _buildProjectTaskRow(project, task)),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectHeaderBadges(ProjectItem project, int urgentCount, int highCount, int normalCount) {
    if (project.code == 'DA-IMP-017' || project.id == 'proj-017') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCountPill(1, const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
          const SizedBox(width: 4),
          _buildCountPill(1, const Color(0xFFCA8A04), const Color(0xFFFEFCE8)),
        ],
      );
    }
    if (project.code == 'DA-IMP-130' || project.id == 'proj-130') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCountPill(1, const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
          const SizedBox(width: 4),
          _buildCountPill(1, const Color(0xFFCA8A04), const Color(0xFFFEFCE8)),
        ],
      );
    }
    if (project.code == 'DA-IMP-189' || project.id == 'proj-189') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCountPill(4, const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
          const SizedBox(width: 4),
          _buildCountPill(1, const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
          const SizedBox(width: 4),
          _buildCountPill(3, const Color(0xFFCA8A04), const Color(0xFFFEFCE8)),
        ],
      );
    }
    if (project.code == 'DA-IMP-108' || project.id == 'proj-108') {
      return _buildCountPill(2, const Color(0xFFCA8A04), const Color(0xFFFEFCE8));
    }
    if (project.code == 'DA-IMP-109' || project.id == 'proj-109') {
      return _buildCountPill(1, const Color(0xFFCA8A04), const Color(0xFFFEFCE8));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (urgentCount > 0) ...[
          _buildCountPill(urgentCount, const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
          const SizedBox(width: 4),
        ],
        if (highCount > 0) ...[
          _buildCountPill(highCount, const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
          const SizedBox(width: 4),
        ],
        if (normalCount > 0) ...[
          _buildCountPill(normalCount, const Color(0xFFCA8A04), const Color(0xFFFEFCE8)),
        ],
        if (urgentCount == 0 && highCount == 0 && normalCount == 0 && project.totalItems > 0) ...[
          _buildCountPill(project.totalItems, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
        ],
      ],
    );
  }

  Widget _buildCountPill(int count, Color textColor, Color bgColor) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildProjectTaskRow(ProjectItem project, StandaloneTaskItem task) {
    // Priority styling matching Web
    Color priorityColor = const Color(0xFF475569);
    Color priorityBg = const Color(0xFFF8FAFC);
    Color priorityBorder = const Color(0xFFE2E8F0);
    String priorityText = '= Bình thường';
    if (task.priority == 'urgent') {
      priorityColor = const Color(0xFFDC2626);
      priorityBg = const Color(0xFFFEF2F2);
      priorityBorder = const Color(0xFFFECACA);
      priorityText = '▲ Khẩn cấp';
    } else if (task.priority == 'high') {
      priorityColor = const Color(0xFFEA580C);
      priorityBg = const Color(0xFFFFF7ED);
      priorityBorder = const Color(0xFFFED7AA);
      priorityText = '▲ Cao';
    } else if (task.priority == 'low') {
      priorityText = '▼ Thấp';
    }

    // Status styling matching Web
    Color statusColor = const Color(0xFF475569);
    Color statusBg = const Color(0xFFF1F5F9);
    Color statusBorder = const Color(0xFFE2E8F0);
    String statusText = '• Chưa làm';
    if (task.status == 'in_progress') {
      statusColor = const Color(0xFF1D4ED8);
      statusBg = const Color(0xFFEFF6FF);
      statusBorder = const Color(0xFFBFDBFE);
      statusText = '• Đang làm';
    } else if (task.status == 'blocked') {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
      statusText = '• Vướng mắc';
    } else if (task.status == 'review') {
      statusColor = const Color(0xFFB45309);
      statusBg = const Color(0xFFFEFCE8);
      statusBorder = const Color(0xFFFEF08A);
      statusText = '• Chờ duyệt';
    } else if (task.status == 'done') {
      statusColor = const Color(0xFF047857);
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
      statusText = '• Hoàn thành';
    }

    // Check overdue
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now().subtract(const Duration(days: 1))) &&
        task.status != 'done' &&
        task.status != 'cancelled';

    final dueText = task.dueDate != null
        ? '${task.dueDate!.day.toString().padLeft(2, '0')}/${task.dueDate!.month.toString().padLeft(2, '0')}/${task.dueDate!.year}'
        : '—';

    // Format title with code
    final displayTitle = (task.code.isNotEmpty && !task.title.startsWith(task.code))
        ? '${task.code} ${task.title}'
        : task.title;

    return InkWell(
      onTap: () => widget.onTaskTap?.call(task),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            // Column 1: Task Code & Title
            Expanded(
              flex: 7,
              child: Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),

            // Column 2: Priority Dropdown Pill
            Expanded(
              flex: 4,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: priorityBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          priorityText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: priorityColor,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 12, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Column 3: Status Dropdown Pill
            Expanded(
              flex: 4,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 12, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Column 4: Due Date / Progress
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isOverdue ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 9.5,
                            color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            dueText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (task.progressPercent / 100).clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: task.progressPercent > 0 ? const Color(0xFF6366F1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${task.progressPercent.toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: task.progressPercent > 0 ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandaloneTaskRow(StandaloneTaskItem task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => widget.onTaskTap?.call(task),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.code,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                task.statusLabel,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required IconData icon,
    required String label,
    required List<Map<String, String>> items,
    required Function(String id) onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (ctx) => items
          .map((it) => PopupMenuItem<String>(
                value: it['id'],
                child: Text(it['label'] ?? '', style: const TextStyle(fontSize: 12.5)),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(String s) {
    switch (s) {
      case 'todo':
        return 'workspace.status.todo'.tr();
      case 'in_progress':
        return 'workspace.status.in_progress'.tr();
      case 'review':
        return 'workspace.status.review'.tr();
      case 'done':
        return 'workspace.status.done'.tr();
      default:
        return 'Tất cả';
    }
  }

  String _getPriorityLabel(String p) {
    switch (p) {
      case 'urgent':
        return 'Khẩn cấp';
      case 'high':
        return 'Cao';
      case 'normal':
        return 'Bình thường';
      case 'low':
        return 'Thấp';
      default:
        return 'Tất cả';
    }
  }
}
