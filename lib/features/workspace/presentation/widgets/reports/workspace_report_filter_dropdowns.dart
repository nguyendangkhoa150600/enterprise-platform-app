import 'package:flutter/material.dart';
import '../../../../../models/workspace_models.dart';
import '../../../domain/models/workspace_report_models.dart';
import '../searchable_dropdown_field.dart';

/// Hàng lọc dự án, nhóm dự án, nhãn và nhân sự cho báo cáo
/// Đồng bộ 1:1 với Web React (Tất cả dự án | Mọi nhóm DA | Mọi nhãn | Mọi người)
class WorkspaceReportFilterDropdowns extends StatelessWidget {
  final List<ProjectItem> projects;
  final List<String> groups;
  final List<TagItem> tags;
  final List<Map<String, String>> users;

  final String? selectedProjectId;
  final String? selectedGroup;
  final String? selectedTagId;
  final String? selectedUserId;

  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String?> onUserChanged;

  const WorkspaceReportFilterDropdowns({
    super.key,
    required this.projects,
    required this.groups,
    required this.tags,
    required this.users,
    required this.selectedProjectId,
    required this.selectedGroup,
    required this.selectedTagId,
    required this.selectedUserId,
    required this.onProjectChanged,
    required this.onGroupChanged,
    required this.onTagChanged,
    required this.onUserChanged,
  });

  @override
  Widget build(BuildContext context) {
    ProjectItem? currentProject;
    if (selectedProjectId != null) {
      for (final p in projects) {
        if (p.id == selectedProjectId) {
          currentProject = p;
          break;
        }
      }
    }

    TagItem? currentTag;
    if (selectedTagId != null) {
      for (final t in tags) {
        if (t.id == selectedTagId) {
          currentTag = t;
          break;
        }
      }
    }

    Map<String, String>? currentUser;
    if (selectedUserId != null) {
      for (final u in users) {
        if (u['id'] == selectedUserId) {
          currentUser = u;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          // Row 1: Dự án & Nhóm
          Row(
            children: [
              // Chọn dự án
              Expanded(
                child: SearchableDropdownField<ProjectItem>(
                  value: currentProject,
                  items: projects,
                  hintText: 'Tất cả dự án',
                  icon: Icons.business_center_outlined,
                  itemLabel: (p) => '${p.code} · ${p.name}',
                  itemSubtitle: (p) => (p.customerName != null && p.customerName!.isNotEmpty) ? p.customerName : null,
                  onChanged: (p) => onProjectChanged(p.id),
                  onClear: () => onProjectChanged(null),
                  showClear: selectedProjectId != null,
                ),
              ),
              const SizedBox(width: 8),
              // Chọn nhóm dự án
              Expanded(
                child: SearchableDropdownField<String>(
                  value: selectedGroup,
                  items: ['__none__', ...groups],
                  hintText: 'Mọi nhóm dự án',
                  icon: Icons.folder_special_outlined,
                  itemLabel: (g) => g == '__none__' ? 'Chưa phân nhóm' : g,
                  onChanged: onGroupChanged,
                  onClear: () => onGroupChanged(null),
                  showClear: selectedGroup != null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Nhãn & Người phụ trách
          Row(
            children: [
              // Chọn nhãn
              Expanded(
                child: SearchableDropdownField<TagItem>(
                  value: currentTag,
                  items: tags,
                  hintText: 'Mọi nhãn',
                  icon: Icons.label_outline,
                  itemLabel: (t) => t.name,
                  onChanged: (t) => onTagChanged(t.id),
                  onClear: () => onTagChanged(null),
                  showClear: selectedTagId != null,
                ),
              ),
              const SizedBox(width: 8),
              // Chọn người phụ trách
              Expanded(
                child: SearchableDropdownField<Map<String, String>>(
                  value: currentUser,
                  items: users,
                  hintText: 'Mọi người',
                  icon: Icons.person_outline,
                  itemLabel: (u) => u['name'] ?? u['id'] ?? '',
                  itemSubtitle: (u) => u['position'],
                  onChanged: (u) => onUserChanged(u['id']),
                  onClear: () => onUserChanged(null),
                  showClear: selectedUserId != null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
