import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../data/local/database_helper.dart';
import '../../../../data/models/swipe_history_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/who_liked_user_item.dart';

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

class WhoLikedMeViewModel extends Notifier<WhoLikedMeState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  WhoLikedMeState build() {
    final myId = ref.watch(authStateChangesProvider).value?.uid;
    if (myId != null) {
      final sub = ref
          .read(firestoreServiceProvider)
          .streamWhoLikedMe(myId)
          .listen(
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
    final myId = ref.read(firebaseAuthServiceProvider).currentUser?.uid;
    if (myId == null) {
      state = const WhoLikedMeState(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await ref
          .read(firestoreServiceProvider)
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
    final myId = ref.read(firebaseAuthServiceProvider).currentUser?.uid;
    if (myId == null) return null;

    try {
      // 1. Ghi nhận vào Firestore
      final matchId = await ref.read(firestoreServiceProvider).recordSwipe(
            myId: myId,
            targetUserId: targetUser.id,
            isLike: true,
            isSuperLike: isSuperLike,
          );

      // 2. Ghi nhận vào SQLite cache
      await _dbHelper.insertSwipeHistory(
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
    final myId = ref.read(firebaseAuthServiceProvider).currentUser?.uid;
    if (myId == null) return;

    try {
      // 1. Ghi nhận vào Firestore
      await ref.read(firestoreServiceProvider).recordSwipe(
            myId: myId,
            targetUserId: targetUser.id,
            isLike: false,
          );

      // 2. Ghi nhận vào SQLite cache
      await _dbHelper.insertSwipeHistory(
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

final whoLikedMeViewModelProvider =
    NotifierProvider<WhoLikedMeViewModel, WhoLikedMeState>(
  WhoLikedMeViewModel.new,
);

/// Provider đếm số người chưa match đã like mình
final whoLikedMeCountProvider = Provider<int>((ref) {
  final state = ref.watch(whoLikedMeViewModelProvider);
  return state.items.where((i) => !i.isMatched).length;
});

/// Provider tập hợp các ID người dùng đã like mình (chưa match).
/// Module Discovery (Huy) có thể dùng trực tiếp để hiển thị huy hiệu "Đã thích bạn"
/// trên thẻ quẹt một cách mượt mà không cần truy vấn Firestore lặp lại.
final whoLikedMeUserIdsProvider = Provider<Set<String>>((ref) {
  final state = ref.watch(whoLikedMeViewModelProvider);
  return state.items
      .where((i) => !i.isMatched)
      .map((i) => i.user.id)
      .toSet();
});
