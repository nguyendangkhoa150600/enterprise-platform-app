import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_models.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<NotificationRecord> _notifications = [];
  NotificationSummary _summary = NotificationSummary();
  List<NotificationPreference> _preferences = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  List<NotificationRecord> get notifications => _notifications;
  NotificationSummary get summary => _summary;
  int get unreadCount => _summary.unreadCount;
  List<NotificationPreference> get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  NotificationProvider() {
    _init();
  }

  void _init() {
    refresh();
    _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _fetchSummarySilently();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getNotifications(limit: 50),
        _service.getSummary(),
        _service.getPreferences(),
      ]);

      _notifications = results[0] as List<NotificationRecord>;
      _summary = results[1] as NotificationSummary;
      _preferences = results[2] as List<NotificationPreference>;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchSummarySilently() async {
    try {
      final newSummary = await _service.getSummary();
      if (newSummary.unreadCount != _summary.unreadCount ||
          newSummary.lastSequence != _summary.lastSequence) {
        _summary = newSummary;
        final latestList = await _service.getNotifications(limit: 50);
        _notifications = latestList;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAsRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1 && !_notifications[idx].isRead) {
      final item = _notifications[idx];
      _notifications[idx] = NotificationRecord(
        id: item.id,
        module: item.module,
        category: item.category,
        priority: item.priority,
        title: item.title,
        body: item.body,
        deepLink: item.deepLink,
        sourceType: item.sourceType,
        sourceId: item.sourceId,
        aggregateCount: item.aggregateCount,
        readAt: DateTime.now().toIso8601String(),
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        sequence: item.sequence,
      );
      _summary = NotificationSummary(
        unreadCount: (_summary.unreadCount > 0) ? _summary.unreadCount - 1 : 0,
        lastSequence: _summary.lastSequence,
      );
      notifyListeners();

      await _service.setRead(notificationId, true);
    }
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) {
      if (n.isRead) return n;
      return NotificationRecord(
        id: n.id,
        module: n.module,
        category: n.category,
        priority: n.priority,
        title: n.title,
        body: n.body,
        deepLink: n.deepLink,
        sourceType: n.sourceType,
        sourceId: n.sourceId,
        aggregateCount: n.aggregateCount,
        readAt: DateTime.now().toIso8601String(),
        createdAt: n.createdAt,
        updatedAt: n.updatedAt,
        sequence: n.sequence,
      );
    }).toList();

    _summary = NotificationSummary(unreadCount: 0, lastSequence: _summary.lastSequence);
    notifyListeners();

    await _service.readAll();
  }

  Future<void> savePreferences(List<NotificationPreference> newPrefs) async {
    _preferences = newPrefs;
    notifyListeners();
    await _service.setPreferences(newPrefs);
  }
}
