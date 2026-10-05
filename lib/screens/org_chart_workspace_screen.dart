import 'package:flutter/material.dart';
import '../models/platform_models.dart';
import '../services/platform_service.dart';

class OrgChartWorkspaceScreen extends StatefulWidget {
  final OrganizationSnapshot snapshot;
  final String treeName;
  final String treeCode;
  final bool isPrimary;
  final VoidCallback? onDataChanged;

  const OrgChartWorkspaceScreen({
    super.key,
    required this.snapshot,
    this.treeName = 'Sơ đồ tổ chức SAVINA',
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
                  widget.treeName,
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
                  child: const Text(
                    'CHÍNH',
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
          const Text(
            'Cây tổ chức chính, gồm SAVINA và các pháp nhân liên quan.',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB), size: 22),
          tooltip: 'Thêm node mới',
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
                  Expanded(child: _buildTabSegment(0, 'Sơ đồ đồ họa', Icons.account_tree_outlined)),
                  Expanded(child: _buildTabSegment(1, 'Sơ đồ phân cấp', Icons.format_list_bulleted_rounded)),
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
                  const SnackBar(
                    content: Text('Đã căn giữa và sắp xếp lại bố cục sơ đồ.'),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'Thêm',
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
                _buildCanvasIconButton(Icons.add, 'Phóng to', _zoomIn),
                const SizedBox(width: 2),
                _buildCanvasIconButton(Icons.remove, 'Thu nhỏ', _zoomOut),
                const SizedBox(width: 2),
                _buildCanvasIconButton(Icons.crop_free, 'Khôi phục', _resetZoom),
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
              children: const [
                Icon(Icons.touch_app_outlined, size: 13, color: Colors.white70),
                SizedBox(width: 5),
                Text(
                  'Bấm node để xem thuộc tính chi tiết',
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
      bottomBadge = '$childUnits đơn vị';
    } else if (childPositions > 0) {
      bottomBadge = '$childPositions chức vụ';
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
                            isUnit ? 'ĐƠN VỊ' : 'CHỨC DANH',
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
        return u?.fullName ?? 'Đã phân công';
      }
      return 'Chưa có nhân sự';
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
      return 'Không có / chưa chọn quản lý';
    }
  }

  // ==========================================
  // 4. HIERARCHY TREE LIST VIEW (MATCHING LEFT SIDEBAR OF WEB)
  // ==========================================
  Widget _buildHierarchyTreeListView() {
    final rootNodes = _snapshot.nodes.where((n) {
      return n.parentId == null || n.parentId!.isEmpty || !_snapshot.nodes.any((p) => p.id == n.parentId);
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
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm node...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 17, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 15, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
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
                  const Text(
                    'Sơ đồ phân cấp',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: _expandAll,
                        child: const Text('Mở hết', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('·', style: TextStyle(color: Color(0xFF94A3B8))),
                      ),
                      InkWell(
                        onTap: _collapseAll,
                        child: const Text('Thu gọn', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
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
                'Tổng cộng: ${_snapshot.nodes.length} node',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const Text(
                'Bấm node để xem chi tiết',
                style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTreeListRecursive(OrgNode node, int depth) {
    final children = _snapshot.nodes.where((n) => n.parentId == node.id).toList();
    final hasChildren = children.isNotEmpty;
    final isCollapsed = _collapsedNodeIds.contains(node.id);
    final isSelected = _selectedNode?.id == node.id;
    final isUnit = node.nodeTypeId == 'nt-dept' || node.nodeTypeId == 'nt-team' || node.parentId == null;

    // Filter matching
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final matchesSelf = node.name.toLowerCase().contains(q) || node.code.toLowerCase().contains(q);
      final matchesChild = _nodeOrChildrenMatch(node, q);
      if (!matchesSelf && !matchesChild) return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() => _selectedNode = node);
            _showNodeDetailBottomSheet(node);
          },
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
                    onTap: () {
                      setState(() {
                        if (isCollapsed) {
                          _collapsedNodeIds.remove(node.id);
                        } else {
                          _collapsedNodeIds.add(node.id);
                        }
                      });
                    },
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
                  tooltip: 'Thêm node con',
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  onPressed: () => _showAddOrEditNodeDialog(parentNodeId: node.id),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF64748B)),
                  tooltip: 'Chỉnh sửa',
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  onPressed: () => _showAddOrEditNodeDialog(existingNode: node),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                  tooltip: 'Xóa',
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  onPressed: () => _confirmDeleteNode(node),
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

  bool _nodeOrChildrenMatch(OrgNode node, String query) {
    if (node.name.toLowerCase().contains(query) || node.code.toLowerCase().contains(query)) return true;
    final children = _snapshot.nodes.where((n) => n.parentId == node.id).toList();
    for (final c in children) {
      if (_nodeOrChildrenMatch(c, query)) return true;
    }
    return false;
  }

  // ==========================================
  // 5. THUỘC TÍNH CHI TIẾT (DETAIL & EDIT DRAWER / MODAL)
  // Matching Right Sidebar in Web Screenshot
  // ==========================================
  void _showNodeDetailBottomSheet(OrgNode node) {
    final nameCtrl = TextEditingController(text: node.name);
    final codeCtrl = TextEditingController(text: node.code);
    final descCtrl = TextEditingController(text: node.description ?? '');
    String selectedCategory = (node.nodeTypeId == 'nt-pos-lead' || node.nodeTypeId == 'nt-pos-exec') ? 'position' : 'unit';
    String? selectedParentId = node.parentId;

    final availableParents = _snapshot.nodes.where((n) => n.id != node.id).toList();

    // Find subordinate positions under this unit node
    final subordinatePositions = _snapshot.nodes.where((n) {
      return n.parentId == node.id && (n.nodeTypeId == 'nt-pos-lead' || n.nodeTypeId == 'nt-pos-exec');
    }).toList();

    // Default manager position
    String? selectedManagerPositionId = subordinatePositions.where((p) => p.nodeTypeId == 'nt-pos-lead').firstOrNull?.id;

    // Personnel assigned if this is a position
    final positionAssignments = _snapshot.assignments.where((a) => a.nodeId == node.id && a.status == 'active').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header matching Web: THUỘC TÍNH CHI TIẾT + Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 17, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        const Text(
                          'THUỘC TÍNH CHI TIẾT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: selectedCategory == 'unit' ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selectedCategory == 'unit' ? const Color(0xFF93C5FD) : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Text(
                        selectedCategory == 'unit' ? 'Đơn vị' : 'Chức danh',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: selectedCategory == 'unit' ? const Color(0xFF1D4ED8) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),

                // 1. Đơn vị / Chức danh (Tên node)
                const Text(
                  'Đơn vị / Chức danh (Tên node)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _buildInputDecoration('Nhập tên đơn vị hoặc chức danh...'),
                ),
                const SizedBox(height: 12),

                // Warning / Info Note matching Web
                if (node.parentId == null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'Sơ đồ này đã có node gốc. Mỗi sơ đồ chỉ được phép tạo 1 node gốc duy nhất.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFD97706), height: 1.3),
                    ),
                  ),

                // 2. Chức danh quản lý (Node Position chính) - Shown when category is 'unit'
                if (selectedCategory == 'unit') ...[
                  const Text(
                    'Chức danh quản lý (Node Position chính)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedManagerPositionId,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Không có / chưa chọn quản lý', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          ),
                          ...subordinatePositions.map((p) {
                            return DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text(p.name, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
                            );
                          }),
                        ],
                        onChanged: (val) => setModalState(() => selectedManagerPositionId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. Phân loại Đối tượng (Loại node)
                const Text(
                  'Phân loại Đối tượng (Loại node)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryOption(
                        label: 'Đơn vị',
                        isSelected: selectedCategory == 'unit',
                        onTap: () => setModalState(() => selectedCategory = 'unit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCategoryOption(
                        label: 'Chức danh',
                        isSelected: selectedCategory == 'position',
                        onTap: () => setModalState(() => selectedCategory = 'position'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  selectedCategory == 'unit'
                      ? 'Đơn vị (phòng, ban, khối...) có thể chứa các đơn vị hoặc chức danh con trực thuộc.'
                      : 'Chức danh (vị trí, chức vụ) đại diện cho vị trí công việc có nhân sự bổ nhiệm.',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                // 4. Mã số định danh (Code / MSNV)
                const Text(
                  'Mã số định danh (Code / MSNV)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: codeCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _buildInputDecoration('Mã code định danh...'),
                ),
                const SizedBox(height: 14),

                // 5. Mô tả chức năng & nhiệm vụ
                const Text(
                  'Mô tả chức năng & nhiệm vụ',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: _buildInputDecoration('Mô tả chức năng, nhiệm vụ và phạm vi trách nhiệm...'),
                ),
                const SizedBox(height: 14),

                // 6. Trực thuộc đơn vị (Node cha)
                const Text(
                  'Trực thuộc đơn vị (Node cha)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedParentId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Không có (Node gốc / Cấp cao nhất)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        ),
                        ...availableParents.map((p) {
                          return DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text('${p.name} (${p.code})', style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                          );
                        }),
                      ],
                      onChanged: (val) => setModalState(() => selectedParentId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions: Save button & Delete button matching Web
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDeleteNode(node);
                      },
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      label: const Text('Xóa node', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng nhập tên và mã định danh của node.')),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          final nodeTypeId = selectedCategory == 'unit' ? 'nt-dept' : 'nt-pos-lead';
                          final success = await _platformService.updateNode(
                            node.id,
                            name: nameCtrl.text.trim(),
                            code: codeCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            parentId: selectedParentId,
                            nodeTypeId: nodeTypeId,
                          );

                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã lưu thay đổi thuộc tính thành công!'), backgroundColor: Color(0xFF059669)),
                            );
                            _refreshSnapshot();
                          }
                        },
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),

                // ========================================================
                // 7. CHỨC DANH TRỰC THUỘC (SUBORDINATE POSITIONS SECTION)
                // Matching Web Screenshot
                // ========================================================
                if (selectedCategory == 'unit') ...[
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // Header with icon and count badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 17, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text(
                            'CHỨC DANH TRỰC THUỘC',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '${subordinatePositions.length} chức danh',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (subordinatePositions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.badge_outlined, size: 28, color: Color(0xFF94A3B8)),
                          SizedBox(height: 6),
                          Text(
                            'Chưa có chức danh trực thuộc',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Thêm các vị trí / chức danh chuyên môn cho đơn vị này bên dưới.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...subordinatePositions.map((pos) {
                      final asg = _snapshot.assignments.where((a) => a.nodeId == pos.id && a.status == 'active').firstOrNull;
                      final assignedUser = _snapshot.users.where((u) => u.id == asg?.userId).firstOrNull;
                      final isLead = pos.nodeTypeId == 'nt-pos-lead' || pos.id == selectedManagerPositionId;
                      final assignedName = assignedUser?.fullName;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showNodeDetailBottomSheet(pos);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            pos.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isLead) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFFDE68A)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.star, size: 10, color: Color(0xFFD97706)),
                                                SizedBox(width: 2),
                                                Text(
                                                  'Quản lý',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFD97706),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    if (assignedName != null && assignedName.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          assignedName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      )
                                    else
                                      const Text(
                                        'Chưa có nhân sự',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddOrEditNodeDialog(parentNodeId: node.id, defaultCategory: 'position');
                      },
                      icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF2563EB)),
                      label: const Text(
                        'Thêm chức danh trực thuộc',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],

                // ========================================================
                // 8. NHÂN SỰ ĐƯỢC BỔ NHIỆM (WHEN INSPECTING A POSITION NODE)
                // ========================================================
                if (selectedCategory == 'position') ...[
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.people_alt_outlined, size: 17, color: Color(0xFF059669)),
                          SizedBox(width: 8),
                          Text(
                            'NHÂN SỰ ĐƯỢC BỔ NHIỆM',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          '${positionAssignments.length} nhân sự',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (positionAssignments.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.person_outline, size: 28, color: Color(0xFF94A3B8)),
                          SizedBox(height: 6),
                          Text(
                            'Vị trí này đang trống',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Chưa có nhân sự nào được bổ nhiệm giữ chức danh này.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...positionAssignments.map((asg) {
                      final assignedUser = _snapshot.users.where((u) => u.id == asg.userId).firstOrNull;
                      final name = assignedUser?.fullName ?? 'Nhân sự';
                      final email = assignedUser?.email ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text(
                                name.isNotEmpty ? name[0] : 'U',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (asg.isPrimary) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: const Text(
                                            'Chính thức',
                                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (email.isNotEmpty)
                                    Text(
                                      email,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Đang giữ vị trí',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(12),
    );
  }

  // ==========================================
  // 6. ADD / EDIT NODE MODAL DIALOG
  // ==========================================
  void _showAddOrEditNodeDialog({OrgNode? existingNode, String? parentNodeId, String? defaultCategory}) {
    final isEditing = existingNode != null;
    final nameCtrl = TextEditingController(text: existingNode?.name ?? '');
    final codeCtrl = TextEditingController(text: existingNode?.code ?? '');
    final descCtrl = TextEditingController(text: existingNode?.description ?? '');
    String selectedCategory = existingNode != null
        ? ((existingNode.nodeTypeId == 'nt-pos-lead' || existingNode.nodeTypeId == 'nt-pos-exec') ? 'position' : 'unit')
        : (defaultCategory ?? 'unit');
    String? selectedParentId = existingNode?.parentId ?? parentNodeId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  isEditing ? 'Chỉnh sửa Node' : (selectedCategory == 'position' ? 'Thêm chức danh mới' : 'Thêm đơn vị mới vào sơ đồ'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 14),

                const Text('Tên đơn vị / chức danh *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(controller: nameCtrl, style: const TextStyle(fontSize: 13), decoration: _buildInputDecoration('Nhập tên...')),
                const SizedBox(height: 14),

                const Text('Phân loại đối tượng', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryOption(
                        label: 'Đơn vị',
                        isSelected: selectedCategory == 'unit',
                        onTap: () => setDialogState(() => selectedCategory = 'unit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCategoryOption(
                        label: 'Chức danh',
                        isSelected: selectedCategory == 'position',
                        onTap: () => setDialogState(() => selectedCategory = 'position'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Mã số định danh (Code) *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(controller: codeCtrl, style: const TextStyle(fontSize: 13), decoration: _buildInputDecoration('Mã CODE...')),
                const SizedBox(height: 14),

                const Text('Trực thuộc đơn vị (Node cha)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedParentId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Không có (Node gốc / Cấp cao nhất)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        ),
                        ..._snapshot.nodes.where((n) => n.id != existingNode?.id).map((p) {
                          return DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text('${p.name} (${p.code})', style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                          );
                        }),
                      ],
                      onChanged: (val) => setDialogState(() => selectedParentId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng điền đầy đủ tên và mã định danh.')),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        final nodeTypeId = selectedCategory == 'unit' ? 'nt-dept' : 'nt-pos-lead';

                        bool success = false;
                        if (isEditing) {
                          success = await _platformService.updateNode(
                            existingNode.id,
                            name: nameCtrl.text.trim(),
                            code: codeCtrl.text.trim(),
                            parentId: selectedParentId,
                            nodeTypeId: nodeTypeId,
                            description: descCtrl.text.trim(),
                          );
                        } else {
                          success = await _platformService.createNode(
                            treeId: 't-1',
                            name: nameCtrl.text.trim(),
                            code: codeCtrl.text.trim(),
                            parentId: selectedParentId,
                            nodeTypeId: nodeTypeId,
                            description: descCtrl.text.trim(),
                          );
                        }

                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEditing ? 'Đã cập nhật node thành công!' : 'Đã thêm node mới thành công!'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                          _refreshSnapshot();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(isEditing ? 'Lưu thay đổi' : 'Thêm node', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteNode(OrgNode node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa node sơ đồ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${node.name}" khỏi sơ đồ tổ chức không? Các vị trí trực thuộc cũng sẽ bị ảnh hưởng.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _platformService.deleteNode(node.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa node thành công!'), backgroundColor: Color(0xFFEF4444)),
                );
                _refreshSnapshot();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa node'),
          ),
        ],
      ),
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
