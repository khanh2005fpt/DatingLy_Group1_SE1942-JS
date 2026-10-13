import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/firebase_auth_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../../../data/services/preferences_service.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserModel? userModel;
  final bool isAuthenticated;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.userModel,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserModel? userModel,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      userModel: userModel ?? this.userModel,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthViewModel extends Notifier<AuthState> {
  FirebaseAuthService get _authService => ref.read(firebaseAuthServiceProvider);
  FirestoreService get _firestoreService => ref.read(firestoreServiceProvider);
  PreferencesService get _prefs => ref.read(preferencesServiceProvider);

  @override
  AuthState build() {
    Future.microtask(_initCurrentUser);
    return const AuthState();
  }

  Future<void> _initCurrentUser() async {
    final currentFirebaseUser = _authService.currentUser;
    if (currentFirebaseUser != null) {
      final profile =
          await _firestoreService.getUserProfile(currentFirebaseUser.uid);
      state = state.copyWith(
        userModel: profile,
        isAuthenticated: true,
      );
    }
  }

  // Đăng nhập
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cred = await _authService.signInWithEmail(email, password);
      final uid = cred.user!.uid;
      final profile = await _firestoreService.getUserProfile(uid);

      if (profile != null && profile.fullName.isNotEmpty) {
        await _prefs.setHasSeenOnboarding(true);
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        userModel: profile,
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

  // Đăng ký
  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cred = await _authService.signUpWithEmail(email, password);
      final uid = cred.user!.uid;

      // Tạo profile rỗng ban đầu trên Firestore
      final initialUser = UserModel(
        id: uid,
        email: email.trim(),
        createdAt: DateTime.now(),
      );
      await _firestoreService.saveUserProfile(initialUser);

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

  // Cập nhật profile ban đầu sau khi đăng ký (Onboarding)
  Future<bool> updateInitialProfile({
    required String fullName,
    required int age,
    required String gender,
    required String bio,
    required List<String> tags,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      state = state.copyWith(errorMessage: 'Chưa đăng nhập');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updated = UserModel(
        id: uid,
        email: _authService.currentUser?.email ?? '',
        fullName: fullName,
        age: age,
        gender: gender,
        bio: bio,
        tags: tags,
        avatarUrls: state.userModel?.avatarUrls ?? [],
        updatedAt: DateTime.now(),
      );

      await _firestoreService.saveUserProfile(updated);
      await _prefs.setHasSeenOnboarding(true);

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

  // Đăng xuất
  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký tài khoản khác.';
      case 'invalid-email':
        return 'Địa chỉ email không đúng định dạng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (cần tối thiểu 6 ký tự).';
      case 'network-request-failed':
        return 'Lỗi mạng hoặc không có kết nối internet.';
      default:
        return 'Lỗi xác thực: $code';
    }
  }
}

// ViewModel Provider cho Auth
final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);
