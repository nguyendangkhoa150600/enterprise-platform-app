import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hrm_attendance_models.dart';
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

  bool _isLoading = true;
  bool _isPunching = false;
  bool _isInShift = false;
  String _historyFilter = 'ALL';

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

  Future<void> _loadAllAttendanceData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.getAttendanceContext(),
      _service.precheck(),
      _service.getTodayAttendance(),
      _service.getAttendanceHistory(),
      _service.getCorrections(),
    ]);

    if (mounted) {
      final todayRec = results[2] as AttendanceRecord?;
      setState(() {
        _context = results[0] as AttendanceContext;
        _precheck = results[1] as PrecheckResult;
        _todayRecord = todayRec;
        _history = results[3] as List<AttendanceRecord>;
        _corrections = results[4] as List<AttendanceCorrection>;
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
            Tab(text: 'Đơn giải trình'),
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
                _buildCorrectionsTab(),
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
  // TAB 2: ATTENDANCE HISTORY (SỔ CHẤM CÔNG)
  // ==========================================
  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
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
          const SizedBox(height: 16),

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
      ),
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
  // TAB 3: CORRECTIONS (ĐƠN GIẢI TRÌNH CÔNG)
  // ==========================================
  Widget _buildCorrectionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & New Request Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách đơn giải trình',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCorrectionDialog(null),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tạo đơn'),
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

          if (_corrections.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('Chưa có đơn giải trình nào.', style: TextStyle(color: Color(0xFF94A3B8))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _corrections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final c = _corrections[index];
                return _buildCorrectionCard(c);
              },
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

  // ==========================================
  // CORRECTION DIALOG / MODAL
  // ==========================================
  void _showCorrectionDialog(AttendanceRecord? item) {
    final reasonController = TextEditingController();
    final dateStr = item?.workDate ?? DateTime.now().toIso8601String().substring(0, 10);
    String inTime = '08:00';
    String outTime = '17:30';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Đơn giải trình chấm công',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Ngày giải trình: ${_formatDate(dateStr)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 16),
              const Text('Khung giờ đề xuất công:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text('Vào: $inTime', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text('Ra: $outTime', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Lý do giải trình (*):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Nhập chi tiết lý do quên quẹt thẻ, đi công tác, thiết bị lỗi...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập lý do giải trình.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  await _service.createCorrection(
                    attendanceId: item?.id,
                    requestDate: dateStr,
                    newCheckInAt: '${dateStr}T08:00:00+07:00',
                    newCheckOutAt: '${dateStr}T17:30:00+07:00',
                    reason: reasonController.text.trim(),
                  );
                  final corrs = await _service.getCorrections();
                  setState(() => _corrections = corrs);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã gửi đơn giải trình công lên Quản lý thành công.'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('GỬI ĐƠN GIẢI TRÌNH'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
