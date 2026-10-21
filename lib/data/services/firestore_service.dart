import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/geo_utils.dart';
import '../models/discovery_filter.dart';
import '../models/user_model.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';

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

  /// Người đã Like / Super Like mình mà mình chưa quẹt lại (và không bị chặn).
  Future<List<UserModel>> getUsersWhoLikedMe(String myId) async {
    final excluded = await getExcludedUserIds(myId);

    final snap = await _swipesCol.where('swiped_id', isEqualTo: myId).get();
    final likers = snap.docs
        .where((d) {
          final a = d.data()['action'];
          return a == 'like' || a == 'super_like';
        })
        .map((d) => d.data()['swiper_id'] as String?)
        .whereType<String>()
        .where((id) => !excluded.contains(id))
        .toSet()
        .take(50);

    final users = await Future.wait(likers.map(getUserProfile));
    return users
        .whereType<UserModel>()
        .where((u) => u.fullName.trim().isNotEmpty)
        .toList();
  }

  Future<void> updateLocation(String userId, GeoPoint location) async {
    await _usersCol
        .doc(userId)
        .set({'location': location}, SetOptions(merge: true));
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

  /// Tập id cần loại khỏi Discovery: chính mình, người đã quẹt, người mình
  /// đã chặn (`blocked_users` của mình) và người đã chặn mình.
  Future<Set<String>> getExcludedUserIds(String myId) async {
    final excluded = <String>{myId};

    final mySwipes =
        await _swipesCol.where('swiper_id', isEqualTo: myId).get();
    for (final d in mySwipes.docs) {
      final id = d.data()['swiped_id'];
      if (id is String) excluded.add(id);
    }

    final me = await _usersCol.doc(myId).get();
    final blocked = me.data()?['blocked_users'];
    if (blocked is List) {
      excluded.addAll(blocked.map((e) => e.toString()));
    }
    return excluded;
  }

  /// Lấy một trang ứng viên. Query server theo khoảng tuổi (orderBy age, cursor
  /// [startAfter]); giới tính, block, khoảng cách, sở thích lọc phía client.
  /// Lặp tối đa [maxRounds] lần để đủ [pageSize] sau khi lọc.
  Future<DiscoveryPage> getDiscoveryPage({
    required String myId,
    required DiscoveryFilter filter,
    required Set<String> excludedIds,
    GeoPoint? myLocation,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int pageSize = 20,
    int maxRounds = 5,
  }) async {
    final users = <UserModel>[];
    var cursor = startAfter;
    var hasMore = true;
    const fetchSize = 30;

    for (var round = 0; round < maxRounds && users.length < pageSize; round++) {
      var query = _usersCol
          .where('age', isGreaterThanOrEqualTo: filter.minAge)
          .where('age', isLessThanOrEqualTo: filter.maxAge)
          .orderBy('age');
      if (cursor != null) query = query.startAfterDocument(cursor);

      final snap = await query.limit(fetchSize).get();
      if (snap.docs.isNotEmpty) cursor = snap.docs.last;
      if (snap.docs.length < fetchSize) hasMore = false;

      for (final doc in snap.docs) {
        if (excludedIds.contains(doc.id)) continue;
        final data = doc.data();

        // Đối phương đã chặn mình
        final theirBlocked = data['blocked_users'];
        if (theirBlocked is List && theirBlocked.contains(myId)) continue;

        final user = UserModel.fromFirestore(doc);
        if (user.fullName.trim().isEmpty) continue; // hồ sơ chưa hoàn tất
        if (filter.interestedIn != DiscoveryFilter.anyGender &&
            user.gender != filter.interestedIn) {
          continue;
        }

        // Khoảng cách: chỉ lọc khi cả hai có vị trí
        if (myLocation != null && user.location != null) {
          final km = haversineKm(myLocation.latitude, myLocation.longitude,
              user.location!.latitude, user.location!.longitude);
          if (km > filter.maxDistanceKm) continue;
        }

        // Sở thích: chung với bộ chọn của filter, hoặc ít nhất 1 nếu bật
        if (filter.requireCommonInterest && filter.interests.isNotEmpty) {
          if (!user.tags.any(filter.interests.contains)) continue;
        }

        users.add(user);
        if (users.length >= pageSize) break;
      }

      if (!hasMore) break;
    }

    return DiscoveryPage(users: users, cursor: cursor, hasMore: hasMore);
  }

  /// Ghi nhận swipe ([action]: like | nope | super_like) và kiểm tra match.
  /// Trả về matchId nếu cả 2 bên cùng thích.
  Future<String?> recordSwipe({
    required String myId,
    required String targetUserId,
    required String action,
  }) async {
    await _swipesCol.doc('${myId}_$targetUserId').set({
      'swiper_id': myId,
      'swiped_id': targetUserId,
      'action': action,
      'created_at': FieldValue.serverTimestamp(),
    });

    if (action != 'like' && action != 'super_like') return null;

    // Kiểm tra xem đối phương đã like mình chưa
    final reverse = await _swipesCol.doc('${targetUserId}_$myId').get();
    final reverseAction = reverse.data()?['action'];
    if (reverseAction != 'like' && reverseAction != 'super_like') return null;

    // matchId xác định -> hai bên quẹt gần như đồng thời không tạo match trùng
    final ids = [myId, targetUserId]..sort();
    final matchRef = _matchesCol.doc(ids.join('_'));
    final existing = await matchRef.get();
    if (!existing.exists) {
      await matchRef.set({
        'user1_id': myId,
        'user2_id': targetUserId,
        'users': [myId, targetUserId],
        'created_at': FieldValue.serverTimestamp(),
        'last_message': 'Hai bạn đã tương hợp!',
        'last_message_time': FieldValue.serverTimestamp(),
      });
    }
    return matchRef.id;
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

/// Kết quả một trang Discovery.
class DiscoveryPage {
  final List<UserModel> users;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const DiscoveryPage({
    required this.users,
    required this.cursor,
    required this.hasMore,
  });
}
