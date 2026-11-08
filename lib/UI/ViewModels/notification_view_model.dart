import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/notification_item_model.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/repositories/activity_repository.dart';

part 'notification_view_model.g.dart';

class NotificationState {
  final List<NotificationItemModel> notifications;
  final int unreadCount;
  final String currentFilter; // 'all', 'match', 'like', 'message', 'system'
  final bool isLoading;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.currentFilter = 'all',
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<NotificationItemModel>? notifications,
    int? unreadCount,
    String? currentFilter,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      currentFilter: currentFilter ?? this.currentFilter,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@Riverpod(keepAlive: true)
class NotificationViewModel extends _$NotificationViewModel {
  ActivityRepository get _repository => ref.read(activityRepositoryProvider);

  @override
  NotificationState build() {
    // Tự động load danh sách thông báo khi khởi tạo
    Future.microtask(loadNotifications);
    return const NotificationState(isLoading: true);
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true);
    final filter = state.currentFilter == 'all' ? null : state.currentFilter;
    final items = await _repository.getAllNotifications(typeFilter: filter);
    final unread = await _repository.getUnreadNotificationCount();

    state = state.copyWith(
      notifications: items,
      unreadCount: unread,
      isLoading: false,
    );
  }

  Future<void> setFilter(String filter) async {
    if (state.currentFilter == filter) return;
    state = state.copyWith(currentFilter: filter, isLoading: true);
    final typeFilter = filter == 'all' ? null : filter;
    final items = await _repository.getAllNotifications(typeFilter: typeFilter);
    final unread = await _repository.getUnreadNotificationCount();

    state = state.copyWith(
      notifications: items,
      unreadCount: unread,
      isLoading: false,
    );
  }

  Future<void> markAsRead(int id) async {
    await _repository.markNotificationAsRead(id);
    await loadNotifications();
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllNotificationsAsRead();
    await loadNotifications();
  }

  Future<void> deleteNotification(int id) async {
    await _repository.deleteNotification(id);
    await loadNotifications();
  }

  Future<void> clearAll() async {
    await _repository.clearAllNotifications();
    await loadNotifications();
  }

  /// Thêm thông báo giả lập để demo / kiểm thử tính năng ngay trên giao diện
  Future<void> addDemoNotification({
    required String type,
    required String title,
    required String body,
    String? route,
  }) async {
    final notification = NotificationItemModel(
      notificationId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      route: route,
      createdAt: DateTime.now(),
    );
    await _repository.insertNotification(notification);

    // Bắn local notification nếu cài đặt đang bật
    try {
      await _repository.showLocalNotification(
        title: title,
        body: body,
        payload: route,
      );
    } catch (_) {}

    await loadNotifications();
  }
}

/// Số thông báo chưa đọc cho badge trên App Bar.
@Riverpod(keepAlive: true)
int unreadNotificationCount(Ref ref) =>
    ref.watch(notificationViewModelProvider).unreadCount;
