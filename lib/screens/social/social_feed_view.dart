import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../models/social_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/social_service.dart';
import 'components/social_composer_box.dart';
import 'components/social_user_avatar.dart';
import 'components/social_post_card.dart';
import 'components/social_comments_sheet.dart';
import 'components/social_create_post_sheet.dart';
import 'components/social_nav_drawer.dart';
import 'components/social_groups_view.dart';
import 'components/social_profile_view.dart';

class SocialFeedView extends StatefulWidget {
  /// Từ thông báo: mở sẵn bảng tin của nhóm này (web `/modules/social/groups/<id>`).
  final String? initialGroupId;

  /// Từ thông báo: mở sẵn mục này ('pending', 'groups'...) (web `/modules/social/pending`).
  final String? initialSection;

  const SocialFeedView({super.key, this.initialGroupId, this.initialSection});

  @override
  State<SocialFeedView> createState() => _SocialFeedViewState();
}

class _SocialFeedViewState extends State<SocialFeedView> with SingleTickerProviderStateMixin {
  final List<SocialPost> _posts = [];
  final List<SocialTopic> _topics = [];
  String _activeSection = 'feed'; // 'feed', 'wall', 'pending', 'groups', 'scheduled', 'saved', 'profile'
  String? _activeGroupId;
  String? _activeGroupName;
  String? _selectedTopicId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  SocialPersonProfile? _myProfile;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _nextCursor;
  final ScrollController _scrollController = ScrollController();

  // Collapsible Floating Header (Rule 5.4)
  AnimationController? _headerAnimController;
  Animation<Offset>? _headerSlideAnimation;
  bool _isHeaderVisible = true;

