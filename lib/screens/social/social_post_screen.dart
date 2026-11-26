import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n.dart';
import '../../models/social_models.dart';
import '../../services/social_service.dart';
import 'components/social_comments_sheet.dart';
import 'components/social_post_card.dart';

/// Một bài viết mở từ thông báo (web `/modules/social/posts/<id>[/comments/<id>]`): hiện bài, có link bình luận thì
/// mở luôn khung bình luận.
class SocialPostScreen extends StatefulWidget {
  final String postId;
  final bool openComments;

  const SocialPostScreen({super.key, required this.postId, this.openComments = false});

  @override
  State<SocialPostScreen> createState() => _SocialPostScreenState();
}

class _SocialPostScreenState extends State<SocialPostScreen> {
  SocialPost? _post;
  bool _loading = true;
  bool _commentsOpened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final post = await SocialService().getPost(widget.postId);
    if (!mounted) return;
    setState(() {
      _post = post;
      _loading = false;
    });
    if (post != null && widget.openComments && !_commentsOpened) {
      _commentsOpened = true;
      _openComments(post);
    }
  }

  void _openComments(SocialPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SocialCommentsSheet(post: post, onCommentCountChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      appBar: AppBar(title: Text('home_shell.nav.social'.tr())),
      body: _loading && post == null
          ? const Center(child: CircularProgressIndicator())
          : post == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('social.post_unavailable'.tr(), textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      SocialPostCard(
                        key: ValueKey(post.id),
                        post: post,
                        onPostUpdated: _load,
                        onPostDeleted: () => Navigator.of(context).maybePop(),
                        onCommentTap: () => _openComments(post),
                      ),
                    ],
                  ),
                ),
    );
  }
}
