import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';
import '../services/platform_service.dart';
import '../services/hrm_service.dart';

class UserResolver {
  static final Map<String, String> _userDisplayNames = {};
  static final Map<String, String> _rawNames = {};
  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  static bool _hasLoaded = false;
  static bool get hasLoaded => _hasLoaded;
  static Future<void>? _loadingFuture;

  /// Register user into cache immediately
  static void registerUser(String? id, String? fullName, {String? email, String? username}) {
    if (id == null || id.trim().isEmpty) return;
    final cleanId = id.trim();
    if (fullName != null && fullName.trim().isNotEmpty && fullName != 'Người dùng') {
      _rawNames[cleanId] = fullName.trim();
    }
    final label = _formatUserLabel(fullName, email, username);
    if (label != null) {
      _userDisplayNames[cleanId] = label;
    }
    changeNotifier.value++;
  }

  /// Returns the human-readable display name or account for a given userId / UUID.
  /// If not resolved yet, it triggers a background fetch and returns fallback (never returns raw UUID).
  static String resolve(String? rawId, {String fallback = '—'}) {
    if (rawId == null || rawId.trim().isEmpty) return fallback;
    final clean = rawId.trim();

    // 1. If it already looks like a human name or email or has spaces/at-sign, return as-is
    if (!clean.contains('-') && clean.contains(' ')) return clean;
    if (clean.contains('@')) return clean;

    // 2. Check memory cache
    if (_userDisplayNames.containsKey(clean)) {
      return _userDisplayNames[clean]!;
    }
    if (_rawNames.containsKey(clean)) {
      return _rawNames[clean]!;
    }

    // 3. Check AuthProvider (current user)
    final auth = AuthProvider.instance;
    if (auth != null) {
      if (auth.userId == clean) {
        final label = _formatUserLabel(auth.fullName, auth.email, null) ?? auth.fullName ?? clean;
        _userDisplayNames[clean] = label;
        if (auth.fullName != null && auth.fullName!.isNotEmpty) {
          _rawNames[clean] = auth.fullName!;
        }
        return label;
      }
    }

    // 4. If it's a UUID, trigger ensureLoaded()
    if (isUuid(clean)) {
      ensureLoaded();
      return fallback;
    }

    return clean;
  }

  /// Returns only the full name without email or parenthetical details
  static String resolveName(String? rawId, {String fallback = '—'}) {
    if (rawId == null || rawId.trim().isEmpty) return fallback;
    final clean = rawId.trim();

    // 1. If it already looks like a name with spaces and no hyphens, return as-is
    if (!clean.contains('-') && clean.contains(' ')) return clean;

    // 2. Check rawNames first
    if (_rawNames.containsKey(clean)) {
      return _rawNames[clean]!;
    }

    // 3. Check userDisplayNames
    if (_userDisplayNames.containsKey(clean)) {
      final res = _userDisplayNames[clean]!;
      final paren = res.indexOf(' (');
      if (paren > 0) return res.substring(0, paren);
      return res;
    }

    // 4. If it's a UUID, never return the UUID string to user! Return fallback
    if (isUuid(clean)) {
      ensureLoaded();
      return fallback;
    }

    final res = resolve(rawId, fallback: fallback);
    final paren = res.indexOf(' (');
    if (paren > 0) return res.substring(0, paren);
    return res;
  }

  static bool isUuid(String s) {
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(s);
  }

  static String? _formatUserLabel(String? fullName, String? email, String? username) {
    final hasName = fullName != null && fullName.trim().isNotEmpty && fullName != 'Người dùng';
    final hasEmail = email != null && email.trim().isNotEmpty;
    final hasUsername = username != null && username.trim().isNotEmpty;

    if (hasName) {
      if (hasEmail) return '$fullName ($email)';
      if (hasUsername) return '$fullName (@$username)';
      return fullName;
    }
    if (hasEmail) return email;
    if (hasUsername) return '@$username';
    return null;
  }

  /// Preload all users and employees into cache
  static Future<void> ensureLoaded({bool forceRefresh = false}) async {
    if (_hasLoaded && !forceRefresh) return;
    if (_loadingFuture != null) return _loadingFuture!;

    _loadingFuture = _loadInternal();
    await _loadingFuture;
    _loadingFuture = null;
  }

  static Future<void> _loadInternal() async {
    try {
      // 1. Current user
      final auth = AuthProvider.instance;
      if (auth != null && auth.userId != null && auth.userId!.isNotEmpty) {
        registerUser(auth.userId, auth.fullName, email: auth.email);
      }

      // 2. Tenant users from PlatformService
      final platformService = PlatformService();
      final tenantUsers = await platformService.getTenantUsers();
      for (final u in tenantUsers) {
        registerUser(u.id, u.fullName, email: u.email, username: u.username);
      }

      // 3. Employees from HrmService
      try {
        final employees = await HrmService().getEmployees();
        for (final e in employees) {
          registerUser(e.id, e.fullName, email: e.email);
        }
      } catch (e) {
        debugPrint('[UserResolver] Error loading employees: $e');
      }

      _hasLoaded = true;
      changeNotifier.value++;
    } catch (e) {
      debugPrint('[UserResolver] Error loading users/employees: $e');
    }
  }
}
