import '../models/notification_item_model.dart';
import '../models/swipe_history_model.dart';
import 'database_adapter_web.dart'
    if (dart.library.io) 'database_adapter_native.dart';

abstract class DatabaseAdapter {
  static DatabaseAdapter create() => getDatabaseAdapter();

  Future<void> init();

  // Notifications
  Future<int> insertNotification(NotificationItemModel item);
  Future<List<NotificationItemModel>> getAllNotifications({String? typeFilter});
  Future<int> getUnreadNotificationCount();
  Future<int> markNotificationAsRead(int id);
  Future<int> markAllNotificationsAsRead();
  Future<int> deleteNotification(int id);
  Future<int> clearAllNotifications();

  // Swipe History
  Future<int> insertSwipeHistory(SwipeHistoryModel swipe);
  Future<List<SwipeHistoryModel>> getRecentSwipeHistory({
    int limit = 100,
    String? actionFilter,
  });
  Future<SwipeHistoryModel?> getLastSwipe();
  Future<int> deleteSwipe(int id);
  Future<int> deleteSwipeByTargetUserId(String targetUserId);
  Future<int> clearAllSwipeHistory();

  // Cache clear
  Future<void> clearAllCache();
}
