import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/phone_auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/setting_repository.dart';
import 'auth_error_mapper.dart';
import 'auth_state.dart';
import 'phone_otp_helper.dart' as phone_fmt;

export 'auth_state.dart';

class AuthViewModel extends Notifier<AuthState> {
  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  PhoneAuthRepository get _phoneRepo => ref.read(phoneAuthRepositoryProvider);
  UserRepository get _userRepo => ref.read(userRepositoryProvider);
  SettingRepository get _settingRepo => ref.read(settingRepositoryProvider);

  final phone_fmt.OtpResendTimer _resendTimer = phone_fmt.OtpResendTimer();

  @override
  AuthState build() {
    ref.onDispose(_resendTimer.cancel);

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
  // Phone OTP
  // ---------------------------------------------------------------------------

  String formatPhoneNumber(String raw) => phone_fmt.formatPhoneNumber(raw);

  Future<bool> sendPhoneOtp(String rawPhone) async {
    final phone = formatPhoneNumber(rawPhone);
    if (phone.length < 10) {
      state = state.copyWith(
        errorMessage: 'Số điện thoại không hợp lệ. Vui lòng kiểm tra lại.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      phoneNumber: phone,
    );

    if (phone_fmt.isDemoPhoneNumber(phone)) {
      await Future.delayed(const Duration(milliseconds: 500));
      _enterDemoOtpMode();
      return true;
    }

    final completer = Completer<bool>();

    try {
      await _phoneRepo.verifyPhoneNumber(
        phoneNumber: phone,
        resendToken: state.resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final cred = await _phoneRepo.signInWithCredential(credential);
            await _onAuthSuccess(cred.user!.uid, phoneNumber: phone);
            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            state = state.copyWith(
              isLoading: false,
              errorMessage: 'Lỗi tự động xác thực: $e',
            );
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: mapFirebaseAuthError(e.code),
          );
          if (!completer.isCompleted) completer.complete(false);
        },
        codeSent: (String verificationId, int? resendToken) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            resendToken: resendToken,
            isOtpSent: true,
          );
          startResendTimer(60);
          if (!completer.isCompleted) completer.complete(true);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          state = state.copyWith(verificationId: verificationId);
        },
      );
    } catch (e) {
      if (_isSmsUnsupportedError(e)) {
        // Fallback hỗ trợ môi trường không có SMS Native (Desktop / Test)
        _enterDemoOtpMode();
        if (!completer.isCompleted) completer.complete(true);
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Không thể gửi mã OTP: $e',
        );
        if (!completer.isCompleted) completer.complete(false);
      }
    }

    return completer.future;
  }

  bool _isSmsUnsupportedError(Object e) {
    final errStr = e.toString().toLowerCase();
    return errStr.contains('unimplemented') ||
        errStr.contains('notsupported') ||
        errStr.contains('platform');
  }

  void _enterDemoOtpMode() {
    state = state.copyWith(
      isLoading: false,
      verificationId: phone_fmt.demoVerificationId,
      resendToken: 12345,
      isOtpSent: true,
    );
    startResendTimer(60);
  }

  /// Bắt đầu bộ đếm ngược gửi lại mã OTP (mặc định 60s)
  void startResendTimer([int seconds = 60]) {
    _resendTimer.start(
      seconds,
      (remaining) => state = state.copyWith(resendCountdown: remaining),
    );
  }

  /// Hủy và reset bộ đếm thời gian gửi lại OTP
  void cancelResendTimer() {
    _resendTimer.cancel();
    state = state.copyWith(resendCountdown: 0);
  }

  Future<bool> resendOtp() async {
    if (state.resendCountdown > 0) return false;
    final phone = state.phoneNumber;
    if (phone == null || phone.isEmpty) return false;
    return sendPhoneOtp(phone);
  }

  void resetPhoneAuth() {
    _resendTimer.cancel();
    state = state.copyWith(
      isOtpSent: false,
      verificationId: null,
      resendCountdown: 0,
      clearError: true,
    );
  }

  Future<bool> verifyPhoneOtp(String smsCode) async {
    final vId = state.verificationId;
    if (vId == null || vId.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Phiên xác thực đã hết hạn. Vui lòng gửi lại mã OTP.',
      );
      return false;
    }

    final code = smsCode.trim();
    if (code.length < 6) {
      state = state.copyWith(
        errorMessage: 'Mã OTP bao gồm 6 chữ số.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    if (vId == phone_fmt.demoVerificationId) {
      return _verifyDemoOtp(code);
    }

    try {
      final cred = await _phoneRepo.signInWithOtp(
        verificationId: vId,
        smsCode: code,
      );
      await _onAuthSuccess(cred.user!.uid, phoneNumber: state.phoneNumber);
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
        errorMessage: 'Xác thực OTP thất bại: $e',
      );
      return false;
    }
  }

  /// Chế độ demo / thử nghiệm: chấp nhận mọi mã 6 chữ số.
  Future<bool> _verifyDemoOtp(String code) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (code == '123456' || code == '666666' || code.length == 6) {
      try {
        final cred = await _phoneRepo.signInAnonymously();
        await _onAuthSuccess(cred.user!.uid, phoneNumber: state.phoneNumber);
      } catch (_) {
        final mockUid =
            'user_phone_${state.phoneNumber?.replaceAll(RegExp(r'\D'), '') ?? "demo"}';
        await _onAuthSuccess(mockUid, phoneNumber: state.phoneNumber);
      }
      return true;
    }
    state = state.copyWith(
      isLoading: false,
      errorMessage: 'Mã OTP không chính xác. Mã thử nghiệm là 123456.',
    );
    return false;
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
    String? phoneNumber,
  }) async {
    var profile = await _userRepo.getUserProfile(uid);

    if (profile == null) {
      profile = UserModel(
        id: uid,
        email: email ?? _authRepo.currentUser?.email ?? '',
        phoneNumber: phoneNumber ?? _authRepo.currentUser?.phoneNumber,
        createdAt: DateTime.now(),
      );
      await _userRepo.saveUserProfile(profile);
    }

    final hasCompleted = profile.onboardingCompleted ||
        profile.fullName.trim().isNotEmpty;

    await _settingRepo.setOnboardingCompleted(hasCompleted);
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
    required String orientation,
    required String bio,
    required List<String> tags,
    required List<String> avatarUrls,
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
        orientation: orientation,
        bio: bio.trim(),
        tags: tags,
        avatarUrls: avatarUrls,
        onboardingCompleted: true,
        updatedAt: DateTime.now(),
      );

      await _userRepo.saveUserProfile(updated);
      await _settingRepo.setOnboardingCompleted(true);
      await _settingRepo.setIsFirstTimeUser(false);
      await _settingRepo.cacheUserProfile(updated);

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
    _resendTimer.cancel();
    await _authRepo.signOut();
    await _settingRepo.clearCachedUserProfile();
    state = const AuthState();
  }
}

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);
