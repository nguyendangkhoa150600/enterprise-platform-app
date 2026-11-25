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
import '../../inventory/inventory_overview_screen.dart';
import '../../inventory/inventory_items_screen.dart';
import '../../inventory/inventory_transactions_screen.dart';
import '../../inventory/inventory_documents_screen.dart';
import '../../inventory/inventory_issue_requests_screen.dart';
import '../../inventory/inventory_assets_screen.dart';
import '../../inventory/inventory_reports_screen.dart';
import '../../inventory/inventory_settings_screen.dart';
import '../../main_analysis_screen.dart';
import '../../role_permission_screen.dart';
import '../../user_management_screen.dart';
import '../../assistant_chat_screen.dart';
import '../../enterprise_applications_screen.dart';
import '../../../features/correspondence/presentation/screens/correspondence_overview_screen.dart';
import '../../../features/correspondence/presentation/screens/correspondence_mine_screen.dart';
import '../../../features/correspondence/presentation/screens/correspondence_tracking_screen.dart';
import '../../../features/correspondence/presentation/screens/correspondence_incoming_screen.dart';
import '../../../features/correspondence/presentation/screens/correspondence_outgoing_screen.dart';
import '../../../features/correspondence/presentation/screens/correspondence_archive_screen.dart';
import '../../../features/correspondence/presentation/screens/correspondence_report_screen.dart';
import '../../../features/finance/presentation/screens/finance_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/i18n/app_i18n.dart';
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
  String _selectedCategory = 'APPS'; // 'APPS' (Grid), 'LIST'

  @override
  void dispose() {
    _moduleSearchController.dispose();
    super.dispose();
  }

  /// Sections not shown on mobile.
  static const _hiddenSections = {
    'BẢO TRÌ & THIẾT BỊ',
    'CHẤT LƯỢNG ĐIỆN & CSKH',
  };

  bool _mod(String key) {
    if (widget.modules.isEmpty) return true;
    final k = key.toLowerCase();
    return widget.modules.any((m) {
      final mk = m.key.toLowerCase();
      if (k == 'hrm') {
        return (mk == 'hrm' ||
                mk == 'human-resource' ||
                mk == 'human_resource' ||
                mk.contains('hrm')) &&
            (m.isActive == true);
      }
      return (mk == k || mk.replaceAll('-', '_') == k.replaceAll('-', '_')) &&
          (m.isActive == true);
    });
  }

  bool get _modProcedure => _mod('procedure-engine') || _mod('procedure');
  bool get _modFinance =>
      _mod('finance') ||
      _mod('financial') ||
      _mod('tai-chinh') ||
      _mod('taichinh') ||
      widget.modules.isEmpty;
  bool get _modInventory =>
      _mod('inventory') ||
      _mod('warehouse') ||
      _mod('kho') ||
      _mod('supply-chain') ||
      widget.modules.isEmpty;

  /// HRM menu item: the HRM module is available AND the user holds a permission of that web page.
  bool _hrm(String path) => _mod('hrm') && HrmCapabilities.instance.pageAllowed(path);
  bool _hrmTab(String path, String tab) => _mod('hrm') && HrmCapabilities.instance.tabAllowed(path, tab);

  bool _canPunch(AuthProvider auth, HrmCapabilities hrmCaps) {
    if (!_mod('hrm')) return false;
    if (auth.isAdmin || auth.isTenantAdmin || auth.isPlatformAdmin) return true;
    if (!hrmCaps.loaded || hrmCaps.actions.isEmpty) return true;
    return hrmCaps.canPunch || hrmCaps.pageAllowed('/my-work');
  }

  bool get _showOrg => false;
  bool get _showAdmin => false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    context.watch<HrmCapabilities>();
    final canShowInventory = (auth.isTenantAdmin == true) || (auth.isPlatformAdmin == true) || _modInventory;
    final showApps = true;

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

          // View Mode Switcher: [Ứng dụng] [Danh sách]
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                _buildCategoryPill(
                  id: 'APPS',
                  label: 'modules_menu.apps'.tr(),
                  icon: Icons.grid_view_rounded,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  id: 'LIST',
                  label: 'modules_menu.list'.tr(),
                  icon: Icons.view_list_rounded,
                ),
              ],
            ),
          ),

          // ==========================================
          // MỤC LỚN 1: ỨNG DỤNG / DANH SÁCH
          // ==========================================
          if (showApps) ...[
            // 1. CÔNG VIỆC
            _buildMenuSection(
              title: 'CÔNG VIỆC',
              items: [
                {
                  'title': 'Công việc của tôi',
                  'visible': _mod('workspace'),
                  'icon': Icons.format_list_bulleted_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_workspace_tasks.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 0))),
                },
                {
                  'title': 'Công việc khác',
                  'visible': _mod('workspace'),
                  'icon': Icons.assignment_outlined,
                  'imageAsset': 'assets/images/icons/dashboard_work_todo.png',
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 1))),
                },
                {
                  'title': 'Dự án',
                  'visible': _mod('workspace'),
                  'icon': Icons.work_outline_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_workspace_projects.png',
                  'bg': const Color(0xFFFFFBEB), // Amber 50
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 2))),
                },
                {
                  'title': 'Tài liệu',
                  'visible': _mod('workspace'),
                  'icon': Icons.description_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_shared_library.png',
                  'bg': const Color(0xFFF0FDF4), // Green 50
                  'iconColor': const Color(0xFF16A34A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 4))),
                },
                {
                  'title': 'Báo cáo',
                  'visible': _mod('workspace'),
                  'icon': Icons.bar_chart_rounded,
                  'imageAsset': 'assets/images/icons/nav_reports.png',
                  'bg': const Color(0xFFFAF5FF), // Purple 50
                  'iconColor': const Color(0xFF9333EA),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 5))),
                },
                {
                  'title': 'Khách hàng & HĐ',
                  'visible': _mod('workspace'),
                  'icon': Icons.handshake_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_crm_leads.png',
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
                  'imageAsset': 'assets/images/icons/sidebar_procedure_workspace.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 0))),
                },
                {
                  'title': 'Hồ sơ xử lý',
                  'visible': _modProcedure,
                  'icon': Icons.assignment_outlined,
                  'imageAsset': 'assets/images/icons/dashboard_procedure_tasks.png',
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 1))),
                },
              ],
            ),

            // 3. TÀI CHÍNH (FINANCE)
            _buildMenuSection(
              title: 'TÀI CHÍNH',
              items: [
                {
                  'title': 'Dashboard',
                  'visible': _modFinance,
                  'icon': Icons.dashboard_outlined,
                  'imageAsset': 'assets/images/icons/module_finance.png',
                  'bg': const Color(0xFFF5F3FF), // Violet 50
                  'iconColor': const Color(0xFF7C3AED), // Violet 600
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen(initialTab: 0))),
                },
                {
                  'title': 'Phiếu thu',
                  'visible': _modFinance,
                  'icon': Icons.arrow_downward_rounded,
                  'imageAsset': null,
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669), // Emerald 600
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen(initialTab: 1))),
                },
                {
                  'title': 'Phiếu chi',
                  'visible': _modFinance,
                  'icon': Icons.arrow_upward_rounded,
                  'imageAsset': null,
                  'bg': const Color(0xFFFFF1F2), // Rose 50
                  'iconColor': const Color(0xFFE11D48), // Rose 600
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen(initialTab: 2))),
                },
                {
                  'title': 'Chuyển tiền',
                  'visible': _modFinance,
                  'icon': Icons.swap_horiz_rounded,
                  'imageAsset': null,
                  'bg': const Color(0xFFF0F9FF), // Sky 50
                  'iconColor': const Color(0xFF0284C7), // Sky 600
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen(initialTab: 3))),
                },
                {
                  'title': 'Tài khoản',
                  'visible': _modFinance,
                  'icon': Icons.account_balance_wallet_outlined,
                  'imageAsset': null,
                  'bg': const Color(0xFFEEF2FF), // Indigo 50
                  'iconColor': const Color(0xFF4F46E5), // Indigo 600
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen(initialTab: 4))),
                },
                {
                  'title': 'Báo cáo',
                  'visible': _modFinance,
                  'icon': Icons.pie_chart_outline_rounded,
                  'imageAsset': null,
                  'bg': const Color(0xFFFFFBEB), // Amber 50
                  'iconColor': const Color(0xFFD97706), // Amber 600
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen(initialTab: 5))),
                },
              ],
            ),

            // 3. KHO & VẬT TƯ (TỒN KHO)
            _buildMenuSection(
              title: 'KHO & VẬT TƯ',
              items: [
                {
                  'title': 'Tổng quan',
                  'visible': canShowInventory,
                  'icon': Icons.space_dashboard_rounded,
                  'imageAsset': 'assets/images/icons/module_inventory.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryOverviewScreen())),
                },
                {
                  'title': 'Kho & Danh mục',
                  'visible': canShowInventory,
                  'icon': Icons.inventory_2_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_inventory_stock.png',
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryItemsScreen())),
                },
                {
                  'title': 'Giao dịch & Nhập xuất',
                  'visible': canShowInventory,
                  'icon': Icons.swap_horiz_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_inventory_issue_requests.png',
                  'bg': const Color(0xFFF0F9FF), // Sky 50
                  'iconColor': const Color(0xFF0284C7),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryTransactionsScreen())),
                },
                {
                  'title': 'Chứng từ kho',
                  'visible': canShowInventory,
                  'icon': Icons.receipt_long_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_inventory_documents.png',
                  'bg': const Color(0xFFFAF5FF), // Purple 50
                  'iconColor': const Color(0xFF9333EA),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryDocumentsScreen())),
                },
                {
                  'title': 'Duyệt chứng từ',
                  'visible': canShowInventory,
                  'icon': Icons.assignment_turned_in_outlined,
                  'imageAsset': 'assets/images/icons/dashboard_approvals.png',
                  'bg': const Color(0xFFFEF3C7), // Amber 50
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryDocumentsScreen(
                    initialStatus: 'PENDING',
                    title: 'Duyệt chứng từ',
                    subtitle: 'Phê duyệt các chứng từ xuất nhập kho',
                  ))),
                },
                {
                  'title': 'Yêu cầu xuất từ đơn bán',
                  'visible': canShowInventory,
                  'icon': Icons.outbox_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_inventory_issue_requests.png',
                  'bg': const Color(0xFFFFF7ED), // Orange 50
                  'iconColor': const Color(0xFFEA580C),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryIssueRequestsScreen())),
                },
                {
                  'title': 'Cây tài sản',
                  'visible': false,
                  'icon': Icons.account_tree_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_inventory_assets_tree.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryAssetsScreen(initialTab: 1))),
                },
                {
                  'title': 'Tài sản',
                  'visible': false,
                  'icon': Icons.devices_other_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_inventory_custody.png',
                  'bg': const Color(0xFFEEF2FF), // Indigo 50
                  'iconColor': const Color(0xFF4F46E5),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryAssetsScreen(initialTab: 0))),
                },
                {
                  'title': 'Báo cáo kho',
                  'visible': false,
                  'icon': Icons.bar_chart_rounded,
                  'imageAsset': 'assets/images/icons/nav_reports.png',
                  'bg': const Color(0xFFF0FDF4), // Green 50
                  'iconColor': const Color(0xFF16A34A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryReportsScreen())),
                },
                {
                  'title': 'Cài đặt',
                  'visible': false,
                  'icon': Icons.tune_rounded,
                  'imageAsset': 'assets/images/icons/nav_settings.png',
                  'bg': const Color(0xFFF1F5F9), // Slate 50
                  'iconColor': const Color(0xFF475569),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventorySettingsScreen())),
                },
              ],
            ),

            // 3. QUẢN TRỊ NHÂN SỰ
            _buildMenuSection(
              title: 'QUẢN TRỊ NHÂN SỰ',
              items: [
                // Tổng quan
                {
                  'title': 'Bàn làm việc',
                  'visible': _hrm('/'),
                  'icon': Icons.grid_view_rounded,
                  'imageAsset': 'assets/images/icons/nav_dashboard.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'dashboard'))),
                },
                {
                  'title': 'Giám sát chấm công',
                  'visible': _hrm('/attendance-monitor'),
                  'icon': Icons.monitor_heart_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_attendance_monitor.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF0284C7),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceMonitorScreen())),
                },
                {
                  'title': 'Đơn từ cần xử lý',
                  'visible': _hrm('/approvals'),
                  'icon': Icons.fact_check_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_approvals.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'requests'))),
                },

                // Cá nhân
                {
                  'title': 'Bảng công của tôi',
                  'visible': _hrm('/my-work'),
                  'icon': Icons.access_time_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_my_work.png',
                  'bg': const Color(0xFFF0FDF4), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(initialTabIndex: 1))),
                },
                {
                  'title': 'Chấm công GPS',
                  'visible': _canPunch(auth, context.watch<HrmCapabilities>()),
                  'icon': Icons.fingerprint_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_gps.png',
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(initialTabIndex: 0))),
                },
                {
                  'title': 'Đơn từ của tôi',
                  'visible': _hrm('/requests'),
                  'icon': Icons.description_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_requests.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRequestsScreen())),
                },
                {
                  'title': 'Hồ sơ & Thu nhập',
                  'visible': _hrm('/profile'),
                  'icon': Icons.account_circle_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_profile.png',
                  'bg': const Color(0xFFEEF2FF), // Indigo 50
                  'iconColor': const Color(0xFF4F46E5),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileIncomeScreen())),
                },
                {
                  'title': 'Tài khoản & Mật khẩu',
                  'icon': Icons.manage_accounts_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_account.png',
                  'bg': const Color(0xFFF0FDF4), // Green 50
                  'iconColor': const Color(0xFF16A34A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
                },

                // Quản lý
                {
                  'title': 'Nhân sự',
                  'visible': _hrm('/employees'),
                  'icon': Icons.people_outline_rounded,
                  'imageAsset': 'assets/images/icons/nav_users.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'employees'))),
                },
                {
                  'title': 'Bảng công tổng hợp',
                  'visible': _hrm('/timekeeping'),
                  'icon': Icons.edit_calendar_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_timekeeping.png',
                  'bg': const Color(0xFFF0FDF4), // Green 50
                  'iconColor': const Color(0xFF16A34A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'timesheet'))),
                },
                {
                  'title': 'Quỹ phép năm',
                  'visible': _hrm('/leave'),
                  'icon': Icons.date_range_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_leave.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveBalancesScreen())),
                },
                {
                  'title': 'Lương và chi trả',
                  'visible': _hrm('/payroll'),
                  'icon': Icons.trending_up_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_payroll.png',
                  'bg': const Color(0xFFFFFBEB), // Amber 50
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'payroll'))),
                },
                {
                  'title': 'Lịch xe',
                  'visible': _hrm('/fleet'),
                  'icon': Icons.directions_car_filled_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_hrm_fleet.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF1D4ED8),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FleetScheduleScreen())),
                },
                {
                  'title': 'Cấu hình HRM',
                  'visible': _hrm('/settings'),
                  'icon': Icons.tune_rounded,
                  'imageAsset': 'assets/images/icons/nav_settings.png',
                  'bg': const Color(0xFFF1F5F9), // Slate 50
                  'iconColor': const Color(0xFF475569),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'config'))),
                },
              ],
            ),

            // 4. VĂN THƯ
            _buildMenuSection(
              title: 'VĂN THƯ',
              items: [
                {
                  'title': 'Tổng quan',
                  'visible': true,
                  'icon': Icons.space_dashboard_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_correspondence_overview.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CorrespondenceOverviewScreen())),
                },
                {
                  'title': 'Cần tôi xử lý',
                  'visible': true,
                  'icon': Icons.assignment_ind_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_correspondence_mine.png',
                  'bg': const Color(0xFFEFF6FF), // Sky 50
                  'iconColor': const Color(0xFF0284C7),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CorrespondenceMineScreen())),
                },
                {
                  'title': 'Theo dõi đôn đốc',
                  'visible': true,
                  'icon': Icons.notifications_active_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_correspondence_tracking.png',
                  'bg': const Color(0xFFFFFBEB), // Amber 50
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CorrespondenceTrackingScreen())),
                },
                {
                  'title': 'Công văn đến',
                  'visible': true,
                  'icon': Icons.move_to_inbox_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_correspondence_incoming.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CorrespondenceIncomingScreen())),
                },
                {
                  'title': 'Công văn đi',
                  'visible': true,
                  'icon': Icons.send_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_correspondence_outgoing.png',
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CorrespondenceOutgoingScreen())),
                },
                {
                  'title': 'Kho lưu trữ',
                  'visible': true,
                  'icon': Icons.archive_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_correspondence_archive.png',
                  'bg': const Color(0xFFFAF5FF), // Purple 50
                  'iconColor': const Color(0xFF9333EA),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CorrespondenceArchiveScreen())),
                },
                {
                  'title': 'Báo cáo',
                  'visible': true,
                  'icon': Icons.bar_chart_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_correspondence_reports.png',
                  'bg': const Color(0xFFF0FDF4), // Green 50
                  'iconColor': const Color(0xFF16A34A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CorrespondenceReportScreen())),
                },
              ],
            ),

            // 5. BẢO TRÌ (BẢO TRÌ PHÒNG NGỪA)
            _buildMenuSection(
              title: 'BẢO TRÌ',
              items: [
                {
                  'title': 'Tổng quan',
                  'visible': true,
                  'icon': Icons.space_dashboard_rounded,
                  'imageAsset': 'assets/images/icons/module_maintenance.png',
                  'bg': const Color(0xFFEFF6FF), // Blue 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen(view: 'dashboard'))),
                },
                {
                  'title': 'Ma trận bảo trì',
                  'visible': true,
                  'icon': Icons.grid_view_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_maintenance_matrix.png',
                  'bg': const Color(0xFFECFDF5), // Emerald 50
                  'iconColor': const Color(0xFF059669),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen(view: 'matrix'))),
                },
                {
                  'title': 'Lịch bảo trì',
                  'visible': true,
                  'icon': Icons.calendar_month_outlined,
                  'imageAsset': 'assets/images/icons/sidebar_maintenance_schedules.png',
                  'bg': const Color(0xFFFFFBEB), // Amber 50
                  'iconColor': const Color(0xFFD97706),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen(view: 'schedules'))),
                },
                {
                  'title': 'Phiếu phát sinh',
                  'visible': true,
                  'icon': Icons.warning_amber_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_maintenance_occurrences.png',
                  'bg': const Color(0xFFFFF1F2), // Rose 50
                  'iconColor': const Color(0xFFE11D48),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen(view: 'occurrences'))),
                },
                {
                  'title': 'Lịch sử',
                  'visible': true,
                  'icon': Icons.history_rounded,
                  'imageAsset': 'assets/images/icons/sidebar_maintenance_history.png',
                  'bg': const Color(0xFFFAF5FF), // Purple 50
                  'iconColor': const Color(0xFF9333EA),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen(view: 'history'))),
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
                  'imageAsset': 'assets/images/icons/module_assistant.png',
                  'bg': const Color(0xFFEFF6FF), // Sky 50
                  'iconColor': const Color(0xFF2563EB),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantChatScreen())),
                },
                {
                  'title': 'Ứng dụng phân hệ',
                  'icon': Icons.inventory_2_outlined,
                  'imageAsset': 'assets/images/icons/nav_applications.png',
                  'bg': const Color(0xFFF0FDF4), // Green 50
                  'iconColor': const Color(0xFF16A34A),
                  'onTap': () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EnterpriseApplicationsScreen(),
                    ),
                  ),
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
                  'imageAsset': 'assets/images/icons/nav_users.png',
                  'bg': const Color(0xFFF1F5F9), // Slate 50
                  'iconColor': const Color(0xFF0F172A),
                  'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                },
                {
                  'title': 'Vai trò & phân quyền',
                  'visible': auth.canViewRoles,
                  'icon': Icons.verified_user_outlined,
                  'imageAsset': 'assets/images/icons/nav_authorization.png',
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
          if (_showOrg) ...[
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
          if (_showAdmin) ...[
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

    final isListView = _selectedCategory == 'LIST';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: isListView
          ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
          : const EdgeInsets.fromLTRB(16, 18, 16, 18),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              if (isListView)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${filteredItems.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!isListView)
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
                final iconColor = item['iconColor'] as Color;
                final onTap = item['onTap'] as VoidCallback;

                return InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: item['imageAsset'] != null
                              ? Image.asset(
                                  item['imageAsset'] as String,
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Icon(icon, color: iconColor, size: 26),
                                  ),
                                )
                              : Center(
                                  child: Icon(icon, color: iconColor, size: 26),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredItems.length,
              separatorBuilder: (_, index) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                final label = item['title'] as String;
                final icon = item['icon'] as IconData;
                final iconColor = item['iconColor'] as Color;
                final onTap = item['onTap'] as VoidCallback;

                return InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: item['imageAsset'] != null
                                ? Image.asset(
                                    item['imageAsset'] as String,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Icon(icon, color: iconColor, size: 20),
                                    ),
                                  )
                                : Center(
                                    child: Icon(icon, color: iconColor, size: 20),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Color(0xFF94A3B8),
                        ),
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
}
