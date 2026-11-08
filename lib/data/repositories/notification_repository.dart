import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../local/database_helper.dart';
import '../models/notification_item_model.dart';
import 'setting_repository.dart';

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

/// NotificationRepository: Quản lý thông báo đẩy Firebase Cloud Messaging & Local Notifications (PRM393 MVVM Pattern)
class NotificationRepository {
  /// Channel Android mức cao: server push (tools/push_server) chỉ định channel này.
  static const String mainChannelId = 'datingly_main_channel';
  static const String mainChannelName = 'Thông báo chung';
  static const String mainChannelDescription =
      'Kênh nhận thông báo tương hợp và tin nhắn của DatingLy';

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SettingRepository _settingRepository;

  /// Được gọi khi người dùng bấm vào thông báo (route như `/chat/{id}` hoặc `/likes`).
  void Function(String route)? onRoute;

  NotificationRepository(this._settingRepository);

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
            final route = response.payload;
            if (route != null && route.startsWith('/')) onRoute?.call(route);
          },
        );
      } catch (e) {
        debugPrint('Error initializing local notifications: $e');
      }
    }

    // Tạo channel mức cao để thông báo FCM khi app ở nền cũng hiện popup
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            mainChannelId,
            mainChannelName,
            description: mainChannelDescription,
            importance: Importance.max,
          ),
        );

    // 4. Lấy và lưu FCM Token
    try {
      final token = await _fcm.getToken(
        vapidKey: kIsWeb
            ? 'BNDPi0Xj-0nNxNGW_4KlVjh8L-UJYGVBGkqCe0P4uUDhWzMLXkCM3-yJN7RBXJ4vlafqRc4gBJZf3x3WpqKWRs'
            : null,
      );
      if (token != null) {
        await _settingRepository.setFcmToken(token);
        debugPrint('FCM Device Token: $token');
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    // 5. Lắng nghe thay đổi token
    _fcm.onTokenRefresh.listen((newToken) {
      _settingRepository.setFcmToken(newToken);
    });

    // 6. Xử lý tin nhắn khi App ở Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) return;
      // Match và tin nhắn mới đã được notification_bootstrap lưu + hiện khi app đang mở
      // (có kiểm tra "đang mở đúng phòng chat"), nên bỏ qua để không báo trùng.
      final type = message.data['type'];
      if (type == 'match' || type == 'message') return;

      // Lưu vào SQLite (Trung tâm thông báo) rồi hiện popup nếu đang bật
      await logAndShowNotification(
        title: notification.title ?? 'DatingLy Thông báo',
        body: notification.body ?? '',
        type: type ?? 'system',
        route: message.data['route'],
        data: message.data.toString(),
      );
    });

    // 7. Bấm vào thông báo FCM khi app đang ở nền -> mở đúng màn hình
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final route = message.data['route'];
      if (route is String && route.startsWith('/')) onRoute?.call(route);
    });
  }

  /// Gọi sau khi UI đã chạy: nếu app được mở từ thông báo (lúc đã tắt hẳn) thì mở đúng màn hình.
  Future<void> handleInitialMessage() async {
    try {
      final message = await _fcm.getInitialMessage();
      final route = message?.data['route'];
      if (route is String && route.startsWith('/')) onRoute?.call(route);
    } catch (e) {
      debugPrint('getInitialMessage lỗi: $e');
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
      mainChannelId,
      mainChannelName,
      channelDescription: mainChannelDescription,
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
    if (_settingRepository.notificationsEnabled) {
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
}

