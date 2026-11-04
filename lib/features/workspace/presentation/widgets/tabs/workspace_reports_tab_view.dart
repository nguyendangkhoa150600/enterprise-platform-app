import 'package:flutter/material.dart';
import '../../../../../models/workspace_models.dart';
import '../../../../../services/workspace_service.dart';
import '../../../domain/models/workspace_report_models.dart';
import '../reports/workspace_report_charts_section.dart';
import '../reports/workspace_report_filter_bar.dart';
import '../reports/workspace_report_filter_dropdowns.dart';
import '../reports/workspace_report_groups_section.dart';
import '../reports/workspace_report_items_sheet.dart';
import '../reports/workspace_report_kpi_section.dart';
import '../reports/workspace_report_performance_section.dart';
import '../reports/workspace_report_projects_progress_section.dart';
import '../reports/workspace_report_workload_overdue_section.dart';

/// Tab Báo cáo Workspace đồng bộ 1:1 với Web React `reports-view.tsx`
/// Phân rã theo chuẩn Senior Flutter Developer Architecture: Orchestrator < 300 lines
class WorkspaceReportsTabView extends StatefulWidget {
  final List<ProjectItem> projects;
  final WorkspaceService? service;
  final VoidCallback? onRefresh;

  const WorkspaceReportsTabView({
    super.key,
    required this.projects,
    this.service,
    this.onRefresh,
  });

  @override
  State<WorkspaceReportsTabView> createState() => _WorkspaceReportsTabViewState();
}

class _WorkspaceReportsTabViewState extends State<WorkspaceReportsTabView> {
  late final WorkspaceService _service;

  ReportPeriodPreset _preset = ReportPeriodPreset.week;
  late String _fromDate;
  late String _toDate;

  String? _projectId;
  String? _group;
  String? _tagId;
  String? _userId;

  List<String> _groups = [];
  List<TagItem> _tags = [];
  List<Map<String, String>> _users = [];
  final Map<String, String> _userNames = {};

  bool _isLoading = false;
  String? _error;
  ReportBundle? _bundle;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? WorkspaceService();
    final range = WorkspaceReportDateHelper.getPresetRange(_preset);
    _fromDate = range.from;
    _toDate = range.to;

