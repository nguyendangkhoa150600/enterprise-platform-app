import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hrm_attendance_models.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import './notification_center_screen.dart';
import './my_requests_screen.dart';
import '../services/hrm_attendance_service.dart';
import '../utils/error_handler.dart';

class AttendanceScreen extends StatefulWidget {
  final int initialTabIndex;
  const AttendanceScreen({super.key, this.initialTabIndex = 0});

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
  final Set<String> _cancelledRequestIds = {};

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
  HrmTimesheetBoard? _timesheetBoard;
  bool _isLoadingTimesheet = false;

  String _parseSelectedMonthKey(String displayMonth) {
    final parts = displayMonth.split('/');
    final year = int.tryParse(parts.length > 1 ? parts[1].trim() : '2026') ?? 2026;
    final monthStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    final month = int.tryParse(monthStr) ?? 10;
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTimesheetBoard([String? monthKey]) async {
    final key = monthKey ?? _parseSelectedMonthKey(_selectedMonth);
    setState(() => _isLoadingTimesheet = true);
    try {
      final board = await _service.getTimesheetBoard(month: key, self: true);
      if (mounted) {
        setState(() {
          _timesheetBoard = board;
          _isLoadingTimesheet = false;
        });
      }
    } catch (e) {
      debugPrint('[AttendanceScreen] _loadTimesheetBoard error: $e');
      if (mounted) {
        setState(() => _isLoadingTimesheet = false);
      }
    }
  }


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
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 1));
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

  Future<List<AttendanceCorrection>> _loadLocalDrafts() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('hrm_attendance_drafts');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => AttendanceCorrection.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('[AttendanceScreen] _loadLocalDrafts error: $e');
    }
    return [];
  }

  Future<void> _saveLocalDrafts() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_drafts.map((d) => d.toJson()).toList());
      await sp.setString('hrm_attendance_drafts', encoded);
    } catch (e) {
      debugPrint('[AttendanceScreen] _saveLocalDrafts error: $e');
    }
  }

  Future<void> _loadAllAttendanceData() async {
    setState(() => _isLoading = true);
    final localDrafts = await _loadLocalDrafts();
    final results = await Future.wait([
      _service.getAttendanceContext(),
      _service.precheck(),
      _service.getTodayAttendance(),
      _service.getAttendanceHistory(),
      _service.getCorrections(),
      _service.getLeaveTypes(),
      _service.getDrafts(),
      _service.getTimesheetBoard(month: _parseSelectedMonthKey(_selectedMonth), self: true),
    ]);

    if (mounted) {
      final todayRec = results[2] as AttendanceRecord?;
      final allRemote = ((results[4] as List<AttendanceCorrection>?) ?? []).where((c) => !_cancelledRequestIds.contains(c.id)).toList();
      final explicitDrafts = (results[6] as List<AttendanceCorrection>?) ?? [];
      final combinedDrafts = <AttendanceCorrection>[
        ...explicitDrafts,
        ...allRemote.where((c) => c.status == 'DRAFT'),
        ...localDrafts.where((ld) => ld.id.startsWith('DFT-')),
      ];
      final uniqueDrafts = <AttendanceCorrection>[];
      for (final d in combinedDrafts) {
        if (!uniqueDrafts.any((x) => x.id == d.id)) {
          uniqueDrafts.add(d);
        }
      }

      setState(() {
        _context = results[0] as AttendanceContext?;
        _precheck = results[1] as PrecheckResult?;
        _todayRecord = todayRec;
        _history = (results[3] as List<AttendanceRecord>?) ?? [];
        _corrections = allRemote.where((c) => c.status != 'DRAFT').toList();
        _drafts = uniqueDrafts;
        _leaveTypes = (results[5] as List<LeaveType>?) ?? [];
        _timesheetBoard = results[7] as HrmTimesheetBoard?;
        _isInShift = todayRec?.firstCheckInAt != null && todayRec?.lastCheckOutAt == null;
        _isLoading = false;
        _isLoadingTimesheet = false;
      });
      _saveLocalDrafts();
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
          Consumer<NotificationProvider>(
            builder: (context, noti, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 21),
                    tooltip: 'Trung tâm thông báo',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
                    ),
                  ),
                  if (noti.unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        alignment: Alignment.center,
                        child: Text(
                          noti.unreadCount > 99 ? '99+' : '${noti.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined, size: 20),
            tooltip: 'Đơn từ của tôi',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
            ),
          ),
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

  // Web Style KPI Card
  Widget _buildWebKpiCard({
    required String label,
    required String value,
    required String unit,
    String? hint,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    bool isAlert = false,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isAlert ? const Color(0xFFB91C1C) : const Color(0xFF0F172A),
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          unit,
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (hint != null && hint.isNotEmpty)
                  Text(
                    hint,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (progress != null) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progress / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                ],
              ],
            ),
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
                    // Refresh Button
                    InkWell(
                      onTap: _isLoadingTimesheet ? null : () => _loadTimesheetBoard(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: _isLoadingTimesheet
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF4F46E5)),
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
                              if (val != null) {
                                setState(() => _selectedMonth = val);
                                _loadTimesheetBoard(_parseSelectedMonthKey(val));
                              }
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

    final MonthlyTimesheetRow? myRow = _timesheetBoard?.myEmployee != null
        ? MonthlyTimesheetRow.fromBoardEmployee(_timesheetBoard!.myEmployee!, _timesheetBoard!.myEmployee?.standard)
        : null;
    final Map<int, TimesheetCell> boardCellMap = myRow?.cells ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoadingTimesheet)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Color(0xFFEEF2FF),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            ),
          ),

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
                Text(
                  _timesheetBoard?.month != null
                      ? 'Kỳ: ${_timesheetBoard!.month.month}'
                      : 'Hiển thị 1 / 1 bản ghi',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_matrixSubTab == 0) ...[
          // Sub-Tab 0: Interactive Scrollable Matrix Table
          _buildMatrixTable(year, month, daysInMonth, dayRecordMap, myRow, boardCellMap),
          const SizedBox(height: 14),

          // Legend Box
          _buildMatrixLegend(),
        ] else ...[
          // Sub-Tab 1: Monthly Detailed KPI Breakdown
          _buildMatrixDetailBreakdown(year, month, daysInMonth, dayRecordMap, myRow, boardCellMap),
        ],
      ],
    );
  }

  // Matrix Table Component
  Widget _buildMatrixTable(
    int year,
    int month,
    int daysInMonth,
    Map<int, AttendanceRecord> dayRecordMap,
    MonthlyTimesheetRow? myRow,
    Map<int, TimesheetCell> boardCellMap,
  ) {
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
                  child: Text(
                    myRow?.employeeCode.isNotEmpty == true ? myRow!.employeeCode : 'ME (NV-001)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        myRow?.employeeName.isNotEmpty == true ? myRow!.employeeName : 'Lịch sử chấm công của tôi',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        myRow != null && (myRow.departmentName.isNotEmpty || myRow.positionName.isNotEmpty)
                            ? '${myRow.departmentName.isNotEmpty ? myRow.departmentName : "Ban Điều hành"} • ${myRow.positionName.isNotEmpty ? myRow.positionName : "Quản trị viên"}'
                            : 'Ban Điều hành • Quản trị viên',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                    final boardCell = boardCellMap[day];
                    final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                    final weekdayStr = weekdaysShort[dt.weekday - 1];

                    return InkWell(
                      onTap: () => _showDayDetailModal(day, dateStr, record, boardCell, weekdayStr),
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
                        child: _buildMatrixCellBadgeForBoard(boardCell, record),
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

  // Matrix Cell Badge Helper for TimesheetCell or fallback to AttendanceRecord
  Widget _buildMatrixCellBadgeForBoard(TimesheetCell? cell, AttendanceRecord? record) {
    if (cell != null) {
      if (cell.isLeave) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Text(
            cell.shiftCode.isNotEmpty ? cell.shiftCode : 'P',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
          ),
        );
      }
      if (cell.isLate) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Text(
            'Trễ',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
          ),
        );
      }
      if (cell.isAbnormal || cell.status == 'ABSENT' || cell.status == 'ABNORMAL') {
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
      }
      if (cell.workUnits > 0 || (cell.firstIn != null && cell.firstIn!.isNotEmpty)) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Text(
            cell.workUnits == 1.0 ? 'CC' : (cell.workUnits > 0 ? '${cell.workUnits}' : 'CC'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
          ),
        );
      }
      if (cell.status == 'OFF') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'OFF',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
          ),
        );
      }
      if (cell.status == 'FUTURE' || cell.status == 'NO_SCHEDULE') {
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
    }

    return _buildMatrixCellBadge(record);
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
    } else if (record.status == 'ABNORMAL' || record.status == 'ABSENT') {
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
              _buildLegendChip('OFF', 'Ngày nghỉ tuần', const Color(0xFFF1F5F9), const Color(0xFF475569), const Color(0xFFCBD5E1)),
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
  Widget _buildMatrixDetailBreakdown(
    int year,
    int month,
    int daysInMonth,
    Map<int, AttendanceRecord> dayRecordMap,
    MonthlyTimesheetRow? myRow,
    Map<int, TimesheetCell> boardCellMap,
  ) {
    final summary = myRow?.summary;

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

    final standardDays = summary?.standardWorkDays ?? 22.0;
    final actualWorkDays = summary?.actualWorkDays ?? (validDays + lateDays).toDouble();
    final lateCount = summary?.lateDays ?? lateDays;
    final lateMins = summary?.lateMinutes ?? totalLateMinutes;
    final earlyCount = summary?.earlyDays ?? 0;
    final earlyMins = summary?.earlyMinutes ?? 0;
    final leaveDays = summary?.leaveDays ?? 0.0;
    final absentCount = summary?.absentDays ?? 0;
    final otHours = summary?.otHours ?? 0.0;
    final abnormalCount = summary?.abnormalDays ?? abnormalDays;
    final tripCount = summary?.tripDays ?? 0;
    final unscheduledCount = summary?.unscheduledDays ?? 0;
    final rate = summary != null
        ? summary.completionRate.toStringAsFixed(1)
        : ((actualWorkDays / (standardDays > 0 ? standardDays : 1)) * 100).clamp(0, 100).toStringAsFixed(1);
    final rateDouble = double.tryParse(rate) ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Summary Cards (100% Synced with Web MyKpiStrip)
        // Row 1: Tổng công thực tế & Đi trễ
        Row(
          children: [
            Expanded(
              child: _buildWebKpiCard(
                label: 'Tổng công thực tế',
                value: actualWorkDays.toStringAsFixed(1),
                unit: '/ ${standardDays % 1 == 0 ? standardDays.toInt() : standardDays.toStringAsFixed(1)}',
                hint: summary?.standardHint ?? 'Động theo ngày công của tháng',
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFF059669),
                iconBg: const Color(0xFFECFDF5),
                progress: rateDouble,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWebKpiCard(
                label: 'Đi trễ',
                value: '$lateCount',
                unit: 'lần',
                hint: lateMins > 0 ? '$lateMins phút' : null,
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFF7ED),
                isAlert: lateCount > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: Về sớm & Nghỉ phép (P)
        Row(
          children: [
            Expanded(
              child: _buildWebKpiCard(
                label: 'Về sớm',
                value: '$earlyCount',
                unit: 'lần',
                hint: earlyMins > 0 ? '$earlyMins phút' : null,
                icon: Icons.history_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFF5F3FF),
                isAlert: earlyCount > 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWebKpiCard(
                label: 'Nghỉ phép (P)',
                value: leaveDays % 1 == 0 ? '${leaveDays.toInt()}' : leaveDays.toStringAsFixed(1),
                unit: 'ngày',
                icon: Icons.date_range_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 3: Nghỉ không phép (KP) & Tăng ca (TC)
        Row(
          children: [
            Expanded(
              child: _buildWebKpiCard(
                label: 'Nghỉ không phép (KP)',
                value: '$absentCount',
                unit: 'ngày',
                icon: Icons.alarm_off_rounded,
                iconColor: const Color(0xFFDC2626),
                iconBg: const Color(0xFFFEF2F2),
                isAlert: absentCount > 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWebKpiCard(
                label: 'Tăng ca (TC)',
                value: otHours.toStringAsFixed(1),
                unit: 'giờ',
                hint: 'Đã duyệt',
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF0284C7),
                iconBg: const Color(0xFFF0F9FF),
              ),
            ),
          ],
        ),

        // Extras Chips (Matching Web extras: Bất thường, Công tác, Chưa có ca)
        if (abnormalCount > 0 || tripCount > 0 || unscheduledCount > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (abnormalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Bất thường: ',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$abnormalCount ngày',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              if (tripCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Công tác (CT): ',
                        style: TextStyle(fontSize: 11, color: Color(0xFF4338CA), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$tripCount ngày',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF4338CA), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              if (unscheduledCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Chưa có ca: ',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$unscheduledCount ngày',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chi tiết các ngày đã ghi nhận công:',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '${boardCellMap.isNotEmpty ? boardCellMap.length : dayRecordMap.length} ngày',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (boardCellMap.isEmpty && dayRecordMap.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có dữ liệu chấm công cho tháng này.', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                )
              else
                ...List.generate(daysInMonth, (index) {
                  final day = daysInMonth - index;
                  final r = dayRecordMap[day];
                  final cell = boardCellMap[day];

                  // Only render if cell or record has meaningful activity
                  final hasActivity = (cell != null &&
                          (cell.workUnits > 0 ||
                              cell.isLate ||
                              cell.isLeave ||
                              cell.isAbnormal ||
                              (cell.firstIn != null && cell.firstIn!.isNotEmpty))) ||
                      (r != null);

                  if (!hasActivity) return const SizedBox.shrink();

                  final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final weekday = DateTime(year, month, day).weekday;
                  final weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][weekday - 1];

                  final inTime = cell?.firstIn?.isNotEmpty == true ? cell!.firstIn! : _formatTime(r?.firstCheckInAt);
                  final outTime = cell?.lastOut?.isNotEmpty == true ? cell!.lastOut! : _formatTime(r?.lastCheckOutAt);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _showDayDetailModal(day, dateStr, r, cell, weekdayShort),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$weekdayShort, ${_formatDate(dateStr)}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                if (cell?.shiftName.isNotEmpty == true)
                                  Text(
                                    cell!.shiftName,
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Vào: $inTime  |  Ra: $outTime',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                if (cell != null && cell.workUnits > 0)
                                  Text(
                                    '${cell.workUnits} công',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            _buildMatrixCellBadgeForBoard(cell, r),
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

  // Modal Bottom Sheet on Tapping Matrix Day Cell (100% Matching Web's MyDayPanel & Request List)
  void _showDayDetailModal(int day, String dateStr, AttendanceRecord? record, TimesheetCell? boardCell, String weekdayStr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final rawDay = boardCell?.rawBoardDay;

        // Today comparison
        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final isToday = dateStr == todayStr;
        final isFuture = dateStr.compareTo(todayStr) > 0 || (rawDay?.status == 'FUTURE');

        // Status pill matching Web dayStatusPill
        String statusLabel = 'Chưa có công';
        Color statusBg = const Color(0xFFF1F5F9);
        Color statusColor = const Color(0xFF475569);
        Color statusBorder = const Color(0xFFE2E8F0);

        final rawStatus = rawDay?.status ?? record?.status ?? '';
        final workdayUnits = rawDay?.workdayUnits ?? boardCell?.workUnits ?? (record?.status == 'VALID' ? 1.0 : 0.0);
        final lateMinutes = rawDay?.lateMinutes ?? boardCell?.lateMinutes ?? record?.lateMinutes ?? 0;
        final earlyMinutes = rawDay?.earlyLeaveMinutes ?? boardCell?.earlyMinutes ?? 0;

        if (isFuture) {
          statusLabel = 'Chưa tới ngày';
          statusBg = const Color(0xFFF1F5F9);
          statusColor = const Color(0xFF475569);
          statusBorder = const Color(0xFFE2E8F0);
        } else if (rawStatus == 'ABSENT') {
          statusLabel = 'Nghỉ không phép';
          statusBg = const Color(0xFFFEF2F2);
          statusColor = const Color(0xFFDC2626);
          statusBorder = const Color(0xFFFECACA);
        } else if (rawStatus == 'ABNORMAL') {
          statusLabel = 'Bất thường';
          statusBg = const Color(0xFFFDF4FF);
          statusColor = const Color(0xFFC026D3);
          statusBorder = const Color(0xFFF5D0FE);
        } else if (lateMinutes > 0 || earlyMinutes > 0 || rawStatus == 'LATE' || rawStatus == 'LATE_EARLY' || rawStatus == 'EARLY_LEAVE') {
          statusLabel = earlyMinutes > 0 && lateMinutes > 0
              ? 'Đi trễ, về sớm'
              : (earlyMinutes > 0 ? 'Về sớm' : 'Đi trễ');
          statusBg = const Color(0xFFFFF7ED);
          statusColor = const Color(0xFFEA580C);
          statusBorder = const Color(0xFFFED7AA);
        } else if (rawStatus.contains('LEAVE') || (boardCell?.isLeave ?? false)) {
          statusLabel = 'Nghỉ phép';
          statusBg = const Color(0xFFEFF6FF);
          statusColor = const Color(0xFF2563EB);
          statusBorder = const Color(0xFFBFDBFE);
        } else if (rawStatus == 'OFF') {
          statusLabel = 'Ngày nghỉ';
          statusBg = const Color(0xFFF1F5F9);
          statusColor = const Color(0xFF64748B);
          statusBorder = const Color(0xFFCBD5E1);
        } else if (rawStatus == 'HOLIDAY') {
          statusLabel = 'Ngày lễ';
          statusBg = const Color(0xFFF1F5F9);
          statusColor = const Color(0xFF64748B);
          statusBorder = const Color(0xFFCBD5E1);
        } else if (workdayUnits > 0 || (rawDay?.checkIn != null && rawDay!.checkIn!.isNotEmpty) || record?.status == 'VALID') {
          statusLabel = workdayUnits >= 1.0 ? 'Đủ công' : 'Chưa đủ công';
          statusBg = workdayUnits >= 1.0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7);
          statusColor = workdayUnits >= 1.0 ? const Color(0xFF059669) : const Color(0xFFD97706);
          statusBorder = workdayUnits >= 1.0 ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);
        }

        // Subtitle text: "Hôm nay", "Chưa tới ngày", "Đã qua"
        String subtitleText = isToday ? 'Hôm nay' : (isFuture ? 'Chưa tới ngày' : 'Đã qua');
        if (rawDay?.holidayName != null && rawDay!.holidayName!.isNotEmpty) {
          subtitleText += ' • Lễ: ${rawDay.holidayName}';
        }

        // 4 KPI tiles values (matching Web):
        final workedMinutes = rawDay?.workedMinutes ?? record?.workedMinutes ?? 0;
        final totalWorkedHours = (workedMinutes / 60.0).toStringAsFixed(1);
        final paidMinutes = rawDay?.paidMinutes ?? (workdayUnits * 480).toInt();
        final paidHours = (paidMinutes / 60.0).toStringAsFixed(1);
        final checkInTime = rawDay?.checkIn?.isNotEmpty == true
            ? rawDay!.checkIn!
            : (boardCell?.firstIn?.isNotEmpty == true
                ? boardCell!.firstIn!
                : (record?.firstCheckInAt != null ? _formatTime(record!.firstCheckInAt) : '--:--'));
        final checkOutTime = rawDay?.checkOut?.isNotEmpty == true
            ? rawDay!.checkOut!
            : (boardCell?.lastOut?.isNotEmpty == true
                ? boardCell!.lastOut!
                : (record?.lastCheckOutAt != null ? _formatTime(record!.lastCheckOutAt) : '--:--'));

        // Real Shift info from API
        final shiftName = rawDay?.shiftName ?? boardCell?.shiftName ?? 'Ca Hành Chính';
        final shiftStart = rawDay?.shiftStart ?? '07:30';
        final shiftEnd = rawDay?.shiftEnd ?? '17:00';
        final shiftBreakStart = rawDay?.shiftBreakStart ?? '11:30';
        final shiftBreakEnd = rawDay?.shiftBreakEnd ?? '13:00';
        final shiftBreakMinutes = rawDay?.shiftBreakMinutes ?? 90;
        final scheduledMinutes = rawDay?.scheduledMinutes ?? 480;
        final scheduledHours = (scheduledMinutes / 60.0).round();

        // Requests for THIS SPECIFIC DAY (đơn từ của ngày nào thì chỉ hiển thị ngày đó)
        final dayRequests = <HrmDayRequest>[];
        if (rawDay != null && rawDay.requests.isNotEmpty) {
          dayRequests.addAll(rawDay.requests);
        } else if (_timesheetBoard?.myEmployee != null) {
          final d = _timesheetBoard!.myEmployee!.days[dateStr];
          if (d != null && d.requests.isNotEmpty) {
            dayRequests.addAll(d.requests);
          }
        }

        int modalTab = 0;
        bool isShiftInfoOpen = true;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 8),

                  // Tab Switcher Header (Chi tiết ngày vs Đơn từ trong ngày)
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => modalTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: modalTab == 0 ? const Color(0xFFD97706) : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Chi tiết ngày',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: modalTab == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: modalTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => modalTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: modalTab == 1 ? const Color(0xFFD97706) : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Đơn từ trong ngày (${dayRequests.length})',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: modalTab == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: modalTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: modalTab == 0
                          ? _buildModalDayTab(
                              context: context,
                              weekdayStr: weekdayStr,
                              dateStr: dateStr,
                              subtitleText: subtitleText,
                              statusLabel: statusLabel,
                              statusBg: statusBg,
                              statusColor: statusColor,
                              statusBorder: statusBorder,
                              totalWorkedHours: totalWorkedHours,
                              paidHours: paidHours,
                              checkInTime: checkInTime,
                              checkOutTime: checkOutTime,
                              lateMinutes: lateMinutes,
                              earlyMinutes: earlyMinutes,
                              shiftName: shiftName,
                              shiftStart: shiftStart,
                              shiftEnd: shiftEnd,
                              shiftBreakStart: shiftBreakStart,
                              shiftBreakEnd: shiftBreakEnd,
                              shiftBreakMinutes: shiftBreakMinutes,
                              scheduledHours: scheduledHours,
                              isShiftInfoOpen: isShiftInfoOpen,
                              onToggleShiftInfo: () => setModalState(() => isShiftInfoOpen = !isShiftInfoOpen),
                              rawDay: rawDay,
                              record: record,
                              boardCell: boardCell,
                              dayRequests: dayRequests,
                              onExplain: () {
                                Navigator.pop(ctx);
                                _showCorrectionDialog(record);
                              },
                            )
                          : _buildModalRequestsTab(dayRequests),
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

  Widget _buildModalDayTab({
    required BuildContext context,
    required String weekdayStr,
    required String dateStr,
    required String subtitleText,
    required String statusLabel,
    required Color statusBg,
    required Color statusColor,
    required Color statusBorder,
    required String totalWorkedHours,
    required String paidHours,
    required String checkInTime,
    required String checkOutTime,
    required int lateMinutes,
    required int earlyMinutes,
    required String shiftName,
    required String shiftStart,
    required String shiftEnd,
    required String shiftBreakStart,
    required String shiftBreakEnd,
    required int shiftBreakMinutes,
    required int scheduledHours,
    required bool isShiftInfoOpen,
    required VoidCallback onToggleShiftInfo,
    required HrmBoardDay? rawDay,
    required AttendanceRecord? record,
    required TimesheetCell? boardCell,
    List<HrmDayRequest> dayRequests = const [],
    required VoidCallback onExplain,
  }) {
    final canExplain = rawDay?.status == 'ABSENT' || rawDay?.status == 'ABNORMAL' || lateMinutes > 0 || earlyMinutes > 0;
    final effectiveRequests = dayRequests.isNotEmpty ? dayRequests : (rawDay?.requests ?? const <HrmDayRequest>[]);

    // Leave info for DayBands banner (P)
    final hasLeave = rawDay?.leave != null || effectiveRequests.any((r) => r.kind == 'LEAVE') || (rawDay?.status != null && rawDay!.status.contains('LEAVE')) || (boardCell?.isLeave ?? false);
    String leaveDesc = 'Nghỉ phép năm (Có lương, trừ phép năm)';
    if (rawDay?.leave != null) {
      final lv = rawDay!.leave!;
      final name = lv.reasonName ?? 'Nghỉ phép';
      final pay = lv.paid ? 'Có lương' : 'Không lương';
      final annual = lv.annual ? ', trừ phép năm' : '';
      leaveDesc = '$name ($pay$annual)';
    } else {
      final req = effectiveRequests.where((r) => r.kind == 'LEAVE').firstOrNull;
      if (req != null) {
        final name = req.label ?? req.reasonName ?? 'Nghỉ phép năm';
        final isAnnual = name.toLowerCase().contains('năm');
        leaveDesc = '$name (Có lương${isAnnual ? ", trừ phép năm" : ""})';
      }
    }
    final leaveDaysNum = rawDay?.leave?.days ?? (rawDay?.workdayUnits ?? 1.0);
    final leaveDaysStr = leaveDaysNum == leaveDaysNum.roundToDouble()
        ? '${leaveDaysNum.toInt()} ngày'
        : '$leaveDaysNum ngày';

    final hasOt = rawDay?.otMinutes != null && rawDay!.otMinutes > 0;
    final hasTrip = rawDay?.tripId != null && rawDay!.tripId!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header (Icon, Date, Subtitle, Status Badge)
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3), // Soft yellow background as on Web
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month_rounded, size: 22, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$weekdayStr, ${_formatDate(dateStr)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusBorder),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. 4 Metric Tiles (Grid 2x2: Tổng giờ làm, Giờ công, Giờ vào, Giờ ra)
        Row(
          children: [
            Expanded(child: _buildDayMetricTile(label: 'Tổng giờ làm', value: totalWorkedHours)),
            const SizedBox(width: 8),
            Expanded(child: _buildDayMetricTile(label: 'Giờ công', value: paidHours)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDayMetricTile(
                label: 'Giờ vào',
                value: checkInTime,
                icon: Icons.login_rounded,
                iconBg: checkInTime != '--:--'
                    ? (lateMinutes > 0 ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5))
                    : const Color(0xFFF1F5F9),
                iconColor: checkInTime != '--:--'
                    ? (lateMinutes > 0 ? const Color(0xFFEA580C) : const Color(0xFF059669))
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDayMetricTile(
                label: 'Giờ ra',
                value: checkOutTime,
                icon: Icons.logout_rounded,
                iconBg: checkOutTime != '--:--'
                    ? (earlyMinutes > 0 ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5))
                    : const Color(0xFFF1F5F9),
                iconColor: checkOutTime != '--:--'
                    ? (earlyMinutes > 0 ? const Color(0xFFEA580C) : const Color(0xFF059669))
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3. Shift Timeline (Dòng thời gian ca làm)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimelineStep(label: 'Bắt đầu ca', time: shiftStart, isLast: false),
              _buildTimelineStep(label: 'Bắt đầu nghỉ giữa ca', time: shiftBreakStart, isLast: false),
              if (checkInTime != '--:--')
                _buildTimelineStep(
                  label: 'Chấm công vào',
                  time: checkInTime,
                  note: lateMinutes > 0 ? 'Trễ $lateMinutes phút' : null,
                  isAlert: lateMinutes > 0,
                  isSuccess: lateMinutes == 0,
                  isLast: false,
                ),
              _buildTimelineStep(label: 'Kết thúc nghỉ giữa ca', time: shiftBreakEnd, isLast: false),
              if (checkOutTime != '--:--')
                _buildTimelineStep(
                  label: 'Chấm công ra',
                  time: checkOutTime,
                  note: earlyMinutes > 0 ? 'Sớm $earlyMinutes phút' : null,
                  isAlert: earlyMinutes > 0,
                  isSuccess: earlyMinutes == 0,
                  isLast: false,
                ),
              _buildTimelineStep(label: 'Kết thúc ca', time: shiftEnd, isLast: true),

              // Note when punch in / punch out are missing (Matching Web text-fuchsia-700)
              if (checkInTime == '--:--' && checkOutTime == '--:--') ...[
                const SizedBox(height: 8),
                const Text(
                  'Chưa có giờ vào và giờ ra',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA21CAF), // Fuchsia / Purple matching web
                  ),
                ),
              ] else if (checkInTime == '--:--') ...[
                const SizedBox(height: 8),
                const Text(
                  'Chưa có giờ vào',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA21CAF),
                  ),
                ),
              ] else if (checkOutTime == '--:--') ...[
                const SizedBox(height: 8),
                const Text(
                  'Chưa có giờ ra',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA21CAF),
                  ),
                ),
              ],
            ],
          ),
        ),

        // DayBands (Dải trạng thái: Nghỉ phép / Tăng ca / Công tác)
        if (hasLeave)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('P', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    leaveDesc,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                ),
                Text(
                  leaveDaysStr,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        if (hasOt)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D28D9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('TC', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tăng ca đã duyệt',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5B21B6)),
                  ),
                ),
                Text(
                  '${((rawDay?.otMinutes ?? 0) / 60.0).toStringAsFixed(1)} giờ',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6), fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        if (hasTrip)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4338CA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('CT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Có đơn công tác được duyệt: tính công theo đơn, không cần chấm công.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3730A3)),
                  ),
                ),
              ],
            ),
          ),

        // Section "Đơn từ áp dụng cho ngày này" (Matching Web DayRequestList)
        if (effectiveRequests.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đơn từ áp dụng cho ngày này',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                ...effectiveRequests.map((req) => _buildAppliedRequestCard(context, req)),
                const SizedBox(height: 4),
                const Text(
                  'Chỉ đơn đã duyệt được tính vào công; đơn chờ duyệt hoặc bị từ chối chỉ để tham khảo.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // 4. Collapsible "Thông tin ca làm"
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: onToggleShiftInfo,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Thông tin ca làm',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Icon(
                      isShiftInfoOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
              if (isShiftInfoOpen) ...[
                const SizedBox(height: 12),
                _buildModalInfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Ca làm việc',
                  value: '$shiftName ($shiftStart - $shiftEnd)',
                ),
                const SizedBox(height: 10),
                _buildModalInfoRow(
                  icon: Icons.access_time_rounded,
                  label: 'Thời gian làm việc',
                  value: '$scheduledHours giờ',
                ),
                const SizedBox(height: 10),
                _buildModalInfoRow(
                  icon: Icons.timelapse_outlined,
                  label: 'Nghỉ giữa ca',
                  value: '$shiftBreakStart - $shiftBreakEnd (${(shiftBreakMinutes ~/ 60) > 0 ? "${shiftBreakMinutes ~/ 60} giờ " : ""}${shiftBreakMinutes % 60 > 0 ? "${shiftBreakMinutes % 60} phút" : ""})',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. "Xem chi tiết chấm công >" Button (Matching Web MyDayPanel)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              // Open raw punch log / records for this day
              _showDayPunchesDetailSheet(context, dateStr, rawDay, record);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: Colors.white,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Xem chi tiết chấm công',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFB45309)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 6. Action Button (Làm đơn giải trình nếu có sai lệch)
        if (canExplain) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onExplain,
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
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đóng', style: TextStyle(color: Color(0xFF475569))),
          ),
        ),
      ],
    );
  }

  Widget _buildModalRequestsTab(List<HrmDayRequest> requests) {
    if (requests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: const Text(
          'Không có đơn từ nào trong ngày này.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      );
    }

    return Column(
      children: requests.map((req) {
        Color badgeBg = const Color(0xFFFEF3C7);
        Color badgeColor = const Color(0xFFD97706);
        String badgeText = 'Chờ duyệt';

        if (req.status == 'APPROVED') {
          badgeBg = const Color(0xFFECFDF5);
          badgeColor = const Color(0xFF059669);
          badgeText = 'Đã duyệt';
        } else if (req.status == 'REJECTED') {
          badgeBg = const Color(0xFFFEF2F2);
          badgeColor = const Color(0xFFDC2626);
          badgeText = 'Từ chối';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.label ?? (req.reasonName ?? req.kind),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    if (req.fromAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        req.fromAt!.length >= 10 ? req.fromAt!.substring(0, 10) : req.fromAt!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDateTimeVn(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatRequestTimeRange(HrmDayRequest req) {
    final from = _formatDateTimeVn(req.fromAt);
    final to = _formatDateTimeVn(req.toAt);
    if (from.isEmpty || to.isEmpty) return from.isNotEmpty ? from : to;
    if (from.length >= 10 && to.length >= 10 && from.substring(0, 10) == to.substring(0, 10)) {
      final toTime = to.length > 11 ? to.substring(11) : to;
      return '$from - $toTime';
    }
    return '$from - $to';
  }

  String _formatMinutesToHours(int? minutes) {
    if (minutes == null || minutes <= 0) return '0:00';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  String _getRequestLetter(String kind) {
    switch (kind.toUpperCase()) {
      case 'LEAVE':
        return 'P';
      case 'OT':
        return 'TC';
      case 'TRIP':
        return 'CT';
      case 'CORRECTION':
        return 'GT';
      case 'SHIFT_CHANGE':
        return 'DC';
      case 'CUSTOM':
        return 'KH';
      default:
        return 'P';
    }
  }

  String _getRequestKindLabel(String kind) {
    switch (kind.toUpperCase()) {
      case 'LEAVE':
        return 'Đơn nghỉ';
      case 'OT':
        return 'Tăng ca';
      case 'TRIP':
        return 'Công tác';
      case 'CORRECTION':
        return 'Giải trình công';
      case 'SHIFT_CHANGE':
        return 'Đổi ca';
      case 'CUSTOM':
        return 'Đơn khác';
      default:
        return 'Đơn từ';
    }
  }

  String _getRequestSummary(HrmDayRequest req) {
    final kindLabel = _getRequestKindLabel(req.kind);
    final label = req.label ?? (req.kind == 'LEAVE' ? 'Nghỉ phép năm' : '');
    final minutes = req.minutes;
    String hoursPart = '';
    if (minutes != null && minutes > 0) {
      final hours = minutes / 60.0;
      final hoursStr = hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toStringAsFixed(1);
      if (req.kind == 'OT') {
        hoursPart = '$hoursStr giờ đã duyệt';
      } else if (req.kind == 'LEAVE') {
        hoursPart = '$hoursStr giờ hưởng lương';
      } else {
        hoursPart = '$hoursStr giờ';
      }
    }

    final parts = <String>[];
    if (label.isNotEmpty) parts.add(label);
    if (hoursPart.isNotEmpty) parts.add(hoursPart);

    if (parts.isNotEmpty) {
      return '$kindLabel: ${parts.join(" - ")}';
    }
    return kindLabel;
  }

  Widget _buildAppliedRequestCard(BuildContext context, HrmDayRequest req) {
    final letter = _getRequestLetter(req.kind);
    final summary = _getRequestSummary(req);

    Color badgeBg = const Color(0xFFFEF3C7);
    Color badgeColor = const Color(0xFFD97706);
    Color badgeBorder = const Color(0xFFFDE68A);
    String badgeText = 'Chờ duyệt';

    if (req.status == 'APPROVED') {
      badgeBg = const Color(0xFFECFDF5);
      badgeColor = const Color(0xFF059669);
      badgeBorder = const Color(0xFFA7F3D0);
      badgeText = 'Đã duyệt';
    } else if (req.status == 'REJECTED') {
      badgeBg = const Color(0xFFFEF2F2);
      badgeColor = const Color(0xFFDC2626);
      badgeBorder = const Color(0xFFFECACA);
      badgeText = 'Từ chối';
    }

    final timeRange = _formatRequestTimeRange(req);
    final createdStr = _formatDateTimeVn(req.createdAt);
    final hoursStr = _formatMinutesToHours(req.minutes);

    final details = <MapEntry<String, String>>[];
    if (timeRange.isNotEmpty) details.add(MapEntry('Thời gian', timeRange));
    if (req.label != null && req.label!.isNotEmpty) details.add(MapEntry(req.kind == 'LEAVE' ? 'Loại nghỉ' : 'Nội dung', req.label!));
    if (req.description != null && req.description!.isNotEmpty && req.description != req.label) {
      details.add(MapEntry('Ghi chú', req.description!));
    }
    if (req.kind == 'LEAVE' && req.minutes != null && req.minutes! > 0) {
      details.add(MapEntry('Giờ hưởng lương trong ngày', hoursStr));
    } else if (req.kind == 'OT' && req.minutes != null && req.minutes! > 0) {
      details.add(MapEntry('Số giờ tăng ca', hoursStr));
    }
    if (createdStr.isNotEmpty) details.add(MapEntry('Ngày tạo đơn', createdStr));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      summary,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showRequestDetailModal(context, req),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mở đơn',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...details.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _showRequestDetailModal(BuildContext context, HrmDayRequest req) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
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
              Text(
                _getRequestSummary(req),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              if (req.fromAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Thời gian: ${_formatRequestTimeRange(req)}', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                ),
              if (req.label != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Loại đơn: ${req.label}', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                ),
              if (req.description != null && req.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Lý do / Ghi chú: ${req.description}', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
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

  void _showDayPunchesDetailSheet(BuildContext context, String dateStr, HrmBoardDay? rawDay, AttendanceRecord? record) {
    // Gather punches from record or history or rawDay checkIn/checkOut
    final punches = <AttendancePunch>[];
    if (record != null && record.punchList.isNotEmpty) {
      punches.addAll(record.punchList);
    } else {
      for (final h in _history) {
        if (h.workDate == dateStr) {
          if (h.punchList.isNotEmpty) {
            punches.addAll(h.punchList);
          } else {
            if (h.firstCheckInAt != null) {
              punches.add(AttendancePunch(
                punchType: 'IN',
                occurredAt: h.firstCheckInAt!,
                verificationMethod: h.attendanceSource,
                siteName: h.matchedSiteName,
              ));
            }
            if (h.lastCheckOutAt != null) {
              punches.add(AttendancePunch(
                punchType: 'OUT',
                occurredAt: h.lastCheckOutAt!,
                verificationMethod: h.attendanceSource,
                siteName: h.matchedSiteName,
              ));
            }
          }
        }
      }
    }

    // Fallback to rawDay checkIn / checkOut if list still empty but check-in exists
    if (punches.isEmpty) {
      if (rawDay?.checkIn != null && rawDay!.checkIn!.isNotEmpty && rawDay.checkIn != '--:--') {
        punches.add(AttendancePunch(
          punchType: 'IN',
          occurredAt: '${dateStr}T${rawDay.checkIn}:00',
          verificationMethod: 'MÁY CHẤM CÔNG',
          siteName: rawDay.shiftName,
        ));
      }
      if (rawDay?.checkOut != null && rawDay!.checkOut!.isNotEmpty && rawDay.checkOut != '--:--') {
        punches.add(AttendancePunch(
          punchType: 'OUT',
          occurredAt: '${dateStr}T${rawDay.checkOut}:00',
          verificationMethod: 'MÁY CHẤM CÔNG',
          siteName: rawDay.shiftName,
        ));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chi tiết chấm công (${_formatDate(dateStr)})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (punches.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: const Center(
                    child: Text(
                      'Không có dữ liệu quẹt thẻ cho ngày này.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: punches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (c, idx) {
                      final p = punches[idx];
                      final isCheckIn = p.punchType.toUpperCase() == 'IN' || p.punchType == 'Vào';
                      final deviceOrMethod = p.deviceName?.isNotEmpty == true
                          ? p.deviceName
                          : (p.verificationMethod?.isNotEmpty == true
                              ? p.verificationMethod
                              : (p.siteName?.isNotEmpty == true ? p.siteName : null));

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
                              decoration: BoxDecoration(
                                color: isCheckIn ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                                size: 18,
                                color: isCheckIn ? const Color(0xFF059669) : const Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isCheckIn ? 'Quẹt vào' : 'Quẹt ra',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  if (deviceOrMethod != null)
                                    Text(
                                      'Phương thức: $deviceOrMethod',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              p.occurredAt.length > 5 ? _formatTime(p.occurredAt) : p.occurredAt,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayMetricTile({
    required String label,
    required String value,
    IconData? icon,
    Color? iconBg,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg ?? const Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: iconColor ?? const Color(0xFF059669)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String label,
    required String time,
    String? note,
    bool isAlert = false,
    bool isSuccess = false,
    required bool isLast,
  }) {
    Color dotColor = const Color(0xFF94A3B8);
    Color dotBorder = const Color(0xFFCBD5E1);
    if (isAlert) {
      dotColor = const Color(0xFFEA580C);
      dotBorder = const Color(0xFFEA580C);
    } else if (isSuccess) {
      dotColor = const Color(0xFF059669);
      dotBorder = const Color(0xFF059669);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dot and vertical line
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: isAlert || isSuccess ? dotColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotBorder, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                      if (note != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isAlert ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isAlert ? const Color(0xFFEA580C) : const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ),
      ],
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
              final userFullName = (auth.fullName?.isNotEmpty == true)
                  ? auth.fullName!
                  : (_context?.fullName?.isNotEmpty == true
                      ? _context!.fullName
                      : (auth.email?.split('@').first ?? 'Nhân viên'));
              final employeeCode = (_context?.employeeCode?.isNotEmpty == true)
                  ? _context!.employeeCode
                  : '--';
              final userEmail = auth.email ?? '';
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
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      userFullName,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'CHÍNH THỨC (Official)',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Mã: $employeeCode',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            runSpacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.mail_outline, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 3),
                                  Text(
                                    userEmail,
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.badge_outlined, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 3),
                                  Text(
                                    auth.isTenantAdmin
                                        ? 'Tenant Administrator'
                                        : (auth.isPlatformAdmin
                                            ? 'Platform Administrator'
                                            : (auth.roles.isNotEmpty ? auth.roles.first : 'Tài khoản nhân viên')),
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (_context?.shift != null)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_context!.shift.name} (${_context!.shift.startTime.substring(0, 5)} - ${_context!.shift.endTime.substring(0, 5)})',
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
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
              final filtered = _filterCorrectionsList(draftsList, isDraftTab: true);

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

  List<AttendanceCorrection> _filterCorrectionsList(List<AttendanceCorrection> source, {bool isDraftTab = false}) {
    return source.where((c) {
      if (_cancelledRequestIds.contains(c.id)) return false;
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

      if (!isDraftTab && _requestStatusFilter != 'ALL') {
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
    String statusText = 'Chờ phê duyệt';

    if (c.status == 'DRAFT') {
      statusBg = const Color(0xFFF1F5F9);
      statusColor = const Color(0xFF475569);
      statusText = 'Bản nháp';
    } else if (c.status == 'APPROVED') {
      statusBg = const Color(0xFFECFDF5);
      statusColor = const Color(0xFF059669);
      statusText = 'Đã phê duyệt';
    } else if (c.status == 'REJECTED' || c.status == 'CANCELLED') {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFDC2626);
      statusText = c.status == 'CANCELLED' ? 'Đã thu hồi' : 'Bị từ chối';
    }

    String title = 'Đơn xin nghỉ phép';
    String cleanReason = c.reason;
    if (c.leaveTypeName != null && c.leaveTypeName!.isNotEmpty) {
      title = c.leaveTypeName!;
    } else {
      final match = RegExp(r'^\[(.*?)\]').firstMatch(c.reason);
      if (match != null) {
        title = match.group(1)!;
        cleanReason = c.reason.substring(match.end).trim();
      }
    }
    if (cleanReason.isEmpty) cleanReason = c.reason;

    final code = c.id.length >= 8 ? c.id.substring(c.id.length - 8).toUpperCase() : (c.id.isNotEmpty ? c.id.toUpperCase() : '8E86BF8B');

    return InkWell(
      onTap: () => _showCorrectionDetailDialog(c),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                Text(
                  'LEAVE - $code',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  '${_formatDate(c.fromDate ?? c.requestDate)} - ${_formatDate(c.toDate ?? c.requestDate)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                ),
                if (c.duration != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${c.duration!.toStringAsFixed(c.duration! % 1 == 0 ? 0 : 1)} ngày)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Text(
                'Lý do: $cleanReason',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Xem chi tiết',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
                SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 16, color: Color(0xFF2563EB)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WEB-MATCHED LEAVE REQUEST DETAIL DIALOG
  // ==========================================
  void _showCorrectionDetailDialog(AttendanceCorrection c) {
    String title = 'Đơn xin nghỉ phép';
    String cleanReason = c.reason;
    if (c.leaveTypeName != null && c.leaveTypeName!.isNotEmpty) {
      title = c.leaveTypeName!;
    } else {
      final match = RegExp(r'^\[(.*?)\]').firstMatch(c.reason);
      if (match != null) {
        title = match.group(1)!;
        cleanReason = c.reason.substring(match.end).trim();
      }
    }
    if (cleanReason.isEmpty) cleanReason = c.reason;

    final code = c.id.length >= 8 ? c.id.substring(c.id.length - 8).toUpperCase() : (c.id.isNotEmpty ? c.id.toUpperCase() : '8E86BF8B');

    String statusLabel = 'Chờ phê duyệt';
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusColor = const Color(0xFFD97706);
    if (c.status == 'APPROVED') {
      statusLabel = 'Đã phê duyệt';
      statusBg = const Color(0xFFECFDF5);
      statusColor = const Color(0xFF059669);
    } else if (c.status == 'REJECTED' || c.status == 'CANCELLED') {
      statusLabel = c.status == 'CANCELLED' ? 'Đã thu hồi' : 'Bị từ chối';
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFDC2626);
    }

    final fromFormatted = _formatDate(c.fromDate ?? c.requestDate);
    final toFormatted = _formatDate(c.toDate ?? c.requestDate);
    final createdFormatted = _formatDate(c.createdAt);
    final durationStr = c.duration != null ? '${c.duration!.toStringAsFixed(c.duration! % 1 == 0 ? 0 : 1)} ngày' : '1 ngày';
    final employeeName = c.employeeName ?? _context?.fullName ?? 'Nguyễn Tấn Tài';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            bool isCancelling = false;

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Top Handle & Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
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
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'LEAVE - $code',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4338CA), // Indigo 700
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            text: 'Tạo ngày $createdFormatted bởi ',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            children: [
                              TextSpan(
                                text: employeeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
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
                          // 1. THÔNG TIN NGHIỆP VỤ
                          Row(
                            children: [
                              const Icon(Icons.description_outlined, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              const Text(
                                'THÔNG TIN NGHIỆP VỤ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
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
                                    const Text('Thời gian hiệu lực:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                    Text(
                                      '$fromFormatted - $toFormatted',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Thời lượng / Khối lượng:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                    Text(
                                      durationStr,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text('Lý do khởi tạo:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    cleanReason,
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. THÔNG TIN HỖ TRỢ & ĐIỀU KIỆN ÁP DỤNG
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              const Text(
                                'THÔNG TIN HỖ TRỢ & ĐIỀU KIỆN ÁP DỤNG',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Quỹ phép khả dụng của nhân viên:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                Text(
                                  '---- ngày',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. TIẾN ĐỘ QUY TRÌNH
                          const Text(
                            'TIẾN ĐỘ QUY TRÌNH',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8), // Blue 700
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                // Step 1: Created
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFDCFCE7), // Green 100
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, size: 14, color: Color(0xFF16A34A)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Nhân viên khởi tạo yêu cầu',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            createdFormatted,
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // Step connector
                                Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Container(
                                    width: 2,
                                    height: 18,
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                // Step 2: Approver
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: c.status == 'APPROVED' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        c.status == 'APPROVED' ? Icons.check : Icons.circle,
                                        size: c.status == 'APPROVED' ? 14 : 8,
                                        color: c.status == 'APPROVED' ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          RichText(
                                            text: const TextSpan(
                                              text: 'Cấp thẩm quyền phê duyệt: ',
                                              style: TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                              children: [
                                                TextSpan(
                                                  text: 'Quản lý trực tiếp',
                                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            c.status == 'APPROVED'
                                                ? 'Đã xét duyệt thành công'
                                                : (c.status == 'REJECTED'
                                                    ? 'Đã từ chối đơn: ${c.rejectionReason ?? ""}'
                                                    : 'Đang chờ xét duyệt (SLA 24h)'),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: c.status == 'REJECTED' ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4. KẾT QUẢ XỬ LÝ & ĐỒNG BỘ DỮ LIỆU
                          Row(
                            children: [
                              const Icon(Icons.sync_alt, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              const Text(
                                'KẾT QUẢ XỬ LÝ & ĐỒNG BỘ DỮ LIỆU',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Trạng thái áp dụng:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        c.status == 'APPROVED' ? 'Đã áp dụng' : 'Chờ áp dụng',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Đồng bộ Timesheet / Payroll:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                    Text(
                                      c.status == 'APPROVED' ? 'Đã đồng bộ' : 'Chưa đồng bộ',
                                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Actions (Rút / Hủy đơn & Đóng)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        if (c.status == 'PENDING' || c.status == 'DRAFT') ...[
                          OutlinedButton.icon(
                            onPressed: isCancelling
                                ? null
                                : () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('Xác nhận rút đơn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                        content: const Text('Bạn có chắc chắn muốn rút / hủy đơn yêu cầu này?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dCtx, false),
                                            child: const Text('Quay lại'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(dCtx, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFDC2626),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Rút đơn'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      setModalState(() => isCancelling = true);
                                      final success = await _service.cancelCorrection(c.id);
                                      if (mounted) {
                                        Navigator.pop(ctx);
                                        _cancelledRequestIds.add(c.id);
                                        setState(() {
                                          _corrections.removeWhere((item) => item.id == c.id || _cancelledRequestIds.contains(item.id));
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(success ? 'Đã rút đơn thành công trên hệ thống.' : 'Đã thực hiện rút đơn.'),
                                            backgroundColor: const Color(0xFF059669),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                            label: const Text('Rút / Huỷ đơn', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFECACA)),
                              backgroundColor: const Color(0xFFFEF2F2),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const Spacer(),
                        ] else ...[
                          const Spacer(),
                        ],
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1B4B), // Dark Indigo 950
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: const Text('Đóng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

  Widget _buildDraftCard(AttendanceCorrection draft) {
    String draftType = 'Nghỉ phép';
    String cleanReason = draft.reason;
    final match = RegExp(r'^\[(.*?)\]').firstMatch(draft.reason);
    if (match != null) {
      draftType = match.group(1)!;
      cleanReason = draft.reason.substring(match.end).trim();
    }
    if (cleanReason.isEmpty) cleanReason = '(Chưa nhập lý do)';

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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draftType,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            'Ngày đề nghị: ${_formatDate(draft.requestDate)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
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
                child: const Text(
                  'Bản nháp',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lý do: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                Expanded(
                  child: Text(
                    cleanReason,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  String kind = 'leave';
                  final lower = (draft.leaveTypeName ?? draft.reason).toLowerCase();
                  if (lower.contains('làm thêm') || lower.contains('ot')) {
                    kind = 'ot';
                  } else if (lower.contains('công tác')) {
                    kind = 'business_trip';
                  } else if (lower.contains('đổi ca')) {
                    kind = 'shift_change';
                  } else if (lower.contains('giải trình') || lower.contains('bổ sung công')) {
                    kind = 'correction';
                  } else if (lower.contains('tạm ứng')) {
                    kind = 'advance';
                  } else if (lower.contains('hồ sơ')) {
                    kind = 'profile_correction';
                  }

                  setState(() {
                    _drafts.removeWhere((d) => d.id == draft.id);
                  });
                  _saveLocalDrafts();

                  if (!draft.id.startsWith('DFT-')) {
                    await _service.deleteDraft(
                      draft.id,
                      kind: kind,
                      expectedUpdatedAt: draft.createdAt,
                    );
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa bản nháp thành công.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                label: const Text('Xóa', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showCorrectionDialog(null, initialType: draftType, draftItem: draft),
                icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF475569)),
                label: const Text('Sửa', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCorrectionDialog(null, initialType: draftType, draftItem: draft),
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Gửi duyệt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
    final List<String> baseLeaveTypes = [
      'Phép năm (Hưởng nguyên lương)',
      'Nghỉ phép',
      'Đi công tác / Giải trình công',
      'Làm thêm giờ (Overtime)',
      'Đơn đổi ca làm việc',
      'Đơn giải trình / Bổ sung công',
      'Đơn xin tạm ứng lương',
      'Đơn điều chỉnh thông tin nhân sự',
      'Nghỉ ốm (Hưởng BHXH)',
      'Nghỉ việc riêng (Có lương)',
      'Nghỉ không hưởng lương',
      ..._leaveTypes.map((l) => l.name),
    ];
    final List<String> leaveTypes = [];
    for (final t in baseLeaveTypes) {
      if (!leaveTypes.contains(t)) leaveTypes.add(t);
    }

    String initialReason = '';
    String selectedLeaveType = initialType ?? (item != null ? 'Đi công tác / Giải trình công' : leaveTypes.first);
    final now = DateTime.now();
    DateTime fromDate = DateTime(now.year, now.month, now.day);
    DateTime toDate = DateTime(now.year, now.month, now.day);
    double durationDays = 1.0;

    if (draftItem != null) {
      initialReason = draftItem.reason;
      final match = RegExp(r'^\[(.*?)\]').firstMatch(draftItem.reason);
      if (match != null) {
        final extractedType = match.group(1)!;
        initialReason = draftItem.reason.substring(match.end).trim();
        selectedLeaveType = extractedType;
      }
      if (draftItem.leaveTypeName != null && draftItem.leaveTypeName!.isNotEmpty) {
        selectedLeaveType = draftItem.leaveTypeName!;
      }

      if (draftItem.fromDate != null && draftItem.fromDate!.isNotEmpty) {
        final pf = DateTime.tryParse(draftItem.fromDate!);
        if (pf != null) fromDate = DateTime(pf.year, pf.month, pf.day);
      } else if (draftItem.requestDate.isNotEmpty) {
        final pr = DateTime.tryParse(draftItem.requestDate);
        if (pr != null) fromDate = DateTime(pr.year, pr.month, pr.day);
      }

      if (draftItem.toDate != null && draftItem.toDate!.isNotEmpty) {
        final pt = DateTime.tryParse(draftItem.toDate!);
        if (pt != null) toDate = DateTime(pt.year, pt.month, pt.day);
      } else {
        toDate = fromDate;
      }

      if (draftItem.duration != null && draftItem.duration! > 0) {
        durationDays = draftItem.duration!;
      } else {
        durationDays = (toDate.difference(fromDate).inDays + 1).toDouble();
      }
    } else if (item?.workDate != null) {
      final parsed = DateTime.tryParse(item!.workDate);
      if (parsed != null) {
        fromDate = DateTime(parsed.year, parsed.month, parsed.day);
        toDate = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    // Safety check: ensure selectedLeaveType is present in leaveTypes
    if (!leaveTypes.contains(selectedLeaveType)) {
      final matched = leaveTypes.firstWhere(
        (t) => t.toLowerCase().contains(selectedLeaveType.toLowerCase()) || selectedLeaveType.toLowerCase().contains(t.toLowerCase()),
        orElse: () => '',
      );
      if (matched.isNotEmpty) {
        selectedLeaveType = matched;
      } else {
        leaveTypes.insert(0, selectedLeaveType);
      }
    }

    final reasonController = TextEditingController(text: initialReason);
    final durationController = TextEditingController(text: durationDays.toStringAsFixed(1));
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
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final fDate = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
                            final tDate = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
                            final draftReason = reasonController.text.trim().isEmpty ? '(Bản nháp)' : reasonController.text.trim();

                            String kind = 'leave';
                            final lowerType = selectedLeaveType.toLowerCase();
                            if (lowerType.contains('làm thêm') || lowerType.contains('ot')) {
                              kind = 'ot';
                            } else if (lowerType.contains('công tác')) {
                              kind = 'business_trip';
                            } else if (lowerType.contains('đổi ca')) {
                              kind = 'shift_change';
                            } else if (lowerType.contains('giải trình') || lowerType.contains('bổ sung công')) {
                              kind = 'correction';
                            } else if (lowerType.contains('tạm ứng')) {
                              kind = 'advance';
                            } else if (lowerType.contains('hồ sơ')) {
                              kind = 'profile_correction';
                            }

                            String? targetLeaveTypeId;
                            if (kind == 'leave' && _leaveTypes.isNotEmpty) {
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

                            final payload = <String, dynamic>{
                              if (targetLeaveTypeId != null) 'leaveTypeId': targetLeaveTypeId,
                              'fromDate': fDate,
                              'toDate': tDate,
                              'requestDate': fDate,
                              'workDate': fDate,
                              'reason': draftReason,
                              'duration': durationDays,
                              'isNegativeLeave': allowNegativeBalance,
                              if (item?.id != null) 'attendanceId': item!.id,
                            };

                            // Save to backend
                            final savedDraft = await _service.saveDraft(
                              kind: kind,
                              draftId: draftItem?.id,
                              employeeId: _context?.employeeId,
                              payload: payload,
                              expectedUpdatedAt: draftItem?.createdAt,
                            );

                            final draftObj = savedDraft ?? AttendanceCorrection(
                              id: draftItem?.id ?? 'DFT-${DateTime.now().millisecondsSinceEpoch}',
                              employeeId: _context?.employeeId ?? 'emp-01',
                              attendanceId: item?.id,
                              requestDate: fDate,
                              fromDate: fDate,
                              toDate: tDate,
                              newCheckInAt: '${fDate}T08:00:00+07:00',
                              newCheckOutAt: '${tDate}T17:30:00+07:00',
                              reason: '[$selectedLeaveType] $draftReason',
                              duration: durationDays,
                              leaveTypeName: selectedLeaveType,
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
                            _saveLocalDrafts();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã lưu bản nháp lên hệ thống thành công.'),
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
                                        draftId: draftItem?.id,
                                        expectedUpdatedAt: draftItem?.createdAt,
                                        requestDate: fDate,
                                        fromDate: fDate,
                                        toDate: tDate,
                                        newCheckInAt: fDate,
                                        newCheckOutAt: tDate,
                                        reason: '[$selectedLeaveType] ${reasonController.text.trim()}',
                                        duration: durationDays,
                                        isNegativeLeave: allowNegativeBalance,
                                      );

                                      // Close modal ONLY on success
                                      Navigator.pop(ctx);

                                      if (draftItem != null && !draftItem.id.startsWith('DFT-')) {
                                        _service.deleteDraft(draftItem.id, expectedUpdatedAt: draftItem.createdAt);
                                      }

                                      setState(() {
                                        if (draftItem != null) {
                                          _drafts.removeWhere((d) => d.id == draftItem.id);
                                        }
                                      });
                                      _saveLocalDrafts();
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

