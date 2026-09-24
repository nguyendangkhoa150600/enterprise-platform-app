import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _tenantSlug;
  String? _fullName;
  String? _email;
  String? _tenantId;
  List<String> _permissions = [];
  String? _cookies;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  String? get tenantSlug => _tenantSlug;
  String? get fullName => _fullName;
  String? get email => _email;
  String? get tenantId => _tenantId;
  List<String> get permissions => _permissions;
  String? get cookies => _cookies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  static String get authBaseUrl {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3333/api';
      }
    } catch (_) {}
    return 'http://localhost:3333/api';
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: authBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
  ));

  AuthProvider() {
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
    _tenantSlug = prefs.getString('tenant_slug');
    _fullName = prefs.getString('full_name');
    _email = prefs.getString('email');
    _tenantId = prefs.getString('tenant_id');
    _permissions = prefs.getStringList('permissions') ?? [];
    _cookies = prefs.getString('session_cookies');
    notifyListeners();
  }

  // Set tenant slug after parsing enter url screen
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
    
    // Remove extra domain components or path slashes
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

  // Perform tenant login
  Future<bool> login(String email, String password) async {
    if (_tenantSlug == null) {
      _errorMessage = 'Vui lòng chọn doanh nghiệp trước.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.post(
        '/auth/v1/login',
        data: {
          'email': email,
          'password': password,
          'portal': 'tenant',
          'tenantSlug': _tenantSlug,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final principal = data['principal'];
        
        if (principal == null || principal['kind'] != 'tenant-user') {
          throw Exception('Tài khoản không phải quản trị viên hoặc nhân viên của doanh nghiệp.');
        }

        _fullName = principal['fullName'] ?? 'Người dùng';
        _email = principal['email'];
        _tenantId = principal['tenantId'];
        _isLoggedIn = true;
        
        final List<dynamic> permsList = principal['permissions'] ?? [];
        _permissions = permsList.map((p) => p.toString()).toList();

        // Extract cookies
        final List<String>? setCookies = response.headers['set-cookie'];
        if (setCookies != null && setCookies.isNotEmpty) {
          // Clean and store cookies
          _cookies = setCookies.map((c) => c.split(';').first).join('; ');
        }

        // Persist to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('full_name', _fullName ?? '');
        await prefs.setString('email', _email ?? '');
        await prefs.setString('tenant_id', _tenantId ?? '');
        await prefs.setStringList('permissions', _permissions);
        if (_cookies != null) {
          await prefs.setString('session_cookies', _cookies!);
        }

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
        _errorMessage = 'Hết thời gian kết nối (Timeout). Vui lòng đảm bảo backend (npm run dev trên cổng 3333) đang chạy.';
      } else if (e.type == DioExceptionType.connectionError) {
        _errorMessage = 'Không thể kết nối đến máy chủ Gateway (cổng 8080). Vui lòng kiểm tra Docker.';
      } else if (e.response != null && e.response!.data != null && e.response!.data['message'] != null) {
        _errorMessage = e.response!.data['message'].toString();
      } else {
        _errorMessage = 'Thông tin đăng nhập không chính xác hoặc lỗi hệ thống.';
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

  // Clear tenant selection (change workspace)
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
      // Send logout request
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
      // Ignore network errors on logout to allow offline state clearing
    }

    _isLoggedIn = false;
    _fullName = null;
    _email = null;
    _tenantId = null;
    _permissions = [];
    _cookies = null;
    _isLoading = false;
    _errorMessage = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('full_name');
    await prefs.remove('email');
    await prefs.remove('tenant_id');
    await prefs.remove('permissions');
    await prefs.remove('session_cookies');
    
    notifyListeners();
  }

  // Extract ep_csrf from stored cookies string for POST requests
  String _getCsrfToken() {
    if (_cookies == null) return '';
    final parts = _cookies!.split('; ');
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
}
