class ChatPerson {
  final String id;
  final String fullName;
  final String email;
  final int? avatarVersion;

  ChatPerson({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarVersion,
  });

  factory ChatPerson.fromJson(Map<String, dynamic> json) {
    return ChatPerson(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['displayName']?.toString() ?? 'Người dùng',
      email: json['email']?.toString() ?? '',
      avatarVersion: json['avatarVersion'] is int ? json['avatarVersion'] as int : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'avatarVersion': avatarVersion,
  };
}

class ChatMessagePreview {
  final String id;
  final String senderId;
  final String kind;
  final String excerpt;
  final int attachmentCount;
  final bool hasImage;
  final bool isDeleted;
  final String createdAt;

  ChatMessagePreview({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.excerpt,
    this.attachmentCount = 0,
    this.hasImage = false,
    this.isDeleted = false,
    required this.createdAt,
  });

  factory ChatMessagePreview.fromJson(Map<String, dynamic> json) {
    return ChatMessagePreview(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'text',
      excerpt: json['excerpt']?.toString() ?? '',
      attachmentCount: json['attachmentCount'] is int ? json['attachmentCount'] as int : 0,
      hasImage: json['hasImage'] == true,
      isDeleted: json['isDeleted'] == true,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class ChatConversation {
  final String id;
  final String kind; // 'company', 'direct', 'group'
  final String? title;
  final String? peerUserId;
  final List<String> memberIds;
  final int memberCount;
  final String? myRole;
  final bool muted;
  final int unreadCount;
  final int unreadMentionCount;
  final ChatMessagePreview? lastMessage;
  final String? lastMessageAt;
  final String createdAt;

  ChatConversation({
    required this.id,
    required this.kind,
    this.title,
    this.peerUserId,
    this.memberIds = const [],
    this.memberCount = 0,
    this.myRole,
    this.muted = false,
    this.unreadCount = 0,
    this.unreadMentionCount = 0,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['memberIds'];
    final membersList = membersRaw is List ? membersRaw.map((e) => e.toString()).toList() : <String>[];

    return ChatConversation(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'direct',
      title: json['title']?.toString(),
      peerUserId: json['peerUserId']?.toString(),
      memberIds: membersList,
      memberCount: json['memberCount'] is int ? json['memberCount'] as int : membersList.length,
      myRole: json['myRole']?.toString(),
      muted: json['muted'] == true,
      unreadCount: json['unreadCount'] is int ? json['unreadCount'] as int : 0,
      unreadMentionCount: json['unreadMentionCount'] is int ? json['unreadMentionCount'] as int : 0,
      lastMessage: json['lastMessage'] is Map<String, dynamic>
          ? ChatMessagePreview.fromJson(json['lastMessage'])
          : null,
      lastMessageAt: json['lastMessageAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class ChatAttachment {
  final String id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final bool isImage;

  ChatAttachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    this.sizeBytes = 0,
    this.isImage = false,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? 'Tệp tin',
      contentType: json['contentType']?.toString() ?? 'application/octet-stream',
      sizeBytes: json['sizeBytes'] is int ? json['sizeBytes'] as int : 0,
      isImage: json['isImage'] == true,
    );
  }
}

class ChatReactionSummary {
  final String reaction;
  final List<String> userIds;

  ChatReactionSummary({
    required this.reaction,
    this.userIds = const [],
  });

  factory ChatReactionSummary.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['userIds'];
    final users = rawUsers is List ? rawUsers.map((e) => e.toString()).toList() : <String>[];
    return ChatReactionSummary(
      reaction: json['reaction']?.toString() ?? '',
      userIds: users,
    );
  }
}

class ChatReplyPreview {
  final String id;
  final String senderId;
  final String excerpt;
  final bool isDeleted;
  final bool hasAttachments;

  ChatReplyPreview({
    required this.id,
    required this.senderId,
    required this.excerpt,
    this.isDeleted = false,
    this.hasAttachments = false,
  });

  factory ChatReplyPreview.fromJson(Map<String, dynamic> json) {
    return ChatReplyPreview(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? '',
      isDeleted: json['isDeleted'] == true,
      hasAttachments: json['hasAttachments'] == true,
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String kind; // 'text' or 'system'
  final String body;
  final List<String> mentions;
  final ChatReplyPreview? replyTo;
  final List<ChatAttachment> attachments;
  final List<ChatReactionSummary> reactions;
  final bool isDeleted;
  final bool isEdited;
  final String createdAt;
  final String updatedAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.kind = 'text',
    required this.body,
    this.mentions = const [],
    this.replyTo,
    this.attachments = const [],
    this.reactions = const [],
    this.isDeleted = false,
    this.isEdited = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final mentionsRaw = json['mentions'];
    final mentionsList = mentionsRaw is List ? mentionsRaw.map((e) => e.toString()).toList() : <String>[];

    final replyRaw = json['replyTo'];
    final replyObj = replyRaw is Map<String, dynamic> ? ChatReplyPreview.fromJson(replyRaw) : null;

    final attachRaw = json['attachments'];
    final attachList = attachRaw is List
        ? attachRaw.whereType<Map<String, dynamic>>().map((a) => ChatAttachment.fromJson(a)).toList()
        : <ChatAttachment>[];

    final reactRaw = json['reactions'];
    final reactList = reactRaw is List
        ? reactRaw.whereType<Map<String, dynamic>>().map((r) => ChatReactionSummary.fromJson(r)).toList()
        : <ChatReactionSummary>[];

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'text',
      body: json['body']?.toString() ?? '',
      mentions: mentionsList,
      replyTo: replyObj,
      attachments: attachList,
      reactions: reactList,
      isDeleted: json['isDeleted'] == true,
      isEdited: json['isEdited'] == true,
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

