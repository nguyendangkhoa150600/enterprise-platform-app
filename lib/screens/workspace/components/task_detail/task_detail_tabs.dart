import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import 'task_detail_format.dart';
import 'task_detail_info_tab.dart';
import 'workspace_dependencies_panel.dart';
import 'workspace_external_links_panel.dart';
import 'workspace_linked_documents_panel.dart';
import 'workspace_progress_panel.dart';

/// Các tab phụ của công việc (web `overview-tabs.ts`).
enum TaskOverviewTab { detail, progress, dependencies, documents }

/// Nhớ tab đang mở của đúng một công việc (web `parseStoredTab`/`rememberTab`, ở đây giữ trong bộ nhớ).
class TaskTabMemory {
  static String? _stored;

  static TaskOverviewTab restore(String itemId) {
    final parts = (_stored ?? '').split('|');
    if (parts.length == 2 && parts[0] == itemId) {
      for (final t in TaskOverviewTab.values) {
        if (t.name == parts[1]) return t;
      }
    }
    return TaskOverviewTab.detail;
  }

  static void remember(String itemId, TaskOverviewTab tab) => _stored = '$itemId|${tab.name}';

}

class TaskTabSpec {
  final TaskOverviewTab id;
  final String label;
  /// Số đếm cạnh tên tab; null là chưa biết (không hiện).
  final int? count;
  /// Giữ dựng khi tab khác đang mở (để số đếm có ngay) — web `keepMounted`.
  final bool keepMounted;
  final WidgetBuilder builder;

  const TaskTabSpec({
    required this.id,
    required this.label,
    this.count,
    this.keepMounted = false,
    required this.builder,
  });
}

/// Hàng tab + thân tab. Tab `keepMounted` vẫn dựng nhưng ẩn (Offstage) khi không được chọn.
class TaskDetailTabs extends StatelessWidget {
  final List<TaskTabSpec> tabs;
  final TaskOverviewTab selected;
  final ValueChanged<TaskOverviewTab> onSelect;

  const TaskDetailTabs({super.key, required this.tabs, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in tabs)
                  InkWell(
                    onTap: () => onSelect(t.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: t.id == selected ? const Color(0xFFEAB308) : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: t.id == selected ? FontWeight.bold : FontWeight.w500,
                              color: t.id == selected ? kTaskInk : kTaskMuted,
                            ),
                          ),
                          if (t.count != null) ...[
                            const SizedBox(width: 5),
                            Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('${t.count}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTaskMuted)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in tabs)
                  if (t.keepMounted)
                    Offstage(
                      key: ValueKey(t.id),
                      offstage: t.id != selected,
                      child: Builder(builder: t.builder),
                    )
                  else if (t.id == selected)
                    KeyedSubtree(key: ValueKey(t.id), child: Builder(builder: t.builder)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Các tab phụ của việc dự án (web `tab-overview.tsx` khi có `selected`):
/// Chi tiết (kèm Hồ sơ liên kết và các bước quy trình khi có) | Lịch sử tiến độ | Phụ thuộc (số) | Tài liệu (số).
class ProjectTaskTabs extends StatelessWidget {
  final StandaloneTaskItem item;
  final List<StandaloneTaskItem> projectItems;
  final WorkspaceService service;
  final TaskOverviewTab selected;
  final ValueChanged<TaskOverviewTab> onSelect;
  final int linkCount;
  final int? dependencyCount;
  final int? documentCount;
  final ValueChanged<int> onDependencyCount;
  final ValueChanged<int> onDocumentCount;
  final bool canWrite;
  final bool canManage;
  final bool canDelete;
  final VoidCallback onChanged;
  final ValueChanged<String> onOpenItem;
  final VoidCallback onReportQuantity;

  const ProjectTaskTabs({
    super.key,
    required this.item,
    required this.projectItems,
    required this.service,
    required this.selected,
    required this.onSelect,
    required this.linkCount,
    required this.dependencyCount,
    required this.documentCount,
    required this.onDependencyCount,
    required this.onDocumentCount,
    required this.canWrite,
    required this.canManage,
    required this.canDelete,
    required this.onChanged,
    required this.onOpenItem,
    required this.onReportQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final t = item;
    final hasLinks = linkCount > 0;
    final canEditProgress = canWrite && !t.isReversed;
    String k(String s) => 'workspace.task_detail.tab.$s'.tr();
    return TaskDetailTabs(
      selected: selected,
      onSelect: (tab) {
        TaskTabMemory.remember(t.id, tab);
        onSelect(tab);
      },
      tabs: [
        TaskTabSpec(
          id: TaskOverviewTab.detail,
          label: k('detail'),
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskDetailInfoTab(item: t, onReportQuantity: canEditProgress ? onReportQuantity : null),
              // Web: hồ sơ liên kết và các bước quy trình nằm ngay trong tab Chi tiết, dưới thông tin của việc.
              if (hasLinks) ...[
                const SizedBox(height: 16),
                WorkspaceExternalLinksPanel(
                  key: ValueKey('links-${t.id}'),
                  item: t,
                  service: service,
                  canWrite: canWrite,
                  onChanged: onChanged,
                ),
              ],
            ],
          ),
        ),
        TaskTabSpec(
          id: TaskOverviewTab.progress,
          label: k('progress'),
          builder: (_) => WorkspaceProgressPanel(
            key: ValueKey('progress-${t.id}'),
            item: t,
            service: service,
            canReport: canEditProgress,
            onChanged: onChanged,
          ),
        ),
        TaskTabSpec(
          id: TaskOverviewTab.dependencies,
          label: k('dependencies'),
          count: dependencyCount,
          keepMounted: true,
          builder: (_) => WorkspaceDependenciesPanel(
            key: ValueKey('deps-${t.id}'),
            item: t,
            service: service,
            projectItems: projectItems,
            canManage: canManage && !t.isReversed,
            onChanged: onChanged,
            onOpenItem: onOpenItem,
            onCount: onDependencyCount,
          ),
        ),
        TaskTabSpec(
          id: TaskOverviewTab.documents,
          label: k('documents'),
          count: documentCount,
          keepMounted: true,
          builder: (_) => WorkspaceLinkedDocumentsPanel(
            key: ValueKey('docs-${t.id}'),
            projectId: t.projectId!,
            workItemId: t.id,
            service: service,
            canWrite: canWrite,
            canDelete: canDelete,
            projectItems: projectItems,
            onCount: onDocumentCount,
          ),
        ),
      ],
    );
  }
}
