import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  ChatService._internal() {
    ApiClientHelper.configureDio(_dio);
  }

  /// Lấy danh sách cuộc trò chuyện nội bộ
  Future<List<ChatConversation>> getConversations() async {
    try {
      final res = await _dio.get('/api/platform/v1/chat/conversations');
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['items'] ?? res.data['data'] ?? res.data;
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map((c) => ChatConversation.fromJson(c))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[ChatService] getConversations error: $e');
    }
    return [];
  }

  /// Lấy tổng số tin nhắn chưa đọc
  Future<int> getUnreadCount() async {
    try {
      final res = await _dio.get('/api/platform/v1/chat/unread');
      if (res.statusCode == 200 && res.data != null) {
        final total = res.data['unreadTotal'] ?? res.data['total'] ?? res.data['unreadCount'];
        if (total is int) return total;
        if (total is num) return total.toInt();
      }
    } catch (e) {
      debugPrint('[ChatService] getUnreadCount error: $e');
    }
    return 0;
  }

  /// Lấy danh sách tin nhắn của một cuộc hội thoại
  Future<List<ChatMessage>> getMessages(String conversationId, {String? before}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (before != null && before.isNotEmpty) {
        queryParams['before'] = before;
      }
      final res = await _dio.get(
        '/api/platform/v1/chat/conversations/${Uri.encodeComponent(conversationId)}/messages',
        queryParameters: queryParams,
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['messages'] ?? res.data['data'] ?? res.data;
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map((m) => ChatMessage.fromJson(m))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[ChatService] getMessages error on $conversationId: $e');
    }
    return [];
  }

  /// Gửi tin nhắn mới
  Future<ChatMessage?> sendMessage(
    String conversationId,
    String body, {
    List<String> mentions = const [],
    String? replyToId,
  }) async {
    try {
      final res = await _dio.post(
        '/api/platform/v1/chat/conversations/${Uri.encodeComponent(conversationId)}/messages',
        data: {
          'body': body.trim(),
          if (mentions.isNotEmpty) 'mentions': mentions,
          if (replyToId != null) 'replyToId': replyToId,
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final raw = res.data['message'] ?? res.data;
        if (raw is Map<String, dynamic>) {
          return ChatMessage.fromJson(raw);
        }
      }
    } catch (e) {
      debugPrint('[ChatService] sendMessage error: $e');
    }
    return null;
  }

  /// Đánh dấu đã đọc tin nhắn
  Future<void> markRead(String conversationId, String messageId) async {
    try {
      await _dio.post(
        '/api/platform/v1/chat/conversations/${Uri.encodeComponent(conversationId)}/read',
        data: {'messageId': messageId},
      );
    } catch (e) {
      debugPrint('[ChatService] markRead error: $e');
    }
  }

  /// Thu hồi tin nhắn
  Future<bool> recallMessage(String messageId) async {
    try {
      final res = await _dio.delete(
        '/api/platform/v1/chat/messages/${Uri.encodeComponent(messageId)}',
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[ChatService] recallMessage error: $e');
      return false;
    }
  }

  /// Chỉnh sửa nội dung tin nhắn
  Future<ChatMessage?> editMessage(
    String messageId,
    String body, {
    List<String> mentions = const [],
  }) async {
    try {
      final res = await _dio.patch(
        '/api/platform/v1/chat/messages/${Uri.encodeComponent(messageId)}',
        data: {
          'body': body.trim(),
          if (mentions.isNotEmpty) 'mentions': mentions,
        },
      );
      if (res.statusCode == 200 && res.data != null) {
        if (res.data is Map<String, dynamic>) {
          return ChatMessage.fromJson(res.data as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[ChatService] editMessage error: $e');
    }
    return null;
  }

  /// Thả cảm xúc / reaction vào tin nhắn ('love', 'haha', 'wow', 'sad', 'angry', 'like', hoặc null để gỡ)
  Future<ChatMessage?> reactToMessage(String messageId, String? reaction) async {
    try {
      final res = await _dio.put(
        '/api/platform/v1/chat/messages/${Uri.encodeComponent(messageId)}/reaction',
        data: {'reaction': reaction},
      );
      if (res.statusCode == 200 && res.data != null) {
        if (res.data is Map<String, dynamic>) {
          return ChatMessage.fromJson(res.data as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[ChatService] reactToMessage error: $e');
    }
    return null;
  }

  /// Lấy danh bạ người dùng toàn công ty
  Future<List<ChatPerson>> getPeopleDirectory() async {
    try {
      final res = await _dio.get('/api/platform/v1/people');
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['people'] ?? res.data['data'] ?? res.data;
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map((p) => ChatPerson.fromJson(p))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[ChatService] getPeopleDirectory error: $e');
    }
    return [];
  }

  /// Khởi tạo hoặc lấy cuộc trò chuyện trực tiếp 1-1 với một người
  Future<ChatConversation?> createDirectChat(String userId) async {
    try {
      final res = await _dio.post(
        '/api/platform/v1/chat/conversations/direct',
        data: {'userId': userId},
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (res.data is Map<String, dynamic>) {
          return ChatConversation.fromJson(res.data as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[ChatService] createDirectChat error: $e');
    }
    return null;
  }

  /// Tạo nhóm chat mới
  Future<ChatConversation?> createGroupChat(String title, List<String> memberIds) async {
    try {
      final res = await _dio.post(
        '/api/platform/v1/chat/conversations/group',
        data: {
          'title': title.trim(),
          'memberIds': memberIds,
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (res.data is Map<String, dynamic>) {
          return ChatConversation.fromJson(res.data as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[ChatService] createGroupChat error: $e');
    }
    return null;
  }
}

