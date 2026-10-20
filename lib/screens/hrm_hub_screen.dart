import 'dart:async';
import 'package:flutter/material.dart';
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
  int _employeeSubTab = 0; // 0: Nhân sự (Employees), 1: Chức danh & JD (Positions)
  String _selectedTimesheetMonth = 'Tháng 09/2026';

  @override
  void dispose() {
    _approvalSearchCtrl.dispose();
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

  Future<void> _loadAllHrmData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _hrmService.getDashboardStats(),
      _hrmService.getRequests(),
      _hrmService.getEmployees(forceRefresh: true),
      _hrmService.getPayslips(),
      _hrmService.getShifts(),
      _attendanceService.getTodayAttendance(),
      _hrmService.getDependents(),
      _hrmService.getSalaryAdvances(),
      _hrmService.getTimesheetSummaries(),
      _hrmService.getPolicyConfig(),
      _hrmService.getIntegrationDevices(),
      _hrmService.getPositions(forceRefresh: true),
    ]);

    if (mounted) {
      setState(() {
        _stats = results[0] as HrmDashboardStats;
        _requests = results[1] as List<HrmRequestItem>;
        _employees = results[2] as List<HrmEmployeeItem>;
        _payslips = results[3] as List<HrmPayslipItem>;
        _shifts = results[4] as List<HrmShift>;
        _todayAttendance = results[5] as AttendanceRecord?;
        _dependents = results[6] as List<HrmDependentItem>;
        _advances = results[7] as List<HrmSalaryAdvanceItem>;
        _timesheets = results[8] as List<HrmTimesheetSummaryItem>;
        _policyConfig = results[9] as HrmPolicyConfig;
        _devices = results[10] as List<HrmIntegrationDevice>;
        _positions = results[11] as List<HrmPositionItem>;
        _isLoading = false;
      });
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
        return 'Chính sách & Cấu hình';
      case 'integrations':
        return 'Hệ thống & Tích hợp';
      default:
        return 'Quản trị Nhân sự (HRM)';
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
            if (_activeView != 'dashboard' && widget.initialView == null) {
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
            const Text(
              'SVN DTS / Quản trị Nhân sự',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
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
        return _buildPolicyConfigView();
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
  // 5. BẢNG CÔNG TỔNG HỢP (TIMESHEET SUMMARY)
  // ==========================================
  Widget _buildTimesheetSummaryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                value: _selectedTimesheetMonth,
                underline: const SizedBox(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                items: const [
                  DropdownMenuItem(value: 'Tháng 09/2026', child: Text('Kỳ công Tháng 09/2026')),
                  DropdownMenuItem(value: 'Tháng 10/2026', child: Text('Kỳ công Tháng 10/2026')),
                ],
                onChanged: (v) => setState(() => _selectedTimesheetMonth = v ?? 'Tháng 09/2026'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xuất báo cáo bảng công Excel thành công!')),
                  );
                },
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Xuất Excel', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Overview KPI
          Row(
            children: [
              Expanded(
                child: _buildWebStatCard(
                  title: 'Công chuẩn kỳ',
                  value: '22',
                  subtitle: 'Ngày công theo quy định',
                  icon: Icons.calendar_today,
                  iconBgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWebStatCard(
                  title: 'Tổng giờ OT',
                  value: '45.5h',
                  subtitle: 'Toàn bộ nhân sự',
                  icon: Icons.alarm,
                  iconBgColor: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionHeader(icon: Icons.list_alt, iconColor: const Color(0xFF0F172A), title: 'CHI TIẾT CÔNG NHÂN SỰ'),
          const SizedBox(height: 8),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _timesheets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ts = _timesheets[index];
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ts.employeeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(ts.employeeCode, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(ts.department, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTsBadge('Công đạt: ${ts.actualWorkdays}/${ts.standardWorkdays}', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                        _buildTsBadge('OT: ${ts.overtimeHours}h', const Color(0xFF059669), const Color(0xFFECFDF5)),
                        _buildTsBadge('Trễ: ${ts.lateCount}', ts.lateCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B), const Color(0xFFF1F5F9)),
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

  Widget _buildTsBadge(String text, Color textColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor)),
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
  // 7. CHÍNH SÁCH & CẤU HÌNH (POLICY CONFIG)
  // ==========================================
  Widget _buildPolicyConfigView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chính sách & Cấu hình HRM', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Text('Tham số quy định làm việc, chấm công và đãi ngộ doanh nghiệp', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 16),

          _buildProfileInfoGroup([
            {'label': 'Phép năm tiêu chuẩn', 'value': '${_policyConfig.annualLeaves} ngày / năm'},
            {'label': 'Giới hạn cho phép trễ', 'value': '${_policyConfig.lateGraceMinutes} phút'},
            {'label': 'Hệ số OT Ngày thường', 'value': '${_policyConfig.otWeekdayRate}x'},
            {'label': 'Hệ số OT Cuối tuần', 'value': '${_policyConfig.otWeekendRate}x'},
            {'label': 'Hệ số OT Ngày Lễ/Tết', 'value': '${_policyConfig.otHolidayRate}x'},
            {'label': 'Bán kính GPS hợp lệ', 'value': '${_policyConfig.geofenceRadiusMeters.toInt()} mét'},
            {'label': 'Bắt buộc khớp Wi-Fi WAN', 'value': _policyConfig.requireWifiMatching ? 'Có (Bật)' : 'Không (Tắt)'},
          ]),
        ],
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

            // Filter chips for Employees (Full matching with Web: Tất cả, Chính thức, Thử việc, Tạm nghỉ, Đã nghỉ việc, Chấm dứt hợp đồng)
            if (_employeeSubTab == 0) ...[
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

