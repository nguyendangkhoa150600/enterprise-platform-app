import 'package:flutter/material.dart';
import '../../../models/workspace_models.dart';

/// BottomSheet duyệt Cây Thư Mục tài liệu, đồng bộ 1:1 với Web React
Future<String?> showWorkspaceFolderTreeSheet(
  BuildContext context, {
  required List<WorkspaceFolderItem> folders,
  required List<ProjectItem> projects,
  String? currentFolderId,
  Map<String, int> folderCounts = const {},
}) async {
  return await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FolderTreeSheet(
      folders: folders,
      projects: projects,
      currentFolderId: currentFolderId,
      folderCounts: folderCounts,
    ),
  );
}

class _FolderTreeSheet extends StatefulWidget {
  final List<WorkspaceFolderItem> folders;
  final List<ProjectItem> projects;
  final String? currentFolderId;
  final Map<String, int> folderCounts;

  const _FolderTreeSheet({
    required this.folders,
    required this.projects,
    this.currentFolderId,
    required this.folderCounts,
  });

  @override
  State<_FolderTreeSheet> createState() => _FolderTreeSheetState();
}

class _FolderTreeSheetState extends State<_FolderTreeSheet> {
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    // Mở sẵn các nhánh có chứa thư mục hiện tại
    if (widget.currentFolderId != null) {
      _expandAncestors(widget.currentFolderId!);
    }
  }

  void _expandAncestors(String folderId) {
    String? current = folderId;
    final byId = {for (final f in widget.folders) f.id: f};
    while (current != null && byId.containsKey(current)) {
      _expandedIds.add(current);
      current = byId[current]?.parentId;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phân chia: Kho đơn vị vs Theo dự án
    final unitFolders = widget.folders.where((f) => f.projectId == null || f.projectId!.isEmpty).toList();
    final projectFolders = widget.folders.where((f) => f.projectId != null && f.projectId!.isNotEmpty).toList();

    // Gom nhóm folder dự án theo projectId
    final Map<String, List<WorkspaceFolderItem>> projectFolderMap = {};
    for (final f in projectFolders) {
      projectFolderMap.putIfAbsent(f.projectId!, () => []).add(f);
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.account_tree_outlined, size: 20, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                const Text(
                  'Cây thư mục tài liệu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('ROOT'),
                  child: const Text('Xem tất cả (Gốc)', style: TextStyle(fontSize: 13, color: Color(0xFF2563EB))),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              children: [
                // Phần 1: KHO ĐƠN VỊ
                const Padding(
                  padding: EdgeInsets.only(bottom: 6, top: 4),
                  child: Text(
                    'KHO ĐƠN VỊ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                  ),
                ),
                ..._buildTreeLevel(unitFolders, null),

                const SizedBox(height: 16),

                // Phần 2: THEO DỰ ÁN
                const Padding(
                  padding: EdgeInsets.only(bottom: 6, top: 4),
                  child: Text(
                    'THEO DỰ ÁN',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                  ),
                ),
                ...projectFolderMap.entries.map((entry) {
                  final projId = entry.key;
                  final pFolders = entry.value;
                  final proj = widget.projects.firstWhere(
                    (p) => p.id == projId,
                    orElse: () => ProjectItem(id: projId, name: 'Dự án $projId', code: '', status: 'active'),
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: pFolders.any((f) => f.id == widget.currentFolderId),
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: Icon(Icons.business_center, size: 14, color: Colors.white),
                          ),
                        ),
                        title: Text(
                          proj.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        childrenPadding: const EdgeInsets.only(left: 12, right: 8, bottom: 8),
                        children: _buildTreeLevel(pFolders, null),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTreeLevel(List<WorkspaceFolderItem> allFolders, String? parentId) {
    final children = allFolders.where((f) => f.parentId == parentId).toList();
    if (children.isEmpty) return [];

    return children.map((folder) {
      final isSelected = folder.id == widget.currentFolderId;
      final count = widget.folderCounts[folder.id] ?? 0;
      final subChildren = allFolders.where((f) => f.parentId == folder.id).toList();
      final hasChildren = subChildren.isNotEmpty;
      final isExpanded = _expandedIds.contains(folder.id);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).pop(folder.id);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  if (hasChildren)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedIds.remove(folder.id);
                          } else {
                            _expandedIds.add(folder.id);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                          size: 18,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 22),
                  const Icon(Icons.folder, size: 18, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (hasChildren && isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: _buildTreeLevel(allFolders, folder.id),
              ),
            ),
        ],
      );
    }).toList();
  }
}
