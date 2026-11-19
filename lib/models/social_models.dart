import '../utils/user_resolver.dart';

class SocialUserRef {
  final String id;
  final String name;
  final String? position;
  final String? unitName;
  final String? avatarUrl;

  const SocialUserRef({
    required this.id,
    required this.name,
    this.position,
    this.unitName,
    this.avatarUrl,
  });

  factory SocialUserRef.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    var name = json['name']?.toString() ?? json['full_name']?.toString() ?? '';
    if (name.isEmpty || name == 'Người dùng') {
      name = UserResolver.resolveName(id, fallback: name.isNotEmpty ? name : 'Nhân sự');
    }
    return SocialUserRef(
      id: id,
      name: name,
      position: json['position']?.toString() ?? json['title']?.toString(),
      unitName: json['unitName']?.toString() ?? json['unit_name']?.toString() ?? json['department']?.toString(),
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (position != null) 'position': position,
    if (unitName != null) 'unitName': unitName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
  };
}

class SocialAttachment {
  final String id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final bool isImage;
  final bool isVideo;
  final String? url;
  final String? posterUrl;
  final int? width;
  final int? height;
  final int? durationMs;

  const SocialAttachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.isImage,
    this.isVideo = false,
    this.url,
    this.posterUrl,
    this.width,
    this.height,
    this.durationMs,
  });

  factory SocialAttachment.fromJson(Map<String, dynamic> json) {
    final contentType = json['contentType']?.toString() ?? json['content_type']?.toString() ?? '';
    final isVideo = json['isVideo'] == true ||
        json['is_video'] == true ||
        contentType.startsWith('video/') ||
        contentType == 'video/mp4' ||
        contentType == 'video/webm' ||
        contentType == 'video/quicktime';

    return SocialAttachment(
      id: json['id']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? json['file_name']?.toString() ?? 'attachment',
      contentType: contentType,
      sizeBytes: (json['sizeBytes'] ?? json['size_bytes'] ?? 0) as int,
      isImage: (json['isImage'] == true || json['is_image'] == true) && !isVideo,
      isVideo: isVideo,
      url: json['url']?.toString(),
      posterUrl: json['posterUrl']?.toString() ?? json['poster_url']?.toString(),
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
      durationMs: json['durationMs'] is num
          ? (json['durationMs'] as num).toInt()
          : (json['duration_ms'] is num ? (json['duration_ms'] as num).toInt() : null),
    );
  }
}

class SocialTopic {
  final String id;
  final String name;
  final bool isActive;
  final int postCount;

  const SocialTopic({
    required this.id,
    required this.name,
    this.isActive = true,
    this.postCount = 0,
  });

  factory SocialTopic.fromJson(Map<String, dynamic> json) {
    return SocialTopic(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: json['isActive'] != false && json['is_active'] != false,
      postCount: (json['postCount'] ?? json['post_count'] ?? 0) as int,
    );
  }
}

class SocialPostActivity {
  final String type; // 'avatar.updated', etc.
  final Map<String, dynamic> payload;

  const SocialPostActivity({
    required this.type,
    this.payload = const {},
  });

  factory SocialPostActivity.fromJson(Map<String, dynamic> json) {
    return SocialPostActivity(
      type: json['type']?.toString() ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }

  String get label {
    switch (type) {
      case 'avatar.updated':
        return 'đã cập nhật ảnh đại diện';
      case 'cover.updated':
        return 'đã cập nhật ảnh bìa';
      case 'badge.awarded':
        return 'nhận được huy hiệu mới';
      case 'milestone.reached':
        return 'đạt một mốc kỷ niệm';
      default:
        return 'có hoạt động mới';
    }
  }
}

class SocialPost {
  final String id;
  final SocialUserRef author;
  final String kind; // 'post' | 'announcement'
  final String? title;
  final String bodyHtml;
  final SocialPostActivity? activity;
  final SocialTopic? topic;
  final List<SocialTopic> topics;
  final bool pinned;
  final List<SocialAttachment> attachments;
  final Map<String, int> reactionCounts;
  final int reactionTotal;
  final String? myReaction;
  final int commentCount;
  final DateTime publishedAt;
  final DateTime? editedAt;
  final bool canEdit;
  final bool canDelete;
  final bool canPin;
  final bool canComment;
  final bool canToggleComments;
  final bool commentsDisabled;
  final bool bookmarked;
  final String? groupName;

