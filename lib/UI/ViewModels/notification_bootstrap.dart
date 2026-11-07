import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/match_model.dart';
import '../../data/repositories/app_providers.dart';
import 'chat_view_model.dart';

/// Khởi chạy các luồng thông báo của app (watch 1 lần ở root widget):
///  1. Lưu FCM token vào Firestore (`users/{uid}.fcm_token`) khi đăng nhập / token đổi.
///  2. Hiện local notification khi có match mới hoặc tin nhắn mới.
final notificationBootstrapProvider = Provider<void>((ref) {
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

  // 2. Thông báo match mới / tin nhắn mới
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
        notifications.showNotification(
          title: 'Tương hợp mới! 🎉',
          body: 'Bạn và $name đã thích nhau. Nhắn tin ngay nhé!',
          payload: '/chat/${match.id}',
        );
      } else if (match.unreadCount > old.unreadCount &&
          // Đang mở đúng phòng chat đó thì không cần báo
          !ref.exists(messagesStreamProvider(match.id))) {
        notifications.showNotification(
          title: name,
          body: match.lastMessage ?? 'Bạn có tin nhắn mới',
          payload: '/chat/${match.id}',
        );
      }
    }
  });
});

