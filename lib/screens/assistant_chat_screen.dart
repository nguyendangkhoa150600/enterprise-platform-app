import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/i18n/app_i18n.dart';
import '../core/realtime/realtime_service.dart';
import '../models/assistant_models.dart';
import '../services/assistant_service.dart';
import '../utils/app_toast.dart';
import 'assistant/widgets/assistant_form_card.dart';
import 'assistant/widgets/assistant_message_view.dart';
import 'assistant/widgets/assistant_shortcut_bar.dart';

/// Ảnh gửi kèm tối đa 5MB (web `rj`).
const int _maxImageBytes = 5 * 1024 * 1024;

/// Phím tắt chỉ tải lại khi đã quá 60 giây (web `Jme`), trừ khi buộc tải.
const Duration _shortcutsTtl = Duration(seconds: 60);

/// Khung chat Trợ lý Savina — bản native của giao diện savina-agent mà web mở trong ngăn Trợ lý
/// (`/modules/assistant/?embed=1`): cùng API, cùng luồng sự kiện, cùng bố cục.
class AssistantChatScreen extends StatefulWidget {
  /// Câu gửi ngay khi mở.
  final String? initialPrompt;

  /// Đặt trong một tab (không có thanh tiêu đề riêng của màn).
  final bool isEmbeddedInTab;

  const AssistantChatScreen({super.key, this.initialPrompt, this.isEmbeddedInTab = false});

