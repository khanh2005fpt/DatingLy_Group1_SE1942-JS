import '../models/notification_item_model.dart';
import '../models/swipe_history_model.dart';
import 'database_adapter.dart';

class DatabaseHelper {
  // Singleton instance
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  final DatabaseAdapter _adapter = DatabaseAdapter.create();

  Future<void> init() => _adapter.init();

  // ==========================================
  // NOTIFICATIONS LOG METHODS
  // ==========================================

  Future<int> insertNotification(NotificationItemModel item) =>
      _adapter.insertNotification(item);

  Future<List<NotificationItemModel>> getAllNotifications({
    String? typeFilter,
  }) =>
      _adapter.getAllNotifications(typeFilter: typeFilter);

  Future<int> getUnreadNotificationCount() =>
      _adapter.getUnreadNotificationCount();

  Future<int> markNotificationAsRead(int id) =>
      _adapter.markNotificationAsRead(id);

  Future<int> markAllNotificationsAsRead() =>
      _adapter.markAllNotificationsAsRead();

  Future<int> deleteNotification(int id) => _adapter.deleteNotification(id);

  Future<int> clearAllNotifications() => _adapter.clearAllNotifications();

  // ==========================================
  // SWIPED HISTORY CACHE METHODS
  // ==========================================

  Future<int> insertSwipeHistory(SwipeHistoryModel swipe) =>
      _adapter.insertSwipeHistory(swipe);

  Future<List<SwipeHistoryModel>> getRecentSwipeHistory({
    int limit = 100,
    String? actionFilter,
  }) =>
      _adapter.getRecentSwipeHistory(limit: limit, actionFilter: actionFilter);

  Future<SwipeHistoryModel?> getLastSwipe() => _adapter.getLastSwipe();

  Future<int> deleteSwipe(int id) => _adapter.deleteSwipe(id);

  Future<int> deleteSwipeByTargetUserId(String targetUserId) =>
      _adapter.deleteSwipeByTargetUserId(targetUserId);

  Future<int> clearAllSwipeHistory() => _adapter.clearAllSwipeHistory();

  /// Xóa toàn bộ dữ liệu offline khi Logout (Module 5 integration)
  Future<void> clearAllCache() => _adapter.clearAllCache();
}
