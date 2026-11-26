import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:web_socket/io_web_socket.dart' show IOWebSocket;
import 'package:web_socket/web_socket.dart' as ws;

import '../../providers/auth_provider.dart';

/// Nhận `data` của bao thư realtime (`RealtimeEventEnvelope.data` trên web).
typedef RealtimeDataHandler = void Function(Map<String, dynamic> data);

/// Kết nối realtime dùng chung (web `notification-client.ts` + `realtime-bus.ts`): MỘT socket.io tới realtime-api
/// (`/realtime/socket.io`, chỉ websocket), xác thực bằng cookie phiên như trình duyệt. Chỉ là hạ tầng, không có UI.
///
/// - Kết nối lười: mở khi có người nghe đầu tiên, đóng khi người nghe cuối cùng huỷ.
/// - Cookie được đọc lại mỗi lần mở websocket (kể cả tự nối lại), nên phiên vừa gia hạn vẫn dùng được.
/// - App vào nền lâu thì đóng; quay lại thì nối lại và báo `onReconnected` để màn hình tải bù phần đã lỡ
///   (web: `connected = true` → huỷ bộ nhớ đệm).
/// - Mọi lỗi kết nối đều bị nuốt (chỉ debugPrint): realtime là phụ, màn hình vẫn có đường tải qua API.
class RealtimeService with WidgetsBindingObserver {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  static const String socketPath = '/realtime/socket.io';

  /// Ở nền quá ngần này thì đóng socket (hệ điều hành cũng sẽ cắt), quay lại thì nối lại.
  static const Duration _backgroundGrace = Duration(seconds: 30);

  final Map<String, Set<RealtimeDataHandler>> _handlers = {};
  final Set<VoidCallback> _reconnectHandlers = {};
  int _listeners = 0;

  /// Tăng mỗi lần [reset]: hàm huỷ của đăng ký cũ không được trừ vào đếm của đăng ký mới.
  int _generation = 0;

  sio.Socket? _socket;
  bool _observing = false;
  bool _hasConnected = false;
  Timer? _backgroundTimer;

  bool get isConnected => _socket?.connected ?? false;

  /// Nghe sự kiện [event] (vd. `workspace.chat.changed`). [onReconnected] được gọi mỗi lần socket nối lại sau
  /// khi đã từng nối (có thể đã lỡ tín hiệu). Trả về hàm huỷ đăng ký — gọi trong `dispose()`.
  VoidCallback listen(String event, RealtimeDataHandler onData, {VoidCallback? onReconnected}) {
    final handlers = _handlers.putIfAbsent(event, () => <RealtimeDataHandler>{});
    final isNewEvent = handlers.isEmpty;
    handlers.add(onData);
    if (onReconnected != null) _reconnectHandlers.add(onReconnected);
    _listeners++;
    if (isNewEvent) _bindEvent(event);
    if (_listeners == 1) {
      _observe();
      _connect();
    }
    final generation = _generation;
    var cancelled = false;
    return () {
      if (cancelled || generation != _generation) return;
      cancelled = true;
      handlers.remove(onData);
      if (onReconnected != null) _reconnectHandlers.remove(onReconnected);
      _listeners--;
      if (_listeners <= 0) {
        _listeners = 0;
        _teardown();
      }
    };
  }

  /// Đăng xuất / đổi tổ chức: đóng socket và bỏ mọi người nghe (màn hình còn mở sẽ đăng ký lại khi dựng lại).
  void reset() {
    _generation++;
    _handlers.clear();
    _reconnectHandlers.clear();
    _listeners = 0;
    _teardown();
  }

