import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import './home_screen.dart';
import '../core/i18n/app_i18n.dart';

class LoginScreen extends StatefulWidget {
  final String initialPortal; // retained for backwards compatibility

  const LoginScreen({
    super.key,
    this.initialPortal = 'tenant',
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('saved_remember_me') ?? true;
      final savedEmail = prefs.getString('saved_login_email') ?? '';
      final savedPassword = prefs.getString('saved_login_password') ?? '';

      if (mounted) {
        setState(() {
          _rememberMe = rememberMe;
          if (_rememberMe) {
            if (savedEmail.isNotEmpty) {
              _emailController.text = savedEmail;
            }
            if (savedPassword.isNotEmpty) {
              _passwordController.text = savedPassword;
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (success) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('saved_remember_me', _rememberMe);
          if (_rememberMe) {
            await prefs.setString('saved_login_email', _emailController.text.trim());
            await prefs.setString('saved_login_password', _passwordController.text);
          } else {
            await prefs.remove('saved_login_email');
            await prefs.remove('saved_login_password');
            await prefs.remove('saved_login_portal');
          }
        } catch (_) {}

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120), // Deep rich slate navy
      body: SafeArea(
        child: isDesktop
            ? _buildDesktopLayout(authProvider)
            : _buildMobileLayout(authProvider),
      ),
    );
  }

  Widget _buildMobileLayout(AuthProvider authProvider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top bar: Language Toggle right-aligned
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLanguageToggle(),
            ],
          ),

          const SizedBox(height: 20),

          // 2. Brand Identity & Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    'assets/images/svn_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'SVN ERP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'SVN Digital Transformation Solution',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // 3. Login Form Card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.emerald.withOpacity(0.28),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _buildFormPanel(authProvider),
            ),
          ),

          const SizedBox(height: 26),

          // 4. Balanced Security Footer
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: AppColors.slate500),
                  const SizedBox(width: 6),
                  Text(
                    'Bảo mật kết nối SSL/TLS 256-bit',
                    style: TextStyle(color: AppColors.slate500, fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '© 2026 SVN Technology · Phiên bản 2.4.0',
                style: TextStyle(color: AppColors.slate600, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(AuthProvider authProvider) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerRight, child: _buildLanguageToggle()),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 960,
                  minHeight: 560,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.emerald.withOpacity(0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emerald.withOpacity(0.12),
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildHeroPanel()),
                      Expanded(child: _buildFormPanel(authProvider)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return ListenableBuilder(
      listenable: AppI18n.instance,
      builder: (context, _) {
        final isVi = AppI18n.instance.isVietnamese;
        Widget option(String code, bool selected, Locale locale) {
          return GestureDetector(
            onTap: () => AppI18n.instance.setLocale(locale),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.emerald : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                code,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.slate300,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              option('VI', isVi, const Locale('vi')),
              option('EN', !isVi, const Locale('en')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroPanel() {
    return Container(
      padding: const EdgeInsets.all(44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
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
          // Brand Logo Badge
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/images/svn_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SVN ERP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    'DIGITAL TRANSFORMATION',
                    style: TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Main Hero Title & Description
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emeraldAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.emeraldAccent.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'login.badge.tenant'.tr(),
                  style: const TextStyle(
                    color: AppColors.emeraldAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'login.hero.tenant_title'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'login.hero.tenant_desc'.tr(),
                style: TextStyle(
                  color: AppColors.slate300.withOpacity(0.85),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Security & Compliance tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureTag('Multi-Tenant'),
              _buildFeatureTag('ISO 27001'),
              _buildFeatureTag('Zero-Trust'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFormPanel(AuthProvider authProvider) {
    const activeAccent = AppColors.emerald;

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
            const Text(
              'ĐĂNG NHẬP',
              style: TextStyle(
                color: activeAccent,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Không gian làm việc',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'login.form.tenant_hint'.tr(),
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
                hintText: 'admin@svn.com',
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
                  borderSide: const BorderSide(color: activeAccent, width: 1.5),
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
                  return 'login.error.email_required'.tr();
                }
                if (!val.contains('@')) {
                  return 'login.error.email_invalid'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Field
            Text(
              'login.form.password'.tr(),
              style: const TextStyle(
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
                  borderSide: const BorderSide(color: activeAccent, width: 1.5),
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
                  return 'login.error.password_required'.tr();
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleLogin(),
            ),

            // Remember me checkbox
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                setState(() {
                  _rememberMe = !_rememberMe;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (val) {
                          setState(() {
                            _rememberMe = val ?? false;
                          });
                        },
                        activeColor: activeAccent,
                        checkColor: Colors.white,
                        side: BorderSide(
                          color: AppColors.slate500.withOpacity(0.8),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'login.form.remember_me'.tr(),
                      style: const TextStyle(
                        color: AppColors.slate300,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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

            const SizedBox(height: 22),

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
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'login.form.verifying'.tr(),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : Text(
                        'login.form.submit'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Footer note
            Center(
              child: Text(
                'login.footer.tenant'.tr(),
                style: const TextStyle(
                  color: AppColors.slate500,
                  fontSize: 11.5,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
