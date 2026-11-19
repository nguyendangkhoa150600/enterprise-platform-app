import 'package:flutter/material.dart';
import '../../../models/social_models.dart';
import '../../../providers/auth_provider.dart';
import 'social_user_avatar.dart';

class SocialNavDrawer extends StatelessWidget {
  final String activeSection; // 'feed', 'wall', 'pending', 'groups', 'scheduled'
  final String? selectedTopicId;
  final List<SocialTopic> topics;
  final Function(String section) onSectionSelected;
  final Function(String? topicId) onTopicSelected;

  const SocialNavDrawer({
    super.key,
    required this.activeSection,
    this.selectedTopicId,
    required this.topics,
    required this.onSectionSelected,
    required this.onTopicSelected,
  });

  @override
  Widget build(BuildContext context) {
    final auth = AuthProvider.instance;
    final userName = auth?.fullName ?? 'Nhân sự';
    final userRef = SocialUserRef(
      id: auth?.userId ?? '',
      name: userName,
    );

    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 1. User Profile Card (Matching Web 1:1)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 48, 14, 14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blue curved banner
                  Container(
                    height: 55,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDBEAFE), Color(0xFFEFF6FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                  ),

                  // Avatar & User Info
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -24),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: SocialUserAvatar(
                              user: userRef,
                              radius: 26,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Thành viên · Doanh nghiệp Savina',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  onSectionSelected('profile');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Trang cá nhân',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.blue[600]),
                                    ],
                                  ),
                                ),
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

            // 2. Navigation Menu Box (Matching Web 1:1)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildNavItem(
                    title: 'Bảng tin',
                    section: 'feed',
                    icon: Icons.dynamic_feed_rounded,
                    context: context,
                  ),
                  _buildNavItem(
                    title: 'Tường công ty',
                    section: 'wall',
                    icon: Icons.apartment_rounded,
                    context: context,
                  ),
                  _buildNavItem(
                    title: 'Bài viết chờ duyệt',
                    section: 'pending',
                    icon: Icons.hourglass_top_rounded,
                    context: context,
                  ),
                  _buildNavItem(
                    title: 'Nhóm, thảo luận',
                    section: 'groups',
                    icon: Icons.groups_rounded,
                    context: context,
                  ),
                  _buildNavItem(
                    title: 'Bài viết hẹn giờ',
                    section: 'scheduled',
                    icon: Icons.schedule_rounded,
                    context: context,
                  ),
                  _buildNavItem(
                    title: 'Bài viết đã lưu',
                    section: 'saved',
                    icon: Icons.bookmark_border_rounded,
                    context: context,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. Chuyên mục (Categories Section Matching Web 1:1)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.segment_rounded, size: 18, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        const Text(
                          'Chuyên mục',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // "Tất cả" item
                  _buildTopicItem(
                    title: 'Tất cả',
                    isSelected: selectedTopicId == null,
                    count: null,
                    onTap: () {
                      Navigator.pop(context);
                      onTopicSelected(null);
                    },
                  ),

                  // Topics list
                  ...topics.map((t) => _buildTopicItem(
                        title: t.name,
                        isSelected: selectedTopicId == t.id,
                        count: t.postCount,
                        onTap: () {
                          Navigator.pop(context);
                          onTopicSelected(t.id);
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String title,
    required String section,
    required IconData icon,
    required BuildContext context,
  }) {
    final isSelected = activeSection == section;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFEF9C3) : Colors.transparent, // Cream yellow on active
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        leading: Icon(
          icon,
          size: 19,
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          onSectionSelected(section);
        },
      ),
    );
  }

  Widget _buildTopicItem({
    required String title,
    required bool isSelected,
    required int? count,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFEF9C3) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        dense: true,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
          ),
        ),
        trailing: count != null
            ? Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

