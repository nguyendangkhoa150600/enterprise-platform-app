import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/social_models.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  SocialService._internal() {
    ApiClientHelper.configureDio(_dio);
  }

  /// Lấy danh sách bảng tin (hỗ trợ scope, search, status, bookmarked)
  Future<SocialFeedPage> getFeed({
    String? cursor,
    int? limit,
    String? topicId,
    String? kind,
    String? authorId,
    String? scope,
    String? groupId,
    String? status,
    bool? bookmarked,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (cursor != null && cursor.isNotEmpty) queryParams['cursor'] = cursor;
      if (limit != null && limit > 0) queryParams['limit'] = limit;
      if (topicId != null && topicId.isNotEmpty) queryParams['topicId'] = topicId;
      if (kind != null && kind.isNotEmpty) queryParams['kind'] = kind;
      if (authorId != null && authorId.isNotEmpty) queryParams['authorId'] = authorId;
      if (scope != null && scope.isNotEmpty) queryParams['scope'] = scope;
      if (groupId != null && groupId.isNotEmpty) queryParams['groupId'] = groupId;

      String path;
      if (search != null && search.trim().isNotEmpty) {
        path = '/api/social/v1/search?q=${Uri.encodeComponent(search.trim())}';
      } else if (status != null && status.isNotEmpty) {
        path = '/api/social/v1/me/posts?status=$status';
      } else if (bookmarked == true) {
        path = '/api/social/v1/bookmarks';
      } else {
        path = '/api/social/v1/feed';
      }

      final res = await _dio.get(path, queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        if (res.data is Map<String, dynamic>) {
          return SocialFeedPage.fromJson(res.data as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[SocialService] getFeed error: $e');
    }
    return const SocialFeedPage(items: []);
  }

  /// Lấy danh sách nhóm
  Future<List<SocialGroupSummary>> getGroups({String scope = 'all', String? query}) async {
    try {
      final queryParams = <String, dynamic>{
        'scope': scope,
        if (query != null && query.isNotEmpty) 'query': query,
      };
      final res = await _dio.get('/api/social/v1/groups', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['items'] ?? res.data['data'] ?? res.data;
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map((g) => SocialGroupSummary.fromJson(g))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SocialService] getGroups error: $e');
    }
    return [];
  }

  /// Tham gia nhóm
  Future<bool> joinGroup(String groupId) async {
    try {
      final res = await _dio.post('/api/social/v1/groups/$groupId/join');
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[SocialService] joinGroup error: $e');
      return false;
    }
  }

  /// Rời nhóm
  Future<bool> leaveGroup(String groupId) async {
    try {
      final res = await _dio.post('/api/social/v1/groups/$groupId/leave');
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[SocialService] leaveGroup error: $e');
      return false;
    }
  }

  /// Lấy danh sách chuyên mục
  Future<List<SocialTopic>> getTopics() async {
    try {
      final res = await _dio.get('/api/social/v1/topics');
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['items'] ?? res.data['data'] ?? res.data;
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map((t) => SocialTopic.fromJson(t))
              .where((t) => t.isActive)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SocialService] getTopics error: $e');
    }
    return [];
  }

  /// Thả phản ứng (like, love, haha...) hoặc gỡ phản ứng (type = null)
  Future<bool> setReaction(String postId, String? type) async {
    try {
      final res = await _dio.put(
        '/api/social/v1/posts/$postId/reaction',
        data: {'type': type},
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[SocialService] setReaction error: $e');
      return false;
    }
  }

  /// Lưu bài viết (Bookmark)
  Future<bool> setBookmark(String postId, bool bookmarked) async {
    try {
      final res = await _dio.put(
        '/api/social/v1/posts/$postId/bookmark',
        data: {'bookmarked': bookmarked},
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[SocialService] setBookmark error: $e');
      return false;
    }
  }

  /// Lấy bình luận của một bài viết
  Future<List<SocialComment>> getComments(String postId, {String? cursor, int? limit, String? parentId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (cursor != null && cursor.isNotEmpty) queryParams['cursor'] = cursor;
      if (limit != null && limit > 0) queryParams['limit'] = limit;
      if (parentId != null && parentId.isNotEmpty) queryParams['parentId'] = parentId;

      final res = await _dio.get('/api/social/v1/posts/$postId/comments', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data['items'] ?? res.data['data'] ?? res.data;
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map((c) => SocialComment.fromJson(c))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SocialService] getComments error: $e');
    }
    return [];
  }

  /// Gửi bình luận
  Future<SocialComment?> createComment(String postId, String content, {String? parentId}) async {
    try {
      final res = await _dio.post(
        '/api/social/v1/posts/$postId/comments',
        data: {
          'content': content.trim(),
          if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
        },
      );
      if ((res.statusCode == 200 || res.statusCode == 201) && res.data != null) {
        if (res.data is Map<String, dynamic>) {
          return SocialComment.fromJson(res.data as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[SocialService] createComment error: $e');
    }
    return null;
  }

  /// Xoá bình luận
  Future<bool> deleteComment(String commentId) async {
    try {
      final res = await _dio.delete('/api/social/v1/comments/$commentId');
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[SocialService] deleteComment error: $e');
      return false;
    }
  }

  /// Đăng bài viết mới
  Future<SocialPost?> createPost({
    required String bodyHtml,
    String? title,
    String? topicId,
    String? kind,
  }) async {
    try {
      final data = <String, dynamic>{
        'bodyHtml': bodyHtml.trim(),
        'kind': kind ?? 'post',
      };
      if (title != null && title.trim().isNotEmpty) {
        data['title'] = title.trim();
      }
      if (topicId != null && topicId.trim().isNotEmpty) {
        data['topicIds'] = [topicId.trim()];
      }

      final res = await _dio.post('/api/social/v1/posts', data: data);
      if ((res.statusCode == 200 || res.statusCode == 201) && res.data != null) {
        if (res.data is Map<String, dynamic>) {
          return SocialPost.fromJson(res.data as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[SocialService] createPost error: $e');
    }
    return null;
  }

  /// Lấy thông tin trang cá nhân
  Future<SocialPersonProfile?> getProfile(String userId) async {
    try {
      final res = await _dio.get('/api/social/v1/people/$userId/profile');
      if (res.statusCode == 200 && res.data != null && res.data is Map<String, dynamic>) {
        return SocialPersonProfile.fromJson(res.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[SocialService] getProfile error: $e');
    }
    return null;
  }

  /// Xoá bài viết
  Future<bool> deletePost(String postId) async {
    try {
      final res = await _dio.delete('/api/social/v1/posts/$postId');
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[SocialService] deletePost error: $e');
      return false;
    }
  }
}

