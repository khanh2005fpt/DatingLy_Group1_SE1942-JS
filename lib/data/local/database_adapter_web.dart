import '../models/notification_item_model.dart';
import '../models/swipe_history_model.dart';
import 'database_adapter.dart';

DatabaseAdapter getDatabaseAdapter() => WebDatabaseAdapter();

class WebDatabaseAdapter implements DatabaseAdapter {
  final List<NotificationItemModel> _notifications = [];
  final List<SwipeHistoryModel> _swipes = [];
  int _nextNotificationId = 1;
  int _nextSwipeId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<int> insertNotification(NotificationItemModel item) async {
    final newId = item.id ?? _nextNotificationId++;
    final stored = item.copyWith(id: newId);
    _notifications.removeWhere(
      (n) => n.id == newId || n.notificationId == item.notificationId,
    );
    _notifications.insert(0, stored);
    return newId;
  }

  @override
  Future<List<NotificationItemModel>> getAllNotifications({
    String? typeFilter,
  }) async {
    if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
      return _notifications.where((n) => n.type == typeFilter).toList();
    }
    return List.from(_notifications);
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    return _notifications.where((n) => !n.isRead).length;
  }

  @override
  Future<int> markNotificationAsRead(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> markAllNotificationsAsRead() async {
    int count = 0;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> deleteNotification(int id) async {
    final initial = _notifications.length;
    _notifications.removeWhere((n) => n.id == id);
    return initial - _notifications.length;
  }

  @override
  Future<int> clearAllNotifications() async {
    final count = _notifications.length;
    _notifications.clear();
    return count;
  }

  @override
  Future<int> insertSwipeHistory(SwipeHistoryModel swipe) async {
    final newId = swipe.id ?? _nextSwipeId++;
    final stored = swipe.copyWith(id: newId);
    _swipes.removeWhere((s) => s.targetUserId == swipe.targetUserId);
    _swipes.insert(0, stored);
    return newId;
  }

  @override
  Future<List<SwipeHistoryModel>> getRecentSwipeHistory({
    int limit = 100,
    String? actionFilter,
  }) async {
    List<SwipeHistoryModel> list = _swipes;
    if (actionFilter != null &&
        actionFilter.isNotEmpty &&
        actionFilter != 'all') {
      list = list.where((s) => s.action == actionFilter).toList();
    }
    return list.take(limit).toList();
  }

  @override
  Future<SwipeHistoryModel?> getLastSwipe() async {
    if (_swipes.isEmpty) return null;
    return _swipes.first;
  }

  @override
  Future<int> deleteSwipe(int id) async {
    final initial = _swipes.length;
    _swipes.removeWhere((s) => s.id == id);
    return initial - _swipes.length;
  }

  @override
  Future<int> deleteSwipeByTargetUserId(String targetUserId) async {
    final initial = _swipes.length;
    _swipes.removeWhere((s) => s.targetUserId == targetUserId);
    return initial - _swipes.length;
  }

  @override
  Future<int> clearAllSwipeHistory() async {
    final count = _swipes.length;
    _swipes.clear();
    return count;
  }

  @override
  Future<void> clearAllCache() async {
    _notifications.clear();
    _swipes.clear();
  }
}