  @override
  State<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends State<AssistantChatScreen> with WidgetsBindingObserver {
  final AssistantService _service = AssistantService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<AssistantChatMessage> _messages = [];
  String? _conversationId;
  bool _loaded = false;
  bool _sending = false;
  bool _deepThinking = false;
  String? _image;
  CancelToken? _cancel;

  List<AssistantShortcut> _shortcuts = const [];
  List<String> _suggestions = const [];
  bool _canConfigure = false;
  Map<String, int> _counts = const {};
  DateTime? _shortcutsAt;

  /// Thẻ form mới đến trong lúc đang trả lời: mở sau khi luồng xong.
  final List<String> _formsToOpen = [];
  VoidCallback? _unlisten;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unlisten = RealtimeService.instance.listen('authorization.changed', (_) {
      // Web: quyền trong công ty đổi → lấy lại hàng phím (gộp các lần đổi liền nhau).
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(seconds: 2), () => _loadShortcuts(force: true));
    });
    _init();
  }

  Future<void> _init() async {
    final saved = await _service.loadConversation();
    if (!mounted) return;
    setState(() {
      _messages = saved.messages;
      _conversationId = saved.conversationId;
      _loaded = true;
    });
    _scrollToEnd();
    unawaited(_loadShortcuts(force: true));
    final prompt = widget.initialPrompt?.trim();
    if (prompt != null && prompt.isNotEmpty) unawaited(_send(prompt));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadShortcuts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlisten?.call();
    _refreshTimer?.cancel();
    _cancel?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- phím tắt

  Future<void> _loadShortcuts({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _shortcutsAt != null && now.difference(_shortcutsAt!) < _shortcutsTtl) return;
    _shortcutsAt = now;
    final data = await _service.getShortcuts();
    if (!mounted) return;
    setState(() {
      _shortcuts = data.shortcuts;
      _suggestions = data.suggestions;
      _canConfigure = data.canConfigure;
    });
    if (data.shortcuts.any((s) => s.group == 'view')) {
      await _loadCounts();
    } else if (mounted) {
      setState(() => _counts = const {});
    }
  }

  Future<void> _loadCounts() async {
    final counts = await _service.getCounts();
    if (mounted) setState(() => _counts = counts);
  }

  /// "Tạo nhanh": server trả thao tác (mở thẻ form) hoặc đường dẫn trang ERP (mở màn của ứng dụng).
  Future<void> _openShortcut(AssistantShortcut s, String? value) async {
    Map<String, dynamic> result;
    try {
      result = await _service.openShortcut(s.key, value);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e is AssistantApiException ? e.message : 'assistant.form.open_failed'.tr());
      unawaited(_loadShortcuts(force: true));
      return;
    }
    if (!mounted) return;
    final action = result['action'];
    if (action is Map) {
      final id = _addFormCard(Map<String, dynamic>.from(action), result['title']?.toString() ?? s.label);
      if (id != null) unawaited(_openForm(id));
      return;
    }
    final href = result['href']?.toString();
    if (href != null && href.isNotEmpty) await openAssistantLink(context, href);
  }

  // ---------------------------------------------------------------- thẻ form

  AssistantFormCard? _findCard(String id) {
    for (final m in _messages) {
      for (final f in m.forms) {
        if (f.id == id) return f;
      }
    }
    return null;
  }

  void _replaceCard(AssistantFormCard card) {
    setState(() {
      _messages = [
        for (final m in _messages)
          m.forms.any((f) => f.id == card.id)
              ? m.copyWith(forms: [for (final f in m.forms) f.id == card.id ? card : f])
              : m,
      ];
    });
    _persist();
  }

  /// Web `Q`: thao tác cùng `requestId` cập nhật thẻ có sẵn (gộp bản nháp; thẻ đã đóng/lỗi thì mở lại), còn lại thêm
  /// thẻ mới vào tin [messageId] hoặc một tin Trợ lý mới. Trả id thẻ mới (null khi chỉ cập nhật).
  String? _addFormCard(Map<String, dynamic> action, String title, [String? messageId]) {
    final incoming = AssistantFormCard.fromAction(action, title);
    final existing = _findCard(incoming.id);
    if (existing != null) {
      if (existing.state == 'saved') return null;
      final merged = {...existing.draft, ...incoming.draft};
      _replaceCard(existing.copyWith(
        draft: merged,
        variant: incoming.variant,
        state: 'open',
        clearResult: existing.state != 'open',
      ));
      return null;
    }
    setState(() {
      if (messageId != null && _messages.any((m) => m.id == messageId)) {
        _messages = [
          for (final m in _messages) m.id == messageId ? m.copyWith(forms: [...m.forms, incoming]) : m,
        ];
      } else {
        _messages = [
          ..._messages,
          AssistantChatMessage(
            id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
            role: 'assistant',
            timestamp: DateTime.now(),
            forms: [incoming],
          ),
        ];
      }
    });
    _persist();
    _scrollToEnd();
    return incoming.id;
  }

  Future<void> _openForm(String id) async {
    final card = _findCard(id);
    if (card == null || !mounted) return;
    final next = await runAssistantForm(context, card.copyWith(state: 'open', clearResult: true));
    if (!mounted) return;
    _replaceCard(next);
    if (next.state == 'saved') unawaited(_loadCounts());
  }

  // ---------------------------------------------------------------- gửi tin

  void _updateMessage(String id, AssistantChatMessage Function(AssistantChatMessage m) change) {
    if (!mounted) return;
    setState(() => _messages = [for (final m in _messages) m.id == id ? change(m) : m]);
    _scrollToEnd();
  }

  /// Web `Ue`: gửi câu hỏi (kèm ảnh, phím tắt, câu trả lời cho câu hỏi lựa chọn) và nhận luồng trả lời.
  Future<void> _send(String text, {String? image, String? shortcut, Map<String, dynamic>? answer}) async {
    if ((text.trim().isEmpty && image == null) || _sending) return;
    final now = DateTime.now();
    final assistantId = 'assistant-${now.microsecondsSinceEpoch}';
    final openForms = [
      for (final m in _messages)
        for (final f in m.forms)
          if (f.state == 'open') {'request_id': f.id, 'key': f.key, 'title': f.title, 'draft': f.draft},
    ];
    setState(() {
      _input.clear();
      _image = null;
      _sending = true;
      _messages = [
        // Câu hỏi lựa chọn chưa trả lời mà người dùng gửi tin khác: coi như bỏ qua.
        for (final m in _messages)
          m.question != null && m.question!.answered == null ? m.copyWith(question: m.question!.withAnswered(const [])) : m,
        AssistantChatMessage(
          id: 'user-${now.microsecondsSinceEpoch}',
          role: 'user',
          content: text,
          timestamp: now,
          images: image == null ? const [] : [image],
        ),
        AssistantChatMessage(id: assistantId, role: 'assistant', timestamp: now),
      ];
    });
    _scrollToEnd();

    final cancel = CancelToken();
    _cancel = cancel;
    var content = '';
    var thinking = '';
    var handled = false;

    Future<void> run(String? conversationId) => _service.chat(
          {
            'message': text,
            'conversation_id': conversationId,
            'images': ?(image == null ? null : [image]),
            'deep_thinking': _deepThinking,
            'page': AssistantService.page,
            'shortcut': ?shortcut,
            if (openForms.isNotEmpty) 'open_forms': openForms.length > 3 ? openForms.sublist(openForms.length - 3) : openForms,
            'answer': ?answer,
          },
          AssistantChatCallbacks(
            onConversation: (id) {
              if (mounted) setState(() => _conversationId = id);
            },
            onDelta: (t) {
              content += t;
              _updateMessage(assistantId, (m) => m.copyWith(content: content, clearStatus: true));
            },
            onReasoning: (t) {
              thinking += t;
              _updateMessage(assistantId, (m) => m.copyWith(thinking: thinking));
            },
            onStep: (step) => _updateMessage(
              assistantId,
              (m) => m.copyWith(
                status: step,
                toolSteps: m.toolSteps.isNotEmpty && m.toolSteps.last == step ? m.toolSteps : [...m.toolSteps, step],
              ),
            ),
            onAction: (action, title) {
              handled = true;
              final id = _addFormCard(action, title, assistantId);
              if (id != null) _formsToOpen.add(id);
            },
            onQuestion: (q) {
              handled = true;
              _updateMessage(assistantId, (m) => m.copyWith(question: AssistantQuestion.fromJson(q), clearStatus: true));
            },
            onFile: (f) {
              final name = f['filename']?.toString() ?? '';
              final url = f['url']?.toString() ?? '';
              final isImage = (f['mime_type']?.toString() ?? '').startsWith('image/');
              content += isImage ? '\n\n![$name]($url)\n' : '\n\n[$name]($url)\n';
              _updateMessage(assistantId, (m) => m.copyWith(content: content));
            },
            onError: (message) {
              content += '${content.isEmpty ? '' : '\n\n'}⚠️ $message';
              _updateMessage(assistantId, (m) => m.copyWith(content: content));
            },
          ),
          cancelToken: cancel,
        );

    try {
      try {
        await run(_conversationId);
      } on AssistantApiException catch (e) {
        // Hội thoại cũ đã bị xoá phía server: bắt đầu hội thoại mới rồi gửi lại.
        if (_conversationId == null || !RegExp('Không tìm thấy hội thoại').hasMatch(e.message)) rethrow;
        if (mounted) setState(() => _conversationId = null);
        await run(null);
      }
      if (content.isEmpty && !handled) {
        _updateMessage(assistantId, (m) => m.copyWith(content: 'assistant.no_answer'.tr()));
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      _updateMessage(
        assistantId,
        (m) => m.copyWith(content: m.content.isNotEmpty ? m.content : 'assistant.error_generic'.tr()),
      );
      if (mounted) {
        AppToast.error(context, e is AssistantApiException ? e.message : 'assistant.send_failed'.tr());
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _messages = [for (final m in _messages) m.id == assistantId ? m.copyWith(clearStatus: true) : m];
        });
        if (identical(_cancel, cancel)) _cancel = null;
        _persist();
        unawaited(_loadShortcuts());
        final pending = List.of(_formsToOpen);
        _formsToOpen.clear();
        if (pending.isNotEmpty) unawaited(_openForm(pending.first));
      }
    }
  }

  void _stop() {
    _cancel?.cancel();
    _cancel = null;
    setState(() => _sending = false);
  }

  void _newConversation() {
    _stop();
    setState(() {
      _messages = [];
      _conversationId = null;
    });
    _service.clearConversation();
  }

  void _answer(String messageId, AssistantQuestion q, List<String> labels, List<String> values) {
    if (_sending) return;
    setState(() {
      _messages = [
        for (final m in _messages)
          m.id == messageId && m.question != null ? m.copyWith(question: m.question!.withAnswered(labels)) : m,
      ];
    });
    _send(labels.join(', '), answer: {'question_id': q.id, 'values': values});
  }

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null || !mounted) return;
    final size = await file.length() ?? 0;
    if (!mounted) return;
    if (size > _maxImageBytes) {
      AppToast.error(context, 'assistant.image_too_large'.tr());
      return;
    }
    try {
      final bytes = await file.xFile.readAsBytes();
      final ext = (file.extension ?? 'png').toLowerCase();
      final mime = ext == 'jpg' ? 'jpeg' : ext;
      if (!mounted) return;
      setState(() => _image = 'data:image/$mime;base64,${base64Encode(bytes)}');
    } catch (_) {
      if (mounted) AppToast.error(context, 'assistant.image_failed'.tr());
    }
  }

  void _persist() {
    if (_sending) return;
    _service.saveConversation(_conversationId, _messages);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  // ---------------------------------------------------------------- giao diện

  Widget _headerActions() => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'assistant.deep_thinking'.tr(),
          onPressed: () => setState(() => _deepThinking = !_deepThinking),
          style: IconButton.styleFrom(
            backgroundColor: _deepThinking ? const Color(0xFFFEF3C7) : null,
            foregroundColor: _deepThinking ? const Color(0xFFB45309) : const Color(0xFF6B7280),
          ),
          icon: const Icon(Icons.psychology_outlined, size: 20),
        ),
        IconButton(
          tooltip: 'assistant.new_conversation'.tr(),
          onPressed: _newConversation,
          icon: const Icon(Icons.add_comment_outlined, size: 20, color: Color(0xFF6B7280)),
        ),
      ]);

  Widget _title() => Row(mainAxisSize: MainAxisSize.min, children: [
        const AssistantAvatar(size: 34),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('assistant.title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('assistant.subtitle'.tr(),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]);

  Widget _welcome() {
    final suggestions = _suggestions.isNotEmpty
        ? _suggestions
        : ['assistant.suggest.page_usage'.tr(), 'assistant.suggest.missing_button'.tr()];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        const Center(child: AssistantAvatar(size: 64)),
        const SizedBox(height: 16),
        Text('assistant.welcome_title'.tr(),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('assistant.welcome_desc'.tr(),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B7280))),
        const SizedBox(height: 20),
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: _sending ? null : () => _send(s),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                foregroundColor: const Color(0xFF374151),
              ),
              child: Text(s, style: const TextStyle(fontSize: 13.5)),
            ),
          ),
      ],
    );
  }

  Widget _messageList() {
    final lastId = _messages.isEmpty ? null : _messages.last.id;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final showBubble =
            m.isUser || m.content.isNotEmpty || (m.thinking ?? '').isNotEmpty || m.toolSteps.isNotEmpty || m.images.isNotEmpty || m.forms.isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBubble) AssistantMessageBubble(message: m, streaming: _sending && m.id == lastId),
            if (!m.isUser && m.question != null)
              Padding(
                padding: const EdgeInsets.only(left: 42, bottom: 12),
                child: AssistantQuestionCard(
                  question: m.question!,
                  disabled: _sending,
                  onAnswer: (labels, values) => _answer(m.id, m.question!, labels, values),
                ),
              ),
            for (final f in m.forms) AssistantFormCardView(card: f, onOpen: () => _openForm(f.id)),
          ],
        );
      },
    );
  }

  Widget _composer() {
    final canSend = _input.text.trim().isNotEmpty || _image != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_image != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(clipBehavior: Clip.none, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(UriData.parse(_image!).contentAsBytes(), height: 64, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: InkWell(
                        onTap: () => setState(() => _image = null),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Color(0xFFEF4444),
                          child: Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            AssistantShortcutBar(
              shortcuts: _shortcuts,
              counts: _counts,
              canConfigure: _canConfigure,
              disabled: _sending,
              onView: (s) => _send(s.prompt ?? s.label, shortcut: s.key),
              onCreate: _openShortcut,
              onConfigured: () => _loadShortcuts(force: true),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'assistant.upload_image'.tr(),
                  onPressed: _sending ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined, color: Color(0xFF6B7280)),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'assistant.input_hint'.tr(),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: IconButton.filled(
                    onPressed: _sending ? _stop : (canSend ? () => _send(_input.text, image: _image) : null),
                    style: IconButton.styleFrom(
                      backgroundColor: _sending ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(_sending ? Icons.stop_rounded : Icons.send_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (widget.isEmbeddedInTab)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(children: [Expanded(child: _title()), _headerActions()]),
          ),
        Expanded(
          child: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? _welcome()
                  : _messageList(),
        ),
        _composer(),
      ],
    );
    if (widget.isEmbeddedInTab) return ColoredBox(color: const Color(0xFFF9FAFB), child: body);
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: _title(),
        actions: [_headerActions(), const SizedBox(width: 4)],
      ),
      body: body,
    );
  }
}
