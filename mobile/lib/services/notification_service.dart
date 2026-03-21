import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, VoidCallback, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_base.dart';
import 'device_id_service.dart';
import 'package:lunaura/firebase_options.dart';

const String _keyPromptShown = 'notification_prompt_shown';

/// Arka planda gelen FCM mesajı (isolate'ta çalışır).
/// `main()` içinde `runApp` öncesi `FirebaseMessaging.onBackgroundMessage` ile kaydedilmeli.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  if (message.notification != null) {
    await NotificationService._showLocalNotification(
      title: message.notification!.title ?? 'LunAura',
      body: message.notification!.body ?? '',
    );
  }
}

class NotificationService {
  static bool get _canUseFirebaseMessaging =>
      !kIsWeb && Firebase.apps.isNotEmpty;

  /// Bildirime tıklanınca UI tarafında okunacak callback.
  static VoidCallback? onOpenReadingsRequested;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'reading_ready',
    'Yorum bildirimleri',
    description: 'Okuma yorumunuz hazır olduğunda bildirim',
    importance: Importance.high,
  );

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    // Web'de FCM/local notifications mobil gibi çalışmaz; uygulama çökmesin diye atla.
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      final initSettings = InitializationSettings(
        android: android,
        iOS: darwin,
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
      }

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Android + iOS: izin iste ve token'ı backend'e yaz.
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await _requestPermissionAndRegister();
      } else {
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          await _requestPermissionAndRegister();
        }
      }
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerTokenWithBackend);
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showLocalNotification(
            title: message.notification!.title ?? 'LunAura',
            body: message.notification!.body ?? '',
          );
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        _notifyOpenReadingsRequested();
      });
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _notifyOpenReadingsRequested();
      }
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[NotificationService] FCM init OK');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[NotificationService] init error: $e\n$st');
      }
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    _notifyOpenReadingsRequested();
  }

  static void _notifyOpenReadingsRequested() {
    final cb = onOpenReadingsRequested;
    if (cb == null) return;
    try {
      cb();
    } catch (_) {}
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    final android = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(android: android, iOS: ios);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  static Future<void> _requestPermissionAndRegister() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // Android: kullanıcı reddetse bile FCM token çoğu cihazda üretilir; backend'de tutulsun (sonra izin açılınca çalışır).
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null && token.isNotEmpty) {
            await _registerTokenWithBackend(token);
          }
        } catch (_) {}
      }
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerTokenWithBackend(token);
    }
  }

  static Future<void> _registerTokenWithBackend(String token) async {
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final uri = Uri.parse('${ApiBase.baseUrl}/notifications/register');
      final res = await http
          .post(
            uri,
            headers: ApiBase.headers(deviceId: deviceId),
            body: jsonEncode({'fcm_token': token}),
          )
          .timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        debugPrint(
            '[NotificationService] register FCM: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] register error: $e');
    }
  }

  /// İzin henüz verilmemiş ve dialog daha önce gösterilmediyse true.
  static Future<bool> shouldShowNotificationPrompt() async {
    if (kIsWeb) return false;
    if (!_canUseFirebaseMessaging) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_keyPromptShown) == true) return false;
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcı "Bildirimleri aç" dediğinde: izin iste ve token'ı backend'e kaydet.
  static Future<void> requestPermissionAndRegister() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPromptShown, true);
    if (!_canUseFirebaseMessaging) return;
    await _requestPermissionAndRegister();
  }

  /// Dialog gösterildi ama kullanıcı "Şimdi değil" dediğinde sadece gösterildi işaretle.
  static Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPromptShown, true);
  }
}
