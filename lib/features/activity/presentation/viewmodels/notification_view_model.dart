import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/database_helper.dart';
import '../../../../data/models/notification_item_model.dart';
import '../../../../core/providers/app_providers.dart';

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

class NotificationViewModel extends Notifier<NotificationState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  NotificationState build() {
    // Tự động load danh sách thông báo khi khởi tạo
    Future.microtask(loadNotifications);
    return const NotificationState(isLoading: true);
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true);
    final filter = state.currentFilter == 'all' ? null : state.currentFilter;
    final items = await _dbHelper.getAllNotifications(typeFilter: filter);
    final unread = await _dbHelper.getUnreadNotificationCount();

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
    final items = await _dbHelper.getAllNotifications(typeFilter: typeFilter);
    final unread = await _dbHelper.getUnreadNotificationCount();

    state = state.copyWith(
      notifications: items,
      unreadCount: unread,
      isLoading: false,
    );
  }

  Future<void> markAsRead(int id) async {
    await _dbHelper.markNotificationAsRead(id);
    await loadNotifications();
  }

  Future<void> markAllAsRead() async {
    await _dbHelper.markAllNotificationsAsRead();
    await loadNotifications();
  }

  Future<void> deleteNotification(int id) async {
    await _dbHelper.deleteNotification(id);
    await loadNotifications();
  }

  Future<void> clearAll() async {
    await _dbHelper.clearAllNotifications();
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
    await _dbHelper.insertNotification(notification);

    // Bắn local notification nếu cài đặt đang bật
    try {
      final notifService = ref.read(notificationServiceProvider);
      await notifService.showNotification(
        title: title,
        body: body,
        payload: route,
      );
    } catch (_) {}

    await loadNotifications();
  }
}

final notificationViewModelProvider =
    NotifierProvider<NotificationViewModel, NotificationState>(
  NotificationViewModel.new,
);

/// Provider đếm số thông báo chưa đọc cho badge trên App Bar
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationViewModelProvider).unreadCount;
});
