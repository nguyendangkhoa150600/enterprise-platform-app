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

  List<String> get _quickPrompts => [
    'assistant.chat.qp_leave'.tr(),
    'assistant.chat.qp_ot'.tr(),
    'assistant.chat.qp_trip'.tr(),
    'assistant.chat.qp_meeting'.tr(),
    'assistant.chat.qp_task'.tr(),
    'assistant.chat.qp_incident'.tr(),
  ];

  @override
  void initState() {
    super.initState();
    _loadDirectory();

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

    // 2. Process query via AssistantService
    final reply = await _assistantService.processUserQuery(text, mentions: mentionedNames);

    if (mounted) {
      setState(() {
        _messages.add(reply);
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
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final p = _quickPrompts[idx];
          return ActionChip(
            label: Text(p, style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B))),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => _handleSendMessage(p.substring(p.indexOf(' ') + 1)),
          );
        },
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
