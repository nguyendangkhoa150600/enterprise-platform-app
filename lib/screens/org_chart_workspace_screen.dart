import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';
import '../models/platform_models.dart';
import '../services/platform_service.dart';
import 'org_chart/components/org_chart_modals.dart';
import 'org_chart/components/org_tree_list_view.dart';

class OrgChartWorkspaceScreen extends StatefulWidget {
  final OrganizationSnapshot snapshot;
  final String? treeName;
  final String treeCode;
  final bool isPrimary;
  final VoidCallback? onDataChanged;

  const OrgChartWorkspaceScreen({
    super.key,
    required this.snapshot,
    this.treeName,
    this.treeCode = 'SAVINA-MAIN',
    this.isPrimary = true,
    this.onDataChanged,
  });

  @override
  State<OrgChartWorkspaceScreen> createState() => _OrgChartWorkspaceScreenState();
}

class _OrgChartWorkspaceScreenState extends State<OrgChartWorkspaceScreen> {
  final PlatformService _platformService = PlatformService();
  late OrganizationSnapshot _snapshot;

  // View Mode: 0 = Sơ đồ đồ họa (Visual Canvas), 1 = Sơ đồ phân cấp (Tree View)
  int _viewMode = 0;

  // Search & Tree expansion state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _collapsedNodeIds = {};

  // Canvas zoom & pan
  final TransformationController _transformController = TransformationController();

  // Selected Node for Detail Inspector
  OrgNode? _selectedNode;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.snapshot;
    _transformController.value = Matrix4.identity()
      ..translate(-220.0, 30.0)
      ..scale(0.48, 0.48);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _refreshSnapshot() async {
    final updated = await _platformService.getOrganizationSnapshot();
    if (updated != null && mounted) {
      setState(() {
        _snapshot = updated;
        if (_selectedNode != null) {
          _selectedNode = _snapshot.nodes.firstWhere(
            (n) => n.id == _selectedNode!.id,
            orElse: () => _snapshot.nodes.first,
          );
        }
      });
      widget.onDataChanged?.call();
    }
  }

