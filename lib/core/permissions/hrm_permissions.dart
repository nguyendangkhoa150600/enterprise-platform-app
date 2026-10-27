import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client_helper.dart';

/// Page -> actions, ported 1:1 from the web (`hrmPagePermissions` in hrm-permissions.tsx).
/// Holding ANY of the actions shows the page.
const List<String> hrmAttendanceMonitorPermissions = [
  'hrm.attendance.read',
  'hrm.timesheet.read',
  'hrm.leave.approve',
  'hrm.ot.approve',
  'hrm.trip.approve',
  'hrm.shift.approve',
  'hrm.attendance.approve',
  'hrm.custom.approve',
  'hrm.advance.approve',
];

/// Tabs of the pages that group several functions (web `HRM_HUBS`).
const Map<String, Map<String, List<String>>> hrmHubTabs = {
  '/my-work': {
    'timesheet': ['hrm.self.read'],
  },
  '/profile': {
    'profile': ['hrm.self.read'],
    'payslips': ['hrm.self.payslip'],
  },
  '/employees': {
    'employees': ['hrm.employee.read'],
    'decisions': ['hrm.appointment.read'],
  },
  '/leave': {
    'balances': ['hrm.leave.read'],
    'adjustments': ['hrm.leave.read'],
  },
  '/timekeeping': {
    'timesheets': ['hrm.timesheet.read'],
    'data': ['hrm.attendance.read'],
  },
  '/payroll': {
    'runs': ['hrm.payroll.read'],
    'advances': ['hrm.advance.read'],
  },
  '/fleet': {
    'schedule': ['hrm.fleet.read'],
    'vehicles': ['hrm.fleet.manage'],
    'drivers': ['hrm.fleet.manage'],
  },
  '/settings': {
    'leave': ['hrm.leave.manage'],
    'time': ['hrm.time.configure', 'hrm.device.manage'],
    'schedules': ['hrm.schedule.read'],
    'shifts': ['hrm.shift.read', 'hrm.shift.manage'],
    'standard-work': ['hrm.time.configure'],
    'auto-attendance': ['hrm.time.configure'],
    'payroll': ['hrm.payroll.configure', 'hrm.salary.read', 'hrm.salary.manage'],
    'request-reasons': ['hrm.leave.manage'],
    'approval': ['hrm.automation.manage'],
    'operations': ['hrm.automation.manage', 'hrm.integration.manage', 'hrm.audit.read'],
    'permissions': ['hrm.manage'],
  },
};

List<String> _hubPagePermissions(String path) =>
    {for (final perms in hrmHubTabs[path]!.values) ...perms}.toList();

final Map<String, List<String>> hrmPagePermissions = {
  '/': ['hrm.self.read', 'hrm.dashboard.read'],
  '/attendance-monitor': hrmAttendanceMonitorPermissions,
  '/approvals': [
    'hrm.leave.approve',
    'hrm.leave.approve.all',
    'hrm.ot.approve',
    'hrm.ot.approve.all',
    'hrm.trip.approve',
    'hrm.trip.approve.all',
    'hrm.shift.approve',
    'hrm.shift.approve.all',
    'hrm.attendance.approve',
    'hrm.attendance.approve.all',
    'hrm.profile.approve',
    'hrm.profile.approve.all',
    'hrm.custom.approve',
    'hrm.custom.approve.all',
    'hrm.advance.approve',
    'hrm.advance.approve.all',
    'hrm.request.read',
    'hrm.request.manage',
    'hrm.advance.read',
  ],
  '/my-work': _hubPagePermissions('/my-work'),
  '/requests': ['hrm.self.read'],
  '/profile': _hubPagePermissions('/profile'),
  '/employees': _hubPagePermissions('/employees'),
  '/leave': _hubPagePermissions('/leave'),
  '/timekeeping': _hubPagePermissions('/timekeeping'),
  '/payroll': _hubPagePermissions('/payroll'),
  '/fleet': _hubPagePermissions('/fleet'),
  '/settings': _hubPagePermissions('/settings'),
};

/// Mobile config-center keys -> tab id of the web `/settings` page.
const Map<String, String> hrmConfigKeyToSettingsTab = {
  'LEAVE': 'leave',
  'POLICY': 'time',
  'HOLIDAYS': 'time',
  'GPS': 'time',
  'DEVICES': 'time',
  'AUTO': 'auto-attendance',
  'SHIFTS_ASSIGN': 'schedules',
  'SHIFTS': 'shifts',
  'STANDARD': 'standard-work',
  'REQUEST_TYPES': 'request-reasons',
  'APPROVAL_FLOWS': 'approval',
  'PAYROLL_CFG': 'payroll',
  'OPERATIONS': 'operations',
  'PERMISSIONS': 'permissions',
};

/// The HRM actions of the signed-in user, from GET /hrm/v1/capabilities (same source as the web).
class HrmCapabilities extends ChangeNotifier {
  HrmCapabilities._();
  static final HrmCapabilities instance = HrmCapabilities._();

  late final Dio _dio = () {
    final dio = Dio(BaseOptions(
      baseUrl: AuthProvider.authBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    ApiClientHelper.configureDio(dio);
    return dio;
  }();

  Set<String> _actions = {};
  bool _loaded = false;
  bool _loading = false;

  bool get loaded => _loaded;
  bool get loading => _loading;
  Set<String> get actions => _actions;

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    try {
      final res = await _dio.get('/hrm/v1/capabilities');
      final data = res.data is Map ? (res.data['data'] ?? res.data) : null;
      final list = data is Map ? data['actions'] : null;
      _actions = list is List ? list.map((e) => e.toString()).toSet() : <String>{};
    } catch (e) {
      debugPrint('[HrmCapabilities] load error: $e');
      _actions = {};
    }
    _loaded = true;
    _loading = false;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetActions(Iterable<String> actions) {
    _actions = actions.toSet();
    _loaded = true;
  }

  void clear() {
    _actions = {};
    _loaded = false;
    notifyListeners();
  }

  bool can(String action) => _actions.contains(action);
  bool any(Iterable<String> actions) => actions.any(_actions.contains);

  /// Whether the web menu item for [path] (e.g. '/payroll') is visible.
  bool pageAllowed(String path) {
    final perms = hrmPagePermissions[path];
    return perms == null || any(perms);
  }

  /// Whether tab [tabId] of the hub page [path] is visible.
  bool tabAllowed(String path, String tabId) {
    final perms = hrmHubTabs[path]?[tabId];
    return perms == null || any(perms);
  }

  /// Punching in/out needs hrm.self.read and hrm.self.attendance.
  bool get canPunch => can('hrm.self.read') && can('hrm.self.attendance');
}

