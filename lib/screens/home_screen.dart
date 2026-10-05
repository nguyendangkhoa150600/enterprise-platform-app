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
import './user_management_screen.dart';
import './org_chart_workspace_screen.dart';
import './role_permission_screen.dart';
import '../widgets/assign_role_modal.dart';

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

  // Filter states for Users
  String _userQuery = '';
  String _userRoleFilter = 'ALL';
  String _userStatusFilter = 'ALL';

  // Filter state for Tab Phân hệ
  String _moduleSearchQuery = '';
  final TextEditingController _moduleSearchController = TextEditingController();

  // Organization Structure Web Subtabs & Search
  int _orgStructureTab = 0; // 0: Cây tổ chức, 1: Bổ nhiệm
  String _orgSearchQuery = '';
  final TextEditingController _orgSearchController = TextEditingController();
  
  // Assignment (Bổ nhiệm) Web Filters & Search
  String _assignmentSearchQuery = '';
  final TextEditingController _assignmentSearchController = TextEditingController();
  String _assignmentRoleFilter = 'ALL'; // ALL, primary, concurrent
  String _assignmentStatusFilter = 'ALL'; // ALL, active, inactive, ended

  final ScrollController _attentionScrollController = ScrollController();
  final ScrollController _homeOrgScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAllPlatformData();
  }

  @override
  void dispose() {
    _moduleSearchController.dispose();
    _orgSearchController.dispose();
    _assignmentSearchController.dispose();
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
    } else if (key == 'requests' || key == 'hrm-requests') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 1)));
    } else if (key == 'approvals' || key == 'hrm-approvals') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 2)));
    } else if (key == 'employees' || key == 'shifts' || key == 'payslips') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 3)));
    } else if (key == 'roles' || key == 'permissions' || key == 'role-permission' || key == 'authorization' || key == 'rbac') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePermissionScreen()));
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
                    label: 'Trang chủ',
                    isSelected: _mobileNavIndex == 0,
                    onTap: () => setState(() => _mobileNavIndex = 0),
                  ),

                  // Tab 1: Phân hệ
                  _buildBottomNavItem(
                    icon: Icons.apps_outlined,
                    activeIcon: Icons.apps,
                    label: 'Phân hệ',
                    isSelected: _mobileNavIndex == 1,
                    onTap: () => setState(() => _mobileNavIndex = 1),
                  ),

                  // Space in center for raised button
                  const SizedBox(width: 58),

                  // Tab 2: Sơ đồ tổ chức
                  _buildBottomNavItem(
                    icon: Icons.account_tree_outlined,
                    activeIcon: Icons.account_tree,
                    label: 'Sơ đồ tổ chức',
                    isSelected: _mobileNavIndex == 2,
                    onTap: () => setState(() => _mobileNavIndex = 2),
                  ),

                  // Tab 3: Tài khoản
                  _buildBottomNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Tài khoản',
                    isSelected: _mobileNavIndex == 3,
                    onTap: () => setState(() => _mobileNavIndex = 3),
                  ),
                ],
              ),

              // Raised Center Button: Chấm công
              Positioned(
                top: -18,
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                  onLongPress: _showAttendanceSheet,
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
                        'Chấm công',
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

  void _showAttendanceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Icon & Header
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                size: 36,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Chấm công điện tử',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hệ thống xác thực vị trí GPS & Sinh trắc học',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      const Text(
                        'Thời gian hiện tại:',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      Text(
                        '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF059669)),
                      SizedBox(width: 8),
                      Text(
                        'Địa điểm:',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      Spacer(),
                      Text(
                        'Trụ sở chính SAVINA',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Primary Action: Mở trực tiếp màn hình Chấm công
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
                },
                icon: const Icon(Icons.fingerprint_rounded, size: 20),
                label: const Text('MỞ CHẤM CÔNG ĐIỆN TỬ', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Secondary Action: Mở HRM Hub
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen()));
                },
                icon: const Icon(Icons.hub_outlined, size: 18),
                label: const Text('TRUNG TÂM NHÂN SỰ & ĐƠN TỪ (HRM)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Breadcrumb & Main Page Title
          _buildMobilePageHeader(tenantDisplay),
          const SizedBox(height: 16),

          // 2. Welcome Card with Action Buttons
          _buildMobileWelcomeCard(userName),
          const SizedBox(height: 16),

          // 3. 4 Metric Cards Grid
          _buildMobileMetricsGrid(),
          const SizedBox(height: 20),

          // 4. Attention Items (Điểm cần chú ý)
          _buildMobileAttentionSection(),
          const SizedBox(height: 20),

          // 5. Module Summaries (Quy trình, Bảo trì, Kho vật tư)
          _buildMobileModuleSummariesSection(),
          const SizedBox(height: 20),

          // 6. Enterprise Applications (Ứng dụng doanh nghiệp)
          _buildMobileEnterpriseAppsSection(),
          const SizedBox(height: 20),

          // 7. Sơ đồ tổ chức (Organization Structure)
          _buildMobileOrgChartSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 1. Breadcrumb & Title
  Widget _buildMobilePageHeader(String tenantDisplay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tenant Portal · ${tenantDisplay.toLowerCase()}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: AppColors.slate600),
              tooltip: 'Làm mới',
              onPressed: _loadAllPlatformData,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tổng quan doanh nghiệp',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Theo dõi vận hành từ các ứng dụng doanh nghiệp đang hoạt động.',
          style: TextStyle(fontSize: 12.5, color: AppColors.slate500, height: 1.35),
        ),
      ],
    );
  }

  // 2. Welcome Card (Xin chào)
  Widget _buildMobileWelcomeCard(String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // bg-blue-50
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Xin chào',
            style: TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            userName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Chúc bạn một ngày làm việc hiệu quả.',
            style: TextStyle(fontSize: 12.5, color: AppColors.slate600),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildWelcomeActionButton(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Quản lý người dùng',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                ),
                const SizedBox(width: 8),
                _buildWelcomeActionButton(
                  icon: Icons.verified_user_outlined,
                  label: 'Vai trò & Phân quyền',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePermissionScreen())),
                ),
                const SizedBox(width: 8),
                _buildWelcomeActionButton(
                  icon: Icons.account_tree_outlined,
                  label: 'Thiết lập tổ chức',
                  onTap: () => setState(() => _mobileNavIndex = 2),
                ),
                const SizedBox(width: 8),
                _buildWelcomeActionButton(
                  icon: Icons.apps_outlined,
                  label: 'Quản lý ứng dụng',
                  onTap: () => setState(() => _mobileNavIndex = 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB), // Blue 600
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // 3. 4 Top Metric Cards (Grid 2x2)
  Widget _buildMobileMetricsGrid() {
    final userCount = _activeUsersCount > 0 ? '$_activeUsersCount' : '45';
    final moduleCount = _activeModulesCount > 0 ? '$_activeModulesCount' : '3';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Người dùng hoạt động',
                value: userCount,
                note: 'Tài khoản đang hoạt động',
                icon: Icons.people_outline,
                tone: 'blue',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                label: 'Ứng dụng đang bật',
                value: moduleCount,
                note: 'Theo entitlement hiện tại',
                icon: Icons.layers_outlined,
                tone: 'blue',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Hồ sơ chờ xử lý',
                value: '4',
                note: 'Quy trình cần bạn thao tác',
                icon: Icons.assignment_outlined,
                tone: 'amber',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                label: 'Sự cố đang xử lý',
                value: '0',
                note: 'Sự cố chưa đóng',
                icon: Icons.shield_outlined,
                tone: 'red',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String note,
    required IconData icon,
    required String tone,
  }) {
    Color badgeBg = const Color(0xFFEFF6FF);
    Color iconColor = const Color(0xFF1D4ED8);

    if (tone == 'amber') {
      badgeBg = const Color(0xFFFFFBEB);
      iconColor = const Color(0xFFB45309);
    } else if (tone == 'red') {
      badgeBg = const Color(0xFFFEF2F2);
      iconColor = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
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
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.slate500),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppColors.slate400),
          ),
        ],
      ),
    );
  }

  // 4. Điểm cần chú ý (Attention Section)
  Widget _buildMobileAttentionSection() {
    final items = [
      {
        'title': 'Thí nghiệm định kỳ tủ rơ le lộ 901',
        'code': 'PR-20260918-D0A538',
        'def': 'Thí nghiệm định kỳ thiết bị điện',
        'step': 'Đăng ký thí nghiệm',
        'module': 'procedure',
      },
      {
        'title': 'Mua dầu cách điện bù cho MBA T1',
        'code': 'PR-20260918-038357',
        'def': 'Mua sắm vật tư kỹ thuật',
        'step': 'Đề nghị mua sắm',
        'module': 'procedure',
      },
      {
        'title': 'Mua bổ sung sứ cách điện 24kV cho lộ 901',
        'code': 'PR-20260918-7C50C5',
        'def': 'Mua sắm vật tư kỹ thuật',
        'step': 'Đề nghị mua sắm',
        'module': 'procedure',
      },
      {
        'title': 'Bảo trì quý III/2026 — Máy biến áp T1',
        'code': 'PR-20260918-4E0BCA',
        'def': 'Bảo trì định kỳ máy biến áp lực',
        'step': 'Lập phiếu công việc',
        'module': 'maintenance',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Điểm cần chú ý',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7), // Amber 100
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${items.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Các việc thực tế cần mở module để xử lý.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 20),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Scrollable container for attention items if list is long
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 255),
            child: Scrollbar(
              controller: _attentionScrollController,
              thumbVisibility: items.length > 2,
              child: ListView.separated(
                controller: _attentionScrollController,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final it = items[index];
                  return _buildAttentionItem(it);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionItem(Map<String, String> it) {
    return InkWell(
      onTap: () => _openModule(it['module']!),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.arrow_forward, size: 14, color: AppColors.slate600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it['title']!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildChipTag('Quy trình', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
                      _buildChipTag(it['code']!, const Color(0xFFF1F5F9), AppColors.slate700),
                      _buildChipTag(it['def']!, const Color(0xFFF8FAFC), AppColors.slate600),
                      _buildChipTag('Bước: ${it['step']!}', const Color(0xFFF8FAFC), AppColors.slate600),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Cần xử lý',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: textCol, fontWeight: FontWeight.w500),
      ),
    );
  }

  // 5. Module Summaries Section (Quy trình, Bảo trì, Kho vật tư)
  Widget _buildMobileModuleSummariesSection() {
    return Column(
      children: [
        // Card 1: Quy trình
        _buildModuleSummaryCard(
          title: 'Quy trình',
          icon: Icons.account_tree_outlined,
          onOpen: () => _openModule('procedure'),
          stats: [
            {'label': 'Đang chạy', 'value': '4'},
            {'label': 'Chờ xử lý', 'value': '4'},
            {'label': 'Đã công bố', 'value': '16'},
          ],
          customContent: _buildProcedureMiniChart(),
        ),
        const SizedBox(height: 12),

        // Card 2: Bảo trì
        _buildModuleSummaryCard(
          title: 'Bảo trì',
          icon: Icons.build_outlined,
          onOpen: () => _openModule('maintenance'),
          stats: [
            {'label': 'Lịch đang chạy', 'value': '4'},
            {'label': 'Sắp đến hạn', 'value': '2'},
            {'label': 'Sự cố mở', 'value': '0'},
          ],
          emptyNote: 'Chưa có sự cố mở',
        ),
        const SizedBox(height: 12),

        // Card 3: Kho vật tư
        _buildModuleSummaryCard(
          title: 'Kho vật tư',
          icon: Icons.inventory_2_outlined,
          onOpen: () => _openModule('inventory'),
          stats: [
            {'label': 'Kho hoạt động', 'value': '—'},
            {'label': 'Mã vật tư', 'value': '—'},
            {'label': 'Sắp thiếu', 'value': '—'},
          ],
          emptyNote: 'Chưa có vật tư',
        ),
      ],
    );
  }

  Widget _buildModuleSummaryCard({
    required String title,
    required IconData icon,
    required VoidCallback onOpen,
    required List<Map<String, String>> stats,
    Widget? customContent,
    String? emptyNote,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
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
              Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              InkWell(
                onTap: onOpen,
                child: const Text(
                  'Mở module',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Stats Row
          Row(
            children: stats.map((st) {
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      st['label']!,
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      st['value']!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          if (customContent != null) ...[
            const SizedBox(height: 12),
            customContent,
          ] else if (emptyNote != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  emptyNote,
                  style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcedureMiniChart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Mini Donut
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2563EB), width: 6),
            ),
            child: const Center(
              child: Text(
                '4',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Legend
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildMiniLegend(const Color(0xFF8B5CF6), 'Khởi tạo 4'),
                _buildMiniLegend(const Color(0xFF2563EB), 'Xem xét 0'),
                _buildMiniLegend(const Color(0xFFF97316), 'Thực hiện 0'),
                _buildMiniLegend(const Color(0xFFA855F7), 'Kiểm soát 0'),
                _buildMiniLegend(const Color(0xFFEAB308), 'Phê duyệt 0'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniLegend(Color col, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: col, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.slate600, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // 6. Enterprise Applications Section
  Widget _buildMobileEnterpriseAppsSection() {
    final apps = [
      {
        'key': 'inventory',
        'name': 'Inventory',
        'desc': 'Tài sản, vật tư, kho và giao dịch tồn kho',
        'icon': Icons.inventory_2_outlined,
        'color': AppColors.emerald,
      },
      {
        'key': 'maintenance',
        'name': 'Maintenance',
        'desc': 'Thiết bị, kế hoạch và bảo trì phòng ngừa',
        'icon': Icons.build_outlined,
        'color': const Color(0xFFF97316),
      },
      {
        'key': 'procedure',
        'name': 'Procedure Engine',
        'desc': 'Thiết kế và vận hành quy trình RCSI',
        'icon': Icons.account_tree_outlined,
        'color': const Color(0xFF6366F1),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Ứng dụng doanh nghiệp',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 2),
                Text(
                  'Truy cập nhanh các ứng dụng chính.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.slate500),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _mobileNavIndex = 1),
              child: const Row(
                children: [
                  Text('Xem tất cả', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: apps.map((app) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _openModule(app['key'] as String),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: (app['color'] as Color).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(app['icon'] as IconData, size: 15, color: app['color'] as Color),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                app['name'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            app['desc'] as String,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: AppColors.slate500, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // 7. SƠ ĐỒ TỔ CHỨC (Hierarchical Organization Tree matching Web)
  Widget _buildMobileOrgChartSection() {
    final snapshot = _orgSnapshot;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SƠ ĐỒ TỔ CHỨC',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.slate700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Cây phân cấp cơ cấu & nhân sự phụ trách',
                      style: TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              if (snapshot != null)
                InkWell(
                  onTap: () => setState(() => _mobileNavIndex = 2),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Xem chi tiết',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right, size: 14, color: Color(0xFF0284C7)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Content Tree
          if (snapshot == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Đang tải sơ đồ tổ chức...', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
              ),
            )
          else if (snapshot.nodes.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Chưa có thông tin phòng ban', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: Scrollbar(
                controller: _homeOrgScrollController,
                thumbVisibility: snapshot.nodes.length > 2,
                child: SingleChildScrollView(
                  controller: _homeOrgScrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildOrgTreeList(snapshot),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildOrgTreeList(OrganizationSnapshot snapshot) {
    final rootNodes = snapshot.nodes.where((n) {
      return n.parentId == null || n.parentId!.isEmpty || !snapshot.nodes.any((p) => p.id == n.parentId);
    }).toList();

    List<Widget> widgets = [];
    for (int i = 0; i < rootNodes.length; i++) {
      _buildOrgTreeNodeRecursive(rootNodes[i], 0, snapshot, widgets, i == rootNodes.length - 1);
    }
    return widgets;
  }

  void _buildOrgTreeNodeRecursive(
    OrgNode node,
    int depth,
    OrganizationSnapshot snapshot,
    List<Widget> widgets,
    bool isLastChild,
  ) {
    widgets.add(_buildOrgTreeNodeItem(node, depth, snapshot));

    final children = snapshot.nodes.where((n) => n.parentId == node.id).toList();
    for (int i = 0; i < children.length; i++) {
      _buildOrgTreeNodeRecursive(children[i], depth + 1, snapshot, widgets, i == children.length - 1);
    }
  }

  Widget _buildOrgTreeNodeItem(OrgNode node, int depth, OrganizationSnapshot snapshot) {
    final assignments = snapshot.assignments.where((a) => a.nodeId == node.id).toList();
    final isRoot = depth == 0;
    final isLevel1 = depth == 1;

    Color cardBg = isRoot ? const Color(0xFFF0F9FF) : (isLevel1 ? const Color(0xFFF8FAFC) : Colors.white);
    Color borderColor = isRoot ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0);
    IconData nodeIcon = isRoot ? Icons.corporate_fare : (isLevel1 ? Icons.business_outlined : Icons.group_work_outlined);
    Color iconColor = isRoot ? const Color(0xFF0284C7) : (isLevel1 ? const Color(0xFF475569) : const Color(0xFF64748B));
    String levelBadge = isRoot ? 'Ban Lãnh Đạo' : (isLevel1 ? 'Phòng ban' : 'Đội / Nhóm');

    return Container(
      margin: EdgeInsets.only(
        left: depth * 14.0,
        bottom: 8,
        top: isRoot ? 0 : 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tree connector guide for children
          if (depth > 0)
            Container(
              width: 14,
              height: 32,
              margin: const EdgeInsets.only(right: 4, top: 4),
              child: CustomPaint(
                painter: _TreeBranchPainter(color: const Color(0xFF94A3B8)),
              ),
            ),

          // Node Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: isRoot ? 1.2 : 1),
                boxShadow: isRoot
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withOpacity(0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Node Title Bar (Row 1: Icon + Name + Level Badge)
                  Row(
                    children: [
                      Icon(nodeIcon, size: 15, color: iconColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          node.name,
                          style: TextStyle(
                            fontSize: isRoot ? 13.5 : 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          levelBadge,
                          style: const TextStyle(fontSize: 9, color: AppColors.slate600, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Node Code Tag (Row 2)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isRoot ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      node.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isRoot ? const Color(0xFF0284C7) : AppColors.slate700,
                      ),
                    ),
                  ),

                  // Assigned personnel
                  if (assignments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
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
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isRoot ? Colors.white : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isRoot ? const Color(0xFFBAE6FD) : const Color(0xFFCBD5E1), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 7,
                                backgroundColor: isRoot ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                                child: Text(
                                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                  style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: isRoot ? Colors.white : AppColors.slate800),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                user.fullName,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                              if (a.note != null && a.note!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '· ${a.note!}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE VIEW 2: MODULES CATALOG (GRID MENU STYLE LIKE IMAGE 1)
  // ==========================================
  Widget _buildMobileModulesView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 12, top: 2),
            child: Row(
              children: [
                const Text(
                  'Menu Phân hệ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text(
                    '20+ Chức năng',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _moduleSearchController,
              onChanged: (val) => setState(() => _moduleSearchQuery = val),
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm phân hệ, chức năng...',
                hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 21),
                suffixIcon: _moduleSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                        onPressed: () {
                          _moduleSearchController.clear();
                          setState(() => _moduleSearchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              ),
            ),
          ),

          // 1. WORKPLACE
          _buildMenuSection(
            title: 'WORKPLACE',
            items: [
              {
                'title': 'Quy trình',
                'icon': Icons.account_tree_outlined,
                'bg': const Color(0xFFEEF2FF), // Indigo 50
                'iconColor': const Color(0xFF6366F1),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen())),
              },
              {
                'title': 'Công việc',
                'icon': Icons.assignment_turned_in_outlined,
                'bg': const Color(0xFFECFDF5), // Emerald 50
                'iconColor': const Color(0xFF10B981),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen())),
              },
              {
                'title': 'Dự án',
                'icon': Icons.work_outline_rounded,
                'bg': const Color(0xFFFFFBEB), // Amber 50
                'iconColor': const Color(0xFFF59E0B),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen())),
              },
              {
                'title': 'Thí nghiệm ĐK',
                'icon': Icons.electrical_services_rounded,
                'bg': const Color(0xFFF5F3FF), // Purple 50
                'iconColor': const Color(0xFF8B5CF6),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen())),
              },
              {
                'title': 'Mua sắm vật tư',
                'icon': Icons.shopping_bag_outlined,
                'bg': const Color(0xFFFFF1F2), // Rose 50
                'iconColor': const Color(0xFFF43F5E),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen())),
              },
              {
                'title': 'Tiến độ SLA',
                'icon': Icons.draw_outlined,
                'bg': const Color(0xFFEFF6FF), // Sky 50
                'iconColor': const Color(0xFF0284C7),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen())),
              },
            ],
          ),

          // 2. HRM
          _buildMenuSection(
            title: 'HRM',
            items: [
              {
                'title': 'Chấm công GPS',
                'icon': Icons.fingerprint_rounded,
                'bg': const Color(0xFFEFF6FF), // Blue 50
                'iconColor': const Color(0xFF2563EB),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
              },
              {
                'title': 'Đơn từ',
                'icon': Icons.post_add_rounded,
                'bg': const Color(0xFFE0F2FE), // Sky 50
                'iconColor': const Color(0xFF0284C7),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 1))),
              },
              {
                'title': 'Phê duyệt',
                'icon': Icons.fact_check_outlined,
                'bg': const Color(0xFFF5F3FF), // Purple 50
                'iconColor': const Color(0xFF7C3AED),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 2))),
              },
              {
                'title': 'Nhân sự',
                'icon': Icons.people_alt_outlined,
                'bg': const Color(0xFFECFDF5), // Emerald 50
                'iconColor': const Color(0xFF059669),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 3, initialWorkforceSubTab: 0))),
              },
              {
                'title': 'Ca làm việc',
                'icon': Icons.schedule_rounded,
                'bg': const Color(0xFFFFFBEB), // Amber 50
                'iconColor': const Color(0xFFD97706),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 3, initialWorkforceSubTab: 1))),
              },
              {
                'title': 'Phiếu lương',
                'icon': Icons.receipt_long_rounded,
                'bg': const Color(0xFFFEF2F2), // Red/Pink 50
                'iconColor': const Color(0xFFE11D48),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 3, initialWorkforceSubTab: 2))),
              },
              {
                'title': 'QL Người dùng',
                'icon': Icons.manage_accounts_outlined,
                'bg': const Color(0xFFF1F5F9), // Slate 50
                'iconColor': const Color(0xFF0F172A),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
              },
            ],
          ),

          // 3. BẢO TRÌ & THIẾT BỊ
          _buildMenuSection(
            title: 'BẢO TRÌ & THIẾT BỊ',
            items: [
              {
                'title': 'Thiết bị MBA',
                'icon': Icons.bolt_rounded,
                'bg': const Color(0xFFFFF7ED), // Orange 50
                'iconColor': const Color(0xFFEA580C),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen())),
              },
              {
                'title': 'Lịch bảo trì',
                'icon': Icons.calendar_month_outlined,
                'bg': const Color(0xFFEFF6FF), // Blue 50
                'iconColor': const Color(0xFF2563EB),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen())),
              },
              {
                'title': 'Phiếu công tác',
                'icon': Icons.build_circle_outlined,
                'bg': const Color(0xFFFAF5FF), // Purple 50
                'iconColor': const Color(0xFF9333EA),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen())),
              },
            ],
          ),

          // 4. KHO & VẬT TƯ
          _buildMenuSection(
            title: 'KHO & VẬT TƯ',
            items: [
              {
                'title': 'Sổ kho',
                'icon': Icons.inventory_2_outlined,
                'bg': const Color(0xFFECFDF5), // Emerald 50
                'iconColor': const Color(0xFF059669),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
              },
              {
                'title': 'Xuất nhập kho',
                'icon': Icons.swap_horiz_rounded,
                'bg': const Color(0xFFF0F9FF), // Sky 50
                'iconColor': const Color(0xFF0284C7),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
              },
              {
                'title': 'Cảnh báo tồn',
                'icon': Icons.warning_amber_rounded,
                'bg': const Color(0xFFFFFBEB), // Amber 50
                'iconColor': const Color(0xFFD97706),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
              },
            ],
          ),

          // 5. CHẤT LƯỢNG ĐIỆN & KHÁCH HÀNG
          _buildMenuSection(
            title: 'CHẤT LƯỢNG ĐIỆN & CSKH',
            items: [
              {
                'title': 'Đo đạc phụ tải',
                'icon': Icons.file_upload_outlined,
                'bg': const Color(0xFFFFFBEB), // Amber 50
                'iconColor': const Color(0xFFD97706),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MainAnalysisScreen())),
              },
              {
                'title': 'Sóng hài THD',
                'icon': Icons.auto_graph_rounded,
                'bg': const Color(0xFFEFF6FF), // Blue 50
                'iconColor': const Color(0xFF2563EB),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MainAnalysisScreen())),
              },
              {
                'title': 'Báo cáo KT',
                'icon': Icons.analytics_outlined,
                'bg': const Color(0xFFECFDF5), // Emerald 50
                'iconColor': const Color(0xFF059669),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MainAnalysisScreen())),
              },
              {
                'title': 'Khách hàng',
                'icon': Icons.business_outlined,
                'bg': const Color(0xFFEEF2FF), // Indigo 50
                'iconColor': const Color(0xFF4F46E5),
                'onTap': () => _openModule('crm'),
              },
              {
                'title': 'Hỗ trợ CSKH',
                'icon': Icons.support_agent_rounded,
                'bg': const Color(0xFFF1F5F9), // Slate 50
                'iconColor': const Color(0xFF475569),
                'onTap': () => _openModule('crm'),
              },
            ],
          ),

          // 6. QUẢN TRỊ & PHÂN QUYỀN (RBAC)
          _buildMenuSection(
            title: 'QUẢN TRỊ & PHÂN QUYỀN',
            items: [
              {
                'title': 'Vai trò & Phân quyền',
                'icon': Icons.verified_user_outlined,
                'bg': const Color(0xFFEFF6FF), // Blue 50
                'iconColor': const Color(0xFF2563EB),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePermissionScreen())),
              },
              {
                'title': 'QL Người dùng',
                'icon': Icons.manage_accounts_outlined,
                'bg': const Color(0xFFF1F5F9), // Slate 50
                'iconColor': const Color(0xFF0F172A),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
              },
              {
                'title': 'Sơ đồ tổ chức',
                'icon': Icons.account_tree_outlined,
                'bg': const Color(0xFFECFDF5), // Emerald 50
                'iconColor': const Color(0xFF059669),
                'onTap': () => setState(() => _mobileNavIndex = 2),
              },
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<Map<String, dynamic>> items,
  }) {
    final query = _moduleSearchQuery.trim().toLowerCase();
    final isSectionMatch = query.isNotEmpty && title.toLowerCase().contains(query);
    final filteredItems = query.isEmpty
        ? items
        : items.where((it) {
            if (isSectionMatch) return true;
            final label = (it['title'] as String).toLowerCase();
            return label.contains(query);
          }).toList();

    if (filteredItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 18,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              final label = item['title'] as String;
              final icon = item['icon'] as IconData;
              final bg = item['bg'] as Color;
              final iconColor = item['iconColor'] as Color;
              final onTap = item['onTap'] as VoidCallback;

              return InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(icon, color: iconColor, size: 26),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE VIEW 3: SƠ ĐỒ TỔ CHỨC (ORGANIZATION STRUCTURE)
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
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
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
      case 'Vai trò & Phân quyền':
        return const RolePermissionScreen();
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
                _buildDesktopMenuItem('Vai trò & Phân quyền', Icons.verified_user_outlined),

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
              return InkWell(
                onTap: () => _openModule(m.key),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        m.key == 'procedure'
                            ? Icons.account_tree_outlined
                            : m.key == 'inventory'
                                ? Icons.inventory_2_outlined
                                : m.key == 'maintenance'
                                    ? Icons.build_outlined
                                    : m.key == 'power-quality'
                                        ? Icons.analytics_outlined
                                        : Icons.apps_outlined,
                        color: AppColors.slate700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          m.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.slate800),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.slate400),
                    ],
                  ),
                ),
              );
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
    final authProvider = Provider.of<AuthProvider>(context);
    final canCreate = authProvider.canCreateUser;

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
            if (canCreate)
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
              Row(
                children: [
                  // Status Dropdown
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _userStatusFilter != 'ALL' ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _userStatusFilter != 'ALL' ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _userStatusFilter,
                          isDense: true,
                          isExpanded: true,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: _userStatusFilter != 'ALL' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: _userStatusFilter != 'ALL' ? FontWeight.bold : FontWeight.w500,
                            color: _userStatusFilter != 'ALL' ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          items: const [
                            DropdownMenuItem(
                              value: 'ALL',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.filter_list_rounded, size: 13, color: Color(0xFF64748B)),
                                  SizedBox(width: 5),
                                  Expanded(child: Text('Tất cả trạng thái', style: TextStyle(fontSize: 11, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'active',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                                  SizedBox(width: 5),
                                  Expanded(child: Text('Hoạt động', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'disabled',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cancel_rounded, size: 13, color: Color(0xFFDC2626)),
                                  SizedBox(width: 5),
                                  Expanded(child: Text('Vô hiệu hóa', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _userStatusFilter = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Role Dropdown
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _userRoleFilter != 'ALL' ? const Color(0xFFFAF5FF) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _userRoleFilter != 'ALL' ? const Color(0xFFC084FC) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _userRoleFilter,
                          isDense: true,
                          isExpanded: true,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: _userRoleFilter != 'ALL' ? const Color(0xFF7E22CE) : const Color(0xFF64748B),
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: _userRoleFilter != 'ALL' ? FontWeight.bold : FontWeight.w500,
                            color: _userRoleFilter != 'ALL' ? const Color(0xFF7E22CE) : const Color(0xFF334155),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          items: const [
                            DropdownMenuItem(
                              value: 'ALL',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_outlined, size: 13, color: Color(0xFF64748B)),
                                  SizedBox(width: 5),
                                  Expanded(child: Text('Tất cả vai trò', style: TextStyle(fontSize: 11, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'tenant-admin',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield, size: 13, color: Color(0xFF7E22CE)),
                                  SizedBox(width: 5),
                                  Expanded(child: Text('Quản trị viên (Admin)', style: TextStyle(fontSize: 11, color: Color(0xFF7E22CE), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'tenant-user',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_outline, size: 13, color: Color(0xFF2563EB)),
                                  SizedBox(width: 5),
                                  Expanded(child: Text('Thành viên (Member)', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _userRoleFilter = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  user.fullName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate900,
                                  ),
                                ),
                              ),
                              if (authProvider.canUpdateUser || authProvider.canDeleteUser) ...[
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.more_vert, size: 16, color: AppColors.slate400),
                                  ),
                                  padding: EdgeInsets.zero,
                                  color: Colors.white,
                                  surfaceTintColor: Colors.transparent,
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  offset: const Offset(0, 36),
                                  onSelected: (action) async {
                                    if (action == 'org_profile') {
                                      _showOrgProfileModal(user);
                                    } else if (action == 'edit') {
                                      _showAddUserDialog(editingUser: user);
                                    } else if (action == 'role') {
                                      _showAssignRoleDialog(user);
                                    } else if (action == 'toggle') {
                                      final res = await _platformService.updateUser(
                                        user.id,
                                        status: isActive ? 'disabled' : 'active',
                                      );
                                      if (mounted) {
                                        if (res.success) {
                                          _loadAllPlatformData();
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(res.error ?? 'Không thể cập nhật trạng thái.'),
                                              backgroundColor: const Color(0xFFDC2626),
                                            ),
                                          );
                                        }
                                      }
                                    } else if (action == 'delete') {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Xóa người dùng'),
                                          content: Text('Bạn có chắc chắn muốn xóa "${user.fullName}" không?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              child: const Text('Xóa'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        final res = await _platformService.deleteUser(user.id);
                                        if (mounted) {
                                          if (res.success) {
                                            _loadAllPlatformData();
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(res.error ?? 'Không thể xóa người dùng.'),
                                                backgroundColor: const Color(0xFFDC2626),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'org_profile',
                                      height: 38,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.account_tree_outlined, size: 14, color: Color(0xFF059669)),
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            'Hồ sơ tổ chức',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (authProvider.canUpdateUser) ...[
                                      PopupMenuItem(
                                        value: 'edit',
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              'Sửa thông tin',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'role',
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5F3FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF7C3AED)),
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              'Phân vai trò',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: isActive ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                isActive ? Icons.block : Icons.check_circle_outline,
                                                size: 14,
                                                color: isActive ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              isActive ? 'Vô hiệu hóa tài khoản' : 'Kích hoạt tài khoản',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (authProvider.canDeleteUser) ...[
                                      const PopupMenuDivider(height: 1),
                                      PopupMenuItem(
                                        value: 'delete',
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              'Xóa người dùng',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFDC2626),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email.isNotEmpty ? user.email : 'Chưa có email',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isAdmin ? Colors.purple.shade50 : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isAdmin ? Colors.purple.shade200 : AppColors.slate200,
                                  ),
                                ),
                                child: Text(
                                  isAdmin ? 'Quản trị viên' : 'Thành viên',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isAdmin ? Colors.purple.shade700 : AppColors.slate600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.emerald50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5.5,
                                      height: 5.5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive ? AppColors.emerald700 : Colors.red.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isActive ? 'Hoạt động' : 'Vô hiệu hóa',
                                      style: TextStyle(
                                        color: isActive ? AppColors.emerald700 : Colors.red.shade700,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  
  Future<void> _showOrgProfileModal(TenantUser user) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<OrganizationSnapshot>(
          future: _platformService.getOrganizationSnapshot(),
          builder: (context, snapshot) {
            final hasData = snapshot.hasData;
            OrgNode? userNode;
            OrgNodeType? userNodeType;
            OrgAssignment? userAssignment;

            if (hasData) {
              final snap = snapshot.data!;
              try {
                userAssignment = snap.assignments.firstWhere(
                  (a) => a.userId == user.id,
                );
                userNode = snap.nodes.firstWhere(
                  (n) => n.id == userAssignment!.nodeId,
                );
                userNodeType = snap.nodeTypes.firstWhere(
                  (t) => t.id == userNode!.nodeTypeId,
                );
              } catch (_) {}
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: const Icon(Icons.account_tree_outlined, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hồ sơ tổ chức nhân sự',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.fullName,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.connectionState == ConnectionState.waiting) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ] else if (userNode != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  userNodeType?.name ?? 'Đơn vị / Phòng ban',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Đã gán',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            userNode.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mã vị trí: ${userNode.code}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (userAssignment?.startDate != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Ngày bổ nhiệm: ${userAssignment!.startDate}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFEF3C7)),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.info_outline, color: Color(0xFFD97706), size: 32),
                          SizedBox(height: 10),
                          Text(
                            'Chưa gán vào sơ đồ tổ chức',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Nhân sự này chưa được phân bổ vào phòng ban hoặc vị trí nào trên cây tổ chức doanh nghiệp.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (snapshot.hasData) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrgChartWorkspaceScreen(
                                snapshot: snapshot.data!,
                                treeName: 'Sơ đồ tổ chức SAVINA',
                                treeCode: 'SAVINA-MAIN',
                                onDataChanged: _loadAllPlatformData,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.account_tree_outlined, size: 18),
                      label: const Text(
                        'Mở Sơ đồ cây tổ chức',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignRoleDialog(TenantUser user) async {
    await AssignRoleModal.show(
      context: context,
      user: user,
      platformService: _platformService,
      onSaved: _loadAllPlatformData,
    );
  }

  void _showAddUserDialog({TenantUser? editingUser}) {
    final nameCtrl = TextEditingController(text: editingUser?.fullName ?? '');
    final emailCtrl = TextEditingController(text: editingUser?.email ?? '');
    final passCtrl = TextEditingController();
    String selectedRole = editingUser?.systemRole ?? 'tenant-user';
    String selectedStatus = editingUser?.status ?? 'active';
    bool obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(ctx).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header matching React Web
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        editingUser != null ? 'Chỉnh sửa người dùng' : 'Thêm người dùng',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    editingUser != null
                        ? 'Cập nhật phân quyền và thông tin thành viên'
                        : 'Tài khoản mới chưa có quyền. Quản trị viên gán vai trò sau khi tạo.',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.35),
                  ),
                  const SizedBox(height: 20),

                  // Field 1: Họ và tên
                  const Text(
                    'Họ và tên',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: nameCtrl,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 2: Email
                  const Text(
                    'Email',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        if (!emailCtrl.text.contains('@'))
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Text(
                              '@savina.com',
                              style: TextStyle(fontSize: 13.5, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 3: Mật khẩu
                  const Text(
                    'Mật khẩu',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: passCtrl,
                      obscureText: obscurePassword,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Từ 12 đến 128 ký tự.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),

                  // Actions (Hủy & Lưu người dùng)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng điền đầy đủ họ tên và email.')),
                            );
                            return;
                          }
                          if (editingUser == null && passCtrl.text.trim().length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Mật khẩu tối thiểu từ 6 đến 128 ký tự.')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);

                          String finalEmail = emailCtrl.text.trim();
                          if (!finalEmail.contains('@')) {
                            finalEmail = '$finalEmail@savina.com';
                          }

                          if (editingUser != null) {
                            final res = await _platformService.updateUser(
                              editingUser.id,
                              fullName: nameCtrl.text.trim(),
                              email: finalEmail,
                              password: passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : null,
                              status: selectedStatus,
                            );
                            if (mounted) {
                              if (res.success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã cập nhật thông tin người dùng!'),
                                    backgroundColor: Color(0xFF059669),
                                  ),
                                );
                                _loadAllPlatformData();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.error ?? 'Không thể cập nhật người dùng.'),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            }
                          } else {
                            final res = await _platformService.createUser(
                              fullName: nameCtrl.text.trim(),
                              email: finalEmail,
                              password: passCtrl.text.trim(),
                            );
                            if (mounted) {
                              if (res.success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã thêm người dùng thành công!'),
                                    backgroundColor: Color(0xFF059669),
                                  ),
                                );
                                _loadAllPlatformData();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.error ?? 'Không thể tạo người dùng.'),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6), // Blue 500
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          editingUser != null ? 'Lưu thay đổi' : 'Lưu người dùng',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Organization Structure View (Synchronized with React Web version)
  Widget _buildOrganizationView() {
    final snapshot = _orgSnapshot;
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
          children: const [
            Text('Tenant Portal', style: TextStyle(fontSize: 11.5, color: AppColors.slate500)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 14, color: AppColors.slate400),
            ),
            Text('Quản trị', style: TextStyle(fontSize: 11.5, color: AppColors.slate500)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 14, color: AppColors.slate400),
            ),
            Text('Sơ đồ tổ chức', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.slate700)),
          ],
        ),
        const SizedBox(height: 8),

        // 2. Title & Subtitle
        const Text(
          'Sơ đồ tổ chức',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Quản lý cấu trúc tổ chức trực tiếp trong dữ liệu lõi của tenant.',
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
                title: 'Cây tổ chức',
                icon: Icons.account_tree_outlined,
              ),
              const SizedBox(width: 8),
              _buildOrgSubTabButton(
                index: 1,
                title: 'Bổ nhiệm',
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
    final orgTrees = [
      {
        'code': 'SAVINA-MAIN',
        'name': 'Sơ đồ tổ chức SAVINA',
        'isPrimary': true,
        'description': 'Cây tổ chức chính, gồm SAVINA và các pháp nhân...',
        'type': 'Sơ đồ chính',
        'nodeCount': '${snapshot.nodes.length}',
        'status': 'Hoạt động',
      },
      {
        'code': '123',
        'name': 'CBC_IT',
        'isPrimary': false,
        'description': 'TEST',
        'type': 'Sơ đồ phụ',
        'nodeCount': '0',
        'status': 'Hoạt động',
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
            color: Colors.black.withOpacity(0.02),
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
                          decoration: const InputDecoration(
                            hintText: 'Tìm kiếm sơ đồ theo tên, mã...',
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
                          const SnackBar(content: Text('Chức năng thêm sơ đồ đang được hoàn thiện')),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Thêm sơ đồ mới', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                                  child: const Text(
                                    'CHÍNH',
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
                    Text(
                      item['description'] as String,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 10),

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
                                  treeName: item['name'] as String,
                                  treeCode: item['code'] as String,
                                  isPrimary: isPrimary,
                                  onDataChanged: _loadAllPlatformData,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                          label: const Text('Xem chi tiết', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                          tooltip: 'Chỉnh sửa',
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                          tooltip: 'Xóa',
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
                  'Hiển thị ${filteredTrees.length} / ${orgTrees.length} sơ đồ',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
                const Text(
                  'Nhấp "Xem chi tiết" để mở sơ đồ',
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
          fullName: 'Nhân viên',
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
          name: 'Đơn vị',
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
            color: Colors.black.withOpacity(0.02),
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
                            hintText: 'Tìm nhân sự, vị trí bổ nhiệm...',
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
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateAppointmentDialog(snapshot),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Bổ nhiệm người dùng',
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
                        label: 'Tất cả vai trò',
                        isSelected: _assignmentRoleFilter == 'ALL',
                        onTap: () => setState(() => _assignmentRoleFilter = 'ALL'),
                      ),
                      const SizedBox(width: 6),
                      _buildAssignmentFilterChip(
                        label: 'Bổ nhiệm chính',
                        isSelected: _assignmentRoleFilter == 'primary',
                        onTap: () => setState(() => _assignmentRoleFilter = 'primary'),
                      ),
                      const SizedBox(width: 6),
                      _buildAssignmentFilterChip(
                        label: 'Kiêm nhiệm',
                        isSelected: _assignmentRoleFilter == 'concurrent',
                        onTap: () => setState(() => _assignmentRoleFilter = 'concurrent'),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                      const SizedBox(width: 12),

                      // Status filter matching Web: Tất cả, Hoạt động, Không hoạt động, Đã kết thúc
                      _buildAssignmentFilterChip(
                        label: 'Tất cả trạng thái',
                        isSelected: _assignmentStatusFilter == 'ALL',
                        onTap: () => setState(() => _assignmentStatusFilter = 'ALL'),
                      ),
                      const SizedBox(width: 6),
                      _buildAssignmentFilterChip(
                        label: 'Hoạt động',
                        isSelected: _assignmentStatusFilter == 'active',
                        onTap: () => setState(() => _assignmentStatusFilter = 'active'),
                      ),
                      const SizedBox(width: 6),
                      _buildAssignmentFilterChip(
                        label: 'Không hoạt động',
                        isSelected: _assignmentStatusFilter == 'inactive',
                        onTap: () => setState(() => _assignmentStatusFilter = 'inactive'),
                      ),
                      const SizedBox(width: 6),
                      _buildAssignmentFilterChip(
                        label: 'Đã kết thúc',
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
                    const SizedBox(height: 8),
                    const Text(
                      'Không tìm thấy nhân sự bổ nhiệm phù hợp',
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
                    fullName: 'Nhân viên',
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
                    name: 'Đơn vị',
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
                  badgeLabel = 'Hoạt động';
                } else if (assignment.status == 'ended') {
                  badgeBg = const Color(0xFFF1F5F9);
                  badgeBorder = const Color(0xFFCBD5E1);
                  badgeDot = const Color(0xFF64748B);
                  badgeTextColor = const Color(0xFF64748B);
                  badgeLabel = 'Đã kết thúc';
                } else {
                  badgeBg = const Color(0xFFFEF2F2);
                  badgeBorder = const Color(0xFFFECACA);
                  badgeDot = const Color(0xFFDC2626);
                  badgeTextColor = const Color(0xFFDC2626);
                  badgeLabel = 'Không hoạt động';
                }

                // Date range duration
                String durationText = 'Không thời hạn';
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
                    durationText = 'Từ $startFormatted';
                  } else if (endFormatted.isNotEmpty) {
                    durationText = 'Đến $endFormatted';
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
                                  user.email.isNotEmpty ? user.email : 'chưa có email',
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
                              isPrimary ? 'Bổ nhiệm chính' : 'Kiêm nhiệm',
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
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF64748B)),
                            tooltip: 'Chỉnh sửa bổ nhiệm',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            onPressed: () => _showCreateAppointmentDialog(snapshot, assignment),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 17, color: Color(0xFFEF4444)),
                            tooltip: 'Xóa bổ nhiệm',
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
                  'Hiển thị ${filteredAssignments.length} / ${snapshot.assignments.length} bổ nhiệm',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                Text(
                  '$primaryCount chính · $concurrentCount kiêm nhiệm',
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
    final isEditing = existing != null;
    String selectedUserId = existing?.userId ?? (snapshot.users.isNotEmpty ? snapshot.users.first.id : '');
    String selectedNodeId = existing?.nodeId ?? (snapshot.nodes.isNotEmpty ? snapshot.nodes.first.id : '');
    bool isPrimary = existing?.isPrimary ?? false;
    String status = existing?.status ?? 'active';
    if (status == 'disabled') {
      status = 'inactive';
    } else if (status != 'active' && status != 'inactive' && status != 'ended') {
      status = 'active';
    }
    final noteCtrl = TextEditingController(text: existing?.note ?? '');

    DateTime? startDate = existing?.startDate != null ? DateTime.tryParse(existing!.startDate!) : null;
    DateTime? endDate = existing?.endDate != null ? DateTime.tryParse(existing!.endDate!) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(ctx).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
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

                // Header matching Web
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Chỉnh sửa bổ nhiệm nhân sự' : 'Tạo mới bổ nhiệm nhân sự',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Lưu trực tiếp vào cơ sở dữ liệu của tenant.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Chức danh (Org Node / Position)
                const Text(
                  'Chức danh',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
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
                    child: DropdownButton<String>(
                      value: selectedNodeId.isNotEmpty ? selectedNodeId : null,
                      isExpanded: true,
                      hint: const Text('Chọn chức danh', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                      items: snapshot.nodes.map((n) {
                        return DropdownMenuItem(
                          value: n.id,
                          child: Text(
                            '${n.name} (${n.code})',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedNodeId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Người dùng
                const Text(
                  'Người dùng',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
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
                    child: DropdownButton<String>(
                      value: selectedUserId.isNotEmpty ? selectedUserId : null,
                      isExpanded: true,
                      hint: const Text('Chọn người dùng', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                      items: snapshot.users.map((u) {
                        return DropdownMenuItem(
                          value: u.id,
                          child: Text(
                            u.fullName,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: isEditing
                          ? null
                          : (val) {
                              if (val != null) setDialogState(() => selectedUserId = val);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Row: Từ ngày & Đến ngày
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Từ ngày', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() => startDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    startDate != null
                                        ? '${startDate!.day.toString().padLeft(2, '0')}/${startDate!.month.toString().padLeft(2, '0')}/${startDate!.year}'
                                        : 'dd/mm/yyyy',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: startDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đến ngày', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: endDate ?? (startDate ?? DateTime.now()),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() => endDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    endDate != null
                                        ? '${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}'
                                        : 'dd/mm/yyyy',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: endDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Ghi chú
                const Text(
                  'Ghi chú',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Nhập ghi chú...',
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
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Vị trí chính (Checkbox)
                InkWell(
                  onTap: () => setDialogState(() => isPrimary = !isPrimary),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: isPrimary,
                            onChanged: (val) => setDialogState(() => isPrimary = val ?? false),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            activeColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFF94A3B8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Vị trí chính',
                          style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Trạng thái
                const Text(
                  'Trạng thái',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
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
                    child: DropdownButton<String>(
                      value: status,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Hoạt động', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Không hoạt động', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                        ),
                        DropdownMenuItem(
                          value: 'ended',
                          child: Text('Đã kết thúc', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => status = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Footer Actions matching Web (Hủy & Lưu thay đổi)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        foregroundColor: const Color(0xFF334155),
                      ),
                      child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedUserId.isEmpty || selectedNodeId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng chọn người dùng và chức danh.')),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        final sDateStr = startDate?.toIso8601String();
                        final eDateStr = endDate?.toIso8601String();

                        bool success = false;
                        if (isEditing) {
                          success = await _platformService.updateAssignment(
                            existing.id,
                            nodeId: selectedNodeId,
                            isPrimary: isPrimary,
                            startDate: sDateStr,
                            endDate: eDateStr,
                            status: status,
                            note: noteCtrl.text.trim(),
                          );
                        } else {
                          success = await _platformService.createAssignment(
                            userId: selectedUserId,
                            nodeId: selectedNodeId,
                            isPrimary: isPrimary,
                            startDate: sDateStr,
                            endDate: eDateStr,
                            status: status,
                            note: noteCtrl.text.trim(),
                          );
                        }

                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEditing ? 'Đã cập nhật bổ nhiệm thành công!' : 'Đã tạo bổ nhiệm thành công!'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                          _loadAllPlatformData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Lưu thay đổi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  // DELETE ASSIGNMENT CONFIRMATION
  void _confirmDeleteAssignment(OrgAssignment assignment, String userName, String nodeName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy bổ nhiệm nhân sự', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Bạn có chắc chắn muốn hủy bổ nhiệm nhân sự "$userName" khỏi vị trí "$nodeName" không?',
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
              final success = await _platformService.deleteAssignment(assignment.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã hủy bổ nhiệm thành công!'), backgroundColor: Color(0xFFEF4444)),
                );
                _loadAllPlatformData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa bổ nhiệm'),
          ),
        ],
      ),
    );
  }

  // DIALOG: KHÔNG GIAN LÀM VIỆC SƠ ĐỒ CÂY PHÂN CẤP
  void _showOrgTreeWorkspaceDialog(OrganizationSnapshot snapshot, String treeName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            treeName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Không gian làm việc sơ đồ tổ chức',
                            style: TextStyle(fontSize: 11, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20, color: AppColors.slate600),
                    ),
                  ],
                ),
              ),

              // Tree view content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cây phân cấp gồm ${snapshot.nodes.length} đơn vị phòng ban và ${snapshot.assignments.length} nhân sự bổ nhiệm.',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.slate600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._buildOrgTreeList(snapshot),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

// Tree Branch Painter for Hierarchy Lines
class _TreeBranchPainter extends CustomPainter {
  final Color color;

  _TreeBranchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Vertical line down from top
    path.moveTo(size.width * 0.3, 0);
    path.lineTo(size.width * 0.3, size.height * 0.5);
    // Horizontal branch line to right
    path.lineTo(size.width, size.height * 0.5);

    canvas.drawPath(path, paint);

    // Small branch joint circle
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.5), 2.5, circlePaint);
  }

  @override
  bool shouldRepaint(covariant _TreeBranchPainter oldDelegate) => oldDelegate.color != color;
}
