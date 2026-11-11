import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../models/workspace_models.dart';
import '../../controllers/workspace_controller.dart';

class WorkspaceProjectsTabView extends StatefulWidget {
  final WorkspaceController controller;
  final ValueChanged<ProjectItem> onProjectTap;

  const WorkspaceProjectsTabView({
    super.key,
    required this.controller,
    required this.onProjectTap,
  });

  @override
  State<WorkspaceProjectsTabView> createState() => _WorkspaceProjectsTabViewState();
}

class _WorkspaceProjectsTabViewState extends State<WorkspaceProjectsTabView> {
  // Track expanded project groups
  final Set<String> _expandedGroups = {};
  bool _initializedExpansion = false;
  String? _lastArchivedFilter;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.controller.projectSearch);
    _lastArchivedFilter = widget.controller.archivedFilter;
  }

  @override
  void didUpdateWidget(covariant WorkspaceProjectsTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.archivedFilter != _lastArchivedFilter) {
      _lastArchivedFilter = widget.controller.archivedFilter;
      _expandedGroups.clear();
      _initializedExpansion = false;
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.text = '';
      }
    } else if (widget.controller.projectSearch != _searchCtrl.text) {
      _searchCtrl.text = widget.controller.projectSearch;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final allProjects = controller.projects;

    // Filter projects
    final filtered = allProjects.where((p) {
      if (controller.projectSearch.isNotEmpty) {
        final q = controller.projectSearch.toLowerCase();
        if (!p.name.toLowerCase().contains(q) && !p.code.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (controller.projectStatusFilter != 'ALL' && p.status != controller.projectStatusFilter) {
        return false;
      }
      if (controller.projectGroupFilter != 'ALL') {
        final groupName = p.projectType != null && p.projectType!.trim().isNotEmpty
            ? p.projectType!.trim()
            : 'Chưa phân loại';
        if (groupName != controller.projectGroupFilter) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort projects
    filtered.sort((a, b) {
      if (controller.projectSort == 'code') {
        return a.code.compareTo(b.code);
      }
      return a.name.compareTo(b.name);
    });

    // Group projects by Nhóm (projectType)
    final Map<String, List<ProjectItem>> groupedProjects = {};
    for (final p in filtered) {
      final group = p.projectType != null && p.projectType!.trim().isNotEmpty
          ? p.projectType!.trim()
          : 'Chưa phân loại';
      groupedProjects.putIfAbsent(group, () => []).add(p);
    }

    // Sort groups alphabetically matching Web (Bán hàng ngoài EVN -> Bán hàng trong EVN -> Dịch vụ Thí nghiệm...)
    final sortedGroupKeys = groupedProjects.keys.toList()..sort();
    for (final k in sortedGroupKeys) {
      groupedProjects[k]!.sort((a, b) {
        if (controller.projectSort == 'code') {
          return a.code.compareTo(b.code);
        }
        return a.name.compareTo(b.name);
      });
    }

    // Default open all groups on first load
    if (!_initializedExpansion && sortedGroupKeys.isNotEmpty) {
      _expandedGroups.addAll(sortedGroupKeys);
      _initializedExpansion = true;
    }

    // Compute stats matching Web
    final totalProjects = allProjects.length;
    final runningProjects = allProjects.where((p) => p.status == 'active' || p.status == 'deploying').length;
    final completedProjects = allProjects.where((p) => p.status == 'completed' || p.status == 'done').length;

    // Extract unique groups and count projects per group for filter
    final availableGroups = <String>{};
    final Map<String, int> groupProjectCounts = {};
    for (final p in allProjects) {
      final g = p.projectType != null && p.projectType!.trim().isNotEmpty
          ? p.projectType!.trim()
          : 'Chưa phân loại';
      availableGroups.add(g);
      groupProjectCounts[g] = (groupProjectCounts[g] ?? 0) + 1;
    }
    final sortedGroups = availableGroups.toList()..sort();

    final isArchived = controller.archivedFilter == 'only';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // 1. Top Sub-Tabs: [Dự án] • [Khách hàng] (Matching Web)
        Row(
          children: [
            _buildSubTab(
              label: 'Dự án',
              isSelected: true,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            _buildSubTab(
              label: 'Khách hàng',
              isSelected: false,
              onTap: () => controller.setTab(3),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Segmented Tabs & Summary Badges (Matching Web: Đang làm | Lưu trữ 486 • 194 dự án · Đang chạy 124 · Hoàn thành 0)
        Row(
          children: [
            // Segment [Đang làm] | [Lưu trữ]
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(2.5),
              child: Row(
                children: [
                  _buildSegmentButton(
                    label: 'Đang làm',
                    isActive: !isArchived,
                    onTap: () => controller.setArchivedFilter('exclude'),
                  ),
                  _buildSegmentButton(
                    label: 'Lưu trữ 486',
                    isActive: isArchived,
                    onTap: () => controller.setArchivedFilter('only'),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Top Stats (matching Web: 194 dự án · Đang chạy 124 · Hoàn thành 0)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Text(
                    '$totalProjects dự án',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Đang chạy $runningProjects',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hoàn thành $completedProjects',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
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
            controller: _searchCtrl,
            onChanged: controller.setProjectSearch,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tìm dự án hoặc mã số...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              suffixIcon: controller.projectSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchCtrl.clear();
                        controller.setProjectSearch('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 4. Quick Filters Matching Web: Sắp xếp · Trạng thái · Nhóm
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Sắp xếp
              _buildDropdownFilter(
                icon: Icons.swap_vert_rounded,
                label: controller.projectSort == 'name'
                    ? 'Sắp xếp: Theo tên'
                    : 'Sắp xếp: Theo mã',
                items: [
                  {'id': 'name', 'label': 'Theo tên'},
                  {'id': 'code', 'label': 'Theo mã'},
                ],
                onSelected: controller.setProjectSort,
              ),
              const SizedBox(width: 6),

              // Trạng thái
              _buildDropdownFilter(
                icon: Icons.filter_alt_outlined,
                label: 'Trạng thái: ${_getStatusLabel(controller.projectStatusFilter)}',
                items: [
                  {'id': 'ALL', 'label': 'Tất cả trạng thái'},
                  {'id': 'active', 'label': 'Đang triển khai / Đang chạy'},
                  {'id': 'completed', 'label': 'Hoàn thành'},
                  {'id': 'draft', 'label': 'Khởi tạo'},
                ],
                onSelected: controller.setProjectStatusFilter,
              ),
              const SizedBox(width: 6),

              // Nhóm (Scrollable & Searchable Bottom Sheet)
              InkWell(
                onTap: () => _showGroupFilterSheet(
                  context: context,
                  currentGroup: controller.projectGroupFilter,
                  groups: sortedGroups,
                  groupCounts: groupProjectCounts,
                  onSelected: controller.setProjectGroupFilter,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: controller.projectGroupFilter != 'ALL'
                        ? const Color(0xFFEFF6FF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: controller.projectGroupFilter != 'ALL'
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 13,
                        color: controller.projectGroupFilter != 'ALL'
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        controller.projectGroupFilter == 'ALL'
                            ? 'Nhóm: Tất cả'
                            : 'Nhóm: ${controller.projectGroupFilter}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: controller.projectGroupFilter != 'ALL'
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: controller.projectGroupFilter != 'ALL'
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 14,
                        color: controller.projectGroupFilter != 'ALL'
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Accordion Project Groups matching Web Table 1:1
        if (groupedProjects.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.folder_off_outlined, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  isArchived ? 'Không có dự án lưu trữ nào khớp với bộ lọc' : 'workspace.project.empty'.tr(),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...sortedGroupKeys.map((groupName) {
            final projectsInGroup = groupedProjects[groupName] ?? [];
            return _buildGroupAccordionCard(groupName, projectsInGroup);
          }),
        const SizedBox(height: 24),
      ],
    );
  }

  // Sub Tab button (Dự án / Khách hàng)
  Widget _buildSubTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // Segment Button (Đang làm / Lưu trữ)
  Widget _buildSegmentButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // Group Accordion Card (Matching Web Groups: Bán hàng ngoài EVN, Dịch vụ bảo trì...)
  Widget _buildGroupAccordionCard(String groupName, List<ProjectItem> projects) {
    final isExpanded = _expandedGroups.contains(groupName);

    // Compute badges in group matching Web (red / orange / yellow)
    int urgentItems = 0;
    int openItems = 0;
    for (final p in projects) {
      urgentItems += p.overdueItems;
      openItems += (p.totalItems - p.closedItems);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isExpanded ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Group Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedGroups.remove(groupName);
                } else {
                  _expandedGroups.add(groupName);
                }
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      groupName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Badges matching Web: Red [urgent], Orange [open], Yellow [total]
                  if (urgentItems > 0) ...[
                    _buildCountPill(urgentItems, const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                    const SizedBox(width: 4),
                  ],
                  if (openItems > 0) ...[
                    _buildCountPill(openItems, const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
                    const SizedBox(width: 4),
                  ],
                  _buildCountPill(projects.length, const Color(0xFFCA8A04), const Color(0xFFFEFCE8)),
                ],
              ),
            ),
          ),

          // Group Projects List (when expanded)
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ...projects.map((project) => _buildProjectRow(project)),
          ],
        ],
      ),
    );
  }

  // Project Row within Group
  Widget _buildProjectRow(ProjectItem project) {
    Color statusColor;
    Color statusBg;
    switch (project.status) {
      case 'active':
      case 'deploying':
      case 'in_progress':
        statusColor = const Color(0xFF1D4ED8);
        statusBg = const Color(0xFFEFF6FF);
        break;
      case 'paused':
      case 'blocked':
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        break;
      case 'completed':
      case 'done':
        statusColor = const Color(0xFF047857);
        statusBg = const Color(0xFFD1FAE5);
        break;
      case 'cancelled':
        statusColor = const Color(0xFF64748B);
        statusBg = const Color(0xFFF1F5F9);
        break;
      default:
        statusColor = const Color(0xFF475569);
        statusBg = const Color(0xFFF1F5F9);
        break;
    }

    return InkWell(
      onTap: () => widget.onProjectTap(project),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Project Code & Status Badge & Progress
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    project.statusLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                const Spacer(),
                Text(
                  '${project.progressPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Full Project Name
            Text(
              project.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),

            // Row 3: Customer + Tasks Closed / Overdue
            Row(
              children: [
                if (project.customerName != null && project.customerName!.isNotEmpty) ...[
                  const Icon(Icons.business_outlined, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      project.customerName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${project.closedItems}/${project.totalItems} việc đã đóng',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                if (project.overdueItems > 0) ...[
                  const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8))),
                  Text(
                    '${project.overdueItems} quá hạn',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Count badge pill
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
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  // Dropdown filter button
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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
      case 'active':
        return 'Đang triển khai';
      case 'completed':
        return 'Hoàn thành';
      case 'draft':
        return 'Khởi tạo';
      default:
        return 'Tất cả';
    }
  }

  // Modal Bottom Sheet: Searchable & Scrollable Project Groups
  void _showGroupFilterSheet({
    required BuildContext context,
    required String currentGroup,
    required List<String> groups,
    required Map<String, int> groupCounts,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredGroups = groups.where((g) {
              if (searchQuery.trim().isEmpty) return true;
              return g.toLowerCase().contains(searchQuery.trim().toLowerCase());
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Indicator
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header: Title & Close Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_outlined, size: 20, color: Color(0xFF0F172A)),
                          const SizedBox(width: 8),
                          const Text(
                            'Lọc theo Nhóm dự án',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Search Input
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          onChanged: (val) {
                            setSheetState(() {
                              searchQuery = val;
                            });
                          },
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm nhóm...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                                    onPressed: () {
                                      setSheetState(() {
                                        searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Scrollable List of Groups
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          // "Tất cả các nhóm" option
                          if (searchQuery.trim().isEmpty || 'tất cả các nhóm'.contains(searchQuery.toLowerCase()))
                            _buildGroupSheetItem(
                              label: 'Tất cả các nhóm',
                              count: null,
                              isSelected: currentGroup == 'ALL',
                              onTap: () {
                                onSelected('ALL');
                                Navigator.pop(ctx);
                              },
                            ),

                          if (filteredGroups.isEmpty && searchQuery.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  'Không tìm thấy nhóm phù hợp',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                ),
                              ),
                            )
                          else
                            ...filteredGroups.map((g) {
                              final isSelected = currentGroup == g;
                              final count = groupCounts[g];
                              return _buildGroupSheetItem(
                                label: g,
                                count: count,
                                isSelected: isSelected,
                                onTap: () {
                                  onSelected(g);
                                  Navigator.pop(ctx);
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Group Sheet Item
  Widget _buildGroupSheetItem({
    required String label,
    required int? count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (count != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF1D4ED8))
            else
              const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }
}

