import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_models.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

class NotificationService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  NotificationService() {
    ApiClientHelper.configureDio(_dio);
  }

  // 1. Get Notification List
  Future<List<NotificationRecord>> getNotifications({
    String? cursor,
    int? limit,
    bool? unread,
    NotificationModule? module,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (cursor != null && cursor.isNotEmpty) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit;
      if (unread != null) queryParams['unread'] = unread;
      if (module != null) queryParams['module'] = module.name;

      final response = await _dio.get(
        '/realtime/v1/notifications',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data['items'] ?? response.data['data'] ?? response.data;
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map((item) => NotificationRecord.fromJson(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] getNotifications error: $e');
    }
    return [];
  }

  // 2. Get Notification Summary (Unread count)
  Future<NotificationSummary> getSummary() async {
    try {
      final response = await _dio.get('/realtime/v1/summary');
      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data['data'] ?? response.data;
        if (raw is Map<String, dynamic>) {
          return NotificationSummary.fromJson(raw);
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] getSummary error: $e');
    }
    return NotificationSummary(unreadCount: 0, lastSequence: 0);
  }

  // 3. Mark single notification as read / unread
  Future<bool> setRead(String id, bool read) async {
    try {
      final response = await _dio.patch(
        '/realtime/v1/notifications/$id',
        data: {'read': read},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[NotificationService] setRead error: $e');
      return false;
    }
  }

  // 4. Mark all notifications as read
  Future<bool> readAll() async {
    try {
      final response = await _dio.post('/realtime/v1/notifications/read-all');
      return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[NotificationService] readAll error: $e');
      return false;
    }
  }

  // 5. Get Notification Preferences
  Future<List<NotificationPreference>> getPreferences() async {
    try {
      final response = await _dio.get('/realtime/v1/preferences');
      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data['data'] ?? response.data;
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map((item) => NotificationPreference.fromJson(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] getPreferences error: $e');
    }
    return [];
  }

  // 6. Update Notification Preferences
  Future<bool> setPreferences(List<NotificationPreference> preferences) async {
    try {
      final response = await _dio.put(
        '/realtime/v1/preferences',
        data: {
          'preferences': preferences.map((p) => p.toJson()).toList(),
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[NotificationService] setPreferences error: $e');
      return false;
    }
  }
}
