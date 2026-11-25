import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../features/workspace/data/datasources/workspace_api_base.dart';
import '../../../../features/workspace/data/datasources/workspace_requests_api.dart';
import '../../../../models/workspace_models.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/workspace_service.dart';
import '../../../../features/workspace/presentation/utils/project_access_extension.dart';
import 'requests/request_card.dart';
import 'requests/request_detail_sheet.dart';
import 'requests/request_filter.dart';
import 'requests/request_filter_sheet.dart';
import 'requests/workday_sheets.dart';

/// Tab "Đơn từ" của dự án như web `tab-requests.tsx`.
///
/// Liệt kê đơn module khác gửi kèm dự án (mã DTxxx do Workspace cấp). Chỉ đọc: duyệt hay huỷ đơn làm ở module gốc;
/// riêng đơn đã duyệt được gửi yêu cầu huỷ hiệu lực ngay tại đây (server quyết quyền).
class WorkspaceProjectRequestsTab extends StatefulWidget {
  final ProjectItem project;
  final WorkspaceService service;
  final ProjectAccess access;

  const WorkspaceProjectRequestsTab({
    super.key,
    required this.project,
    required this.service,
    required this.access,
  });

  @override
  State<WorkspaceProjectRequestsTab> createState() => _WorkspaceProjectRequestsTabState();
}

class _WorkspaceProjectRequestsTabState extends State<WorkspaceProjectRequestsTab> {
  final WorkspaceRequestsApi _api = WorkspaceRequestsApi();

  /// Danh sách hiện tại; ngăn chi tiết nghe để cập nhật trạng thái sau khi nạp lại.
  final ValueNotifier<List<ProjectRequestItem>?> _items = ValueNotifier(null);
  String? _error;
  WorkdayRuleSet? _rules;
  RequestFilter _filter = RequestFilter.none;
  RequestSort _sort = RequestSort.initial;
  Timer? _poll;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _loadRules();
    _load(initial: true);
  }

  @override
  void didUpdateWidget(covariant WorkspaceProjectRequestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _filter = RequestFilter.none;
      _load(initial: true);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _items.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    final result = await _api.workdayRules();
    if (!mounted || !result.ok) return;
    setState(() => _rules = result.data);
  }

  /// Lần đầu (đổi dự án) thì xoá danh sách; nạp lại sau thao tác thì giữ danh sách cũ.
  Future<void> _load({bool initial = false}) async {
    final token = ++_loadToken;
    _poll?.cancel();
    setState(() {
      if (initial) _items.value = null;
      _error = null;
    });
    final result = await _api.listProjectRequests(widget.project.id);
    if (!mounted || token != _loadToken) return;
    if (!result.ok) {
      setState(() => _error = result.error ?? 'workspace.requests.err_load'.tr());
      return;
    }
    final items = result.data ?? const <ProjectRequestItem>[];
    setState(() => _items.value = items);
    // Yêu cầu huỷ hiệu lực đi qua sự kiện (vài giây): nạp lại tới khi module nguồn báo kết quả.
    final waiting = items.any((i) => i.reversalRequest != null && i.reversalRequest!.error == null && i.status == 'APPROVED');
    if (waiting) _poll = Timer(const Duration(seconds: 3), () => _load());
  }

  Future<WorkspaceApiResult<void>> _reverse(ProjectRequestItem item, String reason, bool createAdjustment) async {
    final result = await _api.reverseProjectRequest(item.id, reason: reason, createAdjustment: createAdjustment);
    if (result.ok && mounted) _load();
    return result;
  }

  void _openFilter() {
    showRequestFilterSheet(
      context,
      items: _items.value ?? const [],
      filter: _filter,
      sort: _sort,
      onChanged: (filter, sort) {
        if (!mounted) return;
        setState(() {
          _filter = filter;
          _sort = sort;
        });
      },
    );
  }

  void _openDetail(ProjectRequestItem item) {
    showRequestDetailSheet(context, requestId: item.id, items: _items, onReverse: _reverse);
  }

  void _openPriority() {
    showDialog<void>(
      context: context,
      builder: (_) => WorkdayPriorityDialog(
        rules: _rules,
        api: _api,
        onSaved: (saved) {
          if (mounted) setState(() => _rules = saved);
        },
      ),
    );
  }

  void _openReport() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      builder: (_) => WorkdayReportSheet(
        loadMembers: () => widget.service.getProjectMembers(widget.project.id),
        requests: _items.value ?? const [],
        rules: _rules ?? WorkdayRuleSet.defaults,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items.value;
    final visible = items == null
        ? const <ProjectRequestItem>[]
        : visibleRequests(items, _filter, _sort, AuthProvider.instance?.userId);
    final facets = _filter.facets;
    final active = facets > 0 || !_sort.isDefault;
    final muted = Theme.of(context).hintColor;

    String? message;
    if (_error != null) {
      message = _error;
    } else if (items == null) {
      message = 'workspace.requests.loading'.tr();
    } else if (items.isEmpty) {
      message = 'workspace.requests.empty'.tr();
    } else if (visible.isEmpty) {
      message = 'workspace.requests.no_match'.tr();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: _openFilter,
                icon: Icon(Icons.filter_list, size: 16, color: active ? Theme.of(context).colorScheme.primary : null),
                label: Text(facets > 0 ? '${'common.filter'.tr()} ($facets)' : 'common.filter'.tr()),
              ),
              if (items != null)
                Expanded(
                  child: Text(
                    facets > 0
                        ? 'workspace.requests.count_filtered'.tr(args: {'shown': visible.length, 'total': items.length})
                        : 'workspace.requests.count'.tr(args: {'count': items.length}),
                    style: TextStyle(fontSize: 12, color: muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              IconButton(
                tooltip: 'workspace.requests.report_title'.tr(),
                icon: const Icon(Icons.summarize_outlined, size: 20),
                onPressed: _openReport,
              ),
              IconButton(
                tooltip: 'workspace.requests.priority_button'.tr(),
                icon: const Icon(Icons.format_list_numbered, size: 20),
                onPressed: _openPriority,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(),
            child: message != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: muted)),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => RequestCard(item: visible[i], onTap: () => _openDetail(visible[i])),
                  ),
          ),
        ),
      ],
    );
  }
}
