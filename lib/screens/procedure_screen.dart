import 'package:flutter/material.dart';
import '../models/procedure_models.dart';
import '../services/module_business_service.dart';
import '../theme/colors.dart';
import 'procedure/components/procedure_overview_widgets.dart';
import 'procedure/components/procedure_flow_diagram_card.dart';
import 'procedure/components/procedure_instances_view.dart';
import 'procedure/components/procedure_modals.dart';
import '../core/i18n/app_i18n.dart';

class ProcedureScreen extends StatefulWidget {
  final int initialTab;
  const ProcedureScreen({super.key, this.initialTab = 0});

  @override
  State<ProcedureScreen> createState() => _ProcedureScreenState();
}

class _ProcedureScreenState extends State<ProcedureScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();
  List<ProcedureInstance> _instances = [];
  List<ProcedureDefinition> _definitions = [];
  String? _selectedDefinitionId;
  bool _isLoading = true;
  String _selectedStatusFilter = 'ALL';
  String _selectedSlaFilter = 'ALL';
  String _selectedSourceFilter = 'ALL';
  String _searchQuery = '';
  late int _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _loadData();
  }

  // Tải dữ liệu thật 100% từ API, không sử dụng dữ liệu mock
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final ws = await _service.getProcedureWorkspace();
      if (mounted) {
        setState(() {
          _instances = ws.instances;
          _definitions = ws.definitions;
          final validDefs = _definitions.where((d) => d.steps.isNotEmpty).toList();
          if (_selectedDefinitionId == null ||
              !validDefs.any((d) => d.id == _selectedDefinitionId)) {
            _selectedDefinitionId = validDefs.isNotEmpty ? validDefs.first.id : null;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ProcedureInstance> get _filteredList {
    return _instances.where((item) {
      // 1. Tìm kiếm theo mã hồ sơ, tiêu đề, tên quy trình, người tạo
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = item.title.toLowerCase().contains(q) ||
            item.code.toLowerCase().contains(q) ||
            item.definitionName.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q) ||
            item.submitterDisplayName.toLowerCase().contains(q);
        if (!matches) return false;
      }

      // 2. Lọc theo Tab trạng thái (Đồng bộ 100% với Web)
      if (_selectedStatusFilter == 'RUNNING') {
        if (!item.isRunning) return false;
      } else if (_selectedStatusFilter == 'SLA_RISK') {
        if (!item.isSlaWarning &&
            !item.isSlaBreached &&
            item.slaStatus != 'AT_RISK' &&
            item.slaStatus != 'BREACHED') {
          return false;
        }
      } else if (_selectedStatusFilter == 'COMPLETED') {
        if (!item.isCompleted) return false;
      } else if (_selectedStatusFilter == 'REJECTED') {
        if (item.status != 'rejected') return false;
      } else if (_selectedStatusFilter == 'CANCELLED') {
        if (item.status != 'cancelled') return false;
      } else if (_selectedStatusFilter == 'REVERSED') {
        if (item.status != 'reversed') return false;
      }
      // 'ALL' hiển thị tất cả

      // 3. Lọc theo Dropdown SLA
      if (_selectedSlaFilter == 'ON_TIME') {
        if (item.isSlaWarning ||
            item.isSlaBreached ||
            item.slaStatus == 'AT_RISK' ||
            item.slaStatus == 'BREACHED') {
          return false;
        }
      } else if (_selectedSlaFilter == 'AT_RISK') {
        if (!item.isSlaWarning && item.slaStatus != 'AT_RISK') {
          return false;
        }
      } else if (_selectedSlaFilter == 'BREACHED') {
        if (!item.isSlaBreached && item.slaStatus != 'BREACHED') {
          return false;
        }
      }

      // 4. Lọc theo Dropdown Nguồn
      if (_selectedSourceFilter == 'MANUAL') {
        if (item.source?.toUpperCase() == 'SYSTEM' ||
            item.source?.toLowerCase() == 'automated') {
          return false;
        }
      } else if (_selectedSourceFilter == 'SYSTEM') {
        if (item.source?.toUpperCase() != 'SYSTEM' &&
            item.source?.toLowerCase() != 'automated') {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = _activeTab == 0 ? 'procedure.screen.title_overview'.tr() : 'procedure.screen.title_instances'.tr();
    final subtitle = _activeTab == 0
        ? 'procedure.screen.subtitle_overview'.tr()
        : 'procedure.screen.subtitle_instances'.tr();

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        actions: [
          if (_activeTab == 1)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'procedure.screen.open_new'.tr(),
              onPressed: () => showCreateProcedureInstanceDialog(
                context: context,
                definitions: _definitions,
                service: _service,
                onCreated: _loadData,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'common.refresh'.tr(),
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
                child: _activeTab == 0 ? _buildOverviewContent() : _buildInstancesContent(),
              ),
            ),
    );
  }

  // ==========================================
  // TAB 0: TỔNG QUAN (OVERVIEW)
  // ==========================================
  Widget _buildOverviewContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Thống kê 4 thẻ trên cùng
        ProcedureTopMetrics(
          instances: _instances,
          definitions: _definitions,
        ),
        const SizedBox(height: 16),

        // 2. Việc cần làm
        ProcedureActionRequiredCard(
          instances: _instances,
          onItemTap: (item) => showProcedureDetailSheet(
            context: context,
            initialItem: item,
            service: _service,
            onDataChanged: _loadData,
          ),
        ),
        const SizedBox(height: 16),

        // 3. Hồ sơ theo trạng thái + SLA + Đang chờ vai nào
        ProcedureStatusDonutCard(instances: _instances),
        const SizedBox(height: 16),

        // 4. Hồ sơ theo quy trình
        ProcedureByDefinitionCard(instances: _instances),
        const SizedBox(height: 16),

        // 5. Sơ đồ luồng các bước quy trình + Chú thích RACI
        Builder(
          builder: (context) {
            final flowDefs = _definitions.where((d) => d.steps.isNotEmpty).toList();
            return ProcedureFlowDiagramCard(
              definitions: flowDefs,
              selectedDefinitionId: _selectedDefinitionId,
              onSelectProcedure: () => showProcedureSelectorBottomSheet(
                context: context,
                definitions: flowDefs,
                selectedDefinitionId: _selectedDefinitionId,
                onSelected: (defId) => setState(() => _selectedDefinitionId = defId),
              ),
            );
          },
        ),
        const SizedBox(height: 18),

        // Nút chuyển sang Hồ sơ xử lý
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProcedureScreen(initialTab: 1)),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  'procedure.screen.view_all_instances'.tr(args: {'count': _instances.length}),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF2563EB)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================
  // TAB 1: DANH SÁCH HỒ SƠ XỬ LÝ (INSTANCES)
  // ==========================================
  Widget _buildInstancesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls (Tìm kiếm + Bộ lọc Tabs & Dropdowns đồng bộ Web)
        ProcedureSearchFilterControls(
          searchQuery: _searchQuery,
          onSearchChanged: (val) => setState(() => _searchQuery = val),
          selectedStatusFilter: _selectedStatusFilter,
          onStatusFilterChanged: (filter) => setState(() => _selectedStatusFilter = filter),
          selectedSlaFilter: _selectedSlaFilter,
          onSlaFilterChanged: (filter) => setState(() => _selectedSlaFilter = filter),
          selectedSourceFilter: _selectedSourceFilter,
          onSourceFilterChanged: (filter) => setState(() => _selectedSourceFilter = filter),
          instances: _instances,
        ),
        const SizedBox(height: 16),

        // Danh sách thẻ hồ sơ
        if (_filteredList.isEmpty)
          const ProcedureEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _filteredList[index];
              return ProcedureInstanceCard(
                item: item,
                onTap: () => showProcedureDetailSheet(
                  context: context,
                  initialItem: item,
                  service: _service,
                  onDataChanged: _loadData,
                ),
              );
            },
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
