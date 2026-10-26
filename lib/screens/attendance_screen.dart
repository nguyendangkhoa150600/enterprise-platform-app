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
import './attendance/components/attendance_day_modals.dart';
import './attendance/components/attendance_correction_dialog.dart';
import './attendance/components/attendance_history_views.dart';
import '../services/hrm_attendance_service.dart';
import '../utils/error_handler.dart';
import '../core/i18n/app_i18n.dart';

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
  String _selectedMonth = '10/2026';
  final List<String> _availableMonths = ['10/2026', '09/2026', '08/2026'];
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
                Text('attendance.snack.checkin_success'.tr(args: {'time': _formatTime(record.firstCheckInAt)})),
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
        final userMsg = ApiErrorHandler.parse(e, defaultMessage: 'attendance.snack.checkin_failed'.tr());
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
                Text('attendance.snack.checkout_success'.tr(args: {'time': _formatTime(record.lastCheckOutAt), 'hours': (record.workedMinutes / 60).toStringAsFixed(1)})),
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
        final userMsg = ApiErrorHandler.parse(e, defaultMessage: 'attendance.snack.checkout_failed'.tr());
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'attendance.app_bar.title'.tr(),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              'attendance.app_bar.subtitle'.tr(),
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
                    tooltip: 'attendance.app_bar.notifications'.tr(),
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
            tooltip: 'attendance.app_bar.my_requests'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'common.refresh'.tr(),
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
          tabs: [
            Tab(text: 'attendance.tabs.today'.tr()),
            Tab(text: 'attendance.tabs.history'.tr()),
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

    final weekdays = [
      'attendance.weekday.mon'.tr(),
      'attendance.weekday.tue'.tr(),
      'attendance.weekday.wed'.tr(),
      'attendance.weekday.thu'.tr(),
      'attendance.weekday.fri'.tr(),
      'attendance.weekday.sat'.tr(),
      'attendance.weekday.sun'.tr(),
    ];
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
                      child: Row(
                        children: [
                          const Icon(Icons.phone_android, size: 12, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 4),
                          Text(
                            'attendance.today.mobile_direct'.tr(),
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
                        'attendance.today.shift_line'.tr(args: {
                          'name': shift?.name ?? 'attendance.today.default_shift'.tr(),
                          'start': shift?.startTime.substring(0, 5) ?? '08:00',
                          'end': shift?.endTime.substring(0, 5) ?? '17:30',
                          'break': shift?.breakMinutes ?? 90,
                        }),
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
                          Text(
                            'attendance.today.location_status'.tr(),
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
                              Text(
                                'attendance.today.location_valid'.tr(),
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
                      child: Text('attendance.today.distance'.tr(args: {'meters': 15}), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
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
          Text(
            'attendance.today.monthly_summary'.tr(args: {'month': '09/2026'}),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildKpiCard(label: 'attendance.kpi.total_days'.tr(), value: '22', unit: 'attendance.kpi.unit_days'.tr(), color: const Color(0xFF2563EB))),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard(label: 'attendance.kpi.on_time'.tr(), value: '20', unit: 'attendance.kpi.unit_days'.tr(), color: const Color(0xFF059669))),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard(label: 'attendance.kpi.late'.tr(), value: '1', unit: 'attendance.kpi.unit_days'.tr(), color: const Color(0xFFD97706))),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard(label: 'attendance.kpi.explanation'.tr(), value: '1', unit: 'attendance.kpi.unit_requests'.tr(), color: const Color(0xFF7C3AED))),
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
                    Text(
                      'attendance.punch.shift_status'.tr(),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 12, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text(
                        'attendance.punch.in_shift'.tr(),
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
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'attendance.punch.checkin_time'.tr(),
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded, color: Colors.white, size: 28),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'attendance.punch.checkout_button'.tr(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Text(
                                  'attendance.punch.checkout_hint'.tr(),
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
                  Text(
                    'attendance.punch.shift_status'.tr(),
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
                  hasPreviousPunches ? 'attendance.punch.ready_new_shift'.tr() : 'attendance.punch.not_checked_in'.tr(),
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
                      'attendance.punch.previous_round'.tr(args: {'in': _formatTime(_todayRecord?.firstCheckInAt), 'out': _formatTime(_todayRecord?.lastCheckOutAt), 'hours': workedHours}),
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
                                hasPreviousPunches ? 'attendance.punch.checkin_next_button'.tr() : 'attendance.punch.checkin_button'.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                'attendance.punch.checkin_hint'.tr(),
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
                label: Text('attendance.punch.explain_previous'.tr(), style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
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
  // TAB 2: ATTENDANCE HISTORY (Sá»” CHáº¤M CÃ”NG & MA TRáº¬N)
  // ==========================================
  Widget _buildHistoryTab() {
    return AttendanceHistoryView(
      history: _history,
      timesheetBoard: _timesheetBoard,
      isLoadingTimesheet: _isLoadingTimesheet,
      selectedMonth: _selectedMonth,
      availableMonths: _availableMonths,
      onMonthChanged: (m) {
        setState(() => _selectedMonth = m);
        _loadTimesheetBoard(_parseSelectedMonthKey(m));
      },
      onRefreshTimesheet: () => _loadTimesheetBoard(),
      onDaySelected: _showDayDetailModal,
      onExplainItem: (item) => _showCorrectionDialog(item),
    );
  }
  // Modal Bottom Sheet on Tapping Matrix Day Cell
  void _showDayDetailModal(int day, String dateStr, AttendanceRecord? record, TimesheetCell? boardCell, String weekdayStr) {
    showAttendanceDayDetailModal(
      context,
      day: day,
      dateStr: dateStr,
      record: record,
      boardCell: boardCell,
      weekdayStr: weekdayStr,
      history: _history,
      timesheetBoard: _timesheetBoard,
      onOpenCorrectionDialog: (rec) => _showCorrectionDialog(rec),
    );
  }
  // ==========================================
  // WEB-MATCHED CREATE REQUEST MODAL
  // ==========================================
  void _showCorrectionDialog(AttendanceRecord? item, {String? initialType, AttendanceCorrection? draftItem}) {
    showAttendanceCorrectionDialog(
      context,
      item: item,
      initialType: initialType,
      draftItem: draftItem,
      leaveTypesList: _leaveTypes,
      attendanceContext: _context,
      service: _service,
      drafts: _drafts,
      onSubmitted: (newCorr) {
        setState(() {
          if (_corrections.isNotEmpty) {
            if (!_corrections.any((c) => c.id == newCorr.id)) {
              _corrections.insert(0, newCorr);
            }
          } else {
            _corrections = [newCorr];
          }
        });
      },
      onSaveDrafts: _saveLocalDrafts,
    );
  }
}