    _loadMetadata();
    _loadReport();
  }

  Future<void> _loadMetadata() async {
    try {
      final grpList = await _service.getProjectGroups();
      final tagList = await _service.getWorkspaceTags();
      final dir = await _service.getDirectory();

      if (mounted) {
        setState(() {
          _groups = grpList;
          _tags = tagList;
          if (dir != null) {
            _users = dir.people.map((p) => {
              'id': p.userId,
              'name': p.displayName,
              'position': p.positionName ?? '',
            }).toList();
            for (final p in dir.people) {
              _userNames[p.userId] = p.displayName;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[WorkspaceReportsTabView] _loadMetadata error: $e');
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Chuẩn hoá tham số ngày
      final fromIso = _fromDate.isNotEmpty ? '${_fromDate}T00:00:00.000Z' : null;
      final toIso = _toDate.isNotEmpty ? '${_toDate}T23:59:59.000Z' : null;

      final res = await _service.getWorkspaceReports(
        from: fromIso,
        to: toIso,
        projectIds: _projectId != null ? [_projectId!] : null,
        groups: _group != null ? [_group!] : null,
        tagIds: _tagId != null ? [_tagId!] : null,
        userId: _userId,
      );

      if (mounted) {
        setState(() {
          _bundle = res;
          _isLoading = false;
          if (res == null) {
            _error = 'Không thể tải báo cáo. Vui lòng thử lại sau.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Lỗi kết nối khi tải báo cáo: $e';
        });
      }
    }
  }

  void _onPresetChanged(ReportPeriodPreset preset) {
    setState(() {
      _preset = preset;
      if (preset != ReportPeriodPreset.custom) {
        final range = WorkspaceReportDateHelper.getPresetRange(preset);
        _fromDate = range.from;
        _toDate = range.to;
      }
    });
    _loadReport();
  }

  void _onCustomDateChanged(String from, String to) {
    setState(() {
      _fromDate = from;
      _toDate = to;
    });
    _loadReport();
  }

  void _drillDown(String title, String kind, {Map<String, String>? extra}) {
    final fromIso = _fromDate.isNotEmpty ? '${_fromDate}T00:00:00.000Z' : null;
    final toIso = _toDate.isNotEmpty ? '${_toDate}T23:59:59.000Z' : null;

    final targetProjectIds = extra?['projectIds'] != null
        ? [extra!['projectIds']!]
        : (_projectId != null ? [_projectId!] : null);

    final targetGroups = extra?['groups'] != null
        ? [extra!['groups']!]
        : (_group != null ? [_group!] : null);

    final targetTagIds = extra?['tagIds'] != null
        ? [extra!['tagIds']!]
        : (_tagId != null ? [_tagId!] : null);

    final targetUserId = _userId;
    final targetAssignee = extra?['assigneeUserId'];
    final targetStatus = extra?['status'];
    final targetPriority = extra?['priority'];
    final isStatusScope = extra?['statusScope'] == 'true';

    WorkspaceReportItemsSheet.show(
      context,
      title: title,
      loader: () => _service.getWorkspaceReportItems(
        kind: kind,
        from: fromIso,
        to: toIso,
        projectIds: targetProjectIds,
        groups: targetGroups,
        tagIds: targetTagIds,
        userId: targetUserId,
        assigneeUserId: targetAssignee,
        status: targetStatus,
        priority: targetPriority,
      ),
      statusBreakdown: isStatusScope ? _bundle?.statusBreakdown : null,
      initialStatus: targetStatus,
      statusLoader: isStatusScope
          ? (status) => _service.getWorkspaceReportItems(
                kind: kind,
                from: fromIso,
                to: toIso,
                projectIds: targetProjectIds,
                groups: targetGroups,
                tagIds: targetTagIds,
                userId: targetUserId,
                assigneeUserId: targetAssignee,
                status: status,
                priority: targetPriority,
              )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadReport,
      color: const Color(0xFF2563EB),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // 1. Thanh chọn kỳ báo cáo
          WorkspaceReportFilterBar(
            selectedPreset: _preset,
            fromDate: _fromDate,
            toDate: _toDate,
            isLoading: _isLoading,
            onPresetChanged: _onPresetChanged,
            onCustomDateChanged: _onCustomDateChanged,
            onRefresh: _loadReport,
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 2. Bộ lọc (Dự án, Nhóm, Nhãn, Người)
          WorkspaceReportFilterDropdowns(
            projects: widget.projects,
            groups: _groups,
            tags: _tags,
            users: _users,
            selectedProjectId: _projectId,
            selectedGroup: _group,
            selectedTagId: _tagId,
            selectedUserId: _userId,
            onProjectChanged: (val) {
              setState(() => _projectId = val);
              _loadReport();
            },
            onGroupChanged: (val) {
              setState(() => _group = val);
              _loadReport();
            },
            onTagChanged: (val) {
              setState(() => _tagId = val);
              _loadReport();
            },
            onUserChanged: (val) {
              setState(() => _userId = val);
              _loadReport();
            },
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 3. Nội dung báo cáo
          if (_isLoading && _bundle == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            )
          else if (_error != null && _bundle == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _loadReport, child: const Text('Thử lại')),
                  ],
                ),
              ),
            )
          else if (_bundle != null) ...[
            // KPI Summary & Cards
            WorkspaceReportKpiSection(
              bundle: _bundle!,
              onDrillDown: _drillDown,
            ),
            const SizedBox(height: 8),

            // Xu hướng & Công việc theo trạng thái / ưu tiên
            WorkspaceReportChartsSection(
              bundle: _bundle!,
              onDrillDown: _drillDown,
            ),
            const SizedBox(height: 8),

            // Hiệu suất theo người
            WorkspaceReportPerformanceSection(
              performance: _bundle!.performance,
              userNames: _userNames,
              onDrillDown: _drillDown,
            ),
            const SizedBox(height: 8),

            // Theo nhóm dự án & nhãn & tài chính
            WorkspaceReportGroupsSection(
              bundle: _bundle!,
              onDrillDown: _drillDown,
            ),
            const SizedBox(height: 8),

            // Tiến độ dự án
            WorkspaceReportProjectsProgressSection(
              projects: _bundle!.projectProgress,
              onDrillDown: _drillDown,
            ),
            const SizedBox(height: 8),

            // Tải công việc & Công việc quá hạn
            WorkspaceReportWorkloadOverdueSection(
              workload: _bundle!.workload,
              overdue: _bundle!.overdue,
              userNames: _userNames,
              onDrillDown: _drillDown,
            ),
          ],
        ],
      ),
    );
  }
}
