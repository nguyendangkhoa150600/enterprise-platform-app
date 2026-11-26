import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/workspace/presentation/utils/project_access_extension.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/user_resolver.dart';
import 'workspace_blocked_reason_dialog.dart';
import 'workspace_standalone_task_detail_sheet.dart';
import 'workspace_complete_work_item_dialog.dart';
import 'workspace_cancel_work_item_dialog.dart';
import '../../../widgets/user_avatar.dart';

/// Chế độ xem bảng Kanban cho công việc dự án, đồng bộ 1:1 với Web React
/// Hỗ trợ kéo thả (Drag and Drop) thẻ công việc giữa các cột trạng thái
/// Kèm tính năng Edge Auto-scroll (tự động cuộn danh sách khi kéo thẻ đến mép màn hình)
class WorkspaceProjectKanbanView extends StatefulWidget {
  final List<StandaloneTaskItem> tasks;
  final WorkspaceService service;
  final VoidCallback onRefresh;
  /// Quyền trong dự án; `null` thì cho phép mọi thao tác (giữ hành vi cũ).
  final ProjectAccess? access;

  const WorkspaceProjectKanbanView({
    super.key,
    required this.tasks,
    required this.service,
    required this.onRefresh,
    this.access,
  });

  @override
  State<WorkspaceProjectKanbanView> createState() => _WorkspaceProjectKanbanViewState();
}

class _WorkspaceProjectKanbanViewState extends State<WorkspaceProjectKanbanView> {
  late List<StandaloneTaskItem> _localTasks;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  double _scrollSpeed = 0.0;
  /// Trạng thái của thẻ đang kéo, để làm mờ các cột không thả được (web `locked`).
  String? _draggingStatus;

  bool get _canWrite => widget.access?.canWrite ?? true;

  bool _accepts(String from, String to) =>
      _canWrite && from != to && WorkItemTransitions.canTransition(from, to);

  void _endDrag() {
    _stopAutoScroll();
    if (_draggingStatus != null && mounted) setState(() => _draggingStatus = null);
  }

  static const List<Map<String, dynamic>> _columns = [
    {
      'id': 'todo',
      'title': 'Chưa làm',
      'color': Color(0xFF64748B),
      'bgColor': Color(0xFFF8FAFC),
      'headerBg': Color(0xFFE2E8F0),
    },
    {
      'id': 'in_progress',
      'title': 'Đang làm',
      'color': Color(0xFF2563EB),
      'bgColor': Color(0xFFEFF6FF),
      'headerBg': Color(0xFFDBEAFE),
    },
    {
      'id': 'blocked',
      'title': 'Vướng mắc',
      'color': Color(0xFFDC2626),
      'bgColor': Color(0xFFFEF2F2),
      'headerBg': Color(0xFFFEE2E2),
    },
    {
      'id': 'review',
      'title': 'Chờ duyệt',
      'color': Color(0xFFD97706),
      'bgColor': Color(0xFFFFFBEB),
      'headerBg': Color(0xFFFEF3C7),
    },
    {
      'id': 'done',
      'title': 'Hoàn thành',
      'color': Color(0xFF059669),
      'bgColor': Color(0xFFECFDF5),
      'headerBg': Color(0xFFD1FAE5),
    },
    {
      'id': 'cancelled',
      'title': 'Đã huỷ',
      'color': Color(0xFF475569),
      'bgColor': Color(0xFFF1F5F9),
      'headerBg': Color(0xFFE2E8F0),
    },
  ];

  @override
  void initState() {
    super.initState();
    _localTasks = List.from(widget.tasks);
  }

  @override
  void didUpdateWidget(covariant WorkspaceProjectKanbanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tasks != oldWidget.tasks) {
      _localTasks = List.from(widget.tasks);
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _scrollController.dispose();
    super.dispose();
  }

