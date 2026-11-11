import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/platform_models.dart';
import '../../../services/platform_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/colors.dart';
import '../../org_chart_workspace_screen.dart';
import 'home_org_appointment_dialog.dart';

class HomeOrganizationView extends StatefulWidget {
  final OrganizationSnapshot? snapshot;
  final PlatformService platformService;
  final VoidCallback onRefresh;

  const HomeOrganizationView({
    super.key,
    required this.snapshot,
    required this.platformService,
    required this.onRefresh,
  });

  @override
  State<HomeOrganizationView> createState() => _HomeOrganizationViewState();
}

class _HomeOrganizationViewState extends State<HomeOrganizationView> {
  int _orgStructureTab = 0; // 0: Cây tổ chức, 1: Bổ nhiệm
  String _orgSearchQuery = '';
  final TextEditingController _orgSearchController = TextEditingController();

  String _assignmentSearchQuery = '';
  final TextEditingController _assignmentSearchController = TextEditingController();
  String _assignmentRoleFilter = 'ALL';
  String _assignmentStatusFilter = 'ALL';

  @override
  void dispose() {
    _orgSearchController.dispose();
    _assignmentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    if (snapshot == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Breadcrumbs
        Row(
          children: [
            Text('Tenant Portal', style: TextStyle(fontSize: 11.5, color: AppColors.slate500)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 14, color: AppColors.slate400),
            ),
            Text('home.org.breadcrumb_admin'.tr(), style: TextStyle(fontSize: 11.5, color: AppColors.slate500)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 14, color: AppColors.slate400),
            ),
            Text('home.org.org_chart'.tr(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.slate700)),
          ],
        ),
        const SizedBox(height: 8),

        // 2. Title & Subtitle
        Text(
          'home.org.org_chart'.tr(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'home.org.subtitle'.tr(),
          style: TextStyle(fontSize: 12.5, color: AppColors.slate500),
        ),
        const SizedBox(height: 16),

        // 3. Sub-tabs bar matching Web
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
          ),
          child: Row(
            children: [
              _buildOrgSubTabButton(
                index: 0,
                title: 'home.org.tab_trees'.tr(),
                icon: Icons.account_tree_outlined,
              ),
              const SizedBox(width: 8),
              _buildOrgSubTabButton(
                index: 1,
                title: 'home.org.tab_assignments'.tr(),
                icon: Icons.person_add_alt_1_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Sub-tab Content
        if (_orgStructureTab == 0)
          _buildOrgTreesTab(snapshot)
        else
          _buildOrgAssignmentsTab(snapshot),
      ],
    );
  }

