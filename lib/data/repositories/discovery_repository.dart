import 'package:cloud_firestore/cloud_firestore.dart';
import 'geo_utils.dart';
import '../models/discovery_filter.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/who_liked_user_item.dart';
import 'data_helper.dart';
import 'user_repository.dart';

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

/// Lọc 1 ứng viên Discovery. Hàm thuần (không gọi Firestore) để unit test.
/// [data] là dữ liệu thô của doc (đọc `blocked_users`, `ghost_mode`).
bool passesDiscoveryFilter({
  required String myId,
  required Map<String, dynamic> data,
  required UserModel user,
  required DiscoveryFilter filter,
  GeoPoint? myLocation,
}) {
  if (user.id == myId) return false;
  if (data['ghost_mode'] == true) return false; // đang ẩn danh (module Sơn)

  // Đối phương đã chặn mình
  final theirBlocked = data['blocked_users'];
  if (theirBlocked is List && theirBlocked.contains(myId)) return false;

  if (user.fullName.trim().isEmpty) return false; // hồ sơ chưa hoàn tất
  if (user.age < filter.minAge || user.age > filter.maxAge) return false;
  if (filter.filtersByGender && user.gender != filter.interestedIn) {
    return false;
  }

  // Khoảng cách: mình có vị trí thì người không có vị trí bị ẩn
  if (myLocation != null) {
    final loc = user.location;
    if (loc == null) return false;
    final km = haversineKm(myLocation.latitude, myLocation.longitude,
        loc.latitude, loc.longitude);
    if (km > filter.maxDistanceKm) return false;
  }

  // Sở thích: chọn tag nào thì lọc theo tag đó, không phụ thuộc công tắc
  if (filter.interests.isNotEmpty &&
      !user.tags.any(filter.interests.contains)) {
    return false;
  }
  return true;
}

class DiscoveryRepository {
  final DataHelper _helper = DataHelper();
  final UserRepository _userRepo = UserRepository();

  Future<Set<String>> getExcludedUserIds(String myId) async {
    final excluded = <String>{myId};

    final mySwipes =
        await _helper.swipesCol.where('swiper_id', isEqualTo: myId).get();
    for (final d in mySwipes.docs) {
      final id = d.data()['swiped_id'];
      if (id is String) excluded.add(id);
    }

    final me = await _helper.usersCol.doc(myId).get();
    final blocked = me.data()?['blocked_users'];
    if (blocked is List) {
      excluded.addAll(blocked.map((e) => e.toString()));
    }
    return excluded;
  }

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
      var query = _helper.usersCol
          .where('age', isGreaterThanOrEqualTo: filter.minAge)
          .where('age', isLessThanOrEqualTo: filter.maxAge)
          .orderBy('age');
      if (cursor != null) query = query.startAfterDocument(cursor);

      final snap = await query.limit(fetchSize).get();
      if (snap.docs.isNotEmpty) cursor = snap.docs.last;
      if (snap.docs.length < fetchSize) hasMore = false;

      for (final doc in snap.docs) {
        if (excludedIds.contains(doc.id)) continue;
        final user = UserModel.fromFirestore(doc);
        if (!passesDiscoveryFilter(
          myId: myId,
          data: doc.data(),
          user: user,
          filter: filter,
          myLocation: myLocation,
        )) {
          continue;
        }
        users.add(user);
        if (users.length >= pageSize) break;
      }

      if (!hasMore) break;
    }

    return DiscoveryPage(
      users: users,
      cursor: cursor,
      hasMore: hasMore,
    );
  }

  static bool _isLikeAction(Object? a) => a == 'like' || a == 'super_like';

  /// Những người đã Like/Super Like mình (Who Liked You - module 4).
  Future<List<WhoLikedUserItem>> getWhoLikedMe(String myId) async {
    final snap =
        await _helper.swipesCol.where('swiped_id', isEqualTo: myId).get();
    return _toWhoLikedItems(myId, snap.docs);
  }

  /// Bản realtime của [getWhoLikedMe].
  Stream<List<WhoLikedUserItem>> streamWhoLikedMe(String myId) => _helper
      .swipesCol
      .where('swiped_id', isEqualTo: myId)
      .snapshots()
      .asyncMap((snap) => _toWhoLikedItems(myId, snap.docs));

  Future<List<WhoLikedUserItem>> _toWhoLikedItems(
    String myId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    // Lọc action phía client để không cần composite index
    final incoming = docs
        .map((d) => d.data())
        .where((d) => _isLikeAction(d['action']) && d['swiper_id'] != myId)
        .toList();
    if (incoming.isEmpty) return [];

    // Người mình cũng đã like lại => đã match
    final mySwipes =
        await _helper.swipesCol.where('swiper_id', isEqualTo: myId).get();
    final myLikedIds = {
      for (final d in mySwipes.docs)
        if (_isLikeAction(d.data()['action'])) d.data()['swiped_id'] as String,
    };

    final items = await Future.wait(incoming.map((data) async {
      final swiperId = data['swiper_id'] as String?;
      if (swiperId == null) return null;
      final user = await _userRepo.getUserProfile(swiperId);
      if (user == null || user.fullName.trim().isEmpty) return null;
      final ts = data['created_at'];
      return WhoLikedUserItem(
        user: user,
        likedAt: ts is Timestamp ? ts.toDate() : null,
        isMatched: myLikedIds.contains(swiperId),
        isSuperLike: data['action'] == 'super_like',
      );
    }));

    // Super Like lên trước, sau đó mới nhất trước
    return items.whereType<WhoLikedUserItem>().toList()
      ..sort((a, b) {
        if (a.isSuperLike != b.isSuperLike) return a.isSuperLike ? -1 : 1;
        return (b.likedAt ?? DateTime(0)).compareTo(a.likedAt ?? DateTime(0));
      });
  }

  /// Hoàn tác (Rewind) swipe: xoá swipe và xoá match vừa tạo nếu chưa nhắn tin.
  Future<void> undoSwipe({
    required String myId,
    required String targetUserId,
  }) async {
    await _helper.swipesCol.doc('${myId}_$targetUserId').delete();

    final ids = [myId, targetUserId]..sort();
    final matchRef = _helper.matchesCol.doc(ids.join('_'));
    try {
      final match = await matchRef.get();
      final lastMsg = match.data()?['last_message'];
      if (match.exists &&
          (lastMsg == null || lastMsg == 'Hai bạn đã tương hợp!')) {
        await matchRef.delete();
      }
    } catch (e) {
      debugPrint('undoSwipe: không xoá được match: $e');
    }
  }

  Future<String?> recordSwipe({
    required String myId,
    required String targetUserId,
    required String action, // 'like' | 'nope' | 'super_like'
  }) async {
    final swipeDocId = '${myId}_$targetUserId';
    await _helper.swipesCol.doc(swipeDocId).set({
      'swiper_id': myId,
      'swiped_id': targetUserId,
      'action': action,
      'created_at': FieldValue.serverTimestamp(),
    });

    if (action != 'like' && action != 'super_like') return null;

    final reverse = await _helper.swipesCol.doc('${targetUserId}_$myId').get();
    final reverseAction = reverse.data()?['action'];
    if (reverseAction != 'like' && reverseAction != 'super_like') return null;

    final ids = [myId, targetUserId]..sort();
    final matchRef = _helper.matchesCol.doc(ids.join('_'));
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
}

