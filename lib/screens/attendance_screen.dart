import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/hrm_attendance_models.dart';
import '../providers/auth_provider.dart';
import '../services/hrm_attendance_service.dart';
import '../theme/colors.dart';
import '../utils/error_handler.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  final HrmAttendanceService _service = HrmAttendanceService();

  late TabController _tabController;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  AttendanceContext? _context;
  PrecheckResult? _precheck;
  AttendanceRecord? _todayRecord;
  List<AttendanceRecord> _history = [];
  List<AttendanceCorrection> _corrections = [];
  List<AttendanceCorrection> _drafts = [];
  List<LeaveType> _leaveTypes = [];

  bool _isLoading = true;
  bool _isPunching = false;
  bool _isInShift = false;
  String _historyFilter = 'ALL';

  // Matrix View State
  int _historyViewMode = 0; // 0: Bảng công ma trận, 1: Nhật ký quẹt thẻ
  String _selectedMonth = 'Tháng 10/2026';
  final List<String> _availableMonths = ['Tháng 10/2026', 'Tháng 09/2026', 'Tháng 08/2026'];
  int _matrixSubTab = 0; // 0: Bảng chấm công, 1: Chi tiết bảng chấm công
  int _requestsSubTab = 1; // 0: Bản nháp, 1: Tạo đơn mới (Catalog), 2: Chờ duyệt, 3: Lịch sử

  // Search & Filter State for Requests (Matching Web)
  String _requestSearchKeyword = '';
  String _requestTypeFilter = 'ALL';
  String _requestStatusFilter = 'ALL';
  String _requestApproverFilter = '';
  String _requestStepFilter = 'ALL';
  DateTime? _requestFromDate;
  DateTime? _requestToDate;
  bool _showAdvancedFilters = false;

  final TextEditingController _requestSearchController = TextEditingController();
  final TextEditingController _requestApproverController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startLiveClock();
    _loadAllAttendanceData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startLiveClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'TT';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    if (parts.length >= 3) {
      return (parts[parts.length - 2][0] + parts.last[0]).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _loadAllAttendanceData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.getAttendanceContext(),
      _service.precheck(),
      _service.getTodayAttendance(),
      _service.getAttendanceHistory(),
      _service.getCorrections(),
      _service.getLeaveTypes(),
    ]);

    if (mounted) {
      final todayRec = results[2] as AttendanceRecord?;
      setState(() {
        _context = results[0] as AttendanceContext?;
        _precheck = results[1] as PrecheckResult?;
        _todayRecord = todayRec;
        _history = (results[3] as List<AttendanceRecord>?) ?? [];
        _corrections = (results[4] as List<AttendanceCorrection>?) ?? [];
        _leaveTypes = (results[5] as List<LeaveType>?) ?? [];
        _isInShift = todayRec?.firstCheckInAt != null && todayRec?.lastCheckOutAt == null;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCheckIn() async {
    setState(() => _isPunching = true);
    try {
      final record = await _service.checkIn();
      final history = await _service.getAttendanceHistory();
      final precheck = await _service.precheck();

      if (mounted) {
        setState(() {
          _todayRecord = record;
          _history = history;
          _precheck = precheck;
          _isInShift = true; // Chuyển sang hiển thị QUẸT RA
          _isPunching = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Đã quẹt thẻ Vào ca lúc ${_formatTime(record.firstCheckInAt)} thành công.'),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPunching = false);
        final userMsg = ApiErrorHandler.parse(e, defaultMessage: 'Không thể quẹt thẻ Vào ca. Vui lòng thử lại.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMsg),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _handleCheckOut() async {
    setState(() => _isPunching = true);
    try {
      final record = await _service.checkOut();
      final history = await _service.getAttendanceHistory();
      final precheck = await _service.precheck();

      if (mounted) {
        setState(() {
          _todayRecord = record;
          _history = history;
          _precheck = precheck;
          _isInShift = false; // Quẹt ra xong lập tức chuyển lại hiển thị QUẸT VÀO cho ca/lượt tiếp theo
          _isPunching = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Đã quẹt thẻ Hết ca lúc ${_formatTime(record.lastCheckOutAt)} (${(record.workedMinutes / 60).toStringAsFixed(1)}h làm việc).'),
              ],
            ),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPunching = false);
        final userMsg = ApiErrorHandler.parse(e, defaultMessage: 'Không thể quẹt thẻ Hết ca. Vui lòng thử lại.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMsg),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--:--';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatDate(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  List<AttendanceRecord> get _filteredHistory {
    if (_historyFilter == 'ALL') return _history;
    return _history.where((r) => r.status == _historyFilter).toList();
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
              'Chấm công điện tử (HRM Attendance)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              'Xác thực vị trí GPS, Wi-Fi WAN & Sổ chấm công',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Làm mới',
            onPressed: _loadAllAttendanceData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Điểm danh hôm nay'),
            Tab(text: 'Sổ chấm công'),
            Tab(text: 'Đơn từ & Yêu cầu'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(),
                _buildHistoryTab(),
                _buildRequestsTab(),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: TODAY ATTENDANCE PUNCH PANEL
  // ==========================================
  Widget _buildTodayTab() {
    final shift = _context?.shift;
    final hasCheckedIn = _todayRecord?.firstCheckInAt != null;
    final hasCheckedOut = _todayRecord?.lastCheckOutAt != null;

    final hourStr = _currentTime.hour.toString().padLeft(2, '0');
    final minuteStr = _currentTime.minute.toString().padLeft(2, '0');
    final secondStr = _currentTime.second.toString().padLeft(2, '0');

    final weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final weekdayStr = weekdays[_currentTime.weekday - 1];
    final dateStr = '$weekdayStr, ${_currentTime.day.toString().padLeft(2, '0')}/${_currentTime.month.toString().padLeft(2, '0')}/${_currentTime.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Digital Clock & Shift Info Hero Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E293B), // Slate 800
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Tag: Mobile App Direct Check-in
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0284C7)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.phone_android, size: 12, color: Color(0xFF38BDF8)),
                          SizedBox(width: 4),
                          Text(
                            'Mobile Direct Check-in',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Real-time Clock
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$hourStr:$minuteStr',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ':$secondStr',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Shift Details Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 15, color: Color(0xFFFDE047)),
                      const SizedBox(width: 6),
                      Text(
                        '${shift?.name ?? "Ca Hành chính"}: ${shift?.startTime.substring(0, 5) ?? "08:00"} — ${shift?.endTime.substring(0, 5) ?? "17:30"} (Nghỉ trưa ${shift?.breakMinutes ?? 90}p)',
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Location & Network Verification Radar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.radar, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trạng thái Định vị & Kết nối',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Vị trí hợp lệ: Trụ sở chính SAVINA',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Cách 15m', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildVerificationBadge(icon: Icons.gps_fixed, label: 'GPS: 10.7768, 106.7008'),
                    _buildVerificationBadge(icon: Icons.wifi, label: 'Wi-Fi: SVN_OFFICE_5G'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Dynamic Punch Action Hero Card (Chuyển đổi linh hoạt giữa Quẹt Vào & Quẹt Ra nhiều lần trong ngày)
          _buildDynamicPunchCard(),
          const SizedBox(height: 20),

          // 4. Monthly KPI Summary Cards
          const Text(
            'TỔNG KẾT CÔNG THÁNG 09/2026',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildKpiCard(label: 'Tổng ngày công', value: '22', unit: 'ngày', color: const Color(0xFF2563EB))),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard(label: 'Đúng giờ', value: '20', unit: 'ngày', color: const Color(0xFF059669))),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard(label: 'Đi muộn', value: '1', unit: 'ngày', color: const Color(0xFFD97706))),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard(label: 'Giải trình', value: '1', unit: 'đơn', color: const Color(0xFF7C3AED))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicPunchCard() {
    // TRƯỜNG HỢP 1: ĐANG TRONG CA -> CHỈ HIỂN THỊ NÚT QUẸT RA (CHECK-OUT)
    if (_isInShift) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.work_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'TRẠNG THÁI CA LÀM',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text(
                        'Đang trong ca làm việc',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Info Box: Giờ vào ca
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 6),
                      Text(
                        'Thời gian quẹt vào:',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Text(
                    _formatTime(_todayRecord?.firstCheckInAt),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Large Hero Action Button: QUẸT RA CA (CHECK-OUT)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isPunching ? null : _handleCheckOut,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isPunching
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: Colors.white, size: 28),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QUẸT RA CA (CHECK-OUT)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Text(
                                  'Chạm để kết thúc ca & chốt giờ làm việc',
                                  style: TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // TRƯỜNG HỢP 2: CHƯA VÀO CA HOẶC ĐÃ QUẸT RA -> CHỈ HIỂN THỊ NÚT QUẸT VÀO (CHECK-IN)
    final hasPreviousPunches = _todayRecord?.lastCheckOutAt != null;
    final workedHours = ((_todayRecord?.workedMinutes ?? 0) / 60).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.login_rounded, size: 16, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TRẠNG THÁI CA LÀM',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasPreviousPunches ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasPreviousPunches ? 'Sẵn sàng vào ca mới' : 'Chưa điểm danh vào',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasPreviousPunches ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),

          // Lượt quẹt gần nhất (nếu hôm nay đã quẹt ra trước đó)
          if (hasPreviousPunches) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lượt trước: Vào ${_formatTime(_todayRecord?.firstCheckInAt)} — Ra ${_formatTime(_todayRecord?.lastCheckOutAt)} (Đã tích lũy ${workedHours}h)',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Large Hero Action Button: QUẸT VÀO CA (CHECK-IN)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isPunching ? null : _handleCheckIn,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isPunching
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 28),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasPreviousPunches ? 'QUẸT VÀO TIẾP THEO (CHECK-IN)' : 'QUẸT VÀO CA (CHECK-IN)',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Text(
                                'Chạm để ghi nhận giờ bắt đầu làm việc',
                                style: TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Nút phụ giải trình (nếu đã có lượt quẹt)
          if (hasPreviousPunches) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showCorrectionDialog(_todayRecord),
                icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Giải trình công lượt trước', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationBadge({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildKpiCard({required String label, required String value, required String unit, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), textAlign: TextAlign.center, maxLines: 1),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 2),
              Text(unit, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: ATTENDANCE HISTORY (SỔ CHẤM CÔNG & MA TRẬN)
  // ==========================================
  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card: Bảng chấm công ma trận cá nhân theo tháng
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.grid_view_rounded, size: 20, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bảng chấm công ma trận cá nhân theo tháng',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Dữ liệu công ghi nhận theo từng ngày trong tháng. Nhấp vào ô bất kỳ để xem chi tiết giờ vào/ra.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Controls: Mode Switcher & Month Picker
                Row(
                  children: [
                    // Mode Switcher (Bảng công ma trận vs Nhật ký quẹt thẻ)
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _historyViewMode = 0),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _historyViewMode == 0 ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _historyViewMode == 0
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.grid_view_rounded,
                                        size: 13,
                                        color: _historyViewMode == 0 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Ma trận',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: _historyViewMode == 0 ? FontWeight.bold : FontWeight.w500,
                                          color: _historyViewMode == 0 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _historyViewMode = 1),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _historyViewMode == 1 ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _historyViewMode == 1
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.history_rounded,
                                        size: 14,
                                        color: _historyViewMode == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Nhật ký',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: _historyViewMode == 1 ? FontWeight.bold : FontWeight.w500,
                                          color: _historyViewMode == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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
                    ),
                    const SizedBox(width: 8),

                    // Month Picker Dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedMonth,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            items: _availableMonths.map((m) {
                              return DropdownMenuItem(
                                value: m,
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(m, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedMonth = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Body based on View Mode
          if (_historyViewMode == 0)
            _buildMatrixViewMode()
          else
            _buildLogsViewMode(),
        ],
      ),
    );
  }

  // ==========================================
  // MODE 0: BẢNG CÔNG MA TRẬN VIEW
  // ==========================================
  Widget _buildMatrixViewMode() {
    // Parse Year and Month from _selectedMonth (e.g. "Tháng 10/2026")
    final parts = _selectedMonth.split('/');
    final year = int.tryParse(parts.length > 1 ? parts[1].trim() : '2026') ?? 2026;
    final monthStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    final month = int.tryParse(monthStr) ?? 10;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    // Map existing history records by date "YYYY-MM-DD"
    final monthPrefix = '$year-${month.toString().padLeft(2, '0')}';
    final Map<int, AttendanceRecord> dayRecordMap = {};
    for (var r in _history) {
      if (r.workDate.startsWith(monthPrefix)) {
        final d = int.tryParse(r.workDate.substring(8, 10));
        if (d != null) {
          dayRecordMap[d] = r;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-tabs: [Bảng chấm công] vs [Chi tiết bảng chấm công]
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(width: 1.5, color: Color(0xFFE2E8F0))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _matrixSubTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _matrixSubTab == 0 ? const Color(0xFFDC2626) : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 15,
                          color: _matrixSubTab == 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Bảng chấm công',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _matrixSubTab == 0 ? FontWeight.bold : FontWeight.w500,
                            color: _matrixSubTab == 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _matrixSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _matrixSubTab == 1 ? const Color(0xFFDC2626) : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 15,
                          color: _matrixSubTab == 1 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Chi tiết bảng chấm công',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _matrixSubTab == 1 ? FontWeight.bold : FontWeight.w500,
                            color: _matrixSubTab == 1 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Hiển thị 1 / 1 bản ghi',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_matrixSubTab == 0) ...[
          // Sub-Tab 0: Interactive Scrollable Matrix Table
          _buildMatrixTable(year, month, daysInMonth, dayRecordMap),
          const SizedBox(height: 14),

          // Legend Box
          _buildMatrixLegend(),
        ] else ...[
          // Sub-Tab 1: Monthly Detailed KPI Breakdown
          _buildMatrixDetailBreakdown(year, month, daysInMonth, dayRecordMap),
        ],
      ],
    );
  }

  // Matrix Table Component
  Widget _buildMatrixTable(int year, int month, int daysInMonth, Map<int, AttendanceRecord> dayRecordMap) {
    final weekdaysShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee Info Header Row (Mobile Compact Card)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'STT 1',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ME (NV-001)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lịch sử chấm công của tôi',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Ban Điều hành • Quản trị viên',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Scrollable Calendar Matrix
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day of Week Header Row (T2, T3, T4, T5, T6, T7, CN)
                Row(
                  children: List.generate(daysInMonth, (index) {
                    final day = index + 1;
                    final dt = DateTime(year, month, day);
                    final weekday = dt.weekday; // 1=Mon, 7=Sun
                    final isSunday = weekday == 7;
                    final isSaturday = weekday == 6;

                    return Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSunday ? const Color(0xFFFEF2F2) : (isSaturday ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC)),
                        border: Border(
                          right: const BorderSide(color: Color(0xFFE2E8F0)),
                          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        weekdaysShort[weekday - 1],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSunday ? const Color(0xFFDC2626) : const Color(0xFF475569),
                        ),
                      ),
                    );
                  }),
                ),

                // Day Number Header Row (01, 02, 03... 31)
                Row(
                  children: List.generate(daysInMonth, (index) {
                    final day = index + 1;
                    final dt = DateTime(year, month, day);
                    final isSunday = dt.weekday == 7;
                    final isToday = day == DateTime.now().day && month == DateTime.now().month && year == DateTime.now().year;

                    return Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFFEFF6FF)
                            : (isSunday ? const Color(0xFFFEF2F2) : const Color(0xFFFFFFFF)),
                        border: Border(
                          right: const BorderSide(color: Color(0xFFE2E8F0)),
                          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        day.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                          color: isToday ? const Color(0xFF2563EB) : (isSunday ? const Color(0xFFDC2626) : const Color(0xFF334155)),
                        ),
                      ),
                    );
                  }),
                ),

                // Data Cells Row (CC, Trễ, BT, P, KL, -)
                Row(
                  children: List.generate(daysInMonth, (index) {
                    final day = index + 1;
                    final dt = DateTime(year, month, day);
                    final isSunday = dt.weekday == 7;
                    final record = dayRecordMap[day];
                    final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                    final weekdayStr = weekdaysShort[dt.weekday - 1];

                    return InkWell(
                      onTap: () => _showDayDetailModal(day, dateStr, record, weekdayStr),
                      child: Container(
                        width: 44,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSunday ? const Color(0xFFFFF7ED).withValues(alpha: 0.3) : Colors.white,
                          border: const Border(
                            right: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: _buildMatrixCellBadge(record),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Matrix Cell Badge Helper
  Widget _buildMatrixCellBadge(AttendanceRecord? record) {
    if (record == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '—',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
        ),
      );
    }

    if (record.status == 'VALID') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Text(
          'CC',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
        ),
      );
    } else if (record.status == 'LATE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Text(
          'Trễ',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
        ),
      );
    } else if (record.status == 'ABNORMAL') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Text(
          'BT',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
        ),
      );
    } else if (record.status == 'APPROVED_CORRECTION') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: const Text(
          'CC',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
        ),
      );
    } else if (record.status == 'LEAVE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'P',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '—',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
      ),
    );
  }

  // Legend Component (Matching Web Footer)
  Widget _buildMatrixLegend() {
    return Container(
      width: double.infinity,
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
              const Text(
                'Ký hiệu chấm công:',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              Text(
                'Kỳ công: $_selectedMonth • Nhân sự: Tôi',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLegendChip('CC', 'Có chấm công', const Color(0xFFECFDF5), const Color(0xFF059669), const Color(0xFFA7F3D0)),
              _buildLegendChip('Trễ', 'Đi trễ', const Color(0xFFFEF3C7), const Color(0xFFD97706), const Color(0xFFFDE68A)),
              _buildLegendChip('BT', 'Bất thường / Thiếu quẹt', const Color(0xFFFEE2E2), const Color(0xFFDC2626), const Color(0xFFFECACA)),
              _buildLegendChip('P', 'Nghỉ phép', const Color(0xFFF3E8FF), const Color(0xFF7C3AED), const Color(0xFFDDD6FE)),
              _buildLegendChip('KL', 'Không lương', const Color(0xFFF1F5F9), const Color(0xFF475569), const Color(0xFFCBD5E1)),
              _buildLegendChip('—', 'Chưa có dữ liệu', const Color(0xFFF8FAFC), const Color(0xFF94A3B8), const Color(0xFFE2E8F0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendChip(String code, String label, Color bg, Color text, Color border) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
          child: Text(
            code,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: text),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  // Sub-Tab 1: Monthly Detailed Breakdown Component
  Widget _buildMatrixDetailBreakdown(int year, int month, int daysInMonth, Map<int, AttendanceRecord> dayRecordMap) {
    int validDays = 0;
    int lateDays = 0;
    int abnormalDays = 0;
    int totalWorkedMinutes = 0;
    int totalLateMinutes = 0;

    for (var r in dayRecordMap.values) {
      if (r.status == 'VALID' || r.status == 'APPROVED_CORRECTION') validDays++;
      if (r.status == 'LATE') {
        lateDays++;
        totalLateMinutes += r.lateMinutes;
      }
      if (r.status == 'ABNORMAL') abnormalDays++;
      totalWorkedMinutes += r.workedMinutes;
    }

    final standardDays = 22; // chuẩn tháng
    final actualWorkDays = validDays + lateDays;
    final totalHours = (totalWorkedMinutes / 60).toStringAsFixed(1);
    final rate = ((actualWorkDays / standardDays) * 100).clamp(0, 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                label: 'Công chuẩn tháng',
                value: '$standardDays',
                unit: 'ngày',
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                label: 'Thực tế đi làm',
                value: '$actualWorkDays',
                unit: 'ngày',
                color: const Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                label: 'Số lần đi trễ',
                value: '$lateDays',
                unit: 'lần',
                color: const Color(0xFFD97706),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                label: 'Bất thường / Thiếu',
                value: '$abnormalDays',
                unit: 'ngày',
                color: const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                label: 'Tổng giờ tích lũy',
                value: totalHours,
                unit: 'giờ',
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                label: 'Tỷ lệ hoàn thành',
                value: '$rate%',
                unit: '',
                color: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // List of days with records
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chi tiết các ngày đã ghi nhận công:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              if (dayRecordMap.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có dữ liệu chấm công cho tháng này.', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                )
              else
                ...dayRecordMap.entries.map((entry) {
                  final day = entry.key;
                  final r = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _showDayDetailModal(day, r.workDate, r, 'T${DateTime(year, month, day).weekday}'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _formatDate(r.workDate),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const Spacer(),
                            Text(
                              'Vào: ${_formatTime(r.firstCheckInAt)}  |  Ra: ${_formatTime(r.lastCheckOutAt)}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 8),
                            _buildMatrixCellBadge(r),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MODE 1: NHẬT KÝ QUẸT THẺ VIEW
  // ==========================================
  Widget _buildLogsViewMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildHistoryFilterChip('Tất cả', 'ALL'),
              _buildHistoryFilterChip('Hợp lệ', 'VALID'),
              _buildHistoryFilterChip('Đi muộn', 'LATE'),
              _buildHistoryFilterChip('Bất thường', 'ABNORMAL'),
              _buildHistoryFilterChip('Đã duyệt sửa', 'APPROVED_CORRECTION'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // History List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredHistory.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _filteredHistory[index];
            return _buildHistoryItemCard(item);
          },
        ),
      ],
    );
  }

  Widget _buildHistoryFilterChip(String label, String value) {
    final isSelected = _historyFilter == value;
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
        onSelected: (_) => setState(() => _historyFilter = value),
      ),
    );
  }

  // Modal Bottom Sheet on Tapping Matrix Day Cell
  void _showDayDetailModal(int day, String dateStr, AttendanceRecord? record, String weekdayStr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final hasRecord = record != null;
        final isLate = record?.status == 'LATE';
        final isAbnormal = record?.status == 'ABNORMAL';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar Handle
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

              // Title & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$weekdayStr, ${_formatDate(dateStr)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const Text(
                            'Chi tiết dữ liệu chấm công ngày',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildMatrixCellBadge(record),
                ],
              ),
              const SizedBox(height: 16),

              // Time Details Container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Giờ vào:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(record?.firstCheckInAt),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Giờ ra:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(record?.lastCheckOutAt),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tổng công:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              const SizedBox(height: 2),
                              Text(
                                (record?.workedMinutes ?? 0) > 0 ? '${((record?.workedMinutes ?? 0) / 60).toStringAsFixed(1)} giờ' : '--',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isLate) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            'Đi muộn: ${record?.lateMinutes} phút',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                          ),
                        ],
                      ),
                    ],
                    if (record?.note != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Ghi chú: ${record?.note}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Danh sách từng lượt quẹt nếu có
              if (record != null && record.punchList.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
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
                          const Icon(Icons.list_alt_rounded, size: 14, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 6),
                          Text(
                            'Chi tiết ${record.punchList.length} lượt quẹt trong ngày:',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...record.punchList.asMap().entries.map((pEntry) {
                        final pIdx = pEntry.key + 1;
                        final p = pEntry.value;
                        final isCheckIn = p.punchType == 'IN';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isCheckIn ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isCheckIn ? 'Vào (Lượt $pIdx)' : 'Ra (Lượt $pIdx)',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: isCheckIn ? const Color(0xFF059669) : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(p.occurredAt),
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                              const Spacer(),
                              Text(
                                p.siteName ?? 'Trụ sở chính SAVINA',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Site & Source Verification
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'Địa điểm: ${record?.matchedSiteName ?? "Trụ sở chính SAVINA"}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Text(
                    'Xác thực: ${record?.attendanceSource ?? "Mobile App (GPS & Wi-Fi)"}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action buttons
              if (isLate || isAbnormal || !hasRecord) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCorrectionDialog(record);
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Làm đơn giải trình công cho ngày này'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Đóng', style: TextStyle(color: Color(0xFF475569))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryItemCard(AttendanceRecord item) {
    Color statusBg = const Color(0xFFECFDF5);
    Color statusColor = const Color(0xFF059669);
    String statusText = 'Hợp lệ';

    if (item.status == 'LATE') {
      statusBg = const Color(0xFFFEF3C7);
      statusColor = const Color(0xFFD97706);
      statusText = 'Đi muộn ${item.lateMinutes}p';
    } else if (item.status == 'ABNORMAL') {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFDC2626);
      statusText = 'Bất thường (Thiếu quẹt)';
    } else if (item.status == 'APPROVED_CORRECTION') {
      statusBg = const Color(0xFFF3E8FF);
      statusColor = const Color(0xFF7C3AED);
      statusText = 'Đã duyệt sửa công';
    }

    final canExplain = item.status == 'ABNORMAL' || item.status == 'LATE';

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
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(item.workDate),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Giờ vào:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(item.firstCheckInAt),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Giờ ra:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(item.lastCheckOutAt),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tổng công:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      item.workedMinutes > 0 ? '${(item.workedMinutes / 60).toStringAsFixed(1)} giờ' : '--',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.note != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ghi chú: ${item.note}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],
          if (canExplain) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showCorrectionDialog(item),
                icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Giải trình công', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: REQUESTS & APPROVALS (ĐƠN TỪ & YÊU CẦU - ESS 7 LOẠI ĐƠN)
  // ==========================================
  Widget _buildRequestsTab() {
    final pendingCount = _corrections.where((c) => c.status == 'PENDING').length;
    final historyCount = _corrections.where((c) => c.status != 'PENDING').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Quick Actions (Matching Web)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Đơn từ & Yêu cầu',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Text('ESS / 7 loại đơn', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Trung tâm khởi tạo và giám sát tiến độ giao dịch nhân viên.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined, size: 20, color: Color(0xFF475569)),
                    tooltip: 'Xuất lịch sử đơn',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đang xuất tệp lịch sử đơn từ (Excel)...'), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showCorrectionDialog(null),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Tạo đơn mới', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Employee Profile Card (Matching Web Top Hero Card)
          Builder(
            builder: (context) {
              final auth = context.watch<AuthProvider>();
              final userFullName = (_context?.fullName != null && _context!.fullName.isNotEmpty && _context!.fullName != 'SVN Admin')
                  ? _context!.fullName
                  : (auth.fullName?.isNotEmpty == true ? auth.fullName! : 'Nguyễn Tấn Tài');
              final employeeCode = (_context?.employeeCode != null && _context!.employeeCode.isNotEmpty && _context!.employeeCode != 'NV-001')
                  ? _context!.employeeCode
                  : 'MS_385';
              final userEmail = auth.email?.isNotEmpty == true ? auth.email! : 'ngtantai48@gmail.com';
              final userInitials = _getInitials(userFullName);

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar circle with online indicator
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            userInitials,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                userFullName,
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'CHÍNH THỨC (Official)',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Mã: $employeeCode',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'SVN DTS Corporation',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.mail_outline, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              Text(
                                userEmail,
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.badge_outlined, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              const Expanded(
                                child: Text(
                                  'Tenant Administrator',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Thâm niên: 1 năm 2 tháng (+1 ngày phép/năm)', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                              ),
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
          const SizedBox(height: 12),

          // 3. Sub-Navigation Tabs Bar (Bản nháp | Tạo đơn mới 7 loại đơn | Chờ duyệt | Lịch sử)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRequestSubTabButton(
                  index: 0,
                  label: 'Bản nháp',
                  count: _drafts.isNotEmpty ? _drafts.length : null,
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 1,
                  label: 'Tạo đơn mới (Request Catalog)',
                  badge: '7 loại đơn',
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 2,
                  label: 'Đơn đang chờ duyệt (Pending)',
                  count: pendingCount,
                ),
                const SizedBox(width: 6),
                _buildRequestSubTabButton(
                  index: 3,
                  label: 'Lịch sử đơn từ (History)',
                  count: historyCount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Sub-tab Content
          if (_requestsSubTab == 1) ...[
            // ====================================================
            // SUB-TAB 1: 7 REQUEST CATALOG CARDS (100% MATCHING WEB)
            // ====================================================
            _buildCatalogCard(
              icon: Icons.description_outlined,
              iconBgColor: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              badgeText: 'Tự động trừ quỹ phép',
              badgeBgColor: const Color(0xFFECFDF5),
              badgeTextColor: const Color(0xFF059669),
              title: 'Đơn xin nghỉ phép',
              description: 'Nghỉ phép năm, nghỉ ốm BHXH, việc riêng có hưởng lương, nghỉ không lương theo quy chế.',
              infoBoxText: 'Quỹ phép khả dụng: 12.0 ngày',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Phép năm (Hưởng nguyên lương)'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.access_time_filled_rounded,
              iconBgColor: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              badgeText: 'Cần duyệt trước ca làm',
              badgeBgColor: const Color(0xFFFEF3C7),
              badgeTextColor: const Color(0xFFD97706),
              title: 'Đơn làm thêm giờ (OT)',
              description: 'Đăng ký làm thêm ngày thường (1.5x), làm đêm (2.0x), cuối tuần (2.0x) hoặc Lễ Tết (3.0x).',
              infoBoxText: 'Hệ số tính: 1.5x ~ 3.0x lương',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Làm thêm giờ (Overtime)'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.flight_takeoff_rounded,
              iconBgColor: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              badgeText: 'Nội địa / Quốc tế',
              badgeBgColor: const Color(0xFFEFF6FF),
              badgeTextColor: const Color(0xFF2563EB),
              title: 'Đơn đi công tác',
              description: 'Công tác thực địa, hỗ trợ dự án tỉnh xa, hội thảo chuyên môn; kèm chế độ phụ cấp công tác.',
              infoBoxText: 'Chế độ: Phụ cấp + Lưu trú',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Đi công tác / Giải trình công'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.swap_horiz_rounded,
              iconBgColor: const Color(0xFFECFDF5),
              iconColor: const Color(0xFF059669),
              badgeText: 'Cần xác nhận chéo',
              badgeBgColor: const Color(0xFFECFDF5),
              badgeTextColor: const Color(0xFF059669),
              title: 'Đơn đổi ca làm việc',
              description: 'Đổi ca tạm thời/vĩnh viễn; hoán đổi ca trực tương đương với đồng nghiệp cùng bộ phận.',
              infoBoxText: 'Hình thức: Đổi ca / Hoán đổi',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn đổi ca làm việc'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.edit_calendar_rounded,
              iconBgColor: const Color(0xFFFFE4E6),
              iconColor: const Color(0xFFE11D48),
              badgeText: 'Bù công / Giải trình',
              badgeBgColor: const Color(0xFFFFE4E6),
              badgeTextColor: const Color(0xFFE11D48),
              title: 'Đơn giải trình / Bổ sung công',
              description: 'Giải trình quên quẹt thẻ, sự cố thiết bị nhận diện, bổ sung mốc giờ vào/ra thực tế theo phê duyệt.',
              infoBoxText: 'So sánh: Giờ hiện tại vs Đề xuất',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Đi công tác / Giải trình công'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.payments_outlined,
              iconBgColor: const Color(0xFFF3E8FF),
              iconColor: const Color(0xFF7C3AED),
              badgeText: 'Khấu trừ bảng lương',
              badgeBgColor: const Color(0xFFF3E8FF),
              badgeTextColor: const Color(0xFF7C3AED),
              title: 'Đơn xin tạm ứng lương',
              description: 'Đề nghị tạm ứng lương theo quy định công ty, phân bổ khấu trừ vào các kỳ bảng lương.',
              infoBoxText: 'Hạn mức: Tối đa 50% lương cơ bản',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn xin tạm ứng lương'),
            ),
            const SizedBox(height: 12),

            _buildCatalogCard(
              icon: Icons.badge_outlined,
              iconBgColor: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF4F46E5),
              badgeText: 'Phê duyệt HR & Pháp lý',
              badgeBgColor: const Color(0xFFEEF2FF),
              badgeTextColor: const Color(0xFF4F46E5),
              title: 'Đơn điều chỉnh thông tin nhân sự',
              description: 'Đề nghị đính chính thông tin định danh: số CCCD, ngày cấp, nơi cấp, ngày sinh hoặc họ tên pháp lý.',
              infoBoxText: 'Kèm minh chứng: Ảnh CCCD / Giấy tờ',
              buttonText: '+ Khởi tạo đơn này',
              onTap: () => _showCorrectionDialog(null, initialType: 'Đơn điều chỉnh thông tin nhân sự'),
            ),
          ] else if (_requestsSubTab == 2) ...[
            // ====================================================
            // SUB-TAB 2: PENDING REQUESTS (WITH SEARCH & FILTERS)
            // ====================================================
            () {
              final pendingList = _corrections.where((c) => c.status == 'PENDING').toList();
              final filtered = _filterCorrectionsList(pendingList);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestFilterBar(pendingList.length, filtered.length),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.inbox_outlined, size: 40, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 10),
                          Text(
                            _requestSearchKeyword.isNotEmpty || _requestTypeFilter != 'ALL' || _requestFromDate != null
                                ? 'Không tìm thấy hồ sơ phù hợp bộ lọc.'
                                : 'Không có đơn nào đang chờ duyệt.',
                            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildCorrectionCard(filtered[index]),
                    ),
                ],
              );
            }(),
          ] else if (_requestsSubTab == 3) ...[
            // ====================================================
            // SUB-TAB 3: HISTORY REQUESTS (WITH SEARCH & FILTERS)
            // ====================================================
            () {
              final historyList = _corrections.where((c) => c.status != 'PENDING').toList();
              final filtered = _filterCorrectionsList(historyList);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestFilterBar(historyList.length, filtered.length),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.history_toggle_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 10),
                          Text(
                            _requestSearchKeyword.isNotEmpty || _requestTypeFilter != 'ALL' || _requestFromDate != null
                                ? 'Không tìm thấy hồ sơ phù hợp bộ lọc.'
                                : 'Chưa có lịch sử đơn từ đã duyệt.',
                            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildCorrectionCard(filtered[index]),
                    ),
                ],
              );
            }(),
          ] else ...[
            // ====================================================
            // SUB-TAB 0: DRAFTS (WITH SEARCH & DATE RANGE FILTERS)
            // ====================================================
            () {
              final draftsList = _drafts;
              final filtered = _filterCorrectionsList(draftsList);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestFilterBar(draftsList.length, filtered.length),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.drafts_outlined, size: 40, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 10),
                          Text(
                            _requestSearchKeyword.isNotEmpty || _requestTypeFilter != 'ALL' || _requestFromDate != null || _requestToDate != null
                                ? 'Không tìm thấy bản nháp phù hợp bộ lọc.'
                                : 'Chưa có bản nháp nào được lưu.',
                            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildDraftCard(filtered[index]),
                    ),
                ],
              );
            }(),
          ],
        ],
      ),
    );
  }

  // ====================================================
  // SEARCH & FILTER BAR (MATCHING WEB 1:1)
  // ====================================================
  String _removeDiacritics(String str) {
    const withDiacritics = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    var result = str;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result.toLowerCase();
  }

  List<AttendanceCorrection> _filterCorrectionsList(List<AttendanceCorrection> source) {
    return source.where((c) {
      if (_requestSearchKeyword.trim().isNotEmpty) {
        final rawKw = _requestSearchKeyword.toLowerCase().trim();
        final normKw = _removeDiacritics(rawKw);

        final normReason = _removeDiacritics(c.reason);
        final normId = _removeDiacritics(c.id);
        final normDate = _removeDiacritics(c.requestDate);

        final matches = normReason.contains(normKw) ||
            normId.contains(normKw) ||
            normDate.contains(normKw) ||
            c.reason.toLowerCase().contains(rawKw) ||
            c.id.toLowerCase().contains(rawKw) ||
            c.requestDate.toLowerCase().contains(rawKw);

        if (!matches) return false;
      }

      if (_requestTypeFilter != 'ALL') {
        final normType = _removeDiacritics(_requestTypeFilter);
        final normReason = _removeDiacritics(c.reason);
        if (!normReason.contains(normType) && !c.reason.toLowerCase().contains(_requestTypeFilter.toLowerCase())) {
          return false;
        }
      }

      if (_requestStatusFilter != 'ALL') {
        if (c.status != _requestStatusFilter) return false;
      }

      if (_requestFromDate != null) {
        final d = DateTime.tryParse(c.requestDate);
        if (d != null && d.isBefore(DateTime(_requestFromDate!.year, _requestFromDate!.month, _requestFromDate!.day))) {
          return false;
        }
      }

      if (_requestToDate != null) {
        final d = DateTime.tryParse(c.requestDate);
        if (d != null && d.isAfter(DateTime(_requestToDate!.year, _requestToDate!.month, _requestToDate!.day, 23, 59, 59))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildRequestFilterBar(int totalCount, int filteredCount) {
    final bool hasActiveFilter = _requestSearchKeyword.isNotEmpty ||
        _requestTypeFilter != 'ALL' ||
        _requestStatusFilter != 'ALL' ||
        _requestFromDate != null ||
        _requestToDate != null;

    final typeOptions = [
      'ALL',
      'Phép năm',
      'Làm thêm giờ',
      'Đi công tác',
      'Đổi ca',
      'Giải trình',
      'Tạm ứng lương',
      'Thông tin nhân sự',
    ];

    final statusOptions = [
      {'val': 'ALL', 'label': 'Tất cả trạng thái'},
      {'val': 'PENDING', 'label': 'Chờ duyệt'},
      {'val': 'APPROVED', 'label': 'Đã phê duyệt'},
      {'val': 'REJECTED', 'label': 'Bị từ chối'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Row 1: Search textfield + Filter expand toggle button
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _requestSearchController,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo mã đơn, loại hoặc lý do...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _requestSearchKeyword.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _requestSearchController.clear();
                                setState(() => _requestSearchKeyword = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _requestSearchKeyword = val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _showAdvancedFilters ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _showAdvancedFilters ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: _showAdvancedFilters ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                      ),
                      if (hasActiveFilter) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Color(0xFF38BDF8), shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Row 2: Advanced filters panel (Collapsible)
          if (_showAdvancedFilters) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Dropdown 1: Tất cả loại đơn & Dropdown 2: Tất cả trạng thái
            Row(
              children: [
                // Loại đơn dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _requestTypeFilter,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                        items: typeOptions.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t == 'ALL' ? 'Tất cả loại đơn' : t, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _requestTypeFilter = val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Trạng thái dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _requestStatusFilter,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                        items: statusOptions.map((s) {
                          return DropdownMenuItem(
                            value: s['val']!,
                            child: Text(s['label']!, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _requestStatusFilter = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Date Range Row: Từ ngày - Đến ngày
            Row(
              children: [
                // Từ ngày
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _requestFromDate ?? DateTime.now(),
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2028),
                      );
                      if (picked != null) setState(() => _requestFromDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _requestFromDate != null
                                ? 'Từ: ${_requestFromDate!.day.toString().padLeft(2, '0')}/${_requestFromDate!.month.toString().padLeft(2, '0')}/${_requestFromDate!.year}'
                                : 'Từ ngày: dd/mm/yyyy',
                            style: TextStyle(
                              fontSize: 11,
                              color: _requestFromDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Đến ngày
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _requestToDate ?? DateTime.now(),
                        firstDate: _requestFromDate ?? DateTime(2025),
                        lastDate: DateTime(2028),
                      );
                      if (picked != null) setState(() => _requestToDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _requestToDate != null
                                ? 'Đến: ${_requestToDate!.day.toString().padLeft(2, '0')}/${_requestToDate!.month.toString().padLeft(2, '0')}/${_requestToDate!.year}'
                                : 'Đến: dd/mm/yyyy',
                            style: TextStyle(
                              fontSize: 11,
                              color: _requestToDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // Bottom Results Count & Reset Filter Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tìm thấy $filteredCount / $totalCount hồ sơ',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              if (hasActiveFilter)
                InkWell(
                  onTap: () {
                    _requestSearchController.clear();
                    setState(() {
                      _requestSearchKeyword = '';
                      _requestTypeFilter = 'ALL';
                      _requestStatusFilter = 'ALL';
                      _requestFromDate = null;
                      _requestToDate = null;
                    });
                  },
                  child: const Text(
                    'Đặt lại bộ lọc',
                    style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSubTabButton({
    required int index,
    required String label,
    int? count,
    String? badge,
  }) {
    final isSelected = _requestsSubTab == index;
    return InkWell(
      onTap: () => setState(() => _requestsSubTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 7 Catalog Cards Builder (Matching Web 1:1)
  Widget _buildCatalogCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required String title,
    required String description,
    required String infoBoxText,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeTextColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            description,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // Info Field Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              infoBoxText,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),

          // Action Button (+ Khởi tạo đơn này)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1B4B), // Dark Navy
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectionCard(AttendanceCorrection c) {
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusColor = const Color(0xFFD97706);
    String statusText = 'Chờ quản lý duyệt';

    if (c.status == 'APPROVED') {
      statusBg = const Color(0xFFECFDF5);
      statusColor = const Color(0xFF059669);
      statusText = 'Đã phê duyệt';
    } else if (c.status == 'REJECTED') {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFDC2626);
      statusText = 'Bị từ chối';
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ngày đề xuất: ${_formatDate(c.requestDate)}',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Giờ đề xuất: ${_formatTime(c.newCheckInAt)} — ${_formatTime(c.newCheckOutAt)}',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Lý do: ${c.reason}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          if (c.rejectionReason != null) ...[
            const SizedBox(height: 6),
            Text(
              'Lý do từ chối: ${c.rejectionReason}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDraftCard(AttendanceCorrection draft) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_document, size: 16, color: Color(0xFF475569)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ngày tạo đơn: ${_formatDate(draft.requestDate)}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 13, color: Color(0xFF64748B)),
                    SizedBox(width: 3),
                    Text(
                      'Bản nháp',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Text(
              'Nội dung: ${draft.reason}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _drafts.removeWhere((d) => d.id == draft.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa bản nháp.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                label: const Text('Xóa nháp', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCorrectionDialog(null, initialType: null, draftItem: draft),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text('Tiếp tục & Gửi duyệt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WEB-MATCHED CREATE REQUEST MODAL (ĐƠN NGHỈ PHÉP & GIẢI TRÌNH CÔNG)
  // ==========================================
  void _showCorrectionDialog(AttendanceRecord? item, {String? initialType, AttendanceCorrection? draftItem}) {
    String initialReason = '';
    String selectedLeaveType = initialType ?? (item != null ? 'Đi công tác / Giải trình công' : 'Phép năm (Hưởng nguyên lương)');
    final now = DateTime.now();
    DateTime fromDate = DateTime(now.year, now.month, now.day);
    DateTime toDate = DateTime(now.year, now.month, now.day);

    final List<String> leaveTypes = [
      'Phép năm (Hưởng nguyên lương)',
      'Đi công tác / Giải trình công',
      'Làm thêm giờ (Overtime)',
      'Đơn đổi ca làm việc',
      'Đơn giải trình / Bổ sung công',
      'Đơn xin tạm ứng lương',
      'Đơn điều chỉnh thông tin nhân sự',
      'Nghỉ ốm (Hưởng BHXH)',
      'Nghỉ việc riêng (Có lương)',
      'Nghỉ không hưởng lương',
    ];

    if (draftItem != null) {
      initialReason = draftItem.reason;
      for (final t in leaveTypes) {
        if (draftItem.reason.startsWith('[$t]')) {
          selectedLeaveType = t;
          initialReason = draftItem.reason.replaceFirst('[$t]', '').trim();
          break;
        }
      }
      final parsed = DateTime.tryParse(draftItem.requestDate);
      if (parsed != null) {
        fromDate = DateTime(parsed.year, parsed.month, parsed.day);
        toDate = DateTime(parsed.year, parsed.month, parsed.day);
      }
    } else if (item?.workDate != null) {
      final parsed = DateTime.tryParse(item!.workDate);
      if (parsed != null) {
        fromDate = DateTime(parsed.year, parsed.month, parsed.day);
        toDate = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    final reasonController = TextEditingController(text: initialReason);
    final durationController = TextEditingController(text: '1.0');
    double durationDays = 1.0;
    bool allowNegativeBalance = false;
    String? selectedFileName;
    String? modalErrorMessage;
    bool isSubmitting = false;
    const double currentAvailableBalance = 12.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final remainingBalance = currentAvailableBalance - durationDays;

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Top Handle & Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.description_outlined, size: 18, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Khởi tạo: Đơn xin nghỉ phép',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                              onPressed: () => Navigator.pop(ctx),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Nhập đầy đủ thông tin để gửi đơn chờ phê duyệt',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Text(
                                'Chờ người có thẩm quyền duyệt',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Quỹ khả dụng Card (Matching Web Top Box)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Quỹ khả dụng của loại nghỉ đã chọn:',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${currentAvailableBalance.toStringAsFixed(1)} ngày',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E1B4B),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Sau khi xin (${durationDays.toStringAsFixed(1)} ngày):',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${remainingBalance.toStringAsFixed(1)} ngày',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: remainingBalance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 2. Loại hình nghỉ phép (*)
                          const Text(
                            'Loại hình nghỉ phép *',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedLeaveType,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                items: leaveTypes.map((t) {
                                  return DropdownMenuItem(
                                    value: t,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.search, size: 14, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(t, overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedLeaveType = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. Từ ngày (*) và Đến ngày (*)
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Từ ngày *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: modalCtx,
                                          initialDate: fromDate,
                                          firstDate: DateTime(2025),
                                          lastDate: DateTime(2028),
                                        );
                                        if (picked != null) {
                                          setModalState(() {
                                            fromDate = DateTime(picked.year, picked.month, picked.day);
                                            if (toDate.isBefore(fromDate)) toDate = fromDate;
                                            final cleanFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
                                            final cleanTo = DateTime(toDate.year, toDate.month, toDate.day);
                                            final calculated = (cleanTo.difference(cleanFrom).inDays + 1).toDouble();
                                            durationDays = calculated;
                                            durationController.text = calculated.toStringAsFixed(1);
                                            modalErrorMessage = null;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${fromDate.day.toString().padLeft(2, '0')}/${fromDate.month.toString().padLeft(2, '0')}/${fromDate.year}',
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                            ),
                                            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Đến ngày *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: modalCtx,
                                          initialDate: toDate.isBefore(fromDate) ? fromDate : toDate,
                                          firstDate: fromDate,
                                          lastDate: DateTime(2028),
                                        );
                                        if (picked != null) {
                                          setModalState(() {
                                            toDate = DateTime(picked.year, picked.month, picked.day);
                                            final cleanFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
                                            final cleanTo = DateTime(toDate.year, toDate.month, toDate.day);
                                            final calculated = (cleanTo.difference(cleanFrom).inDays + 1).toDouble();
                                            durationDays = calculated;
                                            durationController.text = calculated.toStringAsFixed(1);
                                            modalErrorMessage = null;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${toDate.day.toString().padLeft(2, '0')}/${toDate.month.toString().padLeft(2, '0')}/${toDate.year}',
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                            ),
                                            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 4. Thời lượng nghỉ (Input + Quick Pills)
                          const Text(
                            'Thời lượng nghỉ',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: durationController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                            onChanged: (val) {
                              final d = double.tryParse(val.replaceAll(',', '.'));
                              if (d != null) {
                                setModalState(() {
                                  durationDays = d;
                                  modalErrorMessage = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Nhập số ngày hoặc giờ theo đơn vị của loại nghỉ; không tính OFF và lễ.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),

                          // Quick Pills: Nửa ngày (0.5) | Cả ngày (1.0) | 1.5 ngày | 2 ngày (2.0)
                          Row(
                            children: [
                              _buildQuickPill('0.5 ngày', 0.5, durationDays == 0.5, () {
                                setModalState(() {
                                  durationDays = 0.5;
                                  durationController.text = '0.5';
                                  modalErrorMessage = null;
                                });
                              }),
                              const SizedBox(width: 6),
                              _buildQuickPill('1.0 ngày', 1.0, durationDays == 1.0, () {
                                setModalState(() {
                                  durationDays = 1.0;
                                  durationController.text = '1.0';
                                  modalErrorMessage = null;
                                });
                              }),
                              const SizedBox(width: 6),
                              _buildQuickPill('1.5 ngày', 1.5, durationDays == 1.5, () {
                                setModalState(() {
                                  durationDays = 1.5;
                                  durationController.text = '1.5';
                                  modalErrorMessage = null;
                                });
                              }),
                              const SizedBox(width: 6),
                              _buildQuickPill('2.0 ngày', 2.0, durationDays == 2.0, () {
                                setModalState(() {
                                  durationDays = 2.0;
                                  durationController.text = '2.0';
                                  modalErrorMessage = null;
                                });
                              }),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 5. Checkbox Ứng phép / Âm phép Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEFCE8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFDE047)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: allowNegativeBalance,
                                    activeColor: const Color(0xFF0F172A),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) => setModalState(() => allowNegativeBalance = val ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Đăng ký chế độ Ứng phép / Cho phép Âm phép (tối đa 2 ngày)',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF854D0E)),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Áp dụng khi số dư phép không đủ. Số ngày âm sẽ được tự động bù trừ khi có ngày tích phép mới hoặc trừ vào quyết toán thôi việc.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFFA16207), height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 6. Chứng từ (PDF, PNG, JPEG; tối đa 10 MB)
                          const Text(
                            'Chứng từ (PDF, PNG, JPEG; tối đa 10 MB)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              try {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'xlsx', 'xls'],
                                  allowMultiple: false,
                                );
                                if (result != null && result.files.isNotEmpty) {
                                  final file = result.files.first;
                                  final sizeKb = (file.size / 1024).toStringAsFixed(1);
                                  final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(2);
                                  final sizeText = file.size > 1024 * 1024 ? '$sizeMb MB' : '$sizeKb KB';
                                  setModalState(() {
                                    selectedFileName = '${file.name} ($sizeText)';
                                  });
                                }
                              } catch (e) {
                                debugPrint('Error picking file: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Không thể chọn tệp: $e')),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Chọn tệp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      selectedFileName ?? 'Không có tệp nào được chọn',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: selectedFileName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        fontWeight: selectedFileName != null ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (selectedFileName != null)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                                      onPressed: () => setModalState(() => selectedFileName = null),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 7. Lý do khởi tạo đơn yêu cầu (*)
                          const Text(
                            'Lý do khởi tạo đơn yêu cầu *',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: reasonController,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Nhập chi tiết lý do và thông tin giải trình liên quan...',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 8. Footer Process Note (Matching Web Bottom Badge)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Quy trình áp dụng: Quy trình xét duyệt đơn từ nhân sự',
                                    style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'Node S khởi tạo',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pinned In-Modal Error Banner (Always visible right above action buttons)
                  if (modalErrorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              modalErrorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB91C1C),
                                height: 1.35,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setModalState(() => modalErrorMessage = null),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 2, left: 6),
                              child: Icon(Icons.close, size: 16, color: Color(0xFF991B1B)),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Bottom Action Buttons (Hủy | Lưu nháp | Gửi duyệt đơn)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Hủy', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            final reqDate = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
                            final draftReason = reasonController.text.trim().isEmpty ? '(Bản nháp chưa nhập lý do)' : reasonController.text.trim();
                            final draftObj = AttendanceCorrection(
                              id: draftItem?.id ?? 'DFT-${DateTime.now().millisecondsSinceEpoch}',
                              employeeId: _context?.employeeId ?? 'emp-01',
                              attendanceId: item?.id,
                              requestDate: reqDate,
                              newCheckInAt: '${reqDate}T08:00:00+07:00',
                              newCheckOutAt: '${reqDate}T17:30:00+07:00',
                              reason: '[$selectedLeaveType] $draftReason',
                              status: 'DRAFT',
                              createdAt: DateTime.now().toIso8601String(),
                            );

                            setState(() {
                              if (draftItem != null) {
                                final idx = _drafts.indexWhere((d) => d.id == draftItem.id);
                                if (idx != -1) {
                                  _drafts[idx] = draftObj;
                                } else {
                                  _drafts.insert(0, draftObj);
                                }
                              } else {
                                _drafts.insert(0, draftObj);
                              }
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã lưu bản nháp đơn thành công.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Lưu nháp', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (reasonController.text.trim().isEmpty) {
                                      setModalState(() {
                                        modalErrorMessage = 'Vui lòng nhập lý do khởi tạo đơn yêu cầu.';
                                      });
                                      return;
                                    }

                                    final cleanFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
                                    final cleanTo = DateTime(toDate.year, toDate.month, toDate.day);
                                    final daysSpan = cleanTo.difference(cleanFrom).inDays + 1;
                                    if (cleanFrom.isAfter(cleanTo)) {
                                      setModalState(() {
                                        modalErrorMessage = 'Từ ngày không được lớn hơn Đến ngày.';
                                      });
                                      return;
                                    }

                                    if (durationDays <= 0) {
                                      setModalState(() {
                                        modalErrorMessage = 'Thời lượng nghỉ phải lớn hơn 0 ngày.';
                                      });
                                      return;
                                    }

                                    if (durationDays > daysSpan.toDouble()) {
                                      setModalState(() {
                                        modalErrorMessage = 'Khoảng thời gian từ ${fromDate.day.toString().padLeft(2, '0')}/${fromDate.month.toString().padLeft(2, '0')} đến ${toDate.day.toString().padLeft(2, '0')}/${toDate.month.toString().padLeft(2, '0')} là $daysSpan ngày, thời lượng nghỉ (${durationDays.toStringAsFixed(1)} ngày) không được vượt quá số ngày đã chọn.';
                                      });
                                      return;
                                    }

                                    setModalState(() {
                                      isSubmitting = true;
                                      modalErrorMessage = null;
                                    });

                                    final fDate = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
                                    final tDate = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
                                    try {
                                      String? targetLeaveTypeId;
                                      if (_leaveTypes.isNotEmpty) {
                                        for (final lt in _leaveTypes) {
                                          if (selectedLeaveType.toLowerCase().contains(lt.name.toLowerCase()) ||
                                              lt.name.toLowerCase().contains(selectedLeaveType.toLowerCase()) ||
                                              (lt.code.isNotEmpty && selectedLeaveType.toUpperCase().contains(lt.code.toUpperCase()))) {
                                            targetLeaveTypeId = lt.id;
                                            break;
                                          }
                                        }
                                        targetLeaveTypeId ??= _leaveTypes.first.id;
                                      }

                                      final newCorr = await _service.createCorrection(
                                        employeeId: _context?.employeeId,
                                        attendanceId: item?.id,
                                        leaveTypeId: targetLeaveTypeId,
                                        requestDate: fDate,
                                        newCheckInAt: fDate,
                                        newCheckOutAt: tDate,
                                        reason: '[$selectedLeaveType] ${reasonController.text.trim()}',
                                        duration: durationDays,
                                        isNegativeLeave: allowNegativeBalance,
                                      );

                                      // Close modal ONLY on success
                                      Navigator.pop(ctx);

                                      setState(() {
                                        if (draftItem != null) {
                                          _drafts.removeWhere((d) => d.id == draftItem.id);
                                        }
                                      });
                                      final corrs = await _service.getCorrections();
                                      setState(() {
                                        if (corrs.isNotEmpty) {
                                          _corrections = corrs;
                                          if (!_corrections.any((c) => c.id == newCorr.id)) {
                                            _corrections.insert(0, newCorr);
                                          }
                                        } else {
                                          _corrections = [newCorr];
                                        }
                                        _requestsSubTab = 2; // Switch to Chờ duyệt (Pending) tab
                                      });
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.check_circle_outline, color: Colors.white),
                                                const SizedBox(width: 8),
                                                Expanded(child: Text('Đã gửi $selectedLeaveType lên cấp thẩm quyền phê duyệt thành công.')),
                                              ],
                                            ),
                                            backgroundColor: const Color(0xFF059669),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setModalState(() {
                                        isSubmitting = false;
                                        modalErrorMessage = e.toString().replaceAll('Exception: ', '');
                                      });
                                    }
                                  },
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send_rounded, size: 16),
                            label: Text(
                              isSubmitting ? 'Đang gửi...' : 'Gửi duyệt đơn',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1B4B), // Dark Indigo 950
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                          ),
                        ),
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

  Widget _buildQuickPill(String label, double value, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E1B4B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFFCBD5E1)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}

