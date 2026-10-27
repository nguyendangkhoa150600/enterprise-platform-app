import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:power_quality_analysis/core/permissions/hrm_permissions.dart';
import 'package:power_quality_analysis/providers/auth_provider.dart';

Future<AuthProvider> authWith({String kind = 'tenant-user', List<String> roles = const [], List<String> permissions = const []}) async {
  SharedPreferences.setMockInitialValues({
    'is_logged_in': true,
    'user_kind': kind,
    'roles': roles,
    'permissions': permissions,
  });
  final auth = AuthProvider();
  await auth.init();
  return auth;
}

void main() {
  group('tenant shell permissions (same rules as the web)', () {
    test('tenant.manage sees everything', () async {
      final a = await authWith(permissions: ['tenant.manage']);
      expect(a.canViewRoles, isTrue);
      expect(a.canViewUsers, isTrue);
      expect(a.canViewOrganization, isTrue);
      expect(a.canCreateUser && a.canUpdateUser && a.canDeleteUser, isTrue);
      expect(a.canCreateOrganization && a.canUpdateOrganization && a.canDeleteOrganization, isTrue);
    });

    test('plain employee sees none of the admin pages', () async {
      final a = await authWith(permissions: ['module.access']);
      expect(a.canViewRoles, isFalse);
      expect(a.canViewUsers, isFalse);
      expect(a.canViewOrganization, isFalse);
      expect(a.canCreateUser, isFalse);
    });

    test('read-only users/org: can view but not change; roles still hidden', () async {
      final a = await authWith(permissions: ['core.users.read', 'core.organization.read']);
      expect(a.canViewUsers, isTrue);
      expect(a.canViewOrganization, isTrue);
      expect(a.canViewRoles, isFalse);
      expect(a.canCreateUser || a.canUpdateUser || a.canDeleteUser, isFalse);
      expect(a.canCreateOrganization || a.canUpdateOrganization || a.canDeleteOrganization, isFalse);
    });

    test('granular action only unlocks that action', () async {
      final a = await authWith(permissions: ['core.users.read', 'core.users.update']);
      expect(a.canUpdateUser, isTrue);
      expect(a.canDeleteUser, isFalse);
      expect(a.canCreateUser, isFalse);
    });

    test('tenant-admin role alone no longer bypasses (web uses permissions)', () async {
      final a = await authWith(roles: ['tenant-admin'], permissions: []);
      expect(a.canViewRoles, isFalse);
    });
  });

  group('HRM page / tab permissions (port of web hrmPagePermissions)', () {
    final caps = HrmCapabilities.instance;

    test('employee self-service', () {
      caps.debugSetActions(['hrm.self.read', 'hrm.self.attendance', 'hrm.self.payslip']);
      expect(caps.pageAllowed('/'), isTrue);
      expect(caps.pageAllowed('/my-work'), isTrue);
      expect(caps.pageAllowed('/requests'), isTrue);
      expect(caps.pageAllowed('/profile'), isTrue);
      expect(caps.tabAllowed('/profile', 'payslips'), isTrue);
      expect(caps.canPunch, isTrue);
      // management pages stay hidden
      for (final p in ['/employees', '/timekeeping', '/leave', '/payroll', '/fleet', '/settings', '/approvals', '/attendance-monitor']) {
        expect(caps.pageAllowed(p), isFalse, reason: p);
      }
    });

    test('no payslip permission hides the payslip tab only', () {
      caps.debugSetActions(['hrm.self.read']);
      expect(caps.tabAllowed('/profile', 'profile'), isTrue);
      expect(caps.tabAllowed('/profile', 'payslips'), isFalse);
      expect(caps.canPunch, isFalse);
    });

    test('line manager: approvals + monitor, no payroll/settings', () {
      caps.debugSetActions(['hrm.self.read', 'hrm.leave.approve', 'hrm.ot.approve']);
      expect(caps.pageAllowed('/approvals'), isTrue);
      expect(caps.pageAllowed('/attendance-monitor'), isTrue);
      expect(caps.pageAllowed('/payroll'), isFalse);
      expect(caps.pageAllowed('/settings'), isFalse);
    });

    test('payroll reader sees payroll runs but not advances; settings tabs follow their own actions', () {
      caps.debugSetActions(['hrm.payroll.read', 'hrm.shift.read']);
      expect(caps.pageAllowed('/payroll'), isTrue);
      expect(caps.tabAllowed('/payroll', 'runs'), isTrue);
      expect(caps.tabAllowed('/payroll', 'advances'), isFalse);
      expect(caps.pageAllowed('/settings'), isTrue);
      expect(caps.tabAllowed('/settings', 'shifts'), isTrue);
      expect(caps.tabAllowed('/settings', 'permissions'), isFalse);
      expect(caps.tabAllowed('/settings', 'standard-work'), isFalse);
    });

    test('no capabilities at all hides every HRM page', () {
      caps.debugSetActions([]);
      for (final p in hrmPagePermissions.keys) {
        expect(caps.pageAllowed(p), isFalse, reason: p);
      }
    });
  });
}
