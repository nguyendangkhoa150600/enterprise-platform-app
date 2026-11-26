// Model của khung chat Trợ lý Savina (bản web: savina-agent, `/modules/assistant/`).

String _s(Object? v) => v == null ? '' : v.toString();
String? _opt(Object? v) {
  final s = _s(v);
  return s.isEmpty ? null : s;
}

/// Một phím tắt của hàng "Xem nhanh" / "Tạo nhanh" (web `GET /v1/shortcuts`).
class AssistantShortcut {
  final String key;
  final String label;

  /// `view` (gửi câu hỏi) | `create` (mở form).
  final String group;
  final String? icon;
  final String? hint;

  /// Câu gửi cho Trợ lý khi bấm phím "Xem nhanh"; trống thì gửi [label].
  final String? prompt;

  /// Phím "Tạo nhanh" cần hỏi thêm một giá trị trước khi mở (đây là chữ gợi ý của ô nhập).
  final String? ask;

  const AssistantShortcut({
    required this.key,
    required this.label,
    required this.group,
    this.icon,
    this.hint,
    this.prompt,
    this.ask,
  });

  factory AssistantShortcut.fromJson(Map<String, dynamic> j) => AssistantShortcut(
        key: _s(j['key']),
        label: _s(j['label']),
        group: _s(j['group']),
        icon: _opt(j['icon']),
        hint: _opt(j['hint']),
        prompt: _opt(j['prompt']),
        ask: _opt(j['ask']),
      );
}

class AssistantShortcutsData {
  final List<AssistantShortcut> shortcuts;
  final List<String> suggestions;
  final bool canConfigure;
  const AssistantShortcutsData({this.shortcuts = const [], this.suggestions = const [], this.canConfigure = false});
}

/// Một lựa chọn của câu hỏi Trợ lý hỏi lại (sự kiện `question`).
class AssistantQuestionOption {
  final String label;
  final String? description;
  final String? value;
  const AssistantQuestionOption({required this.label, this.description, this.value});

  factory AssistantQuestionOption.fromJson(Map<String, dynamic> j) =>
      AssistantQuestionOption(label: _s(j['label']), description: _opt(j['description']), value: _opt(j['value']));

  Map<String, dynamic> toJson() => {
        'label': label,
        if (description != null) 'description': description,
        if (value != null) 'value': value,
      };
}

class AssistantQuestion {
  final String id;
  final String question;
  final List<AssistantQuestionOption> options;
  final bool multiSelect;

  /// Nhãn đã trả lời; null là chưa trả lời. Gửi tin mới mà chưa trả lời thì coi như bỏ qua (danh sách rỗng).
  final List<String>? answered;

  const AssistantQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.multiSelect = false,
    this.answered,
  });

  AssistantQuestion withAnswered(List<String> labels) =>
      AssistantQuestion(id: id, question: question, options: options, multiSelect: multiSelect, answered: labels);

  factory AssistantQuestion.fromJson(Map<String, dynamic> j) => AssistantQuestion(
        id: _s(j['id']),
        question: _s(j['question']),
        options: [
          for (final o in (j['options'] as List? ?? const []))
            if (o is Map) AssistantQuestionOption.fromJson(Map<String, dynamic>.from(o)),
        ],
        multiSelect: j['multiSelect'] == true,
        answered: j['answered'] is List ? [for (final a in j['answered'] as List) _s(a)] : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'options': [for (final o in options) o.toJson()],
        'multiSelect': multiSelect,
        if (answered != null) 'answered': answered,
      };
}

/// Thẻ form trong khung chat (web `forms` của tin nhắn): Trợ lý soạn bản nháp, người dùng mở form của phân hệ để
/// xem, sửa, lưu.
class AssistantFormCard {
  final String id;
  final String key;
  final String title;
  final String? page;
  final String? variant;
  final Map<String, dynamic> draft;

  /// `open` | `saved` | `cancelled` | `unavailable` | `failed`.
  final String state;
  final String? label;
  final String? href;
  final String? message;

  const AssistantFormCard({
    required this.id,
    required this.key,
    required this.title,
    this.page,
    this.variant,
    this.draft = const {},
    this.state = 'open',
    this.label,
    this.href,
    this.message,
  });

