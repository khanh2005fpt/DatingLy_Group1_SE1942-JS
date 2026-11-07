import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';
import 'data_helper.dart';
import 'user_repository.dart';

class ChatRepository {
  final DataHelper _helper = DataHelper();
  final UserRepository _userRepo = UserRepository();

  Stream<List<MatchModel>> streamMatches(String myId) {
    return _helper.matchesCol
        .where('users', arrayContains: myId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<MatchModel> list = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final otherId = data['user1_id'] == myId
            ? (data['user2_id'] as String)
            : (data['user1_id'] as String);

        final otherProfile = await _userRepo.getUserProfile(otherId);

        final msgs =
            await _helper.messagesCol.where('match_id', isEqualTo: doc.id).get();
        final unread = msgs.docs.where((m) {
          final d = m.data();
          return d['sender_id'] != myId && d['is_read'] != true;
        }).length;

        list.add(MatchModel.fromMap(
          data,
          doc.id,
          otherProfile: otherProfile,
        ).copyWith(unreadCount: unread));
      }

      list.sort((a, b) => (b.lastMessageTime ?? DateTime(0))
          .compareTo(a.lastMessageTime ?? DateTime(0)));
      return list;
    });
  }

  Stream<List<MessageModel>> streamMessages(String matchId) {
    return _helper.messagesCol
        .where('match_id', isEqualTo: matchId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => (a.createdAt ?? DateTime.now())
          .compareTo(b.createdAt ?? DateTime.now()));
      return list;
    });
  }

  Future<void> sendMessage({
    required String matchId,
    required String senderId,
    required String content,
    String type = 'text',
  }) async {
    await _helper.messagesCol.add({
      'match_id': matchId,
      'sender_id': senderId,
      'content': content,
      'message_type': type,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    await _helper.matchesCol.doc(matchId).update({
      'last_message': content,
      'last_message_time': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markMessagesAsRead({
    required String matchId,
    required String myId,
  }) async {
    final snap =
        await _helper.messagesCol.where('match_id', isEqualTo: matchId).get();
    final unread = snap.docs.where((d) {
      final data = d.data();
      return data['sender_id'] != myId && data['is_read'] != true;
    });
    if (unread.isEmpty) return;

    final batch = _helper.firestore.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }
}

