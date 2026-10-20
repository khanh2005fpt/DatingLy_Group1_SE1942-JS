import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';
import '../models/who_liked_user_item.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _swipesCol =>
      _db.collection('swipes');
  CollectionReference<Map<String, dynamic>> get _matchesCol =>
      _db.collection('matches');
  CollectionReference<Map<String, dynamic>> get _messagesCol =>
      _db.collection('messages');

  // ==================== PROFILE / USER ====================

  Future<void> saveUserProfile(UserModel user) async {
    await _usersCol.doc(user.id).set(
          user.toMap(),
          SetOptions(merge: true),
        );
  }

  /// Lưu FCM token của thiết bị để server có thể gửi push tới đúng người dùng.
  Future<void> updateFcmToken(String userId, String token) async {
    await _usersCol
        .doc(userId)
        .set({'fcm_token': token}, SetOptions(merge: true));
  }

  Future<UserModel?> getUserProfile(String userId) async {
    final doc = await _usersCol.doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> streamUserProfile(String userId) {
    return _usersCol.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  // ==================== DISCOVERY / SWIPES ====================

  Future<List<UserModel>> getDiscoveryUsers({
    required String myId,
    String? genderFilter,
  }) async {
    // 1. Lấy danh sách swiped_id mà mình đã quẹt
    final mySwipes =
        await _swipesCol.where('swiper_id', isEqualTo: myId).get();
    final swipedIds =
        mySwipes.docs.map((d) => d.data()['swiped_id'] as String).toSet();
    swipedIds.add(myId); // Loại bỏ chính mình

    // 2. Query users từ Firestore
    Query<Map<String, dynamic>> query = _usersCol;
    if (genderFilter != null &&
        genderFilter.isNotEmpty &&
        genderFilter != 'all') {
      query = query.where('gender', isEqualTo: genderFilter);
    }

    final querySnapshot = await query.limit(50).get();
    final List<UserModel> users = [];

    for (final doc in querySnapshot.docs) {
      if (!swipedIds.contains(doc.id)) {
        users.add(UserModel.fromFirestore(doc));
      }
    }

    return users;
  }

  /// Ghi nhận swipe và kiểm tra nếu có match
  /// Trả về matchId nếu cả 2 bên cùng Like / Super Like
  Future<String?> recordSwipe({
    required String myId,
    required String targetUserId,
    required bool isLike,
    bool isSuperLike = false,
  }) async {
    final swipeDocId = '${myId}_$targetUserId';
    final action = isSuperLike ? 'superlike' : (isLike ? 'like' : 'nope');

    await _swipesCol.doc(swipeDocId).set({
      'swiper_id': myId,
      'swiped_id': targetUserId,
      'action': action,
      'created_at': FieldValue.serverTimestamp(),
    });

    if (!isLike && !isSuperLike) return null;

    // Kiểm tra xem đối phương đã like/superlike mình chưa
    final reverseDoc =
        await _swipesCol.doc('${targetUserId}_$myId').get();

    if (reverseDoc.exists) {
      final reverseAction = reverseDoc.data()?['action'];
      if (reverseAction == 'like' || reverseAction == 'superlike') {
        // It's a match!
        final matchDoc = await _matchesCol.add({
          'user1_id': myId,
          'user2_id': targetUserId,
          'users': [myId, targetUserId],
          'created_at': FieldValue.serverTimestamp(),
          'last_message': isSuperLike ? 'Super Like tương hợp! ⭐' : 'Hai bạn đã tương hợp!',
          'last_message_time': FieldValue.serverTimestamp(),
        });
        return matchDoc.id;
      }
    }

    return null;
  }

  /// Hoàn tác (Undo/Rewind) swipe giữa myId và targetUserId
  Future<void> undoSwipe({
    required String myId,
    required String targetUserId,
  }) async {
    final swipeDocId = '${myId}_$targetUserId';
    await _swipesCol.doc(swipeDocId).delete();

    // Đồng thời xóa match nếu vừa mới tạo do lượt swipe này (chưa có tin nhắn thật)
    try {
      final matchQuery = await _matchesCol
          .where('users', arrayContains: myId)
          .get();
      for (final doc in matchQuery.docs) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        if (users.contains(targetUserId)) {
          final lastMsg = doc.data()['last_message'];
          if (lastMsg == null ||
              lastMsg == 'Hai bạn đã tương hợp!' ||
              lastMsg == 'Super Like tương hợp! ⭐') {
            await _matchesCol.doc(doc.id).delete();
          }
        }
      }
    } catch (_) {}
  }

  /// Lấy danh sách những người đã Like/SuperLike tài khoản của user (Who Liked You)
  Future<List<WhoLikedUserItem>> getWhoLikedMe(String myId) async {
    // 1. Lấy danh sách swipe mà swiped_id == myId và action in ['like', 'superlike']
    final incomingSwipesSnap = await _swipesCol
        .where('swiped_id', isEqualTo: myId)
        .where('action', whereIn: ['like', 'superlike'])
        .get();

    if (incomingSwipesSnap.docs.isEmpty) return [];

    // 2. Lấy danh sách swipe mà myId đã quẹt để biết đã match hay chưa
    final mySwipesSnap =
        await _swipesCol.where('swiper_id', isEqualTo: myId).get();
    final myLikedIds = <String>{};
    for (final doc in mySwipesSnap.docs) {
      final a = doc.data()['action'];
      if (a == 'like' || a == 'superlike') {
        myLikedIds.add(doc.data()['swiped_id'] as String);
      }
    }

    final List<WhoLikedUserItem> result = [];
    for (final doc in incomingSwipesSnap.docs) {
      final data = doc.data();
      final swiperId = data['swiper_id'] as String?;
      if (swiperId == null || swiperId == myId) continue;

      final userProfile = await getUserProfile(swiperId);
      if (userProfile != null) {
        final timestamp = data['created_at'] != null
            ? (data['created_at'] as Timestamp).toDate()
            : null;
        result.add(WhoLikedUserItem(
          user: userProfile,
          likedAt: timestamp,
          isMatched: myLikedIds.contains(swiperId),
          isSuperLike: data['action'] == 'superlike',
        ));
      }
    }

    // Sắp xếp: Ưu tiên Super Like lên trước, sau đó sắp xếp theo thời gian mới nhất
    result.sort((a, b) {
      if (a.isSuperLike && !b.isSuperLike) return -1;
      if (!a.isSuperLike && b.isSuperLike) return 1;
      return (b.likedAt ?? DateTime(0)).compareTo(a.likedAt ?? DateTime(0));
    });

    return result;
  }

  /// Stream realtime danh sách những người đã Like tài khoản của user
  Stream<List<WhoLikedUserItem>> streamWhoLikedMe(String myId) {
    return _swipesCol
        .where('swiped_id', isEqualTo: myId)
        .where('action', whereIn: ['like', 'superlike'])
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return <WhoLikedUserItem>[];

      final mySwipesSnap =
          await _swipesCol.where('swiper_id', isEqualTo: myId).get();
      final myLikedIds = <String>{};
      for (final doc in mySwipesSnap.docs) {
        final a = doc.data()['action'];
        if (a == 'like' || a == 'superlike') {
          myLikedIds.add(doc.data()['swiped_id'] as String);
        }
      }

      final List<WhoLikedUserItem> result = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final swiperId = data['swiper_id'] as String?;
        if (swiperId == null || swiperId == myId) continue;

        final userProfile = await getUserProfile(swiperId);
        if (userProfile != null) {
          final timestamp = data['created_at'] != null
              ? (data['created_at'] as Timestamp).toDate()
              : null;
          result.add(WhoLikedUserItem(
            user: userProfile,
            likedAt: timestamp,
            isMatched: myLikedIds.contains(swiperId),
            isSuperLike: data['action'] == 'superlike',
          ));
        }
      }

      result.sort((a, b) {
        if (a.isSuperLike && !b.isSuperLike) return -1;
        if (!a.isSuperLike && b.isSuperLike) return 1;
        return (b.likedAt ?? DateTime(0)).compareTo(a.likedAt ?? DateTime(0));
      });

      return result;
    });
  }

  // ==================== MATCHES & CHAT ====================

  Stream<List<MatchModel>> streamMatches(String myId) {
    return _matchesCol
        .where('users', arrayContains: myId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<MatchModel> list = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final otherId = data['user1_id'] == myId
            ? (data['user2_id'] as String)
            : (data['user1_id'] as String);

        final otherProfile = await getUserProfile(otherId);

        // Đếm số tin nhắn chưa đọc (lọc phía client để khỏi cần composite index)
        final msgs =
            await _messagesCol.where('match_id', isEqualTo: doc.id).get();
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
    // Sắp xếp phía client để khỏi cần composite index (match_id + created_at)
    return _messagesCol
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
    // 1. Thêm tin nhắn vào Firestore
    await _messagesCol.add({
      'match_id': matchId,
      'sender_id': senderId,
      'content': content,
      'message_type': type,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2. Cập nhật last_message vào match
    await _matchesCol.doc(matchId).update({
      'last_message': content,
      'last_message_time': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markMessagesAsRead({
    required String matchId,
    required String myId,
  }) async {
    final snap =
        await _messagesCol.where('match_id', isEqualTo: matchId).get();
    final unread = snap.docs.where((d) {
      final data = d.data();
      return data['sender_id'] != myId && data['is_read'] != true;
    });
    if (unread.isEmpty) return;

    final batch = _db.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }
}
