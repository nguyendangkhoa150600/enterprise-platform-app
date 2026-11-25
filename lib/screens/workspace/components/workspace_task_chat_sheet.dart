import 'package:flutter/material.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/workspace_service.dart';
import '../../../../utils/user_resolver.dart';
import '../../../../utils/app_toast.dart';
import '../../../core/i18n/app_i18n.dart';

/// Trạng thái lượt gõ `@`
class _MentionQuery {
  final int start;
  final String term;
  const _MentionQuery(this.start, this.term);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MentionQuery && runtimeType == other.runtimeType && start == other.start && term == other.term;

  @override
  int get hashCode => start.hashCode ^ term.hashCode;
}

/// Bottom Sheet hiển thị trực tiếp trao đổi (Direct Chat Thread) của công việc
/// Đồng bộ 1:1 với ChatDrawer trên Web React packages/features/workspace/src/lib/components/chat-drawer.tsx
void showWorkspaceTaskChatSheet(
  BuildContext context, {
  required StandaloneTaskItem task,
  required WorkspaceService service,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TaskChatSheetContent(
      task: task,
      service: service,
    ),
  );
}

class _TaskChatSheetContent extends StatefulWidget {
  final StandaloneTaskItem task;
  final WorkspaceService service;

  const _TaskChatSheetContent({
    required this.task,
    required this.service,
  });

  @override
  State<_TaskChatSheetContent> createState() => _TaskChatSheetContentState();
}

