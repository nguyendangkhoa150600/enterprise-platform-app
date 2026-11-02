import 'package:flutter/material.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import '../../../../utils/user_resolver.dart';
import '../../../../utils/app_toast.dart';
import 'workspace_standalone_task_dialog.dart';

/// Bottom sheet hiển thị chi tiết công việc ngoài dự án (Standalone Task)
/// Đồng bộ 100% cấu trúc, thông tin và thao tác với phiên bản Web
void showWorkspaceStandaloneTaskDetailSheet(
  BuildContext context, {
  required StandaloneTaskItem task,
  required WorkspaceService service,
  required VoidCallback onRefresh,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _StandaloneTaskDetailContent(
      initialTask: task,
      service: service,
      onRefresh: onRefresh,
    ),
  );
}

class _StandaloneTaskDetailContent extends StatefulWidget {
  final StandaloneTaskItem initialTask;
  final WorkspaceService service;
  final VoidCallback onRefresh;

  const _StandaloneTaskDetailContent({
    required this.initialTask,
    required this.service,
    required this.onRefresh,
  });

  @override
  State<_StandaloneTaskDetailContent> createState() => _StandaloneTaskDetailContentState();
}

class _StandaloneTaskDetailContentState extends State<_StandaloneTaskDetailContent> {
  late StandaloneTaskItem _task;
  bool _isLoadingDetail = true;
  bool _isUpdatingStatus = false;
  Map<String, dynamic>? _detailData;
  List<dynamic> _children = [];
  List<dynamic> _history = [];
  List<String> _allowedStatuses = [];
  bool _canAddChild = false;

  @override
  void initState() {
    super.initState();
    _task = widget.initialTask;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoadingDetail = true);
    try {
      final res = await widget.service.getStandaloneTaskDetail(_task.id);
      if (mounted && res != null) {
        final taskMap = res['task'] is Map ? res['task'] as Map<String, dynamic> : res;
        setState(() {
          _detailData = res;
          _task = StandaloneTaskItem.fromJson(taskMap);
          if (res['children'] is List) {
            _children = res['children'] as List;
          }
          if (res['history'] is List) {
            _history = res['history'] as List;
          }
          if (res['allowedStatuses'] is List) {
            _allowedStatuses = (res['allowedStatuses'] as List).map((e) => e.toString()).toList();
          }
          _canAddChild = res['canAddChild'] == true;
        });
      }
    } catch (e) {
      debugPrint('[StandaloneTaskDetailSheet] _fetchDetail error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    }
  }

  Future<void> _updateStatus(String newStatus, {String? note}) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final ok = await widget.service.changeStandaloneTaskStatus(_task.id, newStatus, note: note);
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
        if (ok) {
          if (newStatus == 'cancelled') {
            Navigator.pop(context);
            widget.onRefresh();
            AppToast.success(context, 'Đã huỷ công việc thành công!');
          } else {
            AppToast.success(context, 'Cập nhật trạng thái thành công!');
            widget.onRefresh();
            _fetchDetail();
          }
        } else {
          AppToast.error(context, 'Không thể cập nhật trạng thái.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
        AppToast.error(context, 'Lỗi: $e');
      }
    }
  }

