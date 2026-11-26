import '../../../../models/workspace_models.dart';
import 'workspace_api_base.dart';

/// Tin được trả lời, rút gọn để hiện dòng trích phía trên câu trả lời (contract `ChatTimelineParent`).
class ChatTimelineParent {
  final String id;
  final String createdBy;

  /// Đầu nội dung tin gốc; rỗng khi tin gốc đã thu hồi.
  final String body;
  final bool isDeleted;

  const ChatTimelineParent({
    required this.id,
    required this.createdBy,
    required this.body,
    required this.isDeleted,
  });

  factory ChatTimelineParent.fromJson(Map<String, dynamic> json) => ChatTimelineParent(
        id: json['id']?.toString() ?? '',
        createdBy: json['createdBy']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        isDeleted: json['isDeleted'] == true,
      );
}

/// Một tin trên dòng thời gian của dự án, kèm node chứa nó (contract `ProjectChatTimelineItem`).
class ChatTimelineEntry {
  final ProjectChatMessage message;

  /// `work_item` hoặc `project`.
  final String entityType;

  /// Id công việc khi `entityType` là `work_item`; id dự án khi là `project`.
  final String entityId;
  final ChatTimelineParent? parent;

  const ChatTimelineEntry({
    required this.message,
    required this.entityType,
    required this.entityId,
    this.parent,
  });

  bool get isProject => entityType == 'project';

  factory ChatTimelineEntry.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    final parent = json['parent'];
    return ChatTimelineEntry(
      message: ProjectChatMessage.fromJson(message is Map ? Map<String, dynamic>.from(message) : const {}),
      entityType: json['entityType']?.toString() ?? 'work_item',
      entityId: json['entityId']?.toString() ?? '',
      parent: parent is Map ? ChatTimelineParent.fromJson(Map<String, dynamic>.from(parent)) : null,
    );
  }
}

/// Một trang dòng thời gian (contract `ProjectChatTimeline`): mỗi trang xếp cũ → mới.
class ChatTimelinePage {
  final List<ChatTimelineEntry> items;
  final bool hasMore;

  const ChatTimelinePage({this.items = const [], this.hasMore = false});
}

/// Bộ lọc gửi lên server (contract `ChatTimelineFilter`), mọi trường tuỳ chọn và cộng dồn (VÀ).
class ChatTimelineFilter {
  final String? q;
  final List<String> authors;
  final List<String> nodes;
  final bool mentionsMe;
  final bool hasAttachment;

  /// ISO, gồm mốc.
  final String? from;

  /// ISO, không gồm mốc.
  final String? to;

  const ChatTimelineFilter({
    this.q,
    this.authors = const [],
    this.nodes = const [],
    this.mentionsMe = false,
    this.hasAttachment = false,
    this.from,
    this.to,
  });

  bool get isActive =>
      (q?.isNotEmpty ?? false) ||
      authors.isNotEmpty ||
      nodes.isNotEmpty ||
      mentionsMe ||
      hasAttachment ||
      from != null ||
      to != null;

  Map<String, dynamic> toQuery() => {
        if (q != null && q!.isNotEmpty) 'q': q,
        if (authors.isNotEmpty) 'authors': authors.join(','),
        if (nodes.isNotEmpty) 'nodes': nodes.join(','),
        if (mentionsMe) 'mentionsMe': '1',
        if (hasAttachment) 'hasAttachment': '1',
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      };
}

/// API dòng thời gian trao đổi của dự án + gửi/trả lời tin, đồng bộ với web `workspace-api.ts`
/// (`loadProjectChatTimeline`, `sendChatMessage`, `replyChatMessage`).
class WorkspaceChatTimelineApi extends WorkspaceApiBase {
  /// GET /projects/:id/chat-timeline — chỉ để đọc, không đánh dấu đã đọc.
  Future<WorkspaceApiResult<ChatTimelinePage>> loadTimeline(
    String projectId, {
    String? before,
    ChatTimelineFilter filter = const ChatTimelineFilter(),
  }) =>
      send(
        'GET',
        '${WorkspaceApiBase.root}/projects/$projectId/chat-timeline',
        query: {
          if (before != null && before.isNotEmpty) 'before': before,
          ...filter.toQuery(),
        },
        parse: (data) => ChatTimelinePage(
          items: WorkspaceApiBase.itemsOf(data).map(ChatTimelineEntry.fromJson).toList(),
          hasMore: data is Map && data['hasMore'] == true,
        ),
      );

