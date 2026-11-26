import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/workspace_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/user_resolver.dart';
import 'chats/chat_feed_by_work.dart';
import 'chats/chat_timeline_pane.dart';

/// Tab "Trao đổi công việc" (Chat Feed Tab) của dự án
/// Đồng bộ 1:1 với Web React packages/features/workspace/src/lib/components/tab-chats.tsx:
/// công tắc "Theo công việc | Theo thời gian", mặc định "Theo thời gian" (web :127).
class WorkspaceTabChatsView extends StatefulWidget {
  final String projectId;
  final WorkspaceService service;
  final ValueChanged<StandaloneTaskItem>? onOpenTaskDetail;

  /// Công việc của dự án (chip, đường dẫn cha, bộ lọc công việc); vắng thì tự tải.
  final List<StandaloneTaskItem>? items;

  /// Thành viên dự án (nhắc @, bộ lọc người gửi, vai trò viewer); vắng thì tự tải.
  final List<ProjectMemberItem>? members;

  /// Dự án chưa lưu trữ: được tải tệp mới lên khi đính kèm (web `canUpload={!archived}`).
  /// Gửi tin vào dự án đã lưu trữ do server quyết theo cài đặt "chat khi lưu trữ" của tenant.
  final bool canWrite;

  /// Tin cần cuộn tới khi mở (từ thông báo nhắc tên).
  final String? initialMessageId;

  const WorkspaceTabChatsView({
    super.key,
    required this.projectId,
    required this.service,
    this.onOpenTaskDetail,
    this.items,
    this.members,
    this.canWrite = true,
    this.initialMessageId,
  });

  @override
  State<WorkspaceTabChatsView> createState() => _WorkspaceTabChatsViewState();
}

enum _FeedMode { work, time }

class _WorkspaceTabChatsViewState extends State<WorkspaceTabChatsView> {
  _FeedMode _mode = _FeedMode.time;
  List<StandaloneTaskItem> _items = const [];
  List<ProjectMemberItem> _members = const [];

  @override
  void initState() {
    super.initState();
    _items = widget.items ?? const [];
    _members = widget.members ?? const [];
    _loadContext();
  }

  @override
  void didUpdateWidget(covariant WorkspaceTabChatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != null) _items = widget.items!;
    if (widget.members != null) _members = widget.members!;
  }

  Future<void> _loadContext() async {
    if (widget.items == null) {
      try {
        final items = await widget.service.getProjectWorkItems(widget.projectId);
        if (!mounted) return;
        setState(() => _items = items);
      } catch (_) {}
    }
    if (widget.members == null) {
      try {
        final members = await widget.service.getProjectMembers(widget.projectId);
        if (!mounted) return;
        setState(() => _members = members);
      } catch (_) {}
    }
  }

  String _nameOf(String userId) {
    for (final m in _members) {
      if (m.userId == userId && (m.fullName?.isNotEmpty ?? false)) return m.fullName!;
    }
    return UserResolver.resolveName(userId);
  }

  @override
  Widget build(BuildContext context) {
    // Chưa biết vai trò thì để server quyết: viewer bị từ chối ở API, không chỉ ẩn nút.
    final me = AuthProvider.instance?.userId;
    String? myRole;
    for (final m in _members) {
      if (m.userId == me) myRole = m.role;
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<_FeedMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(value: _FeedMode.work, label: Text('workspace.chat_timeline.mode_work'.tr())),
              ButtonSegment(value: _FeedMode.time, label: Text('workspace.chat_timeline.mode_time'.tr())),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        Expanded(
          child: _mode == _FeedMode.time
              ? ChatTimelinePane(
                  key: ValueKey('timeline-${widget.projectId}'),
                  projectId: widget.projectId,
                  items: _items,
                  members: _members,
                  nameOf: _nameOf,
                  canReply: myRole != 'viewer',
                  canUpload: widget.canWrite,
                  onOpen: widget.onOpenTaskDetail,
                  initialMessageId: widget.initialMessageId,
                )
              : ChatFeedByWorkView(
                  key: ValueKey('work-${widget.projectId}'),
                  projectId: widget.projectId,
                  items: _items,
                  members: _members,
                  nameOf: _nameOf,
                  onOpen: widget.onOpenTaskDetail,
                ),
        ),
      ],
    );
  }
}
