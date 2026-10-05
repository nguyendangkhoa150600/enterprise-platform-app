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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quy trình làm việc (Procedure Engine)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. VIỆC CẦN LÀM
                    _buildActionRequiredCard(),
                    const SizedBox(height: 16),

                    // 2. HỒ SƠ THEO TRẠNG THÁI
                    _buildStatusDonutCard(),
                    const SizedBox(height: 16),

                    // 3. HỒ SƠ THEO QUY TRÌNH
                    _buildByDefinitionCard(),
                    const SizedBox(height: 16),

                    // 4. SƠ ĐỒ LUỒNG CÁC BƯỚC QUY TRÌNH
                    _buildFlowDiagramCard(),
                    const SizedBox(height: 24),

                    // Controls (Search & Filter Tabs)
                    _buildControls(),
                    const SizedBox(height: 16),

                    // Section header for Instances
                    const Text(
                      'DANH SÁCH HỒ SƠ QUY TRÌNH',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.slate500,
                      ),
                    ),
                    const SizedBox(height: 12),

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

  // ==========================================
  // DASHBOARD CARDS MATCHING REACT WEB
  // ==========================================

  // 1. VIỆC CẦN LÀM
  Widget _buildActionRequiredCard() {
    final pendingTasks = _instances.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VIỆC CẦN LÀM',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 12),
          if (pendingTasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text('Không có việc cần xử lý', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
            )
          else
            Column(
              children: pendingTasks.map((task) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: const Text(
                          'Vai S',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // 2. HỒ SƠ THEO TRẠNG THÁI
  Widget _buildStatusDonutCard() {
    final total = _instances.length;
    final inProgress = _instances.where((i) => i.stage == 'IN_PROGRESS' || i.stage == 'IN_REVIEW' || i.stage == 'DRAFT').length;
    final percent = total > 0 ? ((inProgress / total) * 100).round() : 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HỒ SƠ THEO TRẠNG THÁI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Custom Donut Ring
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 10,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        backgroundColor: Color(0xFFE2E8F0),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const Text(
                          'hồ sơ',
                          style: TextStyle(fontSize: 9, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Đang xử lý',
                            style: TextStyle(fontSize: 13, color: AppColors.slate700),
                          ),
                        ),
                        Text(
                          '$total',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$percent%',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. HỒ SƠ THEO QUY TRÌNH
  Widget _buildByDefinitionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HỒ SƠ THEO QUY TRÌNH',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 16),
          _buildDefinitionBar('Mua sắm vật...', 2, 4, const Color(0xFF2563EB)),
          const SizedBox(height: 12),
          _buildDefinitionBar('Thí nghiệm ...', 1, 4, const Color(0xFF059669)),
          const SizedBox(height: 12),
          _buildDefinitionBar('Bảo trì định ...', 1, 4, const Color(0xFFD97706)),
        ],
      ),
    );
  }

  Widget _buildDefinitionBar(String title, int count, int max, Color color) {
    final double ratio = max > 0 ? (count / max).clamp(0.05, 1.0) : 0.1;
    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.slate700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$count',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  // 4. SƠ ĐỒ LUỒNG CÁC BƯỚC QUY TRÌNH
  Widget _buildFlowDiagramCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SƠ ĐỒ LUỒNG CÁC BƯỚC QUY TRÌNH',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 14),

          // Dropdown selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.alt_route, size: 16, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Báo cáo quản trị quý (3 bước · Đã công bố)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.slate500),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Flow step cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFlowStepCard(
                  stepNum: '1',
                  stepName: 'Tổng hợp số liệu quý',
                  roleTag: 'S',
                  roleBg: const Color(0xFFECFDF5),
                  roleColor: const Color(0xFF059669),
                  roleBorder: const Color(0xFFA7F3D0),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right, size: 18, color: AppColors.slate400),
                ),
                _buildFlowStepCard(
                  stepNum: '2',
                  stepName: 'Ban Tổng Giám đố...',
                  roleTag: 'R',
                  roleBg: const Color(0xFFFEF3C7),
                  roleColor: const Color(0xFFD97706),
                  roleBorder: const Color(0xFFFDE68A),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right, size: 18, color: AppColors.slate400),
                ),
                _buildFlowStepCard(
                  stepNum: '3',
                  stepName: 'Hội đồng Quản trị t...',
                  roleTag: 'A',
                  roleBg: const Color(0xFFFEE2E2),
                  roleColor: const Color(0xFFDC2626),
                  roleBorder: const Color(0xFFFECACA),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStepCard({
    required String stepNum,
    required String stepName,
    required String roleTag,
    required Color roleBg,
    required Color roleColor,
    required Color roleBorder,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              stepNum,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stepName,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: roleBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: roleBorder),
            ),
            child: Text(
              roleTag,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
            ),
          ),
        ],
      ),
    );
  }

  // Search & Filter Controls
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
        stageColor = const Color(0xFF2563EB);
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
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                color: Color(0xFF0F172A),
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
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF2563EB)),
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
            child: Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}
