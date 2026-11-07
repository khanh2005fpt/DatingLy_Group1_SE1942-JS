import '../local/database_helper.dart';
import '../models/notification_item_model.dart';
import '../models/swipe_history_model.dart';
import '../models/who_liked_user_item.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

/// Repository cho Module 4 - Activity (Notifications, Who Liked Me, Swipe History)
/// Đóng vai trò trung gian giữa ViewModel và các data sources (SQLite, Firestore, FCM)
class ActivityRepository {
  final DatabaseHelper _dbHelper;
  final FirestoreService _firestoreService;
  final NotificationService _notificationService;

  ActivityRepository({
    required DatabaseHelper dbHelper,
    required FirestoreService firestoreService,
    required NotificationService notificationService,
  })  : _dbHelper = dbHelper,
        _firestoreService = firestoreService,
        _notificationService = notificationService;

  // ==========================================
  // NOTIFICATIONS
  // ==========================================

  Future<List<NotificationItemModel>> getAllNotifications({
    String? typeFilter,
  }) =>
      _dbHelper.getAllNotifications(typeFilter: typeFilter);

  Future<int> getUnreadNotificationCount() =>
      _dbHelper.getUnreadNotificationCount();

  Future<void> markNotificationAsRead(int id) =>
      _dbHelper.markNotificationAsRead(id);

  Future<void> markAllNotificationsAsRead() =>
      _dbHelper.markAllNotificationsAsRead();

  Future<void> deleteNotification(int id) => _dbHelper.deleteNotification(id);

  Future<void> clearAllNotifications() => _dbHelper.clearAllNotifications();

  Future<void> insertNotification(NotificationItemModel notification) =>
      _dbHelper.insertNotification(notification);

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) =>
      _notificationService.showNotification(
        title: title,
        body: body,
        payload: payload,
      );

  // ==========================================
  // WHO LIKED ME
  // ==========================================

  Future<List<WhoLikedUserItem>> getWhoLikedMe(String myId) =>
      _firestoreService.getWhoLikedMe(myId);

  Stream<List<WhoLikedUserItem>> streamWhoLikedMe(String myId) =>
      _firestoreService.streamWhoLikedMe(myId);

  Future<String?> recordSwipe({
    required String myId,
    required String targetUserId,
    required bool isLike,
    bool isSuperLike = false,
  }) =>
      _firestoreService.recordSwipe(
        myId: myId,
        targetUserId: targetUserId,
        isLike: isLike,
        isSuperLike: isSuperLike,
      );

  // ==========================================
  // SWIPE HISTORY
  // ==========================================

  Future<List<SwipeHistoryModel>> getRecentSwipeHistory({
    int limit = 100,
    String? actionFilter,
  }) =>
      _dbHelper.getRecentSwipeHistory(limit: limit, actionFilter: actionFilter);

  Future<SwipeHistoryModel?> getLastSwipe() => _dbHelper.getLastSwipe();

  Future<void> insertSwipeHistory(SwipeHistoryModel swipe) =>
      _dbHelper.insertSwipeHistory(swipe);

  Future<void> undoSwipe({
    required String myId,
    required String targetUserId,
  }) =>
      _firestoreService.undoSwipe(myId: myId, targetUserId: targetUserId);

  Future<void> deleteSwipe(int id) => _dbHelper.deleteSwipe(id);

  Future<void> deleteSwipeByTargetUserId(String targetUserId) =>
      _dbHelper.deleteSwipeByTargetUserId(targetUserId);

  Future<void> clearAllSwipeHistory() => _dbHelper.clearAllSwipeHistory();
}
