import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/platform_models.dart';
import '../providers/auth_provider.dart';
import '../services/platform_service.dart';
import '../theme/colors.dart';
import './inventory_screen.dart';
import './main_analysis_screen.dart';
import './maintenance_screen.dart';
import './procedure_screen.dart';
import './attendance_screen.dart';
import './hrm_hub_screen.dart';
import './login_screen.dart';
import './role_permission_screen.dart';
import './my_requests_screen.dart';
import './workspace_screen.dart';
import './assistant_chat_screen.dart';
import './home/components/home_mobile_profile_view.dart';
import './home/components/home_mobile_modules_view.dart';
import './home/components/home_organization_view.dart';
import './home/components/home_desktop_users_view.dart';
import './home/components/home_mobile_dashboard_view.dart';
import './home/components/home_desktop_dashboard_view.dart';

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

  Future<void> _loadAllPlatformData() async {
    setState(() => _isLoadingData = true);
    final results = await Future.wait([
      _platformService.getTenantUsers(),
      _platformService.getModuleCatalog(),
      _platformService.getOrganizationSnapshot(),
    ]);

    if (mounted) {
      setState(() {
        _users = results[0] as List<TenantUser>;
        _modules = results[1] as List<ModuleCatalogItem>;
        _orgSnapshot = results[2] as OrganizationSnapshot;
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
    } else if (key == 'workspace' || key == 'projects' || key == 'project') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 0)));
    } else if (key == 'customers' || key == 'contracts') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 1)));
    } else if (key == 'tasks' || key == 'standalone-tasks' || key == 'cong-viec') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 2)));
    } else if (key == 'assistant' || key == 'savina-agent' || key == 'ai' || key == 'tro-ly') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantChatScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ph�n h? "$key" dang chu?n b? kh?i ch?y.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.fullName ?? 'Qu?n tr? vi�n';
    final userInitials = userName.isNotEmpty ? userName[0].toUpperCase() : 'A';
    final tenantDisplay = (authProvider.tenantSlug ?? 'svn').toUpperCase();

    if (isDesktop) {
      return _buildDesktopLayout(authProvider, userName, userInitials, tenantDisplay);
    }

    // Mobile / Tablet layout
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                  // Tab 0: Trang ch?
                  _buildBottomNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Trang ch?',
                    isSelected: _mobileNavIndex == 0,
                    onTap: () => setState(() => _mobileNavIndex = 0),
                  ),

                  // Tab 1: Ph�n h?
                  _buildBottomNavItem(
                    icon: Icons.apps_outlined,
                    activeIcon: Icons.apps,
                    label: 'Ph�n h?',
                    isSelected: _mobileNavIndex == 1,
                    onTap: () => setState(() => _mobileNavIndex = 1),
                  ),

                  // Space in center for raised button
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                    child: const SizedBox(width: 68, height: 66),
                  ),

                  // Tab 2: So d? t? ch?c
                  _buildBottomNavItem(
                    icon: Icons.account_tree_outlined,
                    activeIcon: Icons.account_tree,
                    label: 'So d? t? ch?c',
                    isSelected: _mobileNavIndex == 2,
                    onTap: () => setState(() => _mobileNavIndex = 2),
                  ),

                  // Tab 3: T�i kho?n
                  _buildBottomNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'T�i kho?n',
                    isSelected: _mobileNavIndex == 3,
                    onTap: () => setState(() => _mobileNavIndex = 3),
                  ),
                ],
              ),

              // Raised Center Button: Ch?m c�ng
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
                      const Text(
                        'Ch?m c�ng',
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
      onSelectOrgChart: () => setState(() => _mobileNavIndex = 2),
      onOpenModule: _openModule,
    );
  }

  // ==========================================
  // MOBILE VIEW 3: SO �? T? CH?C (ORGANIZATION STRUCTURE)
  // ==========================================
  Widget _buildMobilePeopleView() {
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
      case '?ng d?ng':
        return _buildApplicationsView();
      case 'So d? t? ch?c':
        return _buildOrganizationView();
      case 'Ngu?i d�ng':
        return _buildUsersView();
      case 'Vai tr� & Ph�n quy?n':
        return const RolePermissionScreen();
      case 'B�o c�o':
        return const MainAnalysisScreen();
      case 'C�i d?t':
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
                        'Tenant Admin - $tenantDisplay',
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
                _buildDesktopMenuItem('?ng d?ng', Icons.apps_outlined),
                _buildDesktopMenuItem('So d? t? ch?c', Icons.account_tree_outlined),
                _buildDesktopMenuItem('Ngu?i d�ng', Icons.people_outline),
                _buildDesktopMenuItem('Vai tr� & Ph�n quy?n', Icons.verified_user_outlined),

                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'PH�N H? NGHI?P V?',
                    style: TextStyle(color: AppColors.slate500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                _buildModuleShortcut('D? �n (Workspace)', Icons.work_outline, 'workspace'),
                _buildModuleShortcut('Quy tr�nh (Workflow)', Icons.account_tree, 'procedure'),
                _buildModuleShortcut('Kho v?t tu (Inventory)', Icons.inventory_2, 'inventory'),
                _buildModuleShortcut('B?o tr� (Maintenance)', Icons.build, 'maintenance'),
                _buildModuleShortcut('Ch?t lu?ng di?n (Analysis)', Icons.analytics, 'power-quality'),

                const SizedBox(height: 8),
                const Divider(color: AppColors.slate800, height: 1),
                const SizedBox(height: 8),

                _buildDesktopMenuItem('B�o c�o', Icons.assessment_outlined),
                _buildDesktopMenuItem('C�i d?t', Icons.settings_outlined),
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.white60, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '�ang xu?t',
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

  Widget _buildDesktopMenuItem(String title, IconData icon) {
    final isActive = _desktopTab == title;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: isActive ? Colors.white : AppColors.slate400, size: 18),
        title: Text(
          title,
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
                _desktopTab,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.slate600, size: 20),
                tooltip: 'T?i l?i d? li?u',
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
          const Text('Cài đặt Không gian làm việc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800)),
          const SizedBox(height: 4),
          const Text('C?u h�nh d?nh danh tenant v� ch�nh s�ch b?o m?t.', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
        ],
      ),
    );
  }
}

