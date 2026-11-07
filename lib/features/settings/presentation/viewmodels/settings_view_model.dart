import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../data/models/report_model.dart';
import '../../../../data/models/user_model.dart';

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
    state = state.copyWith(isLoading: true);
    try {
      if (targetId == 'demo_user_123') {
        state = state.copyWith(
          isLoading: false,
          blockedUsers:
              state.blockedUsers.where((u) => u.id != targetId).toList(),
        );
        return;
      }
      if (_myId != null) {
        await ref.read(firestoreServiceProvider).unblockUser(_myId!, targetId);
        final refreshed = await ref
            .read(firestoreServiceProvider)
            .getBlockedUsers(_myId!);
        state = state.copyWith(isLoading: false, blockedUsers: refreshed);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Thêm 1 user mẫu để test tính năng Chặn và Bỏ chặn
  void addDemoBlockedUser() {
    const demo = UserModel(
      id: 'demo_user_123',
      fullName: 'Nguyễn Văn Test (Demo)',
      age: 24,
      gender: 'Nam',
      bio: 'Tài khoản mẫu để thử nghiệm tính năng Chặn và Bỏ chặn',
      avatarUrls: ['https://randomuser.me/api/portraits/men/32.jpg'],
    );
    state = state.copyWith(
      blockedUsers: [
        demo,
        ...state.blockedUsers.where((u) => u.id != demo.id),
      ],
    );
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

  Future<void> _clearSqliteCache() async {
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        final dbFolder = await getDatabasesPath();
        final dbNames = [
          'chat_cache.db',
          'datingly_module4.db',
          'notifications.db',
          'swiped_history_cache.db',
        ];
        for (final name in dbNames) {
          final filePath = p.join(dbFolder, name);
          await deleteDatabase(filePath);
        }
      }
    } catch (e) {
      debugPrint('Lỗi dọn dẹp SQLite cache khi đăng xuất: $e');
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      // 1. Xóa toàn bộ SharedPreferences cục bộ
      await ref.read(preferencesServiceProvider).clearAll();
      // 2. Xóa các database SQLite cache (offline chat, notifications, activity log)
      await _clearSqliteCache();
      // 3. Đăng xuất Firebase Auth
      await FirebaseAuth.instance.signOut();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ─── Re-authenticate / Email / Password Update ───────────────────────

  /// Re-authenticate với mật khẩu hiện tại trước khi đổi email hoặc mật khẩu
  Future<void> reauthenticate(String currentPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw Exception('Không tìm thấy tài khoản người dùng đang đăng nhập');
    }
    final cred = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
  }

  Future<void> updateEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await reauthenticate(currentPassword);
      await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(
        newEmail.trim(),
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await reauthenticate(currentPassword);
      await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, SettingsState>(SettingsViewModel.new);