  // Edge Auto-scroll: Tự động cuộn ngang khi ngón tay kéo thẻ áp sát mép màn hình
  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_scrollController.hasClients) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPos = renderBox.globalToLocal(details.globalPosition);
    final viewportWidth = renderBox.size.width;

    const edgeThreshold = 75.0; // Khoảng cách kích hoạt auto-scroll từ mép

    if (localPos.dx < edgeThreshold) {
      // Gần mép trái -> cuộn sang trái
      final depth = (edgeThreshold - localPos.dx).clamp(0.0, edgeThreshold);
      final ratio = depth / edgeThreshold;
      _scrollSpeed = -(3.0 + ratio * 14.0);
      _startAutoScroll();
    } else if (localPos.dx > viewportWidth - edgeThreshold) {
      // Gần mép phải -> cuộn sang phải
      final depth = (localPos.dx - (viewportWidth - edgeThreshold)).clamp(0.0, edgeThreshold);
      final ratio = depth / edgeThreshold;
      _scrollSpeed = 3.0 + ratio * 14.0;
      _startAutoScroll();
    } else {
      // Ở giữa an toàn -> dừng cuộn
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    if (_autoScrollTimer != null && _autoScrollTimer!.isActive) return;

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_scrollController.hasClients) {
        _stopAutoScroll();
        return;
      }

      final newOffset = (_scrollController.offset + _scrollSpeed).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );

      if (newOffset == _scrollController.offset) {
        return;
      }

      _scrollController.jumpTo(newOffset);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _scrollSpeed = 0.0;
  }

  List<StandaloneTaskItem> _getTasksForColumn(String columnId) {
    return _localTasks.where((t) {
      // Web tab-kanban: `phase` là vỏ chứa, không hiện trên bảng.
      if (t.meta.isPhase) return false;
      final s = t.status.toLowerCase();
      if (columnId == 'todo') {
        return s == 'todo' || s == 'draft' || s.isEmpty;
      }
      if (columnId == 'in_progress') {
        return s == 'in_progress' || s == 'deploying' || s == 'active';
      }
      if (columnId == 'blocked') {
        return s == 'blocked' || s == 'stuck' || s == 'vuong_mac';
      }
      if (columnId == 'review') {
        return s == 'review' || s == 'pending';
      }
      if (columnId == 'done') {
        return s == 'done' || s == 'completed';
      }
      if (columnId == 'cancelled') {
        return s == 'cancelled' || s == 'canceled' || s == 'da_huy';
      }
      return false;
    }).toList();
  }

  void _updateLocalTaskStatus(String taskId, String newStatus) {
    setState(() {
      _localTasks = _localTasks.map((t) {
        if (t.id == taskId) {
          final isDone = newStatus == 'done';
          return t.copyWith(
            status: newStatus,
            progressPercent: isDone ? 100.0 : t.progressPercent,
          );
        }
        return t;
      }).toList();
    });
  }

  /// Web `workItemStatusLabel`: việc huỷ hiệu lực vẫn là `cancelled` nhưng hiện riêng.
  String _statusLabel(StandaloneTaskItem task) {
    if (task.isReversed) return 'workspace.kanban.status_reversed'.tr();
    final col = _columns.where((c) => c['id'] == task.status.toLowerCase());
    return col.isEmpty ? task.status : col.first['title'] as String;
  }

  void _showError(String message) {
    if (!mounted) return;
    AppToast.error(context, message);
  }

  /// Web `toastStatusChanged`: chỉ báo khi Bắt đầu hoặc Hoàn tác; chuyển khác im lặng.
  void _toastStatusChanged(String from, String to, String code) {
    if (!mounted) return;
    if (to == 'in_progress' && from == 'todo') {
      AppToast.success(context, 'workspace.kanban.toast_started'.tr(args: {'code': code}));
    } else if (to == 'in_progress' && from == 'done') {
      AppToast.success(context, 'workspace.kanban.toast_reopened'.tr(args: {'code': code}));
    }
  }

  Future<void> _handleDropTask(StandaloneTaskItem task, String targetColumnId, String targetColumnTitle) async {
    _stopAutoScroll();

    // Nếu cùng trạng thái thì bỏ qua
    final currentStatus = task.status.toLowerCase();
    if (currentStatus == targetColumnId) return;

    final access = widget.access;
    if (!_canWrite) return;
    // Web tab-kanban: chỉ nhận bước chuyển hợp lệ theo bảng trạng thái.
    if (!WorkItemTransitions.canTransition(currentStatus, targetColumnId)) {
      _showError('workspace.kanban.invalid_transition'.tr(args: {
        'from': _statusLabel(task),
        'to': targetColumnTitle,
      }));
      return;
    }

    // Rung nhẹ xác nhận đã thả thành công
    HapticFeedback.lightImpact();

    // Vướng mắc phải kèm lý do — server từ chối `blocked` không có `note`.
    if (targetColumnId == 'blocked') {
      final ok = await showWorkspaceBlockedReasonDialog(
        context,
        task: task,
        onSubmit: (reason) async {
          final done = await widget.service.updateWorkItemStatus(task.id, 'blocked', note: reason);
          return done ? null : (widget.service.lastError ?? 'workspace.kanban.blocked_failed'.tr());
        },
      );
      if (ok && mounted) {
        _updateLocalTaskStatus(task.id, 'blocked');
        widget.onRefresh();
      }
      return;
    }

    // 1. Trường hợp thả vào "Hoàn thành": Kiểm tra điều kiện hoàn thành
    if (targetColumnId == 'done') {
      final completed = await showCompleteWorkItemDialog(
        context,
        workItemId: task.id,
        workItemCode: task.code,
        workItemTitle: task.title,
        service: widget.service,
      );
      if (completed && mounted) {
        _updateLocalTaskStatus(task.id, 'done');
        widget.onRefresh();
      }
      return;
    }

    // 2. Trường hợp thả vào "Đã huỷ": cần quyền huỷ, rồi qua modal lý do
    if (targetColumnId == 'cancelled') {
      if (access != null && !access.canCancelItem) {
        _showError('workspace.kanban.no_cancel_permission'.tr());
        return;
      }
      final cancelled = await showCancelWorkItemDialog(
        context,
        workItemId: task.id,
        workItemCode: task.code,
        workItemTitle: task.title,
        service: widget.service,
      );
      if (cancelled && mounted) {
        _updateLocalTaskStatus(task.id, 'cancelled');
        widget.onRefresh();
      }
      return;
    }

    // 3. Các trạng thái khác: chuyển thẻ ngay, thất bại thì trả về cột cũ và hiện lý do
    final originalStatus = task.status;
    _updateLocalTaskStatus(task.id, targetColumnId);

    final ok = await widget.service.updateWorkItemStatus(task.id, targetColumnId);
    if (!mounted) return;
    if (ok) {
      widget.onRefresh();
      _toastStatusChanged(currentStatus, targetColumnId, task.code);
    } else {
      _updateLocalTaskStatus(task.id, originalStatus);
      _showError(widget.service.lastError ?? 'workspace.kanban.status_failed'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Chiều cao khả dụng trừ đi padding và header cột để ListView cuộn mượt mà
        final availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 500.0;
        final listMaxHeight = (availableHeight - 65).clamp(100.0, double.infinity);

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _columns.map((col) {
              final columnId = col['id'] as String;
              final colTasks = _getTasksForColumn(columnId);
              return _buildKanbanColumn(context, col, colTasks, listMaxHeight);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildKanbanColumn(
    BuildContext context,
    Map<String, dynamic> col,
    List<StandaloneTaskItem> colTasks,
    double listMaxHeight,
  ) {
    final columnId = col['id'] as String;
    final title = col['title'] as String;
    final color = col['color'] as Color;
    final headerBg = col['headerBg'] as Color;

    // Bọc cột bằng DragTarget để nhận thẻ công việc khi được thả vào
    return DragTarget<StandaloneTaskItem>(
      onWillAcceptWithDetails: (details) => _accepts(details.data.status.toLowerCase(), columnId),
      onAcceptWithDetails: (details) {
        _handleDropTask(details.data, columnId, title);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        final locked = _draggingStatus != null && !_accepts(_draggingStatus!, columnId);

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: locked && _draggingStatus != columnId ? 0.45 : 1.0,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 270,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: isHovered ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered ? color : const Color(0xFFE2E8F0),
              width: isHovered ? 2.0 : 1.0,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column Header matching Web 1:1
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isHovered ? color.withValues(alpha: 0.2) : headerBg.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '${colTasks.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tasks List in Column with dynamic height
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listMaxHeight),
                child: colTasks.isEmpty && !isHovered
                    ? Container(
                        height: 90,
                        alignment: Alignment.center,
                        child: Text(
                          'Trống',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: colTasks.length + (isHovered ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (ctx, idx) {
                          if (isHovered && idx == colTasks.length) {
                            return _buildDropPlaceholder(title, color);
                          }
                          return _buildDraggableKanbanCard(context, colTasks[idx], idx + 1);
                        },
                      ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildDropPlaceholder(String columnTitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'Thả vào "$columnTitle"',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableKanbanCard(BuildContext context, StandaloneTaskItem task, int index) {
    // Dùng LongPressDraggable để khi lướt cuộn trang không bị nhầm kéo thả
    return LongPressDraggable<StandaloneTaskItem>(
      data: task,
      // Chỉ xem dự án thì không kéo thả đổi trạng thái được (web `draggable={canWrite}`).
      maxSimultaneousDrags: _canWrite ? null : 0,
      delay: const Duration(milliseconds: 200),
      hapticFeedbackOnStart: true,
      onDragStarted: () {
        HapticFeedback.mediumImpact();
        setState(() => _draggingStatus = task.status.toLowerCase());
      },
      onDragUpdate: _handleDragUpdate,
      onDragEnd: (_) => _endDrag(),
      onDraggableCanceled: (_, _) => _endDrag(),
      onDragCompleted: _endDrag,
      // Thẻ hiển thị khi đang kéo theo ngón tay
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: 250,
          child: Transform.rotate(
            angle: 0.03,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildCardContent(context, task, index),
            ),
          ),
        ),
      ),
      // Thẻ ở vị trí gốc khi đang được kéo đi
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _buildStaticCard(context, task, index),
      ),
      // Thẻ bình thường
      child: _buildStaticCard(context, task, index),
    );
  }

  Widget _buildStaticCard(BuildContext context, StandaloneTaskItem task, int index) {
    final isCancelled = task.status == 'cancelled' || task.status == 'canceled' || task.status == 'da_huy';

    return InkWell(
      onTap: () {
        showWorkspaceStandaloneTaskDetailSheet(
          context,
          task: task,
          service: widget.service,
          onRefresh: widget.onRefresh,
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCancelled ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: _buildCardContent(context, task, index),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, StandaloneTaskItem task, int index) {
    final isCancelled = task.status == 'cancelled' || task.status == 'canceled' || task.status == 'da_huy';
    final assigneeName = task.assigneeName != null && task.assigneeName!.isNotEmpty
        ? task.assigneeName!
        : (task.assigneeUserId.isNotEmpty ? UserResolver.resolveName(task.assigneeUserId) : 'Chưa giao');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Index + Title
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCancelled ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Row 2: Priority chip & Assignee
        Row(
          children: [
            _buildPriorityBadge(task.priority),
            const Spacer(),
            if (assigneeName != 'Chưa giao') ...[
              UserAvatar(
                userId: task.assigneeUserId,
                name: assigneeName,
                size: 16,
                background: const Color(0xFFEAB308),
                foreground: Colors.white,
                fontSize: 7,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  assigneeName,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),

        // Row 3: Due date & Progress
        if (task.dueDate != null || task.plannedStart != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 10.5, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                _formatDate(task.dueDate ?? task.plannedStart),
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              if (isCancelled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    _statusLabel(task),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                )
              else ...[
                SizedBox(
                  width: 45,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (task.progressPercent / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        task.progressPercent >= 100 ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${task.progressPercent.toInt()}%',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: task.progressPercent >= 100 ? const Color(0xFF047857) : const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPriorityBadge(String p) {
    Color bg;
    Color text;
    String label;
    switch (p.toLowerCase()) {
      case 'urgent':
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFDC2626);
        label = 'Khẩn cấp';
        break;
      case 'high':
        bg = const Color(0xFFFFF7ED);
        text = const Color(0xFFEA580C);
        label = 'Cao';
        break;
      case 'low':
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'Thấp';
        break;
      case 'normal':
      default:
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF2563EB);
        label = 'Bình thường';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: text)),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
