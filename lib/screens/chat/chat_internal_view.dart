import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../../services/chat_service.dart';
import '../../theme/colors.dart';
import 'chat_thread_screen.dart';
import 'create_group_dialog.dart';

class ChatInternalView extends StatefulWidget {
  const ChatInternalView({super.key});

  @override
  State<ChatInternalView> createState() => _ChatInternalViewState();
}

class _ChatInternalViewState extends State<ChatInternalView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openConversation(ChatConversation conversation, String title, {String? subtitle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          conversation: conversation,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  Future<void> _startDirectChat(ChatPerson person) async {
    final chatService = ChatService();
    final conv = await chatService.createDirectChat(person.id);
    if (conv != null && mounted) {
      _openConversation(conv, person.fullName, subtitle: person.email);
      context.read<ChatProvider>().loadConversations(silent: true);
    }
  }

  void _openCreateGroup(List<ChatPerson> people) {
    showDialog(
      context: context,
      builder: (_) => CreateGroupDialog(
        people: people,
        onCreated: (conv) {
          _openConversation(conv, conv.title ?? 'Nhóm mới');
          context.read<ChatProvider>().loadConversations(silent: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.conversations;
    final people = chatProvider.people;

    // Filter conversations & people by search query
    final filteredConversations = conversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final title = c.title?.toLowerCase() ?? '';
      final excerpt = c.lastMessage?.excerpt.toLowerCase() ?? '';
      return title.contains(q) || excerpt.contains(q);
    }).toList();

    final filteredPeople = people.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.fullName.toLowerCase().contains(q) || p.email.toLowerCase().contains(q);
    }).toList();

    // Find "Tất cả nội bộ" (company channel)
    final companyConv = conversations.firstWhere(
      (c) => c.kind == 'company',
      orElse: () => ChatConversation(
        id: 'company',
        kind: 'company',
        title: 'Tất cả nội bộ',
        createdAt: '',
      ),
    );

    return RefreshIndicator(
      onRefresh: () async {
        await chatProvider.loadConversations();
        await chatProvider.loadPeople();
      },
      color: AppColors.emerald,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Search Bar & Create Group Action
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      hintText: 'Tìm người hoặc nhóm...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.group_add_outlined, color: AppColors.emerald, size: 20),
                  tooltip: 'Tạo nhóm',
                  onPressed: () => _openCreateGroup(people),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Company Pinned Channel: "Tất cả nội bộ"
          _buildCompanyChannelCard(companyConv),

          const SizedBox(height: 16),

          // 3. Section: Conversations List
          if (filteredConversations.where((c) => c.kind != 'company').isNotEmpty) ...[
            const Text(
              'Gần đây',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...filteredConversations
                .where((c) => c.kind != 'company')
                .map((conv) => _buildConversationRow(conv, people)),
            const SizedBox(height: 16),
          ],

          // 4. Section: People Directory ("Mọi người")
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mọi người trong công ty',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${filteredPeople.length} nhân sự',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (filteredPeople.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: const Text('Không tìm thấy nhân sự phù hợp', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            )
          else
            ...filteredPeople.map((p) => _buildPersonRow(p)),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCompanyChannelCard(ChatConversation companyConv) {
    return InkWell(
      onTap: () => _openConversation(companyConv, 'Tất cả nội bộ', subtitle: 'Kênh chat toàn thể công ty'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade300, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Tất cả nội bộ',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Công ty',
                          style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    companyConv.lastMessage?.excerpt ?? 'Tin nhắn gửi đến toàn bộ nhân sự trong công ty',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (companyConv.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${companyConv.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationRow(ChatConversation conv, List<ChatPerson> people) {
    // Determine title
    String title = conv.title ?? '';
    if (title.isEmpty && conv.peerUserId != null) {
      final peer = people.firstWhere(
        (p) => p.id.toLowerCase() == conv.peerUserId!.toLowerCase(),
        orElse: () => ChatPerson(id: conv.peerUserId!, fullName: 'Đồng nghiệp', email: ''),
      );
      title = peer.fullName;
    }
    if (title.isEmpty) title = 'Trò chuyện';

    final lastMsg = conv.lastMessage;
    final hasUnread = conv.unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        onTap: () => _openConversation(conv, title),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: conv.kind == 'group' ? const Color(0xFF6366F1) : AppColors.emerald,
          child: Text(
            title.isNotEmpty ? title[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          lastMsg?.isDeleted == true ? 'Tin nhắn đã được thu hồi' : (lastMsg?.excerpt ?? 'Bắt đầu cuộc trò chuyện'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontStyle: lastMsg?.isDeleted == true ? FontStyle.italic : FontStyle.normal,
            color: hasUnread ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: hasUnread
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conv.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              )
            : (conv.lastMessageAt != null
                ? Text(
                    _formatTime(conv.lastMessageAt!),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  )
                : null),
      ),
    );
  }

  Widget _buildPersonRow(ChatPerson person) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        onTap: () => _startDirectChat(person),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF3B82F6),
          child: Text(
            person.fullName.isNotEmpty ? person.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        title: Text(
          person.fullName,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        ),
        subtitle: Text(
          person.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF64748B)),
        ),
      ),
    );
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

