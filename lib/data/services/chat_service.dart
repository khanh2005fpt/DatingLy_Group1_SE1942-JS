import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

/// Làm việc với collection `matches` và subcollection `matches/{id}/messages`.
class ChatService {
  static const Duration _profileCacheTtl = Duration(minutes: 5);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cache profile đối phương để mỗi lần danh sách match thay đổi không phải đọc lại
  final Map<String, ({UserModel? profile, DateTime fetchedAt})> _profiles = {};
  // matchId -> 2 user của match (lấy từ streamMatches, dùng khi gửi tin)
  final Map<String, List<String>> _matchUsers = {};

  CollectionReference<Map<String, dynamic>> get _matchesCol =>
      _db.collection('matches');
  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> _messagesCol(String matchId) =>
      _matchesCol.doc(matchId).collection('messages');

  // ==================== MATCHES ====================

  Stream<List<MatchModel>> streamMatches(String myId) {
    return _matchesCol
        .where('users', arrayContains: myId)
        .snapshots()
        .asyncMap((snapshot) async {
      final list = await Future.wait(snapshot.docs.map((doc) async {
        final match = MatchModel.fromMap(doc.data(), doc.id, myId: myId);
        _matchUsers[doc.id] = [match.user1Id, match.user2Id];
        final other = await _getProfile(match.getOtherUserId(myId));
        return match.copyWith(otherProfile: other);
      }));

      // Sắp xếp phía client để khỏi cần composite index (users + last_message_time)
      list.sort((a, b) => b.sortTime.compareTo(a.sortTime));
      return list;
    });
  }

  Future<UserModel?> _getProfile(String userId) async {
    final cached = _profiles[userId];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _profileCacheTtl) {
      return cached.profile;
    }
    final doc = await _usersCol.doc(userId).get();
    final profile =
        doc.exists && doc.data() != null ? UserModel.fromFirestore(doc) : null;
    _profiles[userId] = (profile: profile, fetchedAt: DateTime.now());
    return profile;
  }

  Future<String?> _getOtherUserId(String matchId, String myId) async {
    var users = _matchUsers[matchId];
    if (users == null) {
      final doc = await _matchesCol.doc(matchId).get();
      final data = doc.data();
      if (data == null) return null;
      users = [data['user1_id'] as String, data['user2_id'] as String];
      _matchUsers[matchId] = users;
    }
    return users.firstWhere((id) => id != myId, orElse: () => '');
  }

  // ==================== MESSAGES ====================

  /// Realtime [limit] tin nhắn mới nhất (tăng dần theo thời gian).
  /// includeMetadataChanges để bắt được lúc tin chuyển từ "Đang gửi" sang "Đã gửi".
  Stream<List<MessageModel>> streamLatestMessages(String matchId,
      {int limit = 30}) {
    return _messagesCol(matchId)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs
            .map(MessageModel.fromFirestore)
            .toList()
            .reversed
            .toList());
  }

  /// Tải trang tin cũ hơn [before] (tăng dần theo thời gian).
  Future<List<MessageModel>> fetchMessagesBefore(String matchId,
      DateTime before, {int limit = 30}) async {
    final snap = await _messagesCol(matchId)
        .where('created_at', isLessThan: Timestamp.fromDate(before))
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(MessageModel.fromFirestore).toList().reversed.toList();
  }

  /// Tải các tin mới hơn [after] (dùng để bù phần cache SQLite còn thiếu).
  Future<List<MessageModel>> fetchMessagesAfter(String matchId,
      DateTime after, {int limit = 500}) async {
    final snap = await _messagesCol(matchId)
        .where('created_at', isGreaterThan: Timestamp.fromDate(after))
        .orderBy('created_at')
        .limit(limit)
        .get();
    return snap.docs.map(MessageModel.fromFirestore).toList();
  }

  /// Ghi tin nhắn + cập nhật match trong 1 batch.
  /// Firestore hiện tin ngay ở máy (pending), Future chỉ xong khi server xác nhận.
  Future<void> sendMessage({
    required String matchId,
    required String senderId,
    required String content,
    String type = MessageModel.typeText,
  }) async {
    final otherId = await _getOtherUserId(matchId, senderId);
    final msgRef = _messagesCol(matchId).doc();
    final message = MessageModel(
      id: msgRef.id,
      matchId: matchId,
      senderId: senderId,
      content: content,
      messageType: type,
    );

    final batch = _db.batch();
    batch.set(msgRef, message.toMap());
    batch.update(_matchesCol.doc(matchId), {
      'last_message': message.preview,
      'last_message_time': FieldValue.serverTimestamp(),
      'last_sender_id': senderId,
      if (otherId != null && otherId.isNotEmpty)
        'unread_counts.$otherId': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> markMessagesAsRead({
    required String matchId,
    required String myId,
  }) async {
    // Chỉ lọc 1 field để khỏi cần composite index, lọc người gửi phía client
    final snap =
        await _messagesCol(matchId).where('is_read', isEqualTo: false).get();

    final unread =
        snap.docs.where((doc) => doc.data()['sender_id'] != myId).toList();
    if (unread.isEmpty) return; // Không có gì để đánh dấu -> khỏi tốn lượt ghi

    final batch = _db.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'is_read': true});
    }
    batch.update(_matchesCol.doc(matchId), {'unread_counts.$myId': 0});
    await batch.commit();
  }
}