  void _ensureAnimation() {
    if (_headerAnimController == null) {
      _headerAnimController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 240),
        value: 1.0, // Hiển thị đầy đủ ban đầu
      );
      _headerSlideAnimation = Tween<Offset>(
        begin: const Offset(0, -1.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _headerAnimController!,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));
    }
  }

  void _showHeader() {
    _ensureAnimation();
    if (!_isHeaderVisible) {
      _isHeaderVisible = true;
      _headerAnimController?.forward();
    }
  }

  void _hideHeader() {
    _ensureAnimation();
    if (_isHeaderVisible) {
      _isHeaderVisible = false;
      _headerAnimController?.reverse();
    }
  }

  bool _handleScrollNotification(UserScrollNotification notification) {
    if (_searchFocusNode.hasFocus) {
      return false;
    }

    if (_scrollController.hasClients && _scrollController.offset <= 15) {
      _showHeader();
      return false;
    }

    if (notification.direction == ScrollDirection.reverse) {
      _hideHeader();
    } else if (notification.direction == ScrollDirection.forward) {
      _showHeader();
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _ensureAnimation();
    _scrollController.addListener(_onScroll);
    final groupId = widget.initialGroupId;
    final section = widget.initialSection;
    if (groupId != null && groupId.isNotEmpty) {
      _activeGroupId = groupId;
      _loadTopicsAndFeed();
      SocialService().getGroupName(groupId).then((name) {
        if (!mounted || name == null || _activeGroupId != groupId) return;
        setState(() => _activeGroupName = name);
      });
    } else if (section != null && section.isNotEmpty) {
      _activeSection = section;
      _loadTopicsAndFeed();
    } else {
      _loadTopicsAndFeed();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _headerAnimController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.offset <= 15) {
      _showHeader();
    }
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _nextCursor != null) {
        _loadMorePosts();
      }
    }
  }

  String? get _effectiveScope {
    if (_activeSection == 'wall') return 'wall';
    if (_activeSection == 'feed') return 'all';
    return null;
  }

  String? get _effectiveStatus {
    if (_activeSection == 'pending') return 'pending';
    if (_activeSection == 'scheduled') return 'scheduled';
    return null;
  }

  bool? get _effectiveBookmarked {
    return _activeSection == 'saved' ? true : null;
  }

  String? get _effectiveAuthorId {
    if (_activeSection == 'profile') {
      return AuthProvider.instance?.userId;
    }
    return null;
  }

  String get _sectionTitle {
    if (_activeGroupId != null) return _activeGroupName ?? 'Nhóm thảo luận';
    switch (_activeSection) {
      case 'wall':
        return 'Tường công ty';
      case 'pending':
        return 'Bài viết chờ duyệt';
      case 'groups':
        return 'Nhóm, thảo luận';
      case 'scheduled':
        return 'Bài viết hẹn giờ';
      case 'saved':
        return 'Bài viết đã lưu';
      case 'profile':
        return 'Trang cá nhân';
      default:
        return 'Mạng nội bộ';
    }
  }

  IconData get _sectionIcon {
    if (_activeGroupId != null) return Icons.groups_rounded;
    switch (_activeSection) {
      case 'wall':
        return Icons.apartment_rounded;
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'groups':
        return Icons.groups_rounded;
      case 'scheduled':
        return Icons.schedule_rounded;
      case 'saved':
        return Icons.bookmark_rounded;
      case 'profile':
        return Icons.person_pin_rounded;
      default:
        return Icons.newspaper_rounded;
    }
  }

  String get _emptyText {
    if (_activeGroupId != null) return 'Nhóm này chưa có bài viết nào.';
    switch (_activeSection) {
      case 'pending':
        return 'Không có bài viết nào đang chờ duyệt.';
      case 'scheduled':
        return 'Không có bài viết nào đang hẹn giờ.';
      case 'saved':
        return 'Bạn chưa lưu bài viết nào.';
      case 'profile':
        return 'Bạn chưa đăng bài viết nào.';
      case 'wall':
        return 'Chưa có thông báo nào trên Tường công ty.';
      default:
        return 'Chưa có bài viết nào.';
    }
  }

  Future<void> _loadTopicsAndFeed() async {
    setState(() => _isLoading = true);

    final topicsFuture = SocialService().getTopics();
    final feedFuture = SocialService().getFeed(
      topicId: _selectedTopicId,
      search: _searchQuery,
      scope: _effectiveScope,
      status: _effectiveStatus,
      bookmarked: _effectiveBookmarked,
      authorId: _effectiveAuthorId,
      groupId: _activeGroupId,
      limit: 15,
    );

    final results = await Future.wait([topicsFuture, feedFuture, _loadMyProfile()]);
    final topics = results[0] as List<SocialTopic>;
    final page = results[1] as SocialFeedPage;

    if (mounted) {
      setState(() {
        _topics.clear();
        _topics.addAll(topics);
        _posts.clear();
        _posts.addAll(page.items);
        _nextCursor = page.nextCursor;
        _isLoading = false;
      });
    }
  }

  Future<SocialPersonProfile?> _loadMyProfile() async {
    final uid = AuthProvider.instance?.userId;
    if (uid != null && uid.isNotEmpty) {
      final prof = await SocialService().getProfile(uid);
      if (mounted && prof != null) {
        setState(() => _myProfile = prof);
      }
      return prof;
    }
    return null;
  }

  Future<void> _loadFeedOnly({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);

    final page = await SocialService().getFeed(
      topicId: _selectedTopicId,
      search: _searchQuery,
      scope: _effectiveScope,
      status: _effectiveStatus,
      bookmarked: _effectiveBookmarked,
      authorId: _effectiveAuthorId,
      groupId: _activeGroupId,
      limit: 15,
    );

    if (mounted) {
      setState(() {
        _posts.clear();
        _posts.addAll(page.items);
        _nextCursor = page.nextCursor;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || _nextCursor == null) return;
    setState(() => _isLoadingMore = true);

    final page = await SocialService().getFeed(
      cursor: _nextCursor,
      topicId: _selectedTopicId,
      search: _searchQuery,
      scope: _effectiveScope,
      status: _effectiveStatus,
      bookmarked: _effectiveBookmarked,
      authorId: _effectiveAuthorId,
      groupId: _activeGroupId,
      limit: 15,
    );

    if (mounted) {
      setState(() {
        _posts.addAll(page.items);
        _nextCursor = page.nextCursor;
        _isLoadingMore = false;
      });
    }
  }

  void _onSectionSelected(String section) {
    setState(() {
      _activeSection = section;
      _activeGroupId = null;
      _activeGroupName = null;
      _selectedTopicId = null;
    });
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.jumpTo(0);
      _showHeader();
    }
    if (section != 'groups') {
      _loadFeedOnly();
    }
  }

  void _onGroupSelected(String groupId, String groupName) {
    setState(() {
      _activeSection = 'feed';
      _activeGroupId = groupId;
      _activeGroupName = groupName;
      _selectedTopicId = null;
    });
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.jumpTo(0);
      _showHeader();
    }
    _loadFeedOnly();
  }

  void _onTopicSelected(String? topicId) {
    setState(() {
      _selectedTopicId = topicId;
      if (_activeSection == 'groups') _activeSection = 'feed';
      _activeGroupId = null;
      _activeGroupName = null;
    });
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.jumpTo(0);
      _showHeader();
    }
    _loadFeedOnly();
  }

  void _onSearchSubmitted(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.jumpTo(0);
      _showHeader();
    }
    _loadFeedOnly();
  }

  void _openCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SocialCreatePostSheet(
        topics: _topics,
        onPostCreated: () => _loadFeedOnly(showLoading: false),
      ),
    );
  }

  void _openComments(SocialPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SocialCommentsSheet(
        post: post,
        onCommentCountChanged: () => _loadFeedOnly(showLoading: false),
      ),
    );
  }

  Widget _buildSectionBanner() {
    String? title;
    String? desc;
    IconData? icon;
    Color? color;

    if (_activeGroupId != null) {
      title = _activeGroupName ?? 'Nhóm thảo luận';
      desc = 'Bài viết và thảo luận thuộc nhóm này.';
      icon = Icons.groups_rounded;
      color = const Color(0xFF2563EB);
    } else {
      switch (_activeSection) {
        case 'wall':
          title = 'Tường công ty';
          desc = 'Nơi cập nhật thông báo, sự kiện và tin tức chính thức toàn doanh nghiệp.';
          icon = Icons.apartment_rounded;
          color = const Color(0xFF2563EB);
          break;
        case 'pending':
          title = 'Bài viết chờ duyệt';
          desc = 'Các bài viết bạn đã gửi đang chờ Người kiểm duyệt xem xét và phê duyệt.';
          icon = Icons.hourglass_top_rounded;
          color = const Color(0xFFD97706);
          break;
        case 'scheduled':
          title = 'Bài viết hẹn giờ';
          desc = 'Bài viết của bạn sẽ tự động đăng lên Bảng tin đúng thời gian đã hẹn.';
          icon = Icons.schedule_rounded;
          color = const Color(0xFF059669);
          break;
        case 'saved':
          title = 'Bài viết đã lưu';
          desc = 'Danh sách các bài viết bạn đã đánh dấu lưu để xem lại bất cứ lúc nào.';
          icon = Icons.bookmark_rounded;
          color = const Color(0xFF7C3AED);
          break;
        case 'profile':
          title = 'Trang cá nhân của bạn';
          desc = 'Xem và quản lý tất cả các bài viết do chính bạn đăng.';
          icon = Icons.person_pin_rounded;
          color = const Color(0xFF0284C7);
          break;
        default:
          return const SizedBox.shrink();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    if (_activeGroupId != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeGroupId = null;
                            _activeGroupName = null;
                          });
                          _loadFeedOnly();
                        },
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: SocialProfileView(
              userId: userId,
              onBack: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyProfileCard(AuthProvider auth, String userName) {
    final position = _myProfile?.position;
    final unit = _myProfile?.unitName;
    String subtitle = '';
    if (position != null && position.isNotEmpty && unit != null && unit.isNotEmpty) {
      subtitle = '$position · $unit';
    } else if (position != null && position.isNotEmpty) {
      subtitle = position;
    } else if (unit != null && unit.isNotEmpty) {
      subtitle = unit;
    } else if (auth.roles.isNotEmpty) {
      subtitle = auth.roles.first;
    }

    final postCount = _myProfile?.postCount ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top banner decoration matching web
            Container(
              height: 52,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDBEAFE), Color(0xFFEFF6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: SocialUserAvatar(
                        user: SocialUserRef(
                          id: auth.userId ?? '',
                          name: userName,
                          avatarUrl: _myProfile?.user.avatarUrl,
                        ),
                        radius: 28,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$postCount bài viết',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                if (auth.userId != null) {
                                  _openProfile(auth.userId!);
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                child: Text(
                                  'Trang cá nhân',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureAnimation();
    final auth = context.watch<AuthProvider>();
    final userName = auth.fullName ?? 'Bạn';
    final showComposer = _activeSection == 'feed' || _activeSection == 'wall';
    final showMyProfile = _activeSection == 'feed' && _selectedTopicId == null && _activeGroupId == null && _searchQuery.isEmpty;
    final topPadding = MediaQuery.of(context).padding.top + 146;

    final topWidgets = <Widget>[];
    final banner = _buildSectionBanner();
    if (banner is! SizedBox) {
      topWidgets.add(banner);
    }
    if (showMyProfile) {
      topWidgets.add(_buildMyProfileCard(auth, userName));
    }
    if (showComposer) {
      topWidgets.add(SocialComposerBox(
        user: SocialUserRef(
          id: auth.userId ?? '',
          name: userName,
          avatarUrl: _myProfile?.user.avatarUrl,
        ),
        onTap: _openCreatePost,
      ));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      endDrawer: SocialNavDrawer(
        activeSection: _activeSection,
        selectedTopicId: _selectedTopicId,
        topics: _topics,
        onSectionSelected: _onSectionSelected,
        onTopicSelected: _onTopicSelected,
      ),
      body: Stack(
        children: [
          // 1. Body Content
          if (_activeSection == 'groups')
            Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: SocialGroupsView(
                onGroupSelected: _onGroupSelected,
              ),
            )
          else if (_activeSection == 'profile')
            Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: SocialProfileView(
                userId: auth.userId ?? '',
                onBack: () {
                  setState(() {
                    _activeSection = 'feed';
                  });
                  _loadFeedOnly();
                },
              ),
            )
          else
            NotificationListener<UserScrollNotification>(
              onNotification: _handleScrollNotification,
              child: RefreshIndicator(
                edgeOffset: topPadding - 10,
                onRefresh: () => _loadFeedOnly(showLoading: false),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _posts.isEmpty
                        ? ListView(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(12, topPadding, 12, 80),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              ...topWidgets,
                              Container(
                                margin: const EdgeInsets.only(top: 40),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Icon(_sectionIcon, size: 48, color: const Color(0xFFCBD5E1)),
                                    const SizedBox(height: 12),
                                    Text(
                                      _emptyText,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(12, topPadding, 12, 80),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: topWidgets.length + _posts.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index < topWidgets.length) {
                                return topWidgets[index];
                              }

                              final postIndex = index - topWidgets.length;
                              if (postIndex < _posts.length) {
                                final post = _posts[postIndex];
                                return SocialPostCard(
                                  key: ValueKey(post.id),
                                  post: post,
                                  onPostUpdated: () => _loadFeedOnly(showLoading: false),
                                  onPostDeleted: () {
                                    setState(() {
                                      _posts.removeWhere((p) => p.id == post.id);
                                    });
                                  },
                                  onCommentTap: () => _openComments(post),
                                );
                              }

                              // Bottom loading indicator
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),

          // 2. Thanh công cụ tìm kiếm & chuyên mục nổi thu phóng theo hướng cuộn (Rule 5.4)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: SlideTransition(
                position: _headerSlideAnimation ?? const AlwaysStoppedAnimation(Offset.zero),
                child: AnimatedBuilder(
                  animation: _headerAnimController ?? const AlwaysStoppedAnimation(1.0),
                  builder: (context, child) {
                    return IgnorePointer(
                      ignoring: (_headerAnimController?.value ?? 1.0) == 0,
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top search & Header Bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (_activeSection != 'feed' || _activeGroupId != null) ...[
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back_rounded, size: 22, color: Color(0xFF1E293B)),
                                      onPressed: () {
                                        setState(() {
                                          _activeSection = 'feed';
                                          _activeGroupId = null;
                                          _activeGroupName = null;
                                        });
                                        _loadFeedOnly();
                                      },
                                      splashRadius: 20,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (_activeSection == 'feed' && _activeGroupId == null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        'assets/images/svn_logo.png',
                                        width: 26,
                                        height: 26,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            (auth.tenantSlug != null && auth.tenantSlug!.isNotEmpty)
                                                ? auth.tenantSlug!.toUpperCase()
                                                : 'SVN DTS',
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                              letterSpacing: -0.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const Text(
                                            'Mạng nội bộ',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    Icon(_sectionIcon, color: const Color(0xFF2563EB), size: 22),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _sectionTitle,
                                        style: const TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
                                    onPressed: () {
                                      if (_activeSection == 'groups') {
                                        setState(() {});
                                      } else {
                                        _loadFeedOnly();
                                      }
                                    },
                                    splashRadius: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                  const SizedBox(width: 4),
                                  Builder(
                                    builder: (btnCtx) => IconButton(
                                      icon: const Icon(Icons.menu_rounded, size: 24, color: Color(0xFF1E293B)),
                                      onPressed: () => Scaffold.of(btnCtx).openEndDrawer(),
                                      splashRadius: 20,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Search Input
                              Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: _onSearchSubmitted,
                                  decoration: InputDecoration(
                                    hintText: 'Tìm bài viết, người, nhóm...',
                                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                            onPressed: () {
                                              _searchController.clear();
                                              _onSearchSubmitted('');
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                                  ),
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Categories / Topics Horizontal Bar
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            itemCount: _topics.length + 1,
                            separatorBuilder: (_, index) => const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final isSelected = _selectedTopicId == null && _activeGroupId == null;
                                return ChoiceChip(
                                  label: const Text('Tất cả'),
                                  selected: isSelected,
                                  onSelected: (_) => _onTopicSelected(null),
                                  selectedColor: const Color(0xFFEFF6FF),
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  visualDensity: VisualDensity.compact,
                                );
                              }
                              final topic = _topics[index - 1];
                              final isSelected = _selectedTopicId == topic.id;
                              return ChoiceChip(
                                label: Text(topic.name),
                                selected: isSelected,
                                onSelected: (_) => _onTopicSelected(topic.id),
                                selectedColor: const Color(0xFFEFF6FF),
                                backgroundColor: const Color(0xFFF8FAFC),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                visualDensity: VisualDensity.compact,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
