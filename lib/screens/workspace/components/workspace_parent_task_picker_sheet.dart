import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../../models/workspace_models.dart';

/// Một mục chọn "Công việc cha" — đã theo thứ tự cây và kèm cấp để thụt lề.
class ParentCandidate {
  final String id;
  final String label;
  final int depth;
  final bool done;

  const ParentCandidate({
    required this.id,
    required this.label,
    required this.depth,
    required this.done,
  });
}

/// Port của web `parentCandidateOptions` (project-tree.model.ts):
/// dựng cây từ danh sách phẳng (cha – con, anh em theo `sortOrder` rồi mã),
/// loại cột mốc, việc đã huỷ / huỷ hiệu lực và node đã sát đáy cây.
List<ParentCandidate> buildParentCandidates(List<StandaloneTaskItem> items) {
  final present = items.map((e) => e.id).toSet();
  final childrenOf = <String, List<StandaloneTaskItem>>{};
  final roots = <StandaloneTaskItem>[];
  for (final item in items) {
    final pid = item.parentId;
    if (pid != null && pid.isNotEmpty && present.contains(pid)) {
      childrenOf.putIfAbsent(pid, () => []).add(item);
    } else {
      roots.add(item);
    }
  }
  int bySortOrder(StandaloneTaskItem a, StandaloneTaskItem b) {
    final diff = a.meta.sortOrder - b.meta.sortOrder;
    return diff != 0 ? diff : a.code.compareTo(b.code);
  }

  final result = <ParentCandidate>[];
  final visited = <String>{};
  void emit(StandaloneTaskItem item, int depth) {
    if (!visited.add(item.id)) return;
    final eligible = item.meta.itemType != 'milestone' &&
        !item.isReversed &&
        item.status != 'cancelled' &&
        item.meta.depth < ProjectAccess.maxDepth;
    if (eligible) {
      final done = item.status == 'done';
      final suffix = done ? 'workspace.create_item.parent_done_suffix'.tr() : '';
      result.add(ParentCandidate(
        id: item.id,
        label: '${item.code} · ${item.title}$suffix',
        depth: depth,
        done: done,
      ));
    }
    final children = [...(childrenOf[item.id] ?? const <StandaloneTaskItem>[])]..sort(bySortOrder);
    for (final child in children) {
      emit(child, depth + 1);
    }
  }

  for (final root in [...roots]..sort(bySortOrder)) {
    emit(root, 0);
  }
  return result;
}

/// Searchable selector bottom sheet for picking parent task
class ParentTaskPickerSheet extends StatefulWidget {
  final String initialSelectedId;
  final List<ParentCandidate> options;
  final bool isLoading;
  final void Function(String id, String label) onSelected;

  const ParentTaskPickerSheet({
    super.key,
    required this.initialSelectedId,
    required this.options,
    required this.isLoading,
    required this.onSelected,
  });

  @override
  State<ParentTaskPickerSheet> createState() => _ParentTaskPickerSheetState();
}

class _ParentTaskPickerSheetState extends State<ParentTaskPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((t) {
      if (_query.isEmpty) return true;
      return t.label.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    final rootLabel = 'workspace.create_item.project_root'.tr();

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'workspace.create_item.pick_parent_title'.tr(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _query = val.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                hintText: 'workspace.create_item.pick_parent_search'.tr(),
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // List
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)))
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // Option 1: Gốc dự án
                      ListTile(
                        leading: const Icon(Icons.account_tree_outlined, size: 20, color: Color(0xFF2563EB)),
                        title: Text(rootLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        trailing: widget.initialSelectedId.isEmpty
                            ? const Icon(Icons.check, size: 18, color: Color(0xFF2563EB))
                            : null,
                        onTap: () {
                          widget.onSelected('', rootLabel);
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),

                      // Filtered candidates, thụt lề theo cấp như web
                      ...filtered.map((t) {
                        final isSelected = widget.initialSelectedId == t.id;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.only(left: 16.0 + t.depth * 14.0, right: 16),
                          title: Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : (t.done ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, size: 18, color: Color(0xFF2563EB))
                              : null,
                          onTap: () {
                            widget.onSelected(t.id, t.label);
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
