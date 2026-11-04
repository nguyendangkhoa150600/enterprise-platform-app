import 'package:flutter/material.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/user_resolver.dart';
import 'workspace_sheets.dart';
import 'workspace_project_members_sheet.dart';
import 'workspace_tab_chats.dart';
import 'workspace_project_kanban_view.dart';
import 'workspace_project_gantt_view.dart';
import 'workspace_landscape_fullscreen_screen.dart';
import 'workspace_documents_reports_view.dart';

class ProjectDetailSheet extends StatefulWidget {
  final ProjectItem project;
  final WorkspaceService service;

  const ProjectDetailSheet({
    super.key,
    required this.project,
    required this.service,
  });

  @override
  State<ProjectDetailSheet> createState() => _ProjectDetailSheetState();
}

class _ProjectDetailSheetState extends State<ProjectDetailSheet> {
  late ProjectItem _project;
  bool _isLoadingTasks = true;
  List<StandaloneTaskItem> _tasks = [];
  List<ProjectMemberItem> _members = [];

  // Tab: 0: Công việc, 1: Lịch, 2: Tài liệu, 3: Tài chính, 4: Đơn từ, 5: Hoạt động
  int _selectedTabIndex = 0;

  // Task filters
  String _statusFilter = 'ALL';
  String _priorityFilter = 'ALL';
  String _assigneeFilter = 'ALL';
  String _sortOrder = 'wbs'; // 'wbs' | 'dueDate' | 'priority' | 'title'
  String _viewMode = 'table'; // 'table' | 'kanban'

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _tasks = List.from(widget.project.tasks);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadProjectDetail(),
      _loadWorkItems(),
      _loadMembers(),
    ]);
  }

  Future<void> _loadProjectDetail() async {
    try {
      final updated = await widget.service.getProjectDetail(_project.id);
      if (updated != null && mounted) {
        setState(() => _project = updated);
      }
    } catch (e) {
      debugPrint('[ProjectDetailSheet] loadProjectDetail error: $e');
    }
  }

  Future<void> _loadWorkItems() async {
    setState(() => _isLoadingTasks = true);
    try {
      final items = await widget.service.getProjectWorkItems(_project.id);
      if (mounted) {
        setState(() {
          _tasks = items;
          _isLoadingTasks = false;
        });
        _syncMembersWithTasks();
      }
    } catch (e) {
      debugPrint('[ProjectDetailSheet] loadWorkItems error: $e');
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  void _openLandscapeFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => WorkspaceLandscapeFullscreenScreen(
          project: _project,
          tasks: _tasks,
          initialViewMode: _viewMode,
          service: widget.service,
          onRefresh: _loadWorkItems,
        ),
      ),
    );
  }

  void _syncMembersWithTasks() {
    final Map<String, ProjectMemberItem> memberMap = {};
    for (final m in _members) {
      if (m.userId.isNotEmpty) memberMap[m.userId] = m;
    }
    for (final t in _tasks) {
      if (t.assigneeUserId.isNotEmpty && !memberMap.containsKey(t.assigneeUserId)) {
        final name = t.assigneeName != null && t.assigneeName!.isNotEmpty
            ? t.assigneeName!
            : UserResolver.resolveName(t.assigneeUserId);
        memberMap[t.assigneeUserId] = ProjectMemberItem(
          userId: t.assigneeUserId,
          fullName: name,
          email: '',
          role: 'technician',
        );
      }
    }
    if (memberMap.length != _members.length && mounted) {
      setState(() => _members = memberMap.values.toList());
    }
  }

  Future<void> _loadMembers() async {
    try {
      final list = await widget.service.getProjectMembers(_project.id);
      if (mounted) {
        final Map<String, ProjectMemberItem> memberMap = {};
        for (final m in list) {
          if (m.userId.isNotEmpty) memberMap[m.userId] = m;
        }
        for (final t in _tasks) {
          if (t.assigneeUserId.isNotEmpty && !memberMap.containsKey(t.assigneeUserId)) {
            final name = t.assigneeName != null && t.assigneeName!.isNotEmpty
                ? t.assigneeName!
                : UserResolver.resolveName(t.assigneeUserId);
            memberMap[t.assigneeUserId] = ProjectMemberItem(
              userId: t.assigneeUserId,
              fullName: name,
              email: '',
              role: 'member',
            );
          }
        }
        setState(() {
          _members = memberMap.values.toList();
        });
      }
    } catch (e) {
      debugPrint('[ProjectDetailSheet] loadMembers error: $e');
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  String _formatFullDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _getInitials(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 'DA';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
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
            // Drag indicator & Close
            _buildTopBar(),

            // Web-synchronized Header
            _buildProjectHeader(),

            // Tabs matching Web 1:1
            _buildTabsBar(),

            // Tab Content
            Expanded(
              child: _buildActiveTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Thanh kéo xám luôn ở chính giữa đỉnh modal
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Nút đóng X gọn gàng ở góc phải
          Positioned(
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
              tooltip: 'Đóng',
              onPressed: () => Navigator.pop(context),
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  // Header matching Web 1:1
  Widget _buildProjectHeader() {
    final p = _project;
    final initials = _getInitials(p.name);
    final totalTasks = _tasks.isNotEmpty ? _tasks.length : p.totalItems;
    final totalMembers = _members.isNotEmpty ? _members.length : 4;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Purple circle avatar with initials (like "BN" on Web)
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF7C3AED),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title + Status badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStatusDropdown(p.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar + Percent & Member avatars row
          Row(
            children: [
              // Progress Bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tiến độ dự án',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '${p.progressPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (p.progressPercent / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Members Stack + Button
              _buildMembersStackButton(totalMembers),
            ],
          ),
          const SizedBox(height: 10),

          // Meta Information Row matching Web 1:1
          // ID: DA-IMP-217 · Nhóm: Bán hàng ngoài EVN · 3 công việc · 4 thành viên · 0 tài liệu · 08/06/2023 — 15/06/2023
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'ID: ${p.code} · Nhóm: ${p.typeLabel} · $totalTasks công việc · $totalMembers thành viên · 0 tài liệu · '
              '${p.startDate != null ? _formatDate(p.startDate) : '—'} — ${p.endDate != null ? _formatDate(p.endDate) : '—'}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  // Status badge matching Web
  Widget _buildStatusDropdown(String status) {
    Color bg;
    Color text;
    String label;
    switch (status.toLowerCase()) {
      case 'cancelled':
      case 'canceled':
      case 'da_huy':
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'ĐÃ HUỶ';
        break;
      case 'completed':
      case 'done':
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF047857);
        label = 'HOÀN THÀNH';
        break;
      case 'active':
      case 'deploying':
      case 'in_progress':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        label = 'ĐANG CHẠY';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = 'KHỞI TẠO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: text),
          ),
        ],
      ),
    );
  }

  // Member Avatars Stack & "Thành viên" Button
  Widget _buildMembersStackButton(int count) {
    final displayMembers = _members.take(3).toList();
    return InkWell(
      onTap: _showMembersBottomSheet,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          // Overlapping Avatars
          SizedBox(
            height: 28,
            width: (displayMembers.length * 20.0 + 8.0).clamp(28.0, 78.0),
            child: Stack(
              children: [
                for (int i = 0; i < displayMembers.length; i++)
                  Positioned(
                    left: i * 18.0,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 11.5,
                        backgroundColor: _getMemberColor(i),
                        child: Text(
                          _getInitials(displayMembers[i].fullName ?? 'U'),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // "Thành viên" Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline, size: 14, color: Color(0xFF475569)),
                const SizedBox(width: 4),
                Text(
                  'Thành viên',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getMemberColor(int index) {
    const colors = [
      Color(0xFFEAB308), // Yellow
      Color(0xFF3B82F6), // Blue
      Color(0xFF10B981), // Green
      Color(0xFF8B5CF6), // Purple
      Color(0xFFEC4899), // Pink
    ];
    return colors[index % colors.length];
  }

  // Horizontal Tabs Bar matching Web 1:1
  Widget _buildTabsBar() {
    final totalTasks = _tasks.isNotEmpty ? _tasks.length : _project.totalItems;
    final tabs = [
      {'title': 'Công việc ($totalTasks)', 'index': 0},
      {'title': 'Trao đổi', 'index': 6},
      {'title': 'Lịch', 'index': 1},
      {'title': 'Tài liệu', 'index': 2},
      {'title': 'Tài chính', 'index': 3},
      {'title': 'Đơn từ', 'index': 4},
      {'title': 'Hoạt động', 'index': 5},
    ];

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: tabs.map((tab) {
            final idx = tab['index'] as int;
            final isSelected = _selectedTabIndex == idx;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = idx),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFACC15) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFEAB308) : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    tab['title'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Active Tab Content
  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildTasksTabView();
      case 1:
        return _buildCalendarTabView();
      case 2:
        return _buildDocumentsTabView();
      case 3:
        return _buildFinancialTabView();
      case 4:
        return _buildRequestsTabView();
      case 5:
        return _buildActivityTabView();
      case 6:
        return WorkspaceTabChatsView(
          projectId: _project.id,
          service: widget.service,
        );
      default:
        return _buildTasksTabView();
    }
  }

  // Tab 0: Công việc View (Matching Web 1:1)
  Widget _buildTasksTabView() {
    // Filter tasks
    final filtered = _tasks.where((t) {
      if (_statusFilter != 'ALL' && t.status != _statusFilter) return false;
      if (_priorityFilter != 'ALL' && t.priority != _priorityFilter) return false;
      if (_assigneeFilter != 'ALL' && t.assigneeUserId != _assigneeFilter) return false;
      return true;
    }).toList();

    // Sort tasks
    filtered.sort((a, b) {
      if (_sortOrder == 'dueDate') {
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      } else if (_sortOrder == 'priority') {
        return _getPriorityWeight(b.priority).compareTo(_getPriorityWeight(a.priority));
      } else if (_sortOrder == 'title') {
        return a.title.compareTo(b.title);
      }
      // default: WBS / code / id
      return a.code.compareTo(b.code);
    });

    return Column(
      children: [
        // View modes & "+ Thêm công việc" action bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              // Segment Bảng | Kanban | Gantt
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildViewModePill('Bảng', _viewMode == 'table', () => setState(() => _viewMode = 'table')),
                    _buildViewModePill('Kanban', _viewMode == 'kanban', () => setState(() => _viewMode = 'kanban')),
                    _buildViewModePill('Gantt', _viewMode == 'gantt', () => setState(() => _viewMode = 'gantt')),
                  ],
                ),
              ),

              // Nút xem toàn màn hình nằm ngang
              Tooltip(
                message: 'Xem toàn màn hình nằm ngang',
                child: InkWell(
                  onTap: _openLandscapeFullscreen,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Icon(Icons.screen_rotation, size: 16, color: Color(0xFF334155)),
                  ),
                ),
              ),
              const Spacer(),

              // + Thêm công việc Button matching Web
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tính năng thêm công việc đang được cập nhật')),
                  );
                },
                icon: const Icon(Icons.add, size: 14, color: Color(0xFF0F172A)),
                label: const Text(
                  'Thêm công việc',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFACC15),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Filter Bar (Trạng thái, Ưu tiên, Người thực hiện, Sắp xếp)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              // Trạng thái Filter
              _buildDropdownFilter(
                label: 'Trạng thái: ${_getStatusFilterLabel(_statusFilter)}',
                items: [
                  {'id': 'ALL', 'label': 'Tất cả trạng thái'},
                  {'id': 'todo', 'label': 'Chưa làm'},
                  {'id': 'in_progress', 'label': 'Đang làm'},
                  {'id': 'blocked', 'label': 'Vướng mắc'},
                  {'id': 'review', 'label': 'Chờ duyệt'},
                  {'id': 'done', 'label': 'Đã xong'},
                  {'id': 'cancelled', 'label': 'Đã huỷ'},
                ],
                onSelected: (val) => setState(() => _statusFilter = val),
              ),
              const SizedBox(width: 6),

              // Ưu tiên Filter
              _buildDropdownFilter(
                label: 'Ưu tiên: ${_getPriorityFilterLabel(_priorityFilter)}',
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

              // Người thực hiện Filter
              _buildDropdownFilter(
                label: 'Người thực hiện: ${_getAssigneeFilterLabel(_assigneeFilter)}',
                items: [
                  {'id': 'ALL', 'label': 'Tất cả người thực hiện'},
                  ..._getUniqueAssignees().map((a) => {'id': a['id']!, 'label': a['name']!}),
                ],
                onSelected: (val) => setState(() => _assigneeFilter = val),
              ),
              const SizedBox(width: 6),

              // Sắp xếp
              _buildDropdownFilter(
                label: 'Sắp xếp: ${_getSortFilterLabel(_sortOrder)}',
                items: [
                  {'id': 'wbs', 'label': 'Thứ tự WBS'},
                  {'id': 'dueDate', 'label': 'Thời hạn'},
                  {'id': 'priority', 'label': 'Mức độ ưu tiên'},
                  {'id': 'title', 'label': 'Tên công việc'},
                ],
                onSelected: (val) => setState(() => _sortOrder = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Tasks List / Kanban / Gantt
        Expanded(
          child: _isLoadingTasks
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment_outlined, size: 44, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 8),
                          const Text(
                            'Chưa có công việc nào trong dự án này',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : _viewMode == 'kanban'
                      ? WorkspaceProjectKanbanView(
                          tasks: filtered,
                          service: widget.service,
                          onRefresh: _loadWorkItems,
                        )
                      : _viewMode == 'gantt'
                          ? WorkspaceProjectGanttView(
                              tasks: filtered,
                              service: widget.service,
                              onRefresh: _loadWorkItems,
                            )
                          : RefreshIndicator(
                              color: const Color(0xFFEAB308),
                              onRefresh: _loadWorkItems,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (ctx, idx) {
                                  final task = filtered[idx];
                                  return _buildTaskCard(task, idx + 1);
                                },
                              ),
                            ),
        ),
      ],
    );
  }

  // Work Item Card matching Web Table Row
  Widget _buildTaskCard(StandaloneTaskItem task, int index) {
    final assigneeName = task.assigneeName != null && task.assigneeName!.isNotEmpty
        ? task.assigneeName!
        : (task.assigneeUserId.isNotEmpty ? UserResolver.resolveName(task.assigneeUserId) : 'Chưa giao');

    return InkWell(
      onTap: () {
        showWorkspaceTaskStatusSheet(
          context,
          task: task,
          service: widget.service,
          onStatusChanged: _loadWorkItems,
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Index & Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$index',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Assignee + Priority + Status Chips
            Row(
              children: [
                // Assignee avatar + name
                CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFFEAB308),
                  child: Text(
                    _getInitials(assigneeName),
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    assigneeName,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Priority Chip
                _buildPriorityChip(task.priority),
                const SizedBox(width: 6),

                // Status Chip
                _buildTaskStatusChip(task.status),
              ],
            ),
            const SizedBox(height: 8),

            // Row 3: Dates & Progress Bar
            Row(
              children: [
                const Icon(Icons.date_range_outlined, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  '${_formatDate(task.plannedStart)} — ${_formatDate(task.dueDate)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const Spacer(),

                // Progress Bar - Đồng bộ chuẩn với Kanban: Nếu Đã huỷ thì không hiển thị 100% xanh lá
                if (task.status == 'cancelled' || task.status == 'canceled' || task.status == 'da_huy')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Đã huỷ',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  )
                else ...[
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (task.progressPercent / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          task.status == 'done' || task.status == 'completed' || task.progressPercent >= 100
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${task.progressPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: task.status == 'done' || task.status == 'completed' || task.progressPercent >= 100
                          ? const Color(0xFF047857)
                          : const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Priority Chip
  Widget _buildPriorityChip(String p) {
    Color bg;
    Color text;
    String label;
    switch (p.toLowerCase()) {
      case 'urgent':
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFDC2626);
        label = 'Khẩn cấp';
        break;
      case 'high':
        bg = const Color(0xFFFFF7ED);
        text = const Color(0xFFEA580C);
        label = 'Cao';
        break;
      case 'low':
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'Thấp';
        break;
      case 'normal':
      default:
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF2563EB);
        label = 'Bình thường';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: text.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text)),
    );
  }

  // Task Status Chip matching Web
  Widget _buildTaskStatusChip(String status) {
    Color bg;
    Color text;
    String label;
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF047857);
        label = 'Đã xong';
        break;
      case 'blocked':
      case 'stuck':
      case 'vuong_mac':
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFDC2626);
        label = 'Vướng mắc';
        break;
      case 'cancelled':
      case 'canceled':
      case 'da_huy':
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'Đã huỷ';
        break;
      case 'review':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = 'Chờ duyệt';
        break;
      case 'in_progress':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        label = 'Đang làm';
        break;
      case 'todo':
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        label = 'Chưa làm';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: text.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text)),
    );
  }

  // Other Tabs placeholders with clear Web sync
  Widget _buildCalendarTabView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month_outlined, size: 40, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text(
            'Lịch làm việc dự án ${_project.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Bắt đầu: ${_formatFullDate(_project.startDate)} · Hạn chót: ${_formatFullDate(_project.endDate)}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTabView() {
    return WorkspaceDocumentsView(
      projects: [_project],
      initialProjectId: _project.id,
      onRefresh: _loadWorkItems,
    );
  }

  Widget _buildFinancialTabView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.attach_money_rounded, size: 40, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          const Text(
            'Thông tin tài chính & Hợp đồng dự án',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Nhóm: ${_project.typeLabel} · Mã: ${_project.code}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTabView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description_outlined, size: 40, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          const Text(
            'Chưa có đơn từ nào liên kết với dự án',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTabView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded, size: 40, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          const Text(
            'Nhật ký hoạt động dự án',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cập nhật trạng thái và phân công gần đây',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  // Members Sheet Dialog (opens when tapping [Thành viên])
  void _showMembersBottomSheet() {
    showWorkspaceProjectMembersSheet(
      context,
      project: _project,
      service: widget.service,
      initialMembers: _members,
      projectTasks: _tasks,
      onMembersUpdated: _loadMembers,
    );
  }

  // Helpers
  Widget _buildViewModePill(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  String _getStatusFilterLabel(String s) {
    switch (s) {
      case 'todo':
        return 'Chưa làm';
      case 'in_progress':
        return 'Đang làm';
      case 'blocked':
        return 'Vướng mắc';
      case 'review':
        return 'Chờ duyệt';
      case 'done':
        return 'Đã xong';
      case 'cancelled':
        return 'Đã huỷ';
      default:
        return 'Tất cả';
    }
  }

  String _getPriorityFilterLabel(String p) {
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

  String _getSortFilterLabel(String o) {
    switch (o) {
      case 'dueDate':
        return 'Thời hạn';
      case 'priority':
        return 'Mức độ ưu tiên';
      case 'title':
        return 'Tên việc';
      default:
        return 'Thứ tự WBS';
    }
  }

  List<Map<String, String>> _getUniqueAssignees() {
    final Map<String, String> assignees = {};
    for (final t in _tasks) {
      if (t.assigneeUserId.isNotEmpty) {
        final name = t.assigneeName != null && t.assigneeName!.isNotEmpty
            ? t.assigneeName!
            : UserResolver.resolveName(t.assigneeUserId);
        assignees[t.assigneeUserId] = name;
      }
    }
    return assignees.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  String _getAssigneeFilterLabel(String id) {
    if (id == 'ALL') return 'Tất cả';
    return UserResolver.resolveName(id);
  }

  int _getPriorityWeight(String p) {
    switch (p.toLowerCase()) {
      case 'urgent':
        return 4;
      case 'high':
        return 3;
      case 'normal':
        return 2;
      case 'low':
      default:
        return 1;
    }
  }
}
