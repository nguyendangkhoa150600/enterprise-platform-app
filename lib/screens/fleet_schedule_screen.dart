import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../models/hrm_fleet_models.dart';
import '../models/hrm_models.dart';
import '../services/fleet_service.dart';
import '../services/hrm_service.dart';
import 'fleet/components/fleet_booking_details_sheet.dart';
import 'fleet/components/fleet_cards.dart';
import 'fleet/components/fleet_vehicle_modals.dart';
import 'fleet/components/fleet_driver_modals.dart';

class FleetScheduleScreen extends StatefulWidget {
  const FleetScheduleScreen({super.key});

  @override
  State<FleetScheduleScreen> createState() => _FleetScheduleScreenState();
}

class _FleetScheduleScreenState extends State<FleetScheduleScreen> with SingleTickerProviderStateMixin {
  final FleetService _service = FleetService();
  final HrmService _hrmService = HrmService();

  late TabController _tabController;
  bool _isLoading = true;
  List<HrmFleetVehicle> _vehicles = [];
  List<HrmFleetDriver> _drivers = [];
  List<HrmFleetBooking> _bookings = [];
  List<HrmEmployeeItem> _employees = [];

  int _selectedSpanDays = 14; // 7, 14, 30 matching web
  DateTime _timelineStartDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String _searchQuery = '';
  String _vehicleSearchQuery = '';
  String _driverSearchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _timelineStartDate = DateTime(now.year, now.month, now.day);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadFleetData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shiftTimeline(int days) {
    setState(() {
      _timelineStartDate = _timelineStartDate.add(Duration(days: days));
    });
    _loadFleetData();
  }

  void _resetTimelineToday() {
    final now = DateTime.now();
    setState(() {
      _timelineStartDate = DateTime(now.year, now.month, now.day);
    });
    _loadFleetData();
  }

  String _getVietnameseWeekday(DateTime dt) {
    switch (dt.weekday) {
      case DateTime.monday:
        return 'Thứ 2';
      case DateTime.tuesday:
        return 'Thứ 3';
      case DateTime.wednesday:
        return 'Thứ 4';
      case DateTime.thursday:
        return 'Thứ 5';
      case DateTime.friday:
        return 'Thứ 6';
      case DateTime.saturday:
        return 'Thứ 7';
      case DateTime.sunday:
      default:
        return 'CN';
    }
  }

  bool _isBookingOnDay(HrmFleetBooking b, DateTime day) {
    final startDay = DateTime(b.startAt.year, b.startAt.month, b.startAt.day);
    final endDay = DateTime(b.endAt.year, b.endAt.month, b.endAt.day);
    final targetDay = DateTime(day.year, day.month, day.day);
    return (targetDay.isAtSameMomentAs(startDay) || targetDay.isAfter(startDay)) &&
           (targetDay.isAtSameMomentAs(endDay) || targetDay.isBefore(endDay));
  }

  bool _isBookingForVehicle(HrmFleetBooking b, HrmFleetVehicle v) {
    if (b.vehicleId.isNotEmpty && b.vehicleId == v.id) return true;
    if (b.vehiclePlateNo.isNotEmpty &&
        b.vehiclePlateNo.replaceAll('.', '').replaceAll('-', '').toLowerCase() ==
            v.plateNo.replaceAll('.', '').replaceAll('-', '').toLowerCase()) {
      return true;
    }
    return false;
  }

