import 'package:flutter/material.dart';
import '../models/procedure_models.dart';
import '../services/module_business_service.dart';
import '../theme/colors.dart';

class ProcedureScreen extends StatefulWidget {
  const ProcedureScreen({super.key});

  @override
  State<ProcedureScreen> createState() => _ProcedureScreenState();
}

class _ProcedureScreenState extends State<ProcedureScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();
  List<ProcedureInstance> _instances = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final list = await _service.getProcedureInstances();
    if (mounted) {
      setState(() {
        _instances = list;
        _isLoading = false;
      });
    }
  }

  List<ProcedureInstance> get _filteredList {
    return _instances.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'IN_REVIEW') return item.stage == 'IN_REVIEW';
      if (_selectedFilter == 'IN_PROGRESS') return item.stage == 'IN_PROGRESS';
      if (_selectedFilter == 'COMPLETED') return item.stage == 'COMPLETED';
      if (_selectedFilter == 'SLA_RISK') return item.slaStatus == 'AT_RISK' || item.slaStatus == 'BREACHED';
      return true;
    }).toList();
  }

  int get _inProgressCount => _instances.where((i) => i.stage == 'IN_PROGRESS').length;
  int get _inReviewCount => _instances.where((i) => i.stage == 'IN_REVIEW').length;
  int get _slaBreachedCount => _instances.where((i) => i.slaStatus == 'BREACHED' || i.slaStatus == 'AT_RISK').length;

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
              'Quy trình làm việc (Procedure Engine)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Workspace điều hành quy trình, luồng duyệt & theo dõi SLA',
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metrics Row
                    _buildMetricsRow(),
                    const SizedBox(height: 24),

                    // Controls (Search & Filter Tabs)
                    _buildControls(),
                    const SizedBox(height: 16),

                    // Instance Cards List
                    if (_filteredList.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildProcedureCard(_filteredList[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        final cardWidth = isCompact ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard('TỔNG QUY TRÌNH', '${_instances.length}', Icons.account_tree_outlined, AppColors.slate800, cardWidth),
            _buildMetricCard('ĐANG XỬ LÝ', '$_inProgressCount', Icons.pending_actions_outlined, Colors.blue.shade700, cardWidth),
            _buildMetricCard('CHỜ PHÊ DUYỆT', '$_inReviewCount', Icons.rate_review_outlined, AppColors.amber, cardWidth),
            _buildMetricCard('CẢNH BÁO SLA', '$_slaBreachedCount', Icons.alarm_on_outlined, Colors.red.shade600, cardWidth),
          ],
        );
      },
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        children: [
          // Search input
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm quy trình theo mã, tên hoặc phân loại...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.slate400),
              filled: true,
              fillColor: AppColors.slate50,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tất cả', 'ALL'),
                _buildFilterChip('Đang xử lý', 'IN_PROGRESS'),
                _buildFilterChip('Chờ phê duyệt', 'IN_REVIEW'),
                _buildFilterChip('Cảnh báo SLA', 'SLA_RISK'),
                _buildFilterChip('Đã hoàn thành', 'COMPLETED'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.slate700,
        ),
        selected: isSelected,
        selectedColor: AppColors.slate900,
        backgroundColor: AppColors.slate100,
        showCheckmark: false,
        onSelected: (_) => setState(() => _selectedFilter = value),
      ),
    );
  }

  Widget _buildProcedureCard(ProcedureInstance item) {
    Color stageColor;
    String stageText;
    switch (item.stage) {
      case 'IN_REVIEW':
        stageColor = AppColors.amber;
        stageText = 'Chờ duyệt';
        break;
      case 'COMPLETED':
        stageColor = AppColors.emerald;
        stageText = 'Hoàn thành';
        break;
      default:
        stageColor = Colors.blue.shade700;
        stageText = 'Đang thực hiện';
    }

    Color slaColor = AppColors.emerald;
    String slaText = 'Đúng hạn SLA';
    if (item.slaStatus == 'AT_RISK') {
      slaColor = AppColors.amber;
      slaText = 'Sắp đến hạn SLA';
    } else if (item.slaStatus == 'BREACHED') {
      slaColor = Colors.redAccent;
      slaText = 'Quá hạn SLA';
    }

    return InkWell(
      onTap: () => _showDetailDialog(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code + Stage + SLA
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.code,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stageColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    stageText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: stageColor,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: slaColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: slaColor),
                      const SizedBox(width: 4),
                      Text(
                        slaText,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: slaColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 8),

            // Category & Subtasks Progress
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 14, color: AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  item.category,
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.checklist_outlined, size: 14, color: AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  '${item.completedSubtasksCount}/${item.subtasksCount} nhiệm vụ',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.slate100),
            const SizedBox(height: 10),

            // Assignee & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        (item.assigneeName ?? 'N')[0],
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.assigneeName ?? 'Chưa phân công',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Text(
                      'Chi tiết',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 11, color: Colors.blue),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.slate300),
          SizedBox(height: 12),
          Text(
            'Không tìm thấy quy trình phù hợp',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate700),
          ),
          SizedBox(height: 4),
          Text(
            'Thử thay đổi từ khóa hoặc bộ lọc tìm kiếm.',
            style: TextStyle(fontSize: 12, color: AppColors.slate400),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(ProcedureInstance item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Mã quy trình:', item.code),
              _buildDetailRow('Phân loại:', item.category),
              _buildDetailRow('Giai đoạn:', item.stage),
              _buildDetailRow('Độ ưu tiên:', item.priority),
              _buildDetailRow('Người phụ trách:', item.assigneeName ?? 'Chưa gán'),
              _buildDetailRow('Tiến độ công việc:', '${item.completedSubtasksCount}/${item.subtasksCount} nhiệm vụ con'),
              const SizedBox(height: 16),
              const Text(
                'Lưu ý: Bạn có thể cập nhật trạng thái hoặc gửi yêu cầu vật tư cho quy trình này.',
                style: TextStyle(fontSize: 12, color: AppColors.slate500, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã cập nhật quy trình ${item.code}')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.slate900,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xử lý bước tiếp theo'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.slate400)),
          ),
          Expanded(
            child: Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate800)),
          ),
        ],
      ),
    );
  }
}