  const SocialPost({
    required this.id,
    required this.author,
    this.kind = 'post',
    this.title,
    required this.bodyHtml,
    this.activity,
    this.topic,
    this.topics = const [],
    this.pinned = false,
    this.attachments = const [],
    this.reactionCounts = const {},
    this.reactionTotal = 0,
    this.myReaction,
    this.commentCount = 0,
    required this.publishedAt,
    this.editedAt,
    this.canEdit = false,
    this.canDelete = false,
    this.canPin = false,
    this.canComment = true,
    this.canToggleComments = false,
    this.commentsDisabled = false,
    this.bookmarked = false,
    this.groupName,
  });

  factory SocialPost.fromJson(Map<String, dynamic> json) {
    final authorJson = json['author'];
    final author = authorJson is Map<String, dynamic>
        ? SocialUserRef.fromJson(authorJson)
        : const SocialUserRef(id: '', name: 'Nhân sự');

    final topicJson = json['topic'];
    final topic = topicJson is Map<String, dynamic> ? SocialTopic.fromJson(topicJson) : null;

    final rawTopics = json['topics'];
    final topics = rawTopics is List
        ? rawTopics.whereType<Map<String, dynamic>>().map((t) => SocialTopic.fromJson(t)).toList()
        : <SocialTopic>[];

    final rawAttachments = json['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments.whereType<Map<String, dynamic>>().map((a) => SocialAttachment.fromJson(a)).toList()
        : <SocialAttachment>[];

    final rawReactions = json['reactionCounts'] ?? json['reaction_counts'];
    final reactionCounts = <String, int>{};
    if (rawReactions is Map) {
      rawReactions.forEach((k, v) {
        if (v is num) reactionCounts[k.toString()] = v.toInt();
      });
    }

    final caps = json['capabilities'] as Map<String, dynamic>? ?? {};

    DateTime pubAt = DateTime.now();
    final rawPub = json['publishedAt'] ?? json['published_at'];
    if (rawPub is String) {
      pubAt = DateTime.tryParse(rawPub) ?? DateTime.now();
    }

    DateTime? editAt;
    final rawEdit = json['editedAt'] ?? json['edited_at'];
    if (rawEdit is String) {
      editAt = DateTime.tryParse(rawEdit);
    }

    final rawGroup = json['group'];
    final groupName = rawGroup is Map ? rawGroup['name']?.toString() : null;

    final activityJson = json['activity'];
    final activity = activityJson is Map<String, dynamic>
        ? SocialPostActivity.fromJson(activityJson)
        : null;

    return SocialPost(
      id: json['id']?.toString() ?? '',
      author: author,
      kind: json['kind']?.toString() ?? 'post',
      title: json['title']?.toString(),
      bodyHtml: json['bodyHtml']?.toString() ?? json['body_html']?.toString() ?? json['content']?.toString() ?? '',
      activity: activity,
      topic: topic,
      topics: topics,
      pinned: json['pinned'] == true,
      attachments: attachments,
      reactionCounts: reactionCounts,
      reactionTotal: (json['reactionTotal'] ?? json['reaction_total'] ?? 0) as int,
      myReaction: json['myReaction']?.toString() ?? json['my_reaction']?.toString(),
      commentCount: (json['commentCount'] ?? json['comment_count'] ?? 0) as int,
      publishedAt: pubAt,
      editedAt: editAt,
      canEdit: caps['canEdit'] == true || caps['can_edit'] == true,
      canDelete: caps['canDelete'] == true || caps['can_delete'] == true,
      canPin: caps['canPin'] == true || caps['can_pin'] == true,
      canComment: caps['canComment'] != false && caps['can_comment'] != false,
      canToggleComments: caps['canToggleComments'] == true || caps['can_toggle_comments'] == true,
      commentsDisabled: json['commentsDisabled'] == true || json['comments_disabled'] == true,
      bookmarked: json['bookmarked'] == true,
      groupName: groupName,
    );
  }

  SocialPost copyWith({
    String? bodyHtml,
    Map<String, int>? reactionCounts,
    int? reactionTotal,
    String? myReaction,
    bool clearMyReaction = false,
    int? commentCount,
    bool? bookmarked,
    bool? pinned,
    bool? commentsDisabled,
    SocialPostActivity? activity,
  }) {
    return SocialPost(
      id: id,
      author: author,
      kind: kind,
      title: title,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      activity: activity ?? this.activity,
      topic: topic,
      topics: topics,
      pinned: pinned ?? this.pinned,
      attachments: attachments,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      reactionTotal: reactionTotal ?? this.reactionTotal,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      commentCount: commentCount ?? this.commentCount,
      publishedAt: publishedAt,
      editedAt: editedAt,
      canEdit: canEdit,
      canDelete: canDelete,
      canPin: canPin,
      canComment: canComment,
      canToggleComments: canToggleComments,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      bookmarked: bookmarked ?? this.bookmarked,
      groupName: groupName,
    );
  }
}

class SocialComment {
  final String id;
  final SocialUserRef author;
  final String contentHtml;
  final DateTime publishedAt;
  final DateTime? editedAt;
  final String? parentId;
  final int replyCount;
  final Map<String, int> reactionCounts;
  final int reactionTotal;
  final String? myReaction;
  final bool canEdit;
  final bool canDelete;
  final List<SocialComment> replies;

