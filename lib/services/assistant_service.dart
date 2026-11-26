import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/app_i18n.dart';
import '../models/assistant_models.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

/// Lỗi gọi API Trợ lý, kèm câu đọc được của server.
class AssistantApiException implements Exception {
  final String message;
  final int? status;
  const AssistantApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Các sự kiện của luồng trả lời `POST /v1/chat` (web `VZ`).
class AssistantChatCallbacks {
  final void Function(String id)? onConversation;
  final void Function(String text)? onDelta;
  final void Function(String text)? onReasoning;
  final void Function(String step)? onStep;
  final void Function(Map<String, dynamic> file)? onFile;
  final void Function(Map<String, dynamic> action, String title)? onAction;
  final void Function(Map<String, dynamic> question)? onQuestion;
  final void Function(String message)? onError;

  const AssistantChatCallbacks({
    this.onConversation,
    this.onDelta,
    this.onReasoning,
    this.onStep,
    this.onFile,
    this.onAction,
    this.onQuestion,
    this.onError,
  });
}

/// API của Trợ lý Savina (savina-agent sau gateway, `/api/assistant/v1/...`) — khớp phần gọi API của bản web.
class AssistantService {
  static final AssistantService _instance = AssistantService._internal();
  factory AssistantService() => _instance;

  static const String _root = '/api/assistant';

  /// Trang gửi kèm để Trợ lý trả lời đúng ngữ cảnh (web gửi trang ERP đang mở; ứng dụng không có trang nền).
  static const String page = '/applications';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  AssistantService._internal() {
    ApiClientHelper.configureDio(_dio);
  }

  static final Options _lenient = Options(validateStatus: (s) => s != null && s < 600);

  /// Web `Ks`: câu lỗi của server, không có thì "Lỗi {mã}".
  static String errorOf(Response<dynamic> res) {
    final data = res.data;
    if (data is Map) {
      final message = data['detail'] ?? data['message'] ?? data['error'];
      if (message is String && message.isNotEmpty) return message;
    }
    if (data is String && data.isNotEmpty && data.length < 300) return data;
    return 'assistant.error_status'.tr(args: {'status': res.statusCode});
  }

  /// Gọi lại một lần sau khi làm mới phiên khi gặp 401 (web `Ws`).
  Future<Response<T>> _request<T>(Future<Response<T>> Function() send) async {
    var res = await send();
    if (res.statusCode == 401 && await AuthProvider.silentRelogin()) res = await send();
    return res;
  }

