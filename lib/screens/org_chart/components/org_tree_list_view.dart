import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/platform_models.dart';

class OrgHierarchyTreeListView extends StatelessWidget {
  final OrganizationSnapshot snapshot;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<String> collapsedNodeIds;
  final OrgNode? selectedNode;
  final void Function(String) onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;
  final void Function(String nodeId) onToggleCollapse;
  final void Function(OrgNode node) onSelectNode;
  final void Function(String parentNodeId) onAddChild;
  final void Function(OrgNode node) onEditNode;
  final void Function(OrgNode node) onDeleteNode;

  const OrgHierarchyTreeListView({
    super.key,
    required this.snapshot,
    required this.searchController,
    required this.searchQuery,
    required this.collapsedNodeIds,
    required this.selectedNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onExpandAll,
    required this.onCollapseAll,
    required this.onToggleCollapse,
    required this.onSelectNode,
    required this.onAddChild,
    required this.onEditNode,
    required this.onDeleteNode,
  });

  bool _nodeOrChildrenMatch(OrgNode node, String query) {
    if (node.name.toLowerCase().contains(query) || node.code.toLowerCase().contains(query)) return true;
    final children = snapshot.nodes.where((n) => n.parentId == node.id).toList();
    for (final c in children) {
      if (_nodeOrChildrenMatch(c, query)) return true;
    }
    return false;
  }

  Widget _buildTreeListRecursive(OrgNode node, int depth) {
    final children = snapshot.nodes.where((n) => n.parentId == node.id).toList();
    final hasChildren = children.isNotEmpty;
    final isCollapsed = collapsedNodeIds.contains(node.id);
    final isSelected = selectedNode?.id == node.id;
    final isUnit = node.nodeTypeId == 'nt-dept' || node.nodeTypeId == 'nt-team' || node.parentId == null;

    // Filter matching
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      final matchesSelf = node.name.toLowerCase().contains(q) || node.code.toLowerCase().contains(q);
      final matchesChild = _nodeOrChildrenMatch(node, q);
      if (!matchesSelf && !matchesChild) return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onSelectNode(node),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: EdgeInsets.only(
              left: depth * 16.0 + 6,
              right: 8,
              top: 6,
              bottom: 6,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFF93C5FD) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // Expand / Collapse Chevron
                if (hasChildren)
                  InkWell(
                    onTap: () => onToggleCollapse(node.id),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        isCollapsed ? Icons.chevron_right : Icons.keyboard_arrow_down,
                        size: 16,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 20),

                // Icon (Building for Unit, Tie/Badge for Position)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isUnit ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isUnit ? Icons.business_outlined : Icons.badge_outlined,
                    size: 13,
                    color: isUnit ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 8),

                // Name & Code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        node.code,
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // Quick Action Buttons on hover/row: Add child (+), Edit, Delete
                IconButton(
                  icon: const Icon(Icons.add, size: 15, color: Color(0xFF64748B)),
                  tooltip: 'org_chart.add_child_node'.tr(),
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  onPressed: () => onAddChild(node.id),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF64748B)),
                  tooltip: 'common.edit'.tr(),
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  onPressed: () => onEditNode(node),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                  tooltip: 'common.delete'.tr(),
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  onPressed: () => onDeleteNode(node),
                ),
              ],
            ),
          ),
        ),

        // Recursive Children
        if (hasChildren && !isCollapsed)
          ...children.map((c) => _buildTreeListRecursive(c, depth + 1)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootNodes = snapshot.nodes.where((n) {
      return n.parentId == null || n.parentId!.isEmpty || !snapshot.nodes.any((p) => p.id == n.parentId);
    }).toList();

    return Column(
      children: [
        // Controls Bar (Search + Expand/Collapse all)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              // Search field matching Web
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'org_chart.search_node_hint'.tr(),
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 17, color: Color(0xFF94A3B8)),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 15, color: Color(0xFF94A3B8)),
                            onPressed: onClearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Sơ đồ phân cấp label + Mở hết / Thu gọn
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'org_chart.tree_view'.tr(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: onExpandAll,
                        child: Text('org_chart.expand_all'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('·', style: TextStyle(color: Color(0xFF94A3B8))),
                      ),
                      InkWell(
                        onTap: onCollapseAll,
                        child: Text('org_chart.collapse_all'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tree List Items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            physics: const BouncingScrollPhysics(),
            children: rootNodes.map((root) => _buildTreeListRecursive(root, 0)).toList(),
          ),
        ),

        // Footer status matching Web
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'org_chart.total_nodes'.tr(args: {'count': snapshot.nodes.length}),
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              Text(
                'org_chart.tap_node_detail'.tr(),
                style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
