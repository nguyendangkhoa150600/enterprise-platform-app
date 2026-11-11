import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import 'package:provider/provider.dart';
import '../../../models/platform_models.dart';
import '../../../models/hrm_models.dart';
import '../../../services/hrm_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/permissions/hrm_permissions.dart';
import '../../../models/procedure_models.dart';
import '../../../providers/notification_provider.dart';
import '../../../theme/colors.dart';
import '../../assistant_chat_screen.dart';
import '../../notification_center_screen.dart';
import '../../attendance_screen.dart';
import '../../hrm_hub_screen.dart';
import '../../my_requests_screen.dart';
import '../../user_management_screen.dart';
import '../../role_permission_screen.dart';
import '../../../features/hrm/requests/presentation/widgets/hrm_request_detail_bottom_sheet.dart';
import '../../../services/module_business_service.dart';
import '../../procedure/components/procedure_modals.dart';
import 'home_module_stats.dart';

class HomeMobileDashboardView extends StatelessWidget {
  final String userName;
  final String userInitials;
  final String tenantDisplay;
  final List<TenantUser> users;
  final List<ModuleCatalogItem> modules;
  final OrganizationSnapshot? orgSnapshot;
  final bool isLoadingData;
  final HomeModuleStats? moduleStats;
  final List<HrmRequestItem> pendingRequests;
  final ScrollController attentionScrollController;
  final ScrollController? requestsScrollController;
  final ScrollController homeOrgScrollController;
  final Function(String key) onOpenModule;
  final Function(int index) onNavigateTab;
  final VoidCallback? onRefreshRequests;

  const HomeMobileDashboardView({
    super.key,
    required this.userName,
    required this.userInitials,
    required this.tenantDisplay,
    required this.users,
    required this.modules,
    required this.orgSnapshot,
    required this.isLoadingData,
    this.moduleStats,
    this.pendingRequests = const [],
    required this.attentionScrollController,
    this.requestsScrollController,
    required this.homeOrgScrollController,
    required this.onOpenModule,
    required this.onNavigateTab,
    this.onRefreshRequests,
  });

  bool _has(String key) => modules.any((m) => m.key == key && m.isActive);
  bool get _hasProcedure => _has('procedure-engine') || _has('procedure');
  bool get _hasMaintenance => _has('maintenance');
  bool get _hasHrm => _has('hrm') || _has('human-resource');

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
          if (_hasProcedure) ...[
            _buildMobileAttentionSection(context),
            const SizedBox(height: 20),
          ],

