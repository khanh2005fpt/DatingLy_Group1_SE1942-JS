import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/match_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _swipesCol =>
      _db.collection('swipes');
  CollectionReference<Map<String, dynamic>> get _matchesCol =>
      _db.collection('matches');

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
      // It's a match! Chưa có tin nhắn -> hiện ở hàng "Tương hợp mới"
      final matchId = MatchModel.idFor(myId, targetUserId);
      final matchRef = _matchesCol.doc(matchId);
      if (!(await matchRef.get()).exists) {
        await matchRef.set(
          MatchModel(id: matchId, user1Id: myId, user2Id: targetUserId)
              .toMap(),
        );
      }
      return matchId;
    }

    return null;
  }
}
