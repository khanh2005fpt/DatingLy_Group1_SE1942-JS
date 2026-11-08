import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/match_model.dart';
import '../../data/repositories/app_providers.dart';
import 'chat_view_model.dart';
import 'who_liked_me_view_model.dart';

part 'notification_bootstrap.g.dart';

/// Khởi chạy các luồng thông báo của app (watch 1 lần ở root widget):
///  1. Lưu FCM token vào Firestore (`users/{uid}.fcm_token`) khi đăng nhập / token đổi.
///  2. Lưu SQLite + hiện local notification khi có match mới hoặc tin nhắn mới.
///  3. Báo khi có người mới thích mình (Who Liked You).
@Riverpod(keepAlive: true)
void notificationBootstrap(Ref ref) {
  final notifications = ref.read(notificationRepositoryProvider);
  final userRepo = ref.read(userRepositoryProvider);
  final settings = ref.read(settingRepositoryProvider);

  // 1. Đồng bộ FCM token lên Firestore
  ref.listen(authStateChangesProvider, (previous, next) async {
    final uid = next.value?.uid;
    if (uid == null) return;
    final token = await notifications.getDeviceToken();
    if (token != null) {
      await settings.setFcmToken(token);
      await userRepo.updateFcmToken(uid, token);
    }
  }, fireImmediately: true);

  final tokenSub = notifications.onTokenRefresh.listen((token) async {
    final uid = ref.read(authStateChangesProvider).value?.uid;
    if (uid != null) await userRepo.updateFcmToken(uid, token);
  });
  ref.onDispose(tokenSub.cancel);

  // 2. Thông báo match mới / tin nhắn mới (Tự động lưu SQLite & push)
  ref.listen<AsyncValue<List<MatchModel>>>(matchesStreamProvider,
      (previous, next) {
    final before = previous?.value;
    final current = next.value;
    if (before == null || current == null) return; // lần đầu: chỉ lấy mốc
    if (!settings.notificationsEnabled) return;

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
      } else if (match.unreadCount > old.unreadCount &&
          // Đang mở đúng phòng chat đó thì không cần báo
          // riverpod 3.5 đánh dấu ref.exists deprecated nhưng API thay thế
          // (provider.exist) chưa có trong bản này.
          // ignore: deprecated_member_use
          !ref.exists(messagesStreamProvider(match.id))) {
        notifications.logAndShowNotification(
          title: name,
          body: match.lastMessage ?? 'Bạn có tin nhắn mới',
          type: 'message',
          route: '/chat/${match.id}',
        );
      }
    }
  });

  // 3. Lắng nghe lượt thích mới (Who Liked You) -> Tự động lưu SQLite & push
  ref.listen<WhoLikedMeState>(whoLikedMeViewModelProvider, (previous, next) {
    final prevCount = previous?.items.where((i) => !i.isMatched).length ?? 0;
    final nextCount = next.items.where((i) => !i.isMatched).length;
    if (previous != null && nextCount > prevCount && settings.notificationsEnabled) {
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
          route: '/likes',
        );
      } else {
        notifications.logAndShowNotification(
          title: 'Lượt thích mới! 💖',
          body: '$senderName vừa thích hồ sơ của bạn. Khám phá ngay!',
          type: 'like',
          route: '/likes',
        );
      }
    }
  });
}

