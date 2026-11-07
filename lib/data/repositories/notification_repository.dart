import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'setting_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId}');
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
        final route = response.payload;
        if (route != null && route.startsWith('/')) onRoute?.call(route);
      },
    );

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
      final token = await _fcm.getToken();
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

    // 6. Lắng nghe tin nhắn khi App đang ở Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null || !_settingRepository.notificationsEnabled) {
        return;
      }
      // Match và tin nhắn mới đã được notification_bootstrap hiện khi app đang mở
      // (có kiểm tra "đang mở đúng phòng chat"), nên bỏ qua để không báo trùng.
      final type = message.data['type'];
      if (type == 'match' || type == 'message') return;

      showNotification(
        title: notification.title ?? 'DatingLy Thông báo',
        body: notification.body ?? '',
        payload: message.data['route'],
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

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
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

