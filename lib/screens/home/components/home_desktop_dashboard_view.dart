import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/platform_models.dart';
import '../../../services/platform_service.dart';
import '../../../theme/colors.dart';

class HomeDesktopDashboardView extends StatelessWidget {
  final String userName;
  final List<TenantUser> users;
  final List<ModuleCatalogItem> modules;
  final Function(String key) onOpenModule;
  final Function(String tab) onSelectTab;

  const HomeDesktopDashboardView({
    super.key,
    required this.userName,
    required this.users,
    required this.modules,
    required this.onOpenModule,
    required this.onSelectTab,
  });

  int get _activeUsersCount => users.where((u) => u.isActive).length;
  int get _activeModulesCount => modules.where((m) => m.isActive).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'home.greeting'.tr(args: {'name': userName}),
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
                _buildStatusCard('home.stat.active_users'.tr(), '$_activeUsersCount', null, cardWidth),
                _buildStatusCard('home.stat.enabled_modules'.tr(), '$_activeModulesCount', null, cardWidth),
                _buildStatusCard('home.stat.current_plan'.tr(), 'Enterprise', null, cardWidth),
                _buildStatusCard('home.stat.subscription'.tr(), 'home.stat.active_state'.tr(), 'active', cardWidth),
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
                          Text(
                            'home.stat.active_state'.tr(),
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
    final activeModules = modules.where((m) => m.isActive).toList();

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
              Text(
                'home.my_apps'.tr(),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate800),
              ),
              TextButton(
                onPressed: () => onSelectTab('Ứng dụng'),
                child: Row(
                  children: [
                    Text('home.view_all'.tr(), style: TextStyle(fontSize: 13, color: AppColors.slate500)),
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
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final m = activeModules[index];
              return InkWell(
                onTap: () => onOpenModule(m.key),
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
          Text(
            'home.quick_actions_admin'.tr(),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate800),
          ),
          const SizedBox(height: 16),
          _buildQuickActionItem('home.quick.add_user'.tr(), () => onSelectTab('Người dùng')),
          const Divider(height: 1, color: AppColors.slate100),
          _buildQuickActionItem('home.quick.view_org_chart'.tr(), () => onSelectTab('Sơ đồ tổ chức')),
          const Divider(height: 1, color: AppColors.slate100),
          _buildQuickActionItem('home.quick.manage_app_permissions'.tr(), () => onSelectTab('Ứng dụng')),
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
          Text(
            'home.recent_activity'.tr(),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate800),
          ),
          const SizedBox(height: 16),
          _buildActivityItem('home.activity.invited_user'.tr(), 'home.activity.invited_user_time'.tr()),
          _buildActivityItem('home.activity.updated_inventory'.tr(), 'home.activity.updated_inventory_time'.tr()),
          _buildActivityItem('home.activity.completed_maintenance'.tr(), 'home.activity.completed_maintenance_time'.tr()),
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
}

class HomeDesktopApplicationsView extends StatelessWidget {
  final List<ModuleCatalogItem> modules;
  final PlatformService platformService;
  final Function(String key) onOpenModule;
  final VoidCallback onRefresh;

  const HomeDesktopApplicationsView({
    super.key,
    required this.modules,
    required this.platformService,
    required this.onOpenModule,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'home.catalog.title'.tr(),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        const SizedBox(height: 6),
        Text(
          'home.catalog.subtitle'.tr(),
          style: TextStyle(fontSize: 13, color: AppColors.slate500),
        ),
        const SizedBox(height: 24),

        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: modules.map((m) => _buildModuleCard(context, m)).toList(),
        ),
      ],
    );
  }

  Widget _buildModuleCard(BuildContext context, ModuleCatalogItem m) {
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
                  isActive ? 'home.module.status_active'.tr() : m.entitlementStatus == 'provisioning' ? 'home.module.status_provisioning'.tr() : 'home.module.status_inactive'.tr(),
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
                    onPressed: () => onOpenModule(m.key),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slate900,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('home.module.open'.tr(), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  )
                : OutlinedButton(
                    onPressed: () async {
                      final success = await platformService.requestModuleActivation(m.key);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('home.module.activation_sent'.tr(args: {'name': m.name}))),
                        );
                        onRefresh();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.slate700,
                      side: const BorderSide(color: AppColors.slate300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('home.module.request_activation'.tr(), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
    );
  }
}
