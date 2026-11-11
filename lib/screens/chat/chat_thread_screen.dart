import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/colors.dart';

class ChatThreadScreen extends StatefulWidget {
  final ChatConversation conversation;
  final String title;
  final String? subtitle;

  const ChatThreadScreen({
    super.key,
    required this.conversation,
    required this.title,
    this.subtitle,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  final FocusNode _focusNode = FocusNode();
  ChatMessage? _replyTo;
  ChatMessage? _editingMessage;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollNewMessages();
    });
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final msgs = await _chatService.getMessages(widget.conversation.id);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
      _markLastRead();
    }
  }

  Future<void> _pollNewMessages() async {
    final msgs = await _chatService.getMessages(widget.conversation.id);
    if (mounted && msgs.length != _messages.length) {
      setState(() {
        _messages = msgs;
      });
      _scrollToBottom();
      _markLastRead();
    }
  }

  void _markLastRead() {
    if (_messages.isNotEmpty) {
      final last = _messages.last;
      _chatService.markRead(widget.conversation.id, last.id);
      if (widget.conversation.unreadCount > 0) {
        context.read<ChatProvider>().decrementUnread(widget.conversation.unreadCount);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Check for @mentions
    final mentionMatches = RegExp(r'@([A-Za-z0-9_À-ỹ\s]+?)(?=\s|$)').allMatches(text);
    final mentions = mentionMatches.map((m) => m.group(1)?.trim() ?? '').where((n) => n.isNotEmpty).toList();

    // Mode: Edit message
    if (_editingMessage != null) {
      final msg = _editingMessage!;
      final msgId = msg.id;

      // Kiểm tra cửa sổ 15 phút đồng bộ với React & Backend (CHAT_EDIT_WINDOW_MINUTES = 15)
      if (!_canEditMessage(msg, true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chỉ có thể chỉnh sửa tin nhắn trong vòng 15 phút sau khi gửi.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _editingMessage = null;
          _textController.clear();
        });
        return;
      }

      _textController.clear();
      setState(() {
        _editingMessage = null;
      });

      final updated = await _chatService.editMessage(
        msgId,
        text,
        mentions: mentions,
      );

      if (updated != null && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx != -1) {
            _messages[idx] = updated;
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể chỉnh sửa tin nhắn (đã quá 15 phút hoặc có lỗi xảy ra).'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Mode: Send new message (with optional replyTo)
    final replyId = _replyTo?.id;
    _textController.clear();
    setState(() {
      _replyTo = null;
    });

    final sent = await _chatService.sendMessage(
      widget.conversation.id,
      text,
      mentions: mentions,
      replyToId: replyId,
    );

    if (sent != null && mounted) {
      setState(() {
        _messages.add(sent);
      });
      _scrollToBottom();
      context.read<ChatProvider>().loadConversations(silent: true);
    }
  }

  /// Giới hạn thời gian cho phép chỉnh sửa tin nhắn (15 phút, đồng bộ 1:1 với React Web ERP & Backend contracts)
  static const int chatEditWindowMinutes = 15;

  bool _canEditMessage(ChatMessage msg, bool isMe) {
    if (!isMe || msg.isDeleted) return false;
    try {
      final createdAt = DateTime.parse(msg.createdAt).toUtc();
      final now = DateTime.now().toUtc();
      final diffMinutes = now.difference(createdAt).inMinutes;
      return diffMinutes < chatEditWindowMinutes;
    } catch (_) {
      return false;
    }
  }

  void _startReply(ChatMessage msg) {
    setState(() {
      _replyTo = msg;
      _editingMessage = null;
    });
    _focusNode.requestFocus();
  }

  void _startEdit(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
      _replyTo = null;
      _textController.text = msg.body;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    });
    _focusNode.requestFocus();
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép tin nhắn'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _reactionToEmoji(String reaction) {
    switch (reaction) {
      case 'love':
        return '❤️';
      case 'haha':
        return '😆';
      case 'wow':
        return '😮';
      case 'sad':
        return '😢';
      case 'angry':
        return '😡';
      case 'like':
        return '👍';
      default:
        return '❤️';
    }
  }

  Future<void> _toggleReaction(ChatMessage msg, String reaction, String myUserId) async {
    final existing = msg.reactions.firstWhere(
      (r) => r.reaction == reaction && r.userIds.contains(myUserId),
      orElse: () => ChatReactionSummary(reaction: '', userIds: []),
    );

    final bool removing = existing.reaction.isNotEmpty;
    final String? newReaction = removing ? null : reaction;

    // Optimistic local update
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == msg.id);
      if (idx != -1) {
        final oldMsg = _messages[idx];
        final newReactions = <ChatReactionSummary>[];

        for (final r in oldMsg.reactions) {
          final filteredUsers = r.userIds.where((uid) => uid != myUserId).toList();
          if (filteredUsers.isNotEmpty || (r.reaction == reaction && !removing)) {
            newReactions.add(ChatReactionSummary(
              reaction: r.reaction,
              userIds: filteredUsers,
            ));
          }
        }

        if (!removing) {
          final existingIdx = newReactions.indexWhere((r) => r.reaction == reaction);
          if (existingIdx != -1) {
            final users = List<String>.from(newReactions[existingIdx].userIds);
            if (!users.contains(myUserId)) users.add(myUserId);
            newReactions[existingIdx] = ChatReactionSummary(
              reaction: reaction,
              userIds: users,
            );
          } else {
            newReactions.add(ChatReactionSummary(
              reaction: reaction,
              userIds: [myUserId],
            ));
          }
        }

        _messages[idx] = ChatMessage(
          id: oldMsg.id,
          conversationId: oldMsg.conversationId,
          senderId: oldMsg.senderId,
          kind: oldMsg.kind,
          body: oldMsg.body,
          mentions: oldMsg.mentions,
          replyTo: oldMsg.replyTo,
          attachments: oldMsg.attachments,
          reactions: newReactions,
          isDeleted: oldMsg.isDeleted,
          isEdited: oldMsg.isEdited,
          createdAt: oldMsg.createdAt,
          updatedAt: oldMsg.updatedAt,
        );
      }
    });

    final updated = await _chatService.reactToMessage(msg.id, newReaction);
    if (updated != null && mounted) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx != -1) {
          _messages[idx] = updated;
        }
      });
    }
  }

  void _showMessageActionMenu(
    ChatMessage msg,
    bool isMe,
    String myUserId,
    List<ChatPerson> people,
  ) {
    String? myCurrentReaction;
    for (final r in msg.reactions) {
      if (r.userIds.contains(myUserId)) {
        myCurrentReaction = r.reaction;
        break;
      }
    }

    final canEdit = _canEditMessage(msg, isMe);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Floating Reaction Bar (iOS/Messenger style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // Dark slate pill
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildReactionOption(ctx, msg, 'love', '❤️', myCurrentReaction == 'love', myUserId),
                    _buildReactionOption(ctx, msg, 'haha', '😆', myCurrentReaction == 'haha', myUserId),
                    _buildReactionOption(ctx, msg, 'wow', '😮', myCurrentReaction == 'wow', myUserId),
                    _buildReactionOption(ctx, msg, 'sad', '😢', myCurrentReaction == 'sad', myUserId),
                    _buildReactionOption(ctx, msg, 'angry', '😡', myCurrentReaction == 'angry', myUserId),
                    _buildReactionOption(ctx, msg, 'like', '👍', myCurrentReaction == 'like', myUserId),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Message preview snippet
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? 'Bạn' : _getSenderName(msg.senderId, people),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isMe ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      msg.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Action Menu (Chỉ cho phép sửa nếu là tin của mình và trong vòng 15 phút, đồng bộ 1:1 React)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildActionMenuItem(
                      icon: Icons.reply_rounded,
                      title: 'Trả lời',
                      onTap: () {
                        Navigator.pop(ctx);
                        _startReply(msg);
                      },
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildActionMenuItem(
                      icon: Icons.copy_rounded,
                      title: 'Sao chép',
                      onTap: () {
                        Navigator.pop(ctx);
                        _copyMessage(msg.body);
                      },
                    ),
                    if (canEdit) ...[
                      const Divider(height: 1, indent: 48),
                      _buildActionMenuItem(
                        icon: Icons.edit_outlined,
                        title: 'Chỉnh sửa',
                        onTap: () {
                          Navigator.pop(ctx);
                          _startEdit(msg);
                        },
                      ),
                    ],
                    if (isMe) ...[
                      const Divider(height: 1, indent: 48),
                      _buildActionMenuItem(
                        icon: Icons.delete_outline_rounded,
                        title: 'Xóa / Thu hồi',
                        color: Colors.redAccent,
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleRecall(msg);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReactionOption(
    BuildContext ctx,
    ChatMessage msg,
    String reactionKey,
    String emoji,
    bool isSelected,
    String myUserId,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        _toggleReaction(msg, reactionKey, myUserId);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 26),
        ),
      ),
    );
  }

  Widget _buildActionMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? const Color(0xFF1E293B);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: itemColor),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRecall(ChatMessage msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi tin nhắn'),
        content: const Text('Bạn có chắc chắn muốn thu hồi tin nhắn này đối với mọi người?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thu hồi', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await _chatService.recallMessage(msg.id);
      if (ok && mounted) {
        _loadMessages();
      }
    }
  }

  String _getSenderName(String senderId, List<ChatPerson> people) {
    final person = people.firstWhere(
      (p) => p.id.toLowerCase() == senderId.toLowerCase(),
      orElse: () => ChatPerson(id: senderId, fullName: '', email: ''),
    );
    if (person.fullName.isNotEmpty) return person.fullName;
    if (senderId.contains('@')) return senderId.split('@').first;
    return 'Người dùng';
  }

  String _getSenderInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final firstChar = parts[0].isNotEmpty ? parts[0][0] : '';
      final lastChar = parts[parts.length - 1].isNotEmpty ? parts[parts.length - 1][0] : '';
      return '$firstChar$lastChar'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _getSenderColor(String senderId) {
    final colors = [
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Emerald
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFF97316), // Orange
      const Color(0xFF14B8A6), // Teal
    ];
    int hash = senderId.hashCode.abs();
    return colors[hash % colors.length];
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  String _getDateDividerLabel(DateTime dt, {bool includeTime = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(msgDate).inDays;

    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    if (includeTime) {
      if (diffDays == 0) return timeStr;
      if (diffDays == 1) return 'Hôm qua $timeStr';
      return '$dateStr $timeStr';
    } else {
      if (diffDays == 0) return 'Hôm nay';
      if (diffDays == 1) return 'Hôm qua';
      return dateStr;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final myUserId = authProvider.userId ?? '';
    final people = chatProvider.people;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: widget.conversation.kind == 'company'
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF10B981),
              child: widget.conversation.kind == 'company'
                  ? const Icon(Icons.apartment_rounded, color: Colors.white, size: 20)
                  : Text(
                      widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emerald, strokeWidth: 2))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.slate400),
                            const SizedBox(height: 10),
                            Text(
                              'Chưa có tin nhắn nào',
                              style: TextStyle(color: AppColors.slate500, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hãy gửi lời chào đến mọi người!',
                              style: TextStyle(color: AppColors.slate400, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId.toLowerCase() == myUserId.toLowerCase();
                          final prevMsg = index > 0 ? _messages[index - 1] : null;

                          return _buildMessageRowWithDivider(
                            msg: msg,
                            prevMsg: prevMsg,
                            isMe: isMe,
                            people: people,
                            myUserId: myUserId,
                          );
                        },
                      ),
          ),

          // Composer
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageRowWithDivider({
    required ChatMessage msg,
    required ChatMessage? prevMsg,
    required bool isMe,
    required List<ChatPerson> people,
    required String myUserId,
  }) {
    DateTime? currentDate;
    DateTime? prevDate;
    try {
      currentDate = DateTime.parse(msg.createdAt).toLocal();
    } catch (_) {}
    if (prevMsg != null) {
      try {
        prevDate = DateTime.parse(prevMsg.createdAt).toLocal();
      } catch (_) {}
    }

    // 1. Kiểm tra ngày hoặc khoảng gián đoạn >= 30 phút
    bool showDateDivider = false;
    String dividerLabel = '';

    if (currentDate != null) {
      if (prevDate == null) {
        showDateDivider = true;
        dividerLabel = _getDateDividerLabel(currentDate);
      } else {
        final sameDay = currentDate.year == prevDate.year &&
            currentDate.month == prevDate.month &&
            currentDate.day == prevDate.day;
        final minuteDiff = currentDate.difference(prevDate).inMinutes.abs();

        if (!sameDay) {
          showDateDivider = true;
          dividerLabel = _getDateDividerLabel(currentDate);
        } else if (minuteDiff >= 30) {
          showDateDivider = true;
          // Hiển thị mốc giờ phút gián đoạn 30p như Web ERP (ví dụ: 14:38)
          dividerLabel = _formatTime(msg.createdAt);
        }
      }
    }

    // 2. Kiểm tra xem có hiển thị tên người gửi & avatar không
    // Bắt buộc hiển thị tên nếu không phải tôi AND (sau mốc ngày/30p, hoặc tin đầu, hoặc đổi người gửi, hoặc cách xa >= 5 phút)
    bool showSenderHeader = false;
    if (!isMe) {
      if (showDateDivider ||
          prevMsg == null ||
          prevMsg.senderId.toLowerCase() != msg.senderId.toLowerCase() ||
          (prevDate != null && currentDate != null && currentDate.difference(prevDate).inMinutes.abs() >= 5)) {
        showSenderHeader = true;
      }
    }

    final senderName = _getSenderName(msg.senderId, people);
    final initials = _getSenderInitials(senderName);
    final avatarColor = _getSenderColor(msg.senderId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDateDivider) _buildDateDividerPill(dividerLabel),
        _buildMessageItem(
          msg: msg,
          isMe: isMe,
          showSenderHeader: showSenderHeader,
          senderName: senderName,
          initials: initials,
          avatarColor: avatarColor,
          myUserId: myUserId,
          people: people,
        ),
      ],
    );
  }

  Widget _buildDateDividerPill(String label) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem({
    required ChatMessage msg,
    required bool isMe,
    required bool showSenderHeader,
    required String senderName,
    required String initials,
    required Color avatarColor,
    required String myUserId,
    required List<ChatPerson> people,
  }) {
    if (msg.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(left: isMe ? 0 : 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_outlined, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  'Tin nhắn đã được thu hồi',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: showSenderHeader ? 8 : 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Avatar for other senders
          if (!isMe) ...[
            if (showSenderHeader)
              CircleAvatar(
                radius: 14,
                backgroundColor: avatarColor,
                child: Text(
                  initials,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            else
              const SizedBox(width: 28), // Spacing alignment if same sender
            const SizedBox(width: 8),
          ],

          // Bubble & Sender Name & Reactions
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && showSenderHeader)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 3),
                    child: Text(
                      senderName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),

                GestureDetector(
                  onLongPress: () => _showMessageActionMenu(msg, isMe, myUserId, people),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF2563EB) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        // Quoted reply if any
                        if (msg.replyTo != null)
                          _buildQuotedReplyBox(msg.replyTo!, isMe, people),

                        _buildMessageBody(msg.body, isMe),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (msg.isEdited) ...[
                              Text(
                                'Đã sửa • ',
                                style: TextStyle(
                                  color: isMe ? Colors.white60 : const Color(0xFF94A3B8),
                                  fontSize: 9.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            Text(
                              _formatTime(msg.createdAt),
                              style: TextStyle(
                                color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Reactions display capsule under the bubble
                _buildReactionsDisplay(msg, isMe, myUserId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotedReplyBox(ChatReplyPreview reply, bool isMe, List<ChatPerson> people) {
    final sender = _getSenderName(reply.senderId, people);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isMe ? Colors.black.withOpacity(0.12) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : const Color(0xFF2563EB),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sender,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reply.isDeleted ? 'Tin nhắn đã được thu hồi' : reply.excerpt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: reply.isDeleted ? FontStyle.italic : FontStyle.normal,
              color: isMe ? Colors.white.withOpacity(0.85) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsDisplay(ChatMessage msg, bool isMe, String myUserId) {
    final activeReactions = msg.reactions.where((r) => r.userIds.isNotEmpty).toList();
    if (activeReactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        left: isMe ? 0 : 4,
        right: isMe ? 4 : 0,
        bottom: 2,
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        children: activeReactions.map((r) {
          final emoji = _reactionToEmoji(r.reaction);
          final hasMyReaction = r.userIds.contains(myUserId);
          return GestureDetector(
            onTap: () => _toggleReaction(msg, r.reaction, myUserId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: hasMyReaction ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasMyReaction ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  if (r.userIds.isNotEmpty) ...[
                    const SizedBox(width: 3.5),
                    Text(
                      '${r.userIds.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasMyReaction ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBody(String text, bool isMe) {
    // Highlight @mentions in blue
    if (!text.contains('@')) {
      return Text(
        text,
        style: TextStyle(
          color: isMe ? Colors.white : const Color(0xFF1E293B),
          fontSize: 13.5,
          height: 1.35,
        ),
      );
    }

    final spans = <TextSpan>[];
    final regex = RegExp(r'(@[A-Za-z0-9_À-ỹ\s]+?)(?=\s|$)');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF1E293B),
            fontSize: 13.5,
            height: 1.35,
          ),
        ));
      }

      final mentionText = match.group(0) ?? '';
      spans.add(TextSpan(
        text: mentionText,
        style: TextStyle(
          color: isMe ? const Color(0xFFBFDBFE) : const Color(0xFF2563EB),
          fontWeight: FontWeight.bold,
          fontSize: 13.5,
          height: 1.35,
        ),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(
          color: isMe ? Colors.white : const Color(0xFF1E293B),
          fontSize: 13.5,
          height: 1.35,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildComposer() {
    final hasReply = _replyTo != null;
    final hasEdit = _editingMessage != null;
    final people = context.watch<ChatProvider>().people;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview banner
          if (hasReply)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              'Trả lời ${_getSenderName(_replyTo!.senderId, people)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyTo!.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ],
              ),
            ),

          // Edit preview banner
          if (hasEdit)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFFFFBEB),
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 14, color: Color(0xFFD97706)),
                            SizedBox(width: 4),
                            Text(
                              'Chỉnh sửa tin nhắn',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _editingMessage!.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      setState(() {
                        _editingMessage = null;
                        _textController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),

          // Input Row
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: hasEdit
                            ? 'Chỉnh sửa nội dung...'
                            : (hasReply ? 'Nhập câu trả lời...' : 'Nhập tin nhắn hoặc gõ @...'),
                        hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasEdit ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                  ),
                  child: IconButton(
                    icon: Icon(
                      hasEdit ? Icons.check_rounded : Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
