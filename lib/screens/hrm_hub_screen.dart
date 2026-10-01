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
  const HrmHubScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialWorkforceSubTab = 0,
  });

  @override
  State<HrmHubScreen> createState() => _HrmHubScreenState();
}

class _HrmHubScreenState extends State<HrmHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HrmService _hrmService = HrmService();
  final HrmAttendanceService _attendanceService = HrmAttendanceService();

  // Data states
  HrmDashboardStats? _stats;
  List<HrmRequestItem> _requests = [];
  List<HrmEmployeeItem> _employees = [];
  List<HrmPayslipItem> _payslips = [];
  List<HrmShift> _shifts = [];
  AttendanceRecord? _todayAttendance;

  bool _isLoading = true;
  String _requestFilter = 'ALL';
  String _approvalFilter = 'PENDING';
  String _employeeSearchQuery = '';
  late int _workforceSubTab; // 0: Employees, 1: Shifts, 2: Payslips

  @override
  void initState() {
    super.initState();
    _workforceSubTab = widget.initialWorkforceSubTab.clamp(0, 2);
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _loadAllHrmData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    ]);

    if (mounted) {
      setState(() {
        _stats = results[0] as HrmDashboardStats;
        _requests = results[1] as List<HrmRequestItem>;
        _employees = results[2] as List<HrmEmployeeItem>;
        _payslips = results[3] as List<HrmPayslipItem>;
        _shifts = results[4] as List<HrmShift>;
        _todayAttendance = results[5] as AttendanceRecord?;
        _isLoading = false;
      });
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
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản trị Nhân sự & Đơn từ (HRM)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              'SAVINA Enterprise Human Resource Platform',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _loadAllHrmData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Tổng quan & Cá nhân'),
            Tab(text: 'Đơn từ & Yêu cầu'),
            Tab(text: 'Phê duyệt (Duyệt đơn)'),
            Tab(text: 'Nhân sự & Ca kíp'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildRequestsTab(),
                _buildApprovalsTab(),
                _buildWorkforceTab(),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: OVERVIEW & PERSONAL HUB
  // ==========================================
  Widget _buildOverviewTab() {
    final stats = _stats ?? const HrmDashboardStats(
      totalEmployees: 52,
      activeEmployees: 49,
      workingToday: 45,
      onLeaveToday: 4,
      pendingRequests: 6,
      lateArrivals: 2,
    );

    final hasCheckedIn = _todayAttendance?.firstCheckInAt != null;
    final hasCheckedOut = _todayAttendance?.lastCheckOutAt != null;

    return RefreshIndicator(
      onRefresh: _loadAllHrmData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KPI Stats Grid (4 Cards)
          Row(
            children: [
              Expanded(child: _buildKpiCard(title: 'Tổng nhân sự', value: '${stats.totalEmployees}', subtitle: '${stats.activeEmployees} đang hoạt động', color: const Color(0xFF2563EB), icon: Icons.people_alt_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard(title: 'Đi làm hôm nay', value: '${stats.workingToday}', subtitle: 'Đúng giờ: ${stats.workingToday - stats.lateArrivals}', color: const Color(0xFF059669), icon: Icons.how_to_reg_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildKpiCard(title: 'Nghỉ phép / Vắng', value: '${stats.onLeaveToday}', subtitle: 'Có đơn duyệt hợp lệ', color: const Color(0xFFD97706), icon: Icons.beach_access_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard(title: 'Đơn chờ duyệt', value: '${stats.pendingRequests}', subtitle: 'Cần cấp trên xử lý', color: const Color(0xFF7C3AED), icon: Icons.assignment_late_rounded)),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Hero Attendance Jump Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
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
                    const Row(
                      children: [
                        Icon(Icons.fingerprint_rounded, color: Color(0xFF38BDF8), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Chấm công & Định vị hôm nay',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasCheckedIn ? const Color(0xFF059669).withValues(alpha: 0.2) : const Color(0xFFFEF3C7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: hasCheckedIn ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                      ),
                      child: Text(
                        hasCheckedIn ? (hasCheckedOut ? 'Đã hoàn tất ca' : '🟢 Đang trong ca') : 'Chưa điểm danh',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: hasCheckedIn ? const Color(0xFF34D399) : const Color(0xFFFDE047)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  hasCheckedIn
                      ? 'Đã vào ca: ${_todayAttendance?.firstCheckInAt?.substring(11, 19) ?? "--:--"} • Trụ sở chính SAVINA'
                      : 'Ca chuẩn: 08:00 — 17:30 (Nghỉ trưa 90p) • Vị trí hợp lệ: SVN Headquarter',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                  icon: const Icon(Icons.touch_app_rounded, size: 16),
                  label: const Text('MỞ MÀN HÌNH CHẤM CÔNG DI ĐỘNG'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Quick Action Buttons Grid
          const Text(
            'THAO TÁC NHANH',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.post_add_rounded,
                  title: 'Tạo đơn từ',
                  subtitle: 'Nghỉ phép / OT / Tạm ứng',
                  color: const Color(0xFF0284C7),
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Phiếu lương',
                  subtitle: 'Thu nhập & Khấu trừ',
                  color: const Color(0xFF059669),
                  onTap: () {
                    setState(() => _workforceSubTab = 2);
                    _tabController.animateTo(3);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.badge_outlined,
                  title: 'Danh bạ nhân viên',
                  subtitle: '52 thành viên SAVINA',
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    setState(() => _workforceSubTab = 0);
                    _tabController.animateTo(3);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.event_available_rounded,
                  title: 'Ca & Lịch trực',
                  subtitle: '4 ca kíp luân phiên',
                  color: const Color(0xFFD97706),
                  onTap: () {
                    setState(() => _workforceSubTab = 1);
                    _tabController.animateTo(3);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. Recent Requests Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ĐƠN TỪ GẦN ĐÂY CỦA TÔI',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF64748B)),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('Xem tất cả →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_requests.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Chưa có đơn từ nào.', style: TextStyle(color: Color(0xFF94A3B8)))))
          else
            ..._requests.take(3).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildRequestCard(r),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({required String title, required String value, required String subtitle, required Color color, required IconData icon}) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActionTile({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: REQUESTS (ĐƠN TỪ & YÊU CẦU)
  // ==========================================
  Widget _buildRequestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Create Request Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách Đơn từ của tôi',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateRequestModal(),
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

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tất cả', 'ALL', _requestFilter, (v) => setState(() => _requestFilter = v)),
                _buildFilterChip('Nghỉ phép', 'LEAVE', _requestFilter, (v) => setState(() => _requestFilter = v)),
                _buildFilterChip('Làm thêm (OT)', 'OVERTIME', _requestFilter, (v) => setState(() => _requestFilter = v)),
                _buildFilterChip('Tạm ứng lương', 'ADVANCE', _requestFilter, (v) => setState(() => _requestFilter = v)),
                _buildFilterChip('Đổi ca', 'SHIFTCHANGE', _requestFilter, (v) => setState(() => _requestFilter = v)),
                _buildFilterChip('Công tác', 'BUSINESSTRIP', _requestFilter, (v) => setState(() => _requestFilter = v)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Requests List
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
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
      statusBg = const Color(0xFFECFDF5);
      statusColor = const Color(0xFF059669);
    } else if (r.status == HrmRequestStatus.rejected) {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFDC2626);
    }

    IconData typeIcon = Icons.article_outlined;
    Color typeColor = const Color(0xFF2563EB);
    if (r.type == HrmRequestType.leave) {
      typeIcon = Icons.beach_access_rounded;
      typeColor = const Color(0xFF059669);
    } else if (r.type == HrmRequestType.overtime) {
      typeIcon = Icons.alarm_on_rounded;
      typeColor = const Color(0xFFD97706);
    } else if (r.type == HrmRequestType.advance) {
      typeIcon = Icons.payments_outlined;
      typeColor = const Color(0xFF7C3AED);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeIcon, color: typeColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                child: Text(r.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                'Ngày gửi: ${_formatDate(r.requestDate)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              if (r.durationHours != null) ...[
                const SizedBox(width: 12),
                Text('• ${r.durationHours} giờ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ],
              if (r.amount != null) ...[
                const SizedBox(width: 12),
                Text('• ${_formatCurrency(r.amount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lý do: ${r.reason}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          if (r.approverName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Text(
                    'Đã duyệt bởi: ${r.approverName} lúc ${_formatDate(r.approvedAt)}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: APPROVALS (XỬ LÝ PHÊ DUYỆT ĐƠN TỪ)
  // ==========================================
  Widget _buildApprovalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phê duyệt Đơn từ & Yêu cầu nhân viên',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dành cho Quản lý / Trưởng bộ phận duyệt nghỉ phép, làm thêm, tạm ứng',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // Approval Filter Chips
          Row(
            children: [
              _buildFilterChip('Chờ duyệt (${_requests.where((r) => r.status == HrmRequestStatus.pending).length})', 'PENDING', _approvalFilter, (v) => setState(() => _approvalFilter = v)),
              _buildFilterChip('Đã duyệt', 'APPROVED', _approvalFilter, (v) => setState(() => _approvalFilter = v)),
              _buildFilterChip('Tất cả', 'ALL', _approvalFilter, (v) => setState(() => _approvalFilter = v)),
            ],
          ),
          const SizedBox(height: 16),

          if (_filteredApprovals.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('Không có đơn nào cần xử lý trong mục này.', style: TextStyle(color: Color(0xFF94A3B8))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredApprovals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final r = _filteredApprovals[index];
                return _buildApprovalActionCard(r);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildApprovalActionCard(HrmRequestItem r) {
    final isPending = r.status == HrmRequestStatus.pending;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? const Color(0xFF38BDF8).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          width: isPending ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF0F172A),
                child: Text(
                  r.employeeName.isNotEmpty ? r.employeeName[0] : 'E',
                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.employeeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('${r.employeeCode} • ${r.department}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPending ? const Color(0xFFFEF3C7) : (r.status == HrmRequestStatus.approved ? const Color(0xFFECFDF5) : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPending ? const Color(0xFFD97706) : (r.status == HrmRequestStatus.approved ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(r.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text('Lý do: ${r.reason}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          if (r.durationHours != null || r.amount != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (r.durationHours != null)
                  Text('Thời lượng: ${r.durationHours}h  ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                if (r.amount != null)
                  Text('Số tiền đề xuất: ${_formatCurrency(r.amount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ],
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _hrmService.approveRequest(r.id);
                      _loadAllHrmData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã phê duyệt đơn của ${r.employeeName} thành công.'), backgroundColor: const Color(0xFF059669)),
                        );
                      }
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Phê duyệt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _hrmService.rejectRequest(r.id, reason: 'Chưa đủ điều kiện xét duyệt đợt này');
                      _loadAllHrmData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã từ chối đơn của ${r.employeeName}.'), backgroundColor: const Color(0xFFDC2626)),
                        );
                      }
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Từ chối'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: WORKFORCE, SHIFTS & PAYSLIPS
  // ==========================================
  Widget _buildWorkforceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Sub-tab Navigation
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildSegmentButton('👥 Nhân sự (${_employees.length})', 0),
                _buildSegmentButton('⏰ Ca làm (${_shifts.length})', 1),
                _buildSegmentButton('💰 Phiếu lương', 2),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_workforceSubTab == 0) _buildEmployeesSubView(),
          if (_workforceSubTab == 1) _buildShiftsSubView(),
          if (_workforceSubTab == 2) _buildPayslipsSubView(),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, int index) {
    final isSelected = _workforceSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _workforceSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeesSubView() {
    return Column(
      children: [
        // Search TextField
        TextField(
          onChanged: (val) => setState(() => _employeeSearchQuery = val),
          decoration: InputDecoration(
            hintText: 'Tìm theo tên, mã NV, chức vụ hoặc phòng ban...',
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
        const SizedBox(height: 14),

        // Employees List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchedEmployees.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final e = _searchedEmployees[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF0F172A),
                    child: Text(
                      e.fullName.isNotEmpty ? e.fullName[0] : 'E',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.fullName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('${e.position} • ${e.department}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(e.email, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
                            const SizedBox(width: 10),
                            const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(e.phone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
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

  Widget _buildShiftsSubView() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _shifts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = _shifts[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                    child: Text(s.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    '${s.startTime.substring(0, 5)} — ${s.endTime.substring(0, 5)} (Nghỉ giữa ca ${s.breakMinutes} phút)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayslipsSubView() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _payslips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = _payslips[index];
        final isPaid = p.status == 'PAID';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Phiếu lương: ${p.period}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPaid ? 'Đã chi trả' : 'Chờ đối soát',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPaid ? const Color(0xFF059669) : const Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lương cơ bản:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                  Text(_formatCurrency(p.baseSalary), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Phụ cấp & Thưởng:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                  Text(_formatCurrency(p.allowances + p.bonuses), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Làm thêm giờ (OT):', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                  Text(_formatCurrency(p.overtimePay), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Khấu trừ (BHXH/BHYT/Thuế):', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                  Text('- ${_formatCurrency(p.deductions)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                ],
              ),
              const Divider(height: 18, color: Color(0xFFF1F5F9)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('THỰC NHẬN (NET):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text(_formatCurrency(p.netSalary), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // CREATE REQUEST MODAL BOTTOM SHEET
  // ==========================================
  void _showCreateRequestModal() {
    HrmRequestType selectedType = HrmRequestType.leave;
    final titleController = TextEditingController();
    final reasonController = TextEditingController();
    final hoursController = TextEditingController(text: '8');
    final amountController = TextEditingController(text: '5000000');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tạo đơn từ / Yêu cầu mới',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Request Type Dropdown
                  const Text('Loại đơn từ (*):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<HrmRequestType>(
                    value: selectedType,
                    items: const [
                      DropdownMenuItem(value: HrmRequestType.leave, child: Text('Đơn xin nghỉ phép')),
                      DropdownMenuItem(value: HrmRequestType.overtime, child: Text('Đăng ký làm thêm (OT)')),
                      DropdownMenuItem(value: HrmRequestType.advance, child: Text('Đơn xin tạm ứng lương')),
                      DropdownMenuItem(value: HrmRequestType.shiftChange, child: Text('Đổi ca làm việc')),
                      DropdownMenuItem(value: HrmRequestType.businessTrip, child: Text('Đơn đề xuất công tác')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedType = val);
                      }
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title Field
                  const Text('Tiêu đề đơn:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Nghỉ phép năm, Tăng ca đóng điện trạm...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Conditional fields (Hours or Amount)
                  if (selectedType == HrmRequestType.overtime || selectedType == HrmRequestType.leave) ...[
                    const Text('Số giờ đề xuất:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: hoursController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '8',
                        suffixText: 'giờ',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (selectedType == HrmRequestType.advance) ...[
                    const Text('Số tiền tạm ứng (VNĐ):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '5000000',
                        suffixText: '₫',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Reason Field
                  const Text('Lý do chi tiết (*):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Nhập chi tiết mục đích, kế hoạch bàn giao công việc...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    onPressed: () async {
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập lý do đơn từ.')),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      await _hrmService.createRequest(
                        type: selectedType,
                        title: titleController.text.trim().isNotEmpty
                            ? titleController.text.trim()
                            : 'Đơn ${selectedType.name}',
                        reason: reasonController.text.trim(),
                        durationHours: double.tryParse(hoursController.text),
                        amount: double.tryParse(amountController.text),
                      );

                      _loadAllHrmData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã gửi đơn lên Quản lý phê duyệt thành công!'),
                            backgroundColor: Color(0xFF059669),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('GỬI ĐƠN PHÊ DUYỆT', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
