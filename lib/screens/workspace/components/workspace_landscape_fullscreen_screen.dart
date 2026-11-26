import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/domain/models/workspace_report_models.dart' show TagItem;
import '../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import 'project_detail/project_work_filters.dart';
import 'project_detail/project_work_model.dart';
import 'project_detail/project_work_tree.dart';
import 'workspace_project_kanban_view.dart';
import 'workspace_project_gantt_view.dart';
import 'workspace_standalone_task_detail_sheet.dart';

/// Màn hình xem toàn màn hình nằm ngang của tab Công việc: cùng ba kiểu xem Bảng (cây WBS) / Kanban / Gantt
/// và cùng bộ lọc với tab Công việc (nhận bộ lọc đang áp từ trang dự án).
class WorkspaceLandscapeFullscreenScreen extends StatefulWidget {
  final ProjectItem project;
  final List<StandaloneTaskItem> tasks;
  final String initialViewMode; // 'table' | 'kanban' | 'gantt'
  final WorkspaceService service;
  final VoidCallback onRefresh;

  /// Bộ lọc đang áp ở tab Công việc (mặc định: không lọc).
  final WorkFilter? initialFilter;
  final Map<String, TagItem> tags;
  final String? currentUserId;

  /// Mở chi tiết công việc; vắng thì mở sheet chi tiết mặc định.
  final ValueChanged<StandaloneTaskItem>? onOpenItem;

  const WorkspaceLandscapeFullscreenScreen({
    super.key,
    required this.project,
    required this.tasks,
    this.initialViewMode = 'kanban',
    required this.service,
    required this.onRefresh,
    this.initialFilter,
    this.tags = const {},
    this.currentUserId,
    this.onOpenItem,
  });

  @override
  State<WorkspaceLandscapeFullscreenScreen> createState() => _WorkspaceLandscapeFullscreenScreenState();
}

class _WorkspaceLandscapeFullscreenScreenState extends State<WorkspaceLandscapeFullscreenScreen> {
  late String _viewMode;
  late List<StandaloneTaskItem> _tasks;
  late WorkFilter _filter;
  final Set<String> _collapsed = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _tasks = List.from(widget.tasks);
    _filter = widget.initialFilter ?? WorkFilter.none;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _reloadTasks() async {
    setState(() => _isLoading = true);
    try {
      final items = await widget.service.getProjectWorkItems(widget.project.id);
      if (!mounted) return;
      setState(() {
        _tasks = items;
        _isLoading = false;
      });
      widget.onRefresh();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _exitFullscreen() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Navigator.of(context).pop();
  }

  void _open(StandaloneTaskItem item) {
    if (widget.onOpenItem != null) {
      widget.onOpenItem!(item);
      return;
    }
    showWorkspaceStandaloneTaskDetailSheet(
      context,
      task: item.copyWith(
        projectId: widget.project.id,
        projectCode: widget.project.code,
        projectName: widget.project.name,
      ),
      service: widget.service,
      onRefresh: _reloadTasks,
    );
  }

  void _toggle(WorkTreeRow row) {
    final id = row.item.id;
    setState(() {
      if (_filter.showChildren) {
        _collapsed.contains(id) ? _collapsed.remove(id) : _collapsed.add(id);
      } else {
        _collapsed.remove(id);
        _filter = _filter.copyWith(showChildren: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final matched = matchWorkItems(_tasks, _filter, widget.currentUserId);
    final count = _filter.filtering
        ? 'workspace.work_tab.count_filtered'.tr(args: {'matched': '${matched.length}', 'total': '${_tasks.length}'})
        : 'workspace.work_tab.count'.tr(args: {'total': '${_tasks.length}'});

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'workspace.work_tab.exit_landscape'.tr(),
                      onPressed: _exitFullscreen,
                      icon: const Icon(Icons.fullscreen_exit, size: 20, color: Color(0xFF334155)),
                    ),
                    Expanded(
                      child: Text(
                        widget.project.name,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _segmented(),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => showProjectWorkFilterSheet(
                        context,
                        filter: _filter,
                        items: _tasks,
                        tags: widget.tags,
                        projectId: widget.project.id,
                        currentUserId: widget.currentUserId,
                        onChanged: (f) => setState(() => _filter = f),
                      ),
                      icon: const Icon(Icons.filter_list, size: 15),
                      label: Text(
                        _filter.facets > 0 ? '${'common.filter'.tr()} (${_filter.facets})' : 'common.filter'.tr(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    if (_viewMode == 'table') ...[
                      Checkbox(
                        value: _filter.showChildren,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) => setState(() => _filter = _filter.copyWith(showChildren: v ?? true)),
                      ),
                      Text('workspace.work_tab.show_children'.tr(), style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(width: 8),
                    Text(count, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF64748B)),
                      onPressed: _reloadTasks,
                      tooltip: 'workspace.task_detail.menu.refresh'.tr(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
                    : _content(matched),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<StandaloneTaskItem> matched) {
    switch (_viewMode) {
      case 'kanban':
        return WorkspaceProjectKanbanView(
          tasks: matched,
          service: widget.service,
          onRefresh: _reloadTasks,
          access: widget.project.access,
        );
      case 'gantt':
        return WorkspaceProjectGanttView(
          tasks: matched,
          allTasks: _tasks,
          service: widget.service,
          onRefresh: _reloadTasks,
          access: widget.project.access,
          onOpenTask: _open,
          sort: _filter.sort,
          ascending: _filter.ascending,
        );
      default:
        final rows = workTableRows(_tasks, matched, _filter, _collapsed);
        if (rows.isEmpty) {
          return Center(
            child: Text(
              _filter.filtering
                  ? 'workspace.project_detail.no_items_filtered'.tr()
                  : 'workspace.project_detail.no_items'.tr(),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          );
        }
        return ProjectWorkTree(
          rows: rows,
          tags: widget.tags,
          onOpen: _open,
          onToggle: _toggle,
          onRefresh: _reloadTasks,
        );
    }
  }

  Widget _segmented() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in const ['table', 'kanban', 'gantt'])
            InkWell(
              onTap: () => setState(() => _viewMode = v),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _viewMode == v ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'workspace.work_tab.view_$v'.tr(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _viewMode == v ? FontWeight.bold : FontWeight.w500,
                    color: _viewMode == v ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
