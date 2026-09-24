import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import './home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleBack() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.clearTenant();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(
        _emailController.text,
        _passwordController.text,
      );
      if (success && mounted) {
        // Clear backstack and go home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final authProvider = context.watch<AuthProvider>();
    final tenantDisplay = (authProvider.tenantSlug ?? '').toUpperCase();

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
                        Expanded(child: _buildLeftHeroPanel(tenantDisplay)),
                        Expanded(child: _buildRightLoginPanel(authProvider, tenantDisplay)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLeftHeroPanel(tenantDisplay, isCompact: true),
                        _buildRightLoginPanel(authProvider, tenantDisplay),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftHeroPanel(String tenantSlug, {bool isCompact = false}) {
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          GestureDetector(
            onTap: _handleBack,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Text(
                  'Chọn cổng khác',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          if (!isCompact) const SizedBox(height: 80),

          // Main branding
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DOANH NGHIỆP',
                style: TextStyle(
                  color: AppColors.emeraldAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Không gian làm việc.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Quy trình, bảo trì và kho vật tư của doanh nghiệp bạn, trong cùng một nơi.',
                style: TextStyle(
                  color: AppColors.slate300.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
          
          if (!isCompact) const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildRightLoginPanel(AuthProvider provider, String tenantSlug) {
    return Container(
      padding: const EdgeInsets.all(40),
      color: AppColors.slate800.withOpacity(0.3),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ĐĂNG NHẬP DOANH NGHIỆP - $tenantSlug',
              style: const TextStyle(
                color: AppColors.slate400,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tenant Portal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Dùng tài khoản quản trị viên của doanh nghiệp.',
              style: TextStyle(
                color: AppColors.slate400,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            
            // Email Input
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
                hintText: 'name@company.com',
                hintStyle: const TextStyle(color: AppColors.slate500, fontSize: 13),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                fillColor: AppColors.slate900.withOpacity(0.5),
                filled: true,
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.slate400),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.slate700.withOpacity(0.7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.emerald),
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
                  return 'Vui lòng nhập Email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            // Password Input
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                labelStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
                hintText: '••••••••••••',
                hintStyle: const TextStyle(color: AppColors.slate500, fontSize: 13),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                fillColor: AppColors.slate900.withOpacity(0.5),
                filled: true,
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.slate400),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.slate700.withOpacity(0.7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.emerald),
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
                if (val == null || val.isEmpty) {
                  return 'Vui lòng nhập mật khẩu.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                provider.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: provider.isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.emerald.withOpacity(0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            Text(
              'Tài khoản do doanh nghiệp của bạn cấp. Nếu chưa có, liên hệ người quản trị nội bộ.',
              style: TextStyle(
                color: AppColors.slate500,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
