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
  SocialComment? _replyingTo;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _reactionOverlay;

  static const List<(String, String)> _reactions = [
    ('like', '👍'),
    ('love', '❤️'),
    ('haha', '😂'),
    ('wow', '😮'),
    ('sad', '😢'),
    ('angry', '😡'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_dismissReactionOverlay);
    _loadComments();
  }

  @override
  void dispose() {
    _dismissReactionOverlay();
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _dismissReactionOverlay() {
    _reactionOverlay?.remove();
    _reactionOverlay = null;
  }

  void _showReactionPicker(BuildContext context, Offset tapPosition, SocialComment comment) {
    _dismissReactionOverlay();

    final overlayState = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    const pickerWidth = 248.0;
    const pickerHeight = 46.0;

    // Position floating above the tap position
    double top = tapPosition.dy - pickerHeight - 12;
    if (top < MediaQuery.of(context).padding.top + 20) {
      top = tapPosition.dy + 24; // Fallback below if too high
    }

    final left = (tapPosition.dx - 32).clamp(12.0, screenSize.width - pickerWidth - 12.0);

    _reactionOverlay = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // Barrier dismiss on tap outside
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissReactionOverlay,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.75, end: 1.0),
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      alignment: Alignment.bottomLeft,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _reactions.map((r) {
                        final isSelected = comment.myReaction == r.$1;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _dismissReactionOverlay();
                            _toggleReaction(comment, r.$1);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: isSelected
                                ? BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(16),
                                  )
                                : null,
                            child: Text(
                              r.$2,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(_reactionOverlay!);
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final list = await SocialService().getComments(widget.post.id);

    // Automatically load nested replies for comments with replyCount > 0
    final enriched = await Future.wait(list.map((c) async {
      if (c.replyCount > 0) {
        final replies = await SocialService().getComments(widget.post.id, parentId: c.id);
        return c.copyWith(replies: replies);
      }
      return c;
    }));

    if (mounted) {
      setState(() {
        _comments.clear();
        _comments.addAll(enriched);
        _isLoading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final parentId = _replyingTo != null ? (_replyingTo!.parentId ?? _replyingTo!.id) : null;
    final newComment = await SocialService().createComment(widget.post.id, text, parentId: parentId);

    if (mounted) {
      if (newComment != null) {
        setState(() {
          if (parentId != null) {
            final parentIdx = _comments.indexWhere((c) => c.id == parentId);
            if (parentIdx != -1) {
              final parent = _comments[parentIdx];
              final updatedReplies = [...parent.replies, newComment];
              _comments[parentIdx] = parent.copyWith(
                replies: updatedReplies,
                replyCount: parent.replyCount + 1,
              );
            } else {
              _comments.add(newComment);
            }
          } else {
            _comments.add(newComment);
          }
          _textController.clear();
          _replyingTo = null;
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

  Future<void> _toggleReaction(SocialComment comment, [String? reactionType]) async {
    final oldReaction = comment.myReaction;
    String? newType;

    if (reactionType != null) {
      newType = oldReaction == reactionType ? null : reactionType;
    } else {
      newType = oldReaction != null ? null : 'like';
    }

    if (oldReaction == newType) return;

    // Optimistic update
    final newCounts = Map<String, int>.from(comment.reactionCounts);
    int newTotal = comment.reactionTotal;

    if (oldReaction != null) {
      final cur = newCounts[oldReaction] ?? 1;
      if (cur <= 1) {
        newCounts.remove(oldReaction);
      } else {
        newCounts[oldReaction] = cur - 1;
      }
      newTotal = newTotal > 0 ? newTotal - 1 : 0;
    }

    if (newType != null) {
      newCounts[newType] = (newCounts[newType] ?? 0) + 1;
      newTotal += 1;
    }

    final updated = comment.copyWith(
      myReaction: newType,
      clearMyReaction: newType == null,
      reactionCounts: newCounts,
      reactionTotal: newTotal,
    );

    setState(() {
      _updateCommentInList(updated);
    });

    await SocialService().setCommentReaction(comment.id, newType);
  }

  void _updateCommentInList(SocialComment updated) {
    if (updated.parentId == null) {
      final idx = _comments.indexWhere((c) => c.id == updated.id);
      if (idx != -1) _comments[idx] = updated;
    } else {
      for (int i = 0; i < _comments.length; i++) {
        final parent = _comments[i];
        final replyIdx = parent.replies.indexWhere((r) => r.id == updated.id);
        if (replyIdx != -1) {
          final newReplies = [...parent.replies];
          newReplies[replyIdx] = updated;
          _comments[i] = parent.copyWith(replies: newReplies);
          break;
        }
      }
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
          if (comment.parentId == null) {
            _comments.removeWhere((c) => c.id == comment.id);
          } else {
            for (int i = 0; i < _comments.length; i++) {
              final parent = _comments[i];
              if (parent.replies.any((r) => r.id == comment.id)) {
                final newReplies = parent.replies.where((r) => r.id != comment.id).toList();
                _comments[i] = parent.copyWith(
                  replies: newReplies,
                  replyCount: (parent.replyCount > 0 ? parent.replyCount - 1 : 0),
                );
                break;
              }
            }
          }
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

  String _reactionEmoji(String? type) {
    switch (type) {
      case 'love':
        return '❤️';
      case 'haha':
        return '😂';
      case 'wow':
        return '😮';
      case 'sad':
        return '😢';
      case 'angry':
        return '😡';
      case 'like':
      default:
        return '👍';
    }
  }

  String _topReactionEmoji(Map<String, int> counts) {
    if (counts.isEmpty) return '👍';
    String topKey = 'like';
    int maxCount = -1;
    counts.forEach((k, v) {
      if (v > maxCount) {
        maxCount = v;
      }
    });
    return _reactionEmoji(topKey);
  }

  Widget _buildCommentRow(SocialComment comment, {bool isReply = false}) {
    final cleanBody = _stripHtml(comment.contentHtml);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SocialUserAvatar(
          user: comment.author,
          radius: isReply ? 14 : 17,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          comment.author.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${_formatTime(comment.publishedAt)}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    if (cleanBody.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        cleanBody,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF1E293B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action row below bubble
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Row(
                  children: [
                    // Reaction button (outline thumb when unreacted, emoji when reacted)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleReaction(comment),
                      onLongPressStart: (details) => _showReactionPicker(context, details.globalPosition, comment),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: comment.myReaction != null
                            ? Text(
                                _reactionEmoji(comment.myReaction),
                                style: const TextStyle(fontSize: 14),
                              )
                            : const Icon(
                                Icons.thumb_up_alt_outlined,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Reply Button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() => _replyingTo = comment);
                        _focusNode.requestFocus();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Trả lời',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                    // Reaction Summary Badge
                    if (comment.reactionTotal > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _topReactionEmoji(comment.reactionCounts),
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${comment.reactionTotal}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (comment.canDelete) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _deleteComment(comment),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Xoá',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
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
  }

  Widget _buildCommentThread(SocialComment comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentRow(comment),
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6),
            child: Column(
              children: comment.replies.map((reply) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // L-shaped branch connector
                      Container(
                        width: 16,
                        height: 20,
                        margin: const EdgeInsets.only(right: 8, top: 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                            bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          ),
                          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
                        ),
                      ),
                      Expanded(child: _buildCommentRow(reply, isReply: true)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
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
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _comments.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          return _buildCommentThread(c);
                        },
                      ),
          ),

          // Active reply banner (if replying to someone)
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFFEFF6FF),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Đang trả lời ${_replyingTo!.author.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                  ),
                ],
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
                        decoration: InputDecoration(
                          hintText: _replyingTo != null
                              ? 'Trả lời ${_replyingTo!.author.name}...'
                              : 'Viết bình luận...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