  void _observe() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void _teardown() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _closeSocket();
  }

  void _connect() {
    try {
      final socket = _socket ?? _createSocket();
      if (!socket.connected) socket.connect();
    } catch (e) {
      debugPrint('[Realtime] connect failed: $e');
    }
  }

  sio.Socket _createSocket() {
    _hasConnected = false;
    final socket = sio.io(
      AuthProvider.authBaseUrl,
      sio.OptionBuilder()
          .setPath(socketPath)
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .setRandomizationFactor(1)
          .setWebSocketConnector(_openWebSocket)
          .build(),
    );
    socket.onConnect((_) {
      debugPrint('[Realtime] connected');
      final again = _hasConnected;
      _hasConnected = true;
      if (again) {
        for (final handler in List<VoidCallback>.of(_reconnectHandlers)) {
          _safely(handler);
        }
      }
    });
    socket.onConnectError((e) => debugPrint('[Realtime] connect_error: $e'));
    socket.onDisconnect((reason) => debugPrint('[Realtime] disconnected: $reason'));
    socket.on('session.revoked', (_) => debugPrint('[Realtime] session revoked'));
    for (final event in _handlers.keys) {
      _bindEvent(event, socket);
    }
    _socket = socket;
    return socket;
  }

  void _bindEvent(String event, [sio.Socket? target]) {
    final socket = target ?? _socket;
    if (socket == null) return;
    // Mỗi tên sự kiện chỉ một bộ nghe trên socket; người nghe thật nằm trong [_handlers].
    socket.off(event);
    socket.on(event, (payload) => _dispatch(event, payload));
  }

  void _dispatch(String event, dynamic payload) {
    // Máy chủ gửi (bao thư, offset khôi phục) → client nhận List; chỉ cần bao thư.
    final envelope = payload is List ? (payload.isEmpty ? null : payload.first) : payload;
    if (envelope is! Map) return;
    final data = envelope['data'];
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    for (final handler in List<RealtimeDataHandler>.of(_handlers[event] ?? const {})) {
      try {
        handler(map);
      } catch (e) {
        // Một người nghe lỗi không được chặn những người còn lại (web realtime-bus).
        debugPrint('[Realtime] handler for $event failed: $e');
      }
    }
  }

  void _closeSocket() {
    final socket = _socket;
    _socket = null;
    _hasConnected = false;
    if (socket == null) return;
    try {
      socket.dispose();
    } catch (e) {
      debugPrint('[Realtime] dispose failed: $e');
    }
  }

  /// Mở websocket với cookie MỚI NHẤT và Origin như trình duyệt (máy chủ kiểm Origin + cookie trong handshake).
  /// Bỏ qua lỗi chứng chỉ giống Dio của app (máy chủ thử nghiệm).
  static Future<ws.WebSocket> _openWebSocket(Uri uri, {Iterable<String>? protocols, Map<String, String>? headers}) async {
    final cookies = await AuthProvider.getStoredCookies();
    final client = io.HttpClient()..badCertificateCallback = (cert, host, port) => true;
    try {
      final socket = await io.WebSocket.connect(
        uri.toString(),
        protocols: protocols,
        headers: {
          ...?headers,
          if (cookies != null && cookies.isNotEmpty) 'cookie': cookies,
          'Origin': AuthProvider.authBaseUrl,
        },
        customClient: client,
      );
      return IOWebSocket.fromWebSocket(socket);
    } on io.WebSocketException catch (e) {
      throw ws.WebSocketException(e.message);
    }
  }

  static void _safely(VoidCallback fn) {
    try {
      fn();
    } catch (e) {
      debugPrint('[Realtime] reconnect handler failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_listeners == 0) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundTimer ??= Timer(_backgroundGrace, () {
        _backgroundTimer = null;
        _closeSocket();
      });
    } else if (state == AppLifecycleState.resumed) {
      _backgroundTimer?.cancel();
      _backgroundTimer = null;
      final wasClosed = _socket == null;
      _connect();
      // Socket mới sau thời gian ở nền: đã có thể lỡ tín hiệu, báo người nghe tải bù khi nối được.
      if (wasClosed) _hasConnected = true;
    }
  }
}
