import 'package:flutter/material.dart';
import '../../../models/social_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/social_service.dart';
import 'social_user_avatar.dart';
import 'social_video_player.dart';

class SocialPostCard extends StatefulWidget {
  final SocialPost post;
  final VoidCallback? onPostUpdated;
  final VoidCallback? onPostDeleted;
  final VoidCallback? onCommentTap;

  const SocialPostCard({
    super.key,
    required this.post,
    this.onPostUpdated,
    this.onPostDeleted,
    this.onCommentTap,
  });

  @override
  State<SocialPostCard> createState() => _SocialPostCardState();
}

class _SocialPostCardState extends State<SocialPostCard> {
  late SocialPost _post;
  bool _isReacting = false;
  bool _isBookmarking = false;
  bool _isExpanded = false;
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
    _post = widget.post;
  }

  @override
  void didUpdateWidget(covariant SocialPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _post = widget.post;
    }
  }

  @override
  void dispose() {
    _dismissReactionOverlay();
    super.dispose();
  }

  void _dismissReactionOverlay() {
    _reactionOverlay?.remove();
    _reactionOverlay = null;
  }

  void _showReactionPicker(BuildContext context, Offset tapPosition) {
    _dismissReactionOverlay();

    final overlayState = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    const pickerWidth = 248.0;
    const pickerHeight = 46.0;

    double top = tapPosition.dy - pickerHeight - 12;
    if (top < MediaQuery.of(context).padding.top + 20) {
      top = tapPosition.dy + 24;
    }

    final left = (tapPosition.dx - 32).clamp(16.0, screenSize.width - pickerWidth - 16.0);

    _reactionOverlay = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
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
                        final isSelected = _post.myReaction == r.$1;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _dismissReactionOverlay();
                            _toggleLike(r.$1);
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

  Future<void> _toggleLike([String? reactionType]) async {
    if (_isReacting) return;
    setState(() => _isReacting = true);

    final oldReaction = _post.myReaction;
    String? newReaction;

    if (reactionType != null) {
      newReaction = oldReaction == reactionType ? null : reactionType;
    } else {
      newReaction = oldReaction != null ? null : 'like';
    }

    if (oldReaction == newReaction) {
      if (mounted) setState(() => _isReacting = false);
      return;
    }

    // Optimistic update
    final newCounts = Map<String, int>.from(_post.reactionCounts);
    int newTotal = _post.reactionTotal;

    if (oldReaction != null) {
      final cur = newCounts[oldReaction] ?? 1;
      if (cur <= 1) {
        newCounts.remove(oldReaction);
      } else {
        newCounts[oldReaction] = cur - 1;
      }
      newTotal = (newTotal > 0) ? newTotal - 1 : 0;
    }

    if (newReaction != null) {
      newCounts[newReaction] = (newCounts[newReaction] ?? 0) + 1;
      newTotal += 1;
    }

    setState(() {
      _post = _post.copyWith(
        myReaction: newReaction,
        clearMyReaction: newReaction == null,
        reactionCounts: newCounts,
        reactionTotal: newTotal,
      );
    });

    final success = await SocialService().setReaction(_post.id, newReaction);
    if (!success && mounted) {
      // Revert if failed
      setState(() => _post = widget.post);
    } else {
      widget.onPostUpdated?.call();
    }

    if (mounted) setState(() => _isReacting = false);
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarking) return;
    setState(() => _isBookmarking = true);

    final newBookmarked = !_post.bookmarked;
    setState(() {
      _post = _post.copyWith(bookmarked: newBookmarked);
    });

    final success = await SocialService().setBookmark(_post.id, newBookmarked);
    if (!success && mounted) {
      setState(() => _post = _post.copyWith(bookmarked: !newBookmarked));
    } else {
      widget.onPostUpdated?.call();
    }

    if (mounted) setState(() => _isBookmarking = false);
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'detail':
        widget.onCommentTap?.call();
        break;

      case 'pin':
        final nextPinned = !_post.pinned;
        setState(() => _post = _post.copyWith(pinned: nextPinned));
        final success = await SocialService().pinPost(_post.id, nextPinned);
        if (!success && mounted) {
          setState(() => _post = _post.copyWith(pinned: !nextPinned));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể thay đổi trạng thái ghim bài viết.')),
          );
        } else if (mounted) {
          widget.onPostUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(nextPinned ? 'Đã ghim bài viết.' : 'Đã bỏ ghim bài viết.')),
          );
        }
        break;

      case 'toggle_comments':
        final nextDisabled = !_post.commentsDisabled;
        setState(() => _post = _post.copyWith(commentsDisabled: nextDisabled));
        final success = await SocialService().updatePost(_post.id, {'commentsDisabled': nextDisabled});
        if (!success && mounted) {
          setState(() => _post = _post.copyWith(commentsDisabled: !nextDisabled));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể thay đổi tính năng bình luận.')),
          );
        } else if (mounted) {
          widget.onPostUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(nextDisabled ? 'Đã tắt tính năng bình luận.' : 'Đã bật tính năng bình luận.')),
          );
        }
        break;

      case 'edit':
        await _showEditDialog();
        break;

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text('Bạn có chắc muốn xóa bài viết này không?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Hủy')),
              TextButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          final deleted = await SocialService().deletePost(_post.id);
          if (deleted && mounted) {
            widget.onPostDeleted?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã xóa bài viết.')),
            );
          }
        }
        break;
    }
  }

  Future<void> _showEditDialog() async {
    final textController = TextEditingController(text: _stripHtml(_post.bodyHtml));
    final updatedText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sửa bài viết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Nhập nội dung bài viết...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, textController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Lưu thay đổi'),
              ),
            ],
          ),
        );
      },
    );

    if (updatedText != null && updatedText.isNotEmpty && updatedText != _stripHtml(_post.bodyHtml)) {
      final success = await SocialService().updatePost(_post.id, {'bodyHtml': updatedText});
      if (success && mounted) {
        setState(() => _post = _post.copyWith(bodyHtml: updatedText));
        widget.onPostUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật bài viết thành công.')),
        );
      }
    }
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String title,
    bool isDanger = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDanger ? const Color(0xFFDC2626) : const Color(0xFF475569),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: isDanger ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';

    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _buildReactionBadge() {
    String topReaction = 'like';
    int maxCount = -1;
    _post.reactionCounts.forEach((k, v) {
      if (v > maxCount) {
        maxCount = v;
        topReaction = k;
      }
    });

    Widget badgeIcon;
    if (topReaction == 'like') {
      badgeIcon = Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: Color(0xFF2563EB),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.thumb_up, size: 9, color: Colors.white),
      );
    } else if (topReaction == 'love') {
      badgeIcon = Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.favorite, size: 10, color: Colors.white),
      );
    } else {
      final emoji = switch (topReaction) {
        'haha' => '😂',
        'wow' => '😮',
        'sad' => '😢',
        'angry' => '😡',
        _ => '👍',
      };
      badgeIcon = Text(emoji, style: const TextStyle(fontSize: 13));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badgeIcon,
        const SizedBox(width: 5),
        Text(
          '${_post.reactionTotal}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildLikeButton() {
    final myReaction = _post.myReaction;
    Widget iconWidget;
    String label = 'Thích';
    Color textColor = const Color(0xFF64748B);
    FontWeight fontWeight = FontWeight.w500;

    if (myReaction == null) {
      iconWidget = const Icon(
        Icons.thumb_up_alt_outlined,
        size: 17,
        color: Color(0xFF64748B),
      );
    } else if (myReaction == 'like') {
      iconWidget = const Icon(
        Icons.thumb_up_rounded,
        size: 17,
        color: Color(0xFF2563EB),
      );
      label = 'Thích';
      textColor = const Color(0xFF2563EB);
      fontWeight = FontWeight.w600;
    } else {
      final (emoji, l, color) = switch (myReaction) {
        'love' => ('❤️', 'Yêu thích', const Color(0xFFEF4444)),
        'haha' => ('😂', 'Haha', const Color(0xFFF59E0B)),
        'wow' => ('😮', 'Wow', const Color(0xFFF59E0B)),
        'sad' => ('😢', 'Buồn', const Color(0xFFF59E0B)),
        'angry' => ('😡', 'Phẫn nộ', const Color(0xFFEA580C)),
        _ => ('👍', 'Thích', const Color(0xFF2563EB)),
      };
      iconWidget = Text(emoji, style: const TextStyle(fontSize: 16));
      label = l;
      textColor = color;
      fontWeight = FontWeight.w600;
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleLike(),
        onLongPressStart: (details) => _showReactionPicker(context, details.globalPosition),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: fontWeight,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = _post.author;
    final topic = _post.topic ?? (_post.topics.isNotEmpty ? _post.topics.first : null);
    final cleanText = _stripHtml(_post.bodyHtml);
    final isLongText = cleanText.length > 250;
    final displayText = (!isLongText || _isExpanded)
        ? cleanText
        : '${cleanText.substring(0, 240)}...';


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Unit, Time, Menu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SocialUserAvatar(
                  user: author,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              author.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_post.pinned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.push_pin, size: 10, color: Color(0xFFD97706)),
                                  SizedBox(width: 2),
                                  Text(
                                    'Đã ghim',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (author.position != null && author.position!.isNotEmpty) author.position!,
                          if (author.unitName != null && author.unitName!.isNotEmpty) author.unitName!,
                          _formatTime(_post.publishedAt),
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8), size: 20),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  color: Colors.white,
                  elevation: 6,
                  offset: const Offset(0, 32),
                  onSelected: _handleMenuAction,
                  itemBuilder: (ctx) {
                    final items = <PopupMenuEntry<String>>[];

                    // 1. Xem chi tiết (luôn có)
                    items.add(_buildMenuItem(
                      value: 'detail',
                      icon: Icons.remove_red_eye_outlined,
                      title: 'Xem chi tiết',
                    ));

                    // 2. Ghim bài viết (khi canPin)
                    if (_post.canPin) {
                      items.add(_buildMenuItem(
                        value: 'pin',
                        icon: Icons.push_pin_outlined,
                        title: _post.pinned ? 'Bỏ ghim bài viết' : 'Ghim bài viết',
                      ));
                    }

                    // 3. Tắt/Bật tính năng bình luận (khi canToggleComments)
                    if (_post.canToggleComments) {
                      items.add(_buildMenuItem(
                        value: 'toggle_comments',
                        icon: _post.commentsDisabled
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.comments_disabled_outlined,
                        title: _post.commentsDisabled ? 'Bật tính năng bình luận' : 'Tắt tính năng bình luận',
                      ));
                    }

                    // 4. Sửa bài viết (khi canEdit và activity == null)
                    if (_post.canEdit && _post.activity == null) {
                      items.add(_buildMenuItem(
                        value: 'edit',
                        icon: Icons.edit_outlined,
                        title: 'Sửa bài viết',
                      ));
                    }

                    // 5. Xóa bài viết (khi canDelete)
                    if (_post.canDelete) {
                      items.add(_buildMenuItem(
                        value: 'delete',
                        icon: Icons.delete_outline_rounded,
                        title: 'Xóa bài viết',
                        isDanger: true,
                      ));
                    }

                    return items;
                  },
                ),
              ],
            ),
          ),

          // Topic / Category badge (if present)
          if (topic != null && topic.name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  topic.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),

          // Title (if present)
          if (_post.title != null && _post.title!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
              child: Text(
                _post.title!.trim(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  height: 1.35,
                ),
              ),
            ),

          // Activity (e.g. "Cao Khánh Ngọc đã cập nhật ảnh đại diện")
          if (_post.activity != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF0F172A),
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: author.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' ${_post.activity!.label}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_post.activity!.type == 'avatar.updated' &&
                      author.avatarUrl != null &&
                      author.avatarUrl!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      child: SocialUserAvatar(
                        user: author,
                        radius: 28,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Post Body
          if (cleanText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayText,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF334155),
                      height: 1.45,
                    ),
                  ),
                  if (isLongText)
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isExpanded ? 'Thu gọn' : 'Xem thêm',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Image / Media attachments
          if (_post.attachments.isNotEmpty)
            _buildAttachmentsGrid(_post.attachments),

          // Reaction & Comments Summary Bar
          if (_post.reactionTotal > 0 || _post.commentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Row(
                children: [
                  if (_post.reactionTotal > 0) ...[
                    _buildReactionBadge(),
                  ],
                  const Spacer(),
                  if (_post.commentCount > 0)
                    GestureDetector(
                      onTap: widget.onCommentTap,
                      child: Text(
                        '${_post.commentCount} bình luận',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                ],
              ),
            ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // Actions Row: Thích | Bình luận | Lưu bài
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                _buildLikeButton(),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: widget.onCommentTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 17,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Bình luận',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _toggleBookmark,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _post.bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 18,
                            color: _post.bookmarked ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _post.bookmarked ? 'Đã lưu' : 'Lưu bài',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _post.bookmarked ? FontWeight.w600 : FontWeight.w500,
                              color: _post.bookmarked ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _resolveUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) return rawUrl;
    final base = AuthProvider.authBaseUrl;
    final clean = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return '$base$clean';
  }

  Map<String, String> _getHeaders() {
    final cookies = AuthProvider.instance?.cookies;
    if (cookies != null && cookies.isNotEmpty) {
      return {'cookie': cookies};
    }
    return const {};
  }

  Widget _buildAttachmentsGrid(List<SocialAttachment> attachments) {
    final videos = attachments.where((a) => a.isVideo && (a.url != null || a.posterUrl != null)).toList();
    final images = attachments.where((a) => a.isImage && a.url != null).toList();

    if (videos.isEmpty && images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Video Attachments
        if (videos.isNotEmpty)
          ...videos.map((v) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SocialVideoPlayer(attachment: v),
              )),

        // 2. Image Attachments
        if (images.isNotEmpty)
          _buildImagesGrid(images),
      ],
    );
  }

  Widget _buildImagesGrid(List<SocialAttachment> images) {
    if (images.length == 1) {
      final imgUrl = _resolveUrl(images.first.url);
      return Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxHeight: 280),
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
        ),
        child: Image.network(
          imgUrl,
          fit: BoxFit.cover,
          headers: _getHeaders(),
          errorBuilder: (_, error, stackTrace) => Container(
            height: 180,
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: Icon(Icons.broken_image, color: Color(0xFF94A3B8)),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: images.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final imgUrl = _resolveUrl(images[index].url);
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imgUrl,
              width: 220,
              height: 180,
              fit: BoxFit.cover,
              headers: _getHeaders(),
              errorBuilder: (_, error, stackTrace) => Container(
                width: 220,
                color: const Color(0xFFF1F5F9),
                child: const Icon(Icons.broken_image, color: Color(0xFF94A3B8)),
              ),
            ),
          );
        },
      ),
    );
  }
}
