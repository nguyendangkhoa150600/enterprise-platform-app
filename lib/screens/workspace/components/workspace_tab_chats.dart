import 'package:flutter/material.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/user_resolver.dart';

/// Tab "Trao đổi công việc" (Chat Feed Tab) của dự án
/// Đồng bộ 1:1 với Web React packages/features/workspace/src/lib/components/tab-chats.tsx
class WorkspaceTabChatsView extends StatefulWidget {
  final String projectId;
  final WorkspaceService service;
  final ValueChanged<StandaloneTaskItem>? onOpenTaskDetail;

  const WorkspaceTabChatsView({
    super.key,
    required this.projectId,
    required this.service,
    this.onOpenTaskDetail,
  });

  @override
  State<WorkspaceTabChatsView> createState() => _WorkspaceTabChatsViewState();
}

class _WorkspaceTabChatsViewState extends State<WorkspaceTabChatsView> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _onlyWithChat = false;
  final int _page = 1;
  final int _pageSize = 20;

  bool _isLoading = true;
  String? _errorMessage;
  ProjectChatFeedPage _feedPage = const ProjectChatFeedPage();
  ProjectChatFeedItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pageData = await widget.service.getProjectChatFeed(
        widget.projectId,
        page: _page,
        pageSize: _pageSize,
        search: _searchCtrl.text.trim(),
        onlyWithChat: _onlyWithChat,
      );

      if (mounted) {
        setState(() {
          _feedPage = pageData;
          _isLoading = false;
          // Tự động chọn item đầu tiên nếu chưa chọn item nào hoặc item đã chọn không còn trong list
          if (_feedPage.items.isNotEmpty) {
            final stillExists = _feedPage.items.any((item) => item.workItemId == _selectedItem?.workItemId);
            if (!stillExists) {
              _selectedItem = _feedPage.items.first;
            }
          } else {
            _selectedItem = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể tải danh sách trao đổi. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEAB308)),
                    ),
                  )
                : _errorMessage != null
                    ? _buildErrorState()
                    : _feedPage.items.isEmpty
                        ? _buildEmptyState()
                        : _buildFeedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo mã, tên việc hoặc nội dung...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchCtrl.clear();
                                _loadFeed();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFEAB308), width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _loadFeed(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
                tooltip: 'Tải lại',
                onPressed: _loadFeed,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() => _onlyWithChat = !_onlyWithChat);
                  _loadFeed();
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: Checkbox(
                          value: _onlyWithChat,
                          activeColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() => _onlyWithChat = val ?? false);
                            _loadFeed();
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Chỉ việc có trao đổi',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_feedPage.total > 0)
                Text(
                  'Tổng ${_feedPage.total} công việc',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              _searchCtrl.text.isNotEmpty || _onlyWithChat
                  ? 'Không có công việc phù hợp.'
                  : 'Chưa có trao đổi nào trong các công việc của dự án.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Đã xảy ra lỗi',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFeed,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _feedPage.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _feedPage.items[index];
        final authorName = item.latestBy != null && item.latestBy!.isNotEmpty
            ? UserResolver.resolveName(item.latestBy!)
            : '';

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openThreadBottomSheet(item),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
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
                          item.workItemId,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (item.latestAt != null)
                        Text(
                          _formatDateTime(item.latestAt!),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.messageCount > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: item.messageCount > 0 ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.message_outlined,
                              size: 11,
                              color: item.messageCount > 0 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${item.messageCount}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.messageCount > 0 ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (item.latestBody != null && item.latestBody!.isNotEmpty) ...[
                    Text.rich(
                      TextSpan(
                        children: [
                          if (authorName.isNotEmpty)
                            TextSpan(
                              text: '$authorName: ',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          TextSpan(
                            text: item.latestBody!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    const Text(
                      'Chưa có trao đổi',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openThreadBottomSheet(ProjectChatFeedItem feedItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProjectWorkItemThreadSheet(
        projectId: widget.projectId,
        workItemId: feedItem.workItemId,
        service: widget.service,
        onOpenDetail: widget.onOpenTaskDetail,
      ),
    );
  }

  String _formatDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

/// Bottom Sheet hiển thị luồng trao đổi (Thread) chi tiết của một công việc
class _ProjectWorkItemThreadSheet extends StatefulWidget {
  final String projectId;
  final String workItemId;
  final WorkspaceService service;
  final ValueChanged<StandaloneTaskItem>? onOpenDetail;

  const _ProjectWorkItemThreadSheet({
    required this.projectId,
    required this.workItemId,
    required this.service,
    this.onOpenDetail,
  });

  @override
  State<_ProjectWorkItemThreadSheet> createState() => _ProjectWorkItemThreadSheetState();
}

class _ProjectWorkItemThreadSheetState extends State<_ProjectWorkItemThreadSheet> {
  bool _isLoading = true;
  String? _error;
  List<ProjectChatMessage> _messages = [];
  bool _hasMore = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  Future<void> _loadThread() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final thread = await widget.service.getProjectChatFeedThread(
        widget.projectId,
        widget.workItemId,
      );
      if (mounted) {
        setState(() {
          _messages = thread.messages;
          _hasMore = thread.hasMore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Không thể tải trao đổi của công việc.';
        });
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;

    setState(() => _isLoadingMore = true);
    final oldestId = _messages.first.id;

    try {
      final olderThread = await widget.service.getProjectChatFeedThread(
        widget.projectId,
        widget.workItemId,
        before: oldestId,
      );

      if (mounted) {
        setState(() {
          _messages = [...olderThread.messages, ..._messages];
          _hasMore = olderThread.hasMore;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.workItemId,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Trao đổi công việc',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Messages Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEAB308)),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                      )
                    : _messages.isEmpty
                        ? const Center(
                            child: Text(
                              'Chưa có trao đổi nào.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_hasMore && index == 0) {
                                return Center(
                                  child: TextButton(
                                    onPressed: _isLoadingMore ? null : _loadOlderMessages,
                                    child: _isLoadingMore
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text(
                                            'Xem tin cũ hơn',
                                            style: TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                                          ),
                                  ),
                                );
                              }

                              final msg = _messages[_hasMore ? index - 1 : index];
                              return _buildMessageItem(msg);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ProjectChatMessage message) {
    if (message.isDeleted) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Tin nhắn đã được thu hồi.',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
        ),
      );
    }

    final author = UserResolver.resolveName(message.createdBy);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                author,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                message.createdAt,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              if (message.isEdited) ...[
                const SizedBox(width: 6),
                const Text(
                  '(đã sửa)',
                  style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.body,
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
          if (message.attachmentDocumentId != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attach_file, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 4),
                  Text(
                    'Tài liệu đính kèm',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