  Future<void> _loadFleetData() async {
    setState(() => _isLoading = true);
    try {
      final from = _timelineStartDate;
      final to = _timelineStartDate.add(Duration(days: _selectedSpanDays));

      final results = await Future.wait([
        _service.getVehicles(),
        _service.getDrivers(),
        _service.getBookings(from: from, to: to),
        _hrmService.getEmployees().catchError((_) => <HrmEmployeeItem>[]),
      ]);

      if (mounted) {
        setState(() {
          _vehicles = results[0] as List<HrmFleetVehicle>;
          _drivers = results[1] as List<HrmFleetDriver>;
          _bookings = results[2] as List<HrmFleetBooking>;
          _employees = results[3] as List<HrmEmployeeItem>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[FleetScheduleScreen] _loadFleetData error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Lịch xe',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          if (_tabController.index == 1)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ElevatedButton.icon(
                onPressed: _showCreateVehicleModal,
                icon: const Icon(Icons.add, size: 15, color: Color(0xFF0F172A)),
                label: const Text('Thêm xe', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            )
          else if (_tabController.index == 2)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ElevatedButton.icon(
                onPressed: _showCreateDriverModal,
                icon: const Icon(Icons.add, size: 15, color: Color(0xFF0F172A)),
                label: const Text('Thêm tài xế', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.slate700, size: 21),
            tooltip: 'Làm mới',
            onPressed: _loadFleetData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Lịch xe'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Danh mục xe'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_pin_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Tài xế'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildScheduleTab(),
                _buildVehiclesTab(),
                _buildDriversTab(),
              ],
            ),
    );
  }

  // TAB 1: LỊCH TRÌNH ĐẶT XE (1:1 Web Timeline Matrix)
  Widget _buildScheduleTab() {
    final endDate = _timelineStartDate.add(Duration(days: _selectedSpanDays - 1));
    final dateRangeStr = '${DateFormat('dd/MM/yyyy').format(_timelineStartDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}';

    final filteredVehicles = _vehicles.where((v) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchVehicle = v.name.toLowerCase().contains(q) || v.plateNo.toLowerCase().contains(q);
      final hasMatchingBooking = _bookings.any((b) =>
          _isBookingForVehicle(b, v) &&
          ((b.driverName?.toLowerCase().contains(q) ?? false) ||
           (b.destination?.toLowerCase().contains(q) ?? false) ||
           (b.purpose?.toLowerCase().contains(q) ?? false)));
      return matchVehicle || hasMatchingBooking;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadFleetData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Breadcrumbs
          Row(
            children: const [
              Text('SVN DTS / Quản trị Nhân sự / Quản lý', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Lịch xe công ty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          const Text(
            'Theo dõi lịch đặt, lộ trình công tác và điều phối phương tiện nội bộ doanh nghiệp.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // Overview Metric Chips
          _buildFleetMetricsRow(),
          const SizedBox(height: 14),

          // Date Navigation & Span Controls (1:1 Web)
          Row(
            children: [
              // 7, 14, 30 days selector
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [7, 14, 30].map((days) {
                    final isSel = _selectedSpanDays == days;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedSpanDays = days);
                        _loadFleetData();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF2563EB) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$days ngày',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Spacer(),
              // < Hôm nay > Nav
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _shiftTimeline(-_selectedSpanDays),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Icon(Icons.chevron_left, size: 18, color: Color(0xFF475569)),
                      ),
                    ),
                    Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                    InkWell(
                      onTap: _resetTimelineToday,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: const [
                            Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text('Hôm nay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                    InkWell(
                      onTap: () => _shiftTimeline(_selectedSpanDays),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Icon(Icons.chevron_right, size: 18, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Date Range Label & Status Legends (1:1 Web)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    const Icon(Icons.date_range, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      dateRangeStr,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Chờ đơn gốc duyệt (đang giữ chỗ)',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Đã xác nhận',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Box
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Tìm xe, tài xế, điểm đến...',
                hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // If really NO vehicles in system
          if (_vehicles.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.directions_car_filled_outlined, size: 44, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có xe nào trong danh mục.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Xe công ty đang được đặt cho đơn công tác, công việc, lịch họp và sự cố. Chọn xe và tài xế ngay trên đơn hoặc công việc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateVehicleModal,
                    icon: const Icon(Icons.add, size: 15, color: Color(0xFF0F172A)),
                    label: const Text('Thêm xe mới', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAB308),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // TIMELINE GRID (Bảng ma trận lịch xe 1:1 Web)
            _buildTimelineMatrix(filteredVehicles),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // BẢNG MA TRẬN LỊCH XE (1:1 Web Timeline Grid)
  Widget _buildTimelineMatrix(List<HrmFleetVehicle> vehicles) {
    if (vehicles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: const Text('Không tìm thấy xe phù hợp với bộ lọc.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysList = List.generate(_selectedSpanDays, (i) => _timelineStartDate.add(Duration(days: i)));

    const double vehicleColWidth = 110.0;
    const double dayColWidth = 66.0;

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER ROW
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
              ),
              child: Row(
                children: [
                  // Vehicle Header Column
                  Container(
                    width: vehicleColWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Xe',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Container(width: 1, height: 38, color: const Color(0xFFE2E8F0)),
                  // Day Columns
                  ...daysList.map((day) {
                    final isToday = day.isAtSameMomentAs(today);
                    return Container(
                      width: dayColWidth,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isToday ? const Color(0xFFEFF6FF) : Colors.transparent,
                        border: Border(
                          right: const BorderSide(color: Color(0xFFE2E8F0)),
                          bottom: isToday ? const BorderSide(color: Color(0xFF2563EB), width: 2) : BorderSide.none,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getVietnameseWeekday(day),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                              color: isToday ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${day.day}/${day.month}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isToday ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // VEHICLE ROWS
            ...vehicles.map((v) {
              return Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    // Vehicle Info Cell
                    Container(
                      width: vehicleColWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            v.name,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${v.plateNo} • ${v.seats} chỗ',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 50, color: const Color(0xFFE2E8F0)),
                    // Day Schedule Cells
                    ...daysList.map((day) {
                      final dayBookings = _bookings.where((b) => _isBookingForVehicle(b, v) && _isBookingOnDay(b, day)).toList();
                      final isToday = day.isAtSameMomentAs(today);

                      Widget cellContent;
                      if (dayBookings.isEmpty) {
                        cellContent = Container(
                          width: dayColWidth,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday ? const Color(0xFFF8FAFC) : Colors.white,
                            border: const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: const Text('—', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                        );
                      } else {
                        final b = dayBookings.first;
                        final isConfirmed = b.status == 'IN_PROGRESS' || b.status == 'COMPLETED';
                        final cellBg = isConfirmed ? const Color(0xFFF97316) : const Color(0xFFFEF3C7);
                        final cellBorder = isConfirmed ? const Color(0xFFEA580C) : const Color(0xFFF59E0B);
                        final textColor = isConfirmed ? Colors.white : const Color(0xFF92400E);

                        cellContent = InkWell(
                          onTap: () => _showBookingDetailsSheet(b),
                          child: Container(
                            width: dayColWidth,
                            height: 50,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isToday ? const Color(0xFFF8FAFC) : Colors.white,
                              border: const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: double.infinity,
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              decoration: BoxDecoration(
                                color: cellBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: cellBorder, width: 0.8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                b.purpose?.trim().isNotEmpty == true
                                    ? b.purpose!
                                    : (b.destination?.trim().isNotEmpty == true ? b.destination! : (isConfirmed ? 'Đã duyệt' : 'Giữ chỗ')),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        );
                      }
                      return cellContent;
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }


  Widget _buildFleetMetricsRow() {
    final totalVehicles = _vehicles.length;
    final activeVehicles = _vehicles.where((v) => v.status == 'ACTIVE').length;
    final inUseCount = _bookings.where((b) => b.status == 'IN_PROGRESS' || b.status == 'BOOKED').length;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tổng xe vận hành', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$activeVehicles / $totalVehicles', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
                const Text('Xe sẵn sàng phục vụ', style: TextStyle(fontSize: 10, color: Color(0xFF60A5FA))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDCFCE7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lịch trình sắp tới', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$inUseCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF14532D))),
                const Text('Chuyến công tác & điều động', style: TextStyle(fontSize: 10, color: Color(0xFF4ADE80))),
              ],
            ),
          ),
        ),
      ],
    );
  }


  // TAB 2: DANH MỤC XE (MATCHING WEB)
  Widget _buildVehiclesTab() {
    final filteredVehicles = _vehicles.where((v) {
      if (_vehicleSearchQuery.isEmpty) return true;
      final q = _vehicleSearchQuery.toLowerCase();
      return v.name.toLowerCase().contains(q) ||
          v.plateNo.toLowerCase().contains(q) ||
          (v.note?.toLowerCase().contains(q) ?? false);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadFleetData,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Danh mục xe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    const Text(
                      'Xe công ty có thể được chọn khi làm đơn công tác, công việc, lịch họp và phiếu sự cố.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showCreateVehicleModal,
                icon: const Icon(Icons.add, size: 15, color: Color(0xFF0F172A)),
                label: const Text('Thêm xe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search box (Matching Web)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _vehicleSearchQuery = v.trim().toLowerCase()),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Tìm biển số, tên xe...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_vehicles.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.directions_car_outlined, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có xe nào trong danh mục.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Thêm xe mới để bắt đầu quản lý và phân công lịch trình.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateVehicleModal,
                    icon: const Icon(Icons.add, size: 15, color: Color(0xFF0F172A)),
                    label: const Text('Thêm xe mới', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAB308),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            )
          else if (filteredVehicles.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: const Text('Không tìm thấy xe phù hợp', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            )
          else
            ...filteredVehicles.map((v) => _buildVehicleCard(v)),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(HrmFleetVehicle v) {
    return FleetVehicleCard(
      vehicle: v,
      onEdit: () => _showEditVehicleModal(v),
      onToggleStatus: () => _confirmToggleVehicleStatus(v),
    );
  }

  // TAB 3: DANH SÁCH TÀI XẾ (MATCHING WEB)
  Widget _buildDriversTab() {
    final filteredDrivers = _drivers.where((d) {
      if (_driverSearchQuery.isEmpty) return true;
      final q = _driverSearchQuery.toLowerCase();
      return (d.employeeName?.toLowerCase().contains(q) ?? false) ||
          (d.employeeCode?.toLowerCase().contains(q) ?? false) ||
          (d.licenseNo?.toLowerCase().contains(q) ?? false);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadFleetData,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tài xế', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    const Text(
                      'Tài xế được chọn từ hồ sơ nhân sự HRM để sẵn sàng phân công chuyến đi.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showCreateDriverModal,
                icon: const Icon(Icons.add, size: 15, color: Color(0xFF0F172A)),
                label: const Text('Thêm tài xế', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search box (Matching Web)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _driverSearchQuery = v.trim().toLowerCase()),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên, mã nhân viên, số bằng lái...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_drivers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có tài xế nào trong danh mục.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Thêm tài xế từ hồ sơ nhân sự HRM để sẵn sàng phân công chuyến đi.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateDriverModal,
                    icon: const Icon(Icons.add, size: 15, color: Color(0xFF0F172A)),
                    label: const Text('Thêm tài xế mới', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAB308),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            )
          else if (filteredDrivers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: const Text('Không tìm thấy tài xế phù hợp', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            )
          else
            ...filteredDrivers.map((d) => _buildDriverCard(d)),
        ],
      ),
    );
  }

  Widget _buildDriverCard(HrmFleetDriver d) {
    final isAvailable = d.status == 'ACTIVE';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    d.employeeName?.isNotEmpty == true ? d.employeeName![0].toUpperCase() : 'T',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          d.employeeName ?? 'Tài xế',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isAvailable ? 'Đang sử dụng' : 'Ngừng sử dụng',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Mã NV: ${d.employeeCode ?? "—"} · Giấy phép lái xe: ${d.licenseNo ?? "—"}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showEditDriverModal(d),
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF334155)),
                  label: const Text('Sửa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _confirmToggleDriverStatus(d),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isAvailable ? 'Ngừng sử dụng' : 'Sử dụng lại',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isAvailable ? const Color(0xFF475569) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- MODAL: THEM XE MOI ---
  void _showCreateVehicleModal() {
    showCreateVehicleModal(
      context: context,
      service: _service,
      onVehicleAdded: _loadFleetData,
      onVehicleAddedOffline: (v) {
        setState(() => _vehicles.insert(0, v));
      },
    );
  }

  // --- MODAL: THEM TAI XE MOI ---
  void _showCreateDriverModal() {
    showCreateDriverModal(
      context: context,
      service: _service,
      employees: _employees,
      onDriverAdded: _loadFleetData,
      onDriverAddedOffline: (d) {
        setState(() => _drivers.insert(0, d));
      },
    );
  }

  // BOTTOM SHEET: CHI TIET LICH DAT XE
  void _showBookingDetailsSheet(HrmFleetBooking b) {
    showFleetBookingDetailsSheet(context: context, booking: b);
  }

  // --- MODAL: CHINH SUA XE ---
  void _showEditVehicleModal(HrmFleetVehicle vehicle) {
    showEditVehicleModal(
      context: context,
      service: _service,
      vehicle: vehicle,
      onVehicleUpdated: (updated) {
        setState(() {
          final idx = _vehicles.indexWhere((x) => x.id == vehicle.id);
          if (idx != -1) _vehicles[idx] = updated;
        });
      },
      onRefreshData: _loadFleetData,
    );
  }

  // --- CONFIRM: NGUNG SU DUNG / SU DUNG LAI XE ---
  void _confirmToggleVehicleStatus(HrmFleetVehicle vehicle) {
    confirmToggleVehicleStatus(
      context: context,
      service: _service,
      vehicle: vehicle,
      onStatusUpdated: (targetStatus) {
        setState(() {
          final idx = _vehicles.indexWhere((x) => x.id == vehicle.id);
          if (idx != -1) {
            _vehicles[idx] = HrmFleetVehicle(
              id: vehicle.id,
              plateNo: vehicle.plateNo,
              name: vehicle.name,
              seats: vehicle.seats,
              status: targetStatus,
              note: vehicle.note,
            );
          }
        });
      },
      onRefreshData: _loadFleetData,
    );
  }

  // --- MODAL: CHINH SUA TAI XE ---
  void _showEditDriverModal(HrmFleetDriver driver) {
    showEditDriverModal(
      context: context,
      service: _service,
      driver: driver,
      onDriverUpdated: (updated) {
        setState(() {
          final idx = _drivers.indexWhere((x) => x.id == driver.id);
          if (idx != -1) _drivers[idx] = updated;
        });
      },
      onRefreshData: _loadFleetData,
    );
  }

  // --- CONFIRM: NGUNG SU DUNG / SU DUNG LAI TAI XE ---
  void _confirmToggleDriverStatus(HrmFleetDriver driver) {
    confirmToggleDriverStatus(
      context: context,
      service: _service,
      driver: driver,
      onStatusUpdated: (targetStatus) {
        setState(() {
          final idx = _drivers.indexWhere((x) => x.id == driver.id);
          if (idx != -1) {
            _drivers[idx] = HrmFleetDriver(
              id: driver.id,
              employeeId: driver.employeeId,
              employeeName: driver.employeeName,
              employeeCode: driver.employeeCode,
              licenseNo: driver.licenseNo,
              status: targetStatus,
            );
          }
        });
      },
      onRefreshData: _loadFleetData,
    );
  }
}
