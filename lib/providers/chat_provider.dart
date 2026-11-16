import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<ChatConversation> _conversations = [];
  List<ChatPerson> _people = [];
  PresenceSnapshot? _presence;
  int _unreadTotal = 0;
  bool _isLoading = false;
  Timer? _pollingTimer;

  List<ChatConversation> get conversations => _conversations;
  List<ChatPerson> get people => _people;
  PresenceSnapshot? get presence => _presence;
  int get unreadTotal => _unreadTotal;
  bool get isLoading => _isLoading;

  ChatProvider() {
    init();
  }

  void init() {
    loadUnreadCount();
    loadConversations();
    loadPeople();
    loadPresence();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      loadUnreadCount(notify: false);
      loadConversations(silent: true);
      loadPresence(silent: true);
      if (_people.isEmpty) {
        loadPeople();
      }
    });
  }

  /// Kiểm tra một người dùng có đang trực tuyến không
  bool isUserOnline(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return _presence?.onlineUserIds.contains(userId.toLowerCase()) ?? false;
  }

  /// Lấy mốc thời gian hoạt động cuối cùng của người dùng
  String? lastSeenOf(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return _presence?.lastSeen[userId.toLowerCase()];
  }

  /// Nhãn hiển thị trạng thái hoạt động đồng bộ 1:1 với Web React
  String formatLastSeen(String? lastSeenAt, {DateTime? now}) {
    if (lastSeenAt == null || lastSeenAt.isEmpty) return 'Ngoại tuyến';
    try {
      final parsed = DateTime.parse(lastSeenAt).toUtc();
      final current = (now ?? DateTime.now()).toUtc();
      final diffMinutes = current.difference(parsed).inMinutes;

      if (diffMinutes < 1) return 'Vừa mới hoạt động';
      if (diffMinutes < 60) return 'Hoạt động $diffMinutes phút trước';
      final diffHours = current.difference(parsed).inHours;
      if (diffHours < 24) return 'Hoạt động $diffHours giờ trước';
      final diffDays = current.difference(parsed).inDays;
      if (diffDays == 1) return 'Hoạt động hôm qua';
      if (diffDays < 30) return 'Hoạt động $diffDays ngày trước';
      return 'Ngoại tuyến';
    } catch (_) {
      return 'Ngoại tuyến';
    }
  }

  Future<void> loadPresence({bool silent = false}) async {
    final snapshot = await _chatService.getPresence();
    if (snapshot != null) {
      _presence = snapshot;
      notifyListeners();
    }
  }

  Future<void> loadUnreadCount({bool notify = true}) async {
    final count = await _chatService.getUnreadCount();
    if (_unreadTotal != count) {
      _unreadTotal = count;
      if (notify) notifyListeners();
    }
  }

  Future<void> loadConversations({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    if (_people.isEmpty) {
      await loadPeople();
    }
    final items = await _chatService.getConversations();
    _conversations = items;
    // Calculate unread sum if needed
    int sum = 0;
    for (final c in items) {
      sum += c.unreadCount;
    }
    if (sum > 0 || _unreadTotal == 0) {
      _unreadTotal = sum;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadPeople() async {
    final list = await _chatService.getPeopleDirectory();
    _people = list;
    notifyListeners();
  }

  void decrementUnread(int amount) {
    if (amount <= 0) return;
    _unreadTotal = (_unreadTotal - amount).clamp(0, 9999);
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

