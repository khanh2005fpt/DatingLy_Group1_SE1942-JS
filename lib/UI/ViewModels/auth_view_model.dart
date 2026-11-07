import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/setting_repository.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserModel? userModel;
  final bool isAuthenticated;

  // Phone OTP Auth state
  final String? verificationId;
  final int? resendToken;
  final String? phoneNumber;
  final int resendCountdown;
  final bool isOtpSent;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.userModel,
    this.isAuthenticated = false,
    this.verificationId,
    this.resendToken,
    this.phoneNumber,
    this.resendCountdown = 0,
    this.isOtpSent = false,
  });

  bool get onboardingCompleted =>
      userModel?.onboardingCompleted == true ||
      (userModel != null && userModel!.fullName.trim().isNotEmpty);

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    UserModel? userModel,
    bool? isAuthenticated,
    String? verificationId,
    int? resendToken,
    String? phoneNumber,
    int? resendCountdown,
    bool? isOtpSent,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userModel: userModel ?? this.userModel,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      resendCountdown: resendCountdown ?? this.resendCountdown,
      isOtpSent: isOtpSent ?? this.isOtpSent,
    );
  }
}

class AuthViewModel extends Notifier<AuthState> {
  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  UserRepository get _userRepo => ref.read(userRepositoryProvider);
  SettingRepository get _settingRepo => ref.read(settingRepositoryProvider);

  Timer? _countdownTimer;

  @override
  AuthState build() {
    ref.onDispose(() {
      _countdownTimer?.cancel();
    });

    Future.microtask(_initCurrentUser);
    return const AuthState();
  }

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

  String formatPhoneNumber(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'\s+|-'), '').trim();
    if (cleaned.startsWith('0')) {
      cleaned = '+84${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+84$cleaned';
    }
    return cleaned;
  }

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

    final completer = Completer<bool>();

    try {
      await _authRepo.verifyPhoneNumber(
        phoneNumber: phone,
        resendToken: state.resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final cred =
                await FirebaseAuth.instance.signInWithCredential(credential);
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
            errorMessage: _mapFirebaseError(e.code),
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể gửi mã OTP: $e',
      );
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  /// Bắt đầu bộ đếm ngược gửi lại mã OTP (mặc định 60s)
  void startResendTimer([int seconds = 60]) {
    _countdownTimer?.cancel();
    state = state.copyWith(resendCountdown: seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendCountdown <= 1) {
        timer.cancel();
        state = state.copyWith(resendCountdown: 0);
      } else {
        state = state.copyWith(resendCountdown: state.resendCountdown - 1);
      }
    });
  }

  /// Hủy và reset bộ đếm thời gian gửi lại OTP
  void cancelResendTimer() {
    _countdownTimer?.cancel();
    state = state.copyWith(resendCountdown: 0);
  }

  Future<bool> resendOtp() async {
    if (state.resendCountdown > 0) return false;
    final phone = state.phoneNumber;
    if (phone == null || phone.isEmpty) return false;
    return sendPhoneOtp(phone);
  }

  void resetPhoneAuth() {
    _countdownTimer?.cancel();
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

    if (smsCode.trim().length < 6) {
      state = state.copyWith(
        errorMessage: 'Mã OTP bao gồm 6 chữ số.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cred = await _authRepo.signInWithPhoneOtp(
        verificationId: vId,
        smsCode: smsCode.trim(),
      );
      final uid = cred.user!.uid;
      await _onAuthSuccess(uid, phoneNumber: state.phoneNumber);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseError(e.code),
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

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cred = await _authRepo.signInWithEmail(email, password);
      final uid = cred.user!.uid;
      await _onAuthSuccess(uid, email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseError(e.code),
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

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cred = await _authRepo.signUpWithEmail(email, password);
      final uid = cred.user!.uid;

      final initialUser = UserModel(
        id: uid,
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
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseError(e.code),
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
    _countdownTimer?.cancel();
    await _authRepo.signOut();
    await _settingRepo.clearCachedUserProfile();
    state = const AuthState();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Số điện thoại không đúng định dạng. Vui lòng kiểm tra lại.';
      case 'invalid-verification-code':
        return 'Mã OTP không chính xác. Vui lòng thử lại.';
      case 'session-expired':
        return 'Mã OTP đã hết hiệu lực. Vui lòng nhấn gửi lại mã.';
      case 'quota-exceeded':
        return 'Hạn mức SMS của dịch vụ tạm thời vượt quá. Vui lòng thử lại sau.';
      case 'too-many-requests':
        return 'Bạn đã thử quá nhiều lần. Vui lòng đợi trong giây lát rồi thử lại.';
      case 'user-disabled':
        return 'Tài khoản của bạn đã bị tạm khóa.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Thông tin đăng nhập không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng cho tài khoản khác.';
      case 'invalid-email':
        return 'Địa chỉ email không đúng định dạng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (yêu cầu ít nhất 6 ký tự).';
      case 'network-request-failed':
        return 'Không thể kết nối Internet. Vui lòng kiểm tra mạng.';
      default:
        return 'Lỗi xác thực ($code). Vui lòng thử lại.';
    }
  }
}

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);