          // 5. Đơn từ cần xử lý (HRM Pending Requests)
          if (_hasHrm) ...[
            _buildMobilePendingRequestsSection(context),
            const SizedBox(height: 20),
          ],
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
            Builder(
              builder: (ctx) => InkWell(
                onTap: () => Scaffold.of(ctx).openDrawer(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.menu_rounded, size: 20, color: Color(0xFF1E293B)),
                ),
              ),
            ),
            Text(
              'home.mobile.tenant_portal'.tr(args: {'tenant': tenantDisplay.toLowerCase()}),
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
              tooltip: 'home.mobile.ai_assistant'.tr(),
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
                      tooltip: 'home.mobile.notification_center'.tr(),
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
            Text(
              'home.mobile.system_overview'.tr(),
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
        Text(
          'home.mobile.system_overview_desc'.tr(),
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
          Text(
            'home.mobile.hello'.tr(),
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
          Text(
            'home.mobile.welcome_wish'.tr(),
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
                  label: 'home.mobile.ai_assistant'.tr(),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantChatScreen())),
                ),
                const SizedBox(width: 8),
                if (_has('hrm') && context.watch<HrmCapabilities>().pageAllowed('/my-work')) ...[
                  _buildWelcomeActionButton(
                    icon: Icons.fingerprint_rounded,
                    label: 'home.mobile.gps_attendance'.tr(),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_has('hrm') && HrmCapabilities.instance.pageAllowed('/requests')) ...[
                  _buildWelcomeActionButton(
                    icon: Icons.assignment_outlined,
                    label: 'home.mobile.my_requests'.tr(),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRequestsScreen())),
                  ),
                  const SizedBox(width: 8),
                ],
                if (context.watch<AuthProvider>().canViewUsers)
                  _buildWelcomeActionButton(
                    icon: Icons.manage_accounts_outlined,
                    label: 'home.mobile.user_management'.tr(),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                  ),
                const SizedBox(width: 8),
                _buildWelcomeActionButton(
                  icon: Icons.verified_user_outlined,
                  label: 'home.mobile.roles_permissions'.tr(),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePermissionScreen())),
                ),
                const SizedBox(width: 8),
                _buildWelcomeActionButton(
                  icon: Icons.account_tree_outlined,
                  label: 'home.mobile.org_setup'.tr(),
                  onTap: () => onNavigateTab(2),
                ),
                const SizedBox(width: 8),
                _buildWelcomeActionButton(
                  icon: Icons.apps_outlined,
                  label: 'home.mobile.app_management'.tr(),
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
    final loading = isLoadingData && users.isEmpty && modules.isEmpty;
    final userCount = loading ? '—' : '$_activeUsersCount';
    final moduleCount = loading ? '—' : '$_activeModulesCount';
    final st = moduleStats;
    final pendingCount = st == null || !_hasProcedure ? '—' : '${st.needAction.length}';
    final incidentCount = st == null || !_hasMaintenance ? '—' : '${st.openIncidents}';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'home.mobile.active_users'.tr(),
                value: userCount,
                note: 'home.mobile.active_accounts'.tr(),
                icon: Icons.people_outline,
                tone: 'blue',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                label: 'home.mobile.enabled_apps'.tr(),
                value: moduleCount,
                note: 'home.mobile.per_entitlement'.tr(),
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
                label: 'home.mobile.pending_records'.tr(),
                value: pendingCount,
                note: 'home.mobile.procedures_need_action'.tr(),
                icon: Icons.assignment_outlined,
                tone: 'amber',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                label: 'home.mobile.incidents_in_progress'.tr(),
                value: incidentCount,
                note: 'home.mobile.incidents_open'.tr(),
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
  Widget _buildMobileAttentionSection(BuildContext context) {
    final instances = (moduleStats?.needAction ?? const <ProcedureInstance>[]).take(20).toList();

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
                          Text(
                            'home.mobile.attention_points'.tr(),
                            style: const TextStyle(
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
                              '${instances.length}',
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
                      Text(
                        'home.mobile.attention_desc'.tr(),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 20),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          if (instances.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Center(
                child: Text(
                  moduleStats == null ? '—' : 'home.mobile.no_attention'.tr(),
                  style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 255),
              child: Scrollbar(
                controller: attentionScrollController,
                thumbVisibility: instances.length > 2,
                child: ListView.separated(
                  controller: attentionScrollController,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: instances.length,
                  separatorBuilder: (context, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final inst = instances[index];
                    return _buildAttentionItem(context, inst);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttentionItem(BuildContext context, ProcedureInstance inst) {
    return InkWell(
      onTap: () {
        showProcedureDetailSheet(
          context: context,
          initialItem: inst,
          service: ModuleBusinessService(),
          onDataChanged: () {
            onRefreshRequests?.call();
          },
        );
      },
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
                    inst.title,
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
                      _buildChipTag('home.mobile.procedure'.tr(), const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
                      _buildChipTag(inst.code, const Color(0xFFF1F5F9), AppColors.slate700),
                      if (inst.definitionName.isNotEmpty)
                        _buildChipTag(inst.definitionName, const Color(0xFFF8FAFC), AppColors.slate600),
                      if (inst.currentStep?.name != null && inst.currentStep!.name.isNotEmpty)
                        _buildChipTag('home.mobile.step_label'.tr(args: {'step': inst.currentStep!.name}), const Color(0xFFF8FAFC), AppColors.slate600),
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
              child: Text(
                'home.mobile.need_action'.tr(),
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
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

  // 5. Đơn từ cần xử lý (HRM Pending Requests - Pixel-perfect match with Web & Attention Section)
  Widget _buildMobilePendingRequestsSection(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF059669), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Đơn từ cần xử lý',
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
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${pendingRequests.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Duyệt, từ chối và trao đổi đơn nghỉ phép, tăng ca, công tác, giải trình công... trong module Nhân sự.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.slate500, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HrmHubScreen(initialTabIndex: 2)),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Xem tất cả',
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
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          if (pendingRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 28, color: const Color(0xFF10B981).withValues(alpha: 0.7)),
                    const SizedBox(height: 8),
                    const Text(
                      'Không có đơn từ nào cần xử lý',
                      style: TextStyle(fontSize: 12.5, color: AppColors.slate500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Scrollbar(
                controller: requestsScrollController,
                thumbVisibility: pendingRequests.length > 2,
                child: ListView.separated(
                  controller: requestsScrollController,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: pendingRequests.length,
                  separatorBuilder: (context, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final req = pendingRequests[index];
                    return _buildPendingRequestItem(context, req);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestItem(BuildContext context, HrmRequestItem req) {
    final typeName = req.typeLabel;
    Color typeBg = const Color(0xFFEFF6FF);
    Color typeFg = const Color(0xFF1D4ED8);
    switch (req.type) {
      case HrmRequestType.leave:
        typeBg = const Color(0xFFEFF6FF);
        typeFg = const Color(0xFF1D4ED8);
        break;
      case HrmRequestType.overtime:
        typeBg = const Color(0xFFFEF3C7);
        typeFg = const Color(0xFFB45309);
        break;
      case HrmRequestType.businessTrip:
        typeBg = const Color(0xFFF3E8FF);
        typeFg = const Color(0xFF7E22CE);
        break;
      case HrmRequestType.attendanceCorrection:
        typeBg = const Color(0xFFECFDF5);
        typeFg = const Color(0xFF047857);
        break;
      case HrmRequestType.advance:
        typeBg = const Color(0xFFFFF1F2);
        typeFg = const Color(0xFFBE123C);
        break;
      case HrmRequestType.shiftChange:
        typeBg = const Color(0xFFF0FDF4);
        typeFg = const Color(0xFF15803D);
        break;
    }

    final empName = req.employeeName.isNotEmpty ? req.employeeName : 'Nhân sự';
    final initials = _getInitials(empName);
    final dateStr = _formatDate(req.startDate ?? req.requestDate);
    final reasonText = req.reason.isNotEmpty ? req.reason : req.title;

    return InkWell(
      onTap: () => _openRequestDetailModal(context, req),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
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
                      Expanded(
                        child: Text(
                          empName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (req.department.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${req.department}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reasonText,
                    style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildChipTag(typeName, typeBg, typeFg),
                      if (dateStr.isNotEmpty)
                        _buildChipTag(dateStr, const Color(0xFFF8FAFC), AppColors.slate600),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: const Text(
                'Chờ duyệt',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRequestDetailModal(BuildContext context, HrmRequestItem req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => HrmRequestDetailBottomSheet(
        request: req,
        hrmService: HrmService(),
        onRefreshData: () {
          onRefreshRequests?.call();
        },
        formatDate: (dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}',
        formatTime: (dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
        formatCurrency: (val) {
          if (val == null) return '0 ₫';
          final s = val.toStringAsFixed(0);
          final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
          return '${s.replaceAllMapped(reg, (Match m) => '${m[1]}.')} ₫';
        },
        getEmployeeInitials: (name) => _getInitials(name),
      ),
    );
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'NV';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
