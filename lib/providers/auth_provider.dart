import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class AuthProvider extends ChangeNotifier {
  static AuthProvider? instance;

  bool _isLoggedIn = false;
  String? _kind; // 'tenant-user' | 'platform-admin'
  String? _tenantSlug;
  String? _fullName;
  String? _email;
  String? _tenantId;
  List<String> _roles = [];
  List<String> _permissions = [];
  String? _cookies;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  String? get kind => _kind;
  bool get isPlatformAdmin => _kind == 'platform-admin' || _roles.contains('platform-admin');
  bool get isTenantAdmin => _roles.contains('tenant-admin');
  String? get tenantSlug => _tenantSlug;
  String? get fullName => _fullName;
  String? get email => _email;
  String? get tenantId => _tenantId;
  List<String> get roles => _roles;
  List<String> get permissions => _permissions;
  String? get cookies => _cookies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool hasPermission(String permission) {
    if (isPlatformAdmin || isTenantAdmin) return true;
    return _permissions.contains(permission) || _permissions.contains('*');
  }

  bool hasRole(String role) {
    if (isPlatformAdmin) return true;
    return _roles.contains(role);
  }

  bool get canCreateUser => isPlatformAdmin || isTenantAdmin || hasPermission('core.users.create') || hasPermission('users.create');
  bool get canUpdateUser => isPlatformAdmin || isTenantAdmin || hasPermission('core.users.update') || hasPermission('users.update');
  bool get canDeleteUser => isPlatformAdmin || isTenantAdmin || hasPermission('core.users.delete') || hasPermission('users.delete');

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  static String get authBaseUrl {
    return 'https://enterprise-platform.savinatestinghub.com/api';
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: authBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
  ));

  AuthProvider() {
    instance = this;
    // Ignore SSL certificate errors for dev server
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };
    init();
  }

  // Load persisted session
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _kind = prefs.getString('user_kind') ?? 'tenant-user';
    _tenantSlug = prefs.getString('tenant_slug');
    _fullName = prefs.getString('full_name');
    _email = prefs.getString('email');
    _tenantId = prefs.getString('tenant_id');
    _roles = prefs.getStringList('roles') ?? [];
    _permissions = prefs.getStringList('permissions') ?? [];
    _cookies = prefs.getString('session_cookies');
    notifyListeners();
  }

  // Set tenant slug optionally
  Future<bool> setTenant(String inputUrl) async {
    _errorMessage = null;
    String cleanSlug = inputUrl.trim().toLowerCase();
    
    // Parse /t/tenant-slug/login or similar patterns
    final tPattern = RegExp(r'/t/([^/]+)');
    if (tPattern.hasMatch(cleanSlug)) {
      final match = tPattern.firstMatch(cleanSlug);
      if (match != null && match.groupCount >= 1) {
        cleanSlug = match.group(1)!;
      }
    }
    
    cleanSlug = cleanSlug
        .replaceAll('http://', '')
        .replaceAll('https://', '')
        .split('.')
        .first
        .split('/')
        .first;

    if (cleanSlug.isEmpty) {
      _errorMessage = 'Tên doanh nghiệp không hợp lệ.';
      notifyListeners();
      return false;
    }

    _tenantSlug = cleanSlug;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tenant_slug', _tenantSlug!);
    notifyListeners();
    return true;
  }

  // Perform unified login (portal: 'tenant' or 'platform')
  Future<bool> login({
    required String email,
    required String password,
    String portal = 'tenant',
    String? tenantSlug,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> requestBody = {
        'email': email.trim(),
        'password': password,
        'portal': portal,
      };

      if (tenantSlug != null && tenantSlug.trim().isNotEmpty) {
        requestBody['tenantSlug'] = tenantSlug.trim().toLowerCase();
      } else if (_tenantSlug != null && _tenantSlug!.trim().isNotEmpty && portal == 'tenant') {
        requestBody['tenantSlug'] = _tenantSlug!.trim().toLowerCase();
      }

      final response = await _dio.post(
        '/auth/v1/login',
        data: requestBody,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final principal = data['principal'];
        
        if (principal == null) {
          throw Exception('Không nhận được thông tin xác thực từ máy chủ.');
        }

        _kind = principal['kind']?.toString() ?? (portal == 'platform' ? 'platform-admin' : 'tenant-user');
        _fullName = principal['displayName']?.toString() ?? principal['fullName']?.toString() ?? (portal == 'platform' ? 'Platform Super Admin' : 'Người dùng');
        _email = principal['email']?.toString() ?? email.trim();
        _tenantId = principal['tenantId']?.toString();
        _tenantSlug = principal['tenantSlug']?.toString() ?? (portal == 'platform' ? 'PLATFORM' : 'SVN');
        _isLoggedIn = true;
        
        final List<dynamic> rolesList = principal['roles'] ?? [];
        _roles = rolesList.map((r) => r.toString()).toList();

        final List<dynamic> permsList = principal['permissions'] ?? [];
        _permissions = permsList.map((p) => p.toString()).toList();

        // Extract cookies
        final List<String>? setCookies = response.headers['set-cookie'];
        if (setCookies != null && setCookies.isNotEmpty) {
          _cookies = setCookies.map((c) => c.split(';').first).join('; ');
        }

        // Persist to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_kind', _kind ?? 'tenant-user');
        await prefs.setString('full_name', _fullName ?? '');
        await prefs.setString('email', _email ?? '');
        await prefs.setString('tenant_id', _tenantId ?? '');
        await prefs.setString('tenant_slug', _tenantSlug ?? '');
        await prefs.setStringList('roles', _roles);
        await prefs.setStringList('permissions', _permissions);
        if (_cookies != null) {
          await prefs.setString('session_cookies', _cookies!);
        }
        
        // Save login credentials for seamless silent background renewal
        await prefs.setString('saved_login_email', email.trim());
        await prefs.setString('saved_login_password', password);
        await prefs.setString('saved_login_portal', portal);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        throw Exception('Đăng nhập thất bại.');
      }
    } on DioException catch (e) {
      _isLoading = false;
      debugPrint("DioException: ${e.toString()}");
      if (e.response != null) {
        debugPrint("DioException Response Data: ${e.response!.data}");
        debugPrint("DioException Response Status: ${e.response!.statusCode}");
      }
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        _errorMessage = 'Hết thời gian chờ kết nối (Timeout). Vui lòng kiểm tra lại đường truyền mạng hoặc máy chủ.';
      } else if (e.type == DioExceptionType.connectionError) {
        _errorMessage = 'Không thể kết nối đến máy chủ (${AuthProvider.authBaseUrl}). Vui lòng kiểm tra kết nối mạng của thiết bị.';
      } else if (e.response != null && e.response!.data != null && e.response!.data['message'] != null) {
        _errorMessage = e.response!.data['message'].toString();
      } else {
        _errorMessage = 'Email hoặc mật khẩu không chính xác.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      debugPrint("General Error: ${e.toString()}");
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  // Clear tenant selection
  Future<void> clearTenant() async {
    _tenantSlug = null;
    _errorMessage = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tenant_slug');
    notifyListeners();
  }

  // Perform logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_cookies != null) {
        await _dio.post(
          '/auth/v1/logout',
          options: Options(
            headers: {
              'cookie': _cookies,
              'x-csrf-token': _getCsrfToken(),
            },
          ),
        );
      }
    } catch (_) {
      // Ignore network errors on logout
    }

    _isLoggedIn = false;
    _kind = null;
    _fullName = null;
    _email = null;
    _tenantId = null;
    _tenantSlug = null;
    _roles = [];
    _permissions = [];
    _cookies = null;
    _isLoading = false;
    _errorMessage = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('user_kind');
    await prefs.remove('full_name');
    await prefs.remove('email');
    await prefs.remove('tenant_id');
    await prefs.remove('tenant_slug');
    await prefs.remove('roles');
    await prefs.remove('permissions');
    await prefs.remove('session_cookies');
    await prefs.remove('saved_login_password');
    
    notifyListeners();
  }

  // Extract ep_csrf from stored cookies string for POST requests
  String _getCsrfToken() {
    return extractCsrf(_cookies);
  }

  static String extractCsrf(String? cookies) {
    if (cookies == null || cookies.isEmpty) return '';
    final parts = cookies.split('; ');
    for (var part in parts) {
      if (part.startsWith('ep_csrf=')) {
        return part.substring('ep_csrf='.length);
      }
    }
    return '';
  }

  // Static helper to get cookies for API requests
  static Future<String?> getStoredCookies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_cookies');
  }

  // Static helper to merge and update cookies from response headers
  static Future<void> updateCookiesFromSetCookie(List<String>? setCookies) async {
    if (setCookies == null || setCookies.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingCookies = prefs.getString('session_cookies');
      final Map<String, String> cookieMap = {};

      if (existingCookies != null && existingCookies.isNotEmpty) {
        for (var part in existingCookies.split('; ')) {
          final idx = part.indexOf('=');
          if (idx > 0) {
            cookieMap[part.substring(0, idx).trim()] = part.substring(idx + 1).trim();
          }
        }
      }

      for (var sc in setCookies) {
        final mainPart = sc.split(';').first;
        final idx = mainPart.indexOf('=');
        if (idx > 0) {
          cookieMap[mainPart.substring(0, idx).trim()] = mainPart.substring(idx + 1).trim();
        }
      }

      final merged = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
      await prefs.setString('session_cookies', merged);
      
      if (instance != null) {
        instance!._cookies = merged;
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error updating cookies: $e');
    }
  }

  // Silent automatic background login to renew session seamlessly
  static Future<bool> silentRelogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_login_email');
      final savedPassword = prefs.getString('saved_login_password');
      final savedPortal = prefs.getString('saved_login_portal') ?? 'tenant';
      final savedTenantSlug = prefs.getString('tenant_slug');

      if (savedEmail == null || savedEmail.isEmpty || savedPassword == null || savedPassword.isEmpty) {
        debugPrint('[AuthProvider] silentRelogin: No saved credentials found.');
        return false;
      }

      debugPrint('[AuthProvider] silentRelogin: Attempting silent renewal for $savedEmail...');
      final standaloneDio = Dio(BaseOptions(
        baseUrl: authBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
      ));
      (standaloneDio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        return client;
      };

      final Map<String, dynamic> body = {
        'email': savedEmail.trim(),
        'password': savedPassword,
        'portal': savedPortal,
      };
      if (savedTenantSlug != null && savedTenantSlug.isNotEmpty && savedPortal == 'tenant') {
        body['tenantSlug'] = savedTenantSlug.trim().toLowerCase();
      }

      final response = await standaloneDio.post('/auth/v1/login', data: body);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final principal = data['principal'];
        if (principal != null) {
          final setCookies = response.headers['set-cookie'];
          if (setCookies != null && setCookies.isNotEmpty) {
            final newCookies = setCookies.map((c) => c.split(';').first).join('; ');
            await prefs.setString('session_cookies', newCookies);
            if (instance != null) {
              instance!._cookies = newCookies;
              instance!._isLoggedIn = true;
              instance!._fullName = principal['displayName']?.toString() ?? principal['fullName']?.toString();
              instance!._email = principal['email']?.toString() ?? savedEmail;
              instance!._tenantId = principal['tenantId']?.toString();
              instance!._tenantSlug = principal['tenantSlug']?.toString() ?? savedTenantSlug;
              final List<dynamic> rolesList = principal['roles'] ?? [];
              instance!._roles = rolesList.map((r) => r.toString()).toList();
              final List<dynamic> permsList = principal['permissions'] ?? [];
              instance!._permissions = permsList.map((p) => p.toString()).toList();
              instance!.notifyListeners();
            }
          }
          debugPrint('[AuthProvider] silentRelogin: Session renewed successfully!');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] silentRelogin failed: $e');
    }
    return false;
  }
}
