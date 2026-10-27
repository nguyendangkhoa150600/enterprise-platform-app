import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../models/workspace_models.dart';
import '../../controllers/workspace_controller.dart';

class WorkspaceProjectsTabView extends StatelessWidget {
  final WorkspaceController controller;
  final ValueChanged<ProjectItem> onProjectTap;

  const WorkspaceProjectsTabView({
    super.key,
    required this.controller,
    required this.onProjectTap,
  });

  @override
  Widget build(BuildContext context) {
    final projects = controller.projects;
    final filtered = projects.where((p) {
      if (controller.projectSearch.isNotEmpty) {
        final q = controller.projectSearch.toLowerCase();
        if (!p.name.toLowerCase().contains(q) && !p.code.toLowerCase().contains(q)) return false;
      }
      if (controller.projectStatusFilter != 'ALL' && p.status != controller.projectStatusFilter) return false;
      return true;
    }).toList();

    final total = projects.length;
    final activeCount = projects.where((p) => p.status == 'active').length;
    final completedCount = projects.where((p) => p.status == 'completed').length;
    final overdueCount = projects.where((p) => p.overdueItems > 0).length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
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
            onChanged: controller.setProjectSearch,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'workspace.project.search_hint'.tr(),
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Status filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                selected: controller.projectStatusFilter == 'ALL',
                label: 'workspace.filter.all_count'.tr(args: {'count': total}),
                onTap: () => controller.setProjectStatusFilter('ALL'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: controller.projectStatusFilter == 'active',
                label: 'workspace.filter.active_count'.tr(args: {'count': activeCount}),
                onTap: () => controller.setProjectStatusFilter('active'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                selected: controller.projectStatusFilter == 'completed',
                label: 'workspace.filter.completed_count'.tr(args: {'count': completedCount}),
                onTap: () => controller.setProjectStatusFilter('completed'),
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
                const Icon(Icons.folder_off_outlined, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text('workspace.project.empty'.tr(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
        onTap: () => onProjectTap(project),
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
              Text(
                project.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (project.customerName != null && project.customerName!.isNotEmpty) ...[
                const SizedBox(height: 4),
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
              ],
              const SizedBox(height: 10),
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
}
