import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../models/workspace_models.dart';
import '../../controllers/workspace_controller.dart';

class WorkspaceOtherTasksTabView extends StatelessWidget {
  final WorkspaceController controller;
  final ValueChanged<StandaloneTaskItem> onTaskTap;

  const WorkspaceOtherTasksTabView({
    super.key,
    required this.controller,
    required this.onTaskTap,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tasks = controller.tasks;
    final filtered = tasks.where((t) {
      if (controller.taskSearch.isNotEmpty) {
        final q = controller.taskSearch.toLowerCase();
        if (!t.title.toLowerCase().contains(q) && !t.code.toLowerCase().contains(q)) return false;
      }
      if (controller.taskStatusFilter != 'ALL' && t.status != controller.taskStatusFilter) return false;
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
            onChanged: controller.setTaskSearch,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'workspace.task.search_hint'.tr(),
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                selected: controller.taskStatusFilter == 'ALL',
                label: 'workspace.filter.all_count'.tr(args: {'count': tasks.length}),
                onTap: () => controller.setTaskStatusFilter('ALL'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: controller.taskStatusFilter == 'todo',
                label: 'workspace.filter.todo_count'.tr(args: {'count': tasks.where((t) => t.status == 'todo').length}),
                onTap: () => controller.setTaskStatusFilter('todo'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: controller.taskStatusFilter == 'in_progress',
                label: 'workspace.filter.in_progress_count'.tr(args: {'count': tasks.where((t) => t.status == 'in_progress').length}),
                onTap: () => controller.setTaskStatusFilter('in_progress'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: controller.taskStatusFilter == 'review',
                label: 'workspace.filter.review_count'.tr(args: {'count': tasks.where((t) => t.status == 'review').length}),
                onTap: () => controller.setTaskStatusFilter('review'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: controller.taskStatusFilter == 'done',
                label: 'workspace.filter.done_count'.tr(args: {'count': tasks.where((t) => t.status == 'done').length}),
                onTap: () => controller.setTaskStatusFilter('done'),
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
                const Icon(Icons.assignment_turned_in_outlined, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text('workspace.task.empty'.tr(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
    final isSelected = controller.taskScope == scopeKey;
    return InkWell(
      onTap: () => controller.setTaskScope(scopeKey),
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
        onTap: () => onTaskTap(task),
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
                  Text('workspace.task.detail'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
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
        child: Text('workspace.task.void'.tr(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
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
}
