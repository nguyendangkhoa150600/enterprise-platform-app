part of 'workspace_repository_impl.dart';

/// Trao đổi, báo cáo và nhãn của Workspace — tách khỏi [WorkspaceRepositoryImpl]
/// để file chính không vượt giới hạn 1.500 dòng (project rules mục 4.1). Không đổi hành vi.
mixin _WorkspaceChatReportsRepository implements IWorkspaceRepository {
  WorkspaceRemoteDataSource get _remoteDataSource;
  bool _ok(Response res);
  bool _fail(Object e);

  @override
  Future<ProjectChatFeedPage> getProjectChatFeed(
    String projectId, {
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? onlyWithChat,
  }) async {
    try {
      final raw = await _remoteDataSource.getProjectChatFeedRaw(
        projectId,
        page: page,
        pageSize: pageSize,
        search: search,
        onlyWithChat: onlyWithChat,
      );
      if (raw != null && raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw;
        if (data is Map<String, dynamic>) {
          return ProjectChatFeedPage.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getProjectChatFeed error: $e');
    }
    return const ProjectChatFeedPage();
  }

  @override
  Future<ProjectChatThread> getProjectChatFeedThread(
    String projectId,
    String workItemId, {
    String? before,
  }) async {
    try {
      final raw = await _remoteDataSource.getProjectChatFeedThreadRaw(
        projectId,
        workItemId,
        before: before,
      );
      if (raw != null && raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw;
        if (data is Map<String, dynamic>) {
          return ProjectChatThread.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getProjectChatFeedThread error: $e');
    }
    return const ProjectChatThread();
  }

  @override
  Future<ProjectChatThread> getChatThread(
    String entityType,
    String entityId, {
    String? before,
  }) async {
    try {
      final raw = await _remoteDataSource.getChatThreadRaw(entityType, entityId, before: before);
      if (raw != null && raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw;
        if (data is Map<String, dynamic>) {
          return ProjectChatThread.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getChatThread error: $e');
    }
    return const ProjectChatThread();
  }

  @override
  Future<bool> sendChatMessage({
    required String entityType,
    required String entityId,
    required String body,
    List<String>? mentions,
    List<String>? attachmentDocumentIds,
  }) async {
    try {
      final payload = <String, dynamic>{
        'entityType': entityType,
        'entityId': entityId,
        'body': body.trim(),
        if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
        if (attachmentDocumentIds != null && attachmentDocumentIds.isNotEmpty)
          'attachmentDocumentIds': attachmentDocumentIds,
      };
      final res = await _remoteDataSource.sendChatMessageRaw(payload);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] sendChatMessage error: $e');
      return _fail(e);
    }
  }

  @override
  Future<ReportBundle?> getWorkspaceReports({
    String? from,
    String? to,
    List<String>? projectIds,
    List<String>? groups,
    List<String>? tagIds,
    String? userId,
  }) async {
    try {
      final raw = await _remoteDataSource.getReportsRaw(
        from: from,
        to: to,
        projectIds: projectIds,
        groups: groups,
        tagIds: tagIds,
        userId: userId,
      );
      if (raw != null && raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw;
        if (data is Map<String, dynamic>) {
          return ReportBundle.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getWorkspaceReports error: $e');
    }
    return null;
  }

  @override
  Future<ReportItemList?> getWorkspaceReportItems({
    required String kind,
    String? from,
    String? to,
    List<String>? projectIds,
    List<String>? groups,
    List<String>? tagIds,
    String? userId,
    String? assigneeUserId,
    String? status,
    String? priority,
  }) async {
    try {
      final raw = await _remoteDataSource.getReportItemsRaw(
        kind: kind,
        from: from,
        to: to,
        projectIds: projectIds,
        groups: groups,
        tagIds: tagIds,
        userId: userId,
        assigneeUserId: assigneeUserId,
        status: status,
        priority: priority,
      );
      if (raw != null && raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw;
        if (data is Map<String, dynamic>) {
          return ReportItemList.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getWorkspaceReportItems error: $e');
    }
    return null;
  }

  @override
  Future<List<TagItem>> getWorkspaceTags() async {
    try {
      final raw = await _remoteDataSource.getWorkspaceTagsRaw();
      if (raw != null && raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw;
        final items = data is Map<String, dynamic> ? data['items'] : (raw['items'] ?? data);
        if (items is List) {
          return items.whereType<Map<String, dynamic>>().map(TagItem.fromJson).toList();
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getWorkspaceTags error: $e');
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getTags() async {
    try {
      final raw = await _remoteDataSource.getTagsRaw();
      if (raw != null) {
        final data = raw is Map<String, dynamic> ? (raw['data'] ?? raw) : raw;
        final items = data is Map<String, dynamic>
            ? (data['items'] ?? data['tags'] ?? [])
            : (data is List ? data : []);
        if (items is List) {
          return items.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getTags error: $e');
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>?> createTag(String name) async {
    try {
      final raw = await _remoteDataSource.createTagRaw(name);
      if (raw != null) {
        final data = raw is Map<String, dynamic> ? (raw['data'] ?? raw) : raw;
        if (data is Map<String, dynamic>) {
          if (data['tag'] is Map<String, dynamic>) return data['tag'] as Map<String, dynamic>;
          if (data['item'] is Map<String, dynamic>) return data['item'] as Map<String, dynamic>;
          return data;
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] createTag error: $e');
    }
    return null;
  }

  @override
  Future<List<String>> getRecentWorkItemTitles() async {
    try {
      return await _remoteDataSource.getRecentWorkItemTitlesRaw();
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getRecentWorkItemTitles error: $e');
      return [];
    }
  }
}
