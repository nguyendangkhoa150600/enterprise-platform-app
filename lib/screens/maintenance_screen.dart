import 'package:flutter/material.dart';
import '../models/maintenance_models.dart';
import '../services/module_business_service.dart';
import '../theme/colors.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> with SingleTickerProviderStateMixin {
  final ModuleBusinessService _service = ModuleBusinessService();
  late TabController _tabController;
  List<MaintenanceSchedule> _schedules = [];
  List<MaintenanceIncident> _incidents = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.getMaintenanceSchedules(),
      _service.getMaintenanceIncidents(),
    ]);
    if (mounted) {
      setState(() {
        _schedules = results[0] as List<MaintenanceSchedule>;
        _incidents = results[1] as List<MaintenanceIncident>;
        _isLoading = false;
      });
    }
  }

  List<MaintenanceSchedule> get _filteredSchedules {
    if (_searchQuery.isEmpty) return _schedules;
    return _schedules.where((s) =>
        s.assetName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        s.assetCode.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  int get _dueCount => _schedules.where((s) => s.status == 'DUE' || s.status == 'OVERDUE').length;
  int get _openIncidentsCount => _incidents.where((i) => i.status == 'OPEN' || i.status == 'IN_PROGRESS').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bảo trì & Thiết bị (Maintenance)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Quản lý ma trận bảo dưỡng định kỳ, kế hoạch ngăn ngừa & sự cố',
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.emerald,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.slate400,
          tabs: const [
            Tab(icon: Icon(Icons.event_note_outlined, size: 18), text: 'Lịch bảo dưỡng định kỳ'),
            Tab(icon: Icon(Icons.warning_amber_outlined, size: 18), text: 'Sự cố thiết bị'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSchedulesTab(),
                  _buildIncidentsTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildSchedulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;
              final cardWidth = isCompact ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 24) / 3;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard('KẾ HOẠCH ĐÃ LẬP', '${_schedules.length}', Icons.calendar_month_outlined, AppColors.slate800, cardWidth),
                  _buildMetricCard('ĐẾN HẠN BẢO TRÌ', '$_dueCount', Icons.alarm_outlined, Colors.red.shade600, cardWidth),
                  _buildMetricCard('SỰ CỐ ĐANG MỞ', '$_openIncidentsCount', Icons.build_outlined, AppColors.amber, cardWidth),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm thiết bị theo mã hoặc tên...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.slate400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Schedules List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredSchedules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildScheduleCard(_filteredSchedules[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(MaintenanceSchedule item) {
    Color statusColor;
    String statusText;
    if (item.status == 'OVERDUE') {
      statusColor = Colors.red.shade700;
      statusText = 'Quá hạn';
    } else if (item.status == 'DUE') {
      statusColor = AppColors.amber;
      statusText = 'Đến hạn';
    } else {
      statusColor = AppColors.emerald;
      statusText = 'Đã lên lịch';
    }

    String freqLabel;
    switch (item.frequency) {
      case 'DAILY':
        freqLabel = 'Hàng ngày';
        break;
      case 'WEEKLY':
        freqLabel = 'Hàng tuần';
        break;
      case 'MONTHLY':
        freqLabel = 'Hàng tháng';
        break;
      case 'QUARTERLY':
        freqLabel = 'Hàng quý';
        break;
      default:
        freqLabel = 'Hàng năm';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.assetCode,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.assetName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.repeat, size: 14, color: AppColors.slate400),
              const SizedBox(width: 4),
              Text('Chu kỳ: $freqLabel', style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
              const SizedBox(width: 16),
              const Icon(Icons.event, size: 14, color: AppColors.slate400),
              const SizedBox(width: 4),
              Text('Hạn tới: ${item.nextDueDate}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: item.status == 'OVERDUE' ? Colors.red.shade700 : AppColors.slate700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Báo cáo & Ghi nhận sự cố thiết bị',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Theo dõi tình trạng xử lý các cảnh báo và bất thường kỹ thuật',
            style: TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _incidents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final inc = _incidents[index];
              Color severityColor;
              String severityText;
              if (inc.severity == 'CRITICAL') {
                severityColor = Colors.red.shade700;
                severityText = 'Nghiêm trọng';
              } else if (inc.severity == 'MEDIUM') {
                severityColor = Colors.orange.shade700;
                severityText = 'Trung bình';
              } else {
                severityColor = Colors.blue.shade700;
                severityText = 'Thấp';
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          inc.assetCode,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            severityText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: severityColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      inc.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thiết bị: ${inc.assetName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 13, color: AppColors.slate400),
                        const SizedBox(width: 4),
                        Text(inc.reportedBy ?? 'Kỹ thuật viên', style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time, size: 13, color: AppColors.slate400),
                        const SizedBox(width: 4),
                        Text(inc.reportedAt, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
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

  Widget _buildMetricCard(String title, String val, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate400),
                ),
                const SizedBox(height: 4),
                Text(
                  val,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
