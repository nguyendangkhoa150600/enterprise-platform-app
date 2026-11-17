import 'package:flutter/material.dart';
import '../../../models/social_models.dart';
import '../../../providers/auth_provider.dart';

class SocialUserAvatar extends StatelessWidget {
  final SocialUserRef user;
  final double radius;

  const SocialUserAvatar({
    super.key,
    required this.user,
    this.radius = 20,
  });

  String _resolveAvatarUrl() {
    final base = AuthProvider.authBaseUrl;
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      if (user.avatarUrl!.startsWith('http://') || user.avatarUrl!.startsWith('https://')) {
        return user.avatarUrl!;
      }
      final clean = user.avatarUrl!.startsWith('/') ? user.avatarUrl! : '/${user.avatarUrl!}';
      return '$base$clean';
    }
    if (user.id.isNotEmpty) {
      return '$base/api/platform/v1/users/${Uri.encodeComponent(user.id)}/avatar';
    }
    return '';
  }

  Map<String, String> _getHeaders() {
    final cookies = AuthProvider.instance?.cookies;
    if (cookies != null && cookies.isNotEmpty) {
      return {'cookie': cookies};
    }
    return const {};
  }

  Color _getBgColor(String name) {
    if (name.isEmpty) return const Color(0xFFF59E0B);
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    const colors = [
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _resolveAvatarUrl();
    final initials = user.name.trim().isNotEmpty
        ? user.name.trim().split(' ').last.substring(0, 1).toUpperCase()
        : 'U';
    final bgColor = _getBgColor(user.name);

    if (avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.75,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        headers: _getHeaders(),
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: radius * 2,
            height: radius * 2,
            color: const Color(0xFFF1F5F9),
            alignment: Alignment.center,
            child: SizedBox(
              width: radius,
              height: radius,
              child: const CircularProgressIndicator(strokeWidth: 1.5),
            ),
          );
        },
      ),
    );
  }
}

