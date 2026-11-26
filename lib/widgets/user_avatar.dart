import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../services/api_client_helper.dart';

/// Danh bạ người dùng của công ty để biết ai có ảnh đại diện (web `people-directory`: `GET /api/platform/v1/people`,
/// làm mới sau 5 phút; nhiều nơi gọi cùng lúc chỉ tạo một lời gọi; lỗi thì giữ bản cũ).
class PeopleAvatarDirectory extends ChangeNotifier {
  PeopleAvatarDirectory._() {
    ApiClientHelper.configureDio(_dio);
  }
  static final PeopleAvatarDirectory instance = PeopleAvatarDirectory._();

  static const Duration _refresh = Duration(minutes: 5);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  /// userId (chữ thường) → phiên bản ảnh; null là chưa có ảnh.
  final Map<String, int?> _versions = {};
  final Map<String, String> _names = {};
  DateTime? _loadedAt;
  Future<void>? _loading;

  bool get loaded => _loadedAt != null;

  /// Phiên bản ảnh của [userId]; null khi chưa có ảnh hoặc chưa biết.
  int? versionOf(String userId) => _versions[userId.toLowerCase()];

  /// Tên trong danh bạ (dùng khi nơi gọi không có sẵn tên).
  String? nameOf(String userId) => _names[userId.toLowerCase()];

  Future<void> ensure({bool force = false}) {
    final at = _loadedAt;
    if (!force && at != null && DateTime.now().difference(at) < _refresh) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get('/api/platform/v1/people', options: Options(validateStatus: (s) => s != null && s < 500));
      final data = res.data;
      final people = data is Map ? data['people'] : null;
      if (res.statusCode != 200 || people is! List) return;
      _versions.clear();
      _names.clear();
      for (final p in people) {
        if (p is! Map) continue;
        final id = p['id']?.toString().toLowerCase() ?? '';
        if (id.isEmpty) continue;
        final v = p['avatarVersion'];
        _versions[id] = v is num ? v.toInt() : null;
        final name = p['fullName']?.toString() ?? '';
        if (name.isNotEmpty) _names[id] = name;
      }
      _loadedAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Mất mạng / phiên hết hạn: giữ bản cũ, ảnh đại diện hiện chữ viết tắt.
    }
  }

  /// Sau khi người dùng đổi ảnh của chính mình (web `setPersonAvatarVersion`).
  void setVersion(String userId, int? version) {
    _versions[userId.toLowerCase()] = version;
    notifyListeners();
  }

  /// Đăng xuất / đổi công ty.
  void reset() {
    _versions.clear();
    _names.clear();
    _loadedAt = null;
    notifyListeners();
  }
}

/// Web `initialsOf`: một từ thì 2 chữ đầu, nhiều từ thì chữ đầu của từ đầu và từ cuối.
String userInitials(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

/// Web `pastelAvatarStyle`: màu pastel cố định theo tài khoản (nền, chữ).
(Color, Color) pastelAvatarColors(String seed) {
  var hash = 0;
  for (final c in seed.codeUnits) {
    hash = (hash * 31 + c) & 0xFFFFFFFF;
  }
  final hue = (hash % 360).toDouble();
  return (
    HSLColor.fromAHSL(1, hue, 0.75, 0.90).toColor(),
    HSLColor.fromAHSL(1, hue, 0.45, 0.32).toColor(),
  );
}

/// Ảnh đại diện dùng chung toàn ứng dụng (web `UserAvatar`): ảnh người dùng tải lên ở "Tài khoản của tôi"
/// (`/api/platform/v1/users/:id/avatar?v=`); chưa có ảnh hoặc ảnh lỗi thì hiện chữ viết tắt trên nền pastel.
/// [background]/[foreground] ghi đè màu chữ viết tắt khi màn đã có quy ước màu riêng.
class UserAvatar extends StatefulWidget {
  final String? userId;
  final String? name;
  final double size;
  final Color? background;
  final Color? foreground;
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.userId,
    this.name,
    this.size = 32,
    this.background,
    this.foreground,
    this.fontSize,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  final PeopleAvatarDirectory _dir = PeopleAvatarDirectory.instance;
  String? _failedUrl;

  @override
  void initState() {
    super.initState();
    _dir.addListener(_onDirectory);
    if ((widget.userId ?? '').isNotEmpty) unawaited(_dir.ensure());
  }

  @override
  void dispose() {
    _dir.removeListener(_onDirectory);
    super.dispose();
  }

  void _onDirectory() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.userId ?? '';
    final name = (widget.name ?? '').trim().isNotEmpty ? widget.name : (id.isEmpty ? null : _dir.nameOf(id));
    final version = id.isEmpty ? null : _dir.versionOf(id);
    final url = version == null
        ? null
        : '${AuthProvider.authBaseUrl}/api/platform/v1/users/${Uri.encodeComponent(id)}/avatar?v=$version';
    final size = widget.size;
    final pastel = pastelAvatarColors(id.isNotEmpty ? id : (name ?? 'user'));
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.background ?? pastel.$1),
      child: Text(
        userInitials(name),
        style: TextStyle(
          fontSize: widget.fontSize ?? size * 0.36,
          fontWeight: FontWeight.w700,
          color: widget.foreground ?? pastel.$2,
        ),
      ),
    );
    if (url == null || url == _failedUrl) return fallback;
    final cookies = AuthProvider.instance?.cookies;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        headers: cookies == null || cookies.isEmpty ? null : {'cookie': cookies},
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _failedUrl != url) setState(() => _failedUrl = url);
          });
          return fallback;
        },
        frameBuilder: (_, child, frame, sync) => frame == null && !sync ? fallback : child,
      ),
    );
  }
}
