import 'package:flutter/material.dart';
import '../../../domain/models/workspace_report_models.dart';

/// BottomSheet hiển thị danh sách công việc chi tiết khi bấm vào con số trên Báo cáo
/// Hỗ trợ Tab con theo trạng thái (Đang làm, Đã huỷ, Vướng mắc, Hoàn thành, Chưa làm)
/// Đồng bộ 1:1 với Web React `report-items-dialog.tsx`
class WorkspaceReportItemsSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<ReportItemList?> Function() loader;
  final List<ReportCount>? statusBreakdown;
  final String? initialStatus;
  final Future<ReportItemList?> Function(String? status)? statusLoader;

  const WorkspaceReportItemsSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.loader,
    this.statusBreakdown,
    this.initialStatus,
    this.statusLoader,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Future<ReportItemList?> Function() loader,
    List<ReportCount>? statusBreakdown,
    String? initialStatus,
    Future<ReportItemList?> Function(String? status)? statusLoader,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WorkspaceReportItemsSheet(
        title: title,
        subtitle: subtitle,
        loader: loader,
        statusBreakdown: statusBreakdown,
        initialStatus: initialStatus,
        statusLoader: statusLoader,
      ),
    );
  }

  @override
  State<WorkspaceReportItemsSheet> createState() => _WorkspaceReportItemsSheetState();
}

class _WorkspaceReportItemsSheetState extends State<WorkspaceReportItemsSheet> {
  bool _loading = true;
  String? _error;
  ReportItemList? _data;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = widget.statusLoader != null
          ? await widget.statusLoader!(_selectedStatus)
          : await widget.loader();
      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải danh sách công việc: $e';
          _loading = false;
        });
      }
    }
  }

  void _onStatusTabSelected(String? status) {
    if (_selectedStatus == status) return;
    setState(() {
      _selectedStatus = status;
    });
    _fetch();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'todo':
        return const Color(0xFF64748B);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'blocked':
        return const Color(0xFFEF4444);
      case 'review':
        return const Color(0xFFF59E0B);
      case 'done':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'todo':
        return 'Chưa làm';
      case 'in_progress':
        return 'Đang làm';
      case 'blocked':
        return 'Vướng mắc';
      case 'review':
        return 'Chờ duyệt';
      case 'done':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã huỷ';
      default:
        return status;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFEA580C);
      case 'normal':
        return const Color(0xFF2563EB);
      case 'low':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return 'Khẩn cấp';
      case 'high':
        return 'Cao';
      case 'normal':
        return 'Bình thường';
      case 'low':
        return 'Thấp';
      default:
        return priority;
    }
  }

  Widget _buildStatusTabs() {
    final breakdown = widget.statusBreakdown;
    if (breakdown == null || breakdown.isEmpty) return const SizedBox.shrink();

    final totalCount = breakdown.fold<int>(0, (sum, item) => sum + item.count);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Tab "Tất cả"
            _buildTabChip(
              label: 'Tất cả',
              count: totalCount,
              isSelected: _selectedStatus == null,
              onTap: () => _onStatusTabSelected(null),
            ),
            const SizedBox(width: 8),
            // Từng trạng thái con
            ...breakdown.map((s) {
              final isSelected = _selectedStatus == s.key;
              final color = _getStatusColor(s.key);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildTabChip(
                  label: _getStatusLabel(s.key),
                  count: s.count,
                  color: color,
                  isSelected: isSelected,
                  onTap: () => _onStatusTabSelected(s.key),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required int count,
    Color? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color != null ? color.withValues(alpha: 0.15) : const Color(0xFF0F172A))
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? const Color(0xFF0F172A))
                : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (color ?? Colors.white)
                    : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? (color != null ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.2))
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (color ?? Colors.white)
                      : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedStatus != null
                            ? 'Công việc · ${_getStatusLabel(_selectedStatus!)}'
                            : widget.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Tab con trạng thái
          _buildStatusTabs(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Content body
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDC2626))),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetch, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    final items = _data?.items ?? [];
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 10),
              Text('Không có công việc nào thoả điều kiện', style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: items.length + (_data?.truncated == true ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'Danh sách quá dài đã được thu gọn hiển thị 100 công việc đầu tiên.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
              textAlign: TextAlign.center,
            ),
          );
        }

        final item = items[index];
        final statusColor = _getStatusColor(item.status);
        final priorityColor = _getPriorityColor(item.priority);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.code.isNotEmpty ? item.code : '#',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (item.projectCode.isNotEmpty)
                    Text(
                      item.projectCode,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                    ),
                  const Spacer(),
                  // Priority
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getPriorityLabel(item.priority),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: priorityColor),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusLabel(item.status),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (item.plannedEnd != null && item.plannedEnd!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'Hạn: ${item.plannedEnd}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
