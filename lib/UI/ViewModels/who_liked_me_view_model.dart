import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/models/swipe_history_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/who_liked_user_item.dart';
import '../../data/repositories/activity_repository.dart';

part 'who_liked_me_view_model.g.dart';

class WhoLikedMeState {
  final List<WhoLikedUserItem> items;
  final bool isLoading;
  final bool isGoldUnlocked;
  final String? errorMessage;

  const WhoLikedMeState({
    this.items = const [],
    this.isLoading = false,
    this.isGoldUnlocked = false,
    this.errorMessage,
  });

  WhoLikedMeState copyWith({
    List<WhoLikedUserItem>? items,
    bool? isLoading,
    bool? isGoldUnlocked,
    String? errorMessage,
  }) {
    return WhoLikedMeState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isGoldUnlocked: isGoldUnlocked ?? this.isGoldUnlocked,
      errorMessage: errorMessage,
    );
  }
}

@Riverpod(keepAlive: true)
class WhoLikedMeViewModel extends _$WhoLikedMeViewModel {
  ActivityRepository get _repository => ref.read(activityRepositoryProvider);

  @override
  WhoLikedMeState build() {
    final myId = ref.watch(authStateChangesProvider).value?.uid;
    if (myId != null) {
      final sub = _repository.streamWhoLikedMe(myId).listen(
        (items) {
          state = state.copyWith(items: items, isLoading: false);
        },
        onError: (err) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Lỗi tải người đã thích bạn: $err',
          );
        },
      );
      ref.onDispose(sub.cancel);
    }
    Future.microtask(loadWhoLikedMe);
    return const WhoLikedMeState(isLoading: true);
  }

  Future<void> loadWhoLikedMe() async {
    final myId = ref.read(authRepositoryProvider).currentUser?.uid;
    if (myId == null) {
      state = const WhoLikedMeState(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository
          .getWhoLikedMe(myId)
          .timeout(const Duration(seconds: 15));

      state = state.copyWith(items: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Lỗi tải danh sách người đã thích bạn: $e',
      );
    }
  }

  void toggleGoldPreview() {
    state = state.copyWith(isGoldUnlocked: !state.isGoldUnlocked);
  }

  /// Thích lại người đã thích mình -> Kích hoạt Match ngay lập tức!
  Future<String?> likeBack(UserModel targetUser, {bool isSuperLike = false}) async {
    final myId = ref.read(authRepositoryProvider).currentUser?.uid;
    if (myId == null) return null;

    try {
      // 1. Ghi nhận vào Firestore
      final matchId = await _repository.recordSwipe(
        myId: myId,
        targetUserId: targetUser.id,
        isLike: true,
        isSuperLike: isSuperLike,
      );

      // 2. Ghi nhận vào SQLite cache
      await _repository.insertSwipeHistory(
        SwipeHistoryModel(
          targetUserId: targetUser.id,
          targetUserName: targetUser.fullName,
          targetUserAvatar: targetUser.mainAvatarUrl,
          targetUserAge: targetUser.age,
          targetUserBio: targetUser.bio,
          action: isSuperLike ? 'superlike' : 'like',
          timestamp: DateTime.now(),
        ),
      );

      // 3. Cập nhật state cục bộ
      final updatedList = state.items
          .map((item) => item.user.id == targetUser.id
              ? item.copyWith(isMatched: true)
              : item)
          .toList();
      state = state.copyWith(items: updatedList);

      return matchId;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Lỗi khi tương hợp: $e');
      return null;
    }
  }

  /// Bỏ qua người này
  Future<void> passUser(UserModel targetUser) async {
    final myId = ref.read(authRepositoryProvider).currentUser?.uid;
    if (myId == null) return;

    try {
      // 1. Ghi nhận vào Firestore
      await _repository.recordSwipe(
        myId: myId,
        targetUserId: targetUser.id,
        isLike: false,
      );

      // 2. Ghi nhận vào SQLite cache
      await _repository.insertSwipeHistory(
        SwipeHistoryModel(
          targetUserId: targetUser.id,
          targetUserName: targetUser.fullName,
          targetUserAvatar: targetUser.mainAvatarUrl,
          targetUserAge: targetUser.age,
          targetUserBio: targetUser.bio,
          action: 'nope',
          timestamp: DateTime.now(),
        ),
      );

      // 3. Xóa khỏi danh sách hiển thị
      final updatedList =
          state.items.where((item) => item.user.id != targetUser.id).toList();
      state = state.copyWith(items: updatedList);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Lỗi khi bỏ qua: $e');
    }
  }
}

/// Số người chưa match đã like mình (badge).
@Riverpod(keepAlive: true)
int whoLikedMeCount(Ref ref) => ref
    .watch(whoLikedMeViewModelProvider)
    .items
    .where((i) => !i.isMatched)
    .length;

/// ID những người đã like mình (chưa match), dùng cho huy hiệu "Đã thích bạn".
@Riverpod(keepAlive: true)
Set<String> whoLikedMeUserIds(Ref ref) => ref
    .watch(whoLikedMeViewModelProvider)
    .items
    .where((i) => !i.isMatched)
    .map((i) => i.user.id)
    .toSet();
