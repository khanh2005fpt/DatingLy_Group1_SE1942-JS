import 'package:flutter_test/flutter_test.dart';
import 'package:project_prm/data/models/match_model.dart';
import 'package:project_prm/data/models/message_model.dart';
import 'package:project_prm/features/chat/presentation/utils/chat_time_format.dart';

void main() {
  group('MatchModel', () {
    test('idFor không phụ thuộc thứ tự 2 user', () {
      expect(MatchModel.idFor('a', 'b'), MatchModel.idFor('b', 'a'));
      expect(MatchModel.idFor('uidB', 'uidA'), 'uidA_uidB');
    });

    test('fromMap đọc số tin chưa đọc của đúng người', () {
      final map = {
        'user1_id': 'me',
        'user2_id': 'you',
        'last_sender_id': 'you',
        'last_message': 'Hi',
        'unread_counts': {'me': 3, 'you': 0},
      };
      expect(MatchModel.fromMap(map, 'm1', myId: 'me').unreadCount, 3);
      expect(MatchModel.fromMap(map, 'm1', myId: 'you').unreadCount, 0);
    });

    test('match chưa có tin nhắn là "Tương hợp mới"', () {
      final fresh = MatchModel.fromMap(
          {'user1_id': 'a', 'user2_id': 'b'}, 'm2', myId: 'a');
      expect(fresh.isNewMatch, isTrue);

      final chatting = MatchModel.fromMap(
          {'user1_id': 'a', 'user2_id': 'b', 'last_sender_id': 'a'}, 'm3',
          myId: 'a');
      expect(chatting.isNewMatch, isFalse);
    });
  });

  group('MessageModel', () {
    test('lưu vào cache SQLite rồi đọc lại giữ nguyên dữ liệu', () {
      final msg = MessageModel(
        id: 'x1',
        matchId: 'm1',
        senderId: 'me',
        content: 'https://example.com/a.jpg',
        messageType: MessageModel.typeImage,
        isRead: true,
        createdAt: DateTime(2026, 10, 17, 9, 30),
      );
      final back = MessageModel.fromCacheMap(msg.toCacheMap());

      expect(back.id, msg.id);
      expect(back.matchId, msg.matchId);
      expect(back.content, msg.content);
      expect(back.isImage, isTrue);
      expect(back.isRead, isTrue);
      expect(back.createdAt, msg.createdAt);
      expect(back.preview, '📷 Ảnh');
    });
  });

  group('ChatTimeFormat', () {
    test('nhãn ngày', () {
      final now = DateTime.now();
      expect(ChatTimeFormat.dayLabel(now), 'Hôm nay');
      expect(ChatTimeFormat.dayLabel(now.subtract(const Duration(days: 1))),
          'Hôm qua');
      expect(ChatTimeFormat.dayLabel(DateTime(2025, 3, 7)), '07/03/2025');
    });

    test('giờ dạng HH:mm', () {
      expect(ChatTimeFormat.clock(DateTime(2026, 1, 1, 8, 5)), '08:05');
    });
  });
}