  /// POST /chat/messages (kênh `project`) — trả về `droppedMentions`.
  Future<WorkspaceApiResult<List<String>>> sendProjectMessage(
    String projectId, {
    required String body,
    List<String> mentions = const [],
    List<String> attachmentDocumentIds = const [],
  }) =>
      send(
        'POST',
        '${WorkspaceApiBase.root}/chat/messages',
        body: {
          'entityType': 'project',
          'entityId': projectId,
          'body': body,
          'mentions': mentions,
          if (attachmentDocumentIds.isNotEmpty) 'attachmentDocumentIds': attachmentDocumentIds,
        },
        parse: _dropped,
      );

  /// POST /chat/messages/:id/reply — server lấy kênh từ chính tin được trả lời.
  Future<WorkspaceApiResult<List<String>>> reply(
    String messageId, {
    required String body,
    List<String> mentions = const [],
  }) =>
      send(
        'POST',
        '${WorkspaceApiBase.root}/chat/messages/$messageId/reply',
        body: {'body': body, 'mentions': mentions},
        parse: _dropped,
      );

  /// GET /projects/:id/chat-feed — một trang công việc kèm tóm tắt trao đổi (chế độ "Theo công việc"),
  /// chỉ để đọc. Web `loadProjectChatFeed`: `page`, `pageSize`, `q`, `hasChat=1`.
  Future<WorkspaceApiResult<ProjectChatFeedPage>> loadFeed(
    String projectId, {
    required int page,
    required int pageSize,
    String? search,
    bool onlyWithChat = false,
  }) =>
      send(
        'GET',
        '${WorkspaceApiBase.root}/projects/$projectId/chat-feed',
        query: {
          'page': '$page',
          'pageSize': '$pageSize',
          if (search != null && search.isNotEmpty) 'q': search,
          if (onlyWithChat) 'hasChat': '1',
        },
        parse: (data) => ProjectChatFeedPage.fromJson(_mapOf(data)),
      );

  /// GET /projects/:id/chat-feed/:workItemId — trao đổi của một công việc, cũ → mới, chỉ để đọc.
  /// Có [before] (id tin cũ nhất đang có) thì là trang liền trước nó.
  Future<WorkspaceApiResult<ProjectChatThread>> loadFeedThread(
    String projectId,
    String workItemId, {
    String? before,
  }) =>
      send(
        'GET',
        '${WorkspaceApiBase.root}/projects/$projectId/chat-feed/$workItemId',
        query: {if (before != null && before.isNotEmpty) 'before': before},
        parse: (data) => ProjectChatThread.fromJson(_mapOf(data)),
      );

  /// `{data: {...}}` hoặc `{...}` → map.
  static Map<String, dynamic> _mapOf(dynamic data) {
    final inner = data is Map && data['data'] is Map ? data['data'] : data;
    return inner is Map ? Map<String, dynamic>.from(inner) : const {};
  }

  /// Tài liệu của dự án (để chọn đính kèm), như màn Dự án trên web.
  Future<WorkspaceApiResult<List<WorkspaceDocumentItem>>> loadDocuments(String projectId) => send(
        'GET',
        '${WorkspaceApiBase.root}/documents',
        query: {'projectId': projectId},
        parse: (data) => _listOf(data).map(WorkspaceDocumentItem.fromJson).toList(),
      );

  /// Thư mục của dự án (để tải tệp mới lên khi đính kèm).
  Future<WorkspaceApiResult<List<WorkspaceFolderItem>>> loadFolders(String projectId) => send(
        'GET',
        '${WorkspaceApiBase.root}/folders',
        query: {'projectId': projectId},
        parse: (data) => _listOf(data).map(WorkspaceFolderItem.fromJson).toList(),
      );

  /// `{data: {items}}`, `{items}`, `{data: [...]}` hoặc mảng trần.
  static List<Map<String, dynamic>> _listOf(dynamic data) {
    final inner = data is Map && data['data'] is Map ? data['data'] : data;
    return WorkspaceApiBase.itemsOf(inner);
  }

  static List<String> _dropped(dynamic data) {
    final raw = data is Map ? data['droppedMentions'] : null;
    return raw is List ? raw.map((e) => e.toString()).toList() : const [];
  }
}