  Future<void> _showCancelDialog() async {
    final noteCtrl = TextEditingController();
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ công việc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn có chắc chắn muốn huỷ công việc này không? Vui lòng nhập lý do:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Nhập lý do huỷ việc...',
                hintStyle: const TextStyle(fontSize: 12.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận huỷ'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      _updateStatus('cancelled', note: noteCtrl.text.trim());
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá công việc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Bạn có chắc chắn muốn xoá vĩnh viễn công việc "${_task.title}" không?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final success = await widget.service.deleteStandaloneTask(_task.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onRefresh();
          AppToast.success(context, 'Đã xoá công việc thành công!');
        } else {
          AppToast.error(context, 'Không thể xoá công việc.');
        }
      }
    }
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Lịch sử thay đổi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: _history.isEmpty
                    ? const Center(child: Text('Chưa có lịch sử thay đổi nào.', style: TextStyle(color: Color(0xFF94A3B8))))
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: _history.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final h = _history[idx];
                          final note = h['note']?.toString();
                          final createdBy = h['createdBy']?.toString() ?? '';
                          final createdAt = h['createdAt']?.toString() ?? '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              UserResolver.resolveName(createdBy),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              note != null && note.isNotEmpty ? note : 'Cập nhật trạng thái',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            trailing: Text(
                              _formatDateTime(DateTime.tryParse(createdAt)),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header: Code + Title & Role & Action Icons (History, Delete)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _task.code,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _task.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Vai của bạn: ${_task.myRoleLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.history_rounded, size: 21, color: Color(0xFF64748B)),
                  tooltip: 'Lịch sử thay đổi',
                  onPressed: _showHistoryModal,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                if (_task.myRole == 'assigner') ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 21, color: Color(0xFFDC2626)),
                    tooltip: 'Xoá việc',
                    onPressed: _confirmDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Scrollable Body
          Expanded(
            child: _isLoadingDetail && _detailData == null
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    children: [
                      // 1. Status Chip & Action Buttons Row matching Web
                      _buildActionButtonsRow(),
                      const SizedBox(height: 18),

                      // 2. Information Table matching Web
                      _buildInfoTable(),
                      const SizedBox(height: 18),

                      // 3. Description Block
                      if (_task.description != null && _task.description!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mô tả công việc',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _task.description!,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // 4. Section Việc con (Sub-tasks) matching Web
                      _buildSubtasksSection(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool _canTransitionTo(String targetStatus) {
    if (_allowedStatuses.isNotEmpty) {
      return _allowedStatuses.contains(targetStatus);
    }
    switch (targetStatus) {
      case 'todo':
        return _task.status == 'in_progress' || _task.status == 'blocked';
      case 'in_progress':
        return _task.status == 'todo' || _task.status == 'blocked' || _task.status == 'review';
      case 'blocked':
        return _task.status == 'in_progress';
      case 'review':
        return _task.status == 'in_progress';
      case 'done':
        return _task.status == 'in_progress' || _task.status == 'review';
      case 'cancelled':
        return _task.myRole == 'assigner' && _task.status != 'cancelled' && _task.status != 'done';
      default:
        return false;
    }
  }

  // Row các nút trạng thái matching Web
  Widget _buildActionButtonsRow() {
    if (_isUpdatingStatus) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEAB308)),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Chip Trạng thái hiện tại
        _buildCurrentStatusChip(),

        // Nút: Về Chưa làm (Khi ở Vướng mắc hoặc Đang làm)
        if (_canTransitionTo('todo')) ...[
          OutlinedButton(
            onPressed: () => _updateStatus('todo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text(
              'Về Chưa làm',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],

        // Nút: Bắt đầu làm / Tiếp tục làm / Yêu cầu làm lại
        if (_canTransitionTo('in_progress')) ...[
          OutlinedButton(
            onPressed: () => _updateStatus('in_progress'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(
              _task.status == 'blocked'
                  ? 'Tiếp tục làm'
                  : (_task.status == 'review' ? 'Yêu cầu làm lại' : 'Bắt đầu làm'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],

        // Nút: Báo vướng mắc
        if (_canTransitionTo('blocked')) ...[
          OutlinedButton(
            onPressed: () => _updateStatus('blocked'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Báo vướng mắc', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],

        // Nút: Gửi duyệt (Màu vàng thương hiệu #EAB308 đồng bộ 1:1 với Web)
        if (_canTransitionTo('review')) ...[
          ElevatedButton(
            onPressed: () => _updateStatus('review'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEAB308),
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text(
              'Gửi duyệt',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],

        // Nút: Hoàn thành / Duyệt hoàn thành
        if (_canTransitionTo('done')) ...[
          ElevatedButton(
            onPressed: () => _updateStatus('done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(
              _task.status == 'review' ? 'Duyệt hoàn thành' : 'Hoàn thành',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],

        // Nút: Huỷ việc (Dành cho Người giao)
        if (_canTransitionTo('cancelled') || (_task.myRole == 'assigner' && _task.status != 'cancelled' && _task.status != 'done')) ...[
          ElevatedButton(
            onPressed: _showCancelDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: const Color(0xFFDC2626),
              elevation: 0,
              side: const BorderSide(color: Color(0xFFFECACA)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Huỷ việc', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrentStatusChip() {
    Color bg;
    Color color;
    Color border;
    switch (_task.status) {
      case 'in_progress':
        bg = const Color(0xFFEFF6FF);
        color = const Color(0xFF1D4ED8);
        border = const Color(0xFFBFDBFE);
        break;
      case 'done':
        bg = const Color(0xFFECFDF5);
        color = const Color(0xFF047857);
        border = const Color(0xFFA7F3D0);
        break;
      case 'blocked':
        bg = const Color(0xFFFEF2F2);
        color = const Color(0xFFDC2626);
        border = const Color(0xFFFECACA);
        break;
      case 'cancelled':
        bg = const Color(0xFFF1F5F9);
        color = const Color(0xFF64748B);
        border = const Color(0xFFE2E8F0);
        break;
      case 'todo':
      default:
        bg = const Color(0xFFF1F5F9);
        color = const Color(0xFF475569);
        border = const Color(0xFFE2E8F0);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        _task.statusLabel,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  // Bảng thông tin chi tiết đồng bộ 1:1 với Web
  Widget _buildInfoTable() {
    final creatorName = UserResolver.resolveName(_task.creatorName ?? _task.createdBy);
    final assigneeName = UserResolver.resolveName(_task.assigneeName ?? _task.assigneeUserId);

    final participants = _task.participantUserIds.map((id) => UserResolver.resolveName(id)).join(', ');
    final followers = _task.followerUserIds.map((id) => UserResolver.resolveName(id)).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Người giao', creatorName),
          const Divider(height: 1, color: Color(0xFFF8FAFC)),
          _buildInfoRow('Người phụ trách', assigneeName),
          const Divider(height: 1, color: Color(0xFFF8FAFC)),
          if (participants.isNotEmpty) ...[
            _buildInfoRow('Người cùng thực hiện', participants),
            const Divider(height: 1, color: Color(0xFFF8FAFC)),
          ],
          if (followers.isNotEmpty) ...[
            _buildInfoRow('Người theo dõi', followers),
            const Divider(height: 1, color: Color(0xFFF8FAFC)),
          ],
          _buildInfoRow('Mức ưu tiên', _task.priorityLabel),
          const Divider(height: 1, color: Color(0xFFF8FAFC)),
          _buildInfoRow('Ngày bắt đầu', _formatDate(_task.plannedStart)),
          const Divider(height: 1, color: Color(0xFFF8FAFC)),
          _buildInfoRow('Hạn hoàn thành', _formatDate(_task.dueDate)),
          const Divider(height: 1, color: Color(0xFFF8FAFC)),
          _buildInfoRow('Thực tế', '—'),
          const Divider(height: 1, color: Color(0xFFF8FAFC)),
          _buildProgressRow(),
          const Divider(height: 1, color: Color(0xFFF8FAFC)),
          _buildInfoRow('Giao lúc', _formatDateTime(_task.createdAt)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow() {
    final pct = _task.progressPercent.clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          const SizedBox(
            width: 140,
            child: Text(
              'Tiến độ',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100.0,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFFEAB308),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section Việc con matching Web
  Widget _buildSubtasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 6),
                Text(
                  'Việc con',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            if (_canAddChild) ...[
              TextButton.icon(
                onPressed: () {
                  showWorkspaceAssignStandaloneTaskModal(
                    context,
                    service: widget.service,
                    parentId: _task.id,
                    onCreated: () {
                      _fetchDetail();
                      widget.onRefresh();
                    },
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Thêm việc con', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (_children.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Chưa có việc con. Chia nhỏ công việc và giao cho người khác bằng "Thêm việc con".',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          )
        else
          Column(
            children: _children.map((c) {
              final childMap = c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{};
              final childTask = StandaloneTaskItem.fromJson(childMap);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(childTask.code, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(childTask.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                    Text(childTask.statusLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
