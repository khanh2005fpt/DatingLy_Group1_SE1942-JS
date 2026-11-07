import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/repositories/geo_utils.dart';
import '../../data/models/discovery_filter.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/discovery_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'chat_view_model.dart';

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

class DiscoveryFilterNotifier extends Notifier<DiscoveryFilter> {
  @override
  DiscoveryFilter build() =>
      ref.read(settingRepositoryProvider).loadDiscoveryFilter();

  Future<void> apply(DiscoveryFilter filter) async {
    await ref.read(settingRepositoryProvider).saveDiscoveryFilter(filter);
    state = filter;
  }
}

final discoveryFilterProvider =
    NotifierProvider<DiscoveryFilterNotifier, DiscoveryFilter>(
        DiscoveryFilterNotifier.new);

const int kPrefetchThreshold = 5;

class DiscoveryViewModel extends Notifier<DiscoveryState> {
  Set<String> _excluded = {};
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  int _generation = 0;

  DiscoveryRepository get _discoveryRepo => ref.read(discoveryRepositoryProvider);
  UserRepository get _userRepo => ref.read(userRepositoryProvider);
  String? get _myId => ref.read(authRepositoryProvider).currentUser?.uid;

  @override
  DiscoveryState build() {
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
      var loc = state.myLocation;
      if (loc == null) {
        loc = await ref.read(locationRepositoryProvider).getCurrentLocation();
        if (loc != null) {
          _userRepo.updateLocation(myId, loc).catchError((_) {});
        }
      }
      var tags = state.myTags;
      try {
        final me = await _userRepo.getUserProfile(myId);
        if (me != null) tags = me.tags;
      } catch (_) {}
      _excluded = await _discoveryRepo
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
    if (filter.requireCommonInterest && filter.interests.isEmpty) {
      filter = filter.copyWith(interests: myTags);
    }
    return _discoveryRepo
        .getDiscoveryPage(
          myId: myId,
          filter: filter,
          excludedIds: _excluded,
          myLocation: loc,
          startAfter: _cursor,
        )
        .timeout(const Duration(seconds: 20));
  }

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
      _cursor = page.cursor;
      state = state.copyWith(
        cards: [...state.cards, ...fresh],
        isLoadingMore: false,
        hasMore: page.hasMore,
      );
    } catch (e) {
      if (gen == _generation) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
      }
    }
  }

  double? distanceTo(UserModel user) {
    final me = state.myLocation;
    final them = user.location;
    if (me == null || them == null) return null;
    return haversineKm(
        me.latitude, me.longitude, them.latitude, them.longitude);
  }

  Future<String?> recordSwipe(String targetUserId, SwipeAction action) async {
    final myId = _myId;
    if (myId == null) return null;

    _excluded.add(targetUserId);
    return _discoveryRepo.recordSwipe(
      myId: myId,
      targetUserId: targetUserId,
      action: action.value,
    );
  }

  void onCardConsumed(int remaining) {
    if (remaining <= kPrefetchThreshold) loadMore();
  }
}

final discoveryViewModelProvider =
    NotifierProvider<DiscoveryViewModel, DiscoveryState>(
        DiscoveryViewModel.new);

final matchCountProvider = Provider<int>((ref) {
  return ref.watch(matchesStreamProvider).value?.length ?? 0;
});
