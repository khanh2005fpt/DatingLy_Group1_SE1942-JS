import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../local/database_helper.dart';
import '../models/notification_item_model.dart';
import 'preferences_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId}');
  final notification = message.notification;
  if (notification != null) {
    try {
      await DatabaseHelper.instance.insertNotification(
        NotificationItemModel(
          notificationId: message.messageId ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          title: notification.title ?? 'DatingLy',
          body: notification.body ?? '',
          type: message.data['type'] ?? 'system',
          data: message.data.toString(),
          route: message.data['route'],
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Error saving background notification to SQLite: $e');
    }
  }
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final PreferencesService _prefs;

  // Stream controller để lắng nghe sự kiện người dùng bấm vào thông báo
  final StreamController<String> _notificationClickController =
      StreamController<String>.broadcast();
  Stream<String> get onNotificationClick => _notificationClickController.stream;

  NotificationService(this._prefs);

  Future<void> init() async {
    // 1. Đăng ký background handler cho FCM (chỉ native, web dùng service worker)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // 2. Yêu cầu quyền nhận thông báo từ người dùng
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
          'User notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    // 3. Khởi tạo Local Notifications để hiển thị khi app đang mở (Foreground)
    // Bỏ qua trên Web vì web không hỗ trợ flutter_local_notifications
    if (!kIsWeb) {
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

      try {
        await _localNotifications.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (response) {
            debugPrint('Local notification clicked: ${response.payload}');
            if (response.payload != null && response.payload!.isNotEmpty) {
              _notificationClickController.add(response.payload!);
            }
          },
        );
      } catch (e) {
        debugPrint('Error initializing local notifications: $e');
      }
    }

    // 4. Lấy và lưu FCM Token
    try {
      final token = await _fcm.getToken(
        vapidKey: kIsWeb
            ? 'BNDPi0Xj-0nNxNGW_4KlVjh8L-UJYGVBGkqCe0P4uUDhWzMLXkCM3-yJN7RBXJ4vlafqRc4gBJZf3x3WpqKWRs'
            : null,
      );
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

    // 6. Xử lý tin nhắn khi App ở Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification != null) {
        final title = notification.title ?? 'DatingLy';
        final body = notification.body ?? '';
        final type = message.data['type'] ?? 'system';
        final route = message.data['route'];

        // Lưu vào SQLite
        try {
          await DatabaseHelper.instance.insertNotification(
            NotificationItemModel(
              notificationId: message.messageId ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              body: body,
              type: type,
              data: message.data.toString(),
              route: route,
              createdAt: DateTime.now(),
            ),
          );
        } catch (e) {
          debugPrint('Error saving foreground notification: $e');
        }

        // Hiển thị notification popup nếu user bật thông báo
        if (_prefs.notificationsEnabled) {
          await showNotification(
            title: title,
            body: body,
            payload: route,
          );
        }
      }
    });

    // 7. Xử lý khi user bấm vào notification khi App đang ở Background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened from background: ${message.data}');
      final route = message.data['route'];
      if (route != null && route.toString().isNotEmpty) {
        _notificationClickController.add(route.toString());
      }
    });

    // 8. Xử lý khi user mở app từ notification lúc App bị Terminated hoàn toàn
    try {
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App launched from terminated notification: ${initialMessage.data}');
        final route = initialMessage.data['route'];
        if (route != null && route.toString().isNotEmpty) {
          // Delay nhỏ để router sẵn sàng nhận route
          Future.delayed(const Duration(milliseconds: 600), () {
            _notificationClickController.add(route.toString());
          });
        }
      }
    } catch (e) {
      debugPrint('Error handling initial terminated notification: $e');
    }
  }

  /// Hiển thị Local Notification trên thanh thông báo thiết bị
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Web không hỗ trợ flutter_local_notifications, dùng Web Notification API
    if (kIsWeb) {
      debugPrint('Web notification: $title - $body');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'datingly_main_channel',
      'Thông báo chung',
      channelDescription:
          'Kênh nhận thông báo tương hợp và tin nhắn của DatingLy',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// Ghi nhận thông báo nội bộ vào SQLite & hiển thị push (Match, Message, Like, System)
  Future<void> logAndShowNotification({
    required String title,
    required String body,
    required String type, // 'match', 'like', 'message', 'system'
    String? route,
    String? data,
  }) async {
    // 1. Lưu vào SQLite
    try {
      await DatabaseHelper.instance.insertNotification(
        NotificationItemModel(
          notificationId: '${type}_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          body: body,
          type: type,
          route: route,
          data: data,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Error logging notification to SQLite: $e');
    }

    // 2. Hiển thị thông báo nếu được bật
    if (_prefs.notificationsEnabled) {
      await showNotification(
        title: title,
        body: body,
        payload: route,
      );
    }
  }

  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  Future<String?> getDeviceToken() async {
    try {
      return await _fcm.getToken(
        vapidKey: kIsWeb
            ? 'BNDPi0Xj-0nNxNGW_4KlVjh8L-UJYGVBGkqCe0P4uUDhWzMLXkCM3-yJN7RBXJ4vlafqRc4gBJZf3x3WpqKWRs'
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _notificationClickController.close();
  }
}

