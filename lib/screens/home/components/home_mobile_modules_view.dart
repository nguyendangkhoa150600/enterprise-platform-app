import 'package:flutter/material.dart';
import '../../workspace_screen.dart';
import '../../procedure_screen.dart';
import '../../hrm_hub_screen.dart';
import '../../attendance_monitor_screen.dart';
import '../../attendance_screen.dart';
import '../../my_requests_screen.dart';
import '../../profile_income_screen.dart';
import '../../account_screen.dart';
import '../../leave_balances_screen.dart';
import '../../fleet_schedule_screen.dart';
import '../../maintenance_screen.dart';
import '../../inventory_screen.dart';
import '../../main_analysis_screen.dart';
import '../../role_permission_screen.dart';
import '../../user_management_screen.dart';
import '../../assistant_chat_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/permissions/hrm_permissions.dart';
import '../../../models/platform_models.dart';
import '../../../providers/auth_provider.dart';

class HomeMobileModulesView extends StatefulWidget {
  /// Modules of the signed-in user (the server filters the catalog by the user's roles).
  final List<ModuleCatalogItem> modules;
  final bool modulesLoaded;
  final VoidCallback onSelectOrgChart;
  final VoidCallback? onOpenDashboard;
  final Function(String key) onOpenModule;

  const HomeMobileModulesView({
    super.key,
    this.modules = const [],
    this.modulesLoaded = true,
    required this.onSelectOrgChart,
    this.onOpenDashboard,
    required this.onOpenModule,
  });

  @override
  State<HomeMobileModulesView> createState() => _HomeMobileModulesViewState();
}

class _HomeMobileModulesViewState extends State<HomeMobileModulesView> {
  String _moduleSearchQuery = '';
  final TextEditingController _moduleSearchController = TextEditingController();
  String _selectedCategory = 'ALL'; // 'ALL', 'APPS', 'ORG', 'ADMIN'

  @override
  void dispose() {
    _moduleSearchController.dispose();
    super.dispose();
  }

  /// Sections not shown on mobile.
  static const _hiddenSections = {
    'BẢO TRÌ & THIẾT BỊ',
    'KHO & VẬT TƯ',
    'CHẤT LƯỢNG ĐIỆN & CSKH',
  };

  bool _mod(String key) => widget.modules.any((m) => m.key == key && m.isActive);
  bool get _modProcedure => _mod('procedure-engine') || _mod('procedure');

