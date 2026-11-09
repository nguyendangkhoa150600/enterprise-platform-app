import 'package:flutter/material.dart';
import '../models/maintenance_models.dart';
import '../services/module_business_service.dart';
import '../theme/colors.dart';
import 'maintenance/components/maintenance_history_tab_view.dart';
import 'maintenance/components/maintenance_matrix_tab_view.dart';
import 'maintenance/components/maintenance_occurrences_tab_view.dart';
import 'maintenance/components/maintenance_overview_tab_view.dart';
import 'maintenance/components/maintenance_schedules_tab_view.dart';

class MaintenanceScreen extends StatefulWidget {
  final int initialTab;
  final String view; // 'dashboard' | 'matrix' | 'schedules' | 'occurrences' | 'history' | 'settings'

  const MaintenanceScreen({
    super.key,
    this.initialTab = 0,
    this.view = 'dashboard',
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();

  Map<String, dynamic>? _workspace;
  Map<String, dynamic>? _matrix;
  List<MaintenanceSchedule> _schedules = [];
  List<MaintenanceIncident> _incidents = [];
  List<Map<String, dynamic>> _occurrences = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  String get _currentView {
    if (widget.view != 'dashboard') return widget.view;
    switch (widget.initialTab) {
      case 1:
        return 'matrix';
      case 2:
        return 'schedules';
      case 3:
        return 'occurrences';
      case 4:
        return 'history';
      case 5:
        return 'settings';
      default:
        return widget.view;
    }
  }

  String get _title {
    switch (_currentView) {
      case 'matrix':
        return 'Ma trận bảo trì';
      case 'schedules':
        return 'Lịch bảo trì';
      case 'occurrences':
        return 'Phiếu phát sinh';
      case 'history':
        return 'Lịch sử bảo trì';
      case 'settings':
        return 'Cài đặt bảo trì';
      default:
        return 'Bảo trì phòng ngừa';
    }
  }

  String get _subtitle {
    switch (_currentView) {
      case 'matrix':
        return 'Ma trận chu kỳ bảo trì theo thiết bị';
      case 'schedules':
        return 'Kế hoạch bảo dưỡng định kỳ thiết bị';
      case 'occurrences':
        return 'Phiếu công tác & sự cố phát sinh';
      case 'history':
        return 'Nhật ký thực hiện bảo trì';
      case 'settings':
        return 'Cấu hình tần suất & tích hợp module';
      default:
        return 'Quản lý lịch bảo trì, ma trận chu kỳ & phiếu công tác';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.getMaintenanceWorkspace(),
      _service.getMaintenanceMatrix(),
      _service.getMaintenanceSchedules(),
      _service.getMaintenanceIncidents(),
      _service.getMaintenanceOccurrences(),
      _service.getMaintenanceHistory(),
    ]);

    if (mounted) {
      setState(() {
        _workspace = results[0] as Map<String, dynamic>?;
        _matrix = results[1] as Map<String, dynamic>?;
        _schedules = results[2] as List<MaintenanceSchedule>;
        _incidents = results[3] as List<MaintenanceIncident>;
        _occurrences = results[4] as List<Map<String, dynamic>>;
        _history = results[5] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> get _metrics {
    if (_workspace != null && _workspace!['metrics'] is Map) {
      return Map<String, dynamic>.from(_workspace!['metrics'] as Map);
    }
    return {
      'activeSchedules': _schedules.where((s) => s.status != 'COMPLETED').length,
      'upcomingOccurrences': _schedules.where((s) => s.status == 'DUE' || s.status == 'OVERDUE').length,
      'generatedOccurrences': _occurrences.length,
      'completedOccurrences': _history.length,
      'openIncidents': _incidents.where((i) => i.status != 'RESOLVED').length,
    };
  }

  void _navigateToView(String targetView) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MaintenanceScreen(view: targetView)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    switch (_currentView) {
      case 'matrix':
        return MaintenanceMatrixTabView(
          matrix: _matrix,
          onRefresh: _loadData,
        );
      case 'schedules':
        return MaintenanceSchedulesTabView(
          schedules: _schedules,
          onRefresh: _loadData,
        );
      case 'occurrences':
        return MaintenanceOccurrencesTabView(
          incidents: _incidents,
          occurrences: _occurrences,
          onRefresh: _loadData,
        );
      case 'history':
        return MaintenanceHistoryTabView(
          history: _history,
          onRefresh: _loadData,
        );
      case 'settings':
        return _buildSettingsView();
      default:
        return MaintenanceOverviewTabView(
          metrics: _metrics,
          schedules: _schedules,
          incidents: _incidents,
          occurrences: _occurrences,
          onNavigate: _navigateToView,
        );
    }
  }

  Widget _buildSettingsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cấu hình Bảo trì phòng ngừa',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Các chu kỳ tần suất chuẩn được cấu hình và đồng bộ tự động từ Web ERP: Ngày, Tuần, Tháng, Quý, Năm.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildSettingRow('Tự động sinh phiếu công tác', 'Kích hoạt'),
              _buildSettingRow('Đồng bộ với Kho & Vật tư', 'Đang kết nối'),
              _buildSettingRow('Đồng bộ với Quy trình', 'Đang kết nối'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
          ),
        ],
      ),
    );
  }
}
