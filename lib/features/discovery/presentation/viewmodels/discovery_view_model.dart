import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../data/models/discovery_filter.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/firestore_service.dart';
import '../../../chat/presentation/viewmodels/chat_view_model.dart';

/// Hành động quẹt; [value] là giá trị ghi vào `swipes.action`.
enum SwipeAction {
  like('like'),
  nope('nope'),
  superLike('super_like');

  const SwipeAction(this.value);
  final String value;
}

class DiscoveryState {
  final List<UserModel> cards;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final GeoPoint? myLocation;
  final List<String> myTags;

  const DiscoveryState({
    this.cards = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.myLocation,
    this.myTags = const [],
  });

  DiscoveryState copyWith({
    List<UserModel>? cards,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    GeoPoint? myLocation,
    List<String>? myTags,
  }) {
    return DiscoveryState(
      cards: cards ?? this.cards,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
      myLocation: myLocation ?? this.myLocation,
      myTags: myTags ?? this.myTags,
    );
  }
}

/// Bộ lọc hiện tại, khởi tạo và lưu bằng SharedPreferences.
class DiscoveryFilterNotifier extends Notifier<DiscoveryFilter> {
  @override
  DiscoveryFilter build() =>
      ref.read(preferencesServiceProvider).loadDiscoveryFilter();

  Future<void> apply(DiscoveryFilter filter) async {
    await ref.read(preferencesServiceProvider).saveDiscoveryFilter(filter);
    state = filter;
  }
}

final discoveryFilterProvider =
    NotifierProvider<DiscoveryFilterNotifier, DiscoveryFilter>(
        DiscoveryFilterNotifier.new);

/// Còn ≤ số thẻ này thì tự tải trang kế (prefetch).
const int kPrefetchThreshold = 5;

class DiscoveryViewModel extends Notifier<DiscoveryState> {
  Set<String> _excluded = {};
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  int _generation = 0; // bỏ kết quả của lần load cũ khi filter đổi

  FirestoreService get _fs => ref.read(firestoreServiceProvider);
  String? get _myId => ref.read(firebaseAuthServiceProvider).currentUser?.uid;

  @override
  DiscoveryState build() {
    // Filter đổi -> tải lại từ đầu
    ref.listen<DiscoveryFilter>(discoveryFilterProvider, (prev, next) {
      if (prev != null && prev != next) reload();
    });
    Future.microtask(reload);
    return const DiscoveryState();
  }

  Future<void> reload() async {
    final myId = _myId;
    final gen = ++_generation;
    if (myId == null) {
      state = const DiscoveryState(isLoading: false, hasMore: false);
      return;
    }

    state = DiscoveryState(myLocation: state.myLocation, myTags: state.myTags);
    _cursor = null;
    try {
      // Vị trí: lấy 1 lần, thất bại thì bỏ qua
      var loc = state.myLocation;
      if (loc == null) {
        loc = await ref.read(locationServiceProvider).getCurrentLocation();
        if (loc != null) {
          _fs.updateLocation(myId, loc).catchError((_) {});
        }
      }
      var tags = state.myTags;
      try {
        final me = await _fs.getUserProfile(myId);
        if (me != null) tags = me.tags;
      } catch (_) {}
      _excluded = await _fs
          .getExcludedUserIds(myId)
          .timeout(const Duration(seconds: 15));
      if (gen != _generation) return;

      final page = await _fetch(myId, loc, tags);
      debugPrint('[Discovery] trang 1: +${page.users.length} thẻ, hasMore=${page.hasMore}');
      if (gen != _generation) return;
      state = DiscoveryState(
        cards: page.users,
        isLoading: false,
        hasMore: page.hasMore,
        myLocation: loc,
        myTags: tags,
      );
      _cursor = page.cursor;
      if (page.users.length <= kPrefetchThreshold && page.hasMore) {
        loadMore();
      }
    } catch (e) {
      if (gen != _generation) return;
      state = DiscoveryState(
        isLoading: false,
        hasMore: false,
        errorMessage: 'Lỗi tải danh sách gợi ý: $e',
      );
    }
  }

  Future<DiscoveryPage> _fetch(
      String myId, GeoPoint? loc, List<String> myTags) {
    var filter = ref.read(discoveryFilterProvider);
    // Bật "sở thích chung" mà chưa chọn tag nào -> dùng sở thích của mình
    if (filter.requireCommonInterest && filter.interests.isEmpty) {
      filter = filter.copyWith(interests: myTags);
    }
    return _fs
        .getDiscoveryPage(
          myId: myId,
          filter: filter,
          excludedIds: _excluded,
          myLocation: loc,
          startAfter: _cursor,
        )
        .timeout(const Duration(seconds: 20));
  }

  /// Tải trang kế tiếp (prefetch), không chặn UI.
  Future<void> loadMore() async {
    final myId = _myId;
    if (myId == null || state.isLoading || state.isLoadingMore) return;
    if (!state.hasMore) return;

    final gen = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _fetch(myId, state.myLocation, state.myTags);
      if (gen != _generation) return;
      final have = state.cards.map((u) => u.id).toSet();
      final fresh = page.users.where((u) => !have.contains(u.id)).toList();
      debugPrint('[Discovery] tải thêm: +${fresh.length} thẻ, hasMore=${page.hasMore}');
      _cursor = page.cursor;
      state = state.copyWith(
        cards: [...state.cards, ...fresh],
        isLoadingMore: false,
        hasMore: page.hasMore,
      );
    } catch (e) {
      debugPrint('Discovery loadMore error: $e');
      if (gen == _generation) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
      }
    }
  }

  /// Khoảng cách (km) tới [user], null nếu thiếu vị trí.
  double? distanceTo(UserModel user) {
    final me = state.myLocation;
    final them = user.location;
    if (me == null || them == null) return null;
    return haversineKm(
        me.latitude, me.longitude, them.latitude, them.longitude);
  }

  /// Ghi nhận swipe, trả về matchId nếu hai bên cùng thích.
  Future<String?> recordSwipe(String targetUserId, SwipeAction action) async {
    final myId = _myId;
    if (myId == null) return null;

    _excluded.add(targetUserId);
    return _fs.recordSwipe(
      myId: myId,
      targetUserId: targetUserId,
      action: action.value,
    );
  }

  /// Gọi khi một thẻ đã được quẹt đi; [remaining] = số thẻ còn lại.
  void onCardConsumed(int remaining) {
    if (remaining <= kPrefetchThreshold) loadMore();
  }
}

final discoveryViewModelProvider =
    NotifierProvider<DiscoveryViewModel, DiscoveryState>(
        DiscoveryViewModel.new);

/// Tổng số match của mình (hiển thị badge ở icon chat).
final matchCountProvider = Provider<int>((ref) {
  return ref.watch(matchesStreamProvider).value?.length ?? 0;
});
