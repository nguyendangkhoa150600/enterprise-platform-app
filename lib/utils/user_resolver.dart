import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';
import '../services/platform_service.dart';
import '../services/hrm_service.dart';

class UserResolver {
  static final Map<String, String> _userDisplayNames = {};
  static bool _hasLoaded = false;
  static Future<void>? _loadingFuture;

  /// Returns the human-readable display name or account for a given userId / UUID.
  /// If not resolved yet, it triggers a background fetch and returns a clean label.
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

    // 3. Check AuthProvider (current user)
    final auth = AuthProvider.instance;
    if (auth != null) {
      if (auth.userId == clean) {
        final label = _formatUserLabel(auth.fullName, auth.email, null) ?? clean;
        _userDisplayNames[clean] = label;
        return label;
      }
    }

    // 4. If it's a UUID, trigger ensureLoaded()
    if (_isUuid(clean)) {
      ensureLoaded();
    }

    // 5. If we still don't have this UUID, but current user is logged in and no other users exist yet,
    // and this decision was just created in this session, check if we can fall back to current user's name
    if (_userDisplayNames.containsKey(clean)) {
      return _userDisplayNames[clean]!;
    }

    return clean;
  }

  static bool _isUuid(String s) {
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
        final label = _formatUserLabel(auth.fullName, auth.email, null);
        if (label != null) {
          _userDisplayNames[auth.userId!] = label;
        }
      }

      // 2. Tenant users from PlatformService
      final platformService = PlatformService();
      final tenantUsers = await platformService.getTenantUsers();
      for (final u in tenantUsers) {
        final label = _formatUserLabel(u.fullName, u.email, u.username);
        if (label != null) {
          _userDisplayNames[u.id] = label;
        }
        // Match current user if email matches
        if (auth != null && auth.email != null && auth.email!.isNotEmpty) {
          if (u.email.toLowerCase() == auth.email!.toLowerCase()) {
            if (label != null) {
              _userDisplayNames[u.id] = label;
            }
          }
        }
      }

      // 3. Employees from HrmService
      final employees = await HrmService().getEmployees();
      for (final e in employees) {
        String label = e.fullName;
        if (e.code.isNotEmpty) {
          label = '${e.fullName} (${e.code})';
        } else if (e.email.isNotEmpty) {
          label = '${e.fullName} (${e.email})';
        }
        _userDisplayNames[e.id] = label;
      }

      _hasLoaded = true;
    } catch (e) {
      debugPrint('[UserResolver] Error loading users/employees: $e');
    }
  }
}
