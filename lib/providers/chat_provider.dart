import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<ChatConversation> _conversations = [];
  List<ChatPerson> _people = [];
  int _unreadTotal = 0;
  bool _isLoading = false;
  Timer? _pollingTimer;

  List<ChatConversation> get conversations => _conversations;
  List<ChatPerson> get people => _people;
  int get unreadTotal => _unreadTotal;
  bool get isLoading => _isLoading;

  ChatProvider() {
    init();
  }

  void init() {
    loadUnreadCount();
    loadConversations();
    loadPeople();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      loadUnreadCount(notify: false);
      loadConversations(silent: true);
    });
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

