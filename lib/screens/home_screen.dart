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
import './tenant_input_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Navigation states
  int _mobileNavIndex = 0; // 0: Home, 1: Modules, 2: People, 3: Profile
  String _desktopTab = 'Dashboard';
  int _peopleSubTabIndex = 0; // 0: Users, 1: Org Structure

  final PlatformService _platformService = PlatformService();

  // Data states
  List<TenantUser> _users = [];
  List<ModuleCatalogItem> _modules = [];
  OrganizationSnapshot? _orgSnapshot;
  bool _isLoadingData = false;

  // Filter states for Users
  String _userQuery = '';
  String _userRoleFilter = 'ALL';
  String _userStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadAllPlatformData();
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

  int get _activeUsersCount => _users.where((u) => u.isActive).length;
  int get _activeModulesCount => _modules.where((m) => m.isActive).length;

  List<TenantUser> get _filteredUsers {
    return _users.where((u) {
      final needle = _userQuery.trim().toLowerCase();
      final matchesSearch = needle.isEmpty ||
          u.fullName.toLowerCase().contains(needle) ||
          u.email.toLowerCase().contains(needle);
      if (!matchesSearch) return false;

      if (_userRoleFilter != 'ALL' && u.systemRole != _userRoleFilter) return false;
      if (_userStatusFilter != 'ALL' && u.status != _userStatusFilter) return false;
      return true;
    }).toList();
  }

  void _openModule(String key) {
    if (key == 'procedure') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen()));
    } else if (key == 'inventory') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
    } else if (key == 'maintenance') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen()));
    } else if (key == 'power-quality') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MainAnalysisScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phân hệ "$key" đang chuẩn bị khởi chạy.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.fullName ?? 'Quản trị viên';
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
    );
  }

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
      child: NavigationBar(
        selectedIndex: _mobileNavIndex,
        onDestinationSelected: (index) => setState(() => _mobileNavIndex = index),
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: AppColors.slate900,
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined, color: AppColors.slate500),
            selectedIcon: const Icon(Icons.home, color: Colors.white),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: const Icon(Icons.apps_outlined, color: AppColors.slate500),
            selectedIcon: const Icon(Icons.apps, color: Colors.white),
            label: 'Phân hệ',
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline, color: AppColors.slate500),
            selectedIcon: const Icon(Icons.people, color: Colors.white),
            label: 'Nhân sự',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline, color: AppColors.slate500),
            selectedIcon: const Icon(Icons.person, color: Colors.white),
            label: 'Tài khoản',
          ),
        ],
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
  // MOBILE VIEW 1: HOME DASHBOARD
  // ==========================================
  Widget _buildMobileDashboardView(String userName, String userInitials, String tenantDisplay) {
    final activeModules = _modules.where((m) => m.isActive).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Mobile Top Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, AppColors.slate900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        userInitials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Xin chào, $userName',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.slate200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tenantDisplay,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Tenant Admin',
                            style: TextStyle(fontSize: 11.5, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.slate700),
                tooltip: 'Làm mới',
                onPressed: _loadAllPlatformData,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 2. Enterprise Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade900.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Hệ thống trực tuyến',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ENTERPRISE',
                        style: TextStyle(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Không gian Doanh nghiệp',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Điều hành quy trình, quản trị kho vật tư và bảo trì thiết bị tập trung.',
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Quick Metrics 2x2 Grid
          Row(
            children: [
              Expanded(
                child: _buildCompactMetricCard(
                  'NGƯỜI DÙNG',
                  '$_activeUsersCount',
                  'Đang hoạt động',
                  Icons.people_alt_outlined,
                  Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactMetricCard(
                  'PHÂN HỆ',
                  '$_activeModulesCount',
                  'Đã kích hoạt',
                  Icons.apps_outlined,
                  AppColors.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactMetricCard(
                  'QUY TRÌNH',
                  '4',
                  'Đang xử lý',
                  Icons.account_tree_outlined,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactMetricCard(
                  'BẢO TRÌ',
                  '2 đến hạn',
                  'Kế hoạch tuần',
                  Icons.build_outlined,
                  Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Quick Action Shortcuts (Lối tắt thao tác nhanh)
          const Text(
            'Lối tắt thao tác nhanh',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircularAction('Quy trình', Icons.account_tree, Colors.indigo, () => _openModule('procedure')),
              _buildCircularAction('Kho vật tư', Icons.inventory_2, AppColors.emerald, () => _openModule('inventory')),
              _buildCircularAction('Bảo trì', Icons.build, Colors.orange.shade700, () => _openModule('maintenance')),
              _buildCircularAction('Đo điện', Icons.analytics, AppColors.amber, () => _openModule('power-quality')),
            ],
          ),
          const SizedBox(height: 24),

          // 5. Active Applications Section (Phân hệ đang hoạt động)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Phân hệ đang hoạt động',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              TextButton(
                onPressed: () => setState(() => _mobileNavIndex = 1),
                child: const Row(
                  children: [
                    Text('Tất cả', style: TextStyle(fontSize: 13, color: AppColors.slate500)),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.slate500),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeModules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final m = activeModules[index];
              return _buildMobileModuleListItem(m);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCompactMetricCard(String label, String value, String subtext, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 0.5),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: const TextStyle(fontSize: 11, color: AppColors.slate500),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.slate800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileModuleListItem(ModuleCatalogItem m) {
    IconData icon = Icons.apps;
    Color color = Colors.blue;
    if (m.key == 'procedure') {
      icon = Icons.account_tree_outlined;
      color = Colors.indigo;
    } else if (m.key == 'inventory') {
      icon = Icons.inventory_2_outlined;
      color = AppColors.emerald;
    } else if (m.key == 'maintenance') {
      icon = Icons.build_outlined;
      color = Colors.orange.shade700;
    } else if (m.key == 'power-quality') {
      icon = Icons.analytics_outlined;
      color = AppColors.amber;
    }

    return InkWell(
      onTap: () => _openModule(m.key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE VIEW 2: MODULES CATALOG
  // ==========================================
  Widget _buildMobileModulesView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danh mục Phân hệ Doanh nghiệp',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tất cả ứng dụng nghiệp vụ được cung cấp theo gói dịch vụ của bạn.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _modules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final m = _modules[index];
              return _buildModuleCard(m);
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE VIEW 3: PEOPLE (USERS & ORG)
  // ==========================================
  Widget _buildMobilePeopleView() {
    return Column(
      children: [
        // Tab Selector Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _peopleSubTabIndex = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _peopleSubTabIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _peopleSubTabIndex == 0
                            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Người dùng (${_users.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _peopleSubTabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                            color: _peopleSubTabIndex == 0 ? AppColors.slate900 : AppColors.slate600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _peopleSubTabIndex = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _peopleSubTabIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _peopleSubTabIndex == 1
                            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Sơ đồ tổ chức',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _peopleSubTabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                            color: _peopleSubTabIndex == 1 ? AppColors.slate900 : AppColors.slate600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Subtab Content
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: _peopleSubTabIndex == 0 ? _buildUsersView() : _buildOrganizationView(),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MOBILE VIEW 4: PROFILE & SETTINGS
  // ==========================================
  Widget _buildMobileProfileView(String userName, String userInitials, String tenantDisplay) {
    final authProvider = context.read<AuthProvider>();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.slate900,
                  child: Text(
                    userInitials,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authProvider.email ?? 'admin@company.com',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Quản trị viên Tenant',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emerald700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Workspace details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('THÔNG TIN DOANH NGHIỆP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate400)),
                const SizedBox(height: 12),
                _buildProfileItem(Icons.domain, 'Mã doanh nghiệp (Tenant)', tenantDisplay),
                const Divider(height: 1, color: AppColors.slate100),
                _buildProfileItem(Icons.card_membership, 'Gói dịch vụ', 'Enterprise Unlimited'),
                const Divider(height: 1, color: AppColors.slate100),
                _buildProfileItem(Icons.security, 'Chính sách bảo mật', 'Xác thực chuẩn Token & Cookies'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // App Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ỨNG DỤNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate400)),
                const SizedBox(height: 12),
                _buildProfileItem(Icons.info_outline, 'Phiên bản', 'Savina Enterprise Mobile 2.0.0'),
                const Divider(height: 1, color: AppColors.slate100),
                _buildProfileItem(Icons.support_agent, 'Hỗ trợ kỹ thuật', 'support@savina.vn'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                await authProvider.logout();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const TenantInputScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Đăng xuất tài khoản', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.slate400),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.slate700)),
          const Spacer(),
          Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900)),
        ],
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
      case 'Báo cáo':
        return _buildReportsView();
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
                _buildDesktopMenuItem('Ứng dụng', Icons.apps_outlined),
                _buildDesktopMenuItem('Sơ đồ tổ chức', Icons.account_tree_outlined),
                _buildDesktopMenuItem('Người dùng', Icons.people_outline),

                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'PHÂN HỆ NGHIỆP VỤ',
                    style: TextStyle(color: AppColors.slate500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                _buildModuleShortcut('Quy trình (Workflow)', Icons.account_tree, 'procedure'),
                _buildModuleShortcut('Kho vật tư (Inventory)', Icons.inventory_2, 'inventory'),
                _buildModuleShortcut('Bảo trì (Maintenance)', Icons.build, 'maintenance'),
                _buildModuleShortcut('Chất lượng điện (Analysis)', Icons.analytics, 'power-quality'),

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
                    MaterialPageRoute(builder: (context) => const TenantInputScreen()),
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
                tooltip: 'Tải lại dữ liệu',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xin chào, $userName',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        const SizedBox(height: 24),

        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 1000
                ? (constraints.maxWidth - 3 * 16) / 4
                : constraints.maxWidth >= 600
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStatusCard('NGƯỜI DÙNG HOẠT ĐỘNG', '$_activeUsersCount', null, cardWidth),
                _buildStatusCard('MODULE ĐÃ BẬT', '$_activeModulesCount', null, cardWidth),
                _buildStatusCard('GÓI HIỆN TẠI', 'Enterprise', null, cardWidth),
                _buildStatusCard('ĐĂNG KÝ', 'Đang hoạt động', 'active', cardWidth),
              ],
            );
          },
        ),
        const SizedBox(height: 32),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: _buildMyApplicationsCard()),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildQuickActionsCard(),
                  const SizedBox(height: 24),
                  _buildRecentActivityCard(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String value, String? type, double width) {
    final isActiveBadge = type == 'active';
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          isActiveBadge
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Đang hoạt động',
                            style: TextStyle(color: AppColors.emerald700, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Text(
                  value,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate800),
                ),
        ],
      ),
    );
  }

  Widget _buildMyApplicationsCard() {
    final activeModules = _modules.where((m) => m.isActive).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ứng dụng của tôi',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate800),
              ),
              TextButton(
                onPressed: () => setState(() => _desktopTab = 'Ứng dụng'),
                child: const Row(
                  children: [
                    Text('Xem tất cả', style: TextStyle(fontSize: 13, color: AppColors.slate500)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: AppColors.slate500),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeModules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final m = activeModules[index];
              return _buildMobileModuleListItem(m);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thao tác nhanh (Admin)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate800),
          ),
          const SizedBox(height: 16),
          _buildQuickActionItem('Thêm người dùng mới', () => _showAddUserDialog()),
          const Divider(height: 1, color: AppColors.slate100),
          _buildQuickActionItem('Xem sơ đồ tổ chức', () => setState(() => _desktopTab = 'Sơ đồ tổ chức')),
          const Divider(height: 1, color: AppColors.slate100),
          _buildQuickActionItem('Quản lý phân quyền ứng dụng', () => setState(() => _desktopTab = 'Ứng dụng')),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.slate700)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.slate400),
      onTap: onTap,
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hoạt động gần đây',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate800),
          ),
          const SizedBox(height: 16),
          _buildActivityItem('Đã mời người dùng mới vào hệ thống', '2 giờ trước'),
          _buildActivityItem('Cập nhật chỉ số định mức kho vật tư', 'Hôm qua, 14:30'),
          _buildActivityItem('Hoàn thành bảo trì MBA 110kV T1', '2 ngày trước'),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.slate300, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: AppColors.slate700, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Applications
  Widget _buildApplicationsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Danh mục Ứng dụng Doanh nghiệp',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Các phân hệ công việc đang hoạt động và được cấp quyền trên tài khoản của bạn.',
          style: TextStyle(fontSize: 13, color: AppColors.slate500),
        ),
        const SizedBox(height: 24),

        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _modules.map((m) => _buildModuleCard(m)).toList(),
        ),
      ],
    );
  }

  Widget _buildModuleCard(ModuleCatalogItem m) {
    final isActive = m.isActive;
    IconData icon = Icons.apps_outlined;
    Color color = Colors.blue;
    if (m.key == 'procedure') {
      icon = Icons.account_tree_outlined;
      color = Colors.indigo;
    } else if (m.key == 'inventory') {
      icon = Icons.inventory_2_outlined;
      color = AppColors.emerald;
    } else if (m.key == 'maintenance') {
      icon = Icons.build_outlined;
      color = Colors.orange.shade700;
    } else if (m.key == 'power-quality') {
      icon = Icons.analytics_outlined;
      color = AppColors.amber;
    } else if (m.key == 'crm') {
      icon = Icons.people_outline;
      color = Colors.teal;
    }

    return Container(
      width: 330,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.emerald50 : AppColors.slate100,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Text(
                  isActive ? 'Active' : m.entitlementStatus == 'provisioning' ? 'Đang kích hoạt' : 'Chưa kích hoạt',
                  style: TextStyle(
                    color: isActive ? AppColors.emerald700 : AppColors.slate600,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            m.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          const SizedBox(height: 6),
          Text(
            m.description,
            style: const TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: isActive
                ? ElevatedButton(
                    onPressed: () => _openModule(m.key),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slate900,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Truy cập phân hệ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  )
                : OutlinedButton(
                    onPressed: () async {
                      final success = await _platformService.requestModuleActivation(m.key);
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã gửi yêu cầu kích hoạt cho phân hệ ${m.name}')),
                        );
                        _loadAllPlatformData();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.slate700,
                      side: const BorderSide(color: AppColors.slate300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Yêu cầu kích hoạt', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
    );
  }

  // Users Management
  Widget _buildUsersView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Danh sách Nhân viên',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
            ElevatedButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add_alt_1, size: 14),
              label: const Text('Thêm mới', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slate900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Controls (Search & Filter)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _userQuery = val),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên hoặc email...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.slate400),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.slate400),
                  filled: true,
                  fillColor: AppColors.slate50,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildUserRoleChip('Tất cả', 'ALL'),
                    _buildUserRoleChip('Admin', 'tenant-admin'),
                    _buildUserRoleChip('Thành viên', 'tenant-user'),
                    const SizedBox(width: 8),
                    _buildUserStatusChip('Hoạt động', 'active'),
                    _buildUserStatusChip('Vô hiệu', 'disabled'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Users List
        if (_filteredUsers.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slate200),
            ),
            child: const Center(
              child: Text('Không tìm thấy người dùng phù hợp.', style: TextStyle(color: AppColors.slate500)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredUsers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = _filteredUsers[index];
              final isAdmin = user.systemRole == 'tenant-admin';
              final isActive = user.isActive;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isAdmin ? Colors.purple.shade100 : Colors.blue.shade100,
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: isAdmin ? Colors.purple.shade800 : Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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
                                  user.fullName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isAdmin ? Colors.purple.shade50 : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isAdmin ? 'Admin' : 'Member',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isAdmin ? Colors.purple.shade700 : AppColors.slate600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(user.email, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.emerald50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Disabled',
                        style: TextStyle(
                          color: isActive ? AppColors.emerald700 : Colors.red.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 16, color: AppColors.slate400),
                      padding: EdgeInsets.zero,
                      onSelected: (action) async {
                        if (action == 'toggle') {
                          await _platformService.updateUser(
                            user.id,
                            status: isActive ? 'disabled' : 'active',
                          );
                          _loadAllPlatformData();
                        } else if (action == 'role') {
                          await _platformService.updateUser(
                            user.id,
                            systemRole: isAdmin ? 'tenant-user' : 'tenant-admin',
                          );
                          _loadAllPlatformData();
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(isActive ? 'Vô hiệu hóa tài khoản' : 'Kích hoạt lại tài khoản'),
                        ),
                        PopupMenuItem(
                          value: 'role',
                          child: Text(isAdmin ? 'Chuyển thành Thành viên' : 'Nâng quyền Admin'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildUserRoleChip(String label, String value) {
    final isSelected = _userRoleFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.slate700)),
        selected: isSelected,
        selectedColor: AppColors.slate800,
        backgroundColor: AppColors.slate100,
        showCheckmark: false,
        onSelected: (_) => setState(() => _userRoleFilter = value),
      ),
    );
  }

  Widget _buildUserStatusChip(String label, String value) {
    final isSelected = _userStatusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.slate700)),
        selected: isSelected,
        selectedColor: AppColors.slate800,
        backgroundColor: AppColors.slate100,
        showCheckmark: false,
        onSelected: (_) => setState(() => _userStatusFilter = value),
      ),
    );
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'tenant-user';
    String selectedStatus = 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Thêm người dùng mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên *', hintText: 'Nguyễn Văn A'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email *', hintText: 'name@company.com'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu khởi tạo *', hintText: '••••••••'),
                ),
                const SizedBox(height: 16),
                const Text('Vai trò trong hệ thống:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                DropdownButton<String>(
                  value: selectedRole,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'tenant-user', child: Text('Thành viên (Tenant User)')),
                    DropdownMenuItem(value: 'tenant-admin', child: Text('Quản trị viên (Tenant Admin)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng điền đầy đủ các thông tin bắt buộc.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final success = await _platformService.createUser(
                  fullName: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                  systemRole: selectedRole,
                  status: selectedStatus,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã thêm người dùng thành công!')),
                  );
                  _loadAllPlatformData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slate900,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
  }

  // Organization Structure
  Widget _buildOrganizationView() {
    final snapshot = _orgSnapshot;
    if (snapshot == null) return const Center(child: Text('Đang tải sơ đồ tổ chức...'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sơ đồ Phòng ban & Tổ chức',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Phân cấp cơ cấu tổ chức và nhân sự phụ trách',
          style: TextStyle(fontSize: 12, color: AppColors.slate500),
        ),
        const SizedBox(height: 12),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.nodes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final node = snapshot.nodes[index];
            final assignments = snapshot.assignments.where((a) => a.nodeId == node.id).toList();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.business_outlined, size: 16, color: Colors.blue.shade700),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            node.name,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.slate900),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          node.code,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('NHÂN SỰ PHÂN BỔ', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.slate400)),
                  const SizedBox(height: 6),

                  if (assignments.isEmpty)
                    const Text('Chưa có nhân sự được phân bổ.', style: TextStyle(fontSize: 11.5, color: AppColors.slate400))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: assignments.map((a) {
                        final user = snapshot.users.firstWhere(
                          (u) => u.id == a.userId,
                          orElse: () => TenantUser(
                            id: a.userId,
                            fullName: 'Nhân viên',
                            email: '',
                            systemRole: 'tenant-user',
                            status: 'active',
                            isActive: true,
                            createdAt: '',
                            updatedAt: '',
                          ),
                        );

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.slate50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  user.fullName[0],
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(user.fullName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                              if (a.note != null) ...[
                                const SizedBox(width: 4),
                                Text('(${a.note!})', style: const TextStyle(fontSize: 10, color: AppColors.slate500)),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // Reports & Settings
  Widget _buildReportsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.assessment_outlined, size: 48, color: AppColors.slate300),
          const SizedBox(height: 12),
          const Text('Báo cáo thống kê tổng hợp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800)),
          const SizedBox(height: 4),
          const Text('Báo cáo vận hành quy trình, kho và bảo trì thiết bị.', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
        ],
      ),
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
          const Text('Cấu hình định danh tenant và chính sách bảo mật.', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
        ],
      ),
    );
  }
}
