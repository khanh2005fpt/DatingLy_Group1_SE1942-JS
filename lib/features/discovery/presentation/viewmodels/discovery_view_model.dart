import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../data/models/user_model.dart';
import '../../../chat/presentation/viewmodels/chat_view_model.dart';

class DiscoveryState {
  final List<UserModel> candidates;
  final bool isLoading;
  final String? errorMessage;

  const DiscoveryState({
    this.candidates = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  DiscoveryState copyWith({
    List<UserModel>? candidates,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DiscoveryState(
      candidates: candidates ?? this.candidates,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// ViewModel cho từng tab giới tính ([gender] là tham số của family).
class DiscoveryViewModel extends Notifier<DiscoveryState> {
  DiscoveryViewModel(this.gender);

  final String gender;

  @override
  DiscoveryState build() => const DiscoveryState();

  Future<void> loadCandidates() async {
    final myId = ref.read(firebaseAuthServiceProvider).currentUser?.uid;
    if (myId == null) {
      state = const DiscoveryState(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      // Timeout để không quay vòng vô hạn khi Firestore chưa tạo / mất mạng
      final list = await ref
          .read(firestoreServiceProvider)
          .getDiscoveryUsers(myId: myId, genderFilter: gender)
          .timeout(const Duration(seconds: 15));
      state = DiscoveryState(candidates: list, isLoading: false);
    } catch (e) {
      state = DiscoveryState(
        isLoading: false,
        errorMessage: 'Lỗi tải danh sách gợi ý: $e',
      );
    }
  }

  /// Ghi nhận swipe, trả về matchId nếu hai bên cùng thích / super like.
  Future<String?> recordSwipe(
    String targetUserId,
    bool isLike, {
    bool isSuperLike = false,
  }) async {
    final myId = ref.read(firebaseAuthServiceProvider).currentUser?.uid;
    if (myId == null) return null;

    return ref.read(firestoreServiceProvider).recordSwipe(
          myId: myId,
          targetUserId: targetUserId,
          isLike: isLike,
          isSuperLike: isSuperLike,
        );
  }
}

final discoveryViewModelProvider =
    NotifierProvider.family<DiscoveryViewModel, DiscoveryState, String>(
        DiscoveryViewModel.new);

/// Tổng số match của mình (hiển thị badge ở icon chat).
final matchCountProvider = Provider<int>((ref) {
  return ref.watch(matchesStreamProvider).value?.length ?? 0;
});
