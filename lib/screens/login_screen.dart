import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import './home_screen.dart';

class LoginScreen extends StatefulWidget {
  final String initialPortal; // 'tenant' or 'platform'

  const LoginScreen({
    super.key,
    this.initialPortal = 'tenant',
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late String _portal; // 'tenant' or 'platform'
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _portal = widget.initialPortal;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSwitchPortal(String newPortal) {
    if (_portal == newPortal) return;
    setState(() {
      _portal = newPortal;
      _emailController.clear();
      _passwordController.clear();
    });
    context.read<AuthProvider>().clearError();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        portal: _portal,
      );
      if (success && mounted) {
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
    final isPlatform = _portal == 'platform';

    return Scaffold(
      backgroundColor: AppColors.slate900,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 960 : 440,
                minHeight: isDesktop ? 580 : 0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isPlatform
                      ? const Color(0xFF6366F1).withOpacity(0.3)
                      : AppColors.emerald.withOpacity(0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPlatform
                        ? const Color(0xFF4F46E5).withOpacity(0.18)
                        : AppColors.emerald.withOpacity(0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildHeroPanel(isDesktop: true)),
                          Expanded(child: _buildFormPanel(authProvider)),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeroPanel(isDesktop: false),
                          _buildFormPanel(authProvider),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPanel({required bool isDesktop}) {
    final isPlatform = _portal == 'platform';

    return Container(
      padding: EdgeInsets.all(isDesktop ? 44 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPlatform
              ? const [
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                  Color(0xFF312E81),
                ]
              : const [
                  Color(0xFF0F172A),
                  Color(0xFF064E3B),
                  Color(0xFF047857),
                ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Portal Switcher Pill
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPortalPillOption(
                  id: 'tenant',
                  label: 'Doanh nghiệp',
                  icon: Icons.business_outlined,
                  isSelected: !isPlatform,
                  activeColor: AppColors.emerald,
                ),
                _buildPortalPillOption(
                  id: 'platform',
                  label: 'Quản trị hệ thống',
                  icon: Icons.admin_panel_settings_outlined,
                  isSelected: isPlatform,
                  activeColor: const Color(0xFF6366F1),
                ),
              ],
            ),
          ),

          SizedBox(height: isDesktop ? 60 : 24),

          // Main Hero Title & Description
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPlatform ? const Color(0xFF818CF8) : AppColors.emeraldAccent)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isPlatform ? const Color(0xFF818CF8) : AppColors.emeraldAccent)
                        .withOpacity(0.3),
                  ),
                ),
                child: Text(
                  isPlatform ? 'QUẢN TRỊ HỆ THỐNG' : 'DOANH NGHIỆP',
                  style: TextStyle(
                    color: isPlatform ? const Color(0xFFA5B4FC) : AppColors.emeraldAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isPlatform ? 'Quản trị hệ thống.' : 'Không gian làm việc.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 30 : 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isPlatform
                    ? 'Dành riêng cho người vận hành hệ thống: tạo doanh nghiệp, cấp phân hệ. Không truy cập dữ liệu nội bộ của doanh nghiệp.'
                    : 'Quy trình, bảo trì thiết bị và kho vật tư của doanh nghiệp bạn, gói gọn trong cùng một ứng dụng.',
                style: TextStyle(
                  color: AppColors.slate300.withOpacity(0.85),
                  fontSize: isDesktop ? 13.5 : 12.5,
                  height: 1.5,
                ),
              ),
            ],
          ),

          if (isDesktop) const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPortalPillOption({
    required String id,
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: () => _handleSwitchPortal(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.slate400,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.slate300,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormPanel(AuthProvider authProvider) {
    final isPlatform = _portal == 'platform';
    final activeAccent = isPlatform ? const Color(0xFF6366F1) : AppColors.emerald;

    return Container(
      padding: const EdgeInsets.all(28),
      color: const Color(0xFF0F172A).withOpacity(0.6),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header Info
            Text(
              isPlatform ? 'ĐĂNG NHẬP' : 'ĐĂNG NHẬP DOANH NGHIỆP',
              style: TextStyle(
                color: activeAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPlatform ? 'Cổng quản trị hệ thống' : 'Không gian làm việc',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPlatform
                  ? 'Chỉ dành cho người vận hành hệ thống.'
                  : 'Nhập email công ty để hệ thống tự động nhận diện doanh nghiệp.',
              style: const TextStyle(
                color: AppColors.slate400,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Email Field
            const Text(
              'Email',
              style: TextStyle(
                color: AppColors.slate300,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: isPlatform ? 'superadmin@platform.local' : 'admin@svn.com',
                hintStyle: TextStyle(color: AppColors.slate500.withOpacity(0.7), fontSize: 13),
                fillColor: AppColors.slate900.withOpacity(0.7),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.slate400, size: 18),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.slate700.withOpacity(0.8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: activeAccent, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập email.';
                }
                if (!val.contains('@')) {
                  return 'Email không đúng định dạng.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Field
            const Text(
              'Mật khẩu',
              style: TextStyle(
                color: AppColors.slate300,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '••••••••••••',
                hintStyle: TextStyle(color: AppColors.slate500.withOpacity(0.7), fontSize: 13),
                fillColor: AppColors.slate900.withOpacity(0.7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.slate400, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.slate400,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.slate700.withOpacity(0.8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: activeAccent, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
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

            // Error message display
            if (authProvider.errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authProvider.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: authProvider.isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: activeAccent.withOpacity(0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: authProvider.isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Đang xác minh...',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
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

            const SizedBox(height: 20),

            // Footer note
            Text(
              isPlatform
                  ? 'Chỉ dành cho người quản trị hệ thống. Nhân sự doanh nghiệp đăng nhập ở cổng doanh nghiệp.'
                  : 'Tài khoản do doanh nghiệp của bạn cấp. Nếu chưa có, liên hệ người quản trị nội bộ.',
              style: TextStyle(
                color: AppColors.slate500,
                fontSize: 11.5,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