  AssistantFormCard copyWith({
    Map<String, dynamic>? draft,
    String? variant,
    String? state,
    String? label,
    String? href,
    String? message,
    bool clearResult = false,
  }) =>
      AssistantFormCard(
        id: id,
        key: key,
        title: title,
        page: page,
        variant: variant ?? this.variant,
        draft: draft ?? this.draft,
        state: state ?? this.state,
        label: clearResult ? null : (label ?? this.label),
        href: clearResult ? null : (href ?? this.href),
        message: clearResult ? null : (message ?? this.message),
      );

  /// Sự kiện `action` (hoặc `POST /v1/shortcuts/:key/open`): `{key, requestId, draft, page?, variant?}`.
  factory AssistantFormCard.fromAction(Map<String, dynamic> action, String title) => AssistantFormCard(
        id: _s(action['requestId']),
        key: _s(action['key']),
        title: title,
        page: _opt(action['page']),
        variant: _opt(action['variant']),
        draft: action['draft'] is Map ? Map<String, dynamic>.from(action['draft'] as Map) : const {},
      );

  factory AssistantFormCard.fromJson(Map<String, dynamic> j) => AssistantFormCard(
        id: _s(j['id']),
        key: _s(j['key']),
        title: _s(j['title']),
        page: _opt(j['page']),
        variant: _opt(j['variant']),
        draft: j['draft'] is Map ? Map<String, dynamic>.from(j['draft'] as Map) : const {},
        state: _s(j['state']).isEmpty ? 'open' : _s(j['state']),
        label: _opt(j['label']),
        href: _opt(j['href']),
        message: _opt(j['message']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'title': title,
        if (page != null) 'page': page,
        if (variant != null) 'variant': variant,
        'draft': draft,
        'state': state,
        if (label != null) 'label': label,
        if (href != null) 'href': href,
        if (message != null) 'message': message,
      };
}

/// Một tin trong khung chat (web `messages`).
class AssistantChatMessage {
  final String id;

  /// `user` | `assistant`.
  final String role;
  final String content;
  final DateTime timestamp;

  /// Ảnh người dùng gửi kèm (data URL hoặc đường dẫn).
  final List<String> images;

  /// Đang làm gì (sự kiện `status`), suy nghĩ (`reasoning`) và các bước công cụ — không lưu lại.
  final String? status;
  final String? thinking;
  final List<String> toolSteps;
  final AssistantQuestion? question;
  final List<AssistantFormCard> forms;

  const AssistantChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    required this.timestamp,
    this.images = const [],
    this.status,
    this.thinking,
    this.toolSteps = const [],
    this.question,
    this.forms = const [],
  });

  bool get isUser => role == 'user';

  AssistantChatMessage copyWith({
    String? content,
    String? status,
    bool clearStatus = false,
    String? thinking,
    List<String>? toolSteps,
    AssistantQuestion? question,
    List<AssistantFormCard>? forms,
  }) =>
      AssistantChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        timestamp: timestamp,
        images: images,
        status: clearStatus ? null : (status ?? this.status),
        thinking: thinking ?? this.thinking,
        toolSteps: toolSteps ?? this.toolSteps,
        question: question ?? this.question,
        forms: forms ?? this.forms,
      );

  factory AssistantChatMessage.fromJson(Map<String, dynamic> j) => AssistantChatMessage(
        id: _s(j['id']),
        role: _s(j['role']) == 'user' ? 'user' : 'assistant',
        content: _s(j['content']),
        timestamp: DateTime.fromMillisecondsSinceEpoch((j['timestamp'] as num?)?.toInt() ?? 0),
        images: [for (final m in (j['images'] as List? ?? const [])) _s(m)],
        question: j['question'] is Map ? AssistantQuestion.fromJson(Map<String, dynamic>.from(j['question'] as Map)) : null,
        forms: [
          for (final f in (j['forms'] as List? ?? const []))
            if (f is Map) AssistantFormCard.fromJson(Map<String, dynamic>.from(f)),
        ],
      );

  /// Web `zZ`: không lưu trạng thái tạm, suy nghĩ, các bước, ảnh dạng data URL.
  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'images': [
          for (final m in images)
            if (!m.startsWith('data:')) m,
        ],
        if (question != null) 'question': question!.toJson(),
        if (forms.isNotEmpty) 'forms': [for (final f in forms) f.toJson()],
      };
}
