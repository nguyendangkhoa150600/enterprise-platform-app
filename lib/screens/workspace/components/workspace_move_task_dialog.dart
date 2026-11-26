import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';

/// Modal "Di chuyển CV..." (Move Task Dialog)
/// Đồng bộ 1:1 với Web React packages/features/workspace/src/lib/components/move-dialog.tsx
/// [projectItems] vắng thì hộp thoại tự tải danh sách việc của dự án.
void showWorkspaceMoveTaskDialog(
  BuildContext context, {
  required StandaloneTaskItem task,
  required WorkspaceService service,
  required VoidCallback onMoved,
  List<StandaloneTaskItem>? projectItems,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MoveTaskDialogContent(
      task: task,
      service: service,
      onMoved: onMoved,
      projectItems: projectItems,
    ),
  );
}

/// Một đích hợp lệ, đã xếp theo thứ tự cây (web `buildWorkItemTree`).
class _MoveTarget {
  final StandaloneTaskItem item;
  final int depth;
  const _MoveTarget(this.item, this.depth);
}

/// Node và toàn bộ con cháu (web `branchOf`).
Set<String> _branchOf(List<StandaloneTaskItem> items, String rootId) {
  final childrenOf = <String, List<String>>{};
  for (final it in items) {
    final pid = it.parentId;
    if (pid == null || pid.isEmpty) continue;
    childrenOf.putIfAbsent(pid, () => []).add(it.id);
  }
  final branch = <String>{rootId};
  final queue = [rootId];
  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    for (final child in childrenOf[current] ?? const <String>[]) {
      if (branch.add(child)) queue.add(child);
    }
  }
  return branch;
}

/// Các đích nhận được việc làm con mới, xếp theo cây — cùng luật web `moveTargets`:
/// loại chính nhánh của nó, cha hiện tại, và đích làm cây vượt quá giới hạn độ sâu.
List<_MoveTarget> _moveTargets(List<StandaloneTaskItem> items, StandaloneTaskItem task) {
  final moving = items.firstWhere((it) => it.id == task.id, orElse: () => task);
  final branch = _branchOf(items, moving.id);
  var height = 0;
  for (final it in items) {
    if (branch.contains(it.id)) {
      final h = it.meta.depth - moving.meta.depth;
      if (h > height) height = h;
    }
  }
  bool allowed(StandaloneTaskItem it) =>
      !branch.contains(it.id) &&
      it.id != moving.parentId &&
      it.meta.depth + 1 + height <= ProjectAccess.maxDepth;

  // Dựng cây đầy đủ để giữ thứ tự hiển thị, rồi chỉ giữ các đích hợp lệ.
  final present = items.map((it) => it.id).toSet();
  final childrenOf = <String, List<StandaloneTaskItem>>{};
  final roots = <StandaloneTaskItem>[];
  for (final it in items) {
    final pid = it.parentId;
    if (pid != null && pid.isNotEmpty && present.contains(pid)) {
      childrenOf.putIfAbsent(pid, () => []).add(it);
    } else {
      roots.add(it);
    }
  }
  int bySortOrder(StandaloneTaskItem a, StandaloneTaskItem b) {
    final c = a.meta.sortOrder.compareTo(b.meta.sortOrder);
    return c != 0 ? c : a.code.compareTo(b.code);
  }

  final out = <_MoveTarget>[];
  void emit(StandaloneTaskItem it, int depth) {
    if (allowed(it)) out.add(_MoveTarget(it, depth));
    final children = [...?childrenOf[it.id]]..sort(bySortOrder);
    for (final child in children) {
      emit(child, depth + 1);
    }
  }

  for (final root in [...roots]..sort(bySortOrder)) {
    emit(root, 0);
  }
  return out;
}

String _itemTypeLabel(String itemType) {
  switch (itemType) {
    case 'phase':
      return 'workspace.move.type_phase'.tr();
    case 'milestone':
      return 'workspace.move.type_milestone'.tr();
    default:
      return 'workspace.move.type_task'.tr();
  }
}

class _MoveTaskDialogContent extends StatefulWidget {
  final StandaloneTaskItem task;
  final WorkspaceService service;
  final VoidCallback onMoved;
  final List<StandaloneTaskItem>? projectItems;

  const _MoveTaskDialogContent({
    required this.task,
    required this.service,
    required this.onMoved,
    this.projectItems,
  });

  @override
  State<_MoveTaskDialogContent> createState() => _MoveTaskDialogContentState();
}

class _MoveTaskDialogContentState extends State<_MoveTaskDialogContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<_MoveTarget> _candidates = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _selectedTargetId = '';
  String _query = '';
  String? _error;

  static const String rootTarget = '__root__';

  @override
  void initState() {
    super.initState();
    final given = widget.projectItems;
    if (given != null) {
      _candidates = _moveTargets(given, widget.task);
      _isLoading = false;
    } else {
      _loadCandidates();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    final pId = widget.task.projectId;
    if (pId == null || pId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final list = await widget.service.getProjectWorkItems(pId);
      if (mounted) {
        setState(() {
          _candidates = _moveTargets(list, widget.task);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedTargetId.isEmpty) {
      setState(() => _error = 'workspace.move.pick_target'.tr());
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final targetParentId = _selectedTargetId == rootTarget ? null : _selectedTargetId;

    bool ok = false;
    try {
      ok = await widget.service.moveWorkItem(widget.task.id, parentId: targetParentId);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      widget.onMoved();
    } else {
      setState(() {
        _isSubmitting = false;
        _error = widget.service.lastError ?? 'workspace.move.failed'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canMoveToRoot = widget.task.parentId != null && widget.task.parentId!.isNotEmpty;

    String labelOf(_MoveTarget t) =>
        '${t.item.code} · ${t.item.title} (${_itemTypeLabel(t.item.meta.itemType)})';
    final filtered = _candidates.where((t) {
      if (_query.isEmpty) return true;
      return labelOf(t).toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header matching Web 1:1
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'workspace.move.title'.tr(args: {'code': widget.task.code}),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'workspace.move.subtitle'.tr(args: {'title': widget.task.title}),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),

          // Label & Search Input
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'workspace.move.field_label'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 2),
                Text(
                  'workspace.move.field_hint'.tr(),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _query = val.trim()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    hintText: 'workspace.move.search_hint'.tr(),
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // List of Choices
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEAB308)))
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      // Choice: Cấp gốc của dự án (nếu việc đang là việc con)
                      if (canMoveToRoot) ...[
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.account_tree_outlined, size: 20, color: Color(0xFF2563EB)),
                          title: Text(
                            'workspace.move.root_option'.tr(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          trailing: _selectedTargetId == rootTarget
                              ? const Icon(Icons.check, size: 18, color: Color(0xFF2563EB))
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedTargetId = rootTarget;
                              _error = null;
                            });
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                      ],

                      // Valid target tasks
                      ...filtered.map((t) {
                        final isSelected = _selectedTargetId == t.item.id;
                        final label = labelOf(t);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.only(left: 16.0 + 14.0 * t.depth, right: 16),
                          leading: const Icon(Icons.subdirectory_arrow_right, size: 18, color: Color(0xFF64748B)),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, size: 18, color: Color(0xFF2563EB))
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedTargetId = t.item.id;
                              _error = null;
                            });
                          },
                        );
                      }),
                      if (filtered.isEmpty && !canMoveToRoot)
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'workspace.move.empty'.tr(),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C)),
              ),
            ),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Huỷ', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSubmitting || _selectedTargetId.isEmpty ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAB308),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                        )
                      : Text(
                          'workspace.move.submit'.tr(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
