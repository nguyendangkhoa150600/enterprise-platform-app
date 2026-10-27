import 'package:provider/provider.dart';
import '../core/permissions/hrm_permissions.dart';
import '../shared/widgets/no_access_view.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';
import '../models/hrm_models.dart';
import '../models/hrm_attendance_models.dart';
import '../services/hrm_service.dart';
import '../services/hrm_attendance_service.dart';
import '../widgets/hrm_profile_modals.dart';
import 'attendance_screen.dart';
import 'attendance_monitor_screen.dart';
import 'leave_balances_screen.dart';
import 'profile_income_screen.dart';
import 'account_screen.dart';
import 'hrm/components/hrm_dependents_view.dart';
import 'hrm/components/hrm_shifts_modals.dart';
import '../features/hrm/attendance/presentation/views/hrm_timesheet_summary_view.dart';
import '../features/hrm/schedule/presentation/views/hrm_schedule_management_view.dart';
import '../features/hrm/payroll/presentation/views/hrm_payroll_views.dart';
import '../features/hrm/overview/presentation/screens/hrm_config_overview_view.dart';
import '../features/hrm/config/presentation/views/hrm_attendance_policy_config_view.dart';
import '../features/hrm/config/presentation/views/hrm_leave_policy_config_view.dart';
import '../features/hrm/config/presentation/views/hrm_work_calendar_config_view.dart';
import '../features/hrm/config/presentation/views/hrm_gps_locations_config_view.dart';
import '../features/hrm/config/presentation/views/hrm_hardware_devices_config_view.dart';
import '../features/hrm/config/presentation/views/hrm_shifts_standard_config_views.dart';
import '../features/hrm/config/presentation/views/hrm_config_static_views.dart';
import '../features/hrm/requests/presentation/views/hrm_approvals_view.dart';
import '../features/hrm/employees/presentation/views/hrm_employees_directory_view.dart';

class HrmHubScreen extends StatefulWidget {
  final int initialTabIndex;
  final int initialWorkforceSubTab;
  final String? initialView;

  const HrmHubScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialWorkforceSubTab = 0,
    this.initialView,
  });

  @override
  State<HrmHubScreen> createState() => _HrmHubScreenState();
}


class _HrmHubScreenState extends State<HrmHubScreen> with SingleTickerProviderStateMixin {
  final HrmService _hrmService = HrmService();
  final HrmAttendanceService _attendanceService = HrmAttendanceService();

  late String _activeView;

  List<HrmRequestItem> _requests = [];
  List<HrmEmployeeItem> _employees = [];
  List<HrmPositionItem> _positions = [];
  List<HrmShift> _shifts = [];
  List<HrmDependentItem> _dependents = [];
  List<HrmSalaryAdvanceItem> _advances = [];
  List<HrmIntegrationDevice> _devices = [];
  AttendanceRecord? _todayAttendance;

  bool _isLoading = true;
  final String _timesheetMonthKey = '2026-10';
  HrmTimesheetBoard? _enterpriseTimesheetBoard;
  String _configSubTab = 'OVERVIEW';
  List<Map<String, dynamic>> _policyVersions = [];
  List<Map<String, dynamic>> _calendarExceptions = [];
  List<Map<String, dynamic>> _gpsSites = [];
  List<Map<String, dynamic>> _payrollPeriods = [];

  HrmCapabilities get _caps => HrmCapabilities.instance;

  /// Same page/tab permissions as the web (hrmPagePermissions / HRM_HUBS).
  bool _viewAllowed(String view) {
    switch (view) {
      case 'dashboard':
        return _caps.pageAllowed('/');
      case 'attendance_monitor':
        return _caps.pageAllowed('/attendance-monitor');
      case 'schedule':
        return _caps.tabAllowed('/settings', 'schedules');
      case 'requests':
      case 'approvals':
        return _caps.pageAllowed('/approvals');
      case 'profile_income':
      case 'my_profile':
      case 'dependents':
        return _caps.tabAllowed('/profile', 'profile');
      case 'my_payslips':
        return _caps.tabAllowed('/profile', 'payslips');
      case 'employees':
        return _caps.tabAllowed('/employees', 'employees');
      case 'shifts':
        return _caps.tabAllowed('/settings', 'shifts');
      case 'timesheet':
        return _caps.pageAllowed('/timekeeping');
      case 'payroll':
        return _caps.tabAllowed('/payroll', 'runs');
      case 'advances':
        return _caps.tabAllowed('/payroll', 'advances');
      case 'config':
      case 'policy':
      case 'settings':
        return _caps.pageAllowed('/settings');
      case 'integrations':
        return _caps.tabAllowed('/settings', 'operations');
      default:
        return true;
    }
  }

