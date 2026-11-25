import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/domain/models/workspace_report_models.dart' show TagItem;
import '../../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import '../workspace_project_gantt_view.dart';
import '../workspace_project_kanban_view.dart';
import 'project_work_filters.dart';
import 'project_work_model.dart';
import 'project_work_tree.dart';

/// Tab Công việc của dự án (web tab-work.tsx): thanh công cụ (Bảng | Kanban | Gantt, Bộ lọc,
/// Hiện việc con, "N / M việc", Thêm công việc) và nội dung theo kiểu xem.
/// Bộ lọc và kiểu xem do trang cha giữ để mang sang màn ngang toàn màn hình.
class ProjectWorkTab extends StatefulWidget {
  final ProjectItem project;
  final List<StandaloneTaskItem> items;
  final Map<String, TagItem> tags;
  final WorkspaceService service;
  final String view; // 'table' | 'kanban' | 'gantt'
  final WorkFilter filter;
  final String? currentUserId;
  final bool loading;
  final bool loadFailed;
  final ValueChanged<String> onViewChanged;
  final ValueChanged<WorkFilter> onFilterChanged;
  final ValueChanged<StandaloneTaskItem> onOpenItem;
  final VoidCallback onAddRoot;
  final VoidCallback onOpenLandscape;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  const ProjectWorkTab({
    super.key,
    required this.project,
    required this.items,
    required this.tags,
    required this.service,
    required this.view,
    required this.filter,
    required this.currentUserId,
    required this.loading,
    required this.loadFailed,
    required this.onViewChanged,
    required this.onFilterChanged,
    required this.onOpenItem,
    required this.onAddRoot,
    required this.onOpenLandscape,
    required this.onRefresh,
    required this.onRetry,
  });

  @override
  State<ProjectWorkTab> createState() => _ProjectWorkTabState();
}

class _ProjectWorkTabState extends State<ProjectWorkTab> {
  final Set<String> _collapsed = {};

  void _toggle(WorkTreeRow row) {
    final id = row.item.id;
    if (widget.filter.showChildren) {
      setState(() => _collapsed.contains(id) ? _collapsed.remove(id) : _collapsed.add(id));
    } else {
      // Đang tắt "Hiện việc con": bật lại và mở đúng nhánh này.
      setState(() => _collapsed.remove(id));
      widget.onFilterChanged(widget.filter.copyWith(showChildren: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.project.access;
    final filter = widget.filter;
    final items = widget.items;
    final matched = matchWorkItems(items, filter, widget.currentUserId);
    final count = filter.filtering
        ? 'workspace.work_tab.count_filtered'.tr(args: {'matched': '${matched.length}', 'total': '${items.length}'})
        : 'workspace.work_tab.count'.tr(args: {'total': '${items.length}'});

    return Column(
      children: [
        _toolbar(access, count),
        Expanded(child: _content(access, matched)),
      ],
    );
  }

  Widget _toolbar(ProjectAccess access, String count) {
    final filter = widget.filter;
    final active = filter.facets > 0 || filter.sorted;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        children: [
          Row(
            children: [
              _segmented(),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'workspace.work_tab.landscape'.tr(),
                onPressed: widget.onOpenLandscape,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.screen_rotation, size: 18, color: Color(0xFF334155)),
              ),
              const Spacer(),
              // Không có quyền ghi (người xem, dự án lưu trữ) thì ẩn hẳn nút.
              if (access.canWrite)
                ElevatedButton.icon(
                  onPressed: widget.onAddRoot,
                  icon: const Icon(Icons.add, size: 15, color: Color(0xFF0F172A)),
                  label: Text('workspace.work_tab.add_item'.tr(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFACC15),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => showProjectWorkFilterSheet(
                  context,
                  filter: filter,
                  items: widget.items,
                  tags: widget.tags,
                  projectId: widget.project.id,
                  currentUserId: widget.currentUserId,
                  onChanged: widget.onFilterChanged,
                ),
                icon: const Icon(Icons.filter_list, size: 15),
                label: Text(
                  filter.facets > 0 ? '${'common.filter'.tr()} (${filter.facets})' : 'common.filter'.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: active ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                  side: BorderSide(color: active ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1)),
                ),
              ),
              if (widget.view == 'table') ...[
                const SizedBox(width: 4),
                Checkbox(
                  value: filter.showChildren,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => widget.onFilterChanged(filter.copyWith(showChildren: v ?? true)),
                ),
                Text('workspace.work_tab.show_children'.tr(), style: const TextStyle(fontSize: 12)),
              ],
              const Spacer(),
              Text(count, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segmented() {
    const views = ['table', 'kanban', 'gantt'];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in views)
            InkWell(
              onTap: () => widget.onViewChanged(v),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.view == v ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'workspace.work_tab.view_$v'.tr(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: widget.view == v ? FontWeight.bold : FontWeight.w500,
                    color: widget.view == v ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(ProjectAccess access, List<StandaloneTaskItem> matched) {
    if (widget.loading && widget.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)));
    }
    if (widget.loadFailed && widget.items.isEmpty) {
      return _message('workspace.project_detail.load_failed'.tr(), Icons.cloud_off_outlined, retry: true);
    }
    switch (widget.view) {
      case 'kanban':
        return WorkspaceProjectKanbanView(
          tasks: matched,
          service: widget.service,
          onRefresh: widget.onRefresh,
          access: access,
        );
      case 'gantt':
        return WorkspaceProjectGanttView(
          tasks: matched,
          allTasks: widget.items,
          service: widget.service,
          onRefresh: widget.onRefresh,
          access: access,
          onOpenTask: widget.onOpenItem,
          sort: widget.filter.sort,
          ascending: widget.filter.ascending,
        );
      default:
        final rows = workTableRows(widget.items, matched, widget.filter, _collapsed);
        if (rows.isEmpty) {
          return _message(
            widget.filter.filtering
                ? 'workspace.project_detail.no_items_filtered'.tr()
                : 'workspace.project_detail.no_items'.tr(),
            Icons.assignment_outlined,
          );
        }
        return Column(
          children: [
            Expanded(
              child: ProjectWorkTree(
                rows: rows,
                tags: widget.tags,
                onOpen: widget.onOpenItem,
                onToggle: _toggle,
                onRefresh: widget.onRefresh,
              ),
            ),
            if (access.canWrite)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onAddRoot,
                  icon: const Icon(Icons.add, size: 15),
                  label: Text('workspace.work_tab.add_group'.tr(), style: const TextStyle(fontSize: 12.5)),
                ),
              ),
          ],
        );
    }
  }

  Widget _message(String text, IconData icon, {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          if (retry) TextButton(onPressed: widget.onRetry, child: Text('common.retry'.tr())),
          if (!retry && widget.project.access.canWrite && widget.view == 'table')
            TextButton.icon(
              onPressed: widget.onAddRoot,
              icon: const Icon(Icons.add, size: 15),
              label: Text('workspace.work_tab.add_group'.tr()),
            ),
        ],
      ),
    );
  }
}
