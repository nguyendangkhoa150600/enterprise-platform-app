import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/i18n/app_i18n.dart';
import '../shared/widgets/no_access_view.dart';
import '../models/platform_models.dart';
import '../providers/auth_provider.dart';
import '../services/platform_service.dart';
import '../features/workspace/presentation/widgets/searchable_dropdown_field.dart';

part 'role_permission/components/role_detail_sheet.dart';
part 'role_permission/components/permission_detail_sheet.dart';
part 'role_permission/components/permission_form_sheets.dart';
part 'role_permission/components/role_form_sheets.dart';

class RolePermissionScreen extends StatefulWidget {
  const RolePermissionScreen({super.key});

  @override
  State<RolePermissionScreen> createState() => _RolePermissionScreenState();
}

class _RolePermissionScreenState extends State<RolePermissionScreen> with SingleTickerProviderStateMixin {
  final PlatformService _platformService = PlatformService();
  late TabController _tabController;
  final ScrollController _rolesScrollController = ScrollController();

  bool _isLoading = true;
  List<TenantRole> _roles = [];
  List<TenantPermission> _permissions = [];
  List<TenantUser> _users = [];
  List<ModuleCatalogItem> _modules = [];

  TenantRole? _selectedRole;
  String _searchQuery = '';
  String _permissionSearchQuery = '';
  String _roleFilter = 'system'; // 'system' | 'custom'
  final Map<String, String> _roleDetailTabMap = {};
  String? _selectedMemberUserIdToAdd;
  bool _isAssigningMember = false;

