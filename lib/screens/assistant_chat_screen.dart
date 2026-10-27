import '../core/i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../models/assistant_models.dart';
import '../services/assistant_service.dart';
import '../widgets/assistant_action_card.dart';

class AssistantChatScreen extends StatefulWidget {
  final String? initialPrompt;

  const AssistantChatScreen({
    super.key,
    this.initialPrompt,
  });

  @override
  State<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends State<AssistantChatScreen> {
  final AssistantService _assistantService = AssistantService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<AssistantMessage> _messages = [];
  bool _isTyping = false;

  // Mentions (@) state
  List<MentionUser> _directory = [];
  List<MentionUser> _filteredMentions = [];
  bool _showMentionPopup = false;
  int _mentionStartIndex = -1;

  String _activeShortcutTab = 'view'; // 'view' (Xem nhanh) hoặc 'create' (Tạo nhanh)
  Map<String, int> _shortcutCounts = {
    'view.my_overdue_work': 6,
    'view.pending_approval': 8,
  };

  List<QuickShortcutItem> get _viewShortcuts => [
    const QuickShortcutItem(
      key: 'view.my_work_today',
      label: 'Việc hôm nay',
      icon: Icons.calendar_today_outlined,
      group: 'view',
      prompt: 'Xem việc hôm nay của tôi',
    ),
    QuickShortcutItem(
      key: 'view.my_overdue_work',
      label: 'Việc quá hạn',
      icon: Icons.alarm_outlined,
      group: 'view',
      prompt: 'Xem các việc quá hạn của tôi',
      count: _shortcutCounts['view.my_overdue_work'] ?? 6,
    ),
    QuickShortcutItem(
      key: 'view.pending_approval',
      label: 'Chờ tôi duyệt',
      icon: Icons.checklist_rounded,
      group: 'view',
      prompt: 'Xem các yêu cầu đang chờ tôi duyệt',
      count: _shortcutCounts['view.pending_approval'] ?? 8,
    ),
    const QuickShortcutItem(
      key: 'view.leave_balance',
      label: 'Phép còn lại',
      icon: Icons.hourglass_empty_rounded,
      group: 'view',
      prompt: 'Xem số ngày phép còn lại của tôi',
    ),
  ];

  List<QuickShortcutItem> get _createShortcuts => const [
    QuickShortcutItem(
      key: 'create.leave',
      label: 'Xin nghỉ phép',
      icon: Icons.edit_note_rounded,
      group: 'create',
      prompt: 'Tôi muốn tạo đơn xin nghỉ phép',
    ),
    QuickShortcutItem(
      key: 'create.overtime',
      label: 'Đăng ký làm thêm giờ (OT)',
      icon: Icons.more_time_rounded,
      group: 'create',
      prompt: 'Tôi muốn đăng ký làm thêm giờ (OT)',
    ),
    QuickShortcutItem(
      key: 'create.business_trip',
      label: 'Tạo đơn công tác',
      icon: Icons.flight_takeoff_rounded,
      group: 'create',
      prompt: 'Tôi muốn tạo đơn đi công tác',
    ),
    QuickShortcutItem(
      key: 'create.task',
      label: 'Tạo công việc',
      icon: Icons.add_task_rounded,
      group: 'create',
      prompt: 'Tạo công việc mới',
    ),
    QuickShortcutItem(
      key: 'create.meeting',
      label: 'Đặt lịch họp',
      icon: Icons.event_available_rounded,
      group: 'create',
      prompt: 'Đặt lịch họp mới',
    ),
    QuickShortcutItem(
      key: 'create.incident',
      label: 'Báo sự cố thiết bị',
      icon: Icons.warning_amber_rounded,
      group: 'create',
      prompt: 'Báo sự cố thiết bị hư hỏng',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDirectory();
    _loadShortcutCounts();

    // Initial message from Assistant
    _messages.add(AssistantMessage(
      id: 'welcome',
      sender: MessageSender.assistant,
      text: 'assistant.chat.welcome'.tr(),
      timestamp: DateTime.now(),
    ));

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendMessage(widget.initialPrompt!);
      });
    }
  }

  Future<void> _loadShortcutCounts() async {
    try {
      final counts = await _assistantService.getShortcutCounts();
      if (mounted && counts.isNotEmpty) {
        setState(() {
          _shortcutCounts = counts;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory() async {
    final list = await _assistantService.getMentionDirectory();
    if (mounted) {
      setState(() {
        _directory = list;
      });
    }
  }

  void _onInputChanged(String text) {
    final sel = _inputController.selection;
    if (sel.baseOffset < 0) return;

    final cursorPosition = sel.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastAt = textBeforeCursor.lastIndexOf('@');

    if (lastAt >= 0 && (lastAt == 0 || textBeforeCursor[lastAt - 1] == ' ' || textBeforeCursor[lastAt - 1] == '\n')) {
      final query = textBeforeCursor.substring(lastAt + 1).toLowerCase();
      if (!query.contains(' ')) {
        final matches = _directory.where((u) {
          return u.displayName.toLowerCase().contains(query) ||
              (u.email?.toLowerCase().contains(query) ?? false) ||
              (u.departmentName?.toLowerCase().contains(query) ?? false);
        }).toList();

        setState(() {
          _mentionStartIndex = lastAt;
          _filteredMentions = matches;
          _showMentionPopup = matches.isNotEmpty;
        });
        return;
      }
    }

    if (_showMentionPopup) {
      setState(() {
        _showMentionPopup = false;
        _mentionStartIndex = -1;
      });
    }
  }

  void _insertMention(MentionUser user) {
    if (_mentionStartIndex < 0) return;
    final text = _inputController.text;
    final sel = _inputController.selection;
    final cursorPosition = sel.baseOffset >= 0 ? sel.baseOffset : text.length;

    final before = text.substring(0, _mentionStartIndex);
    final after = text.substring(cursorPosition);
    final inserted = '@${user.displayName} ';

    _inputController.text = '$before$inserted$after';
    _inputController.selection = TextSelection.collapsed(offset: before.length + inserted.length);

    setState(() {
      _showMentionPopup = false;
      _mentionStartIndex = -1;
    });
  }

  Future<void> _handleSendMessage(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    setState(() {
      _showMentionPopup = false;
      _mentionStartIndex = -1;
    });

    // Detect @mentions in message
    final mentionMatches = RegExp(r'@([A-Za-z0-9_À-ỹ\s]+?)(?=\s|$)').allMatches(text);
    final mentionedNames = mentionMatches.map((m) => m.group(1)?.trim() ?? '').where((n) => n.isNotEmpty).toList();

    // 1. Add user message
    final userMsg = AssistantMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      text: text,
      timestamp: DateTime.now(),
      mentions: mentionedNames,
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });

    _scrollToBottom();

    // 2. Process query via AssistantService with real-time SSE delta streaming
    final botMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    bool addedStreamingMsg = false;
    String streamedText = '';

    final reply = await _assistantService.processUserQuery(
      text,
      mentions: mentionedNames,
      onDelta: (delta) {
        if (!mounted) return;
        streamedText += delta;
        setState(() {
          if (!addedStreamingMsg) {
            addedStreamingMsg = true;
            _isTyping = false;
            _messages.add(AssistantMessage(
              id: botMsgId,
              sender: MessageSender.assistant,
              text: streamedText,
              timestamp: DateTime.now(),
            ));
          } else {
            final idx = _messages.indexWhere((m) => m.id == botMsgId);
            if (idx >= 0) {
              _messages[idx] = _messages[idx].copyWith(text: streamedText);
            }
          }
        });
        _scrollToBottom();
      },
    );

    if (mounted) {
      setState(() {
        if (addedStreamingMsg) {
          final idx = _messages.indexWhere((m) => m.id == botMsgId);
          if (idx >= 0) {
            _messages[idx] = reply.copyWith(id: botMsgId);
          } else {
            _messages.add(reply);
          }
        } else {
          _messages.add(reply);
        }
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF2563EB), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'assistant.chat.title'.tr(),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(width: 5),
                    Icon(Icons.verified, size: 13, color: Color(0xFF2563EB)),
                  ],
                ),
                SizedBox(height: 1),
                Text(
                  'assistant.chat.subtitle'.tr(),
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
            tooltip: 'assistant.chat.reset_tooltip'.tr(),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(AssistantMessage(
                  id: 'welcome',
                  sender: MessageSender.assistant,
                  text: 'assistant.chat.reset_welcome'.tr(),
                  timestamp: DateTime.now(),
                ));
              });
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Message list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return _buildTypingIndicator();
                    }
                    final msg = _messages[index];
                    return _buildMessageItem(msg);
                  },
                ),
              ),

              // 2. Quick Prompts Chips
              if (_messages.length <= 3) _buildQuickPromptsBar(),

              // 3. Input bar
              _buildInputBar(),
            ],
          ),

          // Floating Mention Popup when user types @
          if (_showMentionPopup) _buildMentionOverlay(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(AssistantMessage msg) {
    final isUser = msg.sender == MessageSender.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF1D4ED8) : Colors.white,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                      bottomLeft: !isUser ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                    border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _formatMessageText(msg.text, isUser),
                      const SizedBox(height: 4),
                      Text(
                        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isUser ? Colors.white70 : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                // Embedded Action Draft Card in Assistant Message
                if (!isUser && msg.actionDraft != null)
                  AssistantActionCard(
                    draft: msg.actionDraft!,
                    onSubmitted: () => setState(() {}),
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 2),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _formatMessageText(String text, bool isUser) {
    if (isUser) {
      return Text(
        text,
        style: const TextStyle(fontSize: 13.5, color: Colors.white, height: 1.4),
      );
    }

    // Markdown bold handling
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ));
      } else {
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(color: Color(0xFF334155)),
        ));
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13.5, height: 1.4),
        children: spans,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEFF6FF),
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 8),
                Text(
                  'assistant.chat.processing'.tr(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptsBar() {
    final activeItems = _activeShortcutTab == 'view' ? _viewShortcuts : _createShortcuts;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Hai tab chuyển đổi "Xem nhanh" và "Tạo nhanh" chuẩn Web Savina
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _activeShortcutTab = 'view'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: _activeShortcutTab == 'view' ? const Color(0xFFFEF3C7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Xem nhanh',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _activeShortcutTab == 'view' ? FontWeight.w700 : FontWeight.w600,
                        color: _activeShortcutTab == 'view' ? const Color(0xFF92400E) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _activeShortcutTab = 'create'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: _activeShortcutTab == 'create' ? const Color(0xFFFEF3C7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Tạo nhanh',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _activeShortcutTab == 'create' ? FontWeight.w700 : FontWeight.w600,
                        color: _activeShortcutTab == 'create' ? const Color(0xFF92400E) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),

          // 2. Danh sách phím tắt dạng viên thuốc (capsule) có icon + badge số lượng
          SizedBox(
            height: 34,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: activeItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final item = activeItems[idx];
                final count = _shortcutCounts[item.key] ?? item.count;
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => _handleSendMessage(item.prompt),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 14, color: const Color(0xFF334155)),
                          const SizedBox(width: 6),
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (count != null && count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Mention @ trigger button
            IconButton(
              icon: const Icon(Icons.alternate_email_rounded, size: 20, color: Color(0xFF64748B)),
              tooltip: 'assistant.chat.mention_tooltip'.tr(),
              onPressed: () {
                final text = _inputController.text;
                _inputController.text = '$text@';
                _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
                _onInputChanged(_inputController.text);
              },
            ),

            // Input field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _inputController,
                  onChanged: _onInputChanged,
                  onSubmitted: _handleSendMessage,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'assistant.chat.input_hint'.tr(),
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send Button
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                onPressed: () => _handleSendMessage(_inputController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentionOverlay() {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 60,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email, size: 14, color: Color(0xFF2563EB)),
                    SizedBox(width: 6),
                    Text(
                      'assistant.chat.mention_header'.tr(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _filteredMentions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, idx) {
                    final u = _filteredMentions[idx];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Text(
                          u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ),
                      title: Text(u.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        u.departmentName ?? u.roleName ?? u.email ?? '',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                      onTap: () => _insertMention(u),
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
}
