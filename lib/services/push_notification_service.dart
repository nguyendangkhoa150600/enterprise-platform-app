import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../providers/auth_provider.dart';
import 'api_client_helper.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[PushNotificationService] Handling background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._() {
    _dio = Dio(BaseOptions(
      baseUrl: AuthProvider.authBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ));
    ApiClientHelper.configureDio(_dio);
  }

  static final PushNotificationService instance = PushNotificationService._();

  late final Dio _dio;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Android Notification Channel for Heads-up notifications
  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'svn_erp_high_importance_channel',
    'SVN ERP Notifications',
    description: 'Kênh nhận thông báo quan trọng từ hệ thống SVN ERP',
    importance: Importance.max,
    playSound: true,
  );

  /// Callback when a notification is tapped by the user
  void Function(Map<String, dynamic> data)? onNotificationTapped;

  Future<void> init({void Function(Map<String, dynamic> data)? onNotificationTapped}) async {
    this.onNotificationTapped = onNotificationTapped;

    try {
      // 1. Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Set Background Message Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Request permissions
      await _requestPermissions();

      // 4. Setup Local Notifications (for Foreground)
      await _setupLocalNotifications();

      // 5. Get and log FCM Token
      await _retrieveToken();

      // 6. Listen for Token updates
      // ignore: deprecated_member_use
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[PushNotificationService] Token refreshed: $newToken');
        registerDeviceToken(token: newToken);
      });

      // 7. Auto register token if user is already logged in
      registerDeviceToken();

      // 8. Configure Message Listeners
      _setupMessageListeners();
    } catch (e, stack) {
      debugPrint('[PushNotificationService] Initialization error: $e\n$stack');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[PushNotificationService] Permission status: ${settings.authorizationStatus}');

      // For iOS foreground notifications presentation
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Request permission error: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final dynamic decoded = jsonDecode(payload);
              if (decoded is Map<String, dynamic>) {
                _handleNotificationPayload(decoded);
                return;
              }
            } catch (_) {}
            _handleNotificationPayload({'payload': payload});
          }
        },
      );

      // Create Android Channel
      if (!kIsWeb && Platform.isAndroid) {
        final androidImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(_androidChannel);
          await androidImplementation.requestNotificationsPermission();
        }
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Setup local notifications error: $e');
    }
  }

  Future<String?> _retrieveToken() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        String? apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _fcm.getAPNSToken();
        }
        debugPrint('[PushNotificationService] APNs Token: $apnsToken');
      }

      // ignore: deprecated_member_use
      _fcmToken = await _fcm.getToken();
      debugPrint('====================================================');
      debugPrint('[FCM TOKEN] -> $_fcmToken');
      debugPrint('====================================================');
      return _fcmToken;
    } catch (e) {
      debugPrint('[PushNotificationService] Get token error: $e');
      return null;
    }
  }

  /// Persistent Device Identifier for matching backend records
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('push_device_id');
    if (id == null || id.isEmpty) {
      final random = DateTime.now().millisecondsSinceEpoch.toString();
      final platform = Platform.isIOS ? 'ios' : 'android';
      id = 'svn-$platform-$random';
      await prefs.setString('push_device_id', id);
    }
    return id;
  }

  /// 2.1. Đăng ký / Cập nhật FCM Token thiết bị lên Backend
  /// Endpoint: POST /api/platform/v1/push/devices
  Future<bool> registerDeviceToken({String? token}) async {
    final targetToken = token ?? _fcmToken;
    if (targetToken == null || targetToken.trim().isEmpty) return false;

    final cookies = await AuthProvider.getStoredCookies();
    if (cookies == null || cookies.isEmpty) {
      debugPrint('[PushNotificationService] Skip registration: user not logged in yet');
      return false;
    }

    try {
      final deviceId = await _getDeviceId();
      final platform = Platform.isIOS ? 'ios' : 'android';

      debugPrint('[PushNotificationService] Registering device token to server (Platform: $platform, Device: $deviceId)...');
      final response = await _dio.post(
        '/platform/v1/push/devices',
        data: {
          'token': targetToken.trim(),
          'platform': platform,
          'deviceId': deviceId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('[PushNotificationService] FCM token registered to server successfully ✓');
        return true;
      }
    } catch (e) {
      debugPrint('[PushNotificationService] registerDeviceToken error: $e');
    }
    return false;
  }

  /// 2.2. Huỷ đăng ký FCM Token (khi đăng xuất hoặc tắt thông báo)
  /// Endpoint: DELETE /api/platform/v1/push/devices
  Future<bool> unregisterDeviceToken({String? token}) async {
    final targetToken = token ?? _fcmToken;
    try {
      final deviceId = await _getDeviceId();
      debugPrint('[PushNotificationService] Unregistering device token from server...');
      final response = await _dio.delete(
        '/platform/v1/push/devices',
        data: {
          if (targetToken != null && targetToken.isNotEmpty) 'token': targetToken.trim(),
          'deviceId': deviceId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('[PushNotificationService] FCM token unregistered from server successfully ✓');
        return true;
      }
    } catch (e) {
      debugPrint('[PushNotificationService] unregisterDeviceToken error: $e');
    }
    return false;
  }

  /// 2.3. Kiểm tra trạng thái cấu hình FCM của tài khoản trên Server
  /// Endpoint: GET /api/platform/v1/push/status
  Future<Map<String, dynamic>?> checkStatus() async {
    try {
      final response = await _dio.get('/platform/v1/push/status');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? Map<String, dynamic>.from(response.data) : null;
        debugPrint('[PushNotificationService] Server push status: $data');
        return data;
      }
    } catch (e) {
      debugPrint('[PushNotificationService] checkStatus error: $e');
    }
    return null;
  }

  void _setupMessageListeners() {
    // 1. Foreground message: Show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[PushNotificationService] Foreground message received: ${message.messageId}');
      final notification = message.notification;
      final android = message.notification?.android;

      final title = notification?.title ?? message.data['title']?.toString() ?? 'SVN ERP';
      final body = notification?.body ?? message.data['body']?.toString() ?? '';

      _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // 2. App opened from background by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[PushNotificationService] App opened from background notification: ${message.data}');
      _handleNotificationPayload(message.data);
    });

    // 3. App opened from terminated state by tapping notification
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[PushNotificationService] App launched from terminated state: ${message.data}');
        _handleNotificationPayload(message.data);
      }
    });
  }

  void _handleNotificationPayload(Map<String, dynamic> data) {
    if (onNotificationTapped != null) {
      onNotificationTapped!(data);
    }
  }
}