  /// The role detail bottom sheet is built once by showModalBottomSheet, so it must be told to rebuild
  /// whenever this screen's state changes (picked user, assigning flag, reloaded roles...).
  final ValueNotifier<int> _sheetTick = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _sheetTick.value++;
  }

  // ignore: unused_element
  List<Map<String, dynamic>> get _moduleDefs {
    if (_modules.isEmpty) return const [];
    final known = {for (final d in _presentationModuleDefs) d['key']: d};
    return _modules.map((m) {
      final k = known[m.key];
      return <String, dynamic>{
        'key': m.key,
        'name': m.name.isNotEmpty ? m.name : (k?['name'] ?? m.key),
        'desc': m.description.isNotEmpty ? m.description : (k?['desc'] ?? ''),
        'icon': k?['icon'] ?? Icons.apps_outlined,
        'color': k?['color'] ?? const Color(0xFF2563EB),
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _presentationModuleDefs => [
    {
      'key': 'hrm',
      'name': 'roles.module_hrm_name'.tr(),
      'desc': 'roles.module_hrm_desc'.tr(),
      'icon': Icons.layers_outlined,
      'color': const Color(0xFF2563EB),
    },
    {
      'key': 'inventory',
      'name': 'Inventory',
      'desc': 'roles.module_inventory_desc'.tr(),
      'icon': Icons.inventory_2_outlined,
      'color': const Color(0xFF4F46E5),
    },
    {
      'key': 'maintenance',
      'name': 'Maintenance',
      'desc': 'roles.module_maintenance_desc'.tr(),
      'icon': Icons.build_outlined,
      'color': const Color(0xFF2563EB),
    },
    {
      'key': 'procedure-engine',
      'name': 'Procedure Engine',
      'desc': 'roles.module_procedure_desc'.tr(),
      'icon': Icons.account_tree_outlined,
      'color': const Color(0xFF4F46E5),
    },
    {
      'key': 'workspace',
      'name': 'Workspace',
      'desc': 'roles.module_workspace_desc'.tr(),
      'icon': Icons.dashboard_outlined,
      'color': const Color(0xFF2563EB),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _sheetTick.dispose();
    _tabController.dispose();
    _rolesScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _platformService.getTenantRoles(),
        _platformService.getTenantPermissions(),
        _platformService.getTenantUsers(),
        _platformService.getModuleCatalog(),
      ]);

      setState(() {
        _roles = results[0] as List<TenantRole>;
        _permissions = results[1] as List<TenantPermission>;
        _users = results[2] as List<TenantUser>;
        _modules = results[3] as List<ModuleCatalogItem>;

        if (_roles.isNotEmpty && (_selectedRole == null || !_roles.any((r) => r.id == _selectedRole!.id))) {
          _selectedRole = _roles.first;
        } else if (_roles.isNotEmpty && _selectedRole != null) {
          _selectedRole = _roles.firstWhere((r) => r.id == _selectedRole!.id, orElse: () => _roles.first);
        }
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<TenantRole> get _filteredRoles {
    return _roles.where((role) {
      final matchesSearch = _searchQuery.isEmpty ||
          role.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          role.key.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (role.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      if (!matchesSearch) return false;

      if (_roleFilter == 'system') return role.isSystem;
      if (_roleFilter == 'custom') return !role.isSystem;
      return true;
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    // Same rule as the web: the authorization page needs tenant.manage.
    final canManage = auth.canManageTenant;
    if (!auth.canViewRoles) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, elevation: 0),
      body: NoAccessView(message: 'perm.no_access_roles'.tr()),
    );
    }

    final systemRoleCount = _roles.where((r) => r.isSystem).length;
    final customRoleCount = _roles.where((r) => !r.isSystem).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'roles.breadcrumb'.tr(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'roles.title'.tr(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF475569)),
            tooltip: 'common.refresh'.tr(),
            onPressed: _loadData,
          ),
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  final isPermTab = _tabController.index == 1;
                  return ElevatedButton.icon(
                    onPressed: () => isPermTab
                        ? _showCreatePermissionSheet(context)
                        : _showCreateRoleSheet(context),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: Text(
                      isPermTab ? 'Táº¡o permission' : 'roles.create_role'.tr(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPermTab ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : Column(
              children: [
                // Top Fixed 2 Tab Lá»›n (Cá»‘ Ä‘á»‹nh á»Ÿ Ä‘á»‰nh, luÃ´n luÃ´n nhÃ¬n tháº¥y)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) => _buildLargeTabs(),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // 2 MÃ n hÃ¬nh Ä‘á»™c láº­p (Chuyá»ƒn Ä‘á»•i qua láº¡i khi switch tab)
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // MÃ n hÃ¬nh 1: Quáº£n trá»‹ Vai trÃ² (Full Screen)
                      _buildRolesScreen(canManage, systemRoleCount, customRoleCount),

                      // MÃ n hÃ¬nh 2: Quáº£n trá»‹ Permission (Full Screen)
                      _buildPermissionsScreen(canManage),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLargeTabs() {
    final selectedIndex = _tabController.index;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Slate 100
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Tab 1: Vai trÃ²
          Expanded(
            child: _buildLargeTabItem(
              icon: Icons.shield_outlined,
              label: 'Vai trÃ²',
              count: _roles.length,
              isSelected: selectedIndex == 0,
              badgeBg: selectedIndex == 0 ? const Color(0xFFFEF08A) : const Color(0xFFE2E8F0),
              badgeFg: selectedIndex == 0 ? const Color(0xFF854D0E) : const Color(0xFF64748B),
              onTap: () {
                _tabController.animateTo(0);
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 4),
          // Tab 2: Permission
          Expanded(
            child: _buildLargeTabItem(
              icon: Icons.vpn_key_outlined,
              label: 'Permission',
              count: _permissions.length,
              isSelected: selectedIndex == 1,
              badgeBg: selectedIndex == 1 ? const Color(0xFFF3E8FF) : const Color(0xFFE2E8F0),
              badgeFg: selectedIndex == 1 ? const Color(0xFF6B21A8) : const Color(0xFF64748B),
              onTap: () {
                _tabController.animateTo(1);
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeTabItem({
    required IconData icon,
    required String label,
    required int count,
    required bool isSelected,
    required Color badgeBg,
    required Color badgeFg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(int systemCount, int customCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFEFF6FF),
                    title: 'roles.stat_total_roles'.tr(),
                    value: '${_roles.length}',
                    subtext: 'roles.stat_total_roles_sub'.tr(args: {'system': systemCount, 'custom': customCount}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.vpn_key_outlined,
                    iconColor: const Color(0xFF9333EA),
                    iconBg: const Color(0xFFFAF5FF),
                    title: 'roles.stat_permission'.tr(),
                    value: '${_permissions.length}',
                    subtext: 'roles.stat_permission_sub'.tr(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.layers_outlined,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFECFDF5),
                    title: 'roles.stat_modules'.tr(),
                    value: '${_modules.where((m) => m.isActive).length} / ${_modules.length}',
                    subtext: 'kÃ­ch hoáº¡t',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.people_outline,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFF5F3FF),
                    title: 'roles.stat_users'.tr(),
                    value: '${_users.length}',
                    subtext: 'ngÆ°á»i dÃ¹ng',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (subtext.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 1.5),
                          child: Text(
                            subtext,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesScreen(bool canManage, int systemRoleCount, int customRoleCount) {
    final filtered = _filteredRoles;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2563EB),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Banner giá»›i thiá»‡u
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'roles.intro'.tr(),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4 Stat Cards Grid (2x2)
          _buildStatCards(systemRoleCount, customRoleCount),
          const SizedBox(height: 16),

          // Search & Filter Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'roles.search_hint'.tr(),
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),

                // 2 Tab nhá» trong tab Vai trÃ²: Vai trÃ² há»‡ thá»‘ng & Vai trÃ² tÃ¹y chá»‰nh
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() => _roleFilter = 'system');
                            if (_rolesScrollController.hasClients) {
                              _rolesScrollController.jumpTo(0);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _roleFilter == 'system' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _roleFilter == 'system'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
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
                                  Icons.verified_user_outlined,
                                  size: 15,
                                  color: _roleFilter == 'system' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Vai trÃ² há»‡ thá»‘ng',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: _roleFilter == 'system' ? FontWeight.w700 : FontWeight.w500,
                                    color: _roleFilter == 'system' ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: _roleFilter == 'system' ? const Color(0xFFEFF6FF) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$systemRoleCount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _roleFilter == 'system' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() => _roleFilter = 'custom');
                            if (_rolesScrollController.hasClients) {
                              _rolesScrollController.jumpTo(0);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _roleFilter == 'custom' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _roleFilter == 'custom'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
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
                                  Icons.tune_rounded,
                                  size: 15,
                                  color: _roleFilter == 'custom' ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Vai trÃ² tÃ¹y chá»‰nh',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: _roleFilter == 'custom' ? FontWeight.w700 : FontWeight.w500,
                                    color: _roleFilter == 'custom' ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: _roleFilter == 'custom' ? const Color(0xFFFEF3C7) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$customRoleCount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _roleFilter == 'custom' ? const Color(0xFFB45309) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Danh sÃ¡ch cÃ¡c vai trÃ² (Cuá»™n tá»± do, khÃ´ng bá»‹ bÃ³ cá»©ng)
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.shield_outlined, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('roles.not_found'.tr(), style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
                ],
              ),
            )
          else
            ...filtered.map((role) {
              final isSelected = _selectedRole?.id == role.id;
              return _buildRoleCardItem(role, isSelected, canManage);
            }),
        ],
      ),
    );
  }

  Widget _buildRoleCardItem(TenantRole role, bool isSelected, bool canManage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF2563EB).withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            setState(() => _selectedRole = role);
            _showRoleDetailModal(role, canManage);
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      role.isSystem ? Icons.verified_user_outlined : Icons.shield_outlined,
                      size: 16,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : (role.isSystem ? const Color(0xFF3B82F6) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        role.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildSystemBadge(role.isSystem),
                  ],
                ),
                if (role.description?.isNotEmpty == true &&
                    role.description != 'roles.no_description'.tr() &&
                    role.description != 'KhÃ´ng cÃ³ mÃ´ táº£ chi tiáº¿t.') ...[
                  const SizedBox(height: 4),
                  Text(
                    role.description!,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    _buildTagChip(
                      icon: Icons.person_outline,
                      text: 'roles.users_count'.tr(args: {'count': role.userIds.length}),
                    ),
                    const SizedBox(width: 6),
                    _buildTagChip(
                      icon: Icons.widgets_outlined,
                      text: role.moduleKeys.contains('*')
                          ? 'roles.all_modules'.tr()
                          : 'roles.modules_count'.tr(args: {'count': role.moduleKeys.length}),
                    ),
                    const Spacer(),
                    Text(
                      'Chi tiáº¿t',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 1),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildPermissionsScreen(bool canManage) {
    final filtered = _permissions.where((p) {
      if (_permissionSearchQuery.isEmpty) return true;
      final q = _permissionSearchQuery.toLowerCase();
      final matchName = p.name.toLowerCase().contains(q);
      final matchKey = p.key?.toLowerCase().contains(q) ?? false;
      final matchDesc = p.description?.toLowerCase().contains(q) ?? false;
      final matchAction = p.actionKeys.any((a) => a.toLowerCase().contains(q));
      return matchName || matchKey || matchDesc || matchAction;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2563EB),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Banner Permission Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.vpn_key_outlined, color: Color(0xFF9333EA), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Danh má»¥c Permission TiÃªu chuáº©n',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Há»‡ thá»‘ng gá»“m ${_permissions.length} quyá»n tiÃªu chuáº©n quáº£n lÃ½ cÃ¡c hÃ nh Ä‘á»™ng cá»‘t lÃµi vÃ  module.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Box Permission
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'TÃ¬m theo tÃªn quyá»n, mÃ£ permission, hÃ nh Ä‘á»™ng...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF9333EA)),
                ),
              ),
              onChanged: (val) => setState(() => _permissionSearchQuery = val.trim()),
            ),
          ),
          const SizedBox(height: 14),

          // Danh sÃ¡ch Permission Cards
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.vpn_key_outlined, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  const Text('KhÃ´ng tÃ¬m tháº¥y permission phÃ¹ há»£p', style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5)),
                ],
              ),
            )
          else
            ...filtered.map((perm) {
              final usedRoles = _roles.where((r) {
                return r.permissionIds.contains(perm.id) ||
                    perm.roleIds.contains(r.id) ||
                    (r.key.isNotEmpty && perm.roleIds.contains(r.key)) ||
                    (perm.actionKeys.isNotEmpty && r.actionKeys.any((a) => perm.actionKeys.contains(a))) ||
                    (perm.key != null && perm.key!.isNotEmpty && r.actionKeys.contains(perm.key));
              }).toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showPermissionDetailModal(perm, canManage),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.vpn_key_outlined, color: Color(0xFF9333EA), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      perm.name,
                                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${usedRoles.length} vai trÃ²   â€¢   ${perm.actionKeys.length} hÃ nh Ä‘á»™ng',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildSystemBadge(perm.isSystem),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
                                ],
                              ),
                            ],
                          ),
                          if (perm.description != null && perm.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              perm.description!,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSystemBadge(bool isSystem) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSystem ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isSystem ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE)),
      ),
      child: Text(
        isSystem ? 'roles.system'.tr() : 'roles.custom'.tr(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSystem ? const Color(0xFF64748B) : const Color(0xFF2563EB),
        ),
      ),
    );
  }

  Widget _buildTagChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }



  String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[Ã Ã¡áº¡áº£Ã£Ã¢áº§áº¥áº­áº©áº«Äƒáº±áº¯áº·áº³áºµ]'), 'a')
        .replaceAll(RegExp(r'[Ã¨Ã©áº¹áº»áº½Ãªá»áº¿á»‡á»ƒá»…]'), 'e')
        .replaceAll(RegExp(r'[Ã¬Ã­á»‹á»‰Ä©]'), 'i')
        .replaceAll(RegExp(r'[Ã²Ã³á»á»ÃµÃ´á»“á»‘á»™á»•á»—Æ¡á»á»›á»£á»Ÿá»¡]'), 'o')
        .replaceAll(RegExp(r'[Ã¹Ãºá»¥á»§Å©Æ°á»«á»©á»±á»­á»¯]'), 'u')
        .replaceAll(RegExp(r'[á»³Ã½á»µá»·á»¹]'), 'y')
        .replaceAll(RegExp(r'[Ä‘]'), 'd')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }
}