  /// HRM menu item: the HRM module is available AND the user holds a permission of that web page.
  bool _hrm(String path) => _mod('hrm') && HrmCapabilities.instance.pageAllowed(path);
  bool _hrmTab(String path, String tab) => _mod('hrm') && HrmCapabilities.instance.tabAllowed(path, tab);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    context.watch<HrmCapabilities>();
    final showApps = _selectedCategory == 'ALL' || _selectedCategory == 'APPS';
    // The ORG and ADMIN major categories are hidden from the mobile menu.
    const showOrg = false;
    const showAdmin = false;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Drawer button
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 12, top: 2),
            child: Row(
              children: [
                Builder(
                  builder: (ctx) => InkWell(
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.menu_rounded, size: 20, color: Color(0xFF1E293B)),
                    ),
                  ),
                ),
                const Text(
                  'Menu Phân hệ',
                  style: TextStyle(
                    fontSize: 19,
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
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
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

          // Category Pills Filter: [Tất cả] [Ứng dụng] [Tổ chức & Bộ máy] [Quản trị]
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                _buildCategoryPill(
                  id: 'ALL',
                  label: 'Tất cả',
                  icon: Icons.apps_rounded,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  id: 'APPS',
                  label: 'Ứng dụng',
                  icon: Icons.grid_view_rounded,
                ),
              ],
            ),
          ),

          // ==========================================
          // MỤC LỚN 1: ỨNG DỤNG
          // ==========================================
          if (showApps) ...[
            _buildMajorCategoryHeader(
              title: 'MỤC LỚN: ỨNG DỤNG',
              subtitle: 'Các phân hệ vận hành, dự án, quy trình & sản xuất kinh doanh',
              icon: Icons.grid_view_rounded,
              color: const Color(0xFF2563EB),
            ),

            // 1. WORKPLACE (KHÔNG GIAN LÀM VIỆC / CÔNG VIỆC)
            _buildMenuSection(
              title: 'CÔNG VIỆC (WORKPLACE)',
              items: [
                {
                  'title': 'Công việc của tôi',
                  'visible': _mod('workspace'),
                  'icon': Icons.format_list_bulleted_rounded,
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 0))),
                },
                {
                  'title': 'Công việc khác',
                  'visible': _mod('workspace'),
                  'icon': Icons.assignment_outlined,
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 1))),
                },
                {
                  'title': 'Dự án',
                  'visible': _mod('workspace'),
                  'icon': Icons.work_outline_rounded,
                  'bg': const Color(0xFFFFFBEB), // Amber 50
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 2))),
                },
                {
                  'title': 'Tài liệu',
                  'visible': _mod('workspace'),
                  'icon': Icons.description_outlined,
                  'bg': const Color(0xFFF0FDF4), // Green 50
                  'iconColor': const Color(0xFF16A34A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 4))),
                },
                {
                  'title': 'Báo cáo',
                  'visible': _mod('workspace'),
                  'icon': Icons.bar_chart_rounded,
                  'bg': const Color(0xFFFAF5FF), // Purple 50
                  'iconColor': const Color(0xFF9333EA),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 5))),
                },
                {
                  'title': 'Khách hàng & HĐ',
                  'visible': _mod('workspace'),
                  'icon': Icons.handshake_outlined,
                  'bg': const Color(0xFFEEF2FF), // Indigo 50
                  'iconColor': const Color(0xFF4F46E5),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 3))),
                },
              ],
            ),

            // 2. QUY TRÌNH (PROCEDURE ENGINE)
            _buildMenuSection(
              title: 'QUY TRÌNH',
              items: [
                {
                  'title': 'Tổng quan',
                  'visible': _modProcedure,
                  'icon': Icons.space_dashboard_rounded,
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 0))),
                },
                {
                  'title': 'Hồ sơ xử lý',
                  'visible': _modProcedure,
                  'icon': Icons.assignment_outlined,
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 1))),
                },
              ],
            ),

            // 3. QUẢN TRỊ NHÂN SỰ (HRM)
            _buildMenuSection(
              title: 'QUẢN TRỊ NHÂN SỰ (HRM)',
              items: [
                // Tổng quan
                {
                  'title': 'Bàn làm việc',
                  'visible': _hrm('/'),
                  'icon': Icons.space_dashboard_rounded,
                  'bg': const Color(0xFFEEF2FF), // Indigo 50
                  'iconColor': const Color(0xFF4F46E5),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'dashboard'))),
                },
                {
                  'title': 'Giám sát chấm công',
                  'visible': _hrm('/attendance-monitor'),
                  'icon': Icons.insights_rounded,
                  'bg': const Color(0xFFFEF3C7), // Amber 100
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceMonitorScreen())),
                },
                {
                  'title': 'Đơn từ cần xử lý',
                  'visible': _hrm('/approvals'),
                  'icon': Icons.assignment_turned_in_outlined,
                  'bg': const Color(0xFFE0F2FE), // Sky 50
                  'iconColor': const Color(0xFF0284C7),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'requests'))),
                },

                // Cá nhân
                {
                  'title': 'Bảng công của tôi',
                  'visible': _hrm('/my-work'),
                  'icon': Icons.calendar_today_outlined,
                  'bg': const Color(0xFFF0FDF4), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(initialTabIndex: 1))),
                },
                {
                  'title': 'Chấm công GPS',
                  'visible': _mod('hrm') && HrmCapabilities.instance.canPunch,
                  'icon': Icons.fingerprint_rounded,
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(initialTabIndex: 0))),
                },
                {
                  'title': 'Đơn từ của tôi',
                  'visible': _hrm('/requests'),
                  'icon': Icons.assignment_outlined,
                  'bg': const Color(0xFFEFF6FF), // Sky 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRequestsScreen())),
                },
                {
                  'title': 'Hồ sơ & Thu nhập',
                  'visible': _hrm('/profile'),
                  'icon': Icons.assignment_ind_outlined,
                  'bg': const Color(0xFFEEF2FF), // Indigo 50
                  'iconColor': const Color(0xFF4F46E5),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileIncomeScreen())),
                },
                {
                  'title': 'Tài khoản & Mật khẩu',
                  'icon': Icons.manage_accounts_outlined,
                  'bg': const Color(0xFFF0FDF4), // Green 50
                  'iconColor': const Color(0xFF16A34A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
                },

                // Quản lý
                {
                  'title': 'Nhân sự',
                  'visible': _hrm('/employees'),
                  'icon': Icons.people_alt_outlined,
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'employees'))),
                },
                {
                  'title': 'Bảng công tổng hợp',
                  'visible': _hrm('/timekeeping'),
                  'icon': Icons.calculate_outlined,
                  'bg': const Color(0xFFF0FDF4), // Green 50
                  'iconColor': const Color(0xFF16A34A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'timesheet'))),
                },
                {
                  'title': 'Quỹ phép năm',
                  'visible': _hrm('/leave'),
                  'icon': Icons.beach_access_rounded,
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveBalancesScreen())),
                },
                {
                  'title': 'Lương và chi trả',
                  'visible': _hrm('/payroll'),
                  'icon': Icons.payments_outlined,
                  'bg': const Color(0xFFFFFBEB), // Amber 50
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'payroll'))),
                },
                {
                  'title': 'Lịch xe',
                  'visible': _hrm('/fleet'),
                  'icon': Icons.directions_car_filled_outlined,
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF1D4ED8),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FleetScheduleScreen())),
                },
              ],
            ),

            // 4. BẢO TRÌ & THIẾT BỊ
            _buildMenuSection(
              title: 'BẢO TRÌ & THIẾT BỊ',
              items: [
                {
                  'title': 'Thiết bị MBA',
                  'visible': _mod('maintenance'),
                  'icon': Icons.bolt_rounded,
                  'bg': const Color(0xFFFFF7ED), // Orange 50
                  'iconColor': const Color(0xFFEA580C),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen())),
                },
                {
                  'title': 'Lịch bảo trì',
                  'visible': _mod('maintenance'),
                  'icon': Icons.calendar_month_outlined,
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen())),
                },
                {
                  'title': 'Phiếu công tác',
                  'visible': _mod('maintenance'),
                  'icon': Icons.build_circle_outlined,
                  'bg': const Color(0xFFFAF5FF), // Purple 50
                  'iconColor': const Color(0xFF9333EA),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen())),
                },
              ],
            ),

            // 5. KHO & VẬT TƯ
            _buildMenuSection(
              title: 'KHO & VẬT TƯ',
              items: [
                {
                  'title': 'Sổ kho',
                  'visible': _mod('inventory'),
                  'icon': Icons.inventory_2_outlined,
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
                },
                {
                  'title': 'Xuất nhập kho',
                  'visible': _mod('inventory'),
                  'icon': Icons.swap_horiz_rounded,
                  'bg': const Color(0xFFF0F9FF), // Sky 50
                  'iconColor': const Color(0xFF0284C7),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
                },
                {
                  'title': 'Cảnh báo tồn',
                  'visible': _mod('inventory'),
                  'icon': Icons.warning_amber_rounded,
                  'bg': const Color(0xFFFFFBEB), // Amber 50
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
                },
              ],
            ),

            // 6. CHẤT LƯỢNG ĐIỆN & KHÁCH HÀNG
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
                  'onTap': () => widget.onOpenModule('crm'),
                },
                {
                  'title': 'Hỗ trợ CSKH',
                  'icon': Icons.support_agent_rounded,
                  'bg': const Color(0xFFF1F5F9), // Slate 50
                  'iconColor': const Color(0xFF475569),
                  'onTap': () => widget.onOpenModule('crm'),
                },
              ],
            ),

            // 7. TIỆN ÍCH & TÍNH NĂNG KHÁC
            _buildMenuSection(
              title: 'TIỆN ÍCH & TÍNH NĂNG KHÁC',
              items: [
                {
                  'title': 'Lịch & Thông báo',
                  'visible': false,
                  'icon': Icons.event_note_outlined,
                  'bg': const Color(0xFFEFF6FF), // Sky 50
                  'iconColor': const Color(0xFF0284C7),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'schedule'))),
                },
                {
                  'title': 'Người phụ thuộc',
                  'visible': false,
                  'icon': Icons.family_restroom_outlined,
                  'bg': const Color(0xFFFFFBEB), // Amber 50
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'dependents'))),
                },
                {
                  'title': 'Quản lý Ca làm',
                  'visible': false,
                  'icon': Icons.schedule_rounded,
                  'bg': const Color(0xFFFFFBEB), // Amber 50
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'shifts'))),
                },
                {
                  'title': 'Xử lý Đơn từ',
                  'visible': false,
                  'icon': Icons.fact_check_outlined,
                  'bg': const Color(0xFFF5F3FF), // Purple 50
                  'iconColor': const Color(0xFF7C3AED),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'approvals'))),
                },
                {
                  'title': 'Tiền lương & Chi trả',
                  'visible': false,
                  'icon': Icons.account_balance_wallet_outlined,
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'payroll'))),
                },
                {
                  'title': 'Ứng & Thu hồi lương',
                  'visible': false,
                  'icon': Icons.price_change_outlined,
                  'bg': const Color(0xFFFFF7ED), // Orange 50
                  'iconColor': const Color(0xFFEA580C),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'advances'))),
                },
                {
                  'title': 'Chính sách & Cấu hình',
                  'visible': false,
                  'icon': Icons.tune_rounded,
                  'bg': const Color(0xFFF8FAFC), // Slate 50
                  'iconColor': const Color(0xFF475569),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'config'))),
                },
                {
                  'title': 'Hệ thống & Tích hợp',
                  'visible': false,
                  'icon': Icons.hub_outlined,
                  'bg': const Color(0xFFEEF2FF), // Indigo 50
                  'iconColor': const Color(0xFF4F46E5),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'integrations'))),
                },
                {
                  'title': 'Trợ lý AI Savina',
                  'icon': Icons.auto_awesome,
                  'bg': const Color(0xFFEFF6FF), // Sky 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantChatScreen())),
                },
              ],
            ),

            // 0. TỔNG QUAN & ỨNG DỤNG (Bảng điều khiển, Ứng dụng phân hệ)
            _buildMenuSection(
              title: 'TỔNG QUAN & ỨNG DỤNG',
              items: [
                {
                  'title': 'Bảng điều khiển',
                  'icon': Icons.grid_view_outlined,
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => widget.onOpenDashboard?.call(),
                },
                {
                  'title': 'Ứng dụng phân hệ',
                  'icon': Icons.inventory_2_outlined,
                  'bg': const Color(0xFFF0FDF4), // Green 50
                  'iconColor': const Color(0xFF16A34A),
                  'onTap': () => setState(() => _selectedCategory = 'APPS'),
                },
              ],
            ),

            // QUẢN TRỊ DANH TÍNH & TRUY CẬP
            _buildMenuSection(
              title: 'QUẢN TRỊ DANH TÍNH & TRUY CẬP',
              items: [
                {
                  'title': 'Tài khoản người dùng',
                  'visible': auth.canViewUsers,
                  'icon': Icons.people_outline,
                  'bg': const Color(0xFFF1F5F9), // Slate 50
                  'iconColor': const Color(0xFF0F172A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                },
                {
                  'title': 'Vai trò & phân quyền',
                  'visible': auth.canViewRoles,
                  'icon': Icons.verified_user_outlined,
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePermissionScreen())),
                },
              ],
            ),
          ],

          // ==========================================
          // MỤC LỚN 2: TỔ CHỨC & BỘ MÁY
          // ==========================================
          if (showOrg) ...[
            _buildMajorCategoryHeader(
              title: 'MỤC LỚN: TỔ CHỨC & BỘ MÁY',
              subtitle: 'Sơ đồ tổ chức, phòng ban, trung tâm & điều phối bổ nhiệm',
              icon: Icons.alt_route_rounded,
              color: const Color(0xFF059669),
            ),
            _buildMenuSection(
              title: 'TỔ CHỨC & BỘ MÁY',
              items: [
                {
                  'title': 'Sơ đồ tổ chức',
                  'visible': auth.canViewOrganization,
                  'icon': Icons.alt_route_rounded,
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': widget.onSelectOrgChart,
                },
                {
                  'title': 'Cây cơ cấu phòng ban',
                  'visible': auth.canViewOrganization,
                  'icon': Icons.account_tree_outlined,
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': widget.onSelectOrgChart,
                },
                {
                  'title': 'Bổ nhiệm nhân sự',
                  'visible': _hrmTab('/employees', 'decisions'),
                  'icon': Icons.people_alt_outlined,
                  'bg': const Color(0xFFEEF2FF), // Indigo 50
                  'iconColor': const Color(0xFF4F46E5),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'employees'))),
                },
              ],
            ),
          ],

          // ==========================================
          // MỤC LỚN 3: QUẢN TRỊ
          // ==========================================
          if (showAdmin) ...[
            _buildMajorCategoryHeader(
              title: 'MỤC LỚN: QUẢN TRỊ',
              subtitle: 'Quản trị danh tính, tài khoản người dùng & ma trận phân quyền',
              icon: Icons.shield_outlined,
              color: const Color(0xFF7C3AED),
            ),
            _buildMenuSection(
              title: 'QUẢN TRỊ DANH TÍNH & TRUY CẬP',
              items: [
                {
                  'title': 'Tài khoản người dùng',
                  'visible': auth.canViewUsers,
                  'icon': Icons.people_outline,
                  'bg': const Color(0xFFF1F5F9), // Slate 50
                  'iconColor': const Color(0xFF0F172A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                },
                {
                  'title': 'Vai trò & phân quyền',
                  'visible': auth.canViewRoles,
                  'icon': Icons.verified_user_outlined,
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePermissionScreen())),
                },
                {
                  'title': 'Chính sách & Cấu hình',
                  'visible': _hrm('/settings'),
                  'icon': Icons.tune_rounded,
                  'bg': const Color(0xFFF8FAFC), // Slate 50
                  'iconColor': const Color(0xFF475569),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'config'))),
                },
              ],
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedCategory == id;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMajorCategoryHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: color.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<Map<String, dynamic>> items,
  }) {
    if (_hiddenSections.contains(title)) return const SizedBox.shrink();
    items = items.where((it) => it['visible'] != false).toList();
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
            color: Colors.black.withValues(alpha: 0.02),
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
              fontSize: 13.5,
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
}