  const SocialComment({
    required this.id,
    required this.author,
    required this.contentHtml,
    required this.publishedAt,
    this.editedAt,
    this.parentId,
    this.replyCount = 0,
    this.reactionCounts = const {},
    this.reactionTotal = 0,
    this.myReaction,
    this.canEdit = false,
    this.canDelete = false,
    this.replies = const [],
  });

  factory SocialComment.fromJson(Map<String, dynamic> json) {
    final authorJson = json['author'];
    final author = authorJson is Map<String, dynamic>
        ? SocialUserRef.fromJson(authorJson)
        : const SocialUserRef(id: '', name: 'Nhân sự');

    DateTime pubAt = DateTime.now();
    final rawPub = json['createdAt'] ?? json['created_at'] ?? json['publishedAt'] ?? json['published_at'];
    if (rawPub is String) {
      pubAt = DateTime.tryParse(rawPub) ?? DateTime.now();
    }

    DateTime? editAt;
    final rawEdit = json['editedAt'] ?? json['edited_at'];
    if (rawEdit is String) {
      editAt = DateTime.tryParse(rawEdit);
    }

    final rawReactions = json['reactionCounts'] ?? json['reaction_counts'];
    final reactionCounts = <String, int>{};
    if (rawReactions is Map) {
      rawReactions.forEach((k, v) {
        if (v is num) reactionCounts[k.toString()] = v.toInt();
      });
    }

    final caps = json['capabilities'] as Map<String, dynamic>? ?? {};

    final body = json['body']?.toString() ??
        json['contentHtml']?.toString() ??
        json['content_html']?.toString() ??
        json['content']?.toString() ??
        '';

    return SocialComment(
      id: json['id']?.toString() ?? '',
      author: author,
      contentHtml: body,
      publishedAt: pubAt,
      editedAt: editAt,
      parentId: json['parentId']?.toString() ?? json['parent_id']?.toString(),
      replyCount: (json['replyCount'] ?? json['reply_count'] ?? 0) as int,
      reactionCounts: reactionCounts,
      reactionTotal: (json['reactionTotal'] ??
              json['reaction_total'] ??
              reactionCounts.values.fold<int>(0, (a, b) => a + b)) as int,
      myReaction: json['myReaction']?.toString() ?? json['my_reaction']?.toString(),
      canEdit: caps['canEdit'] == true || caps['can_edit'] == true,
      canDelete: caps['canDelete'] == true || caps['can_delete'] == true,
      replies: const [],
    );
  }