  @override
  void initState() {
    super.initState();
    _caps.load();
    if (widget.initialView != null) {
      _activeView = widget.initialView!;
    } else if (widget.initialTabIndex == 1) {
      _activeView = 'requests';
    } else if (widget.initialTabIndex == 2) {
      _activeView = 'approvals';
    } else if (widget.initialTabIndex == 3) {
      if (widget.initialWorkforceSubTab == 1) {
        _activeView = 'shifts';
      } else if (widget.initialWorkforceSubTab == 2) {
        _activeView = 'payroll';
      } else {
        _activeView = 'employees';
      }
    } else {
      _activeView = 'dashboard';
    }

    _loadAllHrmData();
  }

  Future<void> _refreshGpsSites() async {
    try {
      final sites = await _hrmService.getGpsSites();
      if (mounted) {
        setState(() {
          _gpsSites = sites;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('hrm_hub.gps_updated'.tr(args: {'count': sites.length})),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      debugPrint('[HrmHubScreen] _refreshGpsSites error: $e');
    }
  }

  Future<void> _loadAllHrmData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _hrmService.getDashboardStats().catchError((e) => HrmDashboardStats.fromJson(const {})),
        _hrmService.getRequests().catchError((e) => <HrmRequestItem>[]),
        _hrmService.getEmployees(forceRefresh: true).catchError((e) => <HrmEmployeeItem>[]),
        _hrmService.getPayslips().catchError((e) => <HrmPayslipItem>[]),
        _hrmService.getShifts().catchError((e) => <HrmShift>[]),
        _attendanceService.getTodayAttendance().catchError((e) => null),
        _hrmService.getDependents().catchError((e) => <HrmDependentItem>[]),
        _hrmService.getSalaryAdvances().catchError((e) => <HrmSalaryAdvanceItem>[]),
        _attendanceService.getTimesheetBoard(month: _timesheetMonthKey, self: false, page: 1, pageSize: 100).catchError((e) => null),
        _hrmService.getPolicyConfig().catchError((e) => const HrmPolicyConfig()),
        _hrmService.getIntegrationDevices().catchError((e) => <HrmIntegrationDevice>[]),
        _hrmService.getPositions(forceRefresh: true).catchError((e) => <HrmPositionItem>[]),
        _hrmService.getAttendancePolicyVersions().catchError((e) => <Map<String, dynamic>>[]),
        _attendanceService.getAttendanceContext().catchError((e) => null),
        _hrmService.getWorkCalendarExceptions().catchError((e) => <Map<String, dynamic>>[]),
        _hrmService.getGpsSites().catchError((e) => <Map<String, dynamic>>[]),
        _hrmService.getPayrollPeriods().catchError((e) => <Map<String, dynamic>>[]),
        _hrmService.getAnnualLeavePolicy().catchError((e) => null),
      ]);

      if (mounted) {
        final board = results[8] as HrmTimesheetBoard?;
        setState(() {
          _requests = results[1] as List<HrmRequestItem>;
          _employees = results[2] as List<HrmEmployeeItem>;
          _shifts = results[4] as List<HrmShift>;
          _todayAttendance = results[5] as AttendanceRecord?;
          _dependents = results[6] as List<HrmDependentItem>;
          _advances = results[7] as List<HrmSalaryAdvanceItem>;
          _enterpriseTimesheetBoard = board;
          _devices = results[10] as List<HrmIntegrationDevice>;
          _positions = results[11] as List<HrmPositionItem>;
          _policyVersions = results[12] as List<Map<String, dynamic>>;
          _calendarExceptions = results[14] as List<Map<String, dynamic>>;
          _gpsSites = results[15] as List<Map<String, dynamic>>;
          _payrollPeriods = results[16] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[HrmHubScreen] _loadAllHrmData unexpected error: ');
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _navigateToView(String viewKey) {
    setState(() {
      _activeView = viewKey;
    });
  }

  String get _currentViewTitle {
    switch (_activeView) {
      case 'dashboard':
        return 'hrm_hub.title.dashboard'.tr();
      case 'attendance_monitor':
        return 'hrm_hub.title.attendance_monitor'.tr();
      case 'schedule':
        return 'hrm_hub.title.schedule'.tr();
      case 'requests':
      case 'approvals':
        return 'hrm_hub.title.approvals'.tr();
      case 'profile_income':
        return 'hrm_hub.title.profile_income'.tr();
      case 'my_profile':
        return 'hrm_hub.title.my_profile'.tr();
      case 'my_payslips':
        return 'hrm_hub.title.my_payslips'.tr();
      case 'employees':
        return 'hrm_hub.title.employees'.tr();
      case 'dependents':
        return 'hrm_hub.title.dependents'.tr();
      case 'shifts':
        return 'hrm_hub.title.shifts'.tr();
      case 'timesheet':
        return 'hrm_hub.title.timesheet'.tr();
      case 'payroll':
        return 'hrm_hub.title.payroll'.tr();
      case 'advances':
        return 'hrm_hub.title.advances'.tr();
      case 'policy':
      case 'config':
      case 'settings':
        return 'hrm_hub.title.config'.tr();
      case 'integrations':
        return 'hrm_hub.title.integrations'.tr();
      default:
        return 'hrm_hub.title.default'.tr();
    }
  }

  String _getConfigSubTabSubtitle() {
    switch (_configSubTab) {
      case 'OVERVIEW':
        return 'hrm_hub.config.overview'.tr();
      case 'LEAVE':
        return 'hrm_hub.config.leave'.tr();
      case 'POLICY':
        return 'hrm_hub.config.policy'.tr();
      case 'HOLIDAYS':
        return 'hrm_hub.config.holidays'.tr();
      case 'GPS':
        return 'hrm_hub.config.gps'.tr();
      case 'DEVICES':
        return 'hrm_hub.config.devices'.tr();
      case 'AUTO':
        return 'hrm_hub.config.auto'.tr();
      case 'SHIFTS_ASSIGN':
        return 'hrm_hub.config.shifts_assign'.tr();
      case 'SHIFTS':
        return 'hrm_hub.config.shifts'.tr();
      case 'STANDARD':
        return 'hrm_hub.config.standard'.tr();
      case 'REQUEST_TYPES':
        return 'hrm_hub.config.request_types'.tr();
      case 'APPROVAL_FLOWS':
        return 'hrm_hub.config.approval_flows'.tr();
      case 'PAYROLL_CFG':
        return 'hrm_hub.config.payroll_cfg'.tr();
      case 'OPERATIONS':
        return 'hrm_hub.config.operations'.tr();
      case 'PERMISSIONS':
        return 'hrm_hub.config.permissions'.tr();
      default:
        return 'hrm_hub.config.overview'.tr();
    }
  }


  String _formatDate(DateTime? dt) {
    if (dt == null) return '--/--/----';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double? val) {
    if (val == null) return '0 ₫';
    final str = val.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')} ₫';
  }

  @override
  Widget build(BuildContext context) {
    context.watch<HrmCapabilities>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Dark slate
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'common.back'.tr(),
          onPressed: () {
            if ((_activeView == 'config' || _activeView == 'policy' || _activeView == 'settings') && _configSubTab != 'OVERVIEW') {
              setState(() => _configSubTab = 'OVERVIEW');
            } else if (_activeView != 'dashboard' && widget.initialView == null) {
              setState(() => _activeView = 'dashboard');
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentViewTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              (_activeView == 'config' || _activeView == 'policy' || _activeView == 'settings')
                  ? 'SVN DTS / ${_getConfigSubTabSubtitle()}'
                  : 'hrm_hub.appbar.breadcrumb'.tr(),
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          if (_activeView == 'config' || _activeView == 'policy' || _activeView == 'settings')
            IconButton(
              icon: const Icon(Icons.view_sidebar_outlined, size: 22),
              tooltip: 'hrm_hub.appbar.config_menu'.tr(),
              onPressed: () => setState(() => _configSubTab = 'OVERVIEW'),
            ),
          if (_activeView != 'dashboard' && widget.initialView == null)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined, size: 20),
              tooltip: 'hrm_hub.appbar.back_to_dashboard'.tr(),
              onPressed: () => _navigateToView('dashboard'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'common.refresh'.tr(),
            onPressed: () async {
              await _loadAllHrmData();
              if (_configSubTab == 'LEAVE') {
              }
            },
          ),
        ],
      ),
      body: (_isLoading || !_caps.loaded)
          ? const Center(child: CircularProgressIndicator())
          : _buildActiveContentView(),
    );
  }

  // ==========================================
  // VIEW DISPATCHER
  // ==========================================
  Widget _buildActiveContentView() {
    if (!_viewAllowed(_activeView)) {
      return NoAccessView(message: 'perm.no_access_hrm'.tr());
    }
    switch (_activeView) {
      case 'dashboard':
        return _buildOverviewTab();
      case 'attendance_monitor':
        return AttendanceMonitorScreen(
          onOpenApprovals: () => _navigateToView('approvals'),
        );
      case 'schedule':
        return _buildScheduleView();
      case 'requests':
        return _buildRequestsTab();
      case 'profile_income':
      case 'my_profile':
        return const ProfileIncomeScreen(initialTabIndex: 0);
      case 'my_payslips':
        return const ProfileIncomeScreen(initialTabIndex: 1);
      case 'my_account':
      case 'account':
        return const AccountScreen();
      case 'employees':
        return _buildEmployeesDirectoryView();
      case 'dependents':
        return _buildDependentsView();
      case 'shifts':
        return _buildShiftsManagementView();
      case 'approvals':
        return _buildApprovalsTab();
      case 'timesheet':
        return _buildTimesheetSummaryView();
      case 'payroll':
        return _buildPayrollView();
      case 'advances':
        return _buildSalaryAdvancesView();
      case 'policy':
      case 'config':
      case 'settings':
        return _buildHrmConfigCenterView();
      case 'integrations':
        return _buildSystemIntegrationsView();
      default:
        return _buildOverviewTab();
    }
  }

  // ==========================================
  // 1. DASHBOARD OVERVIEW (Web 1:1)
  // ==========================================
  Widget _buildOverviewTab() {
    final empCount = _employees.isNotEmpty ? _employees.length : 6;
    final officialEmpCount = _employees.isNotEmpty 
        ? _employees.where((e) => (e.contractType?.toLowerCase().contains('chính thức') ?? false) || e.status == 'ACTIVE').length.clamp(1, 99)
        : 6;
    final hasCheckedIn = _todayAttendance?.firstCheckInAt != null;

    final pendingLeaves = _requests.where((r) => r.type == HrmRequestType.leave && r.status == HrmRequestStatus.pending).length;
    final pendingOts = _requests.where((r) => r.type == HrmRequestType.overtime && r.status == HrmRequestStatus.pending).length;
    final pendingAdvances = _requests.where((r) => r.type == HrmRequestType.advance && r.status == HrmRequestStatus.pending).length;

    return RefreshIndicator(
      onRefresh: _loadAllHrmData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Breadcrumb & Page Title
            Text(
              'hrm_hub.dash.breadcrumb'.tr(),
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'hrm_hub.title.dashboard'.tr(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              'hrm_hub.dash.subtitle'.tr(),
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
            ),
            const SizedBox(height: 14),

            // 2. Banner: Tổng quan Nhân sự & Điều hành
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'hrm_hub.dash.banner_title'.tr(),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          'hrm_hub.dash.realtime'.tr(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'hrm_hub.dash.banner_desc'.tr(),
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_viewAllowed('employees'))
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToView('employees'),
                          icon: const Icon(Icons.people_outline, size: 16),
                          label: Text('hrm_hub.dash.manage_hr'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      if (_viewAllowed('employees') && _viewAllowed('approvals')) const SizedBox(width: 8),
                      if (_viewAllowed('approvals'))
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToView('approvals'),
                          icon: const Icon(Icons.mail_outline, size: 16),
                          label: Text('hrm_hub.dash.process_requests'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_caps.can('hrm.dashboard.read')) ...[
            // 3. Section: QUY MÔ & LỰC LƯỢNG LAO ĐỘNG
            _buildSectionHeader(
              icon: Icons.people_outline,
              iconColor: const Color(0xFF2563EB),
              title: 'hrm_hub.dash.section_workforce'.tr(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildWebStatCard(
                    title: 'hrm_hub.dash.total_employees'.tr(),
                    value: '$empCount',
                    subtitle: 'hrm_hub.dash.total_employees_sub'.tr(),
                    icon: Icons.people_alt_outlined,
                    iconBgColor: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'hrm_hub.dash.official_contracts'.tr(),
                    value: '$officialEmpCount',
                    subtitle: 'hrm_hub.dash.official_sub'.tr(),
                    icon: Icons.how_to_reg_outlined,
                    iconBgColor: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'hrm_hub.dash.probation'.tr(),
                    value: '0',
                    subtitle: 'hrm_hub.dash.probation_sub'.tr(),
                    icon: Icons.person_add_outlined,
                    iconBgColor: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ],
            if (_caps.can('hrm.dashboard.read')) ...[
            // 4. Section: TÌNH HÌNH CHẤM CÔNG HÔM NAY
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  icon: Icons.access_time,
                  iconColor: const Color(0xFF059669),
                  title: 'hrm_hub.dash.section_attendance'.tr(),
                ),
                InkWell(
                  onTap: () async {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceMonitorScreen(
                          onOpenApprovals: () => _navigateToView('approvals'),
                        ),
                      ),
                    );
                    if (res == 'approvals' && mounted) {
                      _navigateToView('approvals');
                    }
                  },
                  child: Text(
                    'hrm_hub.dash.open_monitor'.tr(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildWebStatCard(
                    title: 'hrm_hub.dash.checked_in'.tr(),
                    value: hasCheckedIn ? '1' : '0',
                    subtitle: 'hrm_hub.dash.checked_in_sub'.tr(),
                    icon: Icons.check_circle_outline,
                    iconBgColor: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'hrm_hub.dash.late_today'.tr(),
                    value: '0',
                    subtitle: 'hrm_hub.dash.late_sub'.tr(),
                    icon: Icons.schedule,
                    iconBgColor: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildWebStatCard(
                    title: 'hrm_hub.dash.anomalies'.tr(),
                    value: '0',
                    subtitle: 'hrm_hub.dash.anomalies_sub'.tr(),
                    icon: Icons.warning_amber_rounded,
                    iconBgColor: const Color(0xFFFEF2F2),
                    iconColor: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'hrm_hub.dash.on_leave'.tr(),
                    value: '0',
                    subtitle: 'hrm_hub.dash.on_leave_sub'.tr(),
                    icon: Icons.calendar_today_outlined,
                    iconBgColor: const Color(0xFFFAF5FF),
                    iconColor: const Color(0xFF9333EA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ],
            if (_caps.pageAllowed('/approvals')) ...[
            // 5. Section: ĐƠN TỪ & YÊU CẦU CHỜ XỬ LÝ
            _buildSectionHeader(
              icon: Icons.mark_email_unread_outlined,
              iconColor: const Color(0xFFD97706),
              title: 'hrm_hub.dash.section_requests'.tr(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildWebStatCard(
                    title: 'hrm_hub.dash.leave_pending'.tr(),
                    value: '$pendingLeaves',
                    subtitle: 'hrm_hub.dash.leave_pending_sub'.tr(),
                    icon: Icons.article_outlined,
                    iconBgColor: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'hrm_hub.dash.ot_pending'.tr(),
                    value: '$pendingOts',
                    subtitle: 'hrm_hub.dash.ot_pending_sub'.tr(),
                    icon: Icons.schedule,
                    iconBgColor: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'hrm_hub.dash.explain_pending'.tr(),
                    value: '$pendingAdvances',
                    subtitle: 'hrm_hub.dash.explain_pending_sub'.tr(),
                    icon: Icons.description_outlined,
                    iconBgColor: const Color(0xFFFAF5FF),
                    iconColor: const Color(0xFF9333EA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ],
            // 6. Section: PHÂN KHU CHỨC NĂNG NGHIỆP VỤ
            _buildSectionHeader(
              icon: Icons.bolt,
              iconColor: const Color(0xFF0F172A),
              title: 'hrm_hub.dash.section_modules'.tr(),
            ),
            const SizedBox(height: 10),
            if (_viewAllowed('employees'))
            _buildBusinessActionCard(
              icon: Icons.person_outline,
              title: 'hrm_hub.module.employees_title'.tr(),
              description: 'hrm_hub.module.employees_desc'.tr(),
              onTap: () => _navigateToView('employees'),
            ),
            const SizedBox(height: 8),
            if (_viewAllowed('dependents'))
            _buildBusinessActionCard(
              icon: Icons.family_restroom_outlined,
              title: 'hrm_hub.module.dependents_title'.tr(),
              description: 'hrm_hub.module.dependents_desc'.tr(),
              onTap: () => _navigateToView('dependents'),
            ),
            const SizedBox(height: 8),
            if (_viewAllowed('shifts'))
            _buildBusinessActionCard(
              icon: Icons.calendar_month_outlined,
              title: 'hrm_hub.module.shifts_title'.tr(),
              description: 'hrm_hub.module.shifts_desc'.tr(),
              onTap: () => _navigateToView('shifts'),
            ),
            const SizedBox(height: 8),
            if (_caps.pageAllowed('/my-work'))
            _buildBusinessActionCard(
              icon: Icons.access_time,
              title: 'hrm_hub.module.attendance_title'.tr(),
              description: 'hrm_hub.module.attendance_desc'.tr(),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
            ),
            const SizedBox(height: 8),
            if (_viewAllowed('attendance_monitor'))
            _buildBusinessActionCard(
              icon: Icons.insights_rounded,
              title: 'hrm_hub.title.attendance_monitor'.tr(),
              description: 'hrm_hub.module.monitor_desc'.tr(),
              onTap: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceMonitorScreen(
                      onOpenApprovals: () => _navigateToView('approvals'),
                    ),
                  ),
                );
                if (res == 'approvals' && mounted) {
                  _navigateToView('approvals');
                }
              },
            ),
            const SizedBox(height: 8),
            if (_caps.pageAllowed('/leave'))
            _buildBusinessActionCard(
              icon: Icons.beach_access_rounded,
              title: 'hrm_hub.module.leave_title'.tr(),
              description: 'hrm_hub.module.leave_desc'.tr(),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveBalancesScreen())),
            ),
            const SizedBox(height: 8),
            if (_viewAllowed('approvals'))
            _buildBusinessActionCard(
              icon: Icons.assignment_turned_in_outlined,
              title: 'hrm_hub.module.approvals_title'.tr(),
              description: 'hrm_hub.module.approvals_desc'.tr(),
              onTap: () => _navigateToView('approvals'),
            ),
            const SizedBox(height: 8),
            if (_viewAllowed('timesheet'))
            _buildBusinessActionCard(
              icon: Icons.calculate_outlined,
              title: 'hrm_hub.module.timesheet_title'.tr(),
              description: 'hrm_hub.module.timesheet_desc'.tr(),
              onTap: () => _navigateToView('timesheet'),
            ),
            const SizedBox(height: 8),
            if (_viewAllowed('payroll'))
            _buildBusinessActionCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'hrm_hub.title.payroll'.tr(),
              description: 'hrm_hub.module.payroll_desc'.tr(),
              onTap: () => _navigateToView('payroll'),
            ),
            const SizedBox(height: 8),
            if (_viewAllowed('advances'))
            _buildBusinessActionCard(
              icon: Icons.price_change_outlined,
              title: 'hrm_hub.title.advances'.tr(),
              description: 'hrm_hub.module.advances_desc'.tr(),
              onTap: () => _navigateToView('advances'),
            ),
            const SizedBox(height: 8),
            if (_viewAllowed('config'))
            _buildBusinessActionCard(
              icon: Icons.tune_rounded,
              title: 'hrm_hub.module.config_title'.tr(),
              description: 'hrm_hub.module.config_desc'.tr(),
              onTap: () => _navigateToView('config'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required Color iconColor, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildWebStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessActionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF334155)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }


  // ==========================================
  // 2. LỊCH & THÔNG BÁO (SCHEDULE)
  // ==========================================
  Widget _buildScheduleView() {
    return HrmScheduleManagementView(
      hrmService: _hrmService,
      shifts: _shifts,
      employees: _employees,
    );
  }

  // ==========================================
  // 3. NGƯỜI PHỤ THUỘC (DEPENDENTS)
  // ==========================================
  Widget _buildDependentsView() {
    return HrmDependentsView(
      dependents: _dependents,
      formatCurrency: _formatCurrency,
      formatDate: _formatDate,
      onAddDependent: () {
        HrmProfileModals.showAddDependentModal(
          context,
          onAdded: (_) => _loadAllHrmData(),
        );
      },
    );
  }

  // ==========================================
  // 4. BẢNG CÔNG & DỮ LIỆU CHẤM CÔNG (TIMESHEET)
  // ==========================================
  Widget _buildTimesheetSummaryView() {
    return HrmTimesheetSummaryView(
      attendanceService: _attendanceService,
      employees: _employees,
      initialBoard: _enterpriseTimesheetBoard,
      onRefreshData: _loadAllHrmData,
    );
  }

  // ==========================================
  // 5. ỨNG & THU HỒI LƯƠNG (SALARY ADVANCES)
  // ==========================================
  Widget _buildSalaryAdvancesView() {
    return HrmSalaryAdvancesStandaloneView(
      advances: _advances,
      formatCurrency: _formatCurrency,
    );
  }

  // ==========================================
  // 6. TRUNG TÂM CẤU HÌNH HRM (HRM CONFIG CENTER)
  // ==========================================
  Widget _buildHrmConfigCenterView() {
    return _configSubTab == 'OVERVIEW'
        ? HrmConfigOverviewView(
            onRefresh: _loadAllHrmData,
            onSelectConfigItem: (subTabKey) {
              setState(() => _configSubTab = subTabKey);
            },
          )
        : _buildHrmConfigDedicatedSubView();
  }

  Widget _buildHrmConfigDedicatedSubView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breadcrumbs with Back button
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _configSubTab = 'OVERVIEW'),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back_ios_rounded, size: 12, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text('hrm_hub.config.overview'.tr(), style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      _getConfigSubTabSubtitle(),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Sub-view Body
                if (_configSubTab == 'LEAVE') HrmLeavePolicyConfigView(hrmService: _hrmService),
                if (_configSubTab == 'POLICY') HrmAttendancePolicyConfigView(
                  policyVersions: _policyVersions,
                  hrmService: _hrmService,
                  onRefreshData: _loadAllHrmData,
                ),
                if (_configSubTab == 'HOLIDAYS') HrmWorkCalendarConfigView(
                  calendarExceptions: _calendarExceptions,
                  onNavigateToSubTab: (subTab) => setState(() => _configSubTab = subTab),
                ),
                if (_configSubTab == 'GPS') HrmGpsLocationsConfigView(
                  gpsSites: _gpsSites,
                  hrmService: _hrmService,
                  onRefreshGpsSites: _refreshGpsSites,
                ),
                if (_configSubTab == 'DEVICES') HrmHardwareDevicesConfigView(
                  devices: _devices,
                  onSyncDevices: _syncIntegrationDevices,
                ),
                if (_configSubTab == 'AUTO') HrmAutoAttendanceConfigView(
                  enabled: _autoAttendanceEnabled,
                  effectiveFrom: _autoAttendanceEffectiveFrom,
                  activeDays: _autoAttendanceActiveDays,
                  isSaving: _isSavingAutoAttendance,
                  onToggleEnabled: (v) => setState(() => _autoAttendanceEnabled = v),
                  onToggleDay: _toggleAutoAttendanceDay,
                  onSave: _saveAutoAttendanceSettings,
                ),
                if (_configSubTab == 'SHIFTS_ASSIGN') _buildShiftsManagementView(),
                if (_configSubTab == 'SHIFTS') HrmShiftsCatalogConfigView(
                  shifts: _shifts,
                  onOpenModal: () => HrmShiftsModals.showShiftsCatalogModal(context),
                ),
                if (_configSubTab == 'STANDARD') HrmStandardWorkdaysConfigView(
                  onOpenModal: () => HrmShiftsModals.showStandardWorkdaysModal(context),
                ),
                if (_configSubTab == 'REQUEST_TYPES') const HrmRequestTypesReasonsView(),
                if (_configSubTab == 'APPROVAL_FLOWS') const HrmApprovalFlowsConfigView(),
                if (_configSubTab == 'PAYROLL_CFG') HrmPayrollSettingsConfigView(
                  onOpenPayroll: () => _navigateToView('payroll'),
                ),
                if (_configSubTab == 'OPERATIONS') HrmSystemIntegrationsConfigView(
                  devices: _devices,
                  onSyncDevices: _syncIntegrationDevices,
                ),
                if (_configSubTab == 'PERMISSIONS') const HrmPermissionsConfigView(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _syncIntegrationDevices() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('hrm_hub.sync_devices'.tr()), backgroundColor: Color(0xFF2563EB)),
    );
  }

  bool _autoAttendanceEnabled = true;
  final String _autoAttendanceEffectiveFrom = '01/01/2026';
  final Set<int> _autoAttendanceActiveDays = {1, 2, 3, 4, 5};
  bool _isSavingAutoAttendance = false;

  void _toggleAutoAttendanceDay(int dayNumber, bool selected) {
    setState(() {
      if (selected) {
        _autoAttendanceActiveDays.add(dayNumber);
      } else {
        _autoAttendanceActiveDays.remove(dayNumber);
      }
    });
  }

  void _saveAutoAttendanceSettings() {
    setState(() => _isSavingAutoAttendance = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isSavingAutoAttendance = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('hrm_hub.auto_saved'.tr()), backgroundColor: Color(0xFF059669)),
        );
      }
    });
  }

  // ==========================================
  // 7. HỆ THỐNG & TÍCH HỢP (INTEGRATIONS)
  // ==========================================
  Widget _buildSystemIntegrationsView() {
    return HrmSystemIntegrationsConfigView(
      devices: _devices,
      onSyncDevices: _syncIntegrationDevices,
    );
  }

  // ==========================================
  // 8. NHÂN SỰ & CHỨC DANH (EMPLOYEES DIRECTORY)
  // ==========================================
  Widget _buildEmployeesDirectoryView() {
    return HrmEmployeesDirectoryView(
      employees: _employees,
      positions: _positions,
      onRefreshData: _loadAllHrmData,
    );
  }

  // ==========================================
  // 9. QUẢN LÝ CA & CHẤM CÔNG (SHIFTS)
  // ==========================================
  Widget _buildShiftsManagementView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('hrm_screens.shifts.catalog_title'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Text('hrm_hub.shifts.subtitle'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _shifts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final s = _shifts[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.schedule_rounded, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('hrm_hub.shifts.line'.tr(args: {'start': s.startTime, 'end': s.endTime, 'minutes': s.breakMinutes}), style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 10. TIỀN LƯƠNG & CHI TRẢ (PAYROLL)
  // ==========================================
  Widget _buildPayrollView() {
    return HrmPayrollView(
      payrollPeriods: _payrollPeriods,
      advances: _advances,
      employees: _employees,
      hrmService: _hrmService,
      onRefreshData: _loadAllHrmData,
      onNavigateToView: _navigateToView,
      formatCurrency: _formatCurrency,
    );
  }

  // ==========================================
  // 11. ĐƠN TỪ CẦN XỬ LÝ (WEB 1:1 APPROVALS)
  // ==========================================
  Widget _buildRequestsTab() {
    return HrmApprovalsView(
      requests: _requests,
      hrmService: _hrmService,
      onRefreshData: _loadAllHrmData,
      formatCurrency: _formatCurrency,
      formatDate: _formatDate,
      formatTime: _formatTime,
    );
  }

  Widget _buildApprovalsTab() => _buildRequestsTab();
}
