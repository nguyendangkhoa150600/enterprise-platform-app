import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import 'workspace_project_kanban_view.dart';
import 'workspace_project_gantt_view.dart';
import 'workspace_sheets.dart';

/// Màn hình xem toàn màn hình theo chiều nằm ngang (Landscape Fullscreen)
/// Hỗ trợ trải nghiệm tối đa cho chế độ Kanban và biểu đồ tiến độ Gantt
class WorkspaceLandscapeFullscreenScreen extends StatefulWidget {
  final ProjectItem project;
  final List<StandaloneTaskItem> tasks;
  final String initialViewMode; // 'table' | 'kanban' | 'gantt'
  final WorkspaceService service;
  final VoidCallback onRefresh;

  const WorkspaceLandscapeFullscreenScreen({
    super.key,
    required this.project,
    required this.tasks,
    this.initialViewMode = 'kanban',
    required this.service,
    required this.onRefresh,
  });

  @override
  State<WorkspaceLandscapeFullscreenScreen> createState() => _WorkspaceLandscapeFullscreenScreenState();
}

class _WorkspaceLandscapeFullscreenScreenState extends State<WorkspaceLandscapeFullscreenScreen> {
  late String _viewMode;
  late List<StandaloneTaskItem> _tasks;
  bool _isLoading = false;

  // Filter
  String _statusFilter = 'ALL';
  final String _priorityFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _tasks = List.from(widget.tasks);

    // Khóa hướng màn hình nằm ngang khi mở
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Phục hồi lại hướng dọc khi đóng
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  Future<void> _reloadTasks() async {
    setState(() => _isLoading = true);
    try {
      final items = await widget.service.getProjectWorkItems(widget.project.id);
      if (mounted) {
        setState(() {
          _tasks = items;
          _isLoading = false;
        });
      }
      widget.onRefresh();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _exitFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    Navigator.of(context).pop();
  }

  List<StandaloneTaskItem> _getFilteredTasks() {
    return _tasks.where((t) {
      if (_statusFilter != 'ALL' && t.status != _statusFilter) return false;
      if (_priorityFilter != 'ALL' && t.priority != _priorityFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredTasks();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Luôn khôi phục chiều dọc khi người dùng nhấn nút Back hệ thống
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Thanh điều hướng trên cùng nằm ngang (Compact Navigation Bar)
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    // Nút thu nhỏ / Thoát nằm ngang
                    InkWell(
                      onTap: _exitFullscreen,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen_exit, size: 18, color: Color(0xFF334155)),
                            SizedBox(width: 4),
                            Text(
                              'Thu nhỏ',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Tên dự án
                    Expanded(
                      child: Text(
                        widget.project.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Segment chuyển chế độ xem: Bảng | Kanban | Gantt
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeTab('Bảng', _viewMode == 'table', () => setState(() => _viewMode = 'table')),
                          _buildModeTab('Kanban', _viewMode == 'kanban', () => setState(() => _viewMode = 'kanban')),
                          _buildModeTab('Gantt', _viewMode == 'gantt', () => setState(() => _viewMode = 'gantt')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Filter Trạng thái nhanh
                    PopupMenuButton<String>(
                      onSelected: (val) => setState(() => _statusFilter = val),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'ALL', child: Text('Tất cả trạng thái', style: TextStyle(fontSize: 12))),
                        const PopupMenuItem(value: 'todo', child: Text('Chưa làm', style: TextStyle(fontSize: 12))),
                        const PopupMenuItem(value: 'in_progress', child: Text('Đang làm', style: TextStyle(fontSize: 12))),
                        const PopupMenuItem(value: 'blocked', child: Text('Vướng mắc', style: TextStyle(fontSize: 12))),
                        const PopupMenuItem(value: 'review', child: Text('Chờ duyệt', style: TextStyle(fontSize: 12))),
                        const PopupMenuItem(value: 'done', child: Text('Hoàn thành', style: TextStyle(fontSize: 12))),
                        const PopupMenuItem(value: 'cancelled', child: Text('Đã huỷ', style: TextStyle(fontSize: 12))),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _statusFilter == 'ALL' ? 'Lọc' : _getStatusLabel(_statusFilter),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Nút Reload
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF64748B)),
                      onPressed: _reloadTasks,
                      tooltip: 'Tải lại',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Nội dung hiển thị toàn màn hình theo chế độ đã chọn
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
                    : _viewMode == 'kanban'
                        ? WorkspaceProjectKanbanView(
                            tasks: filtered,
                            service: widget.service,
                            onRefresh: _reloadTasks,
                          )
                        : _viewMode == 'gantt'
                            ? WorkspaceProjectGanttView(
                                tasks: filtered,
                                service: widget.service,
                                onRefresh: _reloadTasks,
                              )
                            : _buildTableView(filtered),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
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

  Widget _buildTableView(List<StandaloneTaskItem> filtered) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Chưa có công việc nào', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (ctx, idx) {
        final task = filtered[idx];
        final isCancelled = task.status == 'cancelled' || task.status == 'canceled' || task.status == 'da_huy';
        final isDone = task.status == 'done' || task.status == 'completed';

        return InkWell(
          onTap: () {
            showWorkspaceTaskStatusSheet(
              context,
              task: task,
              service: widget.service,
              onStatusChanged: _reloadTasks,
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${idx + 1}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isCancelled ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildLandscapePriorityChip(task.priority),
                const SizedBox(width: 8),
                _buildLandscapeStatusChip(task.status),
                const SizedBox(width: 14),
                if (isCancelled)
                  const Text('Đã huỷ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))
                else
                  Text(
                    '${task.progressPercent.toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDone || task.progressPercent >= 100 ? const Color(0xFF047857) : const Color(0xFF3B82F6),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLandscapePriorityChip(String p) {
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: text)),
    );
  }

  Widget _buildLandscapeStatusChip(String status) {
    Color bg;
    Color text;
    String label;
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF047857);
        label = 'Hoàn thành';
        break;
      case 'blocked':
      case 'stuck':
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFDC2626);
        label = 'Vướng mắc';
        break;
      case 'review':
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFD97706);
        label = 'Chờ duyệt';
        break;
      case 'in_progress':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        label = 'Đang làm';
        break;
      case 'cancelled':
      case 'canceled':
      case 'da_huy':
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'Đã huỷ';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        label = 'Chưa làm';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: text)),
    );
  }

  String _getStatusLabel(String s) {
    switch (s) {
      case 'todo': return 'Chưa làm';
      case 'in_progress': return 'Đang làm';
      case 'blocked': return 'Vướng mắc';
      case 'review': return 'Chờ duyệt';
      case 'done': return 'Đã xong';
      case 'cancelled': return 'Đã huỷ';
      default: return 'Tất cả';
    }
  }
}
