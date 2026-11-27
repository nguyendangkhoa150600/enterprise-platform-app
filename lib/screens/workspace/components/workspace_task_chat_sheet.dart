import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../features/workspace/data/datasources/workspace_chat_timeline_api.dart';
import '../../../features/workspace/data/datasources/workspace_remote_datasource.dart';
import '../../../models/workspace_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/user_resolver.dart';
import '../../../widgets/comment_thread_view.dart';
import 'workspace_upload_document_dialog.dart';

/// Bảng trượt trao đổi của công việc (web `ChatDrawer`, luồng `work_item`), mở từ nút "Trao đổi".
void showWorkspaceTaskChatSheet(
  BuildContext context, {
  required StandaloneTaskItem task,
  required WorkspaceService service,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TaskChatSheet(task: task, service: service),
  );
}

/// Khung trao đổi nhúng thẳng trong màn chi tiết công việc (đặt trên "Lịch sử hoạt động").
class WorkspaceTaskChatPanel extends StatelessWidget {
  final StandaloneTaskItem task;
  final WorkspaceService service;
  const WorkspaceTaskChatPanel({super.key, required this.task, required this.service});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: WorkspaceTaskChatThread(task: task, service: service),
      );
}

class _TaskChatSheet extends StatelessWidget {
  final StandaloneTaskItem task;
  final WorkspaceService service;
  const _TaskChatSheet({required this.task, required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      margin: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
            child: Row(children: [
              Expanded(
                child: Text(
                  '${task.code} · ${task.title}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: WorkspaceTaskChatThread(task: task, service: service),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dữ liệu trao đổi của một công việc: tải luồng `work_item`, làm mới khi có tín hiệu realtime
/// `workspace.chat.changed`, nhắc thành viên dự án bằng handle, đính kèm tài liệu dự án hoặc tải tệp mới lên.
/// Giao diện là [CommentThreadView] (cùng khối với "Trao đổi và ý kiến" của đơn từ).
class WorkspaceTaskChatThread extends StatefulWidget {
  final StandaloneTaskItem task;
  final WorkspaceService service;
  const WorkspaceTaskChatThread({super.key, required this.task, required this.service});

  @override
  State<WorkspaceTaskChatThread> createState() => _WorkspaceTaskChatThreadState();
}

class _WorkspaceTaskChatThreadState extends State<WorkspaceTaskChatThread> {
  bool _loading = true;
  List<ProjectChatMessage> _messages = [];
  List<ProjectMemberItem> _members = [];
  final Map<String, String> _handles = {};

  final WorkspaceChatTimelineApi _docsApi = WorkspaceChatTimelineApi();
  List<WorkspaceDocumentItem> _documents = [];
  List<WorkspaceFolderItem> _folders = [];
  final List<String> _attachmentIds = [];
  VoidCallback? _offRealtime;
  Timer? _realtimeTimer;

  String get _projectId => widget.task.projectId ?? '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadMembers();
    _loadDocuments();
    // Web chat-drawer: máy chủ đẩy `workspace.chat.changed` (chỉ có id) → tải lại luồng của đúng công việc này.
    _offRealtime = RealtimeService.instance.listen(
      'workspace.chat.changed',
      (data) {
        if (data['entityType'] != 'work_item' || data['entityId'] != widget.task.id) return;
        if (data['change'] == 'read') return;
        _scheduleReload();
      },
      onReconnected: _scheduleReload,
    );
  }

  @override
  void dispose() {
    _offRealtime?.call();
    _realtimeTimer?.cancel();
    super.dispose();
  }

  void _scheduleReload() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadMessages(silent: true);
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      // Web chat-drawer: luồng `work_item` là nguồn chính; chỉ đọc luồng của bảng trao đổi dự án khi luồng chính rỗng.
      var thread = await widget.service.getChatThread('work_item', widget.task.id);
      if (thread.messages.isEmpty && _projectId.isNotEmpty) {
        thread = await widget.service.getProjectChatFeedThread(_projectId, widget.task.id);
      }
      if (!mounted) return;
      setState(() {
        _messages = thread.messages;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDocuments() async {
    if (_projectId.isEmpty) return;
    final results = await Future.wait([_docsApi.loadDocuments(_projectId), _docsApi.loadFolders(_projectId)]);
    if (!mounted) return;
    setState(() {
      _documents = (results[0].data as List<WorkspaceDocumentItem>?) ?? _documents;
      _folders = (results[1].data as List<WorkspaceFolderItem>?) ?? _folders;
    });
  }

  Future<void> _loadMembers() async {
    List<ProjectMemberItem> list = const [];
    if (_projectId.isNotEmpty) {
      try {
        list = await widget.service.getProjectMembers(_projectId);
      } catch (_) {}
    }
    if (list.isEmpty) {
      // Không lấy được thành viên dự án: dùng những người của công việc.
      final t = widget.task;
      list = [
        if (t.assigneeUserId.isNotEmpty)
          ProjectMemberItem(userId: t.assigneeUserId, fullName: t.assigneeName, role: 'assignee'),
        if (t.createdBy.isNotEmpty && t.createdBy != t.assigneeUserId)
          ProjectMemberItem(userId: t.createdBy, fullName: t.creatorName, role: 'creator'),
        for (final id in t.participantUserIds.toSet())
          if (id != t.assigneeUserId && id != t.createdBy) ProjectMemberItem(userId: id, role: 'participant'),
      ];
    }
    if (!mounted) return;
    setState(() {
      _members = list;
      _handles
        ..clear()
        ..addAll({for (final m in list) m.userId: _handleOf(_nameOf(m), m.userId)});
    });
  }

  String _nameOf(ProjectMemberItem m) =>
      (m.fullName ?? '').isNotEmpty ? m.fullName! : UserResolver.resolveName(m.userId);

  static String _plain(String s) {
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      final lower = ch.toLowerCase();
      final i = from.indexOf(lower);
      if (i < 0) {
        buf.write(ch);
      } else {
        buf.write(ch == lower ? to[i] : to[i].toUpperCase());
      }
    }
    return buf.toString();
  }

  /// Handle nhắc tên: tên không dấu viết liền, hoa chữ đầu mỗi từ (ví dụ "NguyenDangKhoa").
  static String _handleOf(String name, String userId) {
    if (name.isEmpty || name == '—') return userId;
    final words =
        _plain(name).replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final handle = words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join();
    return handle.isEmpty ? userId : handle;
  }

  Future<List<CommentMentionCandidate>> _search(String query) async {
    final term = _plain(query.trim()).toLowerCase();
    return [
      for (final m in _members)
        if (term.isEmpty ||
            _plain(_nameOf(m)).toLowerCase().contains(term) ||
            (_handles[m.userId] ?? '').toLowerCase().contains(term))
          CommentMentionCandidate(
            userId: m.userId,
            name: _nameOf(m),
            insertText: _handles[m.userId] ?? m.userId,
            subtitle: '@${_handles[m.userId] ?? m.userId}',
          ),
    ];
  }

  Future<bool> _send(String body, List<String> mentionUserIds) async {
    final attachments = List<String>.of(_attachmentIds);
    if (body.isEmpty && attachments.isEmpty) return false;
    bool ok;
    try {
      ok = await widget.service.sendChatMessage(
        entityType: 'work_item',
        entityId: widget.task.id,
        body: body,
        mentions: mentionUserIds.isEmpty ? null : mentionUserIds,
        attachmentDocumentIds: attachments.isEmpty ? null : attachments,
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return ok;
    if (!ok) {
      AppToast.error(context, widget.service.lastError ?? 'workspace.task_chat.send_failed'.tr());
      return false;
    }
    setState(_attachmentIds.clear);
    await _loadMessages(silent: true);
    return true;
  }

  String _documentName(String id) {
    for (final d in _documents) {
      if (d.id == id) return d.name;
    }
    return 'workspace.chat_timeline.unknown_attachment'.tr();
  }

  /// Web: tải tệp mới lên kho tài liệu (gắn với công việc, tự xếp vào thư mục dự án/công việc) rồi chọn sẵn để gửi.
  Future<void> _upload() async {
    if (_projectId.isEmpty) return;
    final ids = await showUploadWorkspaceDocumentsDialog(
      context,
      remote: WorkspaceRemoteDataSource(),
      folders: _folders,
      linkedTo: (entityType: 'work_item', entityId: widget.task.id),
      autoPath: (projectId: _projectId, workItemId: widget.task.id),
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    await _loadDocuments();
    if (!mounted) return;
    setState(() {
      for (final id in ids) {
        if (!_attachmentIds.contains(id)) _attachmentIds.add(id);
      }
    });
  }

  Future<void> _pickExisting() async {
    final options = _documents.where((d) => !_attachmentIds.contains(d.id)).toList();
    if (options.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text('workspace.task_chat.attach_pick'.tr(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final d in options)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined, size: 20),
                      title: Text(d.name, style: const TextStyle(fontSize: 13.5)),
                      onTap: () => Navigator.pop(ctx, d.id),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _attachmentIds.add(picked));
  }

  Widget _composerHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Web: chọn một tài liệu đã có của dự án, hoặc tải tệp mới lên (nút kẹp giấy trong ô nhập).
          if (_documents.isNotEmpty)
            InkWell(
              onTap: _pickExisting,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_link_rounded, size: 15, color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(
                  (_attachmentIds.isEmpty ? 'workspace.task_chat.attach_existing' : 'workspace.task_chat.attach_more')
                      .tr(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                ),
              ]),
            )
          else
            Text('workspace.task_chat.no_documents'.tr(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          if (_attachmentIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final id in _attachmentIds)
                  InputChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.attach_file_rounded, size: 14),
                    label: Text(_documentName(id), style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _attachmentIds.remove(id)),
                  ),
              ]),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final me = AuthProvider.instance?.userId;
    final mentionPattern = RegExp(r'@[a-zA-Z0-9_À-ɏḀ-ỿ]+');
    return CommentThreadView(
      title: 'workspace.task_chat.title'.tr(args: {'count': _messages.length}),
      loading: _loading,
      loadingText: 'workspace.task_chat.loading'.tr(),
      emptyText: 'workspace.task_chat.empty'.tr(),
      hintText: 'workspace.task_chat.hint'.tr(),
      searchMentions: _search,
      onSend: _send,
      canSendEmpty: _attachmentIds.isNotEmpty,
      composerHeader: _composerHeader(),
      onAttach: _projectId.isEmpty ? null : _upload,
      attachTooltip: 'workspace.task_chat.attach_upload'.tr(),
      entries: [
        for (final m in _messages)
          CommentThreadEntry(
            id: m.id,
            authorUserId: m.createdBy,
            authorName: UserResolver.resolveName(m.createdBy),
            createdAt: DateTime.tryParse(m.createdAt)?.toLocal() ?? DateTime.now(),
            body: m.body,
            mine: me != null && m.createdBy == me,
            mentionTokens: [for (final x in mentionPattern.allMatches(m.body)) x.group(0)!],
            attachments: [
              for (final id in {...m.attachmentDocumentIds, ?m.attachmentDocumentId}) _documentName(id),
            ],
          ),
      ],
    );
  }
}
