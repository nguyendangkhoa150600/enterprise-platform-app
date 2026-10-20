import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../models/hrm_fleet_models.dart';
import '../services/fleet_service.dart';

class FleetScheduleScreen extends StatefulWidget {
  const FleetScheduleScreen({super.key});

  @override
  State<FleetScheduleScreen> createState() => _FleetScheduleScreenState();
}

class _FleetScheduleScreenState extends State<FleetScheduleScreen> with SingleTickerProviderStateMixin {
  final FleetService _service = FleetService();

  late TabController _tabController;
  bool _isLoading = true;
  List<HrmFleetVehicle> _vehicles = [];
  List<HrmFleetDriver> _drivers = [];
  List<HrmFleetBooking> _bookings = [];

  int _selectedSpanDays = 14; // 7, 14, 30 matching web
  String _statusFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFleetData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFleetData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(Duration(days: _selectedSpanDays));

      final results = await Future.wait([
        _service.getVehicles(),
        _service.getDrivers(),
        _service.getBookings(from: from, to: to),
      ]);

      if (mounted) {
        setState(() {
          _vehicles = results[0] as List<HrmFleetVehicle>;
          _drivers = results[1] as List<HrmFleetDriver>;
          _bookings = results[2] as List<HrmFleetBooking>;
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
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Lịch đặt (${_bookings.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_car_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Đội xe (${_vehicles.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_pin_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Tài xế (${_drivers.length})'),
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

  // TAB 1: LỊCH TRÌNH ĐẶT XE
  Widget _buildScheduleTab() {
    final filteredBookings = _bookings.where((b) {
      if (_statusFilter != 'ALL' && b.status != _statusFilter) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = b.vehicleName.toLowerCase().contains(q) ||
            b.vehiclePlateNo.toLowerCase().contains(q) ||
            (b.driverName?.toLowerCase().contains(q) ?? false) ||
            (b.destination?.toLowerCase().contains(q) ?? false) ||
            (b.purpose?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      return true;
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

          // Filter Controls (Span Selector & Search)
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
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
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
                      prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('ALL', 'Tất cả (${_bookings.length})'),
                _buildStatusChip('BOOKED', 'Đã đặt'),
                _buildStatusChip('IN_PROGRESS', 'Đang chạy'),
                _buildStatusChip('COMPLETED', 'Đã hoàn thành'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Booking List
          if (filteredBookings.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  Icon(Icons.directions_car_filled_outlined, size: 40, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text('Không có lịch xe nào trong khoảng thời gian này', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                ],
              ),
            )
          else
            ...filteredBookings.map((b) => _buildBookingCard(b)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String key, String label) {
    final isSel = _statusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _statusFilter = key),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              color: isSel ? const Color(0xFF2563EB) : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFleetMetricsRow() {
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
                const Text('Tổng xe vận hành', style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$activeVehicles / ${_vehicles.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
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

  Widget _buildBookingCard(HrmFleetBooking b) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    Color statusBg = const Color(0xFFEFF6FF);
    Color statusFg = const Color(0xFF2563EB);
    String statusText = 'ĐÃ ĐẶT';

    if (b.status == 'IN_PROGRESS') {
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFD97706);
      statusText = 'ĐANG CHẠY';
    } else if (b.status == 'COMPLETED') {
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF16A34A);
      statusText = 'HOÀN THÀNH';
    } else if (b.status == 'CANCELLED') {
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFDC2626);
      statusText = 'ĐÃ HỦY';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: () => _showBookingDetailsSheet(b),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Vehicle & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          b.vehiclePlateNo,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        b.vehicleName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusFg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Time Window
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    '${dateFormat.format(b.startAt)} → ${dateFormat.format(b.endAt)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Destination & Driver
              if (b.destination != null && b.destination!.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b.destination!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              // Footer: Driver & Source
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  Text(
                    'Tài xế: ${b.driverName ?? "Chưa phân công"}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const Spacer(),
                  if (b.sourceLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        b.sourceLabel!,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 2: ĐỘI XE
  Widget _buildVehiclesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _vehicles.length,
      itemBuilder: (ctx, i) {
        final v = _vehicles[i];
        final isAvailable = v.status == 'ACTIVE';

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isAvailable ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAvailable ? const Color(0xFFBFDBFE) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    size: 24,
                    color: isAvailable ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(v.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAvailable ? 'SẴN SÀNG' : 'BẢO DƯỠNG',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(v.plateNo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          ),
                          const SizedBox(width: 8),
                          Text('${v.seats} chỗ ngồi', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        ],
                      ),
                      if (v.note != null && v.note!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(v.note!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // TAB 3: DANH SÁCH TÀI XẾ
  Widget _buildDriversTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _drivers.length,
      itemBuilder: (ctx, i) {
        final d = _drivers[i];
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
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: const Icon(Icons.person, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(d.employeeName ?? 'Tài xế', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAvailable ? 'HOẠT ĐỘNG' : 'TẠM NGHỈ',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('Mã NV: ${d.employeeCode ?? "TX"} · Giấy phép lái xe: ${d.licenseNo ?? "—"}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // BOTTOM SHEET: CHI TIẾT LỊCH ĐẶT XE (Web 1:1 DetailRow)
  void _showBookingDetailsSheet(HrmFleetBooking b) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chi tiết chuyến xe · ${b.id}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(b.sourceLabel ?? 'Đơn công tác', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Phương tiện', '${b.vehicleName} (${b.vehiclePlateNo})'),
            _buildDetailRow('Tài xế phụ trách', b.driverName ?? 'Chưa phân công'),
            _buildDetailRow('Khởi hành', dateFormat.format(b.startAt)),
            _buildDetailRow('Dự kiến về', dateFormat.format(b.endAt)),
            _buildDetailRow('Điểm đến', b.destination ?? '—'),
            _buildDetailRow('Mục đích công tác', b.purpose ?? '—'),
            _buildDetailRow('Trạng thái', b.status == 'BOOKED' ? 'Đã xếp lịch xe' : b.status),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Đóng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
