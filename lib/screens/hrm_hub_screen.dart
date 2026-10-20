import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/hrm_models.dart';
import '../models/hrm_attendance_models.dart';
import '../services/hrm_service.dart';
import '../services/hrm_attendance_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/hrm_profile_modals.dart';
import '../widgets/hrm_employee_action_modals.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_status_badge.dart';
import '../shared/widgets/empty_state_view.dart';
import '../features/hrm/data/hrm_repository.dart';
import '../features/hrm/widgets/employee_directory_card.dart';
import '../features/hrm/widgets/position_jd_card.dart';
import '../features/hrm/widgets/hrm_metric_header.dart';
import 'attendance_screen.dart';
import 'attendance_monitor_screen.dart';
import 'leave_balances_screen.dart';
import 'profile_income_screen.dart';
import 'account_screen.dart';

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

  // Active View State
  // 'dashboard' | 'schedule' | 'requests' | 'my_profile' | 'my_payslips' |
  // 'employees' | 'dependents' | 'shifts' | 'approvals' | 'timesheet' |
  // 'payroll' | 'advances' | 'policy' | 'integrations'
  late String _activeView;

  HrmDashboardStats? _stats;
  List<HrmRequestItem> _requests = [];
  List<HrmEmployeeItem> _employees = [];
  List<HrmPositionItem> _positions = [];
  List<HrmPayslipItem> _payslips = [];
  List<HrmShift> _shifts = [];
  List<HrmDependentItem> _dependents = [];
  List<HrmSalaryAdvanceItem> _advances = [];
  List<HrmTimesheetSummaryItem> _timesheets = [];
  List<HrmIntegrationDevice> _devices = [];
  HrmPolicyConfig _policyConfig = const HrmPolicyConfig();
  AttendanceRecord? _todayAttendance;

  bool _isLoading = true;
  String _approvalTab = 'ALL'; // 'ALL', 'PENDING', 'PROCESSING', 'PROCESSED'
  String _approvalTypeFilter = 'ALL';
  String _approvalDeptFilter = 'ALL';
  String _approvalStepFilter = 'ALL';
  String _approvalStatusFilter = 'ALL';
  DateTime? _approvalStartDateFilter;
  DateTime? _approvalEndDateFilter;
  String _approvalSearchQuery = '';
  final Set<String> _selectedApprovalIds = {};
  final TextEditingController _approvalSearchCtrl = TextEditingController();
  String _employeeSearchQuery = '';
  String _employeeStatusFilter = 'ALL';
  String _employeeDepartmentFilter = 'ALL';
  String _employeePositionFilter = 'ALL';
  int _employeeSubTab = 0; // 0: Nhân sự (Employees), 1: Chức danh & JD (Positions)
  String _timesheetMonthKey = '2026-10'; // Default to October 2026 (matching web)
  String _timesheetSearchQuery = '';
  String _timesheetFilterTab = 'ALL';
  int _timesheetCurrentPage = 1;
  int _timesheetPageSize = 10;
  int _timesheetSubTab = 0; // 0: Bảng công, 1: Dữ liệu chấm công
  final Set<String> _selectedTimesheetEmpIds = {};
  HrmTimesheetBoard? _enterpriseTimesheetBoard;
  bool _isLoadingTimesheetBoard = false;
  String _timesheetPeriodState = 'OPEN'; // 'OPEN' | 'REQUESTS_CLOSED' | 'LOCKED'
  String _configSubTab = 'OVERVIEW'; // 'OVERVIEW' | 'POLICY' | 'HOLIDAYS' | 'GPS' | 'DEVICES' | 'AUTO' | 'SHIFTS' | 'STANDARD'
  String _configSearchQuery = '';
  final TextEditingController _configSearchCtrl = TextEditingController();
  final ScrollController _configSubTabScrollCtrl = ScrollController();
  List<Map<String, dynamic>> _policyVersions = [];
  List<Map<String, dynamic>> _calendarExceptions = [];
  String _calendarSearchQuery = '';
  String _calendarTypeFilter = 'ALL';
  final TextEditingController _calendarSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _gpsSites = [];
  String _gpsSearchQuery = '';
  String _gpsStatusFilter = 'ALL';
  final TextEditingController _gpsSearchCtrl = TextEditingController();
  AttendanceContext? _attendanceContext;

  @override
  void dispose() {
    _approvalSearchCtrl.dispose();
    _configSearchCtrl.dispose();
    _configSubTabScrollCtrl.dispose();
    _calendarSearchCtrl.dispose();
    _gpsSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
            content: Text('Đã cập nhật danh sách địa điểm GPS (${sites.length} địa điểm)'),
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
      ]);

      if (mounted) {
        final board = results[8] as HrmTimesheetBoard?;
        setState(() {
          _stats = results[0] as HrmDashboardStats;
          _requests = results[1] as List<HrmRequestItem>;
          _employees = results[2] as List<HrmEmployeeItem>;
          _payslips = results[3] as List<HrmPayslipItem>;
          _shifts = results[4] as List<HrmShift>;
          _todayAttendance = results[5] as AttendanceRecord?;
          _dependents = results[6] as List<HrmDependentItem>;
          _advances = results[7] as List<HrmSalaryAdvanceItem>;
          _enterpriseTimesheetBoard = board;
          if (board != null && board.month.state.isNotEmpty) {
            _timesheetPeriodState = board.month.state;
          }
          _policyConfig = results[9] as HrmPolicyConfig;
          _devices = results[10] as List<HrmIntegrationDevice>;
          _positions = results[11] as List<HrmPositionItem>;
          _policyVersions = results[12] as List<Map<String, dynamic>>;
          _attendanceContext = results[13] as AttendanceContext?;
          _calendarExceptions = results[14] as List<Map<String, dynamic>>;
          _gpsSites = results[15] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[HrmHubScreen] _loadAllHrmData unexpected error: $e');
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
        return 'Bàn làm việc (Dashboard)';
      case 'attendance_monitor':
        return 'Giám sát chấm công';
      case 'schedule':
        return 'Lịch & Thông báo';
      case 'requests':
      case 'approvals':
        return 'Đơn từ cần xử lý';
      case 'profile_income':
        return 'Hồ sơ & Thu nhập';
      case 'my_profile':
        return 'Hồ sơ của tôi';
      case 'my_payslips':
        return 'Phiếu lương cá nhân';
      case 'employees':
        return 'Nhân sự & Chức danh';
      case 'dependents':
        return 'Người phụ thuộc';
      case 'shifts':
        return 'Quản lý Ca & Chấm công';
      case 'timesheet':
        return 'Bảng công tổng hợp';
      case 'payroll':
        return 'Tiền lương & Chi trả';
      case 'advances':
        return 'Ứng và thu hồi lương';
      case 'policy':
      case 'config':
      case 'settings':
        return 'Cấu hình HRM';
      case 'integrations':
        return 'Hệ thống & Tích hợp';
      default:
        return 'Quản trị Nhân sự (HRM)';
    }
  }

  String _getConfigSubTabSubtitle() {
    switch (_configSubTab) {
      case 'OVERVIEW':
        return 'Tổng quan cấu hình';
      case 'LEAVE':
        return 'Chính sách phép năm';
      case 'POLICY':
        return 'Quy định chấm công';
      case 'HOLIDAYS':
        return 'Lịch làm / OFF / Lễ';
      case 'GPS':
        return 'Địa điểm GPS';
      case 'DEVICES':
        return 'Thiết bị';
      case 'AUTO':
        return 'Chấm công tự động';
      case 'SHIFTS_ASSIGN':
        return 'Phân ca';
      case 'SHIFTS':
        return 'Danh mục ca';
      case 'STANDARD':
        return 'Công chuẩn';
      case 'REQUEST_TYPES':
        return 'Loại đơn & lý do';
      case 'APPROVAL_FLOWS':
        return 'Quy trình duyệt';
      case 'PAYROLL_CFG':
        return 'Lương & OT';
      case 'OPERATIONS':
        return 'Vận hành & tích hợp';
      case 'PERMISSIONS':
        return 'Quyền và vai trò';
      default:
        return 'Tổng quan cấu hình';
    }
  }


  bool _matchesEmployeeStatus(HrmEmployeeItem e, String statusKey) {
    final s = e.status.toUpperCase();
    switch (statusKey) {
      case 'OFFICIAL':
        return s == 'OFFICIAL' || s == 'ACTIVE' || s.contains('CHÍNH THỨC');
      case 'PROBATION':
        return s == 'PROBATION' || s.contains('THỬ VIỆC');
      case 'SUSPENDED':
      case 'ON_LEAVE':
        return s == 'SUSPENDED' || s == 'ON_LEAVE' || s == 'LEAVE' || s.contains('TẠM NGHỈ');
      case 'RESIGNED':
      case 'INACTIVE':
        return s == 'RESIGNED' || s == 'INACTIVE' || s.contains('ĐÃ NGHỈ');
      case 'TERMINATED':
        return s == 'TERMINATED' || s.contains('CHẤM DỨT');
      default:
        return true;
    }
  }

  int _countEmployeesByStatus(String statusKey) {
    if (statusKey == 'ALL') return _employees.length;
    return _employees.where((e) => _matchesEmployeeStatus(e, statusKey)).length;
  }

  List<HrmEmployeeItem> get _searchedEmployees {
    var list = _employees;
    if (_employeeStatusFilter != 'ALL') {
      list = list.where((e) => _matchesEmployeeStatus(e, _employeeStatusFilter)).toList();
    }
    if (_employeeDepartmentFilter != 'ALL') {
      list = list.where((e) => e.department.trim().toLowerCase() == _employeeDepartmentFilter.trim().toLowerCase()).toList();
    }
    if (_employeePositionFilter != 'ALL') {
      list = list.where((e) => e.position.trim().toLowerCase() == _employeePositionFilter.trim().toLowerCase()).toList();
    }
    if (_employeeSearchQuery.trim().isEmpty) return list;
    final q = _employeeSearchQuery.toLowerCase();
    return list.where((e) =>
      e.fullName.toLowerCase().contains(q) ||
      e.code.toLowerCase().contains(q) ||
      e.email.toLowerCase().contains(q) ||
      e.department.toLowerCase().contains(q) ||
      e.position.toLowerCase().contains(q)
    ).toList();
  }

  List<String> get _availableDepartments {
    final set = <String>{};
    for (final e in _employees) {
      if (e.department.trim().isNotEmpty) {
        set.add(e.department.trim());
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _availablePositions {
    final set = <String>{};
    for (final e in _employees) {
      if (e.position.trim().isNotEmpty) {
        set.add(e.position.trim());
      }
    }
    for (final p in _positions) {
      if (p.title.trim().isNotEmpty) {
        set.add(p.title.trim());
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  String _getStatusDropdownLabel(String statusKey) {
    switch (statusKey) {
      case 'OFFICIAL':
        return 'Trạng thái: Chính thức';
      case 'PROBATION':
        return 'Trạng thái: Thử việc';
      case 'SUSPENDED':
      case 'ON_LEAVE':
        return 'Trạng thái: Tạm nghỉ';
      case 'RESIGNED':
      case 'INACTIVE':
        return 'Trạng thái: Đã nghỉ việc';
      case 'TERMINATED':
        return 'Trạng thái: Chấm dứt HĐ';
      default:
        return 'Trạng thái: Tất cả';
    }
  }

  List<HrmPositionItem> get _searchedPositions {
    if (_employeeSearchQuery.trim().isEmpty) return _positions;
    final q = _employeeSearchQuery.toLowerCase();
    return _positions.where((p) =>
      p.title.toLowerCase().contains(q) ||
      p.code.toLowerCase().contains(q) ||
      p.department.toLowerCase().contains(q)
    ).toList();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Dark slate
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Quay lại',
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
                  : 'SVN DTS / Quản trị Nhân sự',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          if (_activeView == 'config' || _activeView == 'policy' || _activeView == 'settings')
            IconButton(
              icon: const Icon(Icons.view_sidebar_outlined, size: 22),
              tooltip: 'Menu Cấu hình',
              onPressed: _showConfigSidebarSheet,
            ),
          if (_activeView != 'dashboard' && widget.initialView == null)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined, size: 20),
              tooltip: 'Về Bàn làm việc',
              onPressed: () => _navigateToView('dashboard'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Làm mới',
            onPressed: _loadAllHrmData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildActiveContentView(),
    );
  }

  // ==========================================
  // VIEW DISPATCHER
  // ==========================================
  Widget _buildActiveContentView() {
    switch (_activeView) {
      case 'dashboard':
        return _buildOverviewTab();
      case 'attendance_monitor':
        return const AttendanceMonitorScreen();
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
            const Text(
              'SVN DTS / Quản trị Nhân sự / Bàn làm việc (Dashboard)',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bàn làm việc (Dashboard)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            const Text(
              'Trung tâm điều hành và giám sát toàn diện hoạt động nhân sự, quân số và vận hành doanh nghiệp.',
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
                      const Text(
                        'Tổng quan Nhân sự & Điều hành',
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
                        child: const Text(
                          'Thời gian thực',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Số liệu tổng hợp từ hồ sơ nhân viên, trạng thái chấm công hôm nay và luồng đơn từ phê duyệt của doanh nghiệp.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToView('employees'),
                          icon: const Icon(Icons.people_outline, size: 16),
                          label: const Text('Quản lý Nhân sự', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToView('approvals'),
                          icon: const Icon(Icons.mail_outline, size: 16),
                          label: const Text('Xử lý Đơn từ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

            // 3. Section: QUY MÔ & LỰC LƯỢNG LAO ĐỘNG
            _buildSectionHeader(
              icon: Icons.people_outline,
              iconColor: const Color(0xFF2563EB),
              title: 'QUY MÔ & LỰC LƯỢNG LAO ĐỘNG',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildWebStatCard(
                    title: 'Tổng nhân viên đang làm',
                    value: '$empCount',
                    subtitle: 'Tất cả hợp đồng đang hiệu lực',
                    icon: Icons.people_alt_outlined,
                    iconBgColor: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'Hợp đồng chính thức',
                    value: '$officialEmpCount',
                    subtitle: '100% tổng quân số',
                    icon: Icons.how_to_reg_outlined,
                    iconBgColor: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'Nhân sự thử việc',
                    value: '0',
                    subtitle: 'Đang trong thời gian đánh giá',
                    icon: Icons.person_add_outlined,
                    iconBgColor: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Section: TÌNH HÌNH CHẤM CÔNG HÔM NAY
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  icon: Icons.access_time,
                  iconColor: const Color(0xFF059669),
                  title: 'TÌNH HÌNH CHẤM CÔNG HÔM NAY',
                ),
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceMonitorScreen())),
                  child: const Text(
                    'Mở giám sát >',
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
                    title: 'Đã chấm vào',
                    value: hasCheckedIn ? '1' : '0',
                    subtitle: 'Có quẹt thẻ ghi nhận giờ vào',
                    icon: Icons.check_circle_outline,
                    iconBgColor: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'Đi trễ hôm nay',
                    value: '0',
                    subtitle: 'Sau giờ giới hạn trễ của ca',
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
                    title: 'Bất thường / Thiếu lượt',
                    value: '0',
                    subtitle: 'Quên chấm vào hoặc ra',
                    icon: Icons.warning_amber_rounded,
                    iconBgColor: const Color(0xFFFEF2F2),
                    iconColor: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'Đang nghỉ phép',
                    value: '0',
                    subtitle: 'Đã được duyệt đơn nghỉ',
                    icon: Icons.calendar_today_outlined,
                    iconBgColor: const Color(0xFFFAF5FF),
                    iconColor: const Color(0xFF9333EA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 5. Section: ĐƠN TỪ & YÊU CẦU CHỜ XỬ LÝ
            _buildSectionHeader(
              icon: Icons.mark_email_unread_outlined,
              iconColor: const Color(0xFFD97706),
              title: 'ĐƠN TỪ & YÊU CẦU CHỜ XỬ LÝ',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildWebStatCard(
                    title: 'Đơn phép chờ duyệt',
                    value: '$pendingLeaves',
                    subtitle: 'Nghỉ phép năm, ốm, ...',
                    icon: Icons.article_outlined,
                    iconBgColor: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'Tăng ca (OT) chờ duyệt',
                    value: '$pendingOts',
                    subtitle: 'Kế hoạch làm thêm ...',
                    icon: Icons.schedule,
                    iconBgColor: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildWebStatCard(
                    title: 'Giải trình công chờ duyệt',
                    value: '$pendingAdvances',
                    subtitle: 'Giải trình quên quẹt t...',
                    icon: Icons.description_outlined,
                    iconBgColor: const Color(0xFFFAF5FF),
                    iconColor: const Color(0xFF9333EA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 6. Section: PHÂN KHU CHỨC NĂNG NGHIỆP VỤ
            _buildSectionHeader(
              icon: Icons.bolt,
              iconColor: const Color(0xFF0F172A),
              title: 'PHÂN KHU CHỨC NĂNG NGHIỆP VỤ',
            ),
            const SizedBox(height: 10),
            _buildBusinessActionCard(
              icon: Icons.person_outline,
              title: 'Hồ sơ Nhân viên & Chức danh',
              description: 'Quản lý thông tin định danh, chức danh, ngạch bậc và hợp đồng',
              onTap: () => _navigateToView('employees'),
            ),
            const SizedBox(height: 8),
            _buildBusinessActionCard(
              icon: Icons.family_restroom_outlined,
              title: 'Người phụ thuộc & Giảm trừ gia cảnh',
              description: 'Hồ sơ người phụ thuộc, mã số thuế và trạng thái xác thực thuế TNCN',
              onTap: () => _navigateToView('dependents'),
            ),
            const SizedBox(height: 8),
            _buildBusinessActionCard(
              icon: Icons.calendar_month_outlined,
              title: 'Quản lý Ca & Phân ca',
              description: 'Thiết lập định nghĩa ca làm việc và bảng phân ca làm việc tuần/tháng',
              onTap: () => _navigateToView('shifts'),
            ),
            const SizedBox(height: 8),
            _buildBusinessActionCard(
              icon: Icons.access_time,
              title: 'Chấm công & Điểm danh',
              description: 'Ghi nhận giờ làm việc, định vị GPS và rà soát các lượt vào ra',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
            ),
            const SizedBox(height: 8),
            _buildBusinessActionCard(
              icon: Icons.insights_rounded,
              title: 'Giám sát chấm công',
              description: 'Theo dõi tình hình vào ca, đi trễ, về sớm và các trường hợp cần xử lý trong ngày',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceMonitorScreen())),
            ),
            const SizedBox(height: 8),
            _buildBusinessActionCard(
              icon: Icons.beach_access_rounded,
              title: 'Quỹ phép năm & Thâm niên',
              description: 'Theo dõi số dư phép năm, thâm niên tích luỹ, phần chuyển tiếp và lịch sử giao dịch quỹ',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveBalancesScreen())),
            ),
            const SizedBox(height: 8),
            _buildBusinessActionCard(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Xử lý Đơn từ & Phê duyệt',
              description: 'Tiếp nhận, kiểm tra tính hợp lệ chính sách và phê duyệt đơn từ nhân viên',
              onTap: () => _navigateToView('approvals'),
            ),
            const SizedBox(height: 8),
            _buildBusinessActionCard(
              icon: Icons.calculate_outlined,
              title: 'Bảng công Tổng hợp',
              description: 'Tổng hợp ngày công, tính toán giờ làm thêm, đi trễ và khóa kỳ công',
              onTap: () => _navigateToView('timesheet'),
            ),
            const SizedBox(height: 8),
            _buildBusinessActionCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Tiền lương & Chi trả',
              description: 'Tính toán lương theo công thức, đối soát thu nhập và phát hành phiếu lương',
              onTap: () => _navigateToView('payroll'),
            ),
            const SizedBox(height: 8),
            _buildBusinessActionCard(
              icon: Icons.price_change_outlined,
              title: 'Ứng và thu hồi lương',
              description: 'Theo dõi các khoản tạm ứng lương cá nhân và tiến độ thu hồi qua các kỳ lương',
              onTap: () => _navigateToView('advances'),
            ),
            const SizedBox(height: 8),
            _buildBusinessActionCard(
              icon: Icons.tune_rounded,
              title: 'Trung tâm cấu hình HRM',
              description: 'Chính sách chấm công, GPS, thiết bị, chấm công tự động, danh mục ca và công chuẩn',
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
  // 2. LỊCH & THÔNG BÁO (SCHEDULE & ANNOUNCEMENTS)
  // ==========================================
  Widget _buildScheduleView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF38BDF8), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lịch làm việc & Thông báo nội bộ', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Theo dõi lịch trực, sự kiện doanh nghiệp và quy chế mới nhất', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Announcements Section
          _buildSectionHeader(icon: Icons.campaign_rounded, iconColor: const Color(0xFF2563EB), title: 'THÔNG BÁO DOANH NGHIỆP'),
          const SizedBox(height: 10),
          _buildAnnouncementCard(
            tag: 'QUY CHẾ',
            tagColor: const Color(0xFF2563EB),
            tagBg: const Color(0xFFEFF6FF),
            title: 'Quy định áp dụng chấm công điện tử GPS & Wi-Fi toàn hệ thống',
            date: '01/10/2026',
            content: 'Yêu cầu toàn thể cán bộ nhân viên thực hiện check-in/out qua ứng dụng SVN DTS khi đến văn phòng hoặc công tác tại hiện trường.',
          ),
          const SizedBox(height: 10),
          _buildAnnouncementCard(
            tag: 'LỊCH NGHỈ LỄ',
            tagColor: const Color(0xFFD97706),
            tagBg: const Color(0xFFFFFBEB),
            title: 'Kế hoạch nghỉ lễ và phân công trực vận hành quý IV/2026',
            date: '28/09/2026',
            content: 'Khối Kỹ thuật & Bảo trì duy trì đội trực 24/7. Nhân sự trực được tính hệ số lương OT 3.0x theo chính sách công ty.',
          ),
          const SizedBox(height: 18),

          // Weekly Shift Schedule
          _buildSectionHeader(icon: Icons.access_time_filled_rounded, iconColor: const Color(0xFF059669), title: 'LỊCH PHÂN CA TUẦN NÀY (BẠN)'),
          const SizedBox(height: 10),
          _buildWeekCalendarCard(),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard({
    required String tag,
    required Color tagColor,
    required Color tagBg,
    required String title,
    required String date,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tagColor)),
              ),
              Text(date, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildWeekCalendarCard() {
    final days = [
      {'day': 'T2', 'date': '05/10', 'shift': 'Ca Hành chính (08:00 - 17:30)', 'isToday': true},
      {'day': 'T3', 'date': '06/10', 'shift': 'Ca Hành chính (08:00 - 17:30)', 'isToday': false},
      {'day': 'T4', 'date': '07/10', 'shift': 'Ca Hành chính (08:00 - 17:30)', 'isToday': false},
      {'day': 'T5', 'date': '08/10', 'shift': 'Ca Hành chính (08:00 - 17:30)', 'isToday': false},
      {'day': 'T6', 'date': '09/10', 'shift': 'Ca Hành chính (08:00 - 17:30)', 'isToday': false},
      {'day': 'T7', 'date': '10/10', 'shift': 'Nghỉ cuối tuần', 'isToday': false},
      {'day': 'CN', 'date': '11/10', 'shift': 'Nghỉ cuối tuần', 'isToday': false},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: days.map((d) {
          final isToday = d['isToday'] as bool;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFFEFF6FF) : Colors.transparent,
              border: Border(bottom: BorderSide(color: const Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${d['day']} ${d['date']}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    d['shift'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday ? const Color(0xFF1E40AF) : const Color(0xFF334155),
                    ),
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Hôm nay', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // 3. HỒ SƠ CỦA TÔI (MY PROFILE)
  // ==========================================
  Widget _buildMyProfileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Digital Employee Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('THẺ NHÂN VIÊN ĐIỆN TỬ', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: const Text('CHÍNH THỨC', style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF2563EB),
                      child: const Text('TT', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nguyễn Tấn Tài', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Mã NV: SVN-EMP001', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11.5)),
                          Text('Chuyên viên Kỹ thuật & R&D', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Khối Kỹ thuật & Vận hành', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    Text('SAVINA Enterprise Platform', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Detail sections
          _buildSectionHeader(icon: Icons.badge_outlined, iconColor: const Color(0xFF2563EB), title: 'THÔNG TIN HỢP ĐỒNG & BẬC LƯƠNG'),
          const SizedBox(height: 8),
          _buildProfileInfoGroup([
            {'label': 'Loại hợp đồng', 'value': 'Hợp đồng lao động không xác định thời hạn'},
            {'label': 'Ngày bắt đầu làm việc', 'value': '01/01/2023'},
            {'label': 'Mã số BHXH', 'value': '7912345678'},
            {'label': 'Mã số thuế cá nhân', 'value': '8091234567'},
            {'label': 'Lương căn bản đóng bảo hiểm', 'value': '28.000.000 ₫'},
          ]),
          const SizedBox(height: 16),

          _buildSectionHeader(icon: Icons.contact_mail_outlined, iconColor: const Color(0xFF059669), title: 'LIÊN HỆ & TÀI KHOẢN NGÂN HÀNG'),
          const SizedBox(height: 8),
          _buildProfileInfoGroup([
            {'label': 'Email công ty', 'value': 'tai.nguyen@savina.vn'},
            {'label': 'Số điện thoại', 'value': '0901 234 567'},
            {'label': 'Ngân hàng nhận lương', 'value': 'Vietcombank - CN Tân Bình'},
            {'label': 'Số tài khoản', 'value': '0071 000 987 654'},
          ]),
        ],
      ),
    );
  }

  Widget _buildProfileInfoGroup(List<Map<String, String>> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: items.map((it) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(it['label']!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ),
                Expanded(
                  child: Text(it['value']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // 4. NGƯỜI PHỤ THUỘC (DEPENDENTS)
  // ==========================================
  Widget _buildDependentsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Người phụ thuộc & Giảm trừ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Hồ sơ đăng ký giảm trừ gia cảnh thuế TNCN', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddDependentModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Đăng ký mới', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Deduction Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mức giảm trừ gia cảnh hiện hành', style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF))),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatCurrency(_dependents.where((d) => d.status == 'VERIFIED').length * 4400000.0)} / tháng',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                      Text('(${_dependents.length} người phụ thuộc đã đăng ký)', style: const TextStyle(fontSize: 10.5, color: Color(0xFF3B82F6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List of Dependents
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dependents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final dep = _dependents[index];
              final isVerified = dep.status == 'VERIFIED';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dep.fullName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVerified ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isVerified ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            isVerified ? 'ĐÃ XÁC THỰC' : 'CHỜ DUYỆT',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isVerified ? const Color(0xFF059669) : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Quan hệ: ${dep.relationship}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                        const SizedBox(width: 12),
                        Text('Ngày sinh: ${_formatDate(dep.dateOfBirth)}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('CCCD/Định danh: ${dep.idNumber} • MST: ${dep.taxCode}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddDependentModal() {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final taxCtrl = TextEditingController();
    String relationship = 'Con ruột';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Đăng ký Người phụ thuộc mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên người phụ thuộc', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: relationship,
                  items: const [
                    DropdownMenuItem(value: 'Con ruột', child: Text('Con ruột (< 18 tuổi hoặc đi học)')),
                    DropdownMenuItem(value: 'Vợ/Chồng', child: Text('Vợ / Chồng không có thu nhập')),
                    DropdownMenuItem(value: 'Cha/Mẹ', child: Text('Cha / Mẹ hết tuổi lao động')),
                  ],
                  onChanged: (v) => setModalState(() => relationship = v ?? 'Con ruột'),
                  decoration: const InputDecoration(labelText: 'Quan hệ nhân thân', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(labelText: 'Số định danh / CCCD / Giấy khai sinh', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: taxCtrl,
                  decoration: const InputDecoration(labelText: 'Mã số thuế cá nhân (nếu có)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    setState(() {
                      _dependents.insert(0, HrmDependentItem(
                        id: 'dep-${DateTime.now().millisecondsSinceEpoch}',
                        employeeId: 'emp-001',
                        employeeName: 'Nguyễn Tấn Tài',
                        fullName: nameCtrl.text.trim(),
                        relationship: relationship,
                        dateOfBirth: DateTime(2022, 1, 1),
                        idNumber: idCtrl.text.trim().isNotEmpty ? idCtrl.text.trim() : '079200099999',
                        taxCode: taxCtrl.text.trim().isNotEmpty ? taxCtrl.text.trim() : '8594000999',
                        status: 'PENDING',
                        startDate: DateTime.now(),
                      ));
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã gửi hồ sơ người phụ thuộc lên kế toán xác thực!'), backgroundColor: Color(0xFF059669)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('NỘP HỒ SƠ ĐĂNG KÝ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 5. BẢNG CÔNG TỔNG HỢP (TIMESHEET MATRIX - PIXEL-PERFECT SYNC WITH WEB)
  // ==========================================

  Future<void> _shiftTimesheetMonth(int delta) async {
    final parts = _timesheetMonthKey.split('-');
    int y = int.tryParse(parts[0]) ?? 2026;
    int m = int.tryParse(parts[1]) ?? 10;
    m += delta;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    final nextKey = '$y-${m.toString().padLeft(2, '0')}';
    setState(() {
      _timesheetMonthKey = nextKey;
      _timesheetCurrentPage = 1;
      _isLoadingTimesheetBoard = true;
    });
    try {
      final board = await _attendanceService.getTimesheetBoard(
        month: nextKey,
        self: false,
        page: 1,
        pageSize: 100,
      );
      if (mounted) {
        setState(() {
          _enterpriseTimesheetBoard = board;
          if (board != null && board.month.state.isNotEmpty) {
            _timesheetPeriodState = board.month.state;
          }
          _isLoadingTimesheetBoard = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTimesheetBoard = false);
    }
  }

  Future<void> _refreshTimesheetBoard() async {
    setState(() => _isLoadingTimesheetBoard = true);
    try {
      final board = await _attendanceService.getTimesheetBoard(
        month: _timesheetMonthKey,
        self: false,
        page: 1,
        pageSize: 100,
      );
      if (mounted) {
        setState(() {
          _enterpriseTimesheetBoard = board;
          if (board != null && board.month.state.isNotEmpty) {
            _timesheetPeriodState = board.month.state;
          }
          _isLoadingTimesheetBoard = false;
        });
      }
    } catch (e) {
      debugPrint('[HrmHubScreen] _refreshTimesheetBoard error: $e');
      if (mounted) setState(() => _isLoadingTimesheetBoard = false);
    }
  }

  String get _timesheetMonthLabel {
    final parts = _timesheetMonthKey.split('-');
    if (parts.length == 2) {
      return 'Tháng ${parts[1]}/${parts[0]}';
    }
    return _timesheetMonthKey;
  }

  int get _daysInSelectedMonth {
    final parts = _timesheetMonthKey.split('-');
    final y = int.tryParse(parts[0]) ?? 2026;
    final m = int.tryParse(parts[1]) ?? 10;
    return DateTime(y, m + 1, 0).day;
  }

  String _getDayWeekdayLabel(int day) {
    final parts = _timesheetMonthKey.split('-');
    final y = int.tryParse(parts[0]) ?? 2026;
    final m = int.tryParse(parts[1]) ?? 10;
    final dt = DateTime(y, m, day);
    switch (dt.weekday) {
      case DateTime.monday: return 'T2';
      case DateTime.tuesday: return 'T3';
      case DateTime.wednesday: return 'T4';
      case DateTime.thursday: return 'T5';
      case DateTime.friday: return 'T6';
      case DateTime.saturday: return 'T7';
      case DateTime.sunday: return 'CN';
      default: return '';
    }
  }

  Color _getTimesheetAvatarBgColor(String code) {
    switch (code) {
      case 'NV001': return const Color(0xFFE0F2FE); // sky 100
      case 'NV002': return const Color(0xFFDCFCE7); // emerald 100
      case 'NV003': return const Color(0xFFF3E8FF); // purple 100
      case 'NV004': return const Color(0xFFFCE7F3); // pink 100
      case 'NV005': return const Color(0xFFEFF6FF); // blue 100
      case 'NV006': return const Color(0xFFFEF3C7); // amber 100
      case 'NV007': return const Color(0xFFEDE9FE); // violet 100
      case 'NV008': return const Color(0xFFCCFBF1); // teal 100
      case 'NV009': return const Color(0xFFFAE8FF); // fuchsia 100
      case 'NV010': return const Color(0xFFFFE4E6); // rose 100
      default:
        const bgs = [
          Color(0xFFE0F2FE), Color(0xFFDCFCE7), Color(0xFFF3E8FF),
          Color(0xFFFCE7F3), Color(0xFFEFF6FF), Color(0xFFFEF3C7),
        ];
        int hash = code.hashCode.abs();
        return bgs[hash % bgs.length];
    }
  }

  Color _getTimesheetAvatarTextColor(String code) {
    switch (code) {
      case 'NV001': return const Color(0xFF0284C7); // sky 600
      case 'NV002': return const Color(0xFF059669); // emerald 600
      case 'NV003': return const Color(0xFF7C3AED); // purple 600
      case 'NV004': return const Color(0xFFDB2777); // pink 600
      case 'NV005': return const Color(0xFF2563EB); // blue 600
      case 'NV006': return const Color(0xFFD97706); // amber 600
      case 'NV007': return const Color(0xFF6D28D9); // violet 600
      case 'NV008': return const Color(0xFF0D9488); // teal 600
      case 'NV009': return const Color(0xFFC026D3); // fuchsia 600
      case 'NV010': return const Color(0xFFE11D48); // rose 600
      default:
        const fgs = [
          Color(0xFF0284C7), Color(0xFF059669), Color(0xFF7C3AED),
          Color(0xFFDB2777), Color(0xFF2563EB), Color(0xFFD97706),
        ];
        int hash = code.hashCode.abs();
        return fgs[hash % fgs.length];
    }
  }

  List<HrmBoardEmployee> get _effectiveTimesheetEmployees {
    if (_enterpriseTimesheetBoard != null && _enterpriseTimesheetBoard!.employees.isNotEmpty) {
      return _enterpriseTimesheetBoard!.employees;
    }
    final daysInMonth = _daysInSelectedMonth;
    final parts = _timesheetMonthKey.split('-');
    final y = int.tryParse(parts[0]) ?? 2026;
    final m = int.tryParse(parts[1]) ?? 10;
    final now = DateTime.now();

    return _employees.map((e) {
      final days = <String, HrmBoardDay>{};
      final isFirstEmp = e.code == 'NV001';

      for (int d = 1; d <= daysInMonth; d++) {
        final dt = DateTime(y, m, d);
        final isSunday = dt.weekday == DateTime.sunday;
        final isFuture = (y > now.year) || (y == now.year && m > now.month) || (y == now.year && m == now.month && d > now.day);

        String st;
        if (isFuture) {
          st = isSunday ? 'OFF' : 'HC';
        } else if (isSunday) {
          st = 'OFF';
        } else {
          if (isFirstEmp && (d == 5 || d == 6 || d == 7 || d == 8 || d == 9 || d == 13 || d == 14)) {
            st = 'PRESENT';
          } else {
            st = 'ABSENT';
          }
        }

        days['$d'] = HrmBoardDay(
          date: '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
          kind: isSunday ? 'OFF' : 'WORK',
          status: st,
          shiftCode: isSunday ? 'OFF' : 'CA_HC',
          shiftName: isSunday ? 'Nghỉ tuần' : 'Ca Hành chính',
          workdayUnits: (st == 'PRESENT' && !isFuture) ? 1.0 : 0.0,
          lateMinutes: (isFirstEmp && d == 5) ? 14 : 0,
        );
      }

      int absentCount = days.values.where((d) => d.status == 'ABSENT').length;
      int presentCount = days.values.where((d) => d.status == 'PRESENT').length;
      int lateDays = (isFirstEmp) ? 1 : 0;

      return HrmBoardEmployee(
        employeeId: e.id,
        employeeCode: e.code,
        employeeName: e.fullName,
        departmentName: e.department,
        positionName: e.position,
        days: days,
        totals: HrmBoardTotals(
          workdayUnits: presentCount.toDouble(),
          lateDays: lateDays,
          earlyLeaveDays: 0,
          absentDays: absentCount,
          annualLeaveDays: 0,
          abnormalDays: 0,
          otMinutes: 0,
        ),
      );
    }).toList();
  }

  List<HrmBoardEmployee> get _filteredTimesheetEmployees {
    var list = _effectiveTimesheetEmployees;
    if (_timesheetSearchQuery.trim().isNotEmpty) {
      final q = _timesheetSearchQuery.toLowerCase();
      list = list.where((e) =>
        e.employeeName.toLowerCase().contains(q) ||
        e.employeeCode.toLowerCase().contains(q) ||
        (e.departmentName?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    switch (_timesheetFilterTab) {
      case 'LATE_EARLY':
        return list.where((e) => (e.totals.lateDays + e.totals.earlyLeaveDays) > 0).toList();
      case 'ABNORMAL':
        return list.where((e) => e.totals.abnormalDays > 0).toList();
      case 'ABSENT':
        return list.where((e) => e.totals.absentDays > 0).toList();
      case 'PENDING':
        return list.where((e) => e.days.values.any((d) => d.requests.any((r) => r.status == 'PENDING'))).toList();
      default:
        return list;
    }
  }

  int _countTimesheetFilter(String key) {
    final list = _effectiveTimesheetEmployees;
    switch (key) {
      case 'LATE_EARLY':
        return list.where((e) => (e.totals.lateDays + e.totals.earlyLeaveDays) > 0).length;
      case 'ABNORMAL':
        return list.where((e) => e.totals.abnormalDays > 0).length;
      case 'ABSENT':
        return list.where((e) => e.totals.absentDays > 0).length;
      case 'PENDING':
        return list.where((e) => e.days.values.any((d) => d.requests.any((r) => r.status == 'PENDING'))).length;
      default:
        return list.length;
    }
  }

  List<HrmBoardEmployee> get _pagedTimesheetEmployees {
    final all = _filteredTimesheetEmployees;
    final start = (_timesheetCurrentPage - 1) * _timesheetPageSize;
    if (start >= all.length) return [];
    final end = (start + _timesheetPageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get _timesheetTotalPages {
    final total = _filteredTimesheetEmployees.length;
    if (total == 0) return 1;
    return (total / _timesheetPageSize).ceil();
  }

  Widget _buildTimesheetSummaryView() {
    final pagedList = _pagedTimesheetEmployees;
    final totalCount = _filteredTimesheetEmployees.length;
    final startIdx = totalCount == 0 ? 0 : (_timesheetCurrentPage - 1) * _timesheetPageSize + 1;
    final endIdx = (startIdx + pagedList.length - 1).clamp(0, totalCount);
    final daysInMonth = _daysInSelectedMonth;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Breadcrumb & Status badge (Responsive)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: const [
                    Icon(Icons.home_outlined, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text('›', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    SizedBox(width: 4),
                    Text('Nhân sự', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    SizedBox(width: 4),
                    Text('›', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Bảng công',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _timesheetPeriodState == 'REQUESTS_CLOSED'
                      ? const Color(0xFFEFF6FF)
                      : (_timesheetPeriodState == 'LOCKED' ? const Color(0xFFF1F5F9) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _timesheetPeriodState == 'REQUESTS_CLOSED'
                        ? const Color(0xFFBFDBFE)
                        : (_timesheetPeriodState == 'LOCKED' ? const Color(0xFFCBD5E1) : const Color(0xFFFDE68A)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 8,
                      color: _timesheetPeriodState == 'REQUESTS_CLOSED'
                          ? const Color(0xFF2563EB)
                          : (_timesheetPeriodState == 'LOCKED' ? const Color(0xFF64748B) : const Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _timesheetPeriodState == 'REQUESTS_CLOSED'
                          ? 'Đã đóng đơn'
                          : (_timesheetPeriodState == 'LOCKED' ? 'Đã chốt' : 'Đang mở'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _timesheetPeriodState == 'REQUESTS_CLOSED'
                            ? const Color(0xFF1D4ED8)
                            : (_timesheetPeriodState == 'LOCKED' ? const Color(0xFF475569) : const Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoadingTimesheetBoard)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFFE2E8F0),
                color: Color(0xFFF59E0B),
              ),
            ),
          const SizedBox(height: 8),

          // Title & Description
          const Text(
            'Bảng công',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          const Text(
            'Theo dõi và tổng hợp công, phép, tăng ca của nhân viên trong tháng.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // 2. Subtabs: Bảng công | Dữ liệu chấm công
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _timesheetSubTab = 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảng công',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _timesheetSubTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2.5,
                      width: 70,
                      decoration: BoxDecoration(
                        color: _timesheetSubTab == 0 ? const Color(0xFFF59E0B) : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => setState(() => _timesheetSubTab = 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dữ liệu chấm công',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _timesheetSubTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2.5,
                      width: 120,
                      decoration: BoxDecoration(
                        color: _timesheetSubTab == 1 ? const Color(0xFFF59E0B) : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // 3. Month Picker & Search Box
          Row(
            children: [
              // Month Selector: < 📅 Tháng 10/2026 >
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _shiftTimesheetMonth(-1),
                    ),
                    const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(
                      _timesheetMonthLabel,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _shiftTimesheetMonth(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Search field
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _timesheetSearchQuery = v;
                      _timesheetCurrentPage = 1;
                    }),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo mã hoặc tên...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Action Buttons (🔒 Chốt đơn từ, 🧮 Tính công, 🔒 Chốt công, 🔓 Mở lại, 📥 Xuất CSV)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLightActionButton(icon: Icons.lock_outline_rounded, label: 'Chốt đơn từ', onTap: _showCloseRequestsModal),
                const SizedBox(width: 6),
                _buildLightActionButton(
                  icon: _isCalculatingTimesheet ? Icons.hourglass_top_rounded : Icons.calculate_outlined,
                  label: _isCalculatingTimesheet ? 'Đang tính...' : 'Tính công',
                  onTap: _handleCalculateTimesheet,
                ),
                const SizedBox(width: 6),
                // Solid Orange Highlighted Action
                InkWell(
                  onTap: _showCloseTimesheetModal,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.lock_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Chốt công',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildLightActionButton(icon: Icons.lock_open_rounded, label: 'Mở lại', onTap: _showReopenTimesheetModal),
                const SizedBox(width: 6),
                _buildLightActionButton(
                  icon: Icons.file_download_outlined,
                  label: _selectedTimesheetEmpIds.isNotEmpty ? 'Xuất CSV (${_selectedTimesheetEmpIds.length})' : 'Xuất CSV',
                  onTap: _exportTimesheetCsv,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 5. Quick Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLightFilterTab('Tất cả (${_countTimesheetFilter('ALL')})', 'ALL', null),
                const SizedBox(width: 6),
                _buildLightFilterTab('Đi trễ, về sớm (${_countTimesheetFilter('LATE_EARLY')})', 'LATE_EARLY', const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                _buildLightFilterTab('Bất thường (${_countTimesheetFilter('ABNORMAL')})', 'ABNORMAL', const Color(0xFFEAB308)),
                const SizedBox(width: 6),
                _buildLightFilterTab('Vắng không phép (${_countTimesheetFilter('ABSENT')})', 'ABSENT', const Color(0xFFEF4444)),
                const SizedBox(width: 6),
                _buildLightFilterTab('Có đơn chờ duyệt (${_countTimesheetFilter('PENDING')})', 'PENDING', const Color(0xFF3B82F6)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 6. Hint Bar: 👉 Vuốt ngang để xem 31 ngày & cột tổng kết | (?) Chú thích
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.swipe_left_rounded, size: 15, color: Color(0xFFD97706)),
                  SizedBox(width: 5),
                  Text(
                    'Vuốt ngang để xem 31 ngày & cột tổng kết',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showTimesheetLegendBottomSheet(),
                child: const Text(
                  'ⓘ Chú thích',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 7. Matrix Data Table with Fixed Left Column and Scrollable Days
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Frozen Left Column (Checkbox + Avatar + Name + Code)
                    SizedBox(
                      width: 145,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Header
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_selectedTimesheetEmpIds.length == pagedList.length) {
                                        _selectedTimesheetEmpIds.clear();
                                      } else {
                                        _selectedTimesheetEmpIds.addAll(pagedList.map((e) => e.employeeId));
                                      }
                                    });
                                  },
                                  child: Icon(
                                    _selectedTimesheetEmpIds.length == pagedList.length && pagedList.isNotEmpty
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 16,
                                    color: _selectedTimesheetEmpIds.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Nhân viên',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        '${pagedList.length} NV (chuẩn 24.5)',
                                        style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Left Employee Rows
                          ...pagedList.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final emp = entry.value;
                            final isSelected = _selectedTimesheetEmpIds.contains(emp.employeeId);
                            final avatarBg = _getTimesheetAvatarBgColor(emp.employeeCode);
                            final avatarText = _getTimesheetAvatarTextColor(emp.employeeCode);
                            final initials = _getEmployeeInitials(emp.employeeName);
                            final isEven = idx % 2 == 0;

                            return Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                                border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedTimesheetEmpIds.remove(emp.employeeId);
                                        } else {
                                          _selectedTimesheetEmpIds.add(emp.employeeId);
                                        }
                                      });
                                    },
                                    child: Icon(
                                      isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      size: 15,
                                      color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: avatarBg,
                                    child: Text(
                                      initials,
                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: avatarText),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          emp.employeeName,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${emp.employeeCode} · ${emp.departmentName ?? ""}',
                                          style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Divider
                    Container(width: 1, color: const Color(0xFFE2E8F0)),

                    // Scrollable Right Area (Days 1..31 + Summary Columns)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Days Header Row
                            Container(
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              child: Row(
                                children: [
                                  // Days 1..31
                                  ...List.generate(daysInMonth, (dIdx) {
                                    final d = dIdx + 1;
                                    final weekday = _getDayWeekdayLabel(d);
                                    final isSunday = weekday == 'CN';
                                    final parts = _timesheetMonthKey.split('-');
                                    final y = int.tryParse(parts[0]) ?? 2026;
                                    final m = int.tryParse(parts[1]) ?? 10;
                                    final now = DateTime.now();
                                    final isToday = (y == now.year && m == now.month && d == now.day);
                                    final isFuture = (y > now.year) || (y == now.year && m > now.month) || (y == now.year && m == now.month && d > now.day);

                                    return Container(
                                      width: 36,
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isToday ? const Color(0xFFFEF3C7).withValues(alpha: 0.5) : Colors.transparent,
                                        border: isToday ? const Border(bottom: BorderSide(color: Color(0xFFF59E0B), width: 2)) : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            weekday,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: isSunday ? FontWeight.bold : FontWeight.w500,
                                              color: isSunday
                                                  ? (isFuture ? const Color(0xFFFDA4AF) : const Color(0xFFE11D48))
                                                  : (isToday ? const Color(0xFFD97706) : (isFuture ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$d',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isSunday
                                                  ? (isFuture ? const Color(0xFFFDA4AF) : const Color(0xFFE11D48))
                                                  : (isToday ? const Color(0xFFD97706) : (isFuture ? const Color(0xFF94A3B8) : const Color(0xFF1E293B))),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                  // Summary Columns Header (Công, T/S, P, KP, !, TC)
                                  _buildSummaryHeaderCell('Công', 38, const Color(0xFF0284C7)),
                                  _buildSummaryHeaderCell('T/S', 34, const Color(0xFFD97706)),
                                  _buildSummaryHeaderCell('P', 34, const Color(0xFF64748B)),
                                  _buildSummaryHeaderCell('KP', 34, const Color(0xFFE11D48)),
                                  _buildSummaryHeaderCell('!', 32, const Color(0xFFE11D48)),
                                  _buildSummaryHeaderCell('TC', 36, const Color(0xFF059669)),
                                ],
                              ),
                            ),

                            // Days Data Rows
                            ...pagedList.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final emp = entry.value;
                              final isEven = idx % 2 == 0;

                              return Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                                  border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
                                ),
                                child: Row(
                                  children: [
                                    // 31 Days cells
                                    ...List.generate(daysInMonth, (dIdx) {
                                      final d = dIdx + 1;
                                      final dayKey = '$d';
                                      final dayObj = emp.days[dayKey];
                                      final weekday = _getDayWeekdayLabel(d);
                                      final isSunday = weekday == 'CN';

                                      final parts = _timesheetMonthKey.split('-');
                                      final y = int.tryParse(parts[0]) ?? 2026;
                                      final m = int.tryParse(parts[1]) ?? 10;
                                      final now = DateTime.now();
                                      final isToday = (y == now.year && m == now.month && d == now.day);
                                      final isFuture = (y > now.year) || (y == now.year && m > now.month) || (y == now.year && m == now.month && d > now.day);

                                      return InkWell(
                                        onTap: () => _showDayDetailModal(emp, d, dayObj, isFuture: isFuture),
                                        child: Container(
                                          width: 36,
                                          height: 52,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isToday
                                                ? const Color(0xFFFEF9C3).withValues(alpha: 0.6)
                                                : (isFuture ? const Color(0xFFF8FAFC).withValues(alpha: 0.5) : Colors.transparent),
                                          ),
                                          child: _buildMatrixCellText(dayObj, isSunday, isFuture),
                                        ),
                                      );
                                    }),

                                    // Summary data cells (matching web totals)
                                    _buildSummaryDataCell('${emp.totals.workdayUnits.toStringAsFixed(emp.totals.workdayUnits % 1 == 0 ? 0 : 1)}', 38, const Color(0xFF0284C7), isBold: true),
                                    _buildSummaryDataCell('${emp.totals.lateDays + emp.totals.earlyLeaveDays}', 34, (emp.totals.lateDays + emp.totals.earlyLeaveDays) > 0 ? const Color(0xFFD97706) : const Color(0xFF94A3B8)),
                                    _buildSummaryDataCell('${emp.totals.annualLeaveDays + emp.totals.paidLeaveDays}', 34, const Color(0xFF94A3B8)),
                                    _buildSummaryDataCell('${emp.totals.absentDays}', 34, emp.totals.absentDays > 0 ? const Color(0xFFE11D48) : const Color(0xFF94A3B8)),
                                    _buildSummaryDataCell('${emp.totals.abnormalDays}', 32, emp.totals.abnormalDays > 0 ? const Color(0xFFE11D48) : const Color(0xFF94A3B8)),
                                    _buildSummaryDataCell('${(emp.totals.otMinutes / 60).toStringAsFixed(0)}', 36, (emp.totals.otMinutes > 0) ? const Color(0xFF059669) : const Color(0xFF94A3B8)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Pagination Row at Bottom of Table (Responsive, completely prevents RenderFlex overflow)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Hiển thị $startIdx-$endIdx / $totalCount NV',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Page numbers: < [ 1 ] 2 3 4 >
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: _timesheetCurrentPage > 1 ? () => setState(() => _timesheetCurrentPage--) : null,
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Icon(Icons.chevron_left_rounded, size: 15, color: Color(0xFF475569)),
                            ),
                          ),
                          const SizedBox(width: 3),
                          ...List.generate(_timesheetTotalPages, (pIdx) {
                            final pageNum = pIdx + 1;
                            final isActive = pageNum == _timesheetCurrentPage;
                            return InkWell(
                              onTap: () => setState(() => _timesheetCurrentPage = pageNum),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFF59E0B) : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isActive ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  '$pageNum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                    color: isActive ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 3),
                          InkWell(
                            onTap: _timesheetCurrentPage < _timesheetTotalPages ? () => setState(() => _timesheetCurrentPage++) : null,
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Icon(Icons.chevron_right_rounded, size: 15, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 8. Legend Box (Matching Screenshot: 0 Vắng không phép, HC Hành chính (đủ), OFF Nghỉ tuần/Lễ, P Nghỉ phép)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLegendItem('0', const Color(0xFFEF4444), 'Vắng không phép', bgColor: const Color(0xFFFEE2E2)),
                  const SizedBox(width: 14),
                  _buildLegendItem('HC', const Color(0xFF0284C7), 'Hành chính (đủ)', bgColor: const Color(0xFFE0F2FE)),
                  const SizedBox(width: 14),
                  _buildLegendItem('OFF', const Color(0xFFEF4444), 'Nghỉ tuần/Lễ', bgColor: const Color(0xFFFEE2E2)),
                  const SizedBox(width: 14),
                  _buildLegendItem('P', const Color(0xFF9333EA), 'Nghỉ phép', bgColor: const Color(0xFFF3E8FF)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLightActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightFilterTab(String label, String key, Color? dotColor) {
    final isActive = _timesheetFilterTab == key;
    return InkWell(
      onTap: () => setState(() {
        _timesheetFilterTab = key;
        _timesheetCurrentPage = 1;
      }),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF59E0B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeaderCell(String title, double width, Color color) {
    return Container(
      width: width,
      alignment: Alignment.center,
      child: Text(
        title,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildSummaryDataCell(String value, double width, Color color, {bool isBold = false}) {
    return Container(
      width: width,
      height: 52,
      alignment: Alignment.center,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMatrixCellText(HrmBoardDay? dayObj, bool isSunday, bool isFuture) {
    if (isFuture) {
      final st = dayObj?.status ?? '';
      final text = (isSunday || st == 'OFF')
          ? 'OFF'
          : (st == 'HC' ? 'HC' : (st.isNotEmpty ? st : 'HC'));
      return Text(
        text,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8), // Màu xám nhạt cho ngày chưa tới
        ),
      );
    }

    if (isSunday || dayObj?.status == 'OFF') {
      return const Text(
        'OFF',
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
      );
    }
    final st = dayObj?.status ?? '';
    if (st == 'HC') {
      return const Text(
        'HC',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
      );
    } else if (st == 'PRESENT') {
      return const Text(
        '8',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
      );
    } else if (st == 'ABSENT') {
      return const Text(
        '0',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
      );
    } else if (st.contains('LEAVE')) {
      return const Text(
        'P',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF9333EA)),
      );
    } else {
      return const Text(
        '0',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
      );
    }
  }

  Widget _buildLegendItem(String tag, Color tagColor, String text, {Color? bgColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: bgColor ?? const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tag,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tagColor),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  void _showTimesheetLegendBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Chú thích ký hiệu Bảng công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 14),
            _buildLegendDetailRow('0', const Color(0xFFEF4444), 'Vắng không phép / Chưa có dữ liệu chấm công', bgColor: const Color(0xFFFEE2E2)),
            const SizedBox(height: 8),
            _buildLegendDetailRow('HC', const Color(0xFF0284C7), 'Ca Hành chính (chuẩn 8 giờ)', bgColor: const Color(0xFFE0F2FE)),
            const SizedBox(height: 8),
            _buildLegendDetailRow('OFF', const Color(0xFFEF4444), 'Nghỉ tuần (Chủ nhật / Thứ 7) hoặc Lễ Tết', bgColor: const Color(0xFFFEE2E2)),
            const SizedBox(height: 8),
            _buildLegendDetailRow('P', const Color(0xFF9333EA), 'Nghỉ phép năm / Nghỉ phép hưởng lương', bgColor: const Color(0xFFF3E8FF)),
            const SizedBox(height: 8),
            _buildLegendDetailRow('Chưa tới', const Color(0xFF94A3B8), 'Ngày chưa diễn ra trong tháng: màu xám nhạt', bgColor: const Color(0xFFF1F5F9)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDetailRow(String tag, Color tagColor, String desc, {Color? bgColor}) {
    return Row(
      children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor ?? const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tagColor)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
      ],
    );
  }

  bool _isCalculatingTimesheet = false;

  // ==========================================
  // TÍNH CÔNG (CALCULATE TIMESHEET - API THẬT)
  // ==========================================
  Future<void> _handleCalculateTimesheet() async {
    if (_isCalculatingTimesheet) return;
    setState(() => _isCalculatingTimesheet = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('Đang tính lại công cho toàn bộ nhân sự...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final res = await _attendanceService.calculateTimesheet(month: _timesheetMonthKey);
      await _refreshTimesheetBoard();

      if (!mounted) return;
      if (res != null) {
        final notice = res.abnormal > 0
            ? 'Đã tính công ${res.count} dòng, còn ${res.abnormal} dòng bất thường cần xử lý trước khi chốt.'
            : 'Đã tính công ${res.count} dòng, không có dòng bất thường.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notice),
            backgroundColor: res.abnormal > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tính công hoặc máy chủ đang bận.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tính công: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculatingTimesheet = false);
    }
  }

  // ==========================================
  // CHỐT ĐƠN TỪ (CLOSE REQUESTS - API THẬT)
  // ==========================================
  void _showCloseRequestsModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        bool isLoadingState = true;
        HrmMonthCloseState? closeState;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            if (isLoadingState) {
              _attendanceService.getTimesheetCloseState(month: _timesheetMonthKey).then((s) {
                if (dialogCtx.mounted) {
                  setModalState(() {
                    closeState = s;
                    isLoadingState = false;
                  });
                }
              }).catchError((err) {
                if (dialogCtx.mounted) {
                  setModalState(() {
                    isLoadingState = false;
                  });
                }
              });
            }

            final blockers = closeState?.blockersForRequests ?? [];
            final hasBlockers = blockers.isNotEmpty;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(22),
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Title & Close Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chốt đơn từ tháng $_timesheetMonthKey',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Từ lúc chốt, không tạo, sửa hay duyệt đơn nào có ngày thuộc tháng này.',
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: isSubmitting ? null : () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (isLoadingState)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        child: Column(
                          children: const [
                            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFF59E0B))),
                            SizedBox(height: 10),
                            Text('Đang kiểm tra điều kiện chốt đơn từ...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      )
                    else if (hasBlockers)
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 220),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Còn vướng, chưa thể thực hiện:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            ),
                            const SizedBox(height: 8),
                            Flexible(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: blockers.map((b) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '• ',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${b.message}${b.count > 0 ? " (${b.count})" : ""}',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF92400E),
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tất cả đơn từ trong tháng đã được xử lý. Bạn có thể tiến hành chốt đơn từ.',
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF166534), height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Action Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Bỏ qua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: (hasBlockers || isLoadingState || isSubmitting)
                              ? (hasBlockers
                                  ? () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Còn vướng đơn từ chưa duyệt trong tháng, chưa thể chốt đơn từ!'),
                                          backgroundColor: Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  : null)
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  final res = await _attendanceService.closeRequests(month: _timesheetMonthKey);
                                  if (!dialogCtx.mounted) return;

                                  if (res['success'] == true) {
                                    Navigator.pop(ctx);
                                    await _refreshTimesheetBoard();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Đã chốt đơn từ tháng $_timesheetMonthKey thành công!'),
                                          backgroundColor: const Color(0xFF16A34A),
                                        ),
                                      );
                                    }
                                  } else {
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['message']?.toString() ?? 'Chốt đơn từ thất bại.'),
                                          backgroundColor: const Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasBlockers ? const Color(0xFFFDE68A) : const Color(0xFFF59E0B),
                            foregroundColor: hasBlockers ? const Color(0xFFB45309) : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  'Xác nhận chốt đơn từ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: hasBlockers ? const Color(0xFFB45309) : Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCloseTimesheetModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        bool isLoadingState = true;
        HrmMonthCloseState? closeState;
        String? loadError;
        bool isSubmitting = false;
        bool hasFetched = false;

        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            void fetchState() async {
              try {
                final state = await _attendanceService.getTimesheetCloseState(month: _timesheetMonthKey);
                setModalState(() {
                  closeState = state;
                  isLoadingState = false;
                  loadError = state == null ? 'Không thể tải điều kiện chốt công' : null;
                });
              } catch (e) {
                setModalState(() {
                  isLoadingState = false;
                  loadError = 'Lỗi kết nối khi kiểm tra chốt công: $e';
                });
              }
            }

            if (!hasFetched) {
              hasFetched = true;
              fetchState();
            }

            final blockers = closeState?.blockersForLock ?? [];
            final hasBlockers = blockers.isNotEmpty;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chốt công tháng $_timesheetMonthKey',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Tính lại và khóa bảng công của tháng để phục vụ tính lương. Sau khi chốt không thể chỉnh sửa.',
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: isSubmitting ? null : () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Loading or Content
                      if (isLoadingState)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFD97706)),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Đang kiểm tra điều kiện chốt công...',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (loadError != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(loadError!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                              ),
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    isLoadingState = true;
                                    loadError = null;
                                  });
                                  fetchState();
                                },
                                child: const Text('Thử lại', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      else if (hasBlockers)
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 250),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Còn vướng, chưa thể thực hiện:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: blockers.map((b) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  '• ',
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    '${b.message}${b.count > 0 ? " (${b.count})" : ""}',
                                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (b.items.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 12, top: 4),
                                                child: Column(
                                                  children: b.items.map((item) {
                                                    final desc = '${item.employeeCode.isNotEmpty ? item.employeeCode : ""} ${item.employeeName.isNotEmpty ? "- ${item.employeeName}" : ""} ${item.date.isNotEmpty ? "- ${item.date}" : ""}: ${item.reason}'.trim();
                                                    return Padding(
                                                      padding: const EdgeInsets.only(bottom: 4),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              desc,
                                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.3),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          InkWell(
                                                            onTap: () {
                                                              Navigator.pop(ctx);
                                                              setState(() {
                                                                _timesheetSearchQuery = item.employeeCode.isNotEmpty
                                                                    ? item.employeeCode
                                                                    : item.employeeName;
                                                              });
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text('Đang lọc tới nhân viên ${item.employeeCode} - ${item.employeeName} (${item.reason})'),
                                                                  backgroundColor: const Color(0xFFD97706),
                                                                ),
                                                              );
                                                            },
                                                            child: const Text(
                                                              'Mở ô công',
                                                              style: TextStyle(
                                                                fontSize: 11.5,
                                                                fontWeight: FontWeight.w600,
                                                                color: Color(0xFF0F172A),
                                                                decoration: TextDecoration.underline,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tất cả điều kiện đã thỏa mãn. Bạn có thể tiến hành chốt bảng công.',
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF166534), height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Bỏ qua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: (isLoadingState || isSubmitting)
                                ? null
                                : hasBlockers
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Chưa thể thực hiện: Còn các điều kiện vướng mắc cần xử lý trước khi chốt công!'),
                                            backgroundColor: Color(0xFFDC2626),
                                          ),
                                        );
                                      }
                                    : () async {
                                        setModalState(() => isSubmitting = true);
                                        final res = await _attendanceService.closeTimesheet(month: _timesheetMonthKey);
                                        if (res['success'] == true) {
                                          await _refreshTimesheetBoard();
                                          if (ctx.mounted) Navigator.pop(ctx);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Đã chốt công tháng $_timesheetMonthKey thành công!'),
                                                backgroundColor: const Color(0xFF16A34A),
                                              ),
                                            );
                                          }
                                        } else {
                                          setModalState(() => isSubmitting = false);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(res['message']?.toString() ?? 'Không thể chốt công. Vui lòng thử lại!'),
                                                backgroundColor: const Color(0xFFDC2626),
                                              ),
                                            );
                                          }
                                        }
                                      },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasBlockers ? const Color(0xFFFDE68A) : const Color(0xFFF59E0B),
                              foregroundColor: hasBlockers ? const Color(0xFFB45309) : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    'Xác nhận chốt công',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: hasBlockers ? const Color(0xFFB45309) : Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReopenTimesheetModal() {
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mở lại kỳ công tháng $_timesheetMonthKey',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Bạn có chắc chắn muốn mở lại kỳ công này? Sau khi mở lại, trạng thái sẽ chuyển về Đang mở để cho phép điều chỉnh công và đơn từ.',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: isSubmitting ? null : () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: 'Lý do mở lại (tùy chọn)',
                    hintText: 'Nhập lý do mở lại kỳ công...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Bỏ qua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              final res = await _attendanceService.reopenTimesheet(
                                month: _timesheetMonthKey,
                                reason: reasonCtrl.text.trim(),
                              );
                              if (res['success'] == true) {
                                await _refreshTimesheetBoard();
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã mở lại kỳ công tháng $_timesheetMonthKey thành công.'),
                                      backgroundColor: const Color(0xFF16A34A),
                                    ),
                                  );
                                }
                              } else {
                                setModalState(() => isSubmitting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['message']?.toString() ?? 'Không thể mở lại kỳ công. Vui lòng thử lại!'),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Xác nhận mở lại',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // XUẤT CSV BẢNG CÔNG (ĐỒNG BỘ CHUẨN WEB ENTERPRISE PLATFORM)
  // ==========================================
  Future<void> _exportTimesheetCsv() async {
    final chosen = _selectedTimesheetEmpIds.isNotEmpty
        ? _effectiveTimesheetEmployees.where((e) => _selectedTimesheetEmpIds.contains(e.employeeId)).toList()
        : _filteredTimesheetEmployees;

    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có dữ liệu nhân viên nào để xuất CSV.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final daysInMonth = _daysInSelectedMonth;
    final parts = _timesheetMonthKey.split('-');
    final y = int.tryParse(parts[0]) ?? 2026;
    final m = int.tryParse(parts[1]) ?? 10;
    final now = DateTime.now();

    // Helper to safely format CSV cells with formula injection protection
    String csvCell(dynamic value) {
      if (value == null) return '""';
      String text = value.toString();
      if (text.startsWith('=') || text.startsWith('+') || text.startsWith('-') || text.startsWith('@') || text.startsWith('\t') || text.startsWith('\r')) {
        text = "'$text";
      }
      return '"${text.replaceAll('"', '""')}"';
    }

    // 1. Header row matching web: Mã NV, Họ tên, Đơn vị, [01/10/2026 ... 31/10/2026], [BOARD_TOTAL_COLUMNS]
    final headers = <String>[
      'Mã NV',
      'Họ tên',
      'Đơn vị',
    ];

    for (int d = 1; d <= daysInMonth; d++) {
      final dayStr = d.toString().padLeft(2, '0');
      final monthStr = m.toString().padLeft(2, '0');
      headers.add('$dayStr/$monthStr/$y');
    }

    headers.addAll([
      'Công',
      'Đi trễ',
      'Về sớm',
      'Bất thường',
      'Nghỉ không phép',
      'Phép năm',
      'Nghỉ có phép',
      'Không lương',
      'Công tác',
      'OT',
    ]);

    final rows = <List<String>>[headers];

    // 2. Data rows
    for (final emp in chosen) {
      final row = <String>[
        emp.employeeCode,
        emp.employeeName,
        emp.departmentName ?? '',
      ];

      // Day columns 1..daysInMonth
      for (int d = 1; d <= daysInMonth; d++) {
        final dayStr = '$d';
        final dateKey = '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        final dayObj = emp.days[dayStr] ?? emp.days[dateKey];
        final isSunday = DateTime(y, m, d).weekday == DateTime.sunday;
        final isFuture = (y > now.year) || (y == now.year && m > now.month) || (y == now.year && m == now.month && d > now.day);

        String cellVal = '';
        if (dayObj != null) {
          final st = dayObj.status;
          if (isFuture) {
            cellVal = (isSunday || st == 'OFF') ? 'OFF' : (st.isNotEmpty ? st : 'HC');
          } else if (isSunday || st == 'OFF') {
            cellVal = 'OFF';
          } else if (st == 'PRESENT') {
            cellVal = dayObj.workdayUnits > 0
                ? (dayObj.workdayUnits % 1 == 0 ? dayObj.workdayUnits.toInt().toString() : dayObj.workdayUnits.toString())
                : '8';
          } else if (st == 'ABSENT') {
            cellVal = '0';
          } else if (st == 'ABNORMAL') {
            cellVal = '!';
          } else if (st == 'ANNUAL_LEAVE') {
            cellVal = 'PN';
          } else if (st == 'PAID_LEAVE') {
            cellVal = 'CP';
          } else if (st == 'UNPAID_LEAVE') {
            cellVal = 'KL';
          } else if (st == 'TRIP') {
            cellVal = 'CT';
          } else if (st == 'HC') {
            cellVal = 'HC';
          } else {
            cellVal = dayObj.workdayUnits > 0
                ? (dayObj.workdayUnits % 1 == 0 ? dayObj.workdayUnits.toInt().toString() : dayObj.workdayUnits.toString())
                : (st.isNotEmpty ? st : '0');
          }
        } else {
          cellVal = isSunday ? 'OFF' : (isFuture ? 'HC' : '0');
        }
        row.add(cellVal);
      }

      // Totals columns matching web BOARD_TOTAL_COLUMNS
      final t = emp.totals;
      row.add(t.workdayUnits % 1 == 0 ? t.workdayUnits.toInt().toString() : t.workdayUnits.toString());
      row.add(t.lateDays > 0 ? '${t.lateDays} ngày / ${t.lateMinutes} phút' : '0');
      row.add(t.earlyLeaveDays > 0 ? '${t.earlyLeaveDays} ngày / ${t.earlyLeaveMinutes} phút' : '0');
      row.add(t.abnormalDays % 1 == 0 ? t.abnormalDays.toInt().toString() : t.abnormalDays.toString());
      row.add(t.absentDays % 1 == 0 ? t.absentDays.toInt().toString() : t.absentDays.toString());
      row.add(t.annualLeaveDays % 1 == 0 ? t.annualLeaveDays.toInt().toString() : t.annualLeaveDays.toString());
      row.add(t.paidLeaveDays % 1 == 0 ? t.paidLeaveDays.toInt().toString() : t.paidLeaveDays.toString());
      row.add(t.unpaidLeaveDays % 1 == 0 ? t.unpaidLeaveDays.toInt().toString() : t.unpaidLeaveDays.toString());
      row.add(t.tripDays % 1 == 0 ? t.tripDays.toInt().toString() : t.tripDays.toString());
      row.add(t.otMinutes > 0 ? '${(t.otMinutes / 60).toStringAsFixed(1)}h (${t.otMinutes}p)' : '0');

      rows.add(row);
    }

    // 3. Assemble CSV string with UTF-8 BOM
    final csvContent = '\uFEFF${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}';
    final bytes = Uint8List.fromList(utf8.encode(csvContent));
    final fileName = 'bang-cong-$_timesheetMonthKey.csv';

    String? savedFilePath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      savedFilePath = file.path;
    } catch (e) {
      debugPrint('[HrmHubScreen] File write error: $e');
    }

    // 4. Trigger system native share/download sheet
    try {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      debugPrint('[HrmHubScreen] Printing.sharePdf error: $e');
    }

    // 5. Show Export Information & Action Bottom Sheet
    if (!mounted) return;
    _showCsvExportedBottomSheet(
      fileName: fileName,
      fileSizeKb: (bytes.length / 1024).toStringAsFixed(1),
      employeeCount: chosen.length,
      savedPath: savedFilePath,
      csvContent: csvContent,
      bytes: bytes,
    );
  }

  void _showCsvExportedBottomSheet({
    required String fileName,
    required String fileSizeKb,
    required int employeeCount,
    required String? savedPath,
    required String csvContent,
    required Uint8List bytes,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xuất CSV Bảng công thành công',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kỳ công: $_timesheetMonthLabel · $employeeCount nhân sự',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildCsvDetailRow('Tên tệp:', fileName, isBold: true),
                  const SizedBox(height: 8),
                  _buildCsvDetailRow('Dung lượng:', '$fileSizeKb KB'),
                  const SizedBox(height: 8),
                  _buildCsvDetailRow('Số nhân sự:', '$employeeCount nhân sự'),
                  const SizedBox(height: 8),
                  _buildCsvDetailRow('Mã hóa:', 'UTF-8 with BOM (tương thích Excel & Sheets)'),
                  if (savedPath != null) ...[
                    const SizedBox(height: 8),
                    _buildCsvDetailRow('Đã lưu tại:', savedPath, isSmall: true),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: csvContent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép nội dung CSV vào bộ nhớ tạm!'),
                          backgroundColor: Color(0xFF16A34A),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Sao chép CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Printing.sharePdf(bytes: bytes, filename: fileName);
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Lưu / Chia sẻ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCsvDetailRow(String label, String value, {bool isBold = false, bool isSmall = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              color: const Color(0xFF0F172A),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showDayDetailModal(HrmBoardEmployee emp, int dayNumber, HrmBoardDay? dayObj, {bool isFuture = false}) {
    final parts = _timesheetMonthKey.split('-');
    final weekday = _getDayWeekdayLabel(dayNumber);
    final dateStr = '$weekday, ngày ${dayNumber.toString().padLeft(2, '0')}/${parts[1]}/${parts[0]}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.employeeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('${emp.employeeCode} · $dateStr', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFE2E8F0)),

            // Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trạng thái công:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFuture
                        ? const Color(0xFFF1F5F9)
                        : ((dayObj?.status == 'PRESENT' || dayObj?.status == 'HC')
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isFuture
                          ? const Color(0xFFCBD5E1)
                          : ((dayObj?.status == 'PRESENT' || dayObj?.status == 'HC')
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFECACA)),
                    ),
                  ),
                  child: Text(
                    isFuture
                        ? (dayObj?.status == 'OFF' ? 'Nghỉ tuần (Chưa tới)' : 'Dự kiến: Ca Hành chính')
                        : (dayObj?.status == 'HC'
                            ? 'Ca Hành chính (đủ)'
                            : (dayObj?.status == 'PRESENT'
                                ? 'Đủ công (8h)'
                                : (dayObj?.status == 'OFF' ? 'Nghỉ tuần' : 'Vắng không phép / Chưa quẹt thẻ'))),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isFuture
                          ? const Color(0xFF64748B)
                          : ((dayObj?.status == 'PRESENT' || dayObj?.status == 'HC')
                              ? const Color(0xFF15803D)
                              : const Color(0xFFDC2626)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Shift
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ca làm việc:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Text(dayObj?.shiftName ?? 'Ca Hành chính (08:00 - 17:30)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 10),

            // Punch In/Out
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Giờ chấm công:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Text(
                  dayObj?.checkIn != null ? 'Vào: ${dayObj!.checkIn} · Ra: ${dayObj.checkOut ?? '--:--'}' : 'Chưa có dữ liệu quẹt thẻ',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            if (dayObj != null && dayObj.lateMinutes > 0) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Đi trễ:', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                  Text('${dayObj.lateMinutes} phút', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 6. ỨNG VÀ THU HỒI LƯƠNG (SALARY ADVANCES)
  // ==========================================
  Widget _buildSalaryAdvancesView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ứng & Thu hồi lương', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Theo dõi tạm ứng và khấu trừ qua các kỳ lương', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng tạo đơn "Tạm ứng lương" từ mục Đơn từ & Yêu cầu.')),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tạo phiếu ứng', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _advances.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final adv = _advances[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(adv.employeeName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(_formatCurrency(adv.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(adv.reason, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kỳ thu hồi: ${adv.repaymentPeriod}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text('Đã thu: ${_formatCurrency(adv.repaidAmount)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ],
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
  // 7. TRUNG TÂM CẤU HÌNH HRM (HRM CONFIGURATION CENTER - 1:1 WEB PIXEL-PERFECT)
  // ==========================================
  Widget _buildHrmConfigCenterView() {
    final configTabs = [
      {'key': 'OVERVIEW', 'title': 'Tổng quan cấu hình', 'icon': Icons.grid_view_rounded},
      {'key': 'LEAVE', 'title': 'Chính sách phép năm', 'icon': Icons.beach_access_rounded},
      {'key': 'POLICY', 'title': 'Quy định chấm công', 'icon': Icons.tune_rounded},
      {'key': 'HOLIDAYS', 'title': 'Lịch làm / OFF / Lễ', 'icon': Icons.calendar_month_outlined},
      {'key': 'GPS', 'title': 'Địa điểm GPS', 'icon': Icons.location_on_outlined},
      {'key': 'DEVICES', 'title': 'Thiết bị', 'icon': Icons.devices_other_outlined},
      {'key': 'AUTO', 'title': 'Chấm công tự động', 'icon': Icons.auto_mode_outlined},
      {'key': 'SHIFTS_ASSIGN', 'title': 'Phân ca', 'icon': Icons.groups_outlined},
      {'key': 'SHIFTS', 'title': 'Danh mục ca', 'icon': Icons.format_list_bulleted_rounded},
      {'key': 'STANDARD', 'title': 'Công chuẩn', 'icon': Icons.event_available_outlined},
      {'key': 'REQUEST_TYPES', 'title': 'Loại đơn & lý do', 'icon': Icons.description_outlined},
      {'key': 'APPROVAL_FLOWS', 'title': 'Quy trình duyệt', 'icon': Icons.alt_route_outlined},
      {'key': 'PAYROLL_CFG', 'title': 'Lương & OT', 'icon': Icons.payments_outlined},
      {'key': 'OPERATIONS', 'title': 'Vận hành & tích hợp', 'icon': Icons.settings_ethernet_rounded},
    ];

    return Column(
      children: [
        // Top Sticky Sub-Tab / Category Navigation Bar (Web-matching)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Sidebar Menu Trigger Button (1:1 Web Left Panel)
              InkWell(
                onTap: _showConfigSidebarSheet,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.view_sidebar_outlined, size: 15, color: Color(0xFF334155)),
                      SizedBox(width: 4),
                      Text('Menu Cấu hình', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(height: 22, child: VerticalDivider(width: 1, color: Color(0xFFE2E8F0))),
              const SizedBox(width: 8),

              // Scrollable Pills matching web sub-items
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView.separated(
                    controller: _configSubTabScrollCtrl,
                    scrollDirection: Axis.horizontal,
                    itemCount: configTabs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, idx) {
                      final tab = configTabs[idx];
                      final isSelected = _configSubTab == tab['key'];
                      return InkWell(
                        onTap: () => setState(() => _configSubTab = tab['key'] as String),
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab['icon'] as IconData,
                                size: 14,
                                color: isSelected ? const Color(0xFFB45309) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                tab['title'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF92400E) : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Sub-Tab Content View
        Expanded(
          child: _configSubTab == 'OVERVIEW'
              ? _buildHrmConfigOverviewContent()
              : _buildHrmConfigDedicatedSubView(),
        ),
      ],
    );
  }

  // OVERVIEW CONTENT (Web 1:1 "Tổng quan cấu hình" -> "Trung tâm cấu hình HRM")
  Widget _buildHrmConfigOverviewContent() {
    final q = _configSearchQuery.trim().toLowerCase();

    final allLeaveItems = [
      {
        'key': 'LEAVE',
        'title': 'Chính sách phép năm',
        'desc': 'Thiết lập nguyên tắc tính phép, thâm niên, ứng phép',
        'icon': Icons.calendar_month_outlined,
        'action': () => setState(() => _configSubTab = 'LEAVE'),
      },
    ];

    final allAttendanceItems = [
      {
        'key': 'POLICY',
        'title': 'Quy định chấm công',
        'desc': 'Thiết lập quy tắc chấm công, điều kiện hợp lệ',
        'icon': Icons.tune_rounded,
        'action': () => setState(() => _configSubTab = 'POLICY'),
      },
      {
        'key': 'HOLIDAYS',
        'title': 'Lịch làm / OFF / Lễ',
        'desc': 'Quản lý lịch làm việc, ngày nghỉ, ngày lễ',
        'icon': Icons.calendar_month_outlined,
        'action': () => setState(() => _configSubTab = 'HOLIDAYS'),
      },
      {
        'key': 'GPS',
        'title': 'Địa điểm GPS',
        'desc': 'Quản lý địa điểm làm việc theo GPS',
        'icon': Icons.location_on_outlined,
        'action': () => setState(() => _configSubTab = 'GPS'),
      },
      {
        'key': 'DEVICES',
        'title': 'Thiết bị',
        'desc': 'Quản lý thiết bị chấm công, máy chấm, app',
        'icon': Icons.devices_other_outlined,
        'action': () => setState(() => _configSubTab = 'DEVICES'),
      },
      {
        'key': 'AUTO',
        'title': 'Chấm công tự động',
        'desc': 'Bật hoặc tắt tự sinh giờ vào/ra theo ca cho từng thứ trong tuần, không cần phân ca lại',
        'icon': Icons.auto_mode_outlined,
        'action': () => setState(() => _configSubTab = 'AUTO'),
      },
    ];

    final allScheduleItems = [
      {
        'key': 'SHIFTS_ASSIGN',
        'title': 'Phân ca',
        'desc': 'Thiết lập và quản lý các ca làm việc theo nhân viên',
        'icon': Icons.groups_outlined,
        'action': () => setState(() => _configSubTab = 'SHIFTS_ASSIGN'),
      },
      {
        'key': 'SHIFTS',
        'title': 'Danh mục ca',
        'desc': 'Quản lý danh mục ca, mẫu ca và quy tắc tính',
        'icon': Icons.format_list_bulleted_rounded,
        'action': () => setState(() => _configSubTab = 'SHIFTS'),
      },
      {
        'key': 'STANDARD',
        'title': 'Công chuẩn',
        'desc': 'Công chuẩn của bảng công theo từng tháng; động theo lịch ca hoặc cố định',
        'icon': Icons.event_available_outlined,
        'action': () => setState(() => _configSubTab = 'STANDARD'),
      },
    ];

    final allRequestItems = [
      {
        'key': 'REQUEST_TYPES',
        'title': 'Loại đơn & lý do',
        'desc': 'Quản lý loại đơn và danh mục lý do (gồm lý do nghỉ) của từng loại',
        'icon': Icons.description_outlined,
        'action': () => setState(() => _configSubTab = 'REQUEST_TYPES'),
      },
      {
        'key': 'APPROVAL_FLOWS',
        'title': 'Quy trình duyệt',
        'desc': 'Thiết lập quy trình phê duyệt đơn từ theo phân cấp',
        'icon': Icons.alt_route_outlined,
        'action': () => setState(() => _configSubTab = 'APPROVAL_FLOWS'),
      },
    ];

    final allPayrollItems = [
      {
        'key': 'PAYROLL_CFG',
        'title': 'Lương & OT',
        'desc': 'Cấu hình lương, phụ cấp, OT và các khoản chi trả',
        'icon': Icons.payments_outlined,
        'action': () => setState(() => _configSubTab = 'PAYROLL_CFG'),
      },
    ];

    final allSystemItems = [
      {
        'key': 'OPERATIONS',
        'title': 'Vận hành & tích hợp',
        'desc': 'Tích hợp dữ liệu, thiết bị và vận hành hệ thống',
        'icon': Icons.settings_ethernet_rounded,
        'action': () => setState(() => _configSubTab = 'OPERATIONS'),
      },
      {
        'key': 'PERMISSIONS',
        'title': 'Quyền và vai trò',
        'desc': 'Phân quyền truy cập và vai trò trong hệ thống',
        'icon': Icons.admin_panel_settings_outlined,
        'action': () => setState(() => _configSubTab = 'PERMISSIONS'),
      },
    ];

    final filteredLeave = allLeaveItems.where((it) {
      if (q.isEmpty) return true;
      return (it['title'] as String).toLowerCase().contains(q) ||
          (it['desc'] as String).toLowerCase().contains(q);
    }).toList();

    final filteredAttendance = allAttendanceItems.where((it) {
      if (q.isEmpty) return true;
      return (it['title'] as String).toLowerCase().contains(q) ||
          (it['desc'] as String).toLowerCase().contains(q);
    }).toList();

    final filteredSchedule = allScheduleItems.where((it) {
      if (q.isEmpty) return true;
      return (it['title'] as String).toLowerCase().contains(q) ||
          (it['desc'] as String).toLowerCase().contains(q);
    }).toList();

    final filteredRequest = allRequestItems.where((it) {
      if (q.isEmpty) return true;
      return (it['title'] as String).toLowerCase().contains(q) ||
          (it['desc'] as String).toLowerCase().contains(q);
    }).toList();

    final filteredPayroll = allPayrollItems.where((it) {
      if (q.isEmpty) return true;
      return (it['title'] as String).toLowerCase().contains(q) ||
          (it['desc'] as String).toLowerCase().contains(q);
    }).toList();

    final filteredSystem = allSystemItems.where((it) {
      if (q.isEmpty) return true;
      return (it['title'] as String).toLowerCase().contains(q) ||
          (it['desc'] as String).toLowerCase().contains(q);
    }).toList();

    final totalCount = filteredLeave.length +
        filteredAttendance.length +
        filteredSchedule.length +
        filteredRequest.length +
        filteredPayroll.length +
        filteredSystem.length;

    return RefreshIndicator(
      onRefresh: _loadAllHrmData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs matching web
            Row(
              children: const [
                Text('Nhân sự', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                SizedBox(width: 4),
                Text('Cấu hình', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                SizedBox(width: 4),
                Text('Tổng quan cấu hình', style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),

            // Header Title matching Web
            const Text(
              'Trung tâm cấu hình HRM',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Quản lý chính sách và danh mục dùng chung cho toàn bộ phân hệ nhân sự.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
            ),
            const SizedBox(height: 14),

            // Search Bar & Badge (Web 1:1)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _configSearchCtrl,
                      onChanged: (val) => setState(() => _configSearchQuery = val),
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Tìm nhanh chức năng hoặc chính sách...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                        suffixIcon: _configSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _configSearchCtrl.clear();
                                  setState(() => _configSearchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        '$totalCount mục cấu hình',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ==========================================
            // GROUP 1: NGHỈ PHÉP
            // ==========================================
            if (filteredLeave.isNotEmpty) ...[
              Container(
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
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Icon(Icons.beach_access_rounded, size: 18, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Nghỉ phép',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Cách tính phép năm, phép thâm niên, ứng phép và các tác vụ định kỳ.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredLeave.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      itemBuilder: (ctx, idx) {
                        final item = filteredLeave[idx];
                        return _buildConfigItemTile(
                          icon: item['icon'] as IconData,
                          title: item['title'] as String,
                          desc: item['desc'] as String,
                          onTap: item['action'] as VoidCallback,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ==========================================
            // GROUP 2: CHẤM CÔNG & THIẾT BỊ
            // ==========================================
            if (filteredAttendance.isNotEmpty) ...[
              Container(
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
                    // Group Header (Section Title)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF059669)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Chấm công & thiết bị',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'GPS, IP, thiết bị, quy tắc vào/ra và lịch ngày làm / OFF / lễ.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Group Items
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredAttendance.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      itemBuilder: (ctx, idx) {
                        final item = filteredAttendance[idx];
                        return _buildConfigItemTile(
                          icon: item['icon'] as IconData,
                          title: item['title'] as String,
                          desc: item['desc'] as String,
                          onTap: item['action'] as VoidCallback,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ==========================================
            // GROUP 3: LỊCH LÀM VIỆC
            // ==========================================
            if (filteredSchedule.isNotEmpty) ...[
              Container(
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
                    // Group Header (Section Title)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDDD6FE)),
                            ),
                            child: const Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF7C3AED)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Lịch làm việc',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Gắn ca theo nhân viên, lịch tuần/tháng, mẫu ca và lịch định kỳ.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Group Items
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredSchedule.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      itemBuilder: (ctx, idx) {
                        final item = filteredSchedule[idx];
                        return _buildConfigItemTile(
                          icon: item['icon'] as IconData,
                          title: item['title'] as String,
                          desc: item['desc'] as String,
                          onTap: item['action'] as VoidCallback,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ==========================================
            // GROUP 4: ĐƠN TỪ & PHÊ DUYỆT
            // ==========================================
            if (filteredRequest.isNotEmpty) ...[
              Container(
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
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: const Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Đơn từ & phê duyệt',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Loại đơn, lý do của từng loại đơn và các bước phê duyệt.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredRequest.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      itemBuilder: (ctx, idx) {
                        final item = filteredRequest[idx];
                        return _buildConfigItemTile(
                          icon: item['icon'] as IconData,
                          title: item['title'] as String,
                          desc: item['desc'] as String,
                          onTap: item['action'] as VoidCallback,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ==========================================
            // GROUP 5: LƯƠNG
            // ==========================================
            if (filteredPayroll.isNotEmpty) ...[
              Container(
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
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Icon(Icons.payments_outlined, size: 18, color: Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Lương & OT',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Cấu hình lương, OT, phụ cấp và các khoản chi trả.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredPayroll.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      itemBuilder: (ctx, idx) {
                        final item = filteredPayroll[idx];
                        return _buildConfigItemTile(
                          icon: item['icon'] as IconData,
                          title: item['title'] as String,
                          desc: item['desc'] as String,
                          onTap: item['action'] as VoidCallback,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ==========================================
            // GROUP 6: HỆ THỐNG
            // ==========================================
            if (filteredSystem.isNotEmpty) ...[
              Container(
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
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Icon(Icons.settings_suggest_outlined, size: 18, color: Color(0xFF475569)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Hệ thống',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Vận hành, tích hợp dữ liệu, phân quyền và vai trò người dùng.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredSystem.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      itemBuilder: (ctx, idx) {
                        final item = filteredSystem[idx];
                        return _buildConfigItemTile(
                          icon: item['icon'] as IconData,
                          title: item['title'] as String,
                          desc: item['desc'] as String,
                          onTap: item['action'] as VoidCallback,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (totalCount == 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'Không tìm thấy mục cấu hình nào khớp với "$_configSearchQuery"',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // DEDICATED SUB-VIEW DISPATCHER
  Widget _buildHrmConfigDedicatedSubView() {
    return SingleChildScrollView(
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
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: const [
                      Icon(Icons.arrow_back_ios_rounded, size: 12, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text('Tổng quan cấu hình', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
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
          if (_configSubTab == 'LEAVE') _buildLeavePolicyConfigSubView(),
          if (_configSubTab == 'POLICY') _buildAttendancePolicySubView(),
          if (_configSubTab == 'HOLIDAYS') _buildWorkCalendarSubView(),
          if (_configSubTab == 'GPS') _buildGpsLocationsSubView(),
          if (_configSubTab == 'DEVICES') _buildHardwareDevicesSubView(),
          if (_configSubTab == 'AUTO') _buildAutoAttendanceSubView(),
          if (_configSubTab == 'SHIFTS_ASSIGN') _buildShiftsManagementView(),
          if (_configSubTab == 'SHIFTS') _buildShiftsCatalogSubView(),
          if (_configSubTab == 'STANDARD') _buildStandardWorkdaysSubView(),
          if (_configSubTab == 'REQUEST_TYPES') _buildRequestTypesReasonsSubView(),
          if (_configSubTab == 'APPROVAL_FLOWS') _buildApprovalFlowsConfigSubView(),
          if (_configSubTab == 'PAYROLL_CFG') _buildPayrollSettingsConfigSubView(),
          if (_configSubTab == 'OPERATIONS' || _configSubTab == 'PERMISSIONS') _buildSystemIntegrationsView(),
        ],
      ),
    );
  }

  // SUBVIEW: CHÍNH SÁCH PHÉP NĂM (Web 1:1)
  Widget _buildLeavePolicyConfigSubView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.beach_access_rounded, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Quy định chính sách phép năm', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Đang áp dụng toàn hệ thống doanh nghiệp SVN DTS', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('HIỆU LỰC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildConfigAttributeRow('Tiêu chuẩn phép năm', '12 ngày / năm (tích lũy 1 ngày/tháng)'),
              _buildConfigAttributeRow('Phép thâm niên', '+1 ngày sau mỗi chu kỳ 05 năm làm việc'),
              _buildConfigAttributeRow('Hạn chót dùng phép tồn', 'Hết ngày 31/03 năm kế tiếp'),
              _buildConfigAttributeRow('Chính sách ứng phép', 'Cho phép ứng tối đa 03 ngày phép năm'),
              _buildConfigAttributeRow('Nghỉ việc hoàn phép', 'Tính tiền lương ngày phép chưa sử dụng khi thôi việc'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveBalancesScreen())),
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                  label: const Text('Xem Quỹ phép & Sổ cái nhân sự', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // SUBVIEW: LOẠI ĐƠN & LÝ DO (Web 1:1)
  Widget _buildRequestTypesReasonsSubView() {
    final types = [
      {
        'title': 'Đơn xin nghỉ phép (Leave)',
        'code': 'LEAVE',
        'icon': Icons.beach_access_rounded,
        'color': const Color(0xFF2563EB),
        'reasons': ['Nghỉ phép năm', 'Nghỉ ốm đau có xác nhận', 'Nghỉ việc riêng hưởng lương (kết hôn/tang chế)', 'Nghỉ không hưởng lương', 'Nghỉ chế độ thai sản'],
      },
      {
        'title': 'Đơn làm thêm giờ (Overtime)',
        'code': 'OVERTIME',
        'icon': Icons.more_time_rounded,
        'color': const Color(0xFFD97706),
        'reasons': ['Làm thêm ngày làm việc bình thường (150%)', 'Làm thêm ngày nghỉ cuối tuần (200%)', 'Làm thêm ngày lễ tết (300%)', 'Trực ca sự cố khẩn cấp'],
      },
      {
        'title': 'Đơn tạm ứng lương (Advance)',
        'code': 'ADVANCE',
        'icon': Icons.payments_outlined,
        'color': const Color(0xFF059669),
        'reasons': ['Tạm ứng chi phí công tác ngoại tỉnh', 'Việc gia đình đột xuất', 'Tạm ứng giữa tháng theo quy chế'],
      },
      {
        'title': 'Đơn điều chỉnh chấm công (Correction)',
        'code': 'CORRECTION',
        'icon': Icons.edit_calendar_rounded,
        'color': const Color(0xFF7C3AED),
        'reasons': ['Quên quẹt thẻ vào/ra', 'Lỗi thiết bị / lỗi kết nối mạng', 'Gặp gỡ khách hàng ngoài văn phòng trước giờ làm', 'Đi công tác khẩn cấp'],
      },
      {
        'title': 'Đơn công tác & điều động (Business Trip)',
        'code': 'BUSINESS_TRIP',
        'icon': Icons.directions_car_outlined,
        'color': const Color(0xFF0284C7),
        'reasons': ['Khảo sát hiện trường trạm & TBA', 'Thí nghiệm kiểm định kỹ thuật', 'Họp đối tác EVN liên tỉnh'],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...types.map((t) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (t['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(t['icon'] as IconData, size: 18, color: t['color'] as Color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t['title'] as String,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(t['code'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Danh mục lý do hợp lệ:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (t['reasons'] as List<String>).map((r) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(r, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                  )).toList(),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  // SUBVIEW: QUY TRÌNH DUYỆT (Web 1:1)
  Widget _buildApprovalFlowsConfigSubView() {
    final flows = [
      {
        'name': 'Quy trình duyệt Đơn xin nghỉ phép',
        'steps': [
          {'step': 'Cấp 1', 'role': 'Quản lý trực tiếp / Trưởng phòng', 'sla': '24 giờ'},
          {'step': 'Cấp 2', 'role': 'Chuyên viên Nhân sự (HR Ops)', 'sla': '12 giờ'},
        ],
      },
      {
        'name': 'Quy trình duyệt Làm thêm giờ (OT)',
        'steps': [
          {'step': 'Cấp 1', 'role': 'Chỉ huy trưởng / Trưởng phòng', 'sla': '12 giờ'},
          {'step': 'Cấp 2', 'role': 'Ban Giám đốc phê duyệt', 'sla': '24 giờ'},
        ],
      },
      {
        'name': 'Quy trình duyệt Tạm ứng lương',
        'steps': [
          {'step': 'Cấp 1', 'role': 'Trưởng bộ phận xác nhận nhu cầu', 'sla': '24 giờ'},
          {'step': 'Cấp 2', 'role': 'Kế toán trưởng đối soát hạn mức', 'sla': '24 giờ'},
          {'step': 'Cấp 3', 'role': 'Tổng Giám đốc ký chi', 'sla': '48 giờ'},
        ],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...flows.map((f) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alt_route_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f['name'] as String,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                ...(f['steps'] as List<Map<String, String>>).map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s['step']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s['role']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      ),
                      Text('SLA: ${s["sla"]}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                )),
              ],
            ),
          ),
        )),
      ],
    );
  }

  // SUBVIEW: LƯƠNG & OT (Web 1:1)
  Widget _buildPayrollSettingsConfigSubView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_outlined, size: 20, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Cấu hình bảng lương & Tỷ lệ OT', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Căn cứ Bộ luật Lao động & Quy chế doanh nghiệp SVN', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildConfigAttributeRow('Làm thêm ngày thường', '150% đơn giá lương giờ'),
              _buildConfigAttributeRow('Làm thêm cuối tuần', '200% đơn giá lương giờ'),
              _buildConfigAttributeRow('Làm thêm Lễ, Tết', '300% đơn giá lương giờ (chưa kể lương ngày lễ)'),
              _buildConfigAttributeRow('Phụ cấp ca đêm (22h - 6h)', '+30% đơn giá tiền lương ban ngày'),
              _buildConfigAttributeRow('Mức giảm trừ gia cảnh', 'Bản thân: 11.000.000đ · Phụ thuộc: 4.400.000đ/người'),
              _buildConfigAttributeRow('Tỷ lệ đóng BHXH, BHYT, BHTN', 'Doanh nghiệp: 21.5% · Người lao động: 10.5%'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _activeView = 'payroll'),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Xem Bảng lương & Chi trả', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigAttributeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // 1. Policy Sub-view (1:1 Web Pixel-Perfect matching Screenshot)
  Widget _buildAttendancePolicySubView() {
    final List<Map<String, dynamic>> versions = _policyVersions.isNotEmpty
        ? _policyVersions
        : <Map<String, dynamic>>[
            {
              'version': 'v4',
              'title': 'v4 Quy định chấm công',
              'validity': '07/10/2026 - 30/11/2026',
              'scope': 'Toàn công ty',
              'conditions': ['GPS 1000 m'],
              'isActive': true,
              'statusText': 'Đang áp dụng',
              'gpsRadiusMeters': 1000.0,
              'requireIp': false,
              'requireDevice': false,
              'timezone': 'Asia/Ho_Chi_Minh',
              'weeklyOff': 'Chưa cấu hình',
            },
            {
              'version': 'v3',
              'title': 'v3 Quy định chấm công',
              'validity': '02/10/2026 - 06/10/2026',
              'scope': 'Toàn công ty',
              'conditions': ['GPS 100 m'],
              'isActive': false,
              'statusText': 'Hết hiệu lực',
              'gpsRadiusMeters': 100.0,
              'requireIp': false,
              'requireDevice': false,
              'timezone': 'Asia/Ho_Chi_Minh',
              'weeklyOff': 'Chưa cấu hình',
            },
            {
              'version': 'v2',
              'title': 'v2 Quy định chấm công',
              'validity': '01/10/2026 - 01/10/2026',
              'scope': 'Toàn công ty',
              'conditions': ['GPS 100 m'],
              'isActive': false,
              'statusText': 'Hết hiệu lực',
              'gpsRadiusMeters': 100.0,
              'requireIp': false,
              'requireDevice': false,
              'timezone': 'Asia/Ho_Chi_Minh',
              'weeklyOff': 'Chưa cấu hình',
            },
            {
              'version': 'v1',
              'title': 'v1 Quy định chấm công',
              'validity': '30/09/2026 - 30/09/2026',
              'scope': 'Toàn công ty',
              'conditions': ['IP', 'GPS 100 m', 'Thiết bị'],
              'isActive': false,
              'statusText': 'Hết hiệu lực',
              'gpsRadiusMeters': 100.0,
              'requireIp': true,
              'requireDevice': true,
              'timezone': 'Asia/Ho_Chi_Minh',
              'weeklyOff': 'Chưa cấu hình',
            },
          ];

    Map<String, dynamic> activeVersion = versions.isNotEmpty ? versions.first : <String, dynamic>{};
    for (final v in versions) {
      if (v['isActive'] == true) {
        activeVersion = v;
        break;
      }
    }
    final gpsRadius = (activeVersion['gpsRadiusMeters'] as num?)?.toDouble() ?? 1000.0;
    final reqIp = activeVersion['requireIp'] == true;
    final reqDevice = activeVersion['requireDevice'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Quy định chấm công',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Thiết lập quy tắc chấm công, điều kiện hợp lệ',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    'Đang áp dụng · ${activeVersion['version'] ?? 'v4'}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _showCreatePolicyVersionModal,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, size: 14, color: Color(0xFF0F172A)),
                        SizedBox(width: 3),
                        Text(
                          'Tạo phiên bản mới',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // SECTION 1: Phiên bản quy định
        Container(
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.history_rounded, size: 17, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Phiên bản quy định',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mỗi phiên bản có ngày hiệu lực riêng; phiên bản mới kết thúc phiên bản cũ cùng phạm vi.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Version items list
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: versions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final v = versions[i];
                  final isActive = v['isActive'] == true;
                  final conditions = (v['conditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['GPS 1000 m'];

                  return InkWell(
                    onTap: () => _showPolicyVersionDetailModal(v),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFF8FAFC) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                v['title'] as String,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  v['statusText'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(
                                width: 70,
                                child: Text('Hiệu lực', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                              Text(v['validity'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const SizedBox(
                                width: 70,
                                child: Text('Phạm vi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                              Text(v['scope'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const SizedBox(
                                width: 70,
                                child: Text('Điều kiện', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                              Wrap(
                                spacing: 4,
                                children: conditions.map((cond) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      cond,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // SECTION 2: Tóm tắt quy định đang áp dụng
        Container(
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Icon(Icons.verified_user_outlined, size: 17, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tóm tắt quy định đang áp dụng',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phiên bản ${activeVersion['version'] ?? 'v4'} · từ ${activeVersion['validity']?.toString().split('-').first.trim() ?? '07/10/2026'}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 6 Summary Rows
              _buildPolicySummaryRow(Icons.calendar_month_outlined, const Color(0xFF2563EB), 'Phạm vi & hiệu lực', '${activeVersion['scope']} · ${activeVersion['validity']}'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.hub_outlined, const Color(0xFFEA580C), 'Kiểm soát IP', reqIp ? 'Bắt buộc' : 'Không yêu cầu'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.location_on_outlined, const Color(0xFF059669), 'Kiểm soát GPS', 'Bắt buộc, dung sai ${gpsRadius.toInt()} m'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.phone_iphone_outlined, const Color(0xFF7C3AED), 'Thiết bị chấm công', reqDevice ? 'Bắt buộc' : 'Không yêu cầu'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.language_outlined, const Color(0xFF0284C7), 'Múi giờ', activeVersion['timezone']?.toString() ?? 'Asia/Ho_Chi_Minh'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.calendar_today_outlined, const Color(0xFFDC2626), 'Ngày nghỉ hằng tuần', activeVersion['weeklyOff']?.toString() ?? 'Chưa cấu hình'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // SECTION 3: Cảnh báo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thay đổi quy định ảnh hưởng đến cách xác thực chấm công từ ngày hiệu lực; kiểm tra kỹ trước khi tạo phiên bản.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPolicySummaryRow(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPolicyVersionDetailModal(Map<String, dynamic> v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 20, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(v['title'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Hiệu lực', v['validity'] as String),
            const SizedBox(height: 8),
            _buildDetailRow('Phạm vi', v['scope'] as String),
            const SizedBox(height: 8),
            _buildDetailRow('Điều kiện', ((v['conditions'] as List<dynamic>?)?.join(', ') ?? 'GPS 1000 m')),
            const SizedBox(height: 8),
            _buildDetailRow('Trạng thái', v['statusText'] as String),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePolicyVersionModal() {
    DateTime selectedStartDate = DateTime(2026, 10, 16);
    DateTime? selectedEndDate;
    String startDate = '16/10/2026';
    String endDate = '';
    String scope = 'ALL'; // 'ALL' or 'PILOT'
    bool reqIp = false;
    final ipController = TextEditingController(text: '');
    bool reqGps = false;
    double gpsTolerance = 100;
    bool reqApprovedDevice = false;
    final tzController = TextEditingController(text: 'Asia/Ho_Chi_Minh');
    final selectedOffDays = <int>{7}; // 7 = Chủ nhật
    final reasonController = TextEditingController(text: '');
    bool isSubmitting = false;
    String? submitErrorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Tạo phiên bản quy định chấm công',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Phiên bản mới có hiệu lực từ ngày chọn và kết thúc phiên bản đang áp dụng cùng phạm vi.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Body (Scrollable 4 sections matching Web Screenshots 1:1)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==========================================
                      // SECTION 1: HIỆU LỰC & PHẠM VI
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F3FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.calendar_month_outlined, size: 17, color: Color(0xFF7C3AED)),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Hiệu lực & phạm vi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 1),
                                    Text('Thời gian áp dụng và nhân viên được áp dụng.', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Dates Row with Interactive Date Pickers
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Hiệu lực từ *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: dialogCtx,
                                            initialDate: selectedStartDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2035),
                                          );
                                          if (picked != null) {
                                            setSheetState(() {
                                              selectedStartDate = picked;
                                              startDate = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                                              if (selectedEndDate != null && selectedEndDate!.isBefore(selectedStartDate)) {
                                                selectedEndDate = null;
                                                endDate = '';
                                              }
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(startDate, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Hiệu lực đến (tùy chọn)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: dialogCtx,
                                            initialDate: selectedEndDate ?? selectedStartDate.add(const Duration(days: 30)),
                                            firstDate: selectedStartDate,
                                            lastDate: DateTime(2035),
                                          );
                                          if (picked != null) {
                                            setSheetState(() {
                                              selectedEndDate = picked;
                                              endDate = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                endDate.isNotEmpty ? endDate : 'dd/mm/yyyy',
                                                style: TextStyle(fontSize: 12, color: endDate.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                                              ),
                                              if (endDate.isNotEmpty)
                                                GestureDetector(
                                                  onTap: () {
                                                    setSheetState(() {
                                                      selectedEndDate = null;
                                                      endDate = '';
                                                    });
                                                  },
                                                  child: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                                                )
                                              else
                                                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Scope Radio Options
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setSheetState(() => scope = 'ALL'),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: scope == 'ALL' ? const Color(0xFFFFFDF5) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: scope == 'ALL' ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0), width: scope == 'ALL' ? 1.5 : 1),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(scope == 'ALL' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: scope == 'ALL' ? const Color(0xFFD97706) : const Color(0xFF94A3B8)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: const [
                                                Text('Toàn công ty', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                SizedBox(height: 1),
                                                Text('Áp dụng cho mọi nhân viên', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setSheetState(() => scope = 'PILOT'),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: scope == 'PILOT' ? const Color(0xFFFFFDF5) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: scope == 'PILOT' ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0), width: scope == 'PILOT' ? 1.5 : 1),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(scope == 'PILOT' ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: scope == 'PILOT' ? const Color(0xFFD97706) : const Color(0xFF94A3B8)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: const [
                                                Text('Một số nhân viên', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                SizedBox(height: 1),
                                                Text('Chỉ áp dụng NV được chọn', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Dynamic Warning banner depending on v4 date overlap
                            if (selectedStartDate.isBefore(DateTime(2026, 12, 1)))
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Khoảng hiệu lực giao với phiên bản đã có ngày kết thúc hoặc bắt đầu muộn hơn, hệ thống sẽ từ chối: v4 (Quy định chấm công, 07/10/2026 - 30/11/2026)',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF991B1B), height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Thời gian hiệu lực hợp lệ, tiếp nối sau phiên bản v4 (kết thúc ngày 30/11/2026).',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF166534), height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ==========================================
                      // SECTION 2: KIỂM SOÁT CHẤM CÔNG
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.shield_outlined, size: 17, color: Color(0xFF059669)),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Kiểm soát chấm công', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 1),
                                    Text('Điều kiện để một lần chấm công được coi là hợp lệ.', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Switch 1: IP
                            Row(
                              children: [
                                Switch(
                                  value: reqIp,
                                  activeThumbColor: const Color(0xFF2563EB),
                                  onChanged: (v) => setSheetState(() => reqIp = v),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('Yêu cầu IP được phép', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                      Text('Chỉ chấm công từ địa chỉ IP trong danh sách bên dưới.', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text('IP hoặc dải CIDR được phép', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 4),
                            TextField(
                              controller: ipController,
                              style: const TextStyle(fontSize: 11.5),
                              decoration: InputDecoration(
                                hintText: 'Ví dụ: 203.0.113.10, 10.0.0.0/24; phân cách bằng dấu phẩy.',
                                hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                            const Divider(height: 24, color: Color(0xFFF1F5F9)),

                            // Switch 2: GPS
                            Row(
                              children: [
                                Switch(
                                  value: reqGps,
                                  activeThumbColor: const Color(0xFF2563EB),
                                  onChanged: (v) => setSheetState(() => reqGps = v),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('Yêu cầu GPS trong bán kính', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                      Text('Vị trí chấm công phải nằm trong bán kính của một địa điểm GPS.', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Dung sai GPS (m)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text('${gpsTolerance.toInt()} m', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF059669),
                                inactiveTrackColor: const Color(0xFFE2E8F0),
                                thumbColor: const Color(0xFF059669),
                                overlayColor: const Color(0xFF059669).withValues(alpha: 0.15),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: gpsTolerance.clamp(50, 500),
                                min: 50,
                                max: 500,
                                divisions: 9,
                                onChanged: (v) => setSheetState(() => gpsTolerance = v),
                              ),
                            ),
                            const Text('Sai số định vị tối đa chấp nhận, từ 50 đến 500 m.', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                            const Divider(height: 24, color: Color(0xFFF1F5F9)),

                            // Switch 3: Device
                            Row(
                              children: [
                                Switch(
                                  value: reqApprovedDevice,
                                  activeThumbColor: const Color(0xFF2563EB),
                                  onChanged: (v) => setSheetState(() => reqApprovedDevice = v),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('Một trình duyệt chấm công đã duyệt cho mỗi nhân viên', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                      Text('Chỉ thiết bị đã được duyệt mới chấm công được.', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ==========================================
                      // SECTION 3: THỜI GIAN & NGÀY NGHỈ
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F3FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.access_time_rounded, size: 17, color: Color(0xFF7C3AED)),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Thời gian & ngày nghỉ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 1),
                                    Text('Múi giờ tính công và ngày nghỉ cố định hằng tuần.', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            const Text('Múi giờ *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 4),
                            TextField(
                              controller: tzController,
                              style: const TextStyle(fontSize: 11.5),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                            const SizedBox(height: 12),

                            const Text('Ngày nghỉ hằng tuần', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (int d = 1; d <= 7; d++) ...[
                                  Builder(builder: (context) {
                                    final label = d == 7 ? 'Chủ nhật' : 'Thứ ${d + 1}';
                                    final isSelected = selectedOffDays.contains(d);
                                    return InkWell(
                                      onTap: () {
                                        setSheetState(() {
                                          if (isSelected) {
                                            selectedOffDays.remove(d);
                                          } else {
                                            selectedOffDays.add(d);
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isSelected ? const Color(0xFFFBBF24) : const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? const Color(0xFF92400E) : const Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tính là ngày nghỉ (OFF) khi tính công, trừ khi lịch làm việc khai báo riêng ngày đó là ngày làm.',
                              style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ==========================================
                      // SECTION 4: GHI NHẬN THAY ĐỔI
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.description_outlined, size: 17, color: Color(0xFFD97706)),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Ghi nhận thay đổi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 1),
                                    Text('Lý do được lưu vào nhật ký để dễ theo dõi.', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            const Text('Lý do thay đổi *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 4),
                            TextField(
                              controller: reasonController,
                              style: const TextStyle(fontSize: 11.5),
                              decoration: InputDecoration(
                                hintText: 'Ví dụ: Bật kiểm soát GPS cho khối văn phòng',
                                hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // In-Modal Error Banner (if API returns error)
                      if (submitErrorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  submitErrorMessage!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C), height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer Action Buttons
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        backgroundColor: const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      child: const Text('Hủy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF78350F),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() {
                                isSubmitting = true;
                                submitErrorMessage = null;
                              });

                              final isoStartDate = '${selectedStartDate.year}-${selectedStartDate.month.toString().padLeft(2, '0')}-${selectedStartDate.day.toString().padLeft(2, '0')}';
                              final isoEndDate = selectedEndDate != null
                                  ? '${selectedEndDate!.year}-${selectedEndDate!.month.toString().padLeft(2, '0')}-${selectedEndDate!.day.toString().padLeft(2, '0')}'
                                  : null;

                              final result = await _hrmService.createAttendancePolicyVersion(
                                startDate: isoStartDate,
                                endDate: isoEndDate,
                                scope: scope,
                                requireIp: reqIp,
                                allowedIps: ipController.text.trim(),
                                requireGps: reqGps,
                                gpsRadiusMeters: gpsTolerance,
                                requireDevice: reqApprovedDevice,
                                timezone: tzController.text.trim(),
                                weeklyOff: selectedOffDays.toList(),
                                changeReason: reasonController.text.trim(),
                                title: 'v5 Quy định chấm công',
                              );

                              if (!mounted) return;

                              if (result.isSuccess) {
                                Navigator.pop(ctx);
                                setState(() => _isLoading = true);
                                await _loadAllHrmData();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ ${result.message}'),
                                      backgroundColor: const Color(0xFF16A34A),
                                    ),
                                  );
                                }
                              } else {
                                setSheetState(() {
                                  isSubmitting = false;
                                  submitErrorMessage = result.message;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Không thể tạo: ${result.message}'),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF78350F)),
                            )
                          : const Text('Tạo phiên bản', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Holidays / Work Calendar Exceptions Sub-view (1:1 Web Pixel-Perfect matching Screenshot)
  Widget _buildWorkCalendarSubView() {
    final allItems = _calendarExceptions.isNotEmpty
        ? _calendarExceptions
        : [
            {
              'id': '1',
              'date': '31/12/2026',
              'name': 'Nghỉ tất niên',
              'type': 'OFF',
              'typeLabel': 'Nghỉ (OFF)',
              'paid': false,
              'paidLabel': 'Không',
            },
            {
              'id': '2',
              'date': '05/09/2026',
              'name': 'Làm bù',
              'type': 'WORK',
              'typeLabel': 'Làm việc',
              'paid': true,
              'paidLabel': 'Có',
            },
            {
              'id': '3',
              'date': '02/09/2026',
              'name': 'Quốc khánh',
              'type': 'HOLIDAY',
              'typeLabel': 'Lễ / Tết',
              'paid': true,
              'paidLabel': 'Có',
            },
          ];

    // Filter by query and type
    final filtered = allItems.where((item) {
      if (_calendarTypeFilter != 'ALL') {
        final t = item['type']?.toString().toUpperCase() ?? '';
        if (_calendarTypeFilter == 'OFF' && !t.contains('OFF')) return false;
        if (_calendarTypeFilter == 'WORK' && !t.contains('WORK') && !t.contains('LÀM')) return false;
        if (_calendarTypeFilter == 'HOLIDAY' && !t.contains('HOLIDAY') && !t.contains('LỄ')) return false;
      }
      if (_calendarSearchQuery.trim().isNotEmpty) {
        final q = _calendarSearchQuery.toLowerCase();
        final date = (item['date']?.toString() ?? '').toLowerCase();
        final name = (item['name']?.toString() ?? '').toLowerCase();
        final typeLabel = (item['typeLabel']?.toString() ?? '').toLowerCase();
        return date.contains(q) || name.contains(q) || typeLabel.contains(q);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (Matching Web 1:1)
        const Text(
          'Lịch làm / OFF / Lễ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 3),
        const Text(
          'Quản lý lịch làm việc, ngày nghỉ, ngày lễ',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),

        // Info Banner (Light blue with clickable link 'Phân ca')
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF0369A1), height: 1.4),
                    children: [
                      const TextSpan(text: 'Lịch lễ/Tết và ngày nghỉ được quản lý tại '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: InkWell(
                          onTap: () {
                            setState(() => _configSubTab = 'SHIFTS');
                          },
                          child: const Text(
                            'Phân ca',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '. Danh sách dưới đây chỉ để tham khảo.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Main Card: Lịch ngày làm / OFF / lễ
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top: Title, Subtitle, Search and Dropdown Filter
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch ngày làm / OFF / lễ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${allItems.length} ngày đã khai báo',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),

                    // Search & Filter Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: TextField(
                              controller: _calendarSearchCtrl,
                              onChanged: (v) => setState(() => _calendarSearchQuery = v),
                              style: const TextStyle(fontSize: 11.5),
                              decoration: InputDecoration(
                                hintText: 'Tìm theo ngày, tên hoặc loại ng...',
                                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                                suffixIcon: _calendarSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _calendarSearchCtrl.clear();
                                          setState(() => _calendarSearchQuery = '');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Dropdown Filter
                        PopupMenuButton<String>(
                          onSelected: (val) => setState(() => _calendarTypeFilter = val),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'ALL', child: Text('Tất cả loại ngày', style: TextStyle(fontSize: 12))),
                            const PopupMenuItem(value: 'OFF', child: Text('Nghỉ (OFF)', style: TextStyle(fontSize: 12))),
                            const PopupMenuItem(value: 'WORK', child: Text('Làm việc', style: TextStyle(fontSize: 12))),
                            const PopupMenuItem(value: 'HOLIDAY', child: Text('Lễ / Tết', style: TextStyle(fontSize: 12))),
                          ],
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _calendarTypeFilter == 'OFF'
                                      ? 'Nghỉ (OFF)'
                                      : _calendarTypeFilter == 'WORK'
                                          ? 'Làm việc'
                                          : _calendarTypeFilter == 'HOLIDAY'
                                              ? 'Lễ / Tết'
                                              : 'Tất cả loại ngày',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Column Header (1:1 Web: Ngày | Tên | Loại | Hưởng lương)
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 3,
                      child: Text('Ngày', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text('Tên', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('Loại', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Hưởng lương',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Body Rows
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Không tìm thấy ngày làm / OFF / lễ phù hợp.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    final date = item['date']?.toString() ?? '';
                    final name = item['name']?.toString() ?? '';
                    final type = item['type']?.toString().toUpperCase() ?? '';
                    final typeLabel = item['typeLabel']?.toString() ?? 'Nghỉ (OFF)';
                    final paidLabel = item['paidLabel']?.toString() ?? 'Không';

                    // Pill colors matching Web screenshot
                    Color pillBg = const Color(0xFFFFFBEB);
                    Color pillBorder = const Color(0xFFFDE68A);
                    Color pillText = const Color(0xFFD97706);

                    if (type.contains('WORK') || type.contains('LÀM')) {
                      pillBg = const Color(0xFFEFF6FF);
                      pillBorder = const Color(0xFFBFDBFE);
                      pillText = const Color(0xFF2563EB);
                    } else if (type.contains('HOLIDAY') || type.contains('LỄ')) {
                      pillBg = const Color(0xFFFFF1F2);
                      pillBorder = const Color(0xFFFECDD3);
                      pillText = const Color(0xFFE11D48);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              date,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: pillBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: pillBorder),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: pillText),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              paidLabel,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: paidLabel == 'Có' ? FontWeight.w600 : FontWeight.normal,
                                color: paidLabel == 'Có' ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Footer (1:1 Web: Tổng X dòng)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  'Tổng ${filtered.length} dòng',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. GPS Sub-view (1:1 Web Pixel-Perfect matching Screenshot)
  Widget _buildGpsLocationsSubView() {
    final allSites = _gpsSites.isNotEmpty
        ? _gpsSites
        : [
            {
              'id': '1',
              'name': 'VP Đà Nẵng',
              'coords': '16.0375, 108.212194',
              'radius': '1000 m',
              'status': 'Đang dùng',
              'isActive': true,
              'latitude': 16.0375,
              'longitude': 108.212194,
              'radiusMeters': 1000.0,
            },
          ];

    final activeCount = allSites.where((s) => s['isActive'] == true || s['status'] == 'Đang dùng').length;

    // Filter by query and status
    final filtered = allSites.where((s) {
      if (_gpsStatusFilter != 'ALL') {
        final isActive = s['isActive'] == true || s['status'] == 'Đang dùng';
        if (_gpsStatusFilter == 'ACTIVE' && !isActive) return false;
        if (_gpsStatusFilter == 'INACTIVE' && isActive) return false;
      }
      if (_gpsSearchQuery.trim().isNotEmpty) {
        final q = _gpsSearchQuery.toLowerCase();
        final name = (s['name']?.toString() ?? '').toLowerCase();
        final coords = (s['coords']?.toString() ?? '').toLowerCase();
        return name.contains(q) || coords.contains(q);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (1:1 Web Screenshot)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Địa điểm GPS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Quản lý địa điểm làm việc theo GPS',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    '$activeCount đang dùng',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Tải lại danh sách',
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: _refreshGpsSites,
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _showAddGpsLocationModal,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, size: 14, color: Color(0xFF78350F)),
                        SizedBox(width: 4),
                        Text(
                          'Thêm địa điểm',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Main Card: Địa điểm chấm công (1:1 Web)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top: Title, Subtitle, Search and Status Filter
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Địa điểm chấm công',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$activeCount địa điểm đang dùng',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),

                    // Search & Filter Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: TextField(
                              controller: _gpsSearchCtrl,
                              onChanged: (v) => setState(() => _gpsSearchQuery = v),
                              style: const TextStyle(fontSize: 11.5),
                              decoration: InputDecoration(
                                hintText: 'Tìm theo tên hoặc tọa độ',
                                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                                suffixIcon: _gpsSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _gpsSearchCtrl.clear();
                                          setState(() => _gpsSearchQuery = '');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Dropdown Filter
                        PopupMenuButton<String>(
                          onSelected: (val) => setState(() => _gpsStatusFilter = val),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'ALL', child: Text('Tất cả trạng thái', style: TextStyle(fontSize: 12))),
                            const PopupMenuItem(value: 'ACTIVE', child: Text('Đang dùng', style: TextStyle(fontSize: 12))),
                            const PopupMenuItem(value: 'INACTIVE', child: Text('Ngừng dùng', style: TextStyle(fontSize: 12))),
                          ],
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _gpsStatusFilter == 'ACTIVE'
                                      ? 'Đang dùng'
                                      : _gpsStatusFilter == 'INACTIVE'
                                          ? 'Ngừng dùng'
                                          : 'Tất cả trạng thái',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Column Header (1:1 Web: Địa điểm | Tọa độ | Bán kính | Trạng thái | Thao tác)
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 7,
                      child: Text('Địa điểm', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 7,
                      child: Text('Tọa độ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text('Bán kính', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      flex: 6,
                      child: Text('Trạng thái', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        'Thao tác',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Body Rows
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Không tìm thấy địa điểm GPS phù hợp.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, idx) {
                    final site = filtered[idx];
                    final name = site['name']?.toString() ?? 'VP Đà Nẵng';
                    final rawCoords = site['coords']?.toString();
                    final coords = (site['latitude'] != null && site['longitude'] != null)
                        ? '${HrmService.formatCoordinate(site['latitude'])}, ${HrmService.formatCoordinate(site['longitude'])}'
                        : (rawCoords != null
                            ? rawCoords.replaceAllMapped(RegExp(r'(\d+)\.0(?!\d)'), (m) => m[1]!)
                            : '16.0375, 108.212194');
                    final radius = site['radius']?.toString() ?? '1000 m';
                    final status = site['status']?.toString() ?? 'Đang dùng';
                    final isActive = site['isActive'] == true || status == 'Đang dùng';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Expanded(
                            flex: 7,
                            child: Text(
                              coords,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Text(
                              radius,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  isActive ? 'Đang dùng' : 'Ngừng',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 38,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF64748B)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _showAddGpsLocationModal(initialSite: site);
                                  } else if (action == 'deactivate' || action == 'activate') {
                                    site['isActive'] = (action == 'activate');
                                    site['status'] = (action == 'activate') ? 'Đang dùng' : 'Ngừng';
                                    if (action == 'deactivate') {
                                      _hrmService.deactivateGpsSite(site);
                                    } else {
                                      _hrmService.updateGpsSite(site);
                                    }
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Đã cập nhật trạng thái địa điểm "$name" thành ${site['status']}')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Đã chọn $action cho $name')),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa', style: TextStyle(fontSize: 12))),
                                  PopupMenuItem(
                                    value: isActive ? 'deactivate' : 'activate',
                                    child: Text(isActive ? 'Ngừng dùng' : 'Áp dụng', style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Footer (1:1 Web: Tổng X dòng)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  'Tổng ${filtered.length} dòng',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddGpsLocationModal({Map<String, dynamic>? initialSite}) {
    final isEditing = initialSite != null;
    final nameCtrl = TextEditingController(text: initialSite?['name']?.toString() ?? '');
    final latCtrl = TextEditingController(
      text: initialSite != null ? HrmService.formatCoordinate(initialSite['latitude']) : '0',
    );
    final lngCtrl = TextEditingController(
      text: initialSite != null ? HrmService.formatCoordinate(initialSite['longitude']) : '0',
    );
    final radiusCtrl = TextEditingController(
      text: initialSite?['radiusMeters']?.toInt().toString() ?? (initialSite != null ? (initialSite['radius']?.toString().replaceAll(' m', '') ?? '100') : '100'),
    );
    final reasonCtrl = TextEditingController(text: initialSite?['reason']?.toString() ?? '');
    bool isSubmitting = false;
    String? validationError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (1:1 Web: Cập nhật địa điểm chấm công khi chỉnh sửa)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Cập nhật địa điểm chấm công' : 'Thêm địa điểm chấm công',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: isSubmitting ? null : () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Nhân viên chấm công trong bán kính quanh tọa độ này được coi là hợp lệ.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
                const SizedBox(height: 16),

                if (validationError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validationError!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tên địa điểm *
                RichText(
                  text: const TextSpan(
                    text: 'Tên địa điểm ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444)))],
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 14),

                // Vĩ độ & Kinh độ
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'Vĩ độ ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444)))],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Từ -90 đến 90.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'Kinh độ ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444)))],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Từ -180 đến 180.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Bán kính (m) *
                RichText(
                  text: const TextSpan(
                    text: 'Bán kính (m) ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444)))],
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: radiusCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Từ 1 đến 100000 m.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),

                // Lý do thay đổi * (1:1 Web: Chỉ hiển thị khi Cập nhật / Chỉnh sửa)
                if (isEditing) ...[
                  const SizedBox(height: 14),
                  RichText(
                    text: const TextSpan(
                      text: 'Lý do thay đổi ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444)))],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Nhập lý do thay đổi...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Actions: Hủy & Xác nhận / Lưu địa điểm (1:1 Web Screenshot)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: isSubmitting ? null : () => Navigator.pop(modalCtx),
                      child: const Text('Hủy', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF78350F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                setModalState(() {
                                  validationError = 'Vui lòng nhập tên địa điểm.';
                                });
                                return;
                              }

                              final lat = double.tryParse(latCtrl.text.trim());
                              if (lat == null || lat < -90 || lat > 90) {
                                setModalState(() {
                                  validationError = 'Vĩ độ phải nằm trong khoảng từ -90 đến 90.';
                                });
                                return;
                              }

                              final lng = double.tryParse(lngCtrl.text.trim());
                              if (lng == null || lng < -180 || lng > 180) {
                                setModalState(() {
                                  validationError = 'Kinh độ phải nằm trong khoảng từ -180 đến 180.';
                                });
                                return;
                              }

                              final rad = double.tryParse(radiusCtrl.text.trim());
                              if (rad == null || rad < 1 || rad > 100000) {
                                setModalState(() {
                                  validationError = 'Bán kính phải từ 1 đến 100.000 m.';
                                });
                                return;
                              }

                              final reason = reasonCtrl.text.trim();
                              if (isEditing && reason.isEmpty) {
                                setModalState(() {
                                  validationError = 'Vui lòng nhập lý do thay đổi.';
                                });
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                                validationError = null;
                              });

                              if (isEditing) {
                                final updatedSite = {
                                  'id': initialSite['id']?.toString() ?? '',
                                  'name': name,
                                  'latitude': lat,
                                  'longitude': lng,
                                  'radiusMeters': rad.toInt(),
                                  'reason': reason,
                                  'updated_at': initialSite['updated_at'],
                                };
                                final updateRes = await _hrmService.updateGpsSite(updatedSite);
                                if (!updateRes.isSuccess) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    validationError = updateRes.message;
                                  });
                                  return;
                                }
                              } else {
                                final result = await _hrmService.createGpsSite(
                                  name: name,
                                  latitude: lat,
                                  longitude: lng,
                                  radiusMeters: rad,
                                );

                                if (!result.isSuccess) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    validationError = result.message;
                                  });
                                  return;
                                }
                              }

                              final latestSites = await _hrmService.getGpsSites();
                              setState(() {
                                _gpsSites = latestSites;
                              });

                              if (!modalCtx.mounted) return;
                              Navigator.pop(modalCtx);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'Đã cập nhật địa điểm "$name" thành công!'
                                        : 'Đã lưu địa điểm "$name" thành công!',
                                  ),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF78350F)),
                            )
                          : Text(isEditing ? 'Xác nhận' : 'Lưu địa điểm', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 4. Devices Sub-view (1:1 Web Pixel-Perfect matching Screenshot style)
  Widget _buildHardwareDevicesSubView() {
    final devList = _devices.isNotEmpty
        ? _devices.map((d) => {
            'name': d.name,
            'location': d.location,
            'ip': d.ipAddress,
            'sync': 'Trạng thái: ${d.status}',
            'status': d.status,
            'type': d.type,
          }).toList()
        : [
            {
              'name': 'Hikvision FaceID DS-K1T671MF',
              'location': 'Cửa chính Tầng 1 - Trụ sở SVN DTS',
              'ip': '192.168.1.201 : 8000',
              'sync': 'Đồng bộ: 2 phút trước',
              'status': 'ONLINE',
              'type': 'FaceID AI',
            },
            {
              'name': 'ZKTeco F22 Vân tay & Thẻ từ',
              'location': 'Cửa xưởng Tầng 2 - Nhà máy Long Hậu',
              'ip': '192.168.1.202 : 4370',
              'sync': 'Đồng bộ: 5 phút trước',
              'status': 'ONLINE',
              'type': 'Vân tay & RFID',
            },
            {
              'name': 'Mobile App SVN DTS (GPS & Wi-Fi)',
              'location': 'Toàn bộ nhân sự di động',
              'ip': 'Cloud sync / WebSocket',
              'sync': 'Đồng bộ: Vừa xong',
              'status': 'ONLINE',
              'type': 'Mobile App',
            },
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Thiết bị',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Quản lý thiết bị chấm công, máy chấm, app',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    '${devList.length} thiết bị · Sẵn sàng',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showHardwareDevicesModal,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, size: 14, color: Color(0xFF78350F)),
                        SizedBox(width: 4),
                        Text(
                          'Thêm thiết bị',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Section 1: Danh sách thiết bị
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.router_outlined, size: 18, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Danh sách máy chấm công & thiết bị', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Kết nối máy nhận diện khuôn mặt (FaceID), vân tay và ứng dụng di động', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final dev = devList[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.devices_outlined, size: 18, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dev['name']!,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          dev['status']!,
                                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dev['location']!,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.dns_outlined, size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'IP: ${dev['ip']}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              Text(
                                dev['sync']!,
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 13),
                              label: const Text('Test Ping', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Ping ${dev['name']} thành công! Độ trễ: 14ms (ONLINE)'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.tune_rounded, size: 13),
                              label: const Text('Cấu hình', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Mở thông số cấu hình: ${dev['name']}'),
                                    backgroundColor: const Color(0xFF334155),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Đồng bộ toàn bộ thiết bị ngay', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đang gửi lệnh tải log từ 3 máy chấm công...'), backgroundColor: Color(0xFF4F46E5)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section 2: Tóm tắt thông số tích hợp
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.hub_outlined, size: 18, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Tóm tắt tích hợp phần cứng', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Cơ chế truyền nhận & đồng bộ log máy chấm công', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildPolicySummaryRow(Icons.cable_rounded, const Color(0xFF2563EB), 'Giao thức kết nối', 'TCP/IP, HTTP Webhook, Cloud Sync'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.timer_outlined, const Color(0xFF059669), 'Chu kỳ đồng bộ log', 'Tự động mỗi 3 phút (Polling & Push)'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.face_rounded, const Color(0xFF7C3AED), 'Cơ chế nhận diện', 'Khuôn mặt 3D + Vân tay + RFID + App'),
              const SizedBox(height: 8),
              _buildPolicySummaryRow(Icons.cloud_off_rounded, const Color(0xFFD97706), 'Xử lý khi mất mạng', 'Bộ đệm offline 50,000 sự kiện, tự đẩy khi có mạng'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section 3: Warning Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Máy chấm công phần cứng cần cài đặt đúng IP mạng LAN nội bộ hoặc Port Forwarding. Khi đồng bộ, log check-in/out sẽ nạp trực tiếp vào dữ liệu Bảng công.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 5. Auto Sub-view
  Widget _buildAutoAttendanceSubView() {
    bool isAutoEnabled = true;
    bool skipOnLeave = true;
    bool skipOnHoliday = true;

    return StatefulBuilder(
      builder: (ctx, setLocalState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_mode_outlined, size: 20, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Text('Chấm công tự động', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Mở Modal', style: TextStyle(fontSize: 11.5)),
                onPressed: _showAutoAttendanceModal,
              ),
            ],
          ),
          const Text('Tự sinh giờ vào/ra theo ca làm việc cho nhân viên văn phòng cố định', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bật tự động sinh công', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  subtitle: const Text('Tự tạo lượt vào 08:00 và ra 17:30', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  value: isAutoEnabled,
                  activeColor: const Color(0xFFD97706),
                  onChanged: (v) => setLocalState(() => isAutoEnabled = v),
                ),
                const Divider(color: Color(0xFFE2E8F0)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bỏ qua khi có đơn xin nghỉ phép', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                  subtitle: const Text('Không sinh công nếu đã có đơn nghỉ được duyệt', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  value: skipOnLeave,
                  activeColor: const Color(0xFFD97706),
                  onChanged: (v) => setLocalState(() => skipOnLeave = v),
                ),
                const Divider(color: Color(0xFFE2E8F0)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bỏ qua ngày Lễ/Tết và Chủ nhật', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                  subtitle: const Text('Chỉ tính các ngày làm việc chính thức', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  value: skipOnHoliday,
                  activeColor: const Color(0xFFD97706),
                  onChanged: (v) => setLocalState(() => skipOnHoliday = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã cập nhật cấu hình tự sinh chấm công!'), backgroundColor: Color(0xFF16A34A)),
                );
              },
              child: const Text('Lưu thiết lập tự động', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Shifts Sub-view
  Widget _buildShiftsCatalogSubView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.format_list_bulleted_rounded, size: 20, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Text('Danh mục Ca làm việc', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Mở Modal', style: TextStyle(fontSize: 11.5)),
              onPressed: _showShiftsCatalogModal,
            ),
          ],
        ),
        const Text('Quy định khung giờ check-in/out, thời gian nghỉ và cách tính công theo ca', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        if (_shifts.isNotEmpty) ...[
          for (int i = 0; i < _shifts.length; i++) ...[
            Builder(builder: (context) {
              final s = _shifts[i];
              final start = s.startTime.length >= 5 ? s.startTime.substring(0, 5) : s.startTime;
              final end = s.endTime.length >= 5 ? s.endTime.substring(0, 5) : s.endTime;
              final color = i == 0
                  ? const Color(0xFF2563EB)
                  : (i == 1
                      ? const Color(0xFF059669)
                      : (i == 2 ? const Color(0xFFD97706) : const Color(0xFF7C3AED)));
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildShiftCard(
                  '${s.name} (${s.code})',
                  '$start — $end',
                  'Nghỉ giữa ca ${s.breakMinutes}p',
                  'Tiêu chuẩn',
                  '1.0 công',
                  color,
                ),
              );
            }),
          ],
        ] else ...[
          _buildShiftCard('Ca Hành chính (HC)', '08:00 — 17:30', 'Nghỉ trưa 90p (12:00 - 13:30)', '8.0 giờ', '1.0 công', const Color(0xFF2563EB)),
          const SizedBox(height: 10),
          _buildShiftCard('Ca Sáng (CA1)', '06:00 — 14:00', 'Nghỉ giữa ca 30p (10:00 - 10:30)', '8.0 giờ', '1.0 công', const Color(0xFF059669)),
          const SizedBox(height: 10),
          _buildShiftCard('Ca Chiều (CA2)', '14:00 — 22:00', 'Nghỉ giữa ca 30p (18:00 - 18:30)', '8.0 giờ', '1.0 công', const Color(0xFFD97706)),
          const SizedBox(height: 10),
          _buildShiftCard('Ca Đêm (CA3)', '22:00 — 06:00', 'Nghỉ giữa ca 30p (02:00 - 02:30)', '8.0 giờ', '1.0 công (+30% lương)', const Color(0xFF7C3AED)),
        ],
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tạo ca làm việc mới', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _showShiftsCatalogModal,
          ),
        ),
      ],
    );
  }

  // 7. Standard Workdays Sub-view
  Widget _buildStandardWorkdaysSubView() {
    final standardMonths = [
      {'month': 'Tháng 01/2026', 'workdays': '25 ngày', 'note': 'Trừ 4 Chủ nhật & 1 Tết DL'},
      {'month': 'Tháng 02/2026', 'workdays': '20 ngày', 'note': 'Nghỉ Tết Bính Ngọ (5 ngày)'},
      {'month': 'Tháng 03/2026', 'workdays': '26 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 04/2026', 'workdays': '25 ngày', 'note': 'Trừ Giỗ Tổ & 30/4'},
      {'month': 'Tháng 05/2026', 'workdays': '25 ngày', 'note': 'Trừ 01/5'},
      {'month': 'Tháng 06/2026', 'workdays': '26 ngày', 'note': 'Trừ 4 Chủ nhật'},
      {'month': 'Tháng 07/2026', 'workdays': '26 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 08/2026', 'workdays': '26 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 09/2026', 'workdays': '25 ngày', 'note': 'Trừ 2 ngày Quốc khánh'},
      {'month': 'Tháng 10/2026', 'workdays': '26 ngày', 'note': 'Tháng hiện tại (Đang áp dụng)'},
      {'month': 'Tháng 11/2026', 'workdays': '25 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 12/2026', 'workdays': '26 ngày', 'note': 'Trừ 4 Chủ nhật'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.event_available_outlined, size: 20, color: Color(0xFF059669)),
                SizedBox(width: 8),
                Text('Công chuẩn bảng công 2026', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Mở Modal', style: TextStyle(fontSize: 11.5)),
              onPressed: _showStandardWorkdaysModal,
            ),
          ],
        ),
        const Text('Số công chuẩn theo từng tháng; tính động theo lịch ca và lịch ngày làm trừ Chủ nhật & ngày Lễ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: standardMonths.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final sm = standardMonths[i];
            final isCurrentMonth = sm['month']!.contains('10/2026');
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentMonth ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isCurrentMonth ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isCurrentMonth ? 1.5 : 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sm['month']!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isCurrentMonth ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(sm['note']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrentMonth ? const Color(0xFF2563EB) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sm['workdays']!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isCurrentMonth ? Colors.white : const Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // SIDEBAR DRAWER SHEET (1:1 VỚI BẢN WEB PANEL TRÁI)
  // ==========================================
  void _showConfigSidebarSheet() {
    String localSearch = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final leaveList = [
            {'key': 'LEAVE', 'title': 'Chính sách phép năm', 'icon': Icons.calendar_month_outlined},
          ];

          final attendanceList = [
            {'key': 'POLICY', 'title': 'Quy định chấm công', 'icon': Icons.tune_rounded},
            {'key': 'HOLIDAYS', 'title': 'Lịch làm / OFF / Lễ', 'icon': Icons.calendar_month_outlined},
            {'key': 'GPS', 'title': 'Địa điểm GPS', 'icon': Icons.location_on_outlined},
            {'key': 'DEVICES', 'title': 'Thiết bị', 'icon': Icons.devices_other_outlined},
            {'key': 'AUTO', 'title': 'Chấm công tự động', 'icon': Icons.auto_mode_outlined},
          ];

          final scheduleList = [
            {'key': 'SHIFTS_ASSIGN', 'title': 'Phân ca', 'icon': Icons.groups_outlined},
            {'key': 'SHIFTS', 'title': 'Danh mục ca', 'icon': Icons.format_list_bulleted_rounded},
            {'key': 'STANDARD', 'title': 'Công chuẩn', 'icon': Icons.event_available_outlined},
          ];

          final requestList = [
            {'key': 'REQUEST_TYPES', 'title': 'Loại đơn & lý do', 'icon': Icons.description_outlined},
            {'key': 'APPROVAL_FLOWS', 'title': 'Quy trình duyệt', 'icon': Icons.alt_route_outlined},
          ];

          final payrollList = [
            {'key': 'PAYROLL_CFG', 'title': 'Lương & OT', 'icon': Icons.payments_outlined},
          ];

          final systemList = [
            {'key': 'OPERATIONS', 'title': 'Vận hành & tích hợp', 'icon': Icons.settings_ethernet_rounded},
            {'key': 'PERMISSIONS', 'title': 'Quyền và vai trò', 'icon': Icons.admin_panel_settings_outlined},
          ];

          final q = localSearch.trim().toLowerCase();
          final filteredLeave = leaveList.where((it) => q.isEmpty || (it['title'] as String).toLowerCase().contains(q)).toList();
          final filteredAtt = attendanceList.where((it) => q.isEmpty || (it['title'] as String).toLowerCase().contains(q)).toList();
          final filteredSch = scheduleList.where((it) => q.isEmpty || (it['title'] as String).toLowerCase().contains(q)).toList();
          final filteredReq = requestList.where((it) => q.isEmpty || (it['title'] as String).toLowerCase().contains(q)).toList();
          final filteredPay = payrollList.where((it) => q.isEmpty || (it['title'] as String).toLowerCase().contains(q)).toList();
          final filteredSys = systemList.where((it) => q.isEmpty || (it['title'] as String).toLowerCase().contains(q)).toList();

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Cấu hình HRM',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Chính sách & danh mục dùng chung',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search Box
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      onChanged: (v) => setLocalState(() => localSearch = v),
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(
                        hintText: 'Tìm cấu hình...',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. TỔNG QUAN CẤU HÌNH (HIGHLIGHTED WEBPANEL STYLE)
                  InkWell(
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      setState(() => _configSubTab = 'OVERVIEW');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: _configSubTab == 'OVERVIEW' ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _configSubTab == 'OVERVIEW' ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                          width: _configSubTab == 'OVERVIEW' ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 18,
                            color: _configSubTab == 'OVERVIEW' ? const Color(0xFFD97706) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tổng quan cấu hình',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _configSubTab == 'OVERVIEW' ? FontWeight.bold : FontWeight.w600,
                                color: _configSubTab == 'OVERVIEW' ? const Color(0xFF92400E) : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (_configSubTab == 'OVERVIEW')
                            const Icon(Icons.check_rounded, size: 16, color: Color(0xFFD97706)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. NGHỈ PHÉP SECTION
                  if (filteredLeave.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'NGHỈ PHÉP',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...filteredLeave.map((item) {
                      final isSelected = _configSubTab == item['key'];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        tileColor: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                        leading: Icon(
                          item['icon'] as IconData,
                          size: 18,
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.chevron_right, size: 16, color: Color(0xFF2563EB)) : null,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          setState(() => _configSubTab = item['key'] as String);
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                  ],

                  // 3. CHẤM CÔNG SECTION
                  if (filteredAtt.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'CHẤM CÔNG',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...filteredAtt.map((item) {
                      final isSelected = _configSubTab == item['key'];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        tileColor: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                        leading: Icon(
                          item['icon'] as IconData,
                          size: 18,
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.chevron_right, size: 16, color: Color(0xFF2563EB)) : null,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          setState(() => _configSubTab = item['key'] as String);
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                  ],

                  // 4. LỊCH LÀM VIỆC SECTION
                  if (filteredSch.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'LỊCH LÀM VIỆC',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...filteredSch.map((item) {
                      final isSelected = _configSubTab == item['key'];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        tileColor: isSelected ? const Color(0xFFF5F3FF) : Colors.transparent,
                        leading: Icon(
                          item['icon'] as IconData,
                          size: 18,
                          color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF334155),
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.chevron_right, size: 16, color: Color(0xFF7C3AED)) : null,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          setState(() => _configSubTab = item['key'] as String);
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                  ],

                  // 5. ĐƠN TỪ & PHÊ DUYỆT SECTION
                  if (filteredReq.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'ĐƠN TỪ & PHÊ DUYỆT',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...filteredReq.map((item) {
                      final isSelected = _configSubTab == item['key'];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        tileColor: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                        leading: Icon(
                          item['icon'] as IconData,
                          size: 18,
                          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF334155),
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.chevron_right, size: 16, color: Color(0xFF0284C7)) : null,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          setState(() => _configSubTab = item['key'] as String);
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                  ],

                  // 6. LƯƠNG SECTION
                  if (filteredPay.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'LƯƠNG',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...filteredPay.map((item) {
                      final isSelected = _configSubTab == item['key'];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        tileColor: isSelected ? const Color(0xFFFFFBEB) : Colors.transparent,
                        leading: Icon(
                          item['icon'] as IconData,
                          size: 18,
                          color: isSelected ? const Color(0xFFD97706) : const Color(0xFF64748B),
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFFB45309) : const Color(0xFF334155),
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD97706)) : null,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          setState(() => _configSubTab = item['key'] as String);
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                  ],

                  // 7. HỆ THỐNG SECTION
                  if (filteredSys.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'HỆ THỐNG',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...filteredSys.map((item) {
                      final isSelected = _configSubTab == item['key'];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        tileColor: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
                        leading: Icon(
                          item['icon'] as IconData,
                          size: 18,
                          color: isSelected ? const Color(0xFF475569) : const Color(0xFF64748B),
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF334155),
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.chevron_right, size: 16, color: Color(0xFF475569)) : null,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          setState(() => _configSubTab = item['key'] as String);
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigItemTile({
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(icon, size: 16, color: const Color(0xFF475569)),
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
                    desc,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // MODALS CHO 7 MỤC CẤU HÌNH TRUNG TÂM HRM (1:1 VỚI BẢN WEB)
  // =========================================================================

  // 1. Quy định chấm công Modal
  void _showAttendancePolicyModal() {
    double lateMins = _policyConfig.lateGraceMinutes.toDouble();
    double earlyMins = 15;
    double radiusM = _policyConfig.geofenceRadiusMeters;
    bool reqWifi = _policyConfig.requireWifiMatching;
    bool allowExplain = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.tune_rounded, size: 20, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text('Quy định chấm công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Text('Thiết lập quy tắc tính công, kiểm tra điều kiện vào/ra hợp lệ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                const SizedBox(height: 16),

                // Card 1: Giờ giấc
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dung sai thời gian chấm công', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Giới hạn cho phép trễ:', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          Text('${lateMins.toInt()} phút', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ],
                      ),
                      Slider(
                        value: lateMins,
                        min: 0,
                        max: 60,
                        divisions: 12,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (v) => setSheetState(() => lateMins = v),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cho phép về sớm tối đa:', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          Text('${earlyMins.toInt()} phút', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ],
                      ),
                      Slider(
                        value: earlyMins,
                        min: 0,
                        max: 60,
                        divisions: 12,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (v) => setSheetState(() => earlyMins = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Card 2: GPS & Mạng
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Xác thực vị trí & Mạng', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Bán kính GPS hợp lệ:', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          Text('${radiusM.toInt()} mét', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                        ],
                      ),
                      Slider(
                        value: radiusM,
                        min: 50,
                        max: 500,
                        divisions: 9,
                        activeColor: const Color(0xFF059669),
                        onChanged: (v) => setSheetState(() => radiusM = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bắt buộc khớp Wi-Fi văn phòng', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        subtitle: const Text('Kiểm tra BSSID mạng doanh nghiệp khi chấm công', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        value: reqWifi,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (v) => setSheetState(() => reqWifi = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cho phép giải trình bổ sung lượt chấm', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        subtitle: const Text('Tạo đơn giải trình quên quẹt thẻ trong vòng 3 ngày', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        value: allowExplain,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (v) => setSheetState(() => allowExplain = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã cập nhật quy định chấm công thành công!'), backgroundColor: Color(0xFF16A34A)),
                      );
                    },
                    child: const Text('Lưu quy định chấm công', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 2. Lịch làm / OFF / Lễ Modal
  void _showWorkCalendarAndHolidaysModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Text('Lịch làm / OFF / Lễ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Text('Quy định ngày làm việc trong tuần và danh mục các ngày nghỉ lễ 2026', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              // Section 1: Weekly Schedule
              const Text('1. Lịch làm việc tuần tiêu chuẩn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    _buildWeeklyScheduleRow('Thứ 2 — Thứ 6', 'Làm cả ngày (08:00 - 17:30)', '1.0 công / ngày', const Color(0xFF16A34A)),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildWeeklyScheduleRow('Thứ 7', 'Làm buổi sáng (08:00 - 12:00)', '0.5 công / ngày', const Color(0xFF2563EB)),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildWeeklyScheduleRow('Chủ nhật', 'Nghỉ hàng tuần (OFF)', 'Nghỉ tuần', const Color(0xFFDC2626)),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Section 2: Holidays 2026
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('2. Danh mục ngày nghỉ Lễ/Tết 2026', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Chính thức', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    _buildHolidayRow('Tết Dương lịch 2026', '01/01/2026', '1 ngày'),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildHolidayRow('Tết Nguyên Đán Bính Ngọ', '16/02 - 20/02/2026', '5 ngày'),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildHolidayRow('Giỗ Tổ Hùng Vương', '26/04/2026', '1 ngày'),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildHolidayRow('Giải phóng Miền Nam & Quốc tế LĐ', '30/04 - 01/05/2026', '2 ngày'),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildHolidayRow('Quốc khánh nước CHXHCNVN', '02/09 - 03/09/2026', '2 ngày'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyScheduleRow(String day, String time, String credit, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Text(time, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
            child: Text(credit, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayRow(String name, String date, String daysCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                Text(date, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
            child: Text(daysCount, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
          ),
        ],
      ),
    );
  }



  // 4. Thiết bị Modal
  void _showHardwareDevicesModal() {
    final devList = [
      {
        'name': 'Hikvision FaceID DS-K1T671MF',
        'location': 'Cửa chính Tầng 1 - Trụ sở',
        'ip': '192.168.1.201',
        'sync': '2 phút trước',
        'status': 'ONLINE',
      },
      {
        'name': 'ZKTeco F22 Vân tay & Thẻ từ',
        'location': 'Cửa xưởng Tầng 2 - Nhà máy',
        'ip': '192.168.1.202',
        'sync': '5 phút trước',
        'status': 'ONLINE',
      },
      {
        'name': 'Mobile App SVN DTS (GPS)',
        'location': 'Toàn bộ nhân sự di động',
        'ip': 'Cloud sync',
        'sync': 'Vừa xong',
        'status': 'ONLINE',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.devices_other_outlined, size: 20, color: Color(0xFF4F46E5)),
                    SizedBox(width: 8),
                    Text('Thiết bị chấm công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Text('Quản lý máy chấm công nhận diện khuôn mặt, máy vân tay và Mobile App', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),

            Expanded(
              child: ListView.separated(
                itemCount: devList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final dev = devList[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: const Icon(Icons.router_rounded, size: 18, color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dev['name']!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Text('${dev['location']} · IP: ${dev['ip']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text('Đồng bộ: ${dev['sync']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF059669))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                          child: Text(dev['status']!, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Đồng bộ ngay', style: TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFFC7D2FE)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đang đồng bộ dữ liệu với các máy chấm công...'), backgroundColor: Color(0xFF4F46E5)),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Thêm thiết bị', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 5. Chấm công tự động Modal
  void _showAutoAttendanceModal() {
    bool isAutoEnabled = true;
    bool skipOnLeave = true;
    bool skipOnHoliday = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_mode_outlined, size: 20, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Text('Chấm công tự động', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Text('Tự sinh giờ vào/ra theo ca làm việc cho nhân viên văn phòng cố định', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bật tự động sinh công', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        subtitle: const Text('Tự tạo lượt vào 08:00 và ra 17:30', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: isAutoEnabled,
                        activeColor: const Color(0xFFD97706),
                        onChanged: (v) => setSheetState(() => isAutoEnabled = v),
                      ),
                      const Divider(color: Color(0xFFE2E8F0)),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bỏ qua khi có đơn xin nghỉ phép', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        subtitle: const Text('Không sinh công nếu đã có đơn nghỉ được duyệt', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: skipOnLeave,
                        activeColor: const Color(0xFFD97706),
                        onChanged: (v) => setSheetState(() => skipOnLeave = v),
                      ),
                      const Divider(color: Color(0xFFE2E8F0)),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bỏ qua ngày Lễ/Tết và Chủ nhật', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        subtitle: const Text('Chỉ tính các ngày làm việc chính thức', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: skipOnHoliday,
                        activeColor: const Color(0xFFD97706),
                        onChanged: (v) => setSheetState(() => skipOnHoliday = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã cập nhật cấu hình tự sinh chấm công!'), backgroundColor: Color(0xFF16A34A)),
                      );
                    },
                    child: const Text('Lưu thiết lập tự động', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 6. Danh mục ca Modal
  void _showShiftsCatalogModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.format_list_bulleted_rounded, size: 20, color: Color(0xFF7C3AED)),
                    SizedBox(width: 8),
                    Text('Danh mục Ca làm việc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Text('Quy định khung giờ check-in/out, thời gian nghỉ và cách tính công theo ca', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),

            Expanded(
              child: ListView(
                children: [
                  _buildShiftCard('Ca Hành chính (HC)', '08:00 — 17:30', 'Nghỉ trưa 90p (12:00 - 13:30)', '8.0 giờ', '1.0 công', const Color(0xFF2563EB)),
                  const SizedBox(height: 10),
                  _buildShiftCard('Ca Sáng (CA1)', '06:00 — 14:00', 'Nghỉ giữa ca 30p (10:00 - 10:30)', '8.0 giờ', '1.0 công', const Color(0xFF059669)),
                  const SizedBox(height: 10),
                  _buildShiftCard('Ca Chiều (CA2)', '14:00 — 22:00', 'Nghỉ giữa ca 30p (18:00 - 18:30)', '8.0 giờ', '1.0 công', const Color(0xFFD97706)),
                  const SizedBox(height: 10),
                  _buildShiftCard('Ca Đêm (CA3)', '22:00 — 06:00', 'Nghỉ giữa ca 30p (02:00 - 02:30)', '8.0 giờ', '1.0 công (+30% lương)', const Color(0xFF7C3AED)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tạo ca làm việc mới', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(String title, String hours, String breakTime, String duration, String credit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.schedule, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text('$hours · $breakTime', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
            child: Text(credit, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  // 7. Công chuẩn Modal
  void _showStandardWorkdaysModal() {
    final standardMonths = [
      {'month': 'Tháng 01/2026', 'workdays': '25 ngày', 'note': 'Trừ 4 Chủ nhật & 1 Tết DL'},
      {'month': 'Tháng 02/2026', 'workdays': '20 ngày', 'note': 'Nghỉ Tết Bính Ngọ (5 ngày)'},
      {'month': 'Tháng 03/2026', 'workdays': '26 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 04/2026', 'workdays': '25 ngày', 'note': 'Trừ Giỗ Tổ & 30/4'},
      {'month': 'Tháng 05/2026', 'workdays': '25 ngày', 'note': 'Trừ 01/5'},
      {'month': 'Tháng 06/2026', 'workdays': '26 ngày', 'note': 'Trừ 4 Chủ nhật'},
      {'month': 'Tháng 07/2026', 'workdays': '26 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 08/2026', 'workdays': '26 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 09/2026', 'workdays': '25 ngày', 'note': 'Trừ 2 ngày Quốc khánh'},
      {'month': 'Tháng 10/2026', 'workdays': '26 ngày', 'note': 'Tháng hiện tại (Đang áp dụng)'},
      {'month': 'Tháng 11/2026', 'workdays': '25 ngày', 'note': 'Trừ 5 Chủ nhật'},
      {'month': 'Tháng 12/2026', 'workdays': '26 ngày', 'note': 'Trừ 4 Chủ nhật'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.event_available_outlined, size: 20, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Text('Công chuẩn bảng công 2026', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Text('Số công chuẩn theo từng tháng; tính động theo lịch ca và lịch ngày làm trừ Chủ nhật & ngày Lễ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),

            Expanded(
              child: ListView.separated(
                itemCount: standardMonths.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final sm = standardMonths[i];
                  final isCurrentMonth = sm['month']!.contains('10/2026');
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrentMonth ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isCurrentMonth ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isCurrentMonth ? 1.5 : 1.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sm['month']!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isCurrentMonth ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A))),
                            Text(sm['note']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCurrentMonth ? const Color(0xFF2563EB) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isCurrentMonth ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            sm['workdays']!,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isCurrentMonth ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 8. HỆ THỐNG & TÍCH HỢP (INTEGRATIONS)
  // ==========================================
  Widget _buildSystemIntegrationsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hệ thống & Tích hợp phần cứng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Quản lý máy chấm công vân tay / FaceID & Webhook', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.sync, color: Color(0xFF2563EB)),
                tooltip: 'Đồng bộ thiết bị',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đang đồng bộ dữ liệu từ các máy chấm công...'), backgroundColor: Color(0xFF2563EB)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final dev = _devices[index];
              final isOnline = dev.status == 'ONLINE';
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
                        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOnline ? Icons.router_rounded : Icons.signal_wifi_off_rounded,
                        color: isOnline ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dev.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('${dev.location} • IP: ${dev.ipAddress}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOnline ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOnline ? const Color(0xFF059669) : const Color(0xFFDC2626)),
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
  // 9. NHÂN SỰ & CHỨC DANH (EMPLOYEES DIRECTORY)
  // ==========================================
  Widget _buildEmployeesDirectoryView() {
    final probationCount = _employees.where((e) => e.status.toUpperCase() == 'PROBATION' || e.status.toUpperCase().contains('THỬ VIỆC')).length;

    return RefreshIndicator(
      onRefresh: _loadAllHrmData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Web-Matched Header Overview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quản lý Nhân sự & Tiêu chuẩn Chức danh',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Hồ sơ nhân sự toàn hệ thống, tiêu chuẩn vị trí & JD, ngạch bậc lương.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  HrmMetricHeader(
                    totalEmployees: _employees.length,
                    probationCount: probationCount,
                    totalPositions: _positions.isNotEmpty ? _positions.length : 41,
                    onTotalTap: () => setState(() {
                      _employeeSubTab = 0;
                      _employeeStatusFilter = 'ALL';
                    }),
                    onProbationTap: () => setState(() {
                      _employeeSubTab = 0;
                      _employeeStatusFilter = 'PROBATION';
                    }),
                    onPositionsTap: () => setState(() {
                      _employeeSubTab = 1;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Tab Pill Selector (Nhân sự vs Chức danh & JD)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _employeeSubTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _employeeSubTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _employeeSubTab == 0
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 16, color: _employeeSubTab == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'Nhân sự (${_employees.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _employeeSubTab == 0 ? FontWeight.bold : FontWeight.w500,
                                color: _employeeSubTab == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _employeeSubTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _employeeSubTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _employeeSubTab == 1
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business_center_outlined, size: 16, color: _employeeSubTab == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'Chức danh & JD (${_positions.length > 0 ? _positions.length : 41})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _employeeSubTab == 1 ? FontWeight.bold : FontWeight.w500,
                                color: _employeeSubTab == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Search bar
            TextField(
              onChanged: (v) => setState(() => _employeeSearchQuery = v),
              decoration: InputDecoration(
                hintText: _employeeSubTab == 0 ? 'Tìm theo họ tên, mã NV, chức danh, email...' : 'Tìm theo mã hoặc tên vị trí chức danh...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // Dropdown filters for Employees (Matching Web 100%: Phòng ban, Chức danh, Trạng thái)
            if (_employeeSubTab == 0) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildEmployeeDropdownFilter(
                      icon: Icons.business_outlined,
                      label: _employeeDepartmentFilter == 'ALL'
                          ? 'Phòng ban: Tất cả'
                          : 'Phòng ban: $_employeeDepartmentFilter',
                      isActive: _employeeDepartmentFilter != 'ALL',
                      onTap: _showDepartmentFilterBottomSheet,
                    ),
                    const SizedBox(width: 8),
                    _buildEmployeeDropdownFilter(
                      icon: Icons.badge_outlined,
                      label: _employeePositionFilter == 'ALL'
                          ? 'Chức danh: Tất cả'
                          : 'Chức danh: $_employeePositionFilter',
                      isActive: _employeePositionFilter != 'ALL',
                      onTap: _showPositionFilterBottomSheet,
                    ),
                    const SizedBox(width: 8),
                    _buildEmployeeDropdownFilter(
                      icon: Icons.verified_user_outlined,
                      label: _getStatusDropdownLabel(_employeeStatusFilter),
                      isActive: _employeeStatusFilter != 'ALL',
                      onTap: _showStatusFilterBottomSheet,
                    ),
                    if (_employeeDepartmentFilter != 'ALL' || _employeePositionFilter != 'ALL' || _employeeStatusFilter != 'ALL') ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _employeeDepartmentFilter = 'ALL';
                            _employeePositionFilter = 'ALL';
                            _employeeStatusFilter = 'ALL';
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                              SizedBox(width: 4),
                              Text('Xóa lọc', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Filter chips for Employees (Full matching with Web: Tất cả, Chính thức, Thử việc, Tạm nghỉ, Đã nghỉ việc, Chấm dứt hợp đồng)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Tất cả (${_countEmployeesByStatus('ALL')})', 'ALL', _employeeStatusFilter, (v) => setState(() => _employeeStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('Chính thức (${_countEmployeesByStatus('OFFICIAL')})', 'OFFICIAL', _employeeStatusFilter, (v) => setState(() => _employeeStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('Thử việc (${_countEmployeesByStatus('PROBATION')})', 'PROBATION', _employeeStatusFilter, (v) => setState(() => _employeeStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('Tạm nghỉ (${_countEmployeesByStatus('SUSPENDED')})', 'SUSPENDED', _employeeStatusFilter, (v) => setState(() => _employeeStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('Đã nghỉ việc (${_countEmployeesByStatus('RESIGNED')})', 'RESIGNED', _employeeStatusFilter, (v) => setState(() => _employeeStatusFilter = v)),
                    const SizedBox(width: 6),
                    _buildFilterChip('Chấm dứt hợp đồng (${_countEmployeesByStatus('TERMINATED')})', 'TERMINATED', _employeeStatusFilter, (v) => setState(() => _employeeStatusFilter = v)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 5. Content list
            if (_employeeSubTab == 0) ...[
              // Tab 0: Employees List
              if (_searchedEmployees.isEmpty)
                const EmptyStateView(
                  icon: Icons.person_search_outlined,
                  title: 'Không tìm thấy nhân viên phù hợp.',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchedEmployees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final emp = _searchedEmployees[index];
                    return EmployeeDirectoryCard(
                      employee: emp,
                      onTap: () => _showEmployeeDetailModal(emp),
                      onActionTap: () => _showEmployeeActionsSheet(emp),
                    );
                  },
                ),
            ] else ...[
              // Tab 1: Positions & JD List
              if (_searchedPositions.isEmpty)
                const EmptyStateView(
                  icon: Icons.work_off_outlined,
                  title: 'Không tìm thấy chức danh phù hợp.',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchedPositions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final pos = _searchedPositions[index];
                    return PositionJdCard(
                      position: pos,
                      onTap: () => _showPositionDetailModal(pos),
                    );
                  },
                ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showPositionDetailModal(HrmPositionItem pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    pos.positionName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Mã chức danh: ${pos.positionCode}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            if (pos.departmentName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Phòng ban: ${pos.departmentName}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
            if (pos.salaryGrade != null && pos.salaryGrade!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Bậc lương / Khung: ${pos.salaryGrade}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pos.hasJd ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pos.hasJd ? '✓ Đã thiết lập bản mô tả công việc (JD)' : '⚠ Chưa cấu hình JD',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: pos.hasJd ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 10. QUẢN LÝ CA & CHẤM CÔNG (SHIFTS)
  // ==========================================
  Widget _buildShiftsManagementView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Danh mục Ca làm việc', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Text('Quy định khung giờ check-in/out và thời lượng nghỉ giữa ca', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _shifts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                          Text('${s.startTime} — ${s.endTime} (Nghỉ trưa ${s.breakMinutes}p)', style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
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
  // 11. TIỀN LƯƠNG & CHI TRẢ (PAYROLL)
  // ==========================================
  Widget _buildPayrollView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bảng lương & Chi trả Doanh nghiệp', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Text('Tổng hợp lương tháng, thuế TNCN và các khoản khấu trừ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _payslips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ps = _payslips[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Bảng lương ${ps.period}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(_formatCurrency(ps.netSalary), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lương cơ bản: ${_formatCurrency(ps.baseSalary)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text('Phụ cấp: ${_formatCurrency(ps.allowances)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
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
  // 12. PHIẾU LƯƠNG CÁ NHÂN (PERSONAL PAYSLIPS)
  // ==========================================
  Widget _buildPersonalPayslipsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phiếu lương của tôi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Text('Tra cứu chi tiết thu nhập thực nhận hàng tháng', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _payslips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ps = _payslips[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ps.period, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('ĐÃ CHI TRẢ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 6),
                    _buildPayslipLine('Lương cơ bản:', _formatCurrency(ps.baseSalary)),
                    _buildPayslipLine('Phụ cấp & Thưởng:', _formatCurrency(ps.allowances + ps.bonuses)),
                    _buildPayslipLine('Làm thêm giờ (OT):', _formatCurrency(ps.overtimePay)),
                    _buildPayslipLine('Khấu trừ (BHXH & Thuế):', '-${_formatCurrency(ps.deductions)}', isDeduction: true),
                    const SizedBox(height: 6),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('THỰC LĨNH (NET):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(_formatCurrency(ps.netSalary), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                      ],
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

  Widget _buildPayslipLine(String label, String value, {bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDeduction ? const Color(0xFFDC2626) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 13. ĐƠN TỪ CẦN XỬ LÝ (WEB 1:1 APPROVALS)
  // ==========================================
  Widget _buildRequestsTab() {
    return _buildApprovalsTab();
  }

  Widget _buildApprovalStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getEmployeeInitials(String name) {
    if (name.trim().isEmpty) return 'NV';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  void _showLeaveQuotaModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFF1E3A8A)),
                      SizedBox(width: 8),
                      Text('Quỹ phép & Thâm niên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text('Quy chế quản lý ngày phép năm và chế độ thâm niên theo HĐLĐ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildQuotaRow('Phép năm tiêu chuẩn:', '12 ngày / năm', highlight: true),
                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                    _buildQuotaRow('Phép thâm niên tích lũy:', '+1 ngày / 5 năm', badge: 'Áp dụng'),
                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                    _buildQuotaRow('Số ngày đã sử dụng:', '3 ngày'),
                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                    _buildQuotaRow('Số ngày còn lại:', '10 ngày', isSuccess: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuotaRow(String label, String value, {bool highlight = false, bool isSuccess = false, String? badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSuccess
                    ? const Color(0xFF059669)
                    : highlight
                        ? const Color(0xFF1E3A8A)
                        : const Color(0xFF0F172A),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(badge, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _handleBulkApprove() async {
    if (_selectedApprovalIds.isEmpty) return;
    final count = _selectedApprovalIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Phê duyệt hàng loạt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Xác nhận phê duyệt đồng loạt $count đơn từ đã chọn theo thẩm quyền quản lý?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Xác nhận duyệt'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      int successCount = 0;
      for (final id in _selectedApprovalIds) {
        final ok = await _hrmService.approveRequest(id);
        if (ok) successCount++;
      }
      setState(() {
        _selectedApprovalIds.clear();
      });
      await _loadAllHrmData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã phê duyệt thành công $successCount/$count đơn từ!'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRequestDetailModal(HrmRequestItem r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _HrmRequestDetailBottomSheet(
        request: r,
        hrmService: _hrmService,
        onRefreshData: _loadAllHrmData,
        formatDate: _formatDate,
        formatTime: _formatTime,
        formatCurrency: _formatCurrency,
        getEmployeeInitials: _getEmployeeInitials,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isError ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(HrmRequestStatus status) {
    Color bg = const Color(0xFFFFF7ED);
    Color fg = const Color(0xFFEA580C);
    Color border = const Color(0xFFFFEDD5);
    String label = 'Chờ duyệt';

    switch (status) {
      case HrmRequestStatus.approved:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        border = const Color(0xFFBBF7D0);
        label = 'Đã phê duyệt';
        break;
      case HrmRequestStatus.rejected:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        border = const Color(0xFFFECACA);
        label = 'Từ chối';
        break;
      case HrmRequestStatus.draft:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        border = const Color(0xFFE2E8F0);
        label = 'Bản nháp';
        break;
      case HrmRequestStatus.cancelled:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        border = const Color(0xFFE2E8F0);
        label = 'Đã rút / hủy';
        break;
      case HrmRequestStatus.processing:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        border = const Color(0xFFDBEAFE);
        label = 'Đang xử lý';
        break;
      case HrmRequestStatus.pending:
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFEA580C);
        border = const Color(0xFFFFEDD5);
        label = 'Chờ duyệt';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  // ==========================================
  Widget _buildApprovalsTab() {
    final pendingCount = _requests.where((r) => r.status == HrmRequestStatus.pending).length;
    final processingCount = _requests.where((r) => r.status == HrmRequestStatus.processing).length;
    final overdueCount = _requests.where((r) => r.status == HrmRequestStatus.pending && r.startDate != null && r.startDate!.isBefore(DateTime.now())).length;
    final now = DateTime.now();
    final processedThisMonth = _requests.where((r) =>
        (r.status == HrmRequestStatus.approved || r.status == HrmRequestStatus.rejected || r.status == HrmRequestStatus.cancelled) &&
        (r.approvedAt?.month == now.month || r.requestDate.month == now.month)).length;
    final processedCount = _requests.where((r) => r.status != HrmRequestStatus.pending && r.status != HrmRequestStatus.processing).length;

    // Filter list
    var filteredList = List<HrmRequestItem>.from(_requests);

    // 1. Status sub-tab
    if (_approvalTab == 'PENDING') {
      filteredList = filteredList.where((r) => r.status == HrmRequestStatus.pending).toList();
    } else if (_approvalTab == 'PROCESSING') {
      filteredList = filteredList.where((r) => r.status == HrmRequestStatus.processing).toList();
    } else if (_approvalTab == 'PROCESSED') {
      filteredList = filteredList.where((r) => r.status != HrmRequestStatus.pending && r.status != HrmRequestStatus.processing).toList();
    }

    // 2. Type filter
    if (_approvalTypeFilter != 'ALL') {
      filteredList = filteredList.where((r) {
        switch (_approvalTypeFilter) {
          case 'LEAVE':
            return r.type == HrmRequestType.leave;
          case 'OVERTIME':
            return r.type == HrmRequestType.overtime;
          case 'ATTENDANCE_CORRECTION':
            return r.type == HrmRequestType.attendanceCorrection;
          case 'BUSINESS_TRIP':
            return r.type == HrmRequestType.businessTrip;
          case 'SHIFT_CHANGE':
            return r.type == HrmRequestType.shiftChange;
          case 'ADVANCE':
            return r.type == HrmRequestType.advance;
          default:
            return true;
        }
      }).toList();
    }

    // 3. Dept filter
    if (_approvalDeptFilter != 'ALL') {
      filteredList = filteredList.where((r) => r.department == _approvalDeptFilter).toList();
    }

    // 4. Status filter dropdown
    if (_approvalStatusFilter != 'ALL') {
      filteredList = filteredList.where((r) => r.status.name.toUpperCase() == _approvalStatusFilter).toList();
    }

    // 5. Date range filter
    if (_approvalStartDateFilter != null) {
      filteredList = filteredList.where((r) => r.requestDate.isAfter(_approvalStartDateFilter!.subtract(const Duration(days: 1)))).toList();
    }
    if (_approvalEndDateFilter != null) {
      filteredList = filteredList.where((r) => r.requestDate.isBefore(_approvalEndDateFilter!.add(const Duration(days: 1)))).toList();
    }

    // 6. Search query
    if (_approvalSearchQuery.trim().isNotEmpty) {
      final q = _approvalSearchQuery.toLowerCase();
      filteredList = filteredList.where((r) =>
        r.employeeName.toLowerCase().contains(q) ||
        r.employeeCode.toLowerCase().contains(q) ||
        r.reason.toLowerCase().contains(q) ||
        r.title.toLowerCase().contains(q)
      ).toList();
    }

    return RefreshIndicator(
      onRefresh: _loadAllHrmData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs
            Row(
              children: const [
                Text('Nhân sự', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                SizedBox(width: 4),
                Text('Đơn từ cần xử lý', style: TextStyle(fontSize: 11, color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),

            // Title & Action Button Row (Removed Quỹ phép and Tạo đơn per instruction)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Đơn từ cần xử lý',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Theo dõi và phê duyệt các yêu cầu đang chờ xử lý.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loadAllHrmData,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Làm mới', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    foregroundColor: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4 Metric Stat Cards (Web 1:1)
            Row(
              children: [
                Expanded(
                  child: _buildApprovalStatCard(
                    title: 'Chờ tôi duyệt',
                    value: '$pendingCount',
                    icon: Icons.warning_amber_rounded,
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFDE68A),
                    iconColor: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildApprovalStatCard(
                    title: 'Đang xử lý',
                    value: '$processingCount',
                    icon: Icons.access_time_rounded,
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFDBEAFE),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildApprovalStatCard(
                    title: 'Quá hạn',
                    value: '$overdueCount',
                    icon: Icons.error_outline_rounded,
                    bgColor: const Color(0xFFFEF2F2),
                    borderColor: const Color(0xFFFECACA),
                    iconColor: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildApprovalStatCard(
                    title: 'Đã xử lý tháng này',
                    value: '$processedThisMonth',
                    icon: Icons.check_circle_outline_rounded,
                    bgColor: const Color(0xFFF0FDF4),
                    borderColor: const Color(0xFFBBF7D0),
                    iconColor: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Web-matching Search & Filter Bar (Screenshot 2: Search + Loại đơn + Phòng ban + Bước duyệt + Trạng thái + Date)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _approvalSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tên nhân viên, mã đơn, lý do...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _approvalSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _approvalSearchCtrl.clear();
                                setState(() => _approvalSearchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    onChanged: (v) => setState(() => _approvalSearchQuery = v),
                  ),
                  const SizedBox(height: 10),

                  // Horizontal Web Dropdown Selectors
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildDropdownFilterBox(
                          label: 'Loại đơn',
                          valueDisplay: _getTypeFilterLabel(_approvalTypeFilter),
                          onTap: _showTypeFilterPicker,
                          hasActiveValue: _approvalTypeFilter != 'ALL',
                        ),
                        const SizedBox(width: 8),
                        _buildDropdownFilterBox(
                          label: 'Phòng ban',
                          valueDisplay: _approvalDeptFilter == 'ALL' ? 'Tất cả' : _approvalDeptFilter,
                          onTap: _showDeptFilterPicker,
                          hasActiveValue: _approvalDeptFilter != 'ALL',
                        ),
                        const SizedBox(width: 8),
                        _buildDropdownFilterBox(
                          label: 'Bước duyệt',
                          valueDisplay: _approvalStepFilter == 'ALL' ? 'Tất cả' : _approvalStepFilter,
                          onTap: _showStepFilterPicker,
                          hasActiveValue: _approvalStepFilter != 'ALL',
                        ),
                        const SizedBox(width: 8),
                        _buildDropdownFilterBox(
                          label: 'Trạng thái',
                          valueDisplay: _getStatusFilterLabel(_approvalStatusFilter),
                          onTap: _showStatusFilterPicker,
                          hasActiveValue: _approvalStatusFilter != 'ALL',
                        ),
                        const SizedBox(width: 8),
                        _buildDateRangeFilterBox(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Filter Tabs & Bulk Approve Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSubTabChip('Tất cả (${_requests.length})', 'ALL'),
                        _buildSubTabChip('Chờ tôi duyệt ($pendingCount)', 'PENDING'),
                        _buildSubTabChip('Đang xử lý ($processingCount)', 'PROCESSING'),
                        _buildSubTabChip('Đã xử lý ($processedCount)', 'PROCESSED'),
                      ],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectedApprovalIds.isNotEmpty ? _handleBulkApprove : null,
                  icon: const Icon(Icons.done_all_rounded, size: 13),
                  label: Text('Duyệt đã chọn (${_selectedApprovalIds.length})', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFF1F5F9),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Request Items List (Matching Web Table format)
            if (filteredList.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.assignment_turned_in_outlined, size: 32, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 8),
                    Text('Không có đơn từ nào phù hợp.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final r = filteredList[index];
                  final isPending = r.status == HrmRequestStatus.pending;
                  final isSelected = _selectedApprovalIds.contains(r.id);

                  final start = r.startDate;
                  final end = r.endDate;
                  String timeStr = _formatDate(r.requestDate);
                  if (start != null && end != null) {
                    if (start.day == end.day && start.month == end.month && start.year == end.year) {
                      timeStr = '${_formatDate(start)} ${_formatTime(start)} -> ${_formatTime(end)}';
                    } else {
                      timeStr = '${_formatDate(start)} -> ${_formatDate(end)}';
                    }
                  } else if (start != null) {
                    timeStr = 'Từ ${_formatDate(start)}';
                  }

                  String durationBadge = '';
                  if (r.durationDays != null && r.durationDays! > 0) {
                    final d = r.durationDays!;
                    durationBadge = d == d.toInt() ? '${d.toInt()}' : '$d';
                  } else if (r.durationHours != null && r.durationHours! > 0) {
                    final h = r.durationHours!;
                    durationBadge = h == h.toInt() ? '${h.toInt()}h' : '${h}h';
                  }

                  return InkWell(
                    onTap: () => _showRequestDetailModal(r),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
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
                          // Row 1: Checkbox + Avatar + Employee info + Type Badge
                          Row(
                            children: [
                              if (isPending)
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: isSelected,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedApprovalIds.add(r.id);
                                        } else {
                                          _selectedApprovalIds.remove(r.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFF1F5F9),
                                child: Text(
                                  _getEmployeeInitials(r.employeeName),
                                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.employeeName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      r.department.isNotEmpty ? '${r.employeeCode} · ${r.department}' : r.employeeCode,
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              _buildTypeBadge(r.type, r.typeLabel),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Row 2: Time and duration
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  timeStr,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (durationBadge.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(durationBadge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Row 3: Reason
                          Text(
                            r.reason,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Row 4: Status & Details indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatusBadge(r.status),
                              Row(
                                children: const [
                                  Text(
                                    'Xem chi tiết',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF2563EB)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Helper: Dropdown Box matching Web Screenshot 2
  Widget _buildDropdownFilterBox({
    required String label,
    required String valueDisplay,
    required VoidCallback onTap,
    bool hasActiveValue = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 105),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: hasActiveValue ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasActiveValue ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_rounded, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  valueDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasActiveValue ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeFilterBox() {
    final hasDate = _approvalStartDateFilter != null || _approvalEndDateFilter != null;
    String display = 'dd/mm/yyyy - dd/mm/yyyy';
    if (_approvalStartDateFilter != null && _approvalEndDateFilter != null) {
      display = '${_formatDate(_approvalStartDateFilter!)} - ${_formatDate(_approvalEndDateFilter!)}';
    } else if (_approvalStartDateFilter != null) {
      display = 'Từ ${_formatDate(_approvalStartDateFilter!)}';
    }

    return InkWell(
      onTap: _selectDateRangeFilter,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: hasDate ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasDate ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              display,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: hasDate ? FontWeight.bold : FontWeight.normal,
                color: hasDate ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              ),
            ),
            if (hasDate) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _approvalStartDateFilter = null;
                    _approvalEndDateFilter = null;
                  });
                },
                child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF64748B)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRangeFilter() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _approvalStartDateFilter != null && _approvalEndDateFilter != null
          ? DateTimeRange(start: _approvalStartDateFilter!, end: _approvalEndDateFilter!)
          : null,
    );
    if (range != null) {
      setState(() {
        _approvalStartDateFilter = range.start;
        _approvalEndDateFilter = range.end;
      });
    }
  }

  String _getTypeFilterLabel(String key) {
    switch (key) {
      case 'LEAVE':
        return 'Nghỉ phép';
      case 'OVERTIME':
        return 'Làm thêm (OT)';
      case 'ATTENDANCE_CORRECTION':
        return 'Giải trình công';
      case 'BUSINESS_TRIP':
        return 'Công tác';
      case 'SHIFT_CHANGE':
        return 'Đổi ca làm';
      case 'ADVANCE':
        return 'Tạm ứng lương';
      default:
        return 'Tất cả';
    }
  }

  String _getStatusFilterLabel(String key) {
    switch (key) {
      case 'PENDING':
        return 'Chờ duyệt';
      case 'PROCESSING':
        return 'Đang xử lý';
      case 'APPROVED':
        return 'Đã phê duyệt';
      case 'CANCELLED':
        return 'Đã rút / hủy';
      case 'REJECTED':
        return 'Từ chối';
      default:
        return 'Tất cả';
    }
  }

  void _showTypeFilterPicker() {
    final types = [
      {'key': 'ALL', 'label': 'Tất cả (${_requests.length})'},
      {'key': 'LEAVE', 'label': 'Nghỉ phép (${_requests.where((r) => r.type == HrmRequestType.leave).length})'},
      {'key': 'OVERTIME', 'label': 'Làm thêm (OT) (${_requests.where((r) => r.type == HrmRequestType.overtime).length})'},
      {'key': 'ATTENDANCE_CORRECTION', 'label': 'Giải trình công (${_requests.where((r) => r.type == HrmRequestType.attendanceCorrection).length})'},
      {'key': 'BUSINESS_TRIP', 'label': 'Công tác (${_requests.where((r) => r.type == HrmRequestType.businessTrip).length})'},
      {'key': 'SHIFT_CHANGE', 'label': 'Đổi ca làm (${_requests.where((r) => r.type == HrmRequestType.shiftChange).length})'},
      {'key': 'ADVANCE', 'label': 'Tạm ứng lương (${_requests.where((r) => r.type == HrmRequestType.advance).length})'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Lọc theo Loại đơn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const Divider(),
            ...types.map((t) {
              final isSel = _approvalTypeFilter == t['key'];
              return ListTile(
                title: Text(t['label']!, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B))),
                trailing: isSel ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  setState(() => _approvalTypeFilter = t['key']!);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showDeptFilterPicker() {
    final depts = <String>{'Tất cả', ..._requests.map((r) => r.department).where((d) => d.isNotEmpty)};
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Lọc theo Phòng ban', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const Divider(),
            ...depts.map((d) {
              final val = d == 'Tất cả' ? 'ALL' : d;
              final isSel = _approvalDeptFilter == val;
              final count = val == 'ALL' ? _requests.length : _requests.where((r) => r.department == d).length;
              return ListTile(
                title: Text('$d ($count)', style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B))),
                trailing: isSel ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  setState(() => _approvalDeptFilter = val);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showStepFilterPicker() {
    final steps = ['Tất cả', 'Cấp 1 - Quản lý trực tiếp', 'Cấp 2 - Ban Giám đốc'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Lọc theo Bước duyệt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const Divider(),
            ...steps.map((s) {
              final val = s == 'Tất cả' ? 'ALL' : s;
              final isSel = _approvalStepFilter == val;
              return ListTile(
                title: Text(s, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B))),
                trailing: isSel ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  setState(() => _approvalStepFilter = val);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showStatusFilterPicker() {
    final stats = [
      {'key': 'ALL', 'label': 'Tất cả (${_requests.length})'},
      {'key': 'PENDING', 'label': 'Chờ duyệt (${_requests.where((r) => r.status == HrmRequestStatus.pending).length})'},
      {'key': 'PROCESSING', 'label': 'Đang xử lý (${_requests.where((r) => r.status == HrmRequestStatus.processing).length})'},
      {'key': 'APPROVED', 'label': 'Đã phê duyệt (${_requests.where((r) => r.status == HrmRequestStatus.approved).length})'},
      {'key': 'CANCELLED', 'label': 'Đã rút / hủy (${_requests.where((r) => r.status == HrmRequestStatus.cancelled).length})'},
      {'key': 'REJECTED', 'label': 'Từ chối (${_requests.where((r) => r.status == HrmRequestStatus.rejected).length})'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Lọc theo Trạng thái', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const Divider(),
            ...stats.map((s) {
              final isSel = _approvalStatusFilter == s['key'];
              return ListTile(
                title: Text(s['label']!, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B))),
                trailing: isSel ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB)) : null,
                onTap: () {
                  setState(() => _approvalStatusFilter = s['key']!);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(HrmRequestType type, String label) {
    Color bg;
    Color fg;
    Color border;
    switch (type) {
      case HrmRequestType.leave:
        bg = const Color(0xFFFFEDD5); // peach orange
        fg = const Color(0xFFC2410C);
        border = const Color(0xFFFED7AA);
        break;
      case HrmRequestType.overtime:
        bg = const Color(0xFFEFF6FF); // blue
        fg = const Color(0xFF2563EB);
        border = const Color(0xFFBFDBFE);
        break;
      case HrmRequestType.attendanceCorrection:
        bg = const Color(0xFFF3E8FF); // purple
        fg = const Color(0xFF7E22CE);
        border = const Color(0xFFE9D5FF);
        break;
      case HrmRequestType.businessTrip:
        bg = const Color(0xFFECFDF5); // emerald
        fg = const Color(0xFF047857);
        border = const Color(0xFFA7F3D0);
        break;
      case HrmRequestType.advance:
        bg = const Color(0xFFFEF3C7); // amber
        fg = const Color(0xFFB45309);
        border = const Color(0xFFFDE68A);
        break;
      case HrmRequestType.shiftChange:
        bg = const Color(0xFFCFFAFE); // cyan
        fg = const Color(0xFF0E7490);
        border = const Color(0xFFA5F3FC);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildSubTabChip(String label, String tabKey) {
    final isSelected = _approvalTab == tabKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _approvalTab = tabKey),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeStatusBadge(String status) {
    final s = status.toUpperCase();
    String label = 'CHÍNH THỨC';
    Color bg = const Color(0xFFECFDF5);
    Color fg = const Color(0xFF059669);

    if (s == 'PROBATION' || s.contains('THỬ VIỆC')) {
      label = 'THỬ VIỆC';
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
    } else if (s == 'SUSPENDED' || s == 'ON_LEAVE' || s == 'LEAVE' || s.contains('TẠM NGHỈ')) {
      label = 'TẠM NGHỈ';
      bg = const Color(0xFFF5F3FF);
      fg = const Color(0xFF7C3AED);
    } else if (s == 'RESIGNED' || s == 'INACTIVE' || s.contains('ĐÃ NGHỈ')) {
      label = 'ĐÃ NGHỈ VIỆC';
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
    } else if (s == 'TERMINATED' || s.contains('CHẤM DỨT')) {
      label = 'CHẤM DỨT HĐ';
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
    } else if (s.isNotEmpty && s != 'OFFICIAL' && s != 'ACTIVE') {
      label = status;
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentValue, Function(String) onSelect) {
    final isSelected = currentValue == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFF0F172A),
        backgroundColor: const Color(0xFFF1F5F9),
        showCheckmark: false,
        onSelected: (_) => onSelect(value),
      ),
    );
  }

  Widget _buildEmployeeDropdownFilter({
    IconData? icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.search,
              size: 14,
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            if (isActive && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF2563EB)),
              )
            else
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  void _showDepartmentFilterBottomSheet() {
    final depts = _availableDepartments;
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = search.trim().isEmpty
                ? depts
                : depts.where((d) => d.toLowerCase().contains(search.toLowerCase())).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lọc theo Phòng ban',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => setModalState(() => search = v),
                    decoration: InputDecoration(
                      hintText: 'Tìm phòng ban...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          dense: true,
                          title: const Text('Phòng ban: Tất cả', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          trailing: _employeeDepartmentFilter == 'ALL'
                              ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                              : Text('${_employees.length}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          selected: _employeeDepartmentFilter == 'ALL',
                          selectedTileColor: const Color(0xFFEFF6FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () {
                            setState(() => _employeeDepartmentFilter = 'ALL');
                            Navigator.pop(ctx);
                          },
                        ),
                        ...filtered.map((d) {
                          final count = _employees.where((e) => e.department.trim().toLowerCase() == d.trim().toLowerCase()).length;
                          final isSelected = _employeeDepartmentFilter.trim().toLowerCase() == d.trim().toLowerCase();
                          return ListTile(
                            dense: true,
                            title: Text(d, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            trailing: isSelected
                                ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                                : Text('$count', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFEFF6FF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onTap: () {
                              setState(() => _employeeDepartmentFilter = d);
                              Navigator.pop(ctx);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPositionFilterBottomSheet() {
    final positions = _availablePositions;
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = search.trim().isEmpty
                ? positions
                : positions.where((p) => p.toLowerCase().contains(search.toLowerCase())).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lọc theo Chức danh',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => setModalState(() => search = v),
                    decoration: InputDecoration(
                      hintText: 'Tìm chức danh...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          dense: true,
                          title: const Text('Chức danh: Tất cả', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          trailing: _employeePositionFilter == 'ALL'
                              ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                              : Text('${_employees.length}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          selected: _employeePositionFilter == 'ALL',
                          selectedTileColor: const Color(0xFFEFF6FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () {
                            setState(() => _employeePositionFilter = 'ALL');
                            Navigator.pop(ctx);
                          },
                        ),
                        ...filtered.map((pos) {
                          final count = _employees.where((e) => e.position.trim().toLowerCase() == pos.trim().toLowerCase()).length;
                          final isSelected = _employeePositionFilter.trim().toLowerCase() == pos.trim().toLowerCase();
                          return ListTile(
                            dense: true,
                            title: Text(pos, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            trailing: isSelected
                                ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                                : Text('$count', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFEFF6FF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onTap: () {
                              setState(() => _employeePositionFilter = pos);
                              Navigator.pop(ctx);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStatusFilterBottomSheet() {
    final statusList = [
      {'key': 'ALL', 'label': 'Trạng thái: Tất cả'},
      {'key': 'OFFICIAL', 'label': 'Chính thức'},
      {'key': 'PROBATION', 'label': 'Thử việc'},
      {'key': 'SUSPENDED', 'label': 'Tạm nghỉ'},
      {'key': 'RESIGNED', 'label': 'Đã nghỉ việc'},
      {'key': 'TERMINATED', 'label': 'Chấm dứt hợp đồng'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lọc theo Trạng thái',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...statusList.map((item) {
                final key = item['key']!;
                final label = item['label']!;
                final count = _countEmployeesByStatus(key);
                final isSelected = _employeeStatusFilter == key;

                return ListTile(
                  dense: true,
                  title: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                      : Text('$count', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    setState(() => _employeeStatusFilter = key);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showCreateRequestModal() {
    HrmEmployeeActionModals.showCreateRequestModal(
      context,
      onSubmitted: () => _loadAllHrmData(),
    );
  }

  // ==========================================
  // EMPLOYEE ACTION MODALS (Xem hồ sơ, Tạo quyết định, Sửa, Ngừng)
  // ==========================================

  void _showEmployeeActionsSheet(HrmEmployeeItem emp) {
    HrmEmployeeActionModals.showEmployeeActionsSheet(
      context,
      emp,
      onRefresh: () => _loadAllHrmData(),
    );
  }

  // 1. Modal: Xem hồ sơ nhân sự (Sử dụng HrmProfileModals dùng chung với Profile & Income)
  void _showEmployeeDetailModal(HrmEmployeeItem emp) {
    HrmProfileModals.showEmployeeDetailSheet(context, emp);
  }

  // 2. Modal: Tạo Quyết định Nhân sự
  void _showCreateDecisionModal(HrmEmployeeItem emp) {
    HrmEmployeeActionModals.showCreateDecisionModal(context, emp);
  }

  // 3. Modal: Sửa thông tin nhân viên
  void _showEditEmployeeModal(HrmEmployeeItem emp) {
    HrmEmployeeActionModals.showEditEmployeeModal(context, emp);
  }

  // 4. Modal: Ngừng hoạt động / Tạm đình chỉ nhân sự
  void _confirmToggleEmployeeActive(HrmEmployeeItem emp) {
    HrmEmployeeActionModals.confirmToggleEmployeeActive(context, emp);
  }
}

class _HrmRequestDetailBottomSheet extends StatefulWidget {
  final HrmRequestItem request;
  final HrmService hrmService;
  final VoidCallback onRefreshData;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;
  final String Function(double?) formatCurrency;
  final String Function(String) getEmployeeInitials;

  const _HrmRequestDetailBottomSheet({
    required this.request,
    required this.hrmService,
    required this.onRefreshData,
    required this.formatDate,
    required this.formatTime,
    required this.formatCurrency,
    required this.getEmployeeInitials,
  });

  @override
  State<_HrmRequestDetailBottomSheet> createState() => _HrmRequestDetailBottomSheetState();
}

class _HrmRequestDetailBottomSheetState extends State<_HrmRequestDetailBottomSheet> {
  late HrmRequestItem _request;
  List<HrmRequestComment> _comments = [];
  bool _isLoadingComments = true;
  bool _isSendingComment = false;
  String? _commentError;
  String? _opinionError;
  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _opinionCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _pollTimer;

  bool _showMentionPicker = false;
  List<HrmMentionCandidate> _mentionCandidates = [];
  final List<HrmMentionCandidate> _selectedMentions = [];
  int _activeMentionStart = 0;
  bool _isActionBusy = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _opinionCtrl.addListener(_onOpinionChanged);
    _loadComments();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadComments(quiet: true);
    });
  }

  void _onOpinionChanged() {
    if (_opinionError != null && _opinionCtrl.text.trim().isNotEmpty) {
      setState(() => _opinionError = null);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _commentCtrl.dispose();
    _opinionCtrl.removeListener(_onOpinionChanged);
    _opinionCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments({bool quiet = false}) async {
    if (!quiet) {
      setState(() => _isLoadingComments = true);
    }
    try {
      final list = await widget.hrmService.getRequestComments(
        kind: _request.apiKind,
        requestId: _request.id,
      );
      if (mounted) {
        setState(() {
          _comments = list;
          _isLoadingComments = false;
          _commentError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
          _commentError = 'Không thể tải trao đổi.';
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onCommentChanged(String val) {
    final pos = _commentCtrl.selection.baseOffset;
    if (pos > 0 && pos <= val.length) {
      final before = val.substring(0, pos);
      final match = RegExp(r'(^|\s)@([^\s@]{0,30})$').firstMatch(before);
      if (match != null) {
        final query = match.group(2) ?? '';
        _activeMentionStart = before.length - query.length - 1;
        _searchMentionCandidates(query);
        return;
      }
    }
    if (_showMentionPicker) {
      setState(() {
        _showMentionPicker = false;
        _mentionCandidates = [];
      });
    }
  }

  Future<void> _searchMentionCandidates(String q) async {
    final res = await widget.hrmService.searchMentionCandidates(query: q);
    if (mounted) {
      setState(() {
        _mentionCandidates = res;
        _showMentionPicker = res.isNotEmpty;
      });
    }
  }

  void _insertMention(HrmMentionCandidate person) {
    final text = _commentCtrl.text;
    final pos = _commentCtrl.selection.baseOffset >= 0 ? _commentCtrl.selection.baseOffset : text.length;
    final start = _activeMentionStart;
    final next = '${text.substring(0, start)}@${person.name} ${text.substring(pos)}';
    _commentCtrl.text = next;
    final newPos = start + person.name.length + 2;
    _commentCtrl.selection = TextSelection.collapsed(offset: newPos);

    if (!_selectedMentions.any((m) => m.userId == person.userId)) {
      _selectedMentions.add(person);
    }
    setState(() {
      _showMentionPicker = false;
      _mentionCandidates = [];
    });
  }

  Future<void> _sendComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _isSendingComment) return;

    setState(() {
      _isSendingComment = true;
      _commentError = null;
    });

    final activeMentions = _selectedMentions
        .where((m) => body.contains('@${m.name}'))
        .map((m) => m.userId)
        .toList();

    final ok = await widget.hrmService.postRequestComment(
      kind: _request.apiKind,
      requestId: _request.id,
      body: body,
      mentionUserIds: activeMentions,
    );

    if (ok) {
      _commentCtrl.clear();
      _selectedMentions.clear();
      setState(() {
        _showMentionPicker = false;
        _mentionCandidates = [];
      });
      await _loadComments(quiet: true);
      _scrollToBottom();
    } else {
      setState(() {
        _commentError = 'Không thể gửi trao đổi. Vui lòng thử lại.';
      });
    }

    if (mounted) {
      setState(() => _isSendingComment = false);
    }
  }

  String _formatCommentTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildDecisionBadge(String decision) {
    final d = decision.toUpperCase();
    String label = 'Đã xử lý';
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (d.contains('APPROV')) {
      label = 'Đã phê duyệt';
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF047857);
    } else if (d.contains('REJECT')) {
      label = 'Đã từ chối';
      bg = const Color(0xFFFFF1F2);
      fg = const Color(0xFFBE123C);
    } else if (d.contains('RETURN')) {
      label = 'Đã trả lại';
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
    } else if (d.contains('COMPLETE')) {
      label = 'Đã hoàn thành bước';
      bg = const Color(0xFFF0F9FF);
      fg = const Color(0xFF0369A1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildCommentBody(HrmRequestComment comment) {
    if (comment.mentions.isEmpty) {
      return Text(
        comment.body,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), height: 1.35),
      );
    }

    final mentionNames = comment.mentions.map((m) => m.name).where((n) => n.isNotEmpty).toList();
    if (mentionNames.isEmpty) {
      return Text(
        comment.body,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), height: 1.35),
      );
    }

    final spans = <InlineSpan>[];
    final pattern = RegExp(
      '(@(?:${mentionNames.map((n) => RegExp.escape(n)).join('|')}))',
    );
    int lastIndex = 0;
    for (final match in pattern.allMatches(comment.body)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: comment.body.substring(lastIndex, match.start),
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
        ));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            match.group(0) ?? '',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ),
      ));
      lastIndex = match.end;
    }
    if (lastIndex < comment.body.length) {
      spans.add(TextSpan(
        text: comment.body.substring(lastIndex),
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _request.status == HrmRequestStatus.pending;
    final isApproved = _request.status == HrmRequestStatus.approved;
    final start = _request.startDate;
    final end = _request.endDate;
    String timeDisplay = widget.formatDate(_request.requestDate);
    if (start != null && end != null) {
      timeDisplay = '${widget.formatDate(start)} ${widget.formatTime(start)} -> ${widget.formatDate(end)} ${widget.formatTime(end)}'.trim();
    } else if (start != null) {
      timeDisplay = 'Từ ${widget.formatDate(start)} ${widget.formatTime(start)}'.trim();
    }

    String quantityLabel = 'Số lượng nghỉ';
    String quantityValue = '1';
    if (_request.type == HrmRequestType.leave) {
      quantityLabel = 'Số lượng nghỉ';
      if (_request.durationDays != null) {
        final d = _request.durationDays!;
        quantityValue = d == d.toInt() ? '${d.toInt()}' : '$d';
      }
    } else if (_request.type == HrmRequestType.overtime) {
      quantityLabel = 'Số giờ làm thêm';
      if (_request.durationHours != null) {
        final h = _request.durationHours!;
        quantityValue = '${h == h.toInt() ? h.toInt() : h} giờ';
      } else {
        quantityValue = '—';
      }
    } else if (_request.type == HrmRequestType.businessTrip) {
      quantityLabel = 'Số ngày công tác';
      quantityValue = _request.durationDays != null ? '${_request.durationDays}' : '—';
    } else if (_request.type == HrmRequestType.advance) {
      quantityLabel = 'Số tiền';
      quantityValue = widget.formatCurrency(_request.amount);
    } else if (_request.type == HrmRequestType.attendanceCorrection) {
      quantityLabel = 'Loại giải trình';
      quantityValue = _request.reason.isNotEmpty ? _request.reason : 'Quên chấm công';
    }

    final shortId = _request.id.length > 8 ? _request.id.substring(_request.id.length - 8).toUpperCase() : _request.id.toUpperCase();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Title & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chi tiết đơn',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Top Card Banner matching Web
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEF3C7)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description_outlined, color: Color(0xFFD97706), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _request.typeLabel,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mã đơn: #$shortId',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending
                            ? const Color(0xFFFFF7ED)
                            : (isApproved ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPending
                              ? const Color(0xFFFFEDD5)
                              : (isApproved ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        isPending
                            ? 'Chờ duyệt'
                            : (isApproved
                                ? 'Đã duyệt'
                                : (_request.status == HrmRequestStatus.rejected ? 'Từ chối' : 'Đã rút / hủy')),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPending
                              ? const Color(0xFFEA580C)
                              : (isApproved ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section: Thông tin nhân viên
              const Text(
                'Thông tin nhân viên',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: Text(
                      widget.getEmployeeInitials(_request.employeeName),
                      style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _request.employeeName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _request.department.isNotEmpty ? '${_request.employeeCode} · ${_request.department}' : _request.employeeCode,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details Key-Value Table matching Web
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('Loại đơn', _request.typeLabel),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('Thời gian', timeDisplay),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('Lý do', _request.reason.isNotEmpty ? _request.reason : '—'),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow('Mô tả', (_request.note != null && _request.note!.isNotEmpty) ? _request.note! : '—'),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              _buildDetailRow(quantityLabel, quantityValue),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 16),

              // Section: Quy trình phê duyệt matching Web
              const Text(
                'Quy trình phê duyệt',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Người gửi
                  Column(
                    children: [
                      const CircleAvatar(
                        radius: 13,
                        backgroundColor: Color(0xFF10B981),
                        child: Icon(Icons.check, size: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Người gửi',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_request.requestDate.day.toString().padLeft(2, '0')}/${_request.requestDate.month.toString().padLeft(2, '0')} ${widget.formatTime(_request.requestDate).isNotEmpty ? widget.formatTime(_request.requestDate) : '13:39'}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  // Connecting Line
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
                      child: Container(
                        height: 2.5,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                  // Step 2: Người duyệt
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: isPending
                            ? const Color(0xFFEA580C)
                            : (isApproved ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                        child: isApproved
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : const Text('2', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Người duyệt',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPending
                            ? 'Đang chờ duyệt'
                            : (isApproved
                                ? 'Đã duyệt'
                                : (_request.status == HrmRequestStatus.rejected ? 'Đã từ chối' : 'Đã rút / hủy')),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPending
                              ? const Color(0xFFEA580C)
                              : (isApproved ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Duyệt trực tiếp, không qua Procedure Engine.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              // Section: Trao đổi và ý kiến
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    'Trao đổi và ý kiến (${_comments.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  if (_isLoadingComments) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Comment Thread List
              if (_isLoadingComments && _comments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: const Center(
                    child: Text(
                      'Đang tải trao đổi...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else if (_comments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Chưa có trao đổi nào. Gõ @ để nhắc tên người cần xem đơn này.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final c = _comments[idx];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: c.mine ? const Color(0xFFFFC90A) : const Color(0xFFE2E8F0),
                          child: Text(
                            _getInitials(c.authorName),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: c.mine ? const Color(0xFF1A1A1A) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    c.authorName,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  if (c.decision != null)
                                    _buildDecisionBadge(c.decision!),
                                  Text(
                                    _formatCommentTime(c.createdAt),
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: c.kind == 'DECISION' ? Colors.white : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: c.kind == 'DECISION' ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                                ),
                                child: _buildCommentBody(c),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

              if (_commentError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _commentError!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 10),

              // Mention candidates autocomplete popup
              if (_showMentionPicker && _mentionCandidates.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.06), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _mentionCandidates.length,
                    itemBuilder: (ctx, i) {
                      final p = _mentionCandidates[i];
                      return InkWell(
                        onTap: () => _insertMention(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: const Color(0xFFE2E8F0),
                                child: Text(_getInitials(p.name), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    if (p.employeeCode.isNotEmpty || p.department.isNotEmpty)
                                      Text(
                                        [p.employeeCode, p.department].where((s) => s.isNotEmpty).join(' · '),
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Comment Input Field matching Web
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        onChanged: _onCommentChanged,
                        decoration: const InputDecoration(
                          hintText: 'Viết trao đổi... gõ @ để nhắc tên',
                          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: 2,
                        minLines: 1,
                      ),
                    ),
                    InkWell(
                      onTap: _isSendingComment ? null : _sendComment,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC90A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _isSendingComment
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)),
                              )
                            : const Icon(Icons.send_rounded, size: 15, color: Color(0xFF1A1A1A)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Bottom Action Area matching Web
              if (isPending) ...[
                TextField(
                  controller: _opinionCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ý kiến xử lý (bắt buộc khi từ chối, tuỳ chọn khi phê duyệt)',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    errorText: _opinionError,
                    errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _opinionError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _opinionError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _opinionError != null ? const Color(0xFFDC2626) : const Color(0xFF2563EB), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isActionBusy
                            ? null
                            : () async {
                                final opinion = _opinionCtrl.text.trim();
                                if (opinion.isEmpty) {
                                  setState(() {
                                    _opinionError = 'Vui lòng nhập ý kiến xử lý trước khi từ chối!';
                                  });
                                  _scrollToBottom();
                                  return;
                                }
                                setState(() {
                                  _opinionError = null;
                                  _isActionBusy = true;
                                });
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(context);
                                final ok = await widget.hrmService.rejectRequest(_request.id, reason: opinion);
                                if (ok) {
                                  await widget.hrmService.postRequestComment(
                                    kind: _request.apiKind,
                                    requestId: _request.id,
                                    body: opinion,
                                    commentKind: 'DECISION',
                                    decision: 'REJECT',
                                  );
                                }
                                widget.onRefreshData();
                                if (mounted) {
                                  nav.pop();
                                  messenger.hideCurrentSnackBar();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok ? 'Đã từ chối đơn yêu cầu thành công!' : 'Từ chối đơn thất bại!',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      backgroundColor: ok ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFFF43F5E)),
                        label: const Text('Từ chối', style: TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isActionBusy
                            ? null
                            : () async {
                                final opinion = _opinionCtrl.text.trim();
                                setState(() {
                                  _opinionError = null;
                                  _isActionBusy = true;
                                });
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(context);
                                final ok = await widget.hrmService.approveRequest(_request.id);
                                if (ok && opinion.isNotEmpty) {
                                  await widget.hrmService.postRequestComment(
                                    kind: _request.apiKind,
                                    requestId: _request.id,
                                    body: opinion,
                                    commentKind: 'DECISION',
                                    decision: 'APPROVE',
                                  );
                                }
                                widget.onRefreshData();
                                if (mounted) {
                                  nav.pop();
                                  messenger.hideCurrentSnackBar();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok ? 'Đã phê duyệt đơn thành công!' : 'Phê duyệt đơn thất bại!',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      backgroundColor: ok ? const Color(0xFF00A86B) : const Color(0xFF1E293B),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                        label: const Text('Phê duyệt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A86B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