  void _zoomIn() {
    final matrix = _transformController.value.clone();
    matrix.scale(1.25, 1.25);
    _transformController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformController.value.clone();
    matrix.scale(0.8, 0.8);
    _transformController.value = matrix;
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity()
        ..translate(-220.0, 30.0)
        ..scale(0.48, 0.48);
    });
  }

  void _expandAll() {
    setState(() => _collapsedNodeIds.clear());
  }

  void _collapseAll() {
    setState(() {
      _collapsedNodeIds.clear();
      for (final n in _snapshot.nodes) {
        _collapsedNodeIds.add(n.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildTopAppBar(),
      body: Column(
        children: [
          _buildWorkspaceSubHeader(),
          Expanded(
            child: _viewMode == 0 ? _buildVisualCanvasView() : _buildHierarchyTreeListView(),
          ),
        ],
      ),
    );
  }

  // 1. TOP APP BAR MATCHING WEB
  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  widget.treeName ?? 'org_chart.savina_chart'.tr(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (widget.isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Text(
                    'org_chart.badge_main'.tr(),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.treeCode,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'org_chart.main_tree_desc'.tr(),
            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB), size: 22),
          tooltip: 'org_chart.add_new_node'.tr(),
          onPressed: () => _showAddOrEditNodeDialog(),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }

  // 2. SUB-HEADER WITH TAB SWITCHER & ACTION BUTTONS
  Widget _buildWorkspaceSubHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // View Switcher (Canvas vs Tree List)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTabSegment(0, 'org_chart.graphic_view'.tr(), Icons.account_tree_outlined)),
                  Expanded(child: _buildTabSegment(1, 'org_chart.tree_view'.tr(), Icons.format_list_bulleted_rounded)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sắp xếp (Căn giữa sơ đồ canvas)
          if (_viewMode == 0) ...[
            InkWell(
              onTap: () {
                _resetZoom();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('org_chart.layout_reset'.tr()),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(7.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(
                  Icons.auto_awesome_mosaic_outlined,
                  size: 16,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Thêm node button
          InkWell(
            onTap: () => _showAddOrEditNodeDialog(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'common.add'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSegment(int index, String title, IconData icon) {
    final isSelected = _viewMode == index;
    return InkWell(
      onTap: () => setState(() => _viewMode = index),
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6.5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13.5,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. VISUAL CANVAS VIEW (INTERACTIVE 2D DIAGRAM)
  // ==========================================
  Widget _buildVisualCanvasView() {
    final rootNodes = _snapshot.nodes.where((n) {
      return n.parentId == null || n.parentId!.isEmpty || !_snapshot.nodes.any((p) => p.id == n.parentId);
    }).toList();

    return Stack(
      children: [
        // Canvas Grid Background & Interactive Node Tree
        Container(
          color: const Color(0xFFF8FAFC),
          child: CustomPaint(
            painter: _GridBackgroundPainter(),
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.15,
              maxScale: 3.0,
              constrained: false, // Unbounded canvas to avoid RenderFlex horizontal/vertical overflow
              boundaryMargin: const EdgeInsets.all(1500),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 120),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: rootNodes.map((root) => _buildCanvasNodeHierarchy(root)).toList(),
                ),
              ),
            ),
          ),
        ),

        // Bottom floating controls (Zoom in, Zoom out, Fit)
        Positioned(
          left: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCanvasIconButton(Icons.add, 'org_chart.zoom_in'.tr(), _zoomIn),
                const SizedBox(width: 2),
                _buildCanvasIconButton(Icons.remove, 'org_chart.zoom_out'.tr(), _zoomOut),
                const SizedBox(width: 2),
                _buildCanvasIconButton(Icons.crop_free, 'org_chart.restore'.tr(), _resetZoom),
              ],
            ),
          ),
        ),

        // Bottom hint banner
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined, size: 13, color: Colors.white70),
                SizedBox(width: 5),
                Text(
                  'org_chart.tap_node_props'.tr(),
                  style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvasIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF334155)),
      ),
    );
  }

  static const double _cardWidth = 150.0;
  static const double _cardHeight = 136.0;

  // Recursive Tree Node Renderer for Canvas
  Widget _buildCanvasNodeHierarchy(OrgNode node) {
    // In Canvas view, exclude positions that are manager/lead embedded in the unit
    final children = _snapshot.nodes.where((n) {
      if (n.parentId != node.id) return false;
      if (n.nodeTypeId == 'nt-pos-lead') return false;
      return true;
    }).toList();
    final hasChildren = children.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The Node Card itself
        _buildCanvasNodeCard(node),

        if (hasChildren) ...[
          // Vertical connector line from parent to children branch bar
          Container(
            width: 1.5,
            height: 16,
            color: const Color(0xFF94A3B8),
          ),

          // Children branching section
          if (children.length == 1)
            _buildCanvasNodeHierarchy(children.first)
          else
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Horizontal connecting branch bar
                Positioned(
                  top: 0,
                  left: (_cardWidth / 2) + 6,
                  right: (_cardWidth / 2) + 6,
                  child: Container(
                    height: 1.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),

                // Children cards row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children.map((child) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drop line from horizontal branch bar to child card
                          Container(
                            width: 1.5,
                            height: 16,
                            color: const Color(0xFF94A3B8),
                          ),
                          _buildCanvasNodeHierarchy(child),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
        ],
      ],
    );
  }

  // Canvas Node Card (Matching Web Image 1 exactly)
  Widget _buildCanvasNodeCard(OrgNode node) {
    final assignments = _snapshot.assignments.where((a) => a.nodeId == node.id).toList();
    final isSelected = _selectedNode?.id == node.id;
    final isUnit = node.nodeTypeId == 'nt-dept' || node.nodeTypeId == 'nt-team' || node.parentId == null;
    final isRoot = node.parentId == null || node.parentId!.isEmpty || node.code == 'SAVINA';
    final initials = _getNodeInitials(node);
    final subtitle = _getNodeSubtitle(node, assignments);

    // Count badges for bottom pill
    final childUnits = _snapshot.nodes.where((n) => n.parentId == node.id && (n.nodeTypeId == 'nt-dept' || n.nodeTypeId == 'nt-team')).length;
    final childPositions = _snapshot.nodes.where((n) => n.parentId == node.id && (n.nodeTypeId == 'nt-pos-lead' || n.nodeTypeId == 'nt-pos-exec')).length;

    String? bottomBadge;
    if (childUnits > 0) {
      bottomBadge = 'org_chart.child_units'.tr(args: {'count': childUnits});
    } else if (childPositions > 0) {
      bottomBadge = 'org_chart.child_positions'.tr(args: {'count': childPositions});
    }

    return GestureDetector(
      onTap: () {
        setState(() => _selectedNode = node);
        _showNodeDetailBottomSheet(node);
      },
      child: Container(
        width: _cardWidth,
        height: _cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Column(
            children: [
              // Top color accent bar
              if (isRoot)
                Row(
                  children: [
                    Expanded(child: Container(height: 3, color: const Color(0xFFEF4444))),
                    Expanded(child: Container(height: 3, color: const Color(0xFF2563EB))),
                  ],
                )
              else
                Container(
                  height: 3,
                  color: isUnit ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                ),

              // Card Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top row: Type name (ĐƠN VỊ / CHỨC DANH) + green dot / indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isUnit ? 'org_chart.type_unit_caps'.tr() : 'org_chart.type_position_caps'.tr(),
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.drag_indicator_rounded, size: 10, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ],
                      ),

                      // Center Avatar Initials
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isUnit ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isUnit ? const Color(0xFF2563EB) : const Color(0xFF059669),
                          ),
                        ),
                      ),

                      // Node Name
                      Text(
                        node.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          height: 1.15,
                        ),
                      ),

                      // Subtitle / Manager / Personnel
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFF64748B),
                          fontStyle: FontStyle.italic,
                          height: 1.1,
                        ),
                      ),

                      // Bottom Count Pill Badge (if available)
                      if (bottomBadge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFDDD6FE), width: 0.8),
                          ),
                          child: Text(
                            bottomBadge,
                            style: const TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getNodeInitials(OrgNode node) {
    if (node.code == 'SAVINA' || node.id == 'node-root') return 'SN';
    final name = node.name;
    if (name.contains('Tây Nguyên')) return 'TN';
    if (name.contains('Miền Nam')) return 'MN';
    if (name.contains('Văn phòng') && name.contains('Khối')) return 'VP';
    if (name.contains('Dịch vụ') || name.contains('Kỹ thuật - Dịch vụ')) return 'DV';
    if (name.contains('Thí nghiệm') && name.contains('Khối')) return 'TN';
    if (name.contains('Công ty')) return 'CT';
    if (name.contains('Hành chính')) return 'HC';
    if (name.contains('Tài chính')) return 'TC';
    if (name.contains('Kinh doanh')) return 'KD';
    if (name.contains('Tư vấn')) return 'TV';
    if (name.contains('Vận hành')) return 'VH';
    if (name.contains('Kỹ thuật')) return 'KT';
    if (name.contains('Đại hội')) return 'ĐĐ';
    if (name.contains('Quản trị')) return 'HQ';
    if (name.contains('Ban Tổng')) return 'BG';

    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'N';
    if (words.length == 1) return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }

  String _getNodeSubtitle(OrgNode node, List<OrgAssignment> assignments) {
    if (node.nodeTypeId == 'nt-pos-lead' || node.nodeTypeId == 'nt-pos-exec') {
      if (assignments.isNotEmpty) {
        final asg = assignments.first;
        final u = _snapshot.users.where((usr) => usr.id == asg.userId).firstOrNull;
        return u?.fullName ?? 'org_chart.assigned'.tr();
      }
      return 'org_chart.no_personnel'.tr();
    } else {
      final leadPos = _snapshot.nodes.where((n) => n.parentId == node.id && n.nodeTypeId == 'nt-pos-lead').firstOrNull;
      if (leadPos != null) {
        final leadAsg = _snapshot.assignments.where((a) => a.nodeId == leadPos.id && a.status == 'active').firstOrNull;
        final leadUser = _snapshot.users.where((u) => u.id == leadAsg?.userId).firstOrNull;
        if (leadUser != null) {
          return '${leadPos.name} -\n${leadUser.fullName}';
        }
        return leadPos.name;
      }
      return 'org_chart.no_manager'.tr();
    }
  }

  // ==========================================
  // 4. HIERARCHY TREE LIST VIEW (MATCHING LEFT SIDEBAR OF WEB)
  // ==========================================
  Widget _buildHierarchyTreeListView() {
    return OrgHierarchyTreeListView(
      snapshot: _snapshot,
      searchController: _searchController,
      searchQuery: _searchQuery,
      collapsedNodeIds: _collapsedNodeIds,
      selectedNode: _selectedNode,
      onSearchChanged: (val) => setState(() => _searchQuery = val),
      onClearSearch: () {
        _searchController.clear();
        setState(() => _searchQuery = '');
      },
      onExpandAll: _expandAll,
      onCollapseAll: _collapseAll,
      onToggleCollapse: (nodeId) {
        setState(() {
          if (_collapsedNodeIds.contains(nodeId)) {
            _collapsedNodeIds.remove(nodeId);
          } else {
            _collapsedNodeIds.add(nodeId);
          }
        });
      },
      onSelectNode: (node) {
        setState(() => _selectedNode = node);
        _showNodeDetailBottomSheet(node);
      },
      onAddChild: (parentNodeId) => _showAddOrEditNodeDialog(parentNodeId: parentNodeId),
      onEditNode: (node) => _showAddOrEditNodeDialog(existingNode: node),
      onDeleteNode: (node) => _confirmDeleteNode(node),
    );
  }

  void _showNodeDetailBottomSheet(OrgNode node) {
    showOrgNodeDetailBottomSheet(
      context,
      node: node,
      snapshot: _snapshot,
      platformService: _platformService,
      onRefreshSnapshot: _refreshSnapshot,
      onSelectNode: (pos) => setState(() => _selectedNode = pos),
      onOpenAddOrEditDialog: _showAddOrEditNodeDialog,
      onConfirmDeleteNode: _confirmDeleteNode,
    );
  }

  void _showAddOrEditNodeDialog({OrgNode? existingNode, String? parentNodeId, String? defaultCategory}) {
    showOrgNodeAddOrEditDialog(
      context,
      existingNode: existingNode,
      parentNodeId: parentNodeId,
      defaultCategory: defaultCategory,
      snapshot: _snapshot,
      platformService: _platformService,
      onRefreshSnapshot: _refreshSnapshot,
    );
  }

  void _confirmDeleteNode(OrgNode node) {
    confirmDeleteOrgNode(
      context,
      node: node,
      platformService: _platformService,
      onRefreshSnapshot: _refreshSnapshot,
    );
  }
}

// Custom Painter for Canvas Grid Background
class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1).withOpacity(0.35)
      ..strokeWidth = 1;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}