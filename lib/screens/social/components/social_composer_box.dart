import 'package:flutter/material.dart';
import '../../../models/social_models.dart';
import 'social_user_avatar.dart';

class SocialComposerBox extends StatelessWidget {
  final SocialUserRef user;
  final VoidCallback onTap;
  final VoidCallback? onPhotoTap;
  final VoidCallback? onPollTap;
  final VoidCallback? onAnnouncementTap;

  const SocialComposerBox({
    super.key,
    required this.user,
    required this.onTap,
    this.onPhotoTap,
    this.onPollTap,
    this.onAnnouncementTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
        children: [
          Row(
            children: [
              SocialUserAvatar(
                user: user,
                radius: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Bạn đang nghĩ gì? Đăng bài viết mới',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                icon: Icons.image_outlined,
                color: const Color(0xFF10B981),
                label: 'Ảnh/Video/File',
                onTap: onPhotoTap ?? onTap,
              ),
              _buildActionButton(
                icon: Icons.poll_outlined,
                color: const Color(0xFF3B82F6),
                label: 'Bình chọn',
                onTap: onPollTap ?? onTap,
              ),
              _buildActionButton(
                icon: Icons.campaign_outlined,
                color: const Color(0xFFF59E0B),
                label: 'Thông báo',
                onTap: onAnnouncementTap ?? onTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

