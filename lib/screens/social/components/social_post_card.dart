import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> _toggleLike() async {
    if (_isReacting) return;
    setState(() => _isReacting = true);

    final isCurrentlyLiked = _post.myReaction != null;
    final newReaction = isCurrentlyLiked ? null : 'like';

    // Optimistic update
    final newCounts = Map<String, int>.from(_post.reactionCounts);
    int newTotal = _post.reactionTotal;

    if (isCurrentlyLiked) {
      final oldType = _post.myReaction!;
      newCounts[oldType] = (newCounts[oldType] ?? 1) - 1;
      if ((newCounts[oldType] ?? 0) <= 0) newCounts.remove(oldType);
      newTotal = (newTotal > 0) ? newTotal - 1 : 0;
    } else {
      newCounts['like'] = (newCounts['like'] ?? 0) + 1;
      newTotal += 1;
    }

    setState(() {
      _post = _post.copyWith(
        myReaction: newReaction,
        clearMyReaction: isCurrentlyLiked,
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

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Color(0xFF475569)),
              title: const Text('Sao chép nội dung bài viết'),
              onTap: () {
                Navigator.pop(ctx);
                final text = _stripHtml(_post.bodyHtml);
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép nội dung vào khay nhớ tạm.')),
                );
              },
            ),
            ListTile(
              leading: Icon(
                _post.bookmarked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
                color: const Color(0xFF475569),
              ),
              title: Text(_post.bookmarked ? 'Bỏ lưu bài viết' : 'Lưu bài viết'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleBookmark();
              },
            ),
            if (_post.canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Xoá bài viết', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Xác nhận xoá'),
                      content: const Text('Bạn có chắc muốn xoá bài viết này không?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Huỷ'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Xoá', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final deleted = await SocialService().deletePost(_post.id);
                    if (deleted) {
                      widget.onPostDeleted?.call();
                    }
                  }
                },
              ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final author = _post.author;
    final topic = _post.topic ?? (_post.topics.isNotEmpty ? _post.topics.first : null);
    final cleanText = _stripHtml(_post.bodyHtml);
    final isLongText = cleanText.length > 250;
    final displayText = (!isLongText || _isExpanded)
        ? cleanText
        : '${cleanText.substring(0, 240)}...';

    final isLiked = _post.myReaction != null;

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
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8), size: 20),
                  onPressed: _showOptionsMenu,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.thumb_up, size: 9, color: Colors.white),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_post.reactionTotal}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
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
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _toggleLike,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                            size: 17,
                            color: isLiked ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Thích',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isLiked ? FontWeight.w600 : FontWeight.w500,
                              color: isLiked ? const Color(0xFF2563EB) : const Color(0xFF64748B),
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
