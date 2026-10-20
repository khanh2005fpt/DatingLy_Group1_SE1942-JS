import 'package:flutter_test/flutter_test.dart';
import 'package:project_prm/data/models/notification_item_model.dart';
import 'package:project_prm/data/models/swipe_history_model.dart';
import 'package:project_prm/data/models/who_liked_user_item.dart';
import 'package:project_prm/data/models/user_model.dart';

void main() {
  group('Module 4 - NotificationItemModel Tests', () {
    test('Map serialization and deserialization', () {
      final now = DateTime.now();
      final item = NotificationItemModel(
        id: 1,
        notificationId: 'notif_123',
        title: 'Tương hợp mới! 🎉',
        body: 'Bạn và Lan đã thích nhau.',
        type: 'match',
        data: '{"matchId":"m_1"}',
        route: '/chat/m_1',
        isRead: false,
        createdAt: now,
      );

      final map = item.toMap();
      expect(map['notification_id'], 'notif_123');
      expect(map['title'], 'Tương hợp mới! 🎉');
      expect(map['type'], 'match');
      expect(map['is_read'], 0);

      final fromMap = NotificationItemModel.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.notificationId, 'notif_123');
      expect(fromMap.title, 'Tương hợp mới! 🎉');
      expect(fromMap.isRead, false);
      expect(fromMap.route, '/chat/m_1');
    });

    test('copyWith updates fields properly', () {
      final item = NotificationItemModel(
        notificationId: 'notif_456',
        title: 'Tin nhắn mới',
        body: 'Hello',
        type: 'message',
        createdAt: DateTime.now(),
      );

      final updated = item.copyWith(isRead: true, title: 'Đã đọc tin');
      expect(updated.isRead, true);
      expect(updated.title, 'Đã đọc tin');
      expect(updated.notificationId, 'notif_456');
    });
  });

  group('Module 4 - SwipeHistoryModel Tests', () {
    test('Map serialization and deserialization', () {
      final now = DateTime.now();
      final swipe = SwipeHistoryModel(
        id: 10,
        targetUserId: 'user_xyz',
        targetUserName: 'Mai Phương',
        targetUserAvatar: 'https://example.com/avatar.jpg',
        targetUserAge: 22,
        targetUserBio: 'Yêu âm nhạc',
        action: 'like',
        timestamp: now,
      );

      final map = swipe.toMap();
      expect(map['target_user_id'], 'user_xyz');
      expect(map['target_user_name'], 'Mai Phương');
      expect(map['action'], 'like');

      final fromMap = SwipeHistoryModel.fromMap(map);
      expect(fromMap.id, 10);
      expect(fromMap.targetUserId, 'user_xyz');
      expect(fromMap.targetUserName, 'Mai Phương');
      expect(fromMap.targetUserAge, 22);
      expect(fromMap.action, 'like');
      expect(fromMap.isLike, true);
      expect(fromMap.isSuperLike, false);
    });

    test('Super Like action helper flags and labels', () {
      final superSwipe = SwipeHistoryModel(
        targetUserId: 'user_super',
        targetUserName: 'Bảo Anh',
        action: 'superlike',
        timestamp: DateTime.now(),
      );

      expect(superSwipe.isSuperLike, true);
      expect(superSwipe.isLike, false);
      expect(superSwipe.isNope, false);
      expect(superSwipe.actionLabel, 'Super Like');
    });
  });

  group('Module 4 - WhoLikedUserItem Tests', () {
    test('Instantiate and copyWith with isSuperLike', () {
      final user = UserModel(
        id: 'u_1',
        fullName: 'Hương Giang',
        email: 'giang@example.com',
        avatarUrls: ['https://example.com/g.jpg'],
        age: 23,
      );

      final item = WhoLikedUserItem(
        user: user,
        likedAt: DateTime.now(),
        isMatched: false,
        isSuperLike: true,
      );

      expect(item.user.fullName, 'Hương Giang');
      expect(item.isMatched, false);
      expect(item.isSuperLike, true);

      final matched = item.copyWith(isMatched: true);
      expect(matched.isMatched, true);
      expect(matched.isSuperLike, true);
    });
  });
}
