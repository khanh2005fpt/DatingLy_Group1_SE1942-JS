import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../data/models/report_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/firebase_storage_service.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class SettingsState {
  final bool isLoading;
  final bool ghostMode;
  final String? error;
  final List<UserModel> blockedUsers;

  const SettingsState({
    this.isLoading = false,
    this.ghostMode = false,
    this.error,
    this.blockedUsers = const [],
  });

  SettingsState copyWith({
    bool? isLoading,
    bool? ghostMode,
    String? error,
    List<UserModel>? blockedUsers,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      ghostMode: ghostMode ?? this.ghostMode,
      error: error,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }
}

// ─── ViewModel ───────────────────────────────────────────────────────────────

class SettingsViewModel extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.read(preferencesServiceProvider);
    return SettingsState(ghostMode: prefs.ghostMode);
  }

  String? get _myId => FirebaseAuth.instance.currentUser?.uid;

  // ─── Ghost Mode ─────────────────────────────────────────────────────

  Future<void> toggleGhostMode() async {
    final newValue = !state.ghostMode;
    final prefs = ref.read(preferencesServiceProvider);
    final firestore = ref.read(firestoreServiceProvider);

    await prefs.setGhostMode(newValue);
    if (_myId != null) {
      await firestore.updateGhostMode(_myId!, newValue);
    }
    state = state.copyWith(ghostMode: newValue);
  }

  // ─── Block / Unblock ────────────────────────────────────────────────

  Future<void> blockUser(String targetId) async {
    if (_myId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(firestoreServiceProvider).blockUser(_myId!, targetId);
      // Cập nhật danh sách blocked nếu đã load
      final refreshed = await ref
          .read(firestoreServiceProvider)
          .getBlockedUsers(_myId!);
      state = state.copyWith(isLoading: false, blockedUsers: refreshed);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> unblockUser(String targetId) async {
    if (_myId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(firestoreServiceProvider).unblockUser(_myId!, targetId);
      final refreshed = await ref
          .read(firestoreServiceProvider)
          .getBlockedUsers(_myId!);
      state = state.copyWith(isLoading: false, blockedUsers: refreshed);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadBlockedUsers() async {
    if (_myId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final list = await ref
          .read(firestoreServiceProvider)
          .getBlockedUsers(_myId!);
      state = state.copyWith(isLoading: false, blockedUsers: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ─── Report ─────────────────────────────────────────────────────────

  Future<void> submitReport({
    required String reportedId,
    required String reason,
    required String description,
    XFile? screenshotFile,
  }) async {
    if (_myId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      String? screenshotUrl;

      // Upload ảnh chụp màn hình nếu có
      if (screenshotFile != null) {
        final storageService = ref.read(firebaseStorageServiceProvider);
        screenshotUrl = await storageService.uploadPhoto(
          userId: _myId!,
          imageFile: screenshotFile,
        );
      }

      final report = ReportModel(
        reporterId: _myId!,
        reportedId: reportedId,
        reason: reason,
        description: description,
        screenshotUrl: screenshotUrl,
      );

      await ref.read(firestoreServiceProvider).submitReport(report);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ─── Sign Out / Clear Cache ─────────────────────────────────────────

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      // 1. Xóa toàn bộ SharedPreferences
      await ref.read(preferencesServiceProvider).clearAll();
      // 2. Đăng xuất Firebase
      await FirebaseAuth.instance.signOut();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ─── Email / Password Update ─────────────────────────────────────────

  Future<void> updateEmail(String newEmail) async {
    state = state.copyWith(isLoading: true);
    try {
      await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(
        newEmail,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true);
    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, SettingsState>(SettingsViewModel.new);
