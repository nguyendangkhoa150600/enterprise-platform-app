import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/i18n/app_i18n.dart';
import '../services/api_client_helper.dart';
import '../shared/widgets/language_selector_tile.dart';
import '../widgets/user_avatar.dart';

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
  bool _isAvatarBusy = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    PeopleAvatarDirectory.instance.addListener(_onDirectoryChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    PeopleAvatarDirectory.instance.removeListener(_onDirectoryChanged);
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmationCtrl.dispose();
    super.dispose();
  }

  void _onDirectoryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AuthProvider.authBaseUrl,
        connectTimeout: const Duration(seconds: 10),
      ));
      ApiClientHelper.configureDio(dio);
      final res = await dio.get('/api/platform/v1/profile', options: Options(validateStatus: (s) => s != null && s < 500));
      if (!mounted) return;
      if (res.statusCode == 200 && res.data is Map) {
        final v = (res.data['avatarVersion'] as num?)?.toInt();
        final userId = Provider.of<AuthProvider>(context, listen: false).userId;
        if (userId != null && userId.isNotEmpty) {
          PeopleAvatarDirectory.instance.setVersion(userId, v);
          setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _chooseAvatar() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null || !mounted) return;

      final size = await file.length() ?? 0;
      if (size > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('account.avatar.size_error'.tr()),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final ext = (file.extension ?? 'png').toLowerCase();
      if (!['png', 'jpg', 'jpeg', 'webp'].contains(ext)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('account.avatar.type_error'.tr()),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() => _isAvatarBusy = true);

      final bytes = await file.xFile.readAsBytes();
      final dio = Dio(BaseOptions(
        baseUrl: AuthProvider.authBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));
      ApiClientHelper.configureDio(dio);

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'avatar.$ext'),
      });

      final res = await dio.put('/api/platform/v1/profile/avatar', data: formData);
      if (!mounted) return;

      if (res.statusCode == 200 && res.data is Map) {
        final newVersion = (res.data['avatarVersion'] as num?)?.toInt();
        final userId = Provider.of<AuthProvider>(context, listen: false).userId;
        if (userId != null && userId.isNotEmpty) {
          PeopleAvatarDirectory.instance.setVersion(userId, newVersion);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('account.avatar.success'.tr()),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('account.avatar.failed'.tr()),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('account.avatar.failed'.tr()),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAvatarBusy = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _isAvatarBusy = true);
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AuthProvider.authBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));
      ApiClientHelper.configureDio(dio);

      final res = await dio.delete('/api/platform/v1/profile/avatar');
      if (!mounted) return;

      if (res.statusCode == 200) {
        final userId = Provider.of<AuthProvider>(context, listen: false).userId;
        if (userId != null && userId.isNotEmpty) {
          PeopleAvatarDirectory.instance.setVersion(userId, null);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('account.avatar.remove_success'.tr()),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('account.avatar.remove_failed'.tr()),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('account.avatar.remove_failed'.tr()),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAvatarBusy = false);
    }
  }

  // Password rules validation matching React
  List<Map<String, dynamic>> _getRules() {
    final current = _currentPasswordCtrl.text;
    final next = _newPasswordCtrl.text;
    final conf = _confirmationCtrl.text;

    return [
      {
        'id': 'length',
        'label': 'account.rule.length'.tr(),
        'required': true,
        'passed': next.length >= 6 && next.length <= 128,
      },
      {
        'id': 'different',
        'label': 'account.rule.different'.tr(),
        'required': true,
        'passed': next.isNotEmpty && next != current,
      },
      {
        'id': 'match',
        'label': 'account.rule.match'.tr(),
        'required': true,
        'passed': next.isNotEmpty && next == conf,
      },
      {
        'id': 'case',
        'label': 'account.rule.case'.tr(),
        'required': false,
        'passed': RegExp(r'[a-z]').hasMatch(next) && RegExp(r'[A-Z]').hasMatch(next),
      },
      {
        'id': 'digit',
        'label': 'account.rule.digit'.tr(),
        'required': false,
        'passed': RegExp(r'\d').hasMatch(next),
      },
      {
        'id': 'symbol',
        'label': 'account.rule.symbol'.tr(),
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
      return {'label': 'account.strength.weak'.tr(), 'bars': 1, 'color': const Color(0xFFEF4444), 'textColor': const Color(0xFFDC2626)};
    }
    int classes = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) classes++;
    if (RegExp(r'[A-Z]').hasMatch(password)) classes++;
    if (RegExp(r'\d').hasMatch(password)) classes++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) classes++;

    if ((classes >= 4 && password.length >= 12) || (classes >= 3 && password.length >= 16)) {
      return {'label': 'account.strength.strong'.tr(), 'bars': 3, 'color': const Color(0xFF10B981), 'textColor': const Color(0xFF059669)};
    }
    if (classes >= 2) {
      return {'label': 'account.strength.medium'.tr(), 'bars': 2, 'color': const Color(0xFFF59E0B), 'textColor': const Color(0xFFD97706)};
    }
    return {'label': 'account.strength.weak'.tr(), 'bars': 1, 'color': const Color(0xFFEF4444), 'textColor': const Color(0xFFDC2626)};
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
          SnackBar(
            content: Text('account.password_changed'.tr()),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _inlineError = res['message']?.toString() ?? 'account.password_change_failed'.tr();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final displayName = auth.fullName ?? 'account.user'.tr();
    final email = auth.email ?? '';
    final tenantSlug = auth.tenantSlug ?? '';
    final isPlatformAdmin = auth.isPlatformAdmin;

    final currentVersion = auth.userId != null ? PeopleAvatarDirectory.instance.versionOf(auth.userId!) : null;
    final hasAvatar = currentVersion != null;

    final rules = _getRules();
    final strength = _getStrength();
    final canSubmit = _canSubmit();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'account.title'.tr(),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'account.subtitle'.tr(),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                ],
              ),
            ),

            // Language selector
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LanguageSelectorTile(),
            ),

            // Card 1: Master Hồ sơ
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Header Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 24, bottom: 20, left: 16, right: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFF8DC).withValues(alpha: 0.6),
                          Colors.white,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFC90A).withValues(alpha: 0.22),
                                      spreadRadius: 5,
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: UserAvatar(
                                  userId: auth.userId,
                                  name: displayName,
                                  size: 88,
                                  fontSize: 28,
                                ),
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Material(
                                  color: Colors.white,
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  shadowColor: Colors.black.withValues(alpha: 0.18),
                                  child: InkWell(
                                    onTap: _isAvatarBusy ? null : _chooseAvatar,
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: _isAvatarBusy
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                            )
                                          : const Icon(Icons.camera_alt_rounded, size: 16, color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isAvatarBusy ? null : _chooseAvatar,
                              icon: const Icon(Icons.camera_alt_outlined, size: 16),
                              label: Text('account.avatar.update_btn'.tr()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1D4ED8),
                                side: const BorderSide(color: Color(0xFFBFD3FB)),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (hasAvatar)
                              OutlinedButton.icon(
                                onPressed: _isAvatarBusy ? null : _removeAvatar,
                                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                label: Text('account.avatar.remove_btn'.tr()),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'account.avatar.hint'.tr(),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),

                  // Profile Detail Rows
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        _buildProfileRow(Icons.person_outline_rounded, 'account.profile.full_name'.tr(), displayName),
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _buildProfileRow(Icons.email_outlined, 'account.profile.login_email'.tr(), email),
                        if (tenantSlug.isNotEmpty) ...[
                          const Divider(height: 16, color: Color(0xFFF1F5F9)),
                          _buildProfileRow(Icons.business_outlined, 'account.profile.enterprise'.tr(), tenantSlug.toUpperCase()),
                        ],
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _buildProfileRow(
                          Icons.shield_outlined,
                          'account.profile.account_type'.tr(),
                          isPlatformAdmin ? 'account.profile.platform_admin'.tr() : 'account.profile.tenant_user'.tr(),
                        ),
                      ],
                    ),
                  ),

                  // Info Notice Box
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isPlatformAdmin
                                ? 'account.profile.platform_note'.tr()
                                : 'account.profile.manage_note'.tr(),
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                          ),
                        ),
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
                    color: Colors.black.withValues(alpha: 0.02),
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
                      Text(
                        'account.change_password.title'.tr(),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'account.change_password.hint'.tr(),
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
                    label: 'account.field.current_password'.tr(),
                    controller: _currentPasswordCtrl,
                    obscure: _obscureCurrent,
                    onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // Mật khẩu mới
                  _buildPasswordField(
                    label: 'account.field.new_password'.tr(),
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
                    label: 'account.field.confirm_password'.tr(),
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
                        Text(
                          'account.rules_title'.tr(),
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
                                    '${rule['label']}${required ? 'account.rule_required_suffix'.tr() : 'account.rule_recommended_suffix'.tr()}',
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
                          : Text('account.save_new_password'.tr(), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
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
