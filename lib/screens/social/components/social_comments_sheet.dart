import 'package:flutter/material.dart';
import '../../../models/social_models.dart';
import '../../../services/social_service.dart';
import 'social_user_avatar.dart';

class SocialCommentsSheet extends StatefulWidget {
  final SocialPost post;
  final VoidCallback? onCommentCountChanged;

  const SocialCommentsSheet({
    super.key,
    required this.post,
    this.onCommentCountChanged,
  });

  @override
  State<SocialCommentsSheet> createState() => _SocialCommentsSheetState();
}

class _SocialCommentsSheetState extends State<SocialCommentsSheet> {
  final List<SocialComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final list = await SocialService().getComments(widget.post.id);
    if (mounted) {
      setState(() {
        _comments.clear();
        _comments.addAll(list);
        _isLoading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final newComment = await SocialService().createComment(widget.post.id, text);

    if (mounted) {
      if (newComment != null) {
        setState(() {
          _comments.add(newComment);
          _textController.clear();
        });
        widget.onCommentCountChanged?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gửi bình luận. Vui lòng thử lại.')),
        );
      }
      setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(SocialComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: const Text('Bạn có chắc muốn xoá bình luận này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await SocialService().deleteComment(comment.id);
      if (success && mounted) {
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
        });
        widget.onCommentCountChanged?.call();
      }
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bình luận (${_comments.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có bình luận nào.\nHãy là người đầu tiên bình luận!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _comments.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SocialUserAvatar(
                                user: c.author,
                                radius: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.author.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _stripHtml(c.contentHtml),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF334155),
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6, top: 4),
                                      child: Row(
                                        children: [
                                          Text(
                                            _formatTime(c.publishedAt),
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          ),
                                          if (c.canDelete) ...[
                                            const SizedBox(width: 12),
                                            GestureDetector(
                                              onTap: () => _deleteComment(c),
                                              child: const Text(
                                                'Xoá',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendComment(),
                        decoration: const InputDecoration(
                          hintText: 'Viết bình luận...',
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 13.5),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _isSending ? null : _sendComment,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _isSending ? const Color(0xFF94A3B8) : const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
