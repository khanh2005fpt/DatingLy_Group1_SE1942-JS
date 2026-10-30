import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';
import '../models/report_model.dart';

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
  CollectionReference<Map<String, dynamic>> get _reportsCol =>
      _db.collection('reports');

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
  /// Trả về matchId nếu cả 2 bên cùng Like
  Future<String?> recordSwipe({
    required String myId,
    required String targetUserId,
    required bool isLike,
  }) async {
    final swipeDocId = '${myId}_$targetUserId';
    final action = isLike ? 'like' : 'nope';

    await _swipesCol.doc(swipeDocId).set({
      'swiper_id': myId,
      'swiped_id': targetUserId,
      'action': action,
      'created_at': FieldValue.serverTimestamp(),
    });

    if (!isLike) return null;

    // Kiểm tra xem đối phương đã like mình chưa
    final reverseDoc =
        await _swipesCol.doc('${targetUserId}_$myId').get();

    if (reverseDoc.exists && reverseDoc.data()?['action'] == 'like') {
      // It's a match!
      final matchDoc = await _matchesCol.add({
        'user1_id': myId,
        'user2_id': targetUserId,
        'users': [myId, targetUserId],
        'created_at': FieldValue.serverTimestamp(),
        'last_message': 'Hai bạn đã tương hợp!',
        'last_message_time': FieldValue.serverTimestamp(),
      });
      return matchDoc.id;
    }

    return null;
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

  // ==================== SAFETY / BLOCK / REPORT ====================

  /// Gửi báo cáo vi phạm vào collection `reports`
  Future<void> submitReport(ReportModel report) async {
    await _reportsCol.add(report.toMap());
  }

  /// Chặn người dùng: thêm targetId vào mảng blocked_users của myId
  Future<void> blockUser(String myId, String targetId) async {
    await _usersCol.doc(myId).update({
      'blocked_users': FieldValue.arrayUnion([targetId]),
    });
  }

  /// Bỏ chặn người dùng: xoá targetId khỏi mảng blocked_users của myId
  Future<void> unblockUser(String myId, String targetId) async {
    await _usersCol.doc(myId).update({
      'blocked_users': FieldValue.arrayRemove([targetId]),
    });
  }

  /// Lấy danh sách user bị chặn của myId (trả về List<UserModel>)
  Future<List<UserModel>> getBlockedUsers(String myId) async {
    final doc = await _usersCol.doc(myId).get();
    if (!doc.exists || doc.data() == null) return [];
    final myProfile = UserModel.fromFirestore(doc);
    final blockedIds = myProfile.blockedUsers;
    if (blockedIds.isEmpty) return [];

    final List<UserModel> blockedList = [];
    for (final id in blockedIds) {
      final user = await getUserProfile(id);
      if (user != null) blockedList.add(user);
    }
    return blockedList;
  }

  /// Cập nhật trạng thái Ghost Mode trên Firestore
  Future<void> updateGhostMode(String userId, bool isGhost) async {
    await _usersCol.doc(userId).set(
      {'ghost_mode': isGhost},
      SetOptions(merge: true),
    );
  }

  /// Lấy tất cả tin nhắn ảnh (message_type == 'image') trong một cuộc hội thoại
  Future<List<MessageModel>> getMatchMediaMessages(String matchId) async {
    final snap = await _messagesCol
        .where('match_id', isEqualTo: matchId)
        .where('message_type', isEqualTo: 'image')
        .get();
    final list = snap.docs
        .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
        .toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    return list;
  }
}

