import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../shared/widgets/language_selector_tile.dart';
import '../../../providers/auth_provider.dart';
import '../../account_screen.dart';
import '../../login_screen.dart';

class HomeMobileProfileView extends StatelessWidget {
  final String userName;
  final String userInitials;
  final String tenantDisplay;

  const HomeMobileProfileView({
    super.key,
    required this.userName,
    required this.userInitials,
    required this.tenantDisplay,
  });

  @override
  Widget build(BuildContext context) {
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
                        child: Text(
                          'home.profile.tenant_admin'.tr(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emerald700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // My Account & Password Change Tile (Matching Web /account)
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.key_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'home.profile.my_account'.tr(),
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'home.profile.my_account_desc'.tr(),
                          style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

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
                Text('home.profile.sec_company'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate400)),
                const SizedBox(height: 12),
                _buildProfileItem(Icons.domain, 'home.profile.tenant_code'.tr(), tenantDisplay),
                const Divider(height: 1, color: AppColors.slate100),
                _buildProfileItem(Icons.card_membership, 'home.profile.plan'.tr(), 'Enterprise Unlimited'),
                const Divider(height: 1, color: AppColors.slate100),
                _buildProfileItem(Icons.security, 'home.profile.security_policy'.tr(), 'home.profile.auth_standard'.tr()),
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
                Text('home.profile.sec_app'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate400)),
                const SizedBox(height: 12),
                _buildProfileItem(Icons.info_outline, 'home.profile.version'.tr(), 'Savina Enterprise Mobile 2.0.0'),
                const Divider(height: 1, color: AppColors.slate100),
                _buildProfileItem(Icons.support_agent, 'home.profile.tech_support'.tr(), 'support@savina.vn'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Language selector
          const LanguageSelectorTile(),
          const SizedBox(height: 28),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout, size: 18),
              label: Text('home.profile.logout'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: AppColors.slate400),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.slate700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
          ),
        ],
      ),
    );
  }
}
