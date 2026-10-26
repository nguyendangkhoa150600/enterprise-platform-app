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

class HomeMobileModulesView extends StatefulWidget {
  final VoidCallback onSelectOrgChart;
  final Function(String key) onOpenModule;

  const HomeMobileModulesView({
    super.key,
    required this.onSelectOrgChart,
    required this.onOpenModule,
  });

  @override
  State<HomeMobileModulesView> createState() => _HomeMobileModulesViewState();
}

class _HomeMobileModulesViewState extends State<HomeMobileModulesView> {
  String _moduleSearchQuery = '';
  final TextEditingController _moduleSearchController = TextEditingController();

  @override
  void dispose() {
    _moduleSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

          // 1. WORKPLACE
          _buildMenuSection(
            title: 'WORKPLACE',
            items: [
              {
                'title': 'Dự án',
                'icon': Icons.work_outline_rounded,
                'bg': const Color(0xFFFFFBEB), // Amber 50
                'iconColor': const Color(0xFFF59E0B),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 0))),
              },
              {
                'title': 'Khách hàng & Hợp đồng',
                'icon': Icons.handshake_outlined,
                'bg': const Color(0xFFEFF6FF), // Blue 50
                'iconColor': const Color(0xFF2563EB),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 1))),
              },
              {
                'title': 'Việc ngoài dự án',
                'icon': Icons.task_alt_outlined,
                'bg': const Color(0xFFECFDF5), // Emerald 50
                'iconColor': const Color(0xFF10B981),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceScreen(initialTab: 2))),
              },
            ],
          ),

          // 2. QUY TRÌNH (PROCEDURE ENGINE)
          _buildMenuSection(
            title: 'QUY TRÌNH',
            items: [
              {
                'title': 'Tổng quan',
                'icon': Icons.space_dashboard_rounded,
                'bg': const Color(0xFFEFF6FF), // Blue 50
                'iconColor': const Color(0xFF2563EB),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 0))),
              },
              {
                'title': 'Hồ sơ xử lý',
                'icon': Icons.assignment_outlined,
                'bg': const Color(0xFFECFDF5), // Emerald 50
                'iconColor': const Color(0xFF059669),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 1))),
              },
            ],
          ),

          // 2. HRM
          _buildMenuSection(
            title: 'QUẢN TRỊ NHÂN SỰ (HRM)',
            items: [
              // 1. TỔNG QUAN
              {
                'title': 'Bàn làm việc',
                'icon': Icons.space_dashboard_rounded,
                'bg': const Color(0xFFEEF2FF), // Indigo 50
                'iconColor': const Color(0xFF4F46E5),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'dashboard'))),
              },
              {
                'title': 'Giám sát chấm công',
                'icon': Icons.insights_rounded,
                'bg': const Color(0xFFFEF3C7), // Amber 100
                'iconColor': const Color(0xFFD97706),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceMonitorScreen())),
              },
              {
                'title': 'Đơn từ cần xử lý',
                'icon': Icons.assignment_turned_in_outlined,
                'bg': const Color(0xFFE0F2FE), // Sky 50
                'iconColor': const Color(0xFF0284C7),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'requests'))),
              },

              // 2. CÁ NHÂN
              {
                'title': 'Bảng công của tôi',
                'icon': Icons.calendar_today_outlined,
                'bg': const Color(0xFFF0FDF4), // Emerald 50
                'iconColor': const Color(0xFF059669),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(initialTabIndex: 1))),
              },
              {
                'title': 'Chấm công GPS',
                'icon': Icons.fingerprint_rounded,
                'bg': const Color(0xFFECFDF5), // Emerald 50
                'iconColor': const Color(0xFF059669),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(initialTabIndex: 0))),
              },
              {
                'title': 'Đơn từ của tôi',
                'icon': Icons.assignment_outlined,
                'bg': const Color(0xFFEFF6FF), // Sky 50
                'iconColor': const Color(0xFF2563EB),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRequestsScreen())),
              },
              {
                'title': 'Hồ sơ & Thu nhập',
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

              // 3. QUẢN LÝ
              {
                'title': 'Nhân sự',
                'icon': Icons.people_alt_outlined,
                'bg': const Color(0xFFECFDF5), // Emerald 50
                'iconColor': const Color(0xFF059669),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'employees'))),
              },
              {
                'title': 'Bảng công tổng hợp',
                'icon': Icons.calculate_outlined,
                'bg': const Color(0xFFF0FDF4), // Green 50
                'iconColor': const Color(0xFF16A34A),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'timesheet'))),
              },
              {
                'title': 'Quỹ phép năm',
                'icon': Icons.beach_access_rounded,
                'bg': const Color(0xFFEFF6FF), // Blue 50
                'iconColor': const Color(0xFF2563EB),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveBalancesScreen())),
              },
              {
                'title': 'Lương và chi trả',
                'icon': Icons.payments_outlined,
                'bg': const Color(0xFFFFFBEB), // Amber 50
                'iconColor': const Color(0xFFD97706),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'payroll'))),
              },
              {
                'title': 'Lịch xe',
                'icon': Icons.directions_car_filled_outlined,
                'bg': const Color(0xFFEFF6FF), // Blue 50
                'iconColor': const Color(0xFF1D4ED8),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FleetScheduleScreen())),
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
                'onTap': widget.onSelectOrgChart,
              },
            ],
          ),
          // 7. TIỆN ÍCH & TÍNH NĂNG KHÁC (Tạm thời chuyển từ HRM)
          _buildMenuSection(
            title: 'TIỆN ÍCH & TÍNH NĂNG KHÁC',
            items: [
              {
                'title': 'Lịch & Thông báo',
                'icon': Icons.event_note_outlined,
                'bg': const Color(0xFFEFF6FF), // Sky 50
                'iconColor': const Color(0xFF0284C7),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'schedule'))),
              },
              {
                'title': 'Người phụ thuộc',
                'icon': Icons.family_restroom_outlined,
                'bg': const Color(0xFFFFFBEB), // Amber 50
                'iconColor': const Color(0xFFD97706),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'dependents'))),
              },
              {
                'title': 'Quản lý Ca làm',
                'icon': Icons.schedule_rounded,
                'bg': const Color(0xFFFFFBEB), // Amber 50
                'iconColor': const Color(0xFFD97706),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'shifts'))),
              },
              {
                'title': 'Xử lý Đơn từ',
                'icon': Icons.fact_check_outlined,
                'bg': const Color(0xFFF5F3FF), // Purple 50
                'iconColor': const Color(0xFF7C3AED),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'approvals'))),
              },
              {
                'title': 'Tiền lương & Chi trả',
                'icon': Icons.account_balance_wallet_outlined,
                'bg': const Color(0xFFEFF6FF), // Blue 50
                'iconColor': const Color(0xFF2563EB),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'payroll'))),
              },
              {
                'title': 'Ứng & Thu hồi lương',
                'icon': Icons.price_change_outlined,
                'bg': const Color(0xFFFFF7ED), // Orange 50
                'iconColor': const Color(0xFFEA580C),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'advances'))),
              },
              {
                'title': 'Chính sách & Cấu hình',
                'icon': Icons.tune_rounded,
                'bg': const Color(0xFFF8FAFC), // Slate 50
                'iconColor': const Color(0xFF475569),
                'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmHubScreen(initialView: 'config'))),
              },
              {
                'title': 'Hệ thống & Tích hợp',
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
}