class _TaskChatSheetContentState extends State<_TaskChatSheetContent> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoading = true;
  bool _isSending = false;
  List<ProjectChatMessage> _messages = [];

  List<ProjectMemberItem> _members = [];
  final Map<String, String> _memberHandles = {};
  _MentionQuery? _mentionQuery;
  final Set<String> _mentionedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadMembers();
    _msgCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _msgCtrl.removeListener(_onTextChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    final q = _findMentionQuery(text, cursor);
    if (q != _mentionQuery) {
      setState(() {
        _mentionQuery = q;
      });
    }
  }

  _MentionQuery? _findMentionQuery(String text, int cursor) {
    if (cursor <= 0 || cursor > text.length) return null;
    final before = text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    if (at < 0) return null;

    final preceding = at == 0 ? ' ' : before[at - 1];
    if (preceding != ' ' && preceding != '\n') return null;

    final term = before.substring(at + 1);
    if (term.contains(' ') || term.contains('\n')) return null;

    return _MentionQuery(at, term);
  }

  String _removeDiacritics(String str) {
    const vietnamese = 'aAeEoOuUiIdDyY';
    final patterns = [
      RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'),
      RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'),
      RegExp(r'[èéẹẻẽêềếệểễ]'),
      RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'),
      RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'),
      RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'),
      RegExp(r'[ùúụủũưừứựửữ]'),
      RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'),
      RegExp(r'[ìíịỉĩ]'),
      RegExp(r'[ÌÍỊỈĨ]'),
      RegExp(r'[đ]'),
      RegExp(r'[Đ]'),
      RegExp(r'[ỳýỵỷỹ]'),
      RegExp(r'[ỲÝỴỶỸ]'),
    ];
    var res = str;
    for (var i = 0; i < patterns.length; i++) {
      res = res.replaceAll(patterns[i], vietnamese[i]);
    }
    return res;
  }

  String _generateHandle(String name, String userId) {
    if (name.isEmpty || name == '—') return userId;
    final normalized = _removeDiacritics(name);
    final words = normalized
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return userId;
    final handle = words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join('');
    return handle.isNotEmpty ? handle : userId;
  }

  void _buildHandles() {
    _memberHandles.clear();
    for (final m in _members) {
      final name = m.fullName != null && m.fullName!.isNotEmpty
          ? m.fullName!
          : UserResolver.resolveName(m.userId);
      _memberHandles[m.userId] = _generateHandle(name, m.userId);
    }
  }

  Future<void> _loadMembers() async {
    final pId = widget.task.projectId ?? '';
    if (pId.isNotEmpty) {
      try {
        final list = await widget.service.getProjectMembers(pId);
        if (mounted && list.isNotEmpty) {
          setState(() {
            _members = list;
            _buildHandles();
          });
          return;
        }
      } catch (_) {}
    }

    // Fallback: nếu không lấy được từ dự án, lấy từ các thành viên trong công việc
    final fallbackList = <ProjectMemberItem>[];
    if (widget.task.assigneeUserId.isNotEmpty) {
      fallbackList.add(ProjectMemberItem(
        userId: widget.task.assigneeUserId,
        fullName: widget.task.assigneeName,
        role: 'assignee',
      ));
    }
    if (widget.task.createdBy.isNotEmpty && widget.task.createdBy != widget.task.assigneeUserId) {
      fallbackList.add(ProjectMemberItem(
        userId: widget.task.createdBy,
        fullName: widget.task.creatorName,
        role: 'creator',
      ));
    }
    for (final uId in widget.task.participantUserIds) {
      if (!fallbackList.any((m) => m.userId == uId)) {
        fallbackList.add(ProjectMemberItem(
          userId: uId,
          role: 'participant',
        ));
      }
    }
    if (fallbackList.isEmpty && UserResolver.allRawNames.isNotEmpty) {
      for (final entry in UserResolver.allRawNames.entries) {
        if (entry.key.isNotEmpty && entry.value != 'Người dùng' && entry.value != '—') {
          fallbackList.add(ProjectMemberItem(
            userId: entry.key,
            fullName: entry.value,
            role: 'member',
          ));
        }
      }
    }
    if (mounted) {
      setState(() {
        _members = fallbackList;
        _buildHandles();
      });
    }
  }

  List<ProjectMemberItem> _getFilteredMembers() {
    if (_mentionQuery == null) return [];
    final term = _mentionQuery!.term.trim().toLowerCase();
    if (term.isEmpty) return _members;

    final normalizedTerm = _removeDiacritics(term);
    return _members.where((m) {
      final name = m.fullName != null && m.fullName!.isNotEmpty
          ? m.fullName!
          : UserResolver.resolveName(m.userId);
      final normalizedName = _removeDiacritics(name).toLowerCase();
      final handle = (_memberHandles[m.userId] ?? m.userId).toLowerCase();
      return normalizedName.contains(normalizedTerm) ||
          handle.contains(normalizedTerm) ||
          m.userId.toLowerCase().contains(term);
    }).toList();
  }

  void _pickMention(ProjectMemberItem member) {
    if (_mentionQuery == null) return;
    final handle = _memberHandles[member.userId] ?? member.userId;
    final inserted = '@$handle ';
    final text = _msgCtrl.text;
    final cursor = _msgCtrl.selection.baseOffset >= 0 ? _msgCtrl.selection.baseOffset : text.length;

    final nextText = text.substring(0, _mentionQuery!.start) + inserted + text.substring(cursor);
    final nextCaret = _mentionQuery!.start + inserted.length;

    _mentionedUserIds.add(member.userId);

    setState(() {
      _mentionQuery = null;
    });

    _msgCtrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextCaret),
    );
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      ProjectChatThread thread = const ProjectChatThread();
      final pId = widget.task.projectId ?? '';

      // Web chat-drawer: luồng `work_item` là nguồn chính; chỉ đọc luồng của
      // bảng trao đổi dự án khi luồng chính không trả tin nào.
      thread = await widget.service.getChatThread('work_item', widget.task.id);
      if (thread.messages.isEmpty && pId.isNotEmpty) {
        thread = await widget.service.getProjectChatFeedThread(pId, widget.task.id);
      }

      if (mounted) {
        setState(() {
          _messages = thread.messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final mentionsToSend = _mentionedUserIds.isNotEmpty ? _mentionedUserIds.toList() : null;
    _msgCtrl.clear();
    _mentionedUserIds.clear();

    bool ok = false;
    try {
      ok = await widget.service.sendChatMessage(
        entityType: 'work_item',
        entityId: widget.task.id,
        body: text,
        mentions: mentionsToSend,
      );
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    setState(() => _isSending = false);
    if (ok) {
      _loadMessages();
    } else {
      // Giữ lại nội dung để người dùng gửi lại; không đẩy sang luồng khác.
      if (_msgCtrl.text.isEmpty) {
        _msgCtrl.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        if (mentionsToSend != null) _mentionedUserIds.addAll(mentionsToSend);
      }
      AppToast.error(context, widget.service.lastError ?? 'workspace.task_chat.send_failed'.tr());
    }
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final vn = dt.isUtc ? dt.add(const Duration(hours: 7)) : dt;
      return '${vn.hour.toString().padLeft(2, '0')}:${vn.minute.toString().padLeft(2, '0')} ${vn.day.toString().padLeft(2, '0')}/${vn.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  Widget _buildMessageBody(String text) {
    final regex = RegExp(r'@([a-zA-Z0-9_\u00C0-\u024F\u1E00-\u1EFF]+)');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
      );
    }

    final spans = <InlineSpan>[];
    int lastIndex = 0;
    for (final m in matches) {
      if (m.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: const TextStyle(
            color: Color(0xFF1D4ED8),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      lastIndex = m.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filteredMembers = _getFilteredMembers();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header matching Web 1:1
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Trao đổi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 7, color: Color(0xFF10B981)),
                                SizedBox(width: 4),
                                Text(
                                  'Trực tiếp',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.task.code} · ${widget.task.title}',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Đóng',
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFEAB308)))
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có trao đổi nào ở mục này.',
                          style: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        itemCount: _messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) {
                          final msg = _messages[idx];
                          final author = UserResolver.resolveName(msg.createdBy);
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      author,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatTime(msg.createdAt),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _buildMessageBody(msg.body),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Mention suggestions overlay (hiển thị ngay phía trên khung nhập khi gõ @)
          if (_mentionQuery != null && filteredMembers.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 210),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Row(
                      children: [
                        const Icon(Icons.alternate_email_rounded, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          'Nhắc thành viên (${filteredMembers.length})',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filteredMembers.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 44, color: Color(0xFFF8FAFC)),
                      itemBuilder: (ctx, i) {
                        final m = filteredMembers[i];
                        final name = m.fullName != null && m.fullName!.isNotEmpty
                            ? m.fullName!
                            : UserResolver.resolveName(m.userId);
                        final handle = _memberHandles[m.userId] ?? m.userId;
                        return InkWell(
                          onTap: () => _pickMention(m),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        '@$handle',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Bottom Bar matching Web 1:1
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dự án chưa có tài liệu nào.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _msgCtrl,
                                style: const TextStyle(fontSize: 13),
                                maxLines: null,
                                decoration: const InputDecoration(
                                  hintText: 'Nhập nội dung, gõ @ để nhắc thành viên. Enter để gửi.',
                                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.attach_file_rounded, size: 20, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: () {
                                AppToast.show(context, 'Đính kèm tài liệu từ dự án.');
                              },
                              tooltip: 'Đính kèm',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _isSending ? null : _sendMessage,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAB308),
                          shape: BoxShape.circle,
                        ),
                        child: _isSending
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                              )
                            : const Icon(Icons.near_me_rounded, size: 18, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
