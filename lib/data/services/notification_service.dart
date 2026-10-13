import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'preferences_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId}');
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final PreferencesService _prefs;

  NotificationService(this._prefs);

  Future<void> init() async {
    // 1. Đăng ký background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Yêu cầu quyền nhận thông báo
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('User notification permission status: ${settings.authorizationStatus}');

    // 3. Khởi tạo Local Notifications để hiển thị khi app đang mở (Foreground)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // 4. Lấy và lưu FCM Token
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _prefs.setFcmToken(token);
        debugPrint('FCM Device Token: $token');
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    // 5. Lắng nghe thay đổi token
    _fcm.onTokenRefresh.listen((newToken) {
      _prefs.setFcmToken(newToken);
    });

    // 6. Lắng nghe tin nhắn khi App đang ở Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null && _prefs.notificationsEnabled) {
        showNotification(
          title: notification.title ?? 'DatingLy Thông báo',
          body: notification.body ?? '',
          payload: message.data['route'],
        );
      }
    });
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'datingly_main_channel',
      'Thông báo chung',
      channelDescription: 'Kênh nhận thông báo tương hợp và tin nhắn của DatingLy',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  Future<String?> getDeviceToken() async {
    try {
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }
}
