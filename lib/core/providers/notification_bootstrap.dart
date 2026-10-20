import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/match_model.dart';
import '../../features/chat/presentation/viewmodels/chat_view_model.dart';
import '../../features/activity/presentation/viewmodels/who_liked_me_view_model.dart';
import '../routes/app_router.dart';
import 'app_providers.dart';

/// Khởi chạy các luồng thông báo của app (watch 1 lần ở root widget):
///  1. Lưu FCM token vào Firestore (`users/{uid}.fcm_token`) khi đăng nhập / token đổi.
///  2. Hiện local notification và lưu vào SQLite khi có match mới hoặc tin nhắn mới.
///  3. Lắng nghe sự kiện click thông báo để điều hướng màn hình.
///  4. Hiện thông báo khi có người mới thích tài khoản (Who Liked You).
final notificationBootstrapProvider = Provider<void>((ref) {
  final notifications = ref.read(notificationServiceProvider);
  final firestore = ref.read(firestoreServiceProvider);
  final prefs = ref.read(preferencesServiceProvider);

  // 1. Đồng bộ FCM token lên Firestore
  ref.listen(authStateChangesProvider, (previous, next) async {
    final uid = next.value?.uid;
    if (uid == null) return;
    final token = await notifications.getDeviceToken();
    if (token != null) {
      await prefs.setFcmToken(token);
      await firestore.updateFcmToken(uid, token);
    }
  }, fireImmediately: true);

  final tokenSub = notifications.onTokenRefresh.listen((token) async {
    final uid = ref.read(authStateChangesProvider).value?.uid;
    if (uid != null) await firestore.updateFcmToken(uid, token);
  });
  ref.onDispose(tokenSub.cancel);

  // 2. Lắng nghe sự kiện click thông báo từ NotificationService để chuyển màn hình
  final clickSub = notifications.onNotificationClick.listen((route) {
    debugPrint('Navigating to route from notification: $route');
    try {
      AppRouter.router.push(route);
    } catch (e) {
      debugPrint('Navigation error from notification: $e');
    }
  });
  ref.onDispose(clickSub.cancel);

  // 3. Thông báo match mới / tin nhắn mới (Tự động lưu SQLite & push)
  ref.listen<AsyncValue<List<MatchModel>>>(matchesStreamProvider,
      (previous, next) {
    final before = previous?.value;
    final current = next.value;
    if (before == null || current == null) return; // lần đầu: chỉ lấy mốc
    if (!prefs.notificationsEnabled) return;

    final oldById = {for (final m in before) m.id: m};
    for (final match in current) {
      final old = oldById[match.id];
      final name = (match.otherProfile?.fullName.isNotEmpty ?? false)
          ? match.otherProfile!.fullName
          : 'Ai đó';

      if (old == null) {
        notifications.logAndShowNotification(
          title: 'Tương hợp mới! 🎉',
          body: 'Bạn và $name đã thích nhau. Nhắn tin ngay nhé!',
          type: 'match',
          route: '/chat/${match.id}',
        );
      } else if (match.unreadCount > old.unreadCount) {
        notifications.logAndShowNotification(
          title: name,
          body: match.lastMessage ?? 'Bạn có tin nhắn mới',
          type: 'message',
          route: '/chat/${match.id}',
        );
      }
    }
  });

  // 4. Lắng nghe lượt thích mới (Who Liked You) -> Tự động lưu SQLite & push
  ref.listen<WhoLikedMeState>(whoLikedMeViewModelProvider, (previous, next) {
    final prevCount = previous?.items.where((i) => !i.isMatched).length ?? 0;
    final nextCount = next.items.where((i) => !i.isMatched).length;
    if (previous != null && nextCount > prevCount && prefs.notificationsEnabled) {
      final newItems = next.items.where((n) =>
          !(previous.items.any((p) => p.user.id == n.user.id)));
      final isSuper = newItems.any((i) => i.isSuperLike);
      final firstNew = newItems.isNotEmpty ? newItems.first : null;
      final senderName = (firstNew != null && firstNew.user.fullName.isNotEmpty)
          ? firstNew.user.fullName
          : 'Ai đó';

      if (isSuper) {
        notifications.logAndShowNotification(
          title: 'Super Like mới! ⭐',
          body: '$senderName vừa tặng bạn một Super Like! Khám phá ngay!',
          type: 'like',
          route: '/who-liked-me',
        );
      } else {
        notifications.logAndShowNotification(
          title: 'Lượt thích mới! 💖',
          body: '$senderName vừa thích hồ sơ của bạn. Khám phá ngay!',
          type: 'like',
          route: '/who-liked-me',
        );
      }
    }
  });
});