  SocialComment copyWith({
    String? contentHtml,
    Map<String, int>? reactionCounts,
    int? reactionTotal,
    String? myReaction,
    bool clearMyReaction = false,
    int? replyCount,
    List<SocialComment>? replies,
  }) {
    return SocialComment(
      id: id,
      author: author,
      contentHtml: contentHtml ?? this.contentHtml,
      publishedAt: publishedAt,
      editedAt: editedAt,
      parentId: parentId,
      replyCount: replyCount ?? this.replyCount,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      reactionTotal: reactionTotal ?? this.reactionTotal,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      canEdit: canEdit,
      canDelete: canDelete,
      replies: replies ?? this.replies,
    );
  }
}

class SocialGroupSummary {
  final String id;
  final String name;
  final String? description;
  final String privacy; // 'public' | 'private'
  final int memberCount;
  final int postCount;
  final String? color;
  final String? icon;
  final bool isMember;
  final String? role; // 'admin' | 'member' | null

  const SocialGroupSummary({
    required this.id,
    required this.name,
    this.description,
    this.privacy = 'public',
    this.memberCount = 0,
    this.postCount = 0,
    this.color,
    this.icon,
    this.isMember = false,
    this.role,
  });

  factory SocialGroupSummary.fromJson(Map<String, dynamic> json) {
    final membership = json['membership'];
    final isMember = membership != null;
    final role = membership is Map ? membership['role']?.toString() : null;

    return SocialGroupSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      privacy: json['privacy']?.toString() ?? 'public',
      memberCount: (json['memberCount'] ?? json['member_count'] ?? 0) as int,
      postCount: (json['postCount'] ?? json['post_count'] ?? 0) as int,
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
      isMember: isMember,
      role: role,
    );
  }
}

class SocialPersonProfile {
  final SocialUserRef user;
  final bool isSelf;
  final String? unitName;
  final String? position;
  final String? email;
  final String? birthday;
  final String? joinedAt;
  final String? employeeCode;
  final int postCount;
  final bool canOpenInHrm;

  const SocialPersonProfile({
    required this.user,
    this.isSelf = false,
    this.unitName,
    this.position,
    this.email,
    this.birthday,
    this.joinedAt,
    this.employeeCode,
    this.postCount = 0,
    this.canOpenInHrm = false,
  });

  factory SocialPersonProfile.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final user = userJson is Map<String, dynamic>
        ? SocialUserRef.fromJson(userJson)
        : const SocialUserRef(id: '', name: 'Người dùng');

    String? bdayStr;
    final bday = json['birthday'];
    if (bday is Map) {
      final day = bday['day']?.toString().padLeft(2, '0');
      final month = bday['month']?.toString().padLeft(2, '0');
      if (day != null && month != null) bdayStr = '$day/$month';
    } else if (bday is String) {
      bdayStr = bday;
    }

    return SocialPersonProfile(
      user: user,
      isSelf: json['isSelf'] == true || json['is_self'] == true,
      unitName: json['unitName']?.toString() ?? json['unit_name']?.toString() ?? user.unitName,
      position: json['position']?.toString() ?? user.position,
      email: json['email']?.toString(),
      birthday: bdayStr,
      joinedAt: json['joinedAt']?.toString() ?? json['joined_at']?.toString(),
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString(),
      postCount: (json['postCount'] ?? json['post_count'] ?? 0) as int,
      canOpenInHrm: json['canOpenInHrm'] == true || json['can_open_in_hrm'] == true,
    );
  }
}

class SocialFeedPage {
  final List<SocialPost> items;
  final String? nextCursor;

  const SocialFeedPage({
    required this.items,
    this.nextCursor,
  });

  factory SocialFeedPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['data'] ?? [];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().map((p) => SocialPost.fromJson(p)).toList()
        : <SocialPost>[];

    return SocialFeedPage(
      items: items,
      nextCursor: json['nextCursor']?.toString() ?? json['next_cursor']?.toString(),
    );
  }
}

