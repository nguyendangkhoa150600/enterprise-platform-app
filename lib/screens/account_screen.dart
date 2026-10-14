import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmationCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _inlineError;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmationCtrl.dispose();
    super.dispose();
  }

  // Password rules validation matching React
  List<Map<String, dynamic>> _getRules() {
    final current = _currentPasswordCtrl.text;
    final next = _newPasswordCtrl.text;
    final conf = _confirmationCtrl.text;

    return [
      {
        'id': 'length',
        'label': 'Từ 6 ký tự trở lên',
        'required': true,
        'passed': next.length >= 6 && next.length <= 128,
      },
      {
        'id': 'different',
        'label': 'Khác mật khẩu hiện tại',
        'required': true,
        'passed': next.isNotEmpty && next != current,
      },
      {
        'id': 'match',
        'label': 'Xác nhận mật khẩu trùng khớp',
        'required': true,
        'passed': next.isNotEmpty && next == conf,
      },
      {
        'id': 'case',
        'label': 'Có cả chữ hoa và chữ thường',
        'required': false,
        'passed': RegExp(r'[a-z]').hasMatch(next) && RegExp(r'[A-Z]').hasMatch(next),
      },
      {
        'id': 'digit',
        'label': 'Có ít nhất một chữ số',
        'required': false,
        'passed': RegExp(r'\d').hasMatch(next),
      },
      {
        'id': 'symbol',
        'label': 'Có ít nhất một ký tự đặc biệt',
        'required': false,
        'passed': RegExp(r'[^A-Za-z0-9]').hasMatch(next),
      },
    ];
  }

  // Password strength calculation
  Map<String, dynamic> _getStrength() {
    final password = _newPasswordCtrl.text;
    if (password.isEmpty) {
      return {'label': '', 'bars': 0, 'color': Colors.transparent, 'textColor': Colors.transparent};
    }
    if (password.length < 8) {
      return {'label': 'Yếu', 'bars': 1, 'color': const Color(0xFFEF4444), 'textColor': const Color(0xFFDC2626)};
    }
    int classes = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) classes++;
    if (RegExp(r'[A-Z]').hasMatch(password)) classes++;
    if (RegExp(r'\d').hasMatch(password)) classes++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) classes++;

    if ((classes >= 4 && password.length >= 12) || (classes >= 3 && password.length >= 16)) {
      return {'label': 'Mạnh', 'bars': 3, 'color': const Color(0xFF10B981), 'textColor': const Color(0xFF059669)};
    }
    if (classes >= 2) {
      return {'label': 'Trung bình', 'bars': 2, 'color': const Color(0xFFF59E0B), 'textColor': const Color(0xFFD97706)};
    }
    return {'label': 'Yếu', 'bars': 1, 'color': const Color(0xFFEF4444), 'textColor': const Color(0xFFDC2626)};
  }

  bool _canSubmit() {
    if (_currentPasswordCtrl.text.isEmpty) return false;
    final rules = _getRules();
    return rules.every((r) => !r['required'] || r['passed'] == true);
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit()) return;

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final res = await auth.changePassword(
      currentPassword: _currentPasswordCtrl.text,
      newPassword: _newPasswordCtrl.text,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (res['success'] == true) {
        _currentPasswordCtrl.clear();
        _newPasswordCtrl.clear();
        _confirmationCtrl.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đổi mật khẩu thành công! Các phiên đăng nhập khác đã được đăng xuất để bảo mật.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _inlineError = res['message']?.toString() ?? 'Đổi mật khẩu thất bại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final displayName = auth.fullName ?? 'Người dùng';
    final email = auth.email ?? '';
    final tenantSlug = auth.tenantSlug ?? '';
    final roles = auth.roles.isNotEmpty ? auth.roles : [auth.kind ?? 'tenant-user'];

    final initials = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join('')
        .toUpperCase();

    final rules = _getRules();
    final strength = _getStrength();
    final canSubmit = _canSubmit();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tài khoản của tôi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Description
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xem thông tin tài khoản và tự đổi mật khẩu đăng nhập của bạn.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                ],
              ),
            ),

            // Card 1: Master Hồ sơ
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Header Banner
                  Container(
                    padding: const EdgeInsets.only(top: 24, bottom: 20, left: 16, right: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: const Color(0xFFEFF6FF), width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withOpacity(0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initials.isNotEmpty ? initials : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: roles.map((r) {
                            String label = r;
                            if (r == 'tenant-admin') label = 'Quản trị doanh nghiệp';
                            else if (r == 'tenant-user') label = 'Người dùng';
                            else if (r == 'platform-admin') label = 'Quản trị nền tảng';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFDBEAFE)),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Profile Detail Rows
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        _buildProfileRow(Icons.person_outline_rounded, 'Họ và tên', displayName),
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _buildProfileRow(Icons.email_outlined, 'Email đăng nhập', email),
                        if (tenantSlug.isNotEmpty) ...[
                          const Divider(height: 16, color: Color(0xFFF1F5F9)),
                          _buildProfileRow(Icons.business_outlined, 'Doanh nghiệp', tenantSlug.toUpperCase()),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Card 2: Đổi mật khẩu
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.key_rounded, size: 18, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Đổi mật khẩu',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Để bảo mật tài khoản, không nên dùng chung mật khẩu với các dịch vụ khác.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
                  ),
                  const SizedBox(height: 16),

                  if (_inlineError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _inlineError!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Mật khẩu hiện tại
                  _buildPasswordField(
                    label: 'Mật khẩu hiện tại *',
                    controller: _currentPasswordCtrl,
                    obscure: _obscureCurrent,
                    onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // Mật khẩu mới
                  _buildPasswordField(
                    label: 'Mật khẩu mới *',
                    controller: _newPasswordCtrl,
                    obscure: _obscureNew,
                    onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                    onChanged: (_) => setState(() {}),
                  ),

                  // Strength Bar
                  if (_newPasswordCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: List.generate(3, (idx) {
                              final active = idx < (strength['bars'] as int);
                              return Expanded(
                                child: Container(
                                  height: 4,
                                  margin: EdgeInsets.only(right: idx < 2 ? 4 : 0),
                                  decoration: BoxDecoration(
                                    color: active ? strength['color'] as Color : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          strength['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: strength['textColor'] as Color,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Xác nhận mật khẩu mới
                  _buildPasswordField(
                    label: 'Xác nhận mật khẩu mới *',
                    controller: _confirmationCtrl,
                    obscure: _obscureConfirm,
                    onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Rules checklist
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yêu cầu mật khẩu:',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        ...rules.map((rule) {
                          final passed = rule['passed'] as bool;
                          final required = rule['required'] as bool;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 14,
                                  color: passed
                                      ? const Color(0xFF059669)
                                      : (required ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${rule['label']}${required ? ' (Bắt buộc)' : ' (Khuyến nghị)'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: passed
                                          ? const Color(0xFF065F46)
                                          : (required ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                      fontWeight: passed ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: canSubmit && !_isSaving ? _handleSubmit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Lưu mật khẩu mới', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
                color: const Color(0xFF94A3B8),
              ),
              onPressed: onToggleObscure,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
          ),
        ),
      ],
    );
  }
}