  Map<String, dynamic> _json(dynamic data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  /// `GET /v1/shortcuts?page=`: phím tắt, câu gợi ý, quyền cài đặt. Lỗi thì trả rỗng (web cũng vậy).
  Future<AssistantShortcutsData> getShortcuts() async {
    try {
      final res = await _request(() => _dio.get('$_root/v1/shortcuts', queryParameters: {'page': page}, options: _lenient));
      if (res.statusCode != 200) return const AssistantShortcutsData();
      final j = _json(res.data);
      return AssistantShortcutsData(
        shortcuts: [
          for (final s in (j['shortcuts'] as List? ?? const []))
            if (s is Map) AssistantShortcut.fromJson(Map<String, dynamic>.from(s)),
        ],
        suggestions: [for (final s in (j['suggestions'] as List? ?? const [])) if (s is String) s],
        canConfigure: j['can_configure'] == true,
      );
    } catch (e) {
      debugPrint('[AssistantService] getShortcuts: $e');
      return const AssistantShortcutsData();
    }
  }

  /// `GET /v1/shortcuts/counts?page=`: số trên phím "Xem nhanh".
  Future<Map<String, int>> getCounts() async {
    try {
      final res =
          await _request(() => _dio.get('$_root/v1/shortcuts/counts', queryParameters: {'page': page}, options: _lenient));
      if (res.statusCode != 200) return const {};
      return {
        for (final e in _json(res.data).entries)
          if (e.value is num) e.key: (e.value as num).toInt(),
      };
    } catch (_) {
      return const {};
    }
  }

  /// `GET /v1/shortcuts/settings`: toàn bộ phím của công ty và các phím đang tắt.
  Future<({List<AssistantShortcut> shortcuts, Set<String> disabled})> getSettings() async {
    final res = await _request(() => _dio.get('$_root/v1/shortcuts/settings', options: _lenient));
    if (res.statusCode != 200) throw AssistantApiException(errorOf(res), res.statusCode);
    final j = _json(res.data);
    return (
      shortcuts: [
        for (final s in (j['shortcuts'] as List? ?? const []))
          if (s is Map) AssistantShortcut.fromJson(Map<String, dynamic>.from(s)),
      ],
      disabled: {for (final k in (j['disabled'] as List? ?? const [])) k.toString()},
    );
  }

  /// `PUT /v1/shortcuts/settings {disabled}`.
  Future<void> saveSettings(Set<String> disabled) async {
    final res = await _request(
        () => _dio.put('$_root/v1/shortcuts/settings', data: {'disabled': disabled.toList()}, options: _lenient));
    if (res.statusCode != 200) throw AssistantApiException(errorOf(res), res.statusCode);
  }

  /// `POST /v1/shortcuts/:key/open {value?}`: trả `{action, title}` (mở thẻ form) hoặc `{href}` (mở trang ERP).
  Future<Map<String, dynamic>> openShortcut(String key, [String? value]) async {
    final res = await _request(() => _dio.post('$_root/v1/shortcuts/${Uri.encodeComponent(key)}/open',
        data: value == null ? <String, dynamic>{} : {'value': value}, options: _lenient));
    if (res.statusCode != 200) throw AssistantApiException(errorOf(res), res.statusCode);
    return _json(res.data);
  }

  /// `POST /v1/chat` (luồng SSE). [body] theo web: message, conversation_id, images, deep_thinking, page, shortcut,
  /// open_forms, answer. Ném [AssistantApiException] khi server từ chối; huỷ bằng [cancelToken].
  Future<void> chat(Map<String, dynamic> body, AssistantChatCallbacks cb, {CancelToken? cancelToken}) async {
    final res = await _request(() => _dio.post<ResponseBody>(
          '$_root/v1/chat',
          data: body,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Accept': 'text/event-stream'},
            receiveTimeout: const Duration(minutes: 5),
            validateStatus: (s) => s != null && s < 600,
          ),
        ));
    final stream = res.data?.stream;
    if (res.statusCode != 200 || stream == null) {
      var message = 'assistant.error_status'.tr(args: {'status': res.statusCode});
      try {
        final raw = await utf8.decoder.bind(stream ?? const Stream<List<int>>.empty()).join();
        final decoded = jsonDecode(raw);
        if (decoded is Map && (decoded['detail'] ?? decoded['message']) is String) {
          message = (decoded['detail'] ?? decoded['message']) as String;
        }
      } catch (_) {}
      throw AssistantApiException(message, res.statusCode);
    }
    var buffer = '';
    await for (final chunk in utf8.decoder.bind(stream)) {
      buffer += chunk.replaceAll('\r\n', '\n');
      int index;
      while ((index = buffer.indexOf('\n\n')) >= 0) {
        final block = buffer.substring(0, index);
        buffer = buffer.substring(index + 2);
        final event = RegExp(r'^event: (.*)$', multiLine: true).firstMatch(block)?.group(1);
        final dataLine = RegExp(r'^data: (.*)$', multiLine: true).firstMatch(block)?.group(1);
        if (event == null || dataLine == null) continue;
        dynamic data;
        try {
          data = jsonDecode(dataLine);
        } catch (_) {
          continue;
        }
        final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        switch (event) {
          case 'conversation':
            cb.onConversation?.call(map['id']?.toString() ?? '');
          case 'delta':
            cb.onDelta?.call(map['text']?.toString() ?? '');
          case 'reasoning':
            cb.onReasoning?.call(map['text']?.toString() ?? '');
          case 'status':
            cb.onStep?.call(map['message']?.toString() ?? '');
          case 'tool_start':
            cb.onStep?.call(toolLabel(map['name']?.toString() ?? '', map['arguments']));
          case 'tool_end':
            if (map['ok'] != true) {
              cb.onStep?.call('assistant.tool_failed'.tr(args: {'tool': _toolName(map['name']?.toString() ?? '')}));
            }
          case 'file':
            cb.onFile?.call(map);
          case 'action':
            final action = map['action'];
            if (action is Map) cb.onAction?.call(Map<String, dynamic>.from(action), map['title']?.toString() ?? '');
          case 'question':
            if (map['id'] != null && map['options'] is List) cb.onQuestion?.call(map);
          case 'error':
            cb.onError?.call(map['message']?.toString() ?? '');
        }
      }
    }
  }

