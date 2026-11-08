import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/setting_repository.dart';
import 'auth_error_mapper.dart';
import 'auth_state.dart';

export 'auth_state.dart';

part 'auth_view_model.g.dart';

@Riverpod(keepAlive: true)
class AuthViewModel extends _$AuthViewModel {
  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  UserRepository get _userRepo => ref.read(userRepositoryProvider);
  SettingRepository get _settingRepo => ref.read(settingRepositoryProvider);

  @override
  AuthState build() {
    Future.microtask(_initCurrentUser);
    return const AuthState();
  }

  // ---------------------------------------------------------------------------
  // Khởi tạo phiên đăng nhập
  // ---------------------------------------------------------------------------

  Future<void> _initCurrentUser() async {
    final currentFirebaseUser = _authRepo.currentUser;
    if (currentFirebaseUser != null) {
      final cached = _settingRepo.getCachedUserProfile();
      if (cached != null && cached.id == currentFirebaseUser.uid) {
        state = state.copyWith(
          userModel: cached,
          isAuthenticated: true,
        );
      }

      try {
        final profile = await _userRepo.getUserProfile(currentFirebaseUser.uid);
        if (profile != null) {
          await _settingRepo.cacheUserProfile(profile);
          state = state.copyWith(
            userModel: profile,
            isAuthenticated: true,
          );
        } else {
          state = state.copyWith(isAuthenticated: true);
        }
      } catch (e) {
        debugPrint('Lỗi tải profile: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Email
  // ---------------------------------------------------------------------------

  Future<bool> signIn(String email, String password) {
    return _runEmailAuth(() async {
      final cred = await _authRepo.signInWithEmail(email, password);
      await _onAuthSuccess(cred.user!.uid, email: email);
    });
  }

  Future<bool> signUp(String email, String password) {
    return _runEmailAuth(() async {
      final cred = await _authRepo.signUpWithEmail(email, password);

      final initialUser = UserModel(
        id: cred.user!.uid,
        email: email.trim(),
        createdAt: DateTime.now(),
      );
      await _userRepo.saveUserProfile(initialUser);
      await _settingRepo.cacheUserProfile(initialUser);
      // Tài khoản mới luôn phải qua onboarding, kể cả khi máy từng hoàn tất onboarding với tài khoản khác
      await _settingRepo.setOnboardingCompleted(false);

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        userModel: initialUser,
      );
    });
  }

  /// Bao loading + xử lý lỗi chung cho đăng nhập / đăng ký Email.
  Future<bool> _runEmailAuth(Future<void> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await action();
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: mapFirebaseAuthError(e.code),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Có lỗi xảy ra: $e',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Profile sau đăng nhập
  // ---------------------------------------------------------------------------

  Future<void> _onAuthSuccess(
    String uid, {
    String? email,
  }) async {
    var profile = await _userRepo.getUserProfile(uid);

    if (profile == null) {
      profile = UserModel(
        id: uid,
        email: email ?? _authRepo.currentUser?.email ?? '',
        phoneNumber: _authRepo.currentUser?.phoneNumber,
        createdAt: DateTime.now(),
      );
      await _userRepo.saveUserProfile(profile);
    }

    final hasCompleted = profile.onboardingCompleted ||
        profile.fullName.trim().isNotEmpty;

    await _settingRepo.setOnboardingCompleted(hasCompleted);
    if (hasCompleted) await _settingRepo.setIsFirstTimeUser(false);
    await _settingRepo.cacheUserProfile(profile);

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      userModel: profile,
    );
  }

  Future<bool> updateInitialProfile({
    required String fullName,
    required DateTime? birthDate,
    required int age,
    required String gender,
    String interestedIn = 'all',
    required String orientation,
    required String bio,
    required List<String> tags,
    required List<String> avatarUrls,
    List<ProfilePrompt> prompts = const [],
  }) async {
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) {
      state = state.copyWith(errorMessage: 'Phiên đăng nhập không tồn tại');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = UserModel(
        id: uid,
        email: _authRepo.currentUser?.email ?? state.userModel?.email ?? '',
        phoneNumber: _authRepo.currentUser?.phoneNumber ??
            state.userModel?.phoneNumber,
        fullName: fullName.trim(),
        birthDate: birthDate,
        age: age,
        gender: gender,
        interestedIn: interestedIn,
        orientation: orientation,
        bio: bio.trim(),
        tags: tags,
        avatarUrls: avatarUrls,
        prompts: prompts,
        onboardingCompleted: true,
        updatedAt: DateTime.now(),
      );

      await _userRepo.saveUserProfile(updated);
      await _settingRepo.setOnboardingCompleted(true);
      await _settingRepo.setIsFirstTimeUser(false);
      await _settingRepo.cacheUserProfile(updated);

      // Đồng bộ ngay bộ lọc Discovery theo xu hướng muốn tìm
      final currentFilter = _settingRepo.loadDiscoveryFilter();
      await _settingRepo.saveDiscoveryFilter(
        currentFilter.copyWith(interestedIn: interestedIn),
      );

      state = state.copyWith(
        isLoading: false,
        userModel: updated,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Lỗi cập nhật hồ sơ: $e',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    // Cache SQLite của module 4 là theo tài khoản: xoá để người sau không thấy
    await ref.read(activityRepositoryProvider).clearAllCache();
    await _authRepo.signOut();
    await _settingRepo.clearCachedUserProfile();
    // Cờ onboarding là theo từng tài khoản: reset để người dùng kế tiếp trên máy này không bị bỏ qua onboarding
    await _settingRepo.setOnboardingCompleted(false);
    state = const AuthState();
  }
}
