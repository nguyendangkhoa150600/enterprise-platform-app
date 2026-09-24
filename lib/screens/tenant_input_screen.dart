import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import './login_screen.dart';

class TenantInputScreen extends StatefulWidget {
  const TenantInputScreen({super.key});

  @override
  State<TenantInputScreen> createState() => _TenantInputScreenState();
}

class _TenantInputScreenState extends State<TenantInputScreen> {
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.setTenant(_urlController.text);
      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.slate900,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1000 : 450,
              minHeight: isDesktop ? 600 : 0,
            ),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.slate800.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.slate700.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildLeftHeroPanel()),
                        Expanded(child: _buildRightInputPanel(authProvider)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLeftHeroPanel(isCompact: true),
                        _buildRightInputPanel(authProvider),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftHeroPanel({bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 32 : 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Text(
              'Enterprise Platform',
              style: TextStyle(
                color: AppColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chọn đúng cổng\ncho đúng vai trò.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Platform Admin quản trị toàn bộ nền tảng. Tenant Admin và người dùng doanh nghiệp truy cập portal cùng các module đã được cấp entitlement.',
            style: TextStyle(
              color: AppColors.slate300.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (!isCompact) ...[
            const SizedBox(height: 48),
            Row(
              children: [
                _buildFlowIndicator('Identity'),
                _buildFlowSeparator(),
                _buildFlowIndicator('Authorization'),
                _buildFlowSeparator(),
                _buildFlowIndicator('Entitlement'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlowIndicator(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.slate900.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate700.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFlowSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.chevron_right,
        color: AppColors.slate500.withOpacity(0.5),
        size: 16,
      ),
    );
  }

  Widget _buildRightInputPanel(AuthProvider provider) {
    return Container(
      padding: const EdgeInsets.all(40),
      color: AppColors.slate800.withOpacity(0.3),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Tenant Portal',
              style: TextStyle(
                color: AppColors.slate400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đường dẫn doanh nghiệp',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nhập tên hoặc đường dẫn không gian làm việc của doanh nghiệp bạn.',
              style: TextStyle(
                color: AppColors.slate400,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'URL hoặc Tenant Slug',
                labelStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
                hintText: '/t/tenant-slug/login hoặc tenant-slug',
                hintStyle: const TextStyle(color: AppColors.slate500, fontSize: 13),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                fillColor: AppColors.slate900.withOpacity(0.5),
                filled: true,
                prefixIcon: const Icon(Icons.business, color: AppColors.slate400),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.slate700.withOpacity(0.7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.amber),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập đường dẫn hoặc slug doanh nghiệp.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleSubmit(),
            ),
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                provider.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.slate900,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tiếp tục',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