  static const Set<String> _knownTools = {
    'huong_dan_su_dung',
    'search_documents',
    'erp_read',
    'execute_code',
    'mo_form',
    'hoi_nguoi_dung',
    'tra_cuu_erp',
  };

  static String _toolName(String name) =>
      _knownTools.contains(name) ? 'assistant.tool.$name'.tr() : 'assistant.tool_call'.tr(args: {'tool': name});

  /// Web `GZ`: tên bước công cụ, kèm nguồn đọc (erp_read) hoặc câu truy vấn.
  static String toolLabel(String name, dynamic arguments) {
    final label = _toolName(name);
    final args = arguments is Map ? arguments : const {};
    if (name == 'erp_read' && args['source'] is String) return '$label: ${args['source']}';
    if (args['query'] is String) {
      final q = args['query'] as String;
      return '$label: “${q.length > 60 ? q.substring(0, 60) : q}”';
    }
    return label;
  }

  /// Đường dẫn tệp của Trợ lý (web `ur`): đường dẫn tương đối nằm dưới `/api/assistant`.
  static String resolveUrl(String url) {
    if (RegExp(r'^(https?:|data:|blob:)').hasMatch(url)) return url;
    return '${AuthProvider.authBaseUrl}$_root${url.startsWith('/') ? url : '/$url'}';
  }

  /// Header phiên đăng nhập cho ảnh/tệp của Trợ lý.
  static Future<Map<String, String>> authHeaders() async {
    final cookies = await AuthProvider.getStoredCookies();
    return {if (cookies != null && cookies.isNotEmpty) 'cookie': cookies};
  }

  /// Tải một tệp của Trợ lý (cần phiên đăng nhập) về [savePath].
  Future<void> download(String url, String savePath) async {
    final res = await _request(() => _dio.download(resolveUrl(url), savePath, options: _lenient));
    if (res.statusCode != 200) throw AssistantApiException(errorOf(res), res.statusCode);
  }

  // ---- Lưu cuộc trò chuyện (web `XA`/`zZ`: theo người dùng + công ty, tối đa 100 tin) ----

  String get _storeKey {
    final auth = AuthProvider.instance;
    return 'sa_chat:${auth?.tenantId ?? ''}:${auth?.userId ?? ''}:portal';
  }

  Future<({String? conversationId, List<AssistantChatMessage> messages})> loadConversation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw == null) return (conversationId: null, messages: const <AssistantChatMessage>[]);
      final j = jsonDecode(raw);
      if (j is! Map) return (conversationId: null, messages: const <AssistantChatMessage>[]);
      return (
        conversationId: j['conversationId'] is String ? j['conversationId'] as String : null,
        messages: [
          for (final m in (j['messages'] as List? ?? const []))
            if (m is Map) AssistantChatMessage.fromJson(Map<String, dynamic>.from(m)),
        ],
      );
    } catch (_) {
      return (conversationId: null, messages: const <AssistantChatMessage>[]);
    }
  }

  Future<void> saveConversation(String? conversationId, List<AssistantChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kept = messages.length > 100 ? messages.sublist(messages.length - 100) : messages;
      if (kept.isEmpty && conversationId == null) {
        await prefs.remove(_storeKey);
        return;
      }
      await prefs.setString(
          _storeKey, jsonEncode({'conversationId': conversationId, 'messages': [for (final m in kept) m.toJson()]}));
    } catch (_) {}
  }

  Future<void> clearConversation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storeKey);
    } catch (_) {}
  }

  /// Tab phím tắt đang chọn (web `sa_shortcut_tab`).
  Future<String> loadShortcutTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('sa_shortcut_tab') == 'create' ? 'create' : 'view';
    } catch (_) {
      return 'view';
    }
  }

  Future<void> saveShortcutTab(String tab) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sa_shortcut_tab', tab);
    } catch (_) {}
  }
}
