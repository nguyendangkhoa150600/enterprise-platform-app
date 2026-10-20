import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hrm_models.dart';
import '../models/hrm_attendance_models.dart';
import '../services/hrm_service.dart';
import '../services/hrm_attendance_service.dart';
import 'attendance_screen.dart';

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

  // Data states
  HrmDashboardStats? _stats;
  List<HrmRequestItem> _requests = [];
  List<HrmEmployeeItem> _employees = [];
  List<HrmPayslipItem> _payslips = [];
  List<HrmShift> _shifts = [];
  List<HrmDependentItem> _dependents = [];
  List<HrmSalaryAdvanceItem> _advances = [];
  List<HrmTimesheetSummaryItem> _timesheets = [];
  List<HrmIntegrationDevice> _devices = [];
  HrmPolicyConfig _policyConfig = const HrmPolicyConfig();
  AttendanceRecord? _todayAttendance;

  bool _isLoading = true;
  String _requestFilter = 'ALL';
  String _approvalFilter = 'PENDING';
  String _employeeSearchQuery = '';
  String _selectedTimesheetMonth = 'Tháng 09/2026';

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
      _hrmService.getEmployees(),
      _hrmService.getPayslips(),
      _hrmService.getShifts(),
      _attendanceService.getTodayAttendance(),
      _hrmService.getDependents(),
      _hrmService.getSalaryAdvances(),
      _hrmService.getTimesheetSummaries(),
      _hrmService.getPolicyConfig(),
      _hrmService.getIntegrationDevices(),
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
      case 'schedule':
        return 'Lịch & Thông báo';
      case 'requests':
        return 'Đơn từ & Yêu cầu';
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
      case 'approvals':
        return 'Xử lý Đơn từ (Phê duyệt)';
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

  List<HrmRequestItem> get _filteredRequests {
    if (_requestFilter == 'ALL') return _requests;
    return _requests.where((r) => r.type.name.toUpperCase() == _requestFilter.toUpperCase()).toList();
  }

  List<HrmRequestItem> get _filteredApprovals {
    if (_approvalFilter == 'ALL') return _requests;
    return _requests.where((r) => r.status.name.toUpperCase() == _approvalFilter.toUpperCase()).toList();
  }

  List<HrmEmployeeItem> get _searchedEmployees {
    if (_employeeSearchQuery.trim().isEmpty) return _employees;
    final q = _employeeSearchQuery.toLowerCase();
    return _employees.where((e) =>
      e.fullName.toLowerCase().contains(q) ||
      e.code.toLowerCase().contains(q) ||
      e.department.toLowerCase().contains(q) ||
      e.position.toLowerCase().contains(q)
    ).toList();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--/--/----';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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
      case 'schedule':
        return _buildScheduleView();
      case 'requests':
        return _buildRequestsTab();
      case 'my_profile':
        return _buildMyProfileView();
      case 'my_payslips':
        return _buildPersonalPayslipsView();
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
            _buildSectionHeader(
              icon: Icons.access_time,
              iconColor: const Color(0xFF059669),
              title: 'TÌNH HÌNH CHẤM CÔNG HÔM NAY',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) => setState(() => _employeeSearchQuery = v),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, mã NV, phòng ban...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _searchedEmployees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final emp = _searchedEmployees[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        emp.fullName.isNotEmpty ? emp.fullName.substring(0, 1) : 'E',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(emp.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('${emp.code} • ${emp.position}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text(emp.department, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
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
  // 13. ĐƠN TỪ & YÊU CẦU (REQUESTS TAB)
  // ==========================================
  Widget _buildRequestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Danh sách Đơn từ của tôi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ElevatedButton.icon(
                onPressed: _showCreateRequestModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tạo đơn mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tất cả', 'ALL', _requestFilter, (v) => setState(() => _requestFilter = v)),
                _buildFilterChip('Nghỉ phép', 'LEAVE', _requestFilter, (v) => setState(() => _requestFilter = v)),
                _buildFilterChip('Làm thêm (OT)', 'OVERTIME', _requestFilter, (v) => setState(() => _requestFilter = v)),
                _buildFilterChip('Tạm ứng lương', 'ADVANCE', _requestFilter, (v) => setState(() => _requestFilter = v)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_filteredRequests.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('Không có đơn từ nào phù hợp.', style: TextStyle(color: Color(0xFF94A3B8))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final r = _filteredRequests[index];
                return _buildRequestCard(r);
              },
            ),
        ],
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

  Widget _buildRequestCard(HrmRequestItem r) {
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusColor = const Color(0xFFD97706);
    if (r.status == HrmRequestStatus.approved) {
      statusBg = const Color(0xFFD1FAE5);
      statusColor = const Color(0xFF059669);
    } else if (r.status == HrmRequestStatus.rejected) {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFDC2626);
    }

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
              Text(r.typeLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                child: Text(r.statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(r.reason, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gửi ngày: ${_formatDate(r.requestDate)}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
              if (r.durationHours != null)
                Text('${r.durationHours} giờ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 14. PHÊ DUYỆT ĐƠN TỪ (APPROVALS TAB)
  // ==========================================
  Widget _buildApprovalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trung tâm Phê duyệt Đơn từ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Text('Xét duyệt nghỉ phép, làm thêm giờ và các yêu cầu từ nhân viên', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildFilterChip('Chờ duyệt', 'PENDING', _approvalFilter, (v) => setState(() => _approvalFilter = v)),
              _buildFilterChip('Đã duyệt', 'APPROVED', _approvalFilter, (v) => setState(() => _approvalFilter = v)),
              _buildFilterChip('Từ chối', 'REJECTED', _approvalFilter, (v) => setState(() => _approvalFilter = v)),
            ],
          ),
          const SizedBox(height: 14),

          if (_filteredApprovals.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('Không có yêu cầu nào trong danh sách.', style: TextStyle(color: Color(0xFF94A3B8))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredApprovals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final r = _filteredApprovals[index];
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
                          Text(r.employeeName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text(r.typeLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(r.reason, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                      const SizedBox(height: 10),
                      if (r.status == HrmRequestStatus.pending)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await _hrmService.rejectRequest(r.id, reason: 'Từ chối bởi cấp quản lý');
                                  _loadAllHrmData();
                                },
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                                child: const Text('Từ chối'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await _hrmService.approveRequest(r.id);
                                  _loadAllHrmData();
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                                child: const Text('Duyệt đơn'),
                              ),
                            ),
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

  void _showCreateRequestModal() {
    HrmRequestType selectedType = HrmRequestType.leave;
    final titleController = TextEditingController();
    final reasonController = TextEditingController();
    final hoursController = TextEditingController();
    final amountController = TextEditingController();

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
                const Text('Tạo Đơn từ / Yêu cầu mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),
                DropdownButtonFormField<HrmRequestType>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: HrmRequestType.leave, child: Text('Đơn xin nghỉ phép')),
                    DropdownMenuItem(value: HrmRequestType.overtime, child: Text('Đơn đăng ký làm thêm giờ (OT)')),
                    DropdownMenuItem(value: HrmRequestType.advance, child: Text('Đơn đề nghị tạm ứng lương')),
                    DropdownMenuItem(value: HrmRequestType.attendanceCorrection, child: Text('Đơn giải trình quẹt công')),
                    DropdownMenuItem(value: HrmRequestType.shiftChange, child: Text('Đơn xin đổi ca làm việc')),
                    DropdownMenuItem(value: HrmRequestType.businessTrip, child: Text('Đơn đề xuất công tác xa')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                  decoration: const InputDecoration(labelText: 'Loại đơn từ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Lý do chi tiết *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (reasonController.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _hrmService.createRequest(
                      type: selectedType,
                      title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'Đơn ${selectedType.name}',
                      reason: reasonController.text.trim(),
                      durationHours: double.tryParse(hoursController.text),
                      amount: double.tryParse(amountController.text),
                    );
                    _loadAllHrmData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('GỬI ĐƠN PHÊ DUYỆT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
