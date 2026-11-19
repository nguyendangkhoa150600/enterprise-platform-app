import 'package:flutter/material.dart';
import '../../../models/social_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/social_service.dart';
import 'social_post_card.dart';
import 'social_user_avatar.dart';

class SocialProfileView extends StatefulWidget {
  final String userId;
  final VoidCallback? onBack;

  const SocialProfileView({
    super.key,
    required this.userId,
    this.onBack,
  });

  @override
  State<SocialProfileView> createState() => _SocialProfileViewState();
}

class _SocialProfileViewState extends State<SocialProfileView> {
  final SocialService _socialService = SocialService();
  bool _isLoadingProfile = true;
  SocialPersonProfile? _profile;

  int _selectedTab = 0; // 0: Bài viết, 1: Giới thiệu

  // Posts tab
  bool _isLoadingPosts = false;
  final List<SocialPost> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void didUpdateWidget(covariant SocialProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadProfileData();
    }
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoadingProfile = true);

    try {
      final res = await _socialService.getProfile(widget.userId);
      if (res != null) {
        _profile = res;
      } else {
        // Fallback to auth info if current user
        final auth = AuthProvider.instance;
        _profile = SocialPersonProfile(
          user: SocialUserRef(
            id: widget.userId,
            name: auth?.fullName ?? 'Người dùng',
          ),
          isSelf: true,
          email: auth?.email,
        );
      }
    } catch (_) {
      final auth = AuthProvider.instance;
      _profile = SocialPersonProfile(
        user: SocialUserRef(
          id: widget.userId,
          name: auth?.fullName ?? 'Người dùng',
        ),
        isSelf: true,
        email: auth?.email,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        _loadUserPosts();
      }
    }
  }

  Future<void> _loadUserPosts() async {
    setState(() => _isLoadingPosts = true);
    final feed = await _socialService.getFeed(authorId: widget.userId);
    if (!mounted) return;
    setState(() {
      _isLoadingPosts = false;
      _posts.clear();
      _posts.addAll(feed.items);
    });
  }

  String _formatDateString(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day/$month/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_rounded, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            const Text(
              'Không tìm thấy thông tin người này.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadProfileData,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    // Role & Unit subtitle
    final List<String> roleParts = [];
    if (profile.position != null && profile.position!.isNotEmpty) {
      roleParts.add(profile.position!);
    }
    if (profile.unitName != null && profile.unitName!.isNotEmpty) {
      roleParts.add(profile.unitName!);
    }
    final subtitle = roleParts.join(' · ');

    // Facts line
    final List<String> facts = [];
    if (profile.birthday != null && profile.birthday!.isNotEmpty) {
      facts.add('Sinh nhật ${profile.birthday}');
    }
    facts.add('${profile.postCount} bài viết');
    final factsLine = facts.join(' · ');

    return RefreshIndicator(
      onRefresh: () async {
        await _loadProfileData();
        await _loadUserPosts();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
        children: [
          // 1. Profile Header Card (1:1 with Web ERP)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar lớn
                SocialUserAvatar(
                  user: profile.user,
                  radius: 32,
                ),
                const SizedBox(width: 14),
                // Thông tin danh tính
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.user.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        factsLine,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Nút mở HRM nếu có quyền
                if (profile.canOpenInHrm)
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 20, color: Color(0xFF94A3B8)),
                    tooltip: 'Hồ sơ trong Nhân sự',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hồ sơ nhân sự chi tiết khả dụng trong phân hệ HRM'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Segmented Tabs: Bài viết | Giới thiệu (1:1 with Web ERP)
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  title: 'Bài viết',
                  index: 0,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  title: 'Giới thiệu',
                  index: 1,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Tab Content
          if (_selectedTab == 0) ...[
            // Tab 0: Bài viết
            if (_isLoadingPosts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_posts.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Chưa có bài viết nào.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              )
            else
              ..._posts.map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SocialPostCard(
                    key: ValueKey(post.id),
                    post: post,
                    onPostUpdated: () => _loadUserPosts(),
                    onPostDeleted: () {
                      setState(() {
                        _posts.removeWhere((p) => p.id == post.id);
                      });
                    },
                  ),
                ),
              ),
          ] else ...[
            // Tab 1: Giới thiệu (AboutPanel 1:1 with Web ERP)
            _buildAboutPanel(profile),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required int index,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        if (_selectedTab != index) {
          setState(() => _selectedTab = index);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutPanel(SocialPersonProfile profile) {
    final List<MapEntry<String, String>> rows = [
      MapEntry('Họ và tên', profile.user.name),
      MapEntry('Chức vụ', profile.position ?? '—'),
      MapEntry('Phòng ban', profile.unitName ?? '—'),
      MapEntry('Email', profile.email ?? '—'),
      MapEntry('Ngày sinh', profile.birthday ?? '—'),
      MapEntry('Ngày vào công ty', _formatDateString(profile.joinedAt)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isLast = index == rows.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        row.key,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
