import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';

class WorkspaceTabBar extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabSelected;

  const WorkspaceTabBar({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'label': 'workspace.title.my_tasks'.tr(), 'icon': Icons.task_alt},
      {'label': 'workspace.title.adhoc'.tr(), 'icon': Icons.assignment_outlined},
      {'label': 'workspace.title.projects'.tr(), 'icon': Icons.folder_outlined},
      {'label': 'workspace.title.customers'.tr(), 'icon': Icons.business_outlined},
      {'label': 'workspace.title.documents'.tr(), 'icon': Icons.description_outlined},
      {'label': 'workspace.title.reports'.tr(), 'icon': Icons.bar_chart_outlined},
    ];

    return Container(
      height: 46,
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = activeTab == index;
          final item = tabs[index];
          return InkWell(
            onTap: () => onTabSelected(index),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 15,
                    color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
