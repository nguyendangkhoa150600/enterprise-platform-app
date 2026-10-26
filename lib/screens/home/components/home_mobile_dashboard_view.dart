import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/platform_models.dart';
import '../../../providers/notification_provider.dart';
import '../../../theme/colors.dart';
import '../../assistant_chat_screen.dart';
import '../../notification_center_screen.dart';
import '../../attendance_screen.dart';
import '../../my_requests_screen.dart';
import '../../user_management_screen.dart';
import '../../role_permission_screen.dart';
import 'org_tree_components.dart';

class HomeMobileDashboardView extends StatelessWidget {
  final String userName;
  final String userInitials;
  final String tenantDisplay;
  final List<TenantUser> users;
  final List<ModuleCatalogItem> modules;
  final OrganizationSnapshot? orgSnapshot;
  final bool isLoadingData;
  final ScrollController attentionScrollController;
  final ScrollController homeOrgScrollController;
  final Function(String key) onOpenModule;
  final Function(int index) onNavigateTab;

  const HomeMobileDashboardView({
    super.key,
    required this.userName,
    required this.userInitials,
    required this.tenantDisplay,
    required this.users,
    required this.modules,
    required this.orgSnapshot,
    required this.isLoadingData,
    required this.attentionScrollController,
    required this.homeOrgScrollController,
    required this.onOpenModule,
    required this.onNavigateTab,
  });

  int get _activeUsersCount => users.where((u) => u.isActive).length;
  int get _activeModulesCount => modules.where((m) => m.isActive).length;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Breadcrumb & Main Page Title
          _buildMobilePageHeader(context, tenantDisplay),
          const SizedBox(height: 16),

          // 2. Welcome Card with Action Buttons
          _buildMobileWelcomeCard(context, userName),
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
  Widget _buildMobilePageHeader(BuildContext context, String tenantDisplay) {
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
              icon: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
              ),
              tooltip: 'Trợ lý Savina AI',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssistantChatScreen()),
              ),
              visualDensity: VisualDensity.compact,
            ),
            Consumer<NotificationProvider>(
              builder: (context, noti, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, size: 21, color: Color(0xFF334155)),
                      tooltip: 'Trung tâm thông báo',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (noti.unreadCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${noti.unreadCount > 99 ? '99+' : noti.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tổng quan hệ thống',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // bg-blue-50
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_outlined, size: 14, color: Color(0xFF2563EB)),
                  SizedBox(width: 4),
                  Text(
                    'Enterprise Plan',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Theo dõi nhanh các chỉ số và ứng dụng chính của tenant.',
          style: TextStyle(fontSize: 12.5, color: AppColors.slate500),
        ),
      ],
    );
  }

  // 2. Welcome Card (Xin chào)
  Widget _buildMobileWelcomeCard(BuildContext context, String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
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
                  icon: Icons.auto_awesome,
                  label: 'Trợ lý Savina AI',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantChatScreen())),
                ),
                const SizedBox(width: 8),
                _buildWelcomeActionButton(
                  icon: Icons.fingerprint_rounded,
                  label: 'Chấm công GPS',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                ),
                const SizedBox(width: 8),
                _buildWelcomeActionButton(
                  icon: Icons.assignment_outlined,
                  label: 'Đơn từ của tôi',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRequestsScreen())),
                ),
                const SizedBox(width: 8),
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
                  onTap: () => onNavigateTab(2),
                ),
                const SizedBox(width: 8),
                _buildWelcomeActionButton(
                  icon: Icons.apps_outlined,
                  label: 'Quản lý ứng dụng',
                  onTap: () => onNavigateTab(1),
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
        backgroundColor: const Color(0xFF2563EB),
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
                              color: const Color(0xFFFEF3C7),
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

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 255),
            child: Scrollbar(
              controller: attentionScrollController,
              thumbVisibility: items.length > 2,
              child: ListView.separated(
                controller: attentionScrollController,
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
      onTap: () => onOpenModule(it['module']!),
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
        _buildModuleSummaryCard(
          title: 'Quy trình',
          icon: Icons.account_tree_outlined,
          onOpen: () => onOpenModule('procedure'),
          stats: [
            {'label': 'Đang chạy', 'value': '4'},
            {'label': 'Chờ xử lý', 'value': '4'},
            {'label': 'Đã công bố', 'value': '16'},
          ],
          customContent: _buildProcedureMiniChart(),
        ),
        const SizedBox(height: 12),
        _buildModuleSummaryCard(
          title: 'Bảo trì',
          icon: Icons.build_outlined,
          onOpen: () => onOpenModule('maintenance'),
          stats: [
            {'label': 'Lịch đang chạy', 'value': '4'},
            {'label': 'Sắp đến hạn', 'value': '2'},
            {'label': 'Sự cố mở', 'value': '0'},
          ],
          emptyNote: 'Chưa có sự cố mở',
        ),
        const SizedBox(height: 12),
        _buildModuleSummaryCard(
          title: 'Kho vật tư',
          icon: Icons.inventory_2_outlined,
          onOpen: () => onOpenModule('inventory'),
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
              onPressed: () => onNavigateTab(1),
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
                  onTap: () => onOpenModule(app['key'] as String),
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
    final snapshot = orgSnapshot;

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
                  onTap: () => onNavigateTab(2),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Xem chi tiết',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 14, color: Color(0xFF0284C7)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

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
                controller: homeOrgScrollController,
                thumbVisibility: snapshot.nodes.length > 2,
                child: SingleChildScrollView(
                  controller: homeOrgScrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: buildOrgTreeList(snapshot),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
