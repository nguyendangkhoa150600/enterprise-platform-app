import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/platform_models.dart';
import '../providers/auth_provider.dart';
import '../services/platform_service.dart';
import '../services/module_business_service.dart';
import '../core/permissions/hrm_permissions.dart';
import '../shared/widgets/no_access_view.dart';
import './home/components/home_module_stats.dart';
import '../theme/colors.dart';
import './inventory_screen.dart';
import './main_analysis_screen.dart';
import './maintenance_screen.dart';
import './procedure_screen.dart';
import './attendance_screen.dart';
import './hrm_hub_screen.dart';
import './login_screen.dart';
import './role_permission_screen.dart';
import './user_management_screen.dart';
import './my_requests_screen.dart';
import './workspace_screen.dart';
import './assistant_chat_screen.dart';
import './home/components/home_mobile_profile_view.dart';
import './home/components/home_mobile_modules_view.dart';
import './home/components/home_organization_view.dart';
import './home/components/home_desktop_users_view.dart';
import './home/components/home_mobile_dashboard_view.dart';
import './home/components/home_desktop_dashboard_view.dart';
import '../core/i18n/app_i18n.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Navigation states
  int _mobileNavIndex = 0; // 0: Home, 1: Modules, 2: People, 3: Profile
  String _desktopTab = 'Dashboard';

  final PlatformService _platformService = PlatformService();

  // Data states
  List<TenantUser> _users = [];
  List<ModuleCatalogItem> _modules = [];
  OrganizationSnapshot? _orgSnapshot;
  bool _isLoadingData = false;
  HomeModuleStats? _moduleStats;
  final ModuleBusinessService _businessService = ModuleBusinessService();

  final ScrollController _attentionScrollController = ScrollController();
  final ScrollController _homeOrgScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAllPlatformData();
  }

  @override
  void dispose() {
    _attentionScrollController.dispose();
    _homeOrgScrollController.dispose();
    super.dispose();
  }

  bool _canAttend(BuildContext context) =>
      _hasModule('hrm') && context.watch<HrmCapabilities>().pageAllowed('/my-work');

  /// The catalog is already filtered by the server to the modules this user's roles can open.
  bool _hasModule(String key) => _modules.any((m) => m.key == key && m.isActive);

  Future<void> _loadAllPlatformData() async {
    setState(() => _isLoadingData = true);
    final results = await Future.wait([
      _platformService.getTenantUsers(),
      _platformService.getModuleCatalog(),
      _platformService.getOrganizationSnapshot(),
      HomeModuleStats.load(_businessService),
      HrmCapabilities.instance.load(force: true),
    ]);

    if (mounted) {
      setState(() {
        _users = results[0] as List<TenantUser>;
        _modules = results[1] as List<ModuleCatalogItem>;
        _orgSnapshot = results[2] as OrganizationSnapshot;
        _moduleStats = results[3] as HomeModuleStats;
        _isLoadingData = false;
      });
    }
  }


  void _openModule(String key) {
    if (key == 'procedure' || key == 'procedure-engine') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen()));
    } else if (key == 'inventory') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
    } else if (key == 'maintenance') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen()));
    } else if (key == 'power-quality') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MainAnalysisScreen()));
    } else if (key == 'hrm' || key == 'human-resource') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen()));
    } else if (key == 'attendance' || key == 'hrm-attendance') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
    } else if (key == 'requests' || key == 'hrm-requests' || key == 'my-requests' || key == 'don-tu') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRequestsScreen()));
    } else if (key == 'approvals' || key == 'hrm-approvals') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 2)));
    } else if (key == 'employees' || key == 'shifts' || key == 'payslips') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 3)));
    } else if (key == 'roles' || key == 'permissions' || key == 'role-permission' || key == 'authorization' || key == 'rbac') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePermissionScreen()));
    } else if (key == 'my-tasks' || key == 'cong-viec-cua-toi') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 0)));
    } else if (key == 'tasks' || key == 'standalone-tasks' || key == 'cong-viec' || key == 'other-tasks' || key == 'cong-viec-khac') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 1)));
    } else if (key == 'workspace' || key == 'projects' || key == 'project' || key == 'du-an') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 2)));
    } else if (key == 'customers' || key == 'contracts' || key == 'khach-hang' || key == 'hop-dong') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 3)));
    } else if (key == 'documents' || key == 'tai-lieu') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 4)));
    } else if (key == 'workspace-reports' || key == 'bao-cao-cong-viec') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 5)));
    } else if (key == 'assistant' || key == 'savina-agent' || key == 'ai' || key == 'tro-ly') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantChatScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('home_shell.module_preparing'.tr(args: {'key': key}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.fullName ?? 'home_shell.default_admin'.tr();
    final userInitials = userName.isNotEmpty ? userName[0].toUpperCase() : 'A';
    final tenantDisplay = (authProvider.tenantSlug ?? 'svn').toUpperCase();

    if (isDesktop) {
      return _buildDesktopLayout(authProvider, userName, userInitials, tenantDisplay);
    }

    // Mobile / Tablet layout
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildMobileDrawer(authProvider, userName, userInitials, tenantDisplay),
      body: SafeArea(
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllPlatformData,
                child: _buildMobileBody(userName, userInitials, tenantDisplay),
              ),
      ),
      bottomNavigationBar: _buildMobileBottomBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AssistantChatScreen()),
        ),
        elevation: 4,
        shape: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.auto_awesome, size: 24, color: Colors.white),
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE NAVIGATION & BODY
  // ==========================================
  // ==========================================
  // MOBILE NAVIGATION & BODY
  // ==========================================
  Widget _buildMobileBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Row of 4 Navigation Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Tab 0: Trang chủ
                  _buildBottomNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'home_shell.nav.home'.tr(),
                    isSelected: _mobileNavIndex == 0,
                    onTap: () => setState(() => _mobileNavIndex = 0),
                  ),

                  // Tab 1: Phân hệ
                  _buildBottomNavItem(
                    icon: Icons.apps_outlined,
                    activeIcon: Icons.apps,
                    label: 'home_shell.nav.modules'.tr(),
                    isSelected: _mobileNavIndex == 1,
                    onTap: () => setState(() => _mobileNavIndex = 1),
                  ),

                  // Space in center for raised button
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _canAttend(context) ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())) : null,
                    child: const SizedBox(width: 68, height: 66),
                  ),

                  // Tab 2: Sơ đồ tổ chức (needs core.organization.read, like the web)
                  if (context.watch<AuthProvider>().canViewOrganization)
                    _buildBottomNavItem(
                      icon: Icons.account_tree_outlined,
                      activeIcon: Icons.account_tree,
                      label: 'home_shell.nav.org'.tr(),
                      isSelected: _mobileNavIndex == 2,
                      onTap: () => setState(() => _mobileNavIndex = 2),
                    )
                  else
                    const SizedBox(width: 56),

                  // Tài khoản
                  _buildBottomNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'home_shell.nav.account'.tr(),
                    isSelected: _mobileNavIndex == 3,
                    onTap: () => setState(() => _mobileNavIndex = 3),
                  ),
                ],
              ),

              // Raised Center Button: Chấm công (needs the HRM module and hrm.self.read, like the web "Công của tôi")
              if (_canAttend(context))
              Positioned(
                top: -18,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2563EB), // Blue 600
                              Color(0xFF1D4ED8), // Blue 700
                            ],
                          ),
                          border: Border.all(color: Colors.white, width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'home_shell.nav.attendance'.tr(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
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

  Widget _buildBottomNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBody(String userName, String userInitials, String tenantDisplay) {
    switch (_mobileNavIndex) {
      case 0:
        return _buildMobileDashboardView(userName, userInitials, tenantDisplay);
      case 1:
        return _buildMobileModulesView();
      case 2:
        return _buildMobilePeopleView();
      case 3:
        return _buildMobileProfileView(userName, userInitials, tenantDisplay);
      default:
        return _buildMobileDashboardView(userName, userInitials, tenantDisplay);
    }
  }

  // ==========================================
  // MOBILE VIEW 1: HOME DASHBOARD (Synchronized with React Web)
  // ==========================================
  Widget _buildMobileDashboardView(String userName, String userInitials, String tenantDisplay) {
    return HomeMobileDashboardView(
      userName: userName,
      userInitials: userInitials,
      tenantDisplay: tenantDisplay,
      users: _users,
      modules: _modules,
      orgSnapshot: _orgSnapshot,
      isLoadingData: _isLoadingData,
      moduleStats: _moduleStats,
      attentionScrollController: _attentionScrollController,
      homeOrgScrollController: _homeOrgScrollController,
      onOpenModule: _openModule,
      onNavigateTab: (idx) => setState(() => _mobileNavIndex = idx),
    );
  }

  // ==========================================
  // MOBILE VIEW 2: MODULES CATALOG (GRID MENU STYLE LIKE IMAGE 1)
  // ==========================================
  Widget _buildMobileModulesView() {
    return HomeMobileModulesView(
      modules: _modules,
      modulesLoaded: !_isLoadingData,
      onSelectOrgChart: () => setState(() => _mobileNavIndex = 2),
      onOpenDashboard: () => setState(() => _mobileNavIndex = 0),
      onOpenModule: _openModule,
    );
  }

  // ==========================================
  // MOBILE VIEW 3: SƠ ĐỒ TỔ CHỨC (ORGANIZATION STRUCTURE)
  // ==========================================
  Widget _buildMobilePeopleView() {
    if (!context.read<AuthProvider>().canViewOrganization) {
      return NoAccessView(message: 'perm.no_access_org'.tr());
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: _buildOrganizationView(),
    );
  }

  // ==========================================
  // MOBILE VIEW 4: PROFILE & SETTINGS
  // ==========================================
  Widget _buildMobileProfileView(String userName, String userInitials, String tenantDisplay) {
    return HomeMobileProfileView(
      userName: userName,
      userInitials: userInitials,
      tenantDisplay: tenantDisplay,
    );
  }

  // ==========================================
  // MOBILE NAVIGATION DRAWER (1:1 Web Sidebar)
  // ==========================================
  Widget _buildMobileDrawer(AuthProvider auth, String userName, String userInitials, String tenantDisplay) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            // Header with tenant info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        userInitials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Quản trị viên · $tenantDisplay',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation List matching 1:1 Web Sidebar
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                children: [
                  // MỤC 1: TỔNG QUAN & ỨNG DỤNG
                  _buildDrawerSectionTitle('TỔNG QUAN & ỨNG DỤNG'),
                  _buildDrawerItem(
                    title: 'Bảng điều khiển',
                    icon: Icons.grid_view_outlined,
                    isSelected: _mobileNavIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _mobileNavIndex = 0);
                    },
                  ),
                  _buildDrawerItem(
                    title: 'Ứng dụng phân hệ',
                    icon: Icons.inventory_2_outlined,
                    isSelected: _mobileNavIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _mobileNavIndex = 1);
                    },
                  ),

                  const SizedBox(height: 18),

                  // MỤC 2: TỔ CHỨC & BỘ MÁY
                  if (auth.canViewOrganization) ...[
                    _buildDrawerSectionTitle('TỔ CHỨC & BỘ MÁY'),
                    _buildDrawerItem(
                      title: 'Sơ đồ tổ chức',
                      icon: Icons.alt_route_rounded,
                      isSelected: _mobileNavIndex == 2,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _mobileNavIndex = 2);
                      },
                    ),
                    const SizedBox(height: 18),
                  ],

                  // MỤC 3: QUẢN TRỊ DANH TÍNH & TRUY CẬP
                  if (auth.canViewUsers || auth.canViewRoles) ...[
                    _buildDrawerSectionTitle('QUẢN TRỊ DANH TÍNH & TRUY CẬP'),
                    if (auth.canViewUsers)
                      _buildDrawerItem(
                        title: 'Tài khoản người dùng',
                        icon: Icons.people_outline,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()));
                        },
                      ),
                    if (auth.canViewRoles)
                      _buildDrawerItem(
                        title: 'Vai trò & phân quyền',
                        icon: Icons.shield_outlined,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePermissionScreen()));
                        },
                      ),
                  ],
                ],
              ),
            ),

            // Logout Footer
            const Divider(color: Color(0xFF1E293B), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () async {
                  await auth.logout();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1E293B)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.white60, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Đăng xuất',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required String title,
    required IconData icon,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DESKTOP LAYOUT (Preserved for tablets / PCs)
  // ==========================================
  Widget _buildDesktopLayout(AuthProvider authProvider, String userName, String userInitials, String tenantDisplay) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: Row(
        children: [
          _buildSidebar(authProvider),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(userName, userInitials),
                Expanded(
                  child: _isLoadingData
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _loadAllPlatformData,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: _buildCurrentTabView(userName),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTabView(String userName) {
    switch (_desktopTab) {
      case 'Dashboard':
        return _buildDashboardView(userName);
      case 'Ứng dụng':
        return _buildApplicationsView();
      case 'Sơ đồ tổ chức':
        return _buildOrganizationView();
      case 'Người dùng':
        return _buildUsersView();
      case 'Vai trò & Phân quyền':
        return const RolePermissionScreen();
      case 'Báo cáo':
        return const MainAnalysisScreen();
      case 'Cài đặt':
        return _buildSettingsView();
      default:
        return _buildDashboardView(userName);
    }
  }

  // Desktop Sidebar
  Widget _buildSidebar(AuthProvider auth) {
    final tenantDisplay = (auth.tenantSlug ?? 'svn').toLowerCase();

    return Container(
      width: 260,
      color: AppColors.slate900,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.slate800)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('E', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enterprise Portal',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'home_shell.tenant_admin_label'.tr(args: {'tenant': tenantDisplay}),
                        style: const TextStyle(color: AppColors.slate400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildDesktopMenuItem('Dashboard', Icons.dashboard_outlined),
                _buildDesktopMenuItem('Ứng dụng', Icons.apps_outlined),
                if (auth.canViewOrganization) _buildDesktopMenuItem('Sơ đồ tổ chức', Icons.account_tree_outlined),
                if (auth.canViewUsers) _buildDesktopMenuItem('Người dùng', Icons.people_outline),
                if (auth.canViewRoles) _buildDesktopMenuItem('Vai trò & Phân quyền', Icons.verified_user_outlined),

                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'home_shell.section_modules'.tr(),
                    style: TextStyle(color: AppColors.slate500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                if (_hasModule('workspace')) _buildModuleShortcut('home_shell.shortcut.workspace'.tr(), Icons.work_outline, 'workspace'),
                if (_hasModule('procedure-engine') || _hasModule('procedure')) _buildModuleShortcut('home_shell.shortcut.procedure'.tr(), Icons.account_tree, 'procedure'),
                if (_hasModule('inventory')) _buildModuleShortcut('home_shell.shortcut.inventory'.tr(), Icons.inventory_2, 'inventory'),
                if (_hasModule('maintenance')) _buildModuleShortcut('home_shell.shortcut.maintenance'.tr(), Icons.build, 'maintenance'),
                _buildModuleShortcut('home_shell.shortcut.analysis'.tr(), Icons.analytics, 'power-quality'),

                const SizedBox(height: 8),
                const Divider(color: AppColors.slate800, height: 1),
                const SizedBox(height: 8),

                _buildDesktopMenuItem('Báo cáo', Icons.assessment_outlined),
                _buildDesktopMenuItem('Cài đặt', Icons.settings_outlined),
              ],
            ),
          ),
          const Divider(color: AppColors.slate800, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: () async {
                await auth.logout();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.slate800),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.white60, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'home_shell.logout'.tr(),
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _tabLabel(String id) {
    switch (id) {
      case 'Dashboard':
        return 'home_shell.tab.dashboard'.tr();
      case 'Ứng dụng':
        return 'home_shell.tab.apps'.tr();
      case 'Sơ đồ tổ chức':
        return 'home_shell.tab.org'.tr();
      case 'Người dùng':
        return 'home_shell.tab.users'.tr();
      case 'Vai trò & Phân quyền':
        return 'home_shell.tab.roles'.tr();
      case 'Báo cáo':
        return 'home_shell.tab.reports'.tr();
      case 'Cài đặt':
        return 'home_shell.tab.settings'.tr();
      default:
        return id;
    }
  }

  Widget _buildDesktopMenuItem(String title, IconData icon) {
    final isActive = _desktopTab == title;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: isActive ? Colors.white : AppColors.slate400, size: 18),
        title: Text(
          _tabLabel(title),
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.slate300,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isActive,
        selectedTileColor: Colors.white.withOpacity(0.08),
        onTap: () => setState(() => _desktopTab = title),
      ),
    );
  }

  Widget _buildModuleShortcut(String title, IconData icon, String moduleKey) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: AppColors.emerald, size: 18),
        title: Text(title, style: const TextStyle(color: AppColors.slate300, fontSize: 12.5)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.slate500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => _openModule(moduleKey),
      ),
    );
  }

  // Header
  Widget _buildHeader(String name, String initials) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.slate200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                _tabLabel(_desktopTab),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.slate600, size: 20),
                tooltip: 'home_shell.reload_data'.tr(),
                onPressed: _loadAllPlatformData,
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: AppColors.slate200, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(color: AppColors.slate800, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Desktop Dashboard
  Widget _buildDashboardView(String userName) {
    return HomeDesktopDashboardView(
      userName: userName,
      users: _users,
      modules: _modules,
      onOpenModule: _openModule,
      onSelectTab: (tab) => setState(() => _desktopTab = tab),
    );
  }

  // Applications
  Widget _buildApplicationsView() {
    return HomeDesktopApplicationsView(
      modules: _modules,
      platformService: _platformService,
      onOpenModule: _openModule,
      onRefresh: _loadAllPlatformData,
    );
  }

  // Users Management
  Widget _buildUsersView() {
    return HomeDesktopUsersView(
      users: _users,
      platformService: _platformService,
      onRefresh: _loadAllPlatformData,
    );
  }

  Widget _buildOrganizationView() {
    return HomeOrganizationView(
      snapshot: _orgSnapshot,
      platformService: _platformService,
      onRefresh: _loadAllPlatformData,
    );
  }

  Widget _buildSettingsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.settings_outlined, size: 48, color: AppColors.slate300),
          const SizedBox(height: 12),
          Text('home_shell.settings.title'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800)),
          const SizedBox(height: 4),
          Text('home_shell.settings.subtitle'.tr(), style: TextStyle(fontSize: 12, color: AppColors.slate500)),
        ],
      ),
    );
  }
}

