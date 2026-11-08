import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/models/swipe_history_model.dart';
import '../../data/repositories/activity_repository.dart';

class SwipeHistoryState {
  final List<SwipeHistoryModel> history;
  final SwipeHistoryModel? lastSwipe;
  final bool isLoading;
  final bool isRewinding;
  final String currentFilter; // 'all', 'like', 'nope'
  final String? errorMessage;

  const SwipeHistoryState({
    this.history = const [],
    this.lastSwipe,
    this.isLoading = false,
    this.isRewinding = false,
    this.currentFilter = 'all',
    this.errorMessage,
  });

  SwipeHistoryState copyWith({
    List<SwipeHistoryModel>? history,
    SwipeHistoryModel? lastSwipe,
    bool? isLoading,
    bool? isRewinding,
    String? currentFilter,
    String? errorMessage,
  }) {
    return SwipeHistoryState(
      history: history ?? this.history,
      lastSwipe: lastSwipe ?? this.lastSwipe,
      isLoading: isLoading ?? this.isLoading,
      isRewinding: isRewinding ?? this.isRewinding,
      currentFilter: currentFilter ?? this.currentFilter,
      errorMessage: errorMessage,
    );
  }
}

class SwipeHistoryViewModel extends Notifier<SwipeHistoryState> {
  ActivityRepository get _repository => ref.read(activityRepositoryProvider);

  @override
  SwipeHistoryState build() {
    Future.microtask(loadHistory);
    return const SwipeHistoryState(isLoading: true);
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final filter =
          state.currentFilter == 'all' ? null : state.currentFilter;
      final list = await _repository.getRecentSwipeHistory(actionFilter: filter);
      final last = await _repository.getLastSwipe();

      state = state.copyWith(
        history: list,
        lastSwipe: last,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Lỗi tải lịch sử quẹt thẻ: $e',
      );
    }
  }

  Future<void> setFilter(String filter) async {
    if (state.currentFilter == filter) return;
    state = state.copyWith(currentFilter: filter, isLoading: true);
    final actionFilter = filter == 'all' ? null : filter;
    final list =
        await _repository.getRecentSwipeHistory(actionFilter: actionFilter);
    final last = await _repository.getLastSwipe();

    state = state.copyWith(
      history: list,
      lastSwipe: last,
      isLoading: false,
    );
  }

  /// Ghi nhận 1 thao tác quẹt vào SQLite
  Future<void> recordSwipe(SwipeHistoryModel swipe) async {
    await _repository.insertSwipeHistory(swipe);
    await loadHistory();
  }

  /// Hoàn tác (Undo/Rewind) lượt quẹt gần nhất
  Future<SwipeHistoryModel?> rewindLastSwipe() async {
    final myId = ref.read(authRepositoryProvider).currentUser?.uid;
    if (myId == null) return null;

    final last = await _repository.getLastSwipe();
    if (last == null) return null;

    state = state.copyWith(isRewinding: true);
    try {
      // 1. Xóa swipe khỏi Firestore để profile có thể xuất hiện lại
      await _repository.undoSwipe(
        myId: myId,
        targetUserId: last.targetUserId,
      );

      // 2. Xóa khỏi SQLite cache
      if (last.id != null) {
        await _repository.deleteSwipe(last.id!);
      } else {
        await _repository.deleteSwipeByTargetUserId(last.targetUserId);
      }

      await loadHistory();
      state = state.copyWith(isRewinding: false);
      return last;
    } catch (e) {
      state = state.copyWith(
        isRewinding: false,
        errorMessage: 'Lỗi hoàn tác: $e',
      );
      return null;
    }
  }

  /// Hoàn tác một lượt quẹt cụ thể trong danh sách
  Future<bool> rewindSwipe(SwipeHistoryModel item) async {
    final myId = ref.read(authRepositoryProvider).currentUser?.uid;
    if (myId == null) return false;

    try {
      await _repository.undoSwipe(
        myId: myId,
        targetUserId: item.targetUserId,
      );

      if (item.id != null) {
        await _repository.deleteSwipe(item.id!);
      } else {
        await _repository.deleteSwipeByTargetUserId(item.targetUserId);
      }

      await loadHistory();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Lỗi khi hoàn tác thẻ này: $e');
      return false;
    }
  }

  Future<void> clearHistory() async {
    await _repository.clearAllSwipeHistory();
    await loadHistory();
  }
}

final swipeHistoryViewModelProvider =
    NotifierProvider<SwipeHistoryViewModel, SwipeHistoryState>(
  SwipeHistoryViewModel.new,
);