  Widget _buildOrgSubTabButton({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _orgStructureTab == index;
    return InkWell(
      onTap: () => setState(() => _orgStructureTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF2563EB) : AppColors.slate500,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : AppColors.slate600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: CÂY TỔ CHỨC (Matching Web Table / List view)
  Widget _buildOrgTreesTab(OrganizationSnapshot snapshot) {
    // Real organization trees (core-snapshot `trees`); node counts come from the nodes of each tree.
    final orgTrees = [
      for (final t in snapshot.trees)
        {
          'id': t.id,
          'code': t.code,
          'name': t.name,
          'isPrimary': t.isPrimary,
          'description': t.description ?? '',
          'type': (t.isPrimary ? 'home.org.type_main' : 'home.org.type_secondary').tr(),
          'nodeCount': '${snapshot.nodes.where((n) => n.treeId == t.id).length}',
          'status': t.status == 'active' ? 'home.org.status_active'.tr() : t.status,
        },
    ];

    final filteredTrees = orgTrees.where((t) {
      if (_orgSearchQuery.isEmpty) return true;
      final query = _orgSearchQuery.toLowerCase();
      return (t['name'] as String).toLowerCase().contains(query) ||
          (t['code'] as String).toLowerCase().contains(query) ||
          (t['description'] as String).toLowerCase().contains(query);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Action Bar
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          controller: _orgSearchController,
                          onChanged: (val) => setState(() => _orgSearchQuery = val),
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'home.org.search_tree_hint'.tr(),
                            hintStyle: TextStyle(fontSize: 12, color: AppColors.slate400),
                            prefixIcon: Icon(Icons.search, size: 18, color: AppColors.slate400),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('home.org.add_tree_wip'.tr())),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('home.org.add_tree'.tr(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // List of Tree Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredTrees.length,
            separatorBuilder: (context, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final item = filteredTrees[index];
              final isPrimary = item['isPrimary'] == true;

              return Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code + Name + Primary Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item['code'] as String,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (isPrimary) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF93C5FD)),
                                  ),
                                  child: Text(
                                    'home.org.badge_main'.tr(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Description
                    if ((item['description'] as String).isNotEmpty) ...[
                      Text(
                        item['description'] as String,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Metadata badges (Loại sơ đồ, Số node, Trạng thái)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Loại sơ đồ
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPrimary ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['type'] as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isPrimary ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                            ),
                          ),
                        ),

                        // Số Node
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            '${item['nodeCount']} node',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),

                        // Trạng thái
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF059669),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item['status'] as String,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Actions Row (Xem chi tiết, Sửa, Xóa)
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrgChartWorkspaceScreen(
                                  snapshot: snapshot,
                                  treeId: item['id'] as String,
                                  treeName: item['name'] as String,
                                  treeCode: item['code'] as String,
                                  isPrimary: isPrimary,
                                  onDataChanged: widget.onRefresh,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                          label: Text('common.view_detail'.tr(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.slate500),
                          tooltip: 'common.edit'.tr(),
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                          tooltip: 'common.delete'.tr(),
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'home.org.showing_trees'.tr(args: {'shown': filteredTrees.length, 'total': orgTrees.length}),
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
                Text(
                  'home.org.click_to_open'.tr(),
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: BỔ NHIỆM (Assignments List View - Synchronized with React Web)
  Widget _buildOrgAssignmentsTab(OrganizationSnapshot snapshot) {
    // Filter assignments
    final filteredAssignments = snapshot.assignments.where((a) {
      final user = snapshot.users.firstWhere(
        (u) => u.id == a.userId,
        orElse: () => TenantUser(
          id: a.userId,
          fullName: 'home.org.employee'.tr(),
          email: '',
          systemRole: 'tenant-user',
          status: 'active',
          isActive: true,
          createdAt: '',
          updatedAt: '',
        ),
      );
      final node = snapshot.nodes.firstWhere(
        (n) => n.id == a.nodeId,
        orElse: () => OrgNode(
          id: a.nodeId,
          treeId: 't-1',
          nodeTypeId: 'nt-dept',
          code: 'NODE',
          name: 'home.org.unit'.tr(),
          status: 'active',
        ),
      );

      // Search Query
      if (_assignmentSearchQuery.isNotEmpty) {
        final query = _assignmentSearchQuery.toLowerCase().trim();
        final matchesUser = user.fullName.toLowerCase().contains(query) || user.email.toLowerCase().contains(query);
        final matchesNode = node.name.toLowerCase().contains(query) || node.code.toLowerCase().contains(query);
        final matchesNote = (a.note ?? '').toLowerCase().contains(query);
        if (!matchesUser && !matchesNode && !matchesNote) return false;
      }

      // Role filter
      if (_assignmentRoleFilter == 'primary' && !a.isPrimary) return false;
      if (_assignmentRoleFilter == 'concurrent' && a.isPrimary) return false;

      // Status filter
      if (_assignmentStatusFilter != 'ALL') {
        if (_assignmentStatusFilter == 'inactive') {
          if (a.status != 'inactive' && a.status != 'disabled') return false;
        } else if (a.status != _assignmentStatusFilter) {
          return false;
        }
      }

      return true;
    }).toList();

    final primaryCount = snapshot.assignments.where((a) => a.isPrimary).length;
    final concurrentCount = snapshot.assignments.where((a) => !a.isPrimary).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Controls (Search bar, Filters & Action Button matching Web)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Search & Button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          controller: _assignmentSearchController,
                          onChanged: (val) => setState(() => _assignmentSearchQuery = val),
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'home.org.search_assign_hint'.tr(),
                            hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate400),
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.slate400),
                            suffixIcon: _assignmentSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: AppColors.slate400),
                                    onPressed: () {
                                      _assignmentSearchController.clear();
                                      setState(() => _assignmentSearchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                    ),
                    if (context.watch<AuthProvider>().canCreateOrganization) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateAppointmentDialog(snapshot),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        'home.org.assign_user'.tr(),
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB), // Blue 600
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Filter Dropdowns / Chips Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Role filter
                      _buildAssignmentFilterChip(
                        label: 'home.org.all_roles'.tr(),
                        isSelected: _assignmentRoleFilter == 'ALL',
                        onTap: () => setState(() => _assignmentRoleFilter = 'ALL'),
                      ),
                      const SizedBox(width: 6),
                      _buildAssignmentFilterChip(
                        label: 'home.org.primary_assignment'.tr(),
                        isSelected: _assignmentRoleFilter == 'primary',
                        onTap: () => setState(() => _assignmentRoleFilter = 'primary'),
                      ),
                      const SizedBox(width: 6),
                      _buildAssignmentFilterChip(
                        label: 'home.org.concurrent'.tr(),
                        isSelected: _assignmentRoleFilter == 'concurrent',
                        onTap: () => setState(() => _assignmentRoleFilter = 'concurrent'),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                      const SizedBox(width: 12),

                      // Status filter matching Web: Tất cả, Hoạt động, Không hoạt động, Đã kết thúc
                      _buildAssignmentFilterChip(
                        label: 'home.org.all_status'.tr(),
                        isSelected: _assignmentStatusFilter == 'ALL',
                        onTap: () => setState(() => _assignmentStatusFilter = 'ALL'),
                      ),
                      const SizedBox(width: 6),
                      _buildAssignmentFilterChip(
                        label: 'home.org.status_active'.tr(),
                        isSelected: _assignmentStatusFilter == 'active',
                        onTap: () => setState(() => _assignmentStatusFilter = 'active'),
                      ),
                      const SizedBox(width: 6),
                      _buildAssignmentFilterChip(
                        label: 'home.org.status_inactive'.tr(),
                        isSelected: _assignmentStatusFilter == 'inactive',
                        onTap: () => setState(() => _assignmentStatusFilter = 'inactive'),
                      ),
                      const SizedBox(width: 6),
                      _buildAssignmentFilterChip(
                        label: 'home.org.status_ended'.tr(),
                        isSelected: _assignmentStatusFilter == 'ended',
                        onTap: () => setState(() => _assignmentStatusFilter = 'ended'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 2. Assignment List
          if (filteredAssignments.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_search_outlined, size: 40, color: AppColors.slate300),
                    SizedBox(height: 8),
                    Text(
                      'home.org.no_assignments'.tr(),
                      style: TextStyle(fontSize: 13, color: AppColors.slate500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredAssignments.length,
              separatorBuilder: (context, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final assignment = filteredAssignments[index];
                final user = snapshot.users.firstWhere(
                  (u) => u.id == assignment.userId,
                  orElse: () => TenantUser(
                    id: assignment.userId,
                    fullName: 'home.org.employee'.tr(),
                    email: '',
                    systemRole: 'tenant-user',
                    status: 'active',
                    isActive: true,
                    createdAt: '',
                    updatedAt: '',
                  ),
                );
                final node = snapshot.nodes.firstWhere(
                  (n) => n.id == assignment.nodeId,
                  orElse: () => OrgNode(
                    id: assignment.nodeId,
                    treeId: 't-1',
                    nodeTypeId: 'nt-dept',
                    code: 'NODE',
                    name: 'home.org.unit'.tr(),
                    status: 'active',
                  ),
                );

                // Initials for avatar e.g. "QH", "TU", "NQ"
                final nameParts = user.fullName.trim().split(' ');
                final initials = nameParts.length >= 2
                    ? '${nameParts[nameParts.length - 2][0]}${nameParts.last[0]}'.toUpperCase()
                    : (user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U');

                final isPrimary = assignment.isPrimary;

                // Status configuration
                Color badgeBg;
                Color badgeBorder;
                Color badgeDot;
                Color badgeTextColor;
                String badgeLabel;

                if (assignment.status == 'active') {
                  badgeBg = const Color(0xFFECFDF5);
                  badgeBorder = const Color(0xFFA7F3D0);
                  badgeDot = const Color(0xFF059669);
                  badgeTextColor = const Color(0xFF059669);
                  badgeLabel = 'home.org.status_active'.tr();
                } else if (assignment.status == 'ended') {
                  badgeBg = const Color(0xFFF1F5F9);
                  badgeBorder = const Color(0xFFCBD5E1);
                  badgeDot = const Color(0xFF64748B);
                  badgeTextColor = const Color(0xFF64748B);
                  badgeLabel = 'home.org.status_ended'.tr();
                } else {
                  badgeBg = const Color(0xFFFEF2F2);
                  badgeBorder = const Color(0xFFFECACA);
                  badgeDot = const Color(0xFFDC2626);
                  badgeTextColor = const Color(0xFFDC2626);
                  badgeLabel = 'home.org.status_inactive'.tr();
                }

                // Date range duration
                String durationText = 'home.org.no_expiry'.tr();
                if (assignment.startDate != null || assignment.endDate != null) {
                  final startFormatted = assignment.startDate != null && assignment.startDate!.length >= 10
                      ? '${assignment.startDate!.substring(8, 10)}/${assignment.startDate!.substring(5, 7)}/${assignment.startDate!.substring(0, 4)}'
                      : '';
                  final endFormatted = assignment.endDate != null && assignment.endDate!.length >= 10
                      ? '${assignment.endDate!.substring(8, 10)}/${assignment.endDate!.substring(5, 7)}/${assignment.endDate!.substring(0, 4)}'
                      : '';
                  if (startFormatted.isNotEmpty && endFormatted.isNotEmpty) {
                    durationText = '$startFormatted - $endFormatted';
                  } else if (startFormatted.isNotEmpty) {
                    durationText = 'home.org.from_date'.tr(args: {'date': startFormatted});
                  } else if (endFormatted.isNotEmpty) {
                    durationText = 'home.org.to_date'.tr(args: {'date': endFormatted});
                  }
                }

                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Avatar + Name/Email + Role Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF), // Sky blue tint
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.email.isNotEmpty ? user.email : 'home.org.no_email'.tr(),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Role Badge (Kiêm nhiệm vs Bổ nhiệm chính)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPrimary ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isPrimary ? const Color(0xFF93C5FD) : const Color(0xFFFCD34D),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isPrimary ? 'home.org.primary_assignment'.tr() : 'home.org.concurrent'.tr(),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isPrimary ? const Color(0xFF1D4ED8) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Position title and code
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              node.code,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Meta details & Actions
                      Row(
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: badgeBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: badgeDot,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  badgeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Duration
                          Text(
                            '· $durationText',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),

                          if (assignment.note != null && assignment.note!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '· ${assignment.note}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                          ] else
                            const Spacer(),

                          // Edit & Delete actions
                          if (context.watch<AuthProvider>().canUpdateOrganization)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF64748B)),
                            tooltip: 'home.org.edit_assignment'.tr(),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            onPressed: () => _showCreateAppointmentDialog(snapshot, assignment),
                          ),
                          if (context.watch<AuthProvider>().canDeleteOrganization)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 17, color: Color(0xFFEF4444)),
                            tooltip: 'home.org.delete_assignment'.tr(),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            onPressed: () => _confirmDeleteAssignment(assignment, user.fullName, node.name),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 3. Footer Statistics matching Web
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'home.org.showing_assignments'.tr(args: {'shown': filteredAssignments.length, 'total': snapshot.assignments.length}),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                Text(
                  'home.org.primary_concurrent_count'.tr(args: {'primary': primaryCount, 'concurrent': concurrentCount}),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // MODAL: BỔ NHIỆM NGƯỜI DÙNG VÀO TỔ CHỨC
  void _showCreateAppointmentDialog(OrganizationSnapshot snapshot, [OrgAssignment? existing]) {
    showOrgAppointmentDialog(
      context: context,
      platformService: widget.platformService,
      onRefresh: widget.onRefresh,
      snapshot: snapshot,
      existing: existing,
    );
  }

  // DELETE ASSIGNMENT CONFIRMATION
  void _confirmDeleteAssignment(OrgAssignment assignment, String userName, String nodeName) {
    confirmDeleteOrgAssignment(
      context: context,
      platformService: widget.platformService,
      onRefresh: widget.onRefresh,
      assignment: assignment,
      userName: userName,
      nodeName: nodeName,
    );
  }
}
